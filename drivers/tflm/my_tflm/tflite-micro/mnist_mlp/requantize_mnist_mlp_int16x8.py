#!/usr/bin/env python3
"""Requantize the trained MNIST MLP to TFLM's int16 x int8 format.

This is a small, TensorFlow-free wrapper around the same rules used by
tensorflow/lite/micro/tools/requantize_flatbuffer.py. Activations become
symmetric int16, weights stay int8, and model biases become int64. The target
software deliberately saturates those int64 bias values to the NPU's int32
bias path before launching an operation.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import flatbuffers
import numpy as np


THIS_DIR = Path(__file__).resolve().parent
TFLM_ROOT = THIS_DIR.parent
sys.path.insert(0, str(TFLM_ROOT))

from tensorflow.lite.python import schema_py_generated as schema  # noqa: E402


def read_model(path: Path):
    data = bytearray(path.read_bytes())
    return schema.ModelT.InitFromObj(schema.Model.GetRootAsModel(data, 0))


def write_model(model, path: Path) -> bytes:
    builder = flatbuffers.Builder(1024)
    model_offset = model.Pack(builder)
    builder.Finish(model_offset, file_identifier=b"TFL3")
    data = bytes(builder.Output())
    path.write_bytes(data)
    return data


def tensor_scale(tensor) -> float:
    if tensor.quantization is None or len(tensor.quantization.scale) != 1:
        raise ValueError(f"tensor {tensor.name!r} must use per-tensor quantization")
    return float(tensor.quantization.scale[0])


def activation_to_int16(tensor) -> None:
    if tensor.type == schema.TensorType.INT16:
        return
    if tensor.type != schema.TensorType.INT8:
        raise ValueError(f"activation {tensor.name!r} is not INT8")
    old_scale = tensor_scale(tensor)
    old_zero_point = int(tensor.quantization.zeroPoint[0])
    real_max = old_scale * (128 - old_zero_point)
    real_min = old_scale * (-128 - old_zero_point)
    tensor.quantization.scale = [max(abs(real_max), abs(real_min)) / 32767.0]
    tensor.quantization.zeroPoint = [0]
    tensor.type = schema.TensorType.INT16


def bias_to_int64(model, input_tensor, weight_tensor, bias_tensor) -> int:
    if bias_tensor.type == schema.TensorType.INT64:
        values = np.frombuffer(
            bytes(model.buffers[bias_tensor.buffer].data), dtype="<i8"
        )
        return int(np.max(np.abs(values))) if values.size else 0
    if bias_tensor.type != schema.TensorType.INT32:
        raise ValueError(f"bias {bias_tensor.name!r} is not INT32")

    input_scale = tensor_scale(input_tensor)
    weight_scale = tensor_scale(weight_tensor)
    old_bias_scale = tensor_scale(bias_tensor)
    new_bias_scale = input_scale * weight_scale
    old_values = np.frombuffer(
        bytes(model.buffers[bias_tensor.buffer].data), dtype="<i4"
    )
    expected_count = int(np.prod(bias_tensor.shape))
    if old_values.size != expected_count:
        raise ValueError(
            f"bias {bias_tensor.name!r} has {old_values.size} values, "
            f"expected {expected_count}"
        )
    new_values = np.rint(
        old_values.astype(np.float64) * old_bias_scale / new_bias_scale
    ).astype("<i8")
    model.buffers[bias_tensor.buffer].data = new_values.tobytes()
    bias_tensor.type = schema.TensorType.INT64
    bias_tensor.quantization.scale = [new_bias_scale]
    bias_tensor.quantization.zeroPoint = [0]
    return int(np.max(np.abs(new_values))) if new_values.size else 0


def requantize(model) -> list[dict[str, int]]:
    bias_stats: list[dict[str, int]] = []
    for subgraph in model.subgraphs:
        tensors = subgraph.tensors
        for operator in subgraph.operators:
            builtin = model.operatorCodes[operator.opcodeIndex].builtinCode
            if builtin == schema.BuiltinOperator.FULLY_CONNECTED:
                input_tensor = tensors[operator.inputs[0]]
                weight_tensor = tensors[operator.inputs[1]]
                output_tensor = tensors[operator.outputs[0]]
                if weight_tensor.type != schema.TensorType.INT8:
                    raise ValueError("fully-connected weights must remain INT8")
                activation_to_int16(input_tensor)
                activation_to_int16(output_tensor)
                if len(operator.inputs) > 2 and operator.inputs[2] >= 0:
                    bias_tensor = tensors[operator.inputs[2]]
                    max_abs = bias_to_int64(
                        model, input_tensor, weight_tensor, bias_tensor
                    )
                    bias_stats.append(
                        {"elements": int(np.prod(bias_tensor.shape)), "max_abs": max_abs}
                    )
            elif builtin == schema.BuiltinOperator.SOFTMAX:
                activation_to_int16(tensors[operator.inputs[0]])
                output_tensor = tensors[operator.outputs[0]]
                output_tensor.type = schema.TensorType.INT16
                output_tensor.quantization.scale = [1.0 / 32768.0]
                output_tensor.quantization.zeroPoint = [0]
            else:
                raise ValueError(f"unsupported operator code {builtin}")
    return bias_stats


def c_array(name: str, data: bytes, columns: int = 12) -> str:
    lines = [f"alignas(16) const unsigned char {name}[] = {{"]
    for offset in range(0, len(data), columns):
        chunk = ", ".join(f"0x{value:02x}" for value in data[offset : offset + columns])
        lines.append(f"  {chunk},")
    lines.append("};")
    return "\n".join(lines)


def write_c_files(data: bytes, source_path: Path, header_path: Path) -> None:
    symbol = "g_mnist_mlp_int16x8_model_data"
    header_path.write_text(
        """#ifndef MNIST_MLP_INT16X8_MODEL_DATA_H_
#define MNIST_MLP_INT16X8_MODEL_DATA_H_

extern const unsigned char g_mnist_mlp_int16x8_model_data[];
extern const int g_mnist_mlp_int16x8_model_data_len;

#endif  // MNIST_MLP_INT16X8_MODEL_DATA_H_
""",
        encoding="utf-8",
    )
    source_path.write_text(
        '#include "mnist_mlp/mnist_mlp_int16x8_model_data.h"\n\n'
        + c_array(symbol, data)
        + f"\n\nconst int {symbol}_len = {len(data)};\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=THIS_DIR / "mnist_mlp_int8.tflite")
    parser.add_argument(
        "--output", type=Path, default=THIS_DIR / "mnist_mlp_int16x8.tflite"
    )
    args = parser.parse_args()

    model = read_model(args.input)
    bias_stats = requantize(model)
    model_data = write_model(model, args.output)
    write_c_files(
        model_data,
        THIS_DIR / "mnist_mlp_int16x8_model_data.cc",
        THIS_DIR / "mnist_mlp_int16x8_model_data.h",
    )
    print(
        json.dumps(
            {
                "input": str(args.input),
                "output": str(args.output),
                "bytes": len(model_data),
                "biases": bias_stats,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
