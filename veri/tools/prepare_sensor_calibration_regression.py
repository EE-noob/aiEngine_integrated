#!/usr/bin/env python3
"""Import and analyze the latest INT16x8 sensor-calibration TFLite model.

The script reproduces the model's holdout split, runs the regular TFLite
interpreter, and compares every FULLY_CONNECTED output with the NPU arithmetic
contract used by this repository:

  * INT16 activations and INT8 weights;
  * model INT64 bias saturated to INT32 before launch;
  * wrapping INT32 dot-product/bias accumulation;
  * NMSIS-compatible reduced-multiplier requantization to INT16.

It also creates the model/test C arrays consumed by the RV32 SoC regression.
Run this script in an environment containing TensorFlow and NumPy (the source
model was produced with the ``tf_2_18`` conda environment).
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import shutil
from pathlib import Path

import numpy as np
import tensorflow as tf
from tensorflow.lite.python import schema_py_generated as schema


VOLTAGE_INPUT = "adc_voltage_4_v"
CURRENT_INPUT = "ina_current_2_a"
TEMPERATURE_INPUT = "hdc3020_ref_temp_c"
HUMIDITY_INPUT = "gxht45_humidity_rh"
VOLTAGE_REFERENCE = "dmm_voltage_v"
CURRENT_REFERENCE = "load_current_a"
HUMIDITY_REFERENCE = "hdc3020_ref_humidity_rh"

VOLTAGE_LIMIT_V = 0.005
CURRENT_LIMIT_A = 0.005
HUMIDITY_LIMIT_RH = 1.0
REFERENCE_TARGET_OUTLIER_LIMIT_V = 0.200
LOW_VOLTAGE_TRANSIENT_LIMIT_V = 0.300
LOW_VOLTAGE_RESIDUAL_LIMIT_V = 0.100
CURRENT_OUTLIER_LIMIT_A = 0.050
HUMIDITY_OUTLIER_LIMIT_RH = 10.0

DEFAULT_SOURCE_ROOT = Path("/home/yusen/公共的/sensor_calibration_data")
MODEL_FILENAME = "sensor_offset_calibrator_int16.tflite"


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    default_output = (
        repo_root
        / "drivers/tflm/my_tflm/tflite-micro/sensor_calibration"
    )
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=DEFAULT_SOURCE_ROOT)
    parser.add_argument(
        "--model-dir",
        default=None,
        help="Model directory below source-root; default selects the newest model by mtime.",
    )
    parser.add_argument("--csv", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, default=default_output)
    parser.add_argument("--soc-samples", type=int, default=3)
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit holdout rows for a quick debug run; zero runs all rows.",
    )
    return parser.parse_args()


def read_values(path: Path) -> tuple[dict[str, np.ndarray], np.ndarray]:
    required = (
        VOLTAGE_INPUT,
        CURRENT_INPUT,
        TEMPERATURE_INPUT,
        HUMIDITY_INPUT,
        VOLTAGE_REFERENCE,
        CURRENT_REFERENCE,
        HUMIDITY_REFERENCE,
    )
    with path.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        rows = list(reader)
        fieldnames = set(reader.fieldnames or ())
    missing = set(required).difference(fieldnames)
    if missing:
        raise ValueError(f"CSV lacks required columns: {sorted(missing)}")
    values = {
        name: np.asarray([float(row[name]) for row in rows], dtype=np.float64)
        for name in required
    }
    for optional in ("target_voltage_v", "target_current_a"):
        if optional in fieldnames:
            values[optional] = np.asarray(
                [float(row[optional]) for row in rows], dtype=np.float64
            )
    finite = np.logical_and.reduce([np.isfinite(value) for value in values.values()])
    source_rows = np.flatnonzero(finite).astype(np.uint32)
    return {name: value[finite] for name, value in values.items()}, source_rows


def accepted_mask(values: dict[str, np.ndarray]) -> np.ndarray:
    voltage = values[VOLTAGE_INPUT]
    reference_voltage = values[VOLTAGE_REFERENCE]
    current = values[CURRENT_INPUT]
    reference_current = values[CURRENT_REFERENCE]
    humidity = values[HUMIDITY_INPUT]
    reference_humidity = values[HUMIDITY_REFERENCE]

    voltage_ok = ~(
        ((voltage <= 0.0) & (np.abs(reference_voltage) > VOLTAGE_LIMIT_V))
        | (
            (voltage < 0.1)
            & (np.abs(reference_voltage - voltage) > 0.010)
        )
    )
    current_ok = np.abs(current - reference_current) <= CURRENT_OUTLIER_LIMIT_A
    humidity_ok = (
        (humidity >= 0.0)
        & (humidity <= 100.0)
        & (reference_humidity >= 0.0)
        & (reference_humidity <= 100.0)
        & (np.abs(humidity - reference_humidity) <= HUMIDITY_OUTLIER_LIMIT_RH)
    )
    if "target_voltage_v" in values:
        stale_reference = (
            np.abs(reference_voltage - values["target_voltage_v"])
            > REFERENCE_TARGET_OUTLIER_LIMIT_V
        )
        low_voltage_transient = (
            values["target_voltage_v"] < LOW_VOLTAGE_TRANSIENT_LIMIT_V
        ) & (
            np.abs(voltage - reference_voltage) > LOW_VOLTAGE_RESIDUAL_LIMIT_V
        )
        voltage_ok &= ~stale_reference & ~low_voltage_transient
    if "target_current_a" in values:
        current_ok &= (
            np.abs(reference_current - values["target_current_a"])
            <= CURRENT_OUTLIER_LIMIT_A
        )
    return voltage_ok & current_ok & humidity_ok


def polynomial_exponents(input_count: int, degree: int) -> list[tuple[int, ...]]:
    def compositions(total: int, count: int) -> list[tuple[int, ...]]:
        if count == 1:
            return [(total,)]
        return [
            (first, *suffix)
            for first in range(total, -1, -1)
            for suffix in compositions(total - first, count - 1)
        ]

    return [
        exponent
        for total_degree in range(1, degree + 1)
        for exponent in compositions(total_degree, input_count)
    ]


def make_features(
    values: dict[str, np.ndarray], metadata: dict
) -> np.ndarray:
    model_inputs = metadata["model_inputs"]
    raw = np.column_stack([values[name] for name in model_inputs])
    normalized = (
        raw - np.asarray(metadata["raw_input_mean"], dtype=np.float64)
    ) / np.asarray(metadata["raw_input_scale"], dtype=np.float64)
    if metadata.get("feature_mode") != "interaction_polynomial":
        raise ValueError("latest sensor model must use interaction_polynomial")
    exponents = polynomial_exponents(
        len(model_inputs), int(metadata["polynomial_degree"])
    )
    expanded = np.column_stack(
        [
            np.prod(normalized ** np.asarray(exponent, dtype=np.int64), axis=1)
            for exponent in exponents
        ]
    )
    features = (
        expanded - np.asarray(metadata["expanded_feature_mean"], dtype=np.float64)
    ) / np.asarray(metadata["expanded_feature_scale"], dtype=np.float64)
    return features.astype(np.float32)


def quantize_multiplier(real_multiplier: float) -> tuple[int, int]:
    significand, shift = math.frexp(real_multiplier)
    quantized = int(math.floor(significand * (1 << 31) + 0.5))
    if quantized == (1 << 31):
        quantized //= 2
        shift += 1
    if shift < -31:
        return 0, 0
    if shift > 30:
        return (1 << 31) - 1, 30
    return quantized, shift


def nmsis_requantize_s64(
    accumulator: np.ndarray, multiplier: int, shift: int
) -> np.ndarray:
    reduced_multiplier = (
        (multiplier + (1 << 15)) >> 16
        if multiplier < 0x7FFF0000
        else 0x7FFF
    )
    total_shift = 15 - shift
    # Object integers avoid NumPy int64 overflow in the intermediate product.
    value = accumulator.astype(object) * reduced_multiplier
    value = (value + (1 << (total_shift - 1))) >> total_shift
    return np.asarray(value, dtype=np.int64)


def signed_int32_wrap(value: np.ndarray) -> np.ndarray:
    return ((value + (1 << 31)) % (1 << 32) - (1 << 31)).astype(np.int64)


def truncating_divide(numerator: int, denominator: int) -> int:
    return (
        numerator // denominator
        if numerator >= 0
        else -((-numerator) // denominator)
    )


def saturating_rounding_doubling_high_mul(a: int, b: int) -> int:
    if a == np.iinfo(np.int32).min and b == np.iinfo(np.int32).min:
        return int(np.iinfo(np.int32).max)
    product = a * b
    nudge = (1 << 30) if product >= 0 else 1 - (1 << 30)
    return truncating_divide(product + nudge, 1 << 31)


def rounding_divide_by_pot(value: int, exponent: int) -> int:
    if exponent == 0:
        return value
    mask = (1 << exponent) - 1
    remainder = value & mask
    threshold = (mask >> 1) + (1 if value < 0 else 0)
    return (value >> exponent) + (1 if remainder > threshold else 0)


def multiply_by_quantized_multiplier(
    values: np.ndarray, multiplier: int, shift: int
) -> np.ndarray:
    left_shift = max(shift, 0)
    right_shift = max(-shift, 0)

    def multiply_one(value: int) -> int:
        high_mul = saturating_rounding_doubling_high_mul(
            int(value) * (1 << left_shift), multiplier
        )
        return rounding_divide_by_pot(high_mul, right_shift)

    return np.asarray(
        [multiply_one(int(value)) for value in values.reshape(-1)],
        dtype=np.int64,
    ).reshape(values.shape)


def activation_range(options) -> tuple[int, int]:
    activation = int(options.fusedActivationFunction)
    if activation == schema.ActivationFunctionType.NONE:
        return -32768, 32767
    if activation == schema.ActivationFunctionType.RELU:
        return 0, 32767
    if activation == schema.ActivationFunctionType.RELU6:
        raise ValueError("RELU6 is not expected in the imported sensor model")
    raise ValueError(f"unsupported fused activation {activation}")


def model_from_bytes(content: bytes):
    return schema.ModelT.InitFromObj(
        schema.Model.GetRootAsModel(bytearray(content), 0)
    )


def tensor_buffer(model, tensor, dtype: str) -> np.ndarray:
    raw = model.buffers[tensor.buffer].data
    data = bytes(raw) if raw is not None else b""
    return np.frombuffer(data, dtype=dtype)


def evaluate_fc_contract(
    model,
    quantized_inputs: np.ndarray,
    reference_tensors: dict[int, np.ndarray],
) -> tuple[dict, dict[int, np.ndarray]]:
    subgraph = model.subgraphs[0]
    input_tensor = subgraph.tensors[subgraph.inputs[0]]
    input_scale = float(input_tensor.quantization.scale[0])
    input_zero_point = int(input_tensor.quantization.zeroPoint[0])
    if input_zero_point != 0:
        raise ValueError("NPU INT16x8 path requires symmetric INT16 input")

    fc_records = []
    total_mismatches = 0
    maximum_difference = 0
    total_accumulator_overflows = 0
    total_saturated_biases = 0
    npu_tensors = {int(subgraph.inputs[0]): quantized_inputs}

    for operator_index, operator in enumerate(subgraph.operators):
        builtin = model.operatorCodes[operator.opcodeIndex].builtinCode
        if builtin != schema.BuiltinOperator.FULLY_CONNECTED:
            continue
        input_index, weight_index, bias_index = [int(x) for x in operator.inputs]
        if input_index != int(subgraph.inputs[0]):
            raise ValueError("sensor FC must consume the model input directly")
        weight_tensor = subgraph.tensors[weight_index]
        output_index = int(operator.outputs[0])
        output_tensor = subgraph.tensors[output_index]
        weights = tensor_buffer(model, weight_tensor, np.int8).reshape(
            weight_tensor.shape
        ).astype(np.int64)
        if len(weight_tensor.quantization.scale) != 1:
            raise ValueError("per-channel sensor weights are not supported")

        if bias_index < 0:
            model_bias = np.zeros(weights.shape[0], dtype=np.int64)
        else:
            bias_tensor = subgraph.tensors[bias_index]
            model_bias = tensor_buffer(model, bias_tensor, "<i8").astype(np.int64)
        saturated_bias = np.clip(
            model_bias, np.iinfo(np.int32).min, np.iinfo(np.int32).max
        ).astype(np.int64)
        saturated_bias_count = int(np.count_nonzero(model_bias != saturated_bias))
        total_saturated_biases += saturated_bias_count

        accumulator = quantized_inputs.astype(np.int64) @ weights.T
        accumulator += saturated_bias
        overflow = (accumulator < np.iinfo(np.int32).min) | (
            accumulator > np.iinfo(np.int32).max
        )
        overflow_count = int(np.count_nonzero(overflow))
        total_accumulator_overflows += overflow_count
        wrapped_accumulator = signed_int32_wrap(accumulator)

        real_multiplier = (
            input_scale
            * float(weight_tensor.quantization.scale[0])
            / float(output_tensor.quantization.scale[0])
        )
        multiplier, shift = quantize_multiplier(real_multiplier)
        npu_output = nmsis_requantize_s64(
            wrapped_accumulator, multiplier, shift
        )
        minimum, maximum = activation_range(operator.builtinOptions)
        npu_output = np.clip(npu_output, minimum, maximum).astype(np.int16)
        npu_tensors[output_index] = npu_output

        reference_output = reference_tensors[output_index]
        difference = npu_output.astype(np.int32) - reference_output.astype(np.int32)
        mismatch_count = int(np.count_nonzero(difference))
        max_difference = int(np.max(np.abs(difference), initial=0))
        total_mismatches += mismatch_count
        maximum_difference = max(maximum_difference, max_difference)
        fc_records.append(
            {
                "operator_index": operator_index,
                "input_depth": int(weights.shape[1]),
                "output_depth": int(weights.shape[0]),
                "model_bias_min": int(model_bias.min(initial=0)),
                "model_bias_max": int(model_bias.max(initial=0)),
                "saturated_bias_elements": saturated_bias_count,
                "accumulator_min": int(accumulator.min()),
                "accumulator_max": int(accumulator.max()),
                "accumulator_overflow_elements": overflow_count,
                "npu_vs_tflite_mismatch_elements": mismatch_count,
                "npu_vs_tflite_max_abs_qdiff": max_difference,
            }
        )

    return {
        "operators": fc_records,
        "total_saturated_bias_elements": total_saturated_biases,
        "total_accumulator_overflow_elements": total_accumulator_overflows,
        "total_npu_vs_tflite_mismatch_elements": total_mismatches,
        "npu_vs_tflite_max_abs_qdiff": maximum_difference,
        "all_fc_outputs_bit_exact": total_mismatches == 0,
    }, npu_tensors


def run_final_outputs(
    interpreter: tf.lite.Interpreter,
    quantized_inputs: np.ndarray,
    capture_indices: list[int],
) -> tuple[np.ndarray, list[dict], dict[int, np.ndarray]]:
    input_detail = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()
    output = np.empty((len(quantized_inputs), len(output_details)), dtype=np.int16)
    captured = {
        index: np.empty((len(quantized_inputs), 1), dtype=np.int16)
        for index in capture_indices
    }
    for row, quantized in enumerate(quantized_inputs):
        interpreter.set_tensor(input_detail["index"], quantized[None, :])
        interpreter.invoke()
        for output_index, detail in enumerate(output_details):
            output[row, output_index] = interpreter.get_tensor(
                detail["index"]
            ).reshape(-1)[0]
        for tensor_index in capture_indices:
            captured[tensor_index][row] = interpreter.get_tensor(
                tensor_index
            ).reshape(-1)
    return output, output_details, captured


def run_npu_software_tail(
    model,
    npu_tensors: dict[int, np.ndarray],
    output_details: list[dict],
) -> np.ndarray:
    """Run the non-accelerated ADD tail with TFLM's integer arithmetic."""
    subgraph = model.subgraphs[0]
    for operator in subgraph.operators:
        builtin = model.operatorCodes[operator.opcodeIndex].builtinCode
        if builtin == schema.BuiltinOperator.FULLY_CONNECTED:
            continue
        if builtin != schema.BuiltinOperator.ADD:
            raise ValueError(f"unsupported sensor software-tail operator {builtin}")
        input1_index, input2_index = [int(index) for index in operator.inputs]
        output_index = int(operator.outputs[0])
        input1_tensor = subgraph.tensors[input1_index]
        input2_tensor = subgraph.tensors[input2_index]
        output_tensor = subgraph.tensors[output_index]
        input1 = npu_tensors[input1_index].astype(np.int64)
        input2 = npu_tensors[input2_index].astype(np.int64)
        input1_scale = float(input1_tensor.quantization.scale[0])
        input2_scale = float(input2_tensor.quantization.scale[0])
        output_scale = float(output_tensor.quantization.scale[0])
        twice_max_input_scale = 2.0 * max(input1_scale, input2_scale)
        input1_multiplier, input1_shift = quantize_multiplier(
            input1_scale / twice_max_input_scale
        )
        input2_multiplier, input2_shift = quantize_multiplier(
            input2_scale / twice_max_input_scale
        )
        output_multiplier, output_shift = quantize_multiplier(
            twice_max_input_scale / ((1 << 15) * output_scale)
        )
        shifted_input1 = (
            input1 - int(input1_tensor.quantization.zeroPoint[0])
        ) * (1 << 15)
        shifted_input2 = (
            input2 - int(input2_tensor.quantization.zeroPoint[0])
        ) * (1 << 15)
        scaled_input1 = multiply_by_quantized_multiplier(
            shifted_input1, input1_multiplier, input1_shift
        )
        scaled_input2 = multiply_by_quantized_multiplier(
            shifted_input2, input2_multiplier, input2_shift
        )
        raw_sum = scaled_input1 + scaled_input2
        result = multiply_by_quantized_multiplier(
            raw_sum, output_multiplier, output_shift
        ) + int(output_tensor.quantization.zeroPoint[0])
        minimum, maximum = activation_range(operator.builtinOptions)
        npu_tensors[output_index] = np.clip(result, minimum, maximum).astype(
            np.int16
        )

    final_outputs = np.empty(
        (len(next(iter(npu_tensors.values()))), len(output_details)), dtype=np.int16
    )
    for column, detail in enumerate(output_details):
        final_outputs[:, column] = npu_tensors[int(detail["index"])].reshape(-1)
    return final_outputs


def error_metrics(
    reference: np.ndarray, calibrated: np.ndarray, limit: float
) -> dict[str, float | bool]:
    error = calibrated - reference
    absolute = np.abs(error)
    return {
        "mae": float(absolute.mean()),
        "rmse": float(np.sqrt(np.square(error).mean())),
        "max_abs_error": float(absolute.max()),
        "within_limit_fraction": float((absolute <= limit).mean()),
        "limit": limit,
        "passes_all_samples": bool(np.all(absolute <= limit)),
    }


def physical_metrics(
    quantized_outputs: np.ndarray,
    output_details: list[dict],
    output_order: list[str],
    metadata: dict,
    values: dict[str, np.ndarray],
    holdout_indices: np.ndarray,
) -> dict:
    normalized_by_name = {}
    for column, (detail, name) in enumerate(zip(output_details, output_order)):
        scale, zero_point = detail["quantization"]
        normalized_by_name[name] = (
            quantized_outputs[:, column].astype(np.float64) - zero_point
        ) * scale
    semantic_names = (
        "voltage_offset_v",
        "current_offset_a",
        "humidity_offset_rh",
    )
    normalized = np.column_stack([normalized_by_name[name] for name in semantic_names])
    offsets = normalized * np.asarray(metadata["offset_scale"]) + np.asarray(
        metadata["offset_mean"]
    )
    raw = np.column_stack(
        (
            values[VOLTAGE_INPUT],
            values[CURRENT_INPUT],
            values[HUMIDITY_INPUT],
        )
    )[holdout_indices]
    references = np.column_stack(
        (
            values[VOLTAGE_REFERENCE],
            values[CURRENT_REFERENCE],
            values[HUMIDITY_REFERENCE],
        )
    )[holdout_indices]
    calibrated = raw + offsets
    return {
        "voltage": error_metrics(references[:, 0], calibrated[:, 0], VOLTAGE_LIMIT_V),
        "current": error_metrics(references[:, 1], calibrated[:, 1], CURRENT_LIMIT_A),
        "humidity": error_metrics(
            references[:, 2], calibrated[:, 2], HUMIDITY_LIMIT_RH
        ),
    }


def format_c_values(values: np.ndarray, indent: str = "    ") -> str:
    flat = [str(int(value)) for value in values.reshape(-1)]
    return "\n".join(
        indent + ", ".join(flat[offset : offset + 12]) + ","
        for offset in range(0, len(flat), 12)
    )


def write_model_data(output_dir: Path, content: bytes) -> None:
    header = output_dir / "sensor_calibration_model_data.h"
    source = output_dir / "sensor_calibration_model_data.cc"
    header.write_text(
        "#ifndef SENSOR_CALIBRATION_MODEL_DATA_H_\n"
        "#define SENSOR_CALIBRATION_MODEL_DATA_H_\n\n"
        "extern const unsigned char g_sensor_calibration_model_data[];\n"
        "extern const int g_sensor_calibration_model_data_len;\n\n"
        "#endif  // SENSOR_CALIBRATION_MODEL_DATA_H_\n",
        encoding="utf-8",
    )
    lines = [
        '#include "sensor_calibration/sensor_calibration_model_data.h"',
        "",
        "alignas(16) const unsigned char g_sensor_calibration_model_data[] = {",
    ]
    for offset in range(0, len(content), 12):
        lines.append(
            "  " + ", ".join(f"0x{value:02x}" for value in content[offset : offset + 12]) + ","
        )
    lines.extend(
        [
            "};",
            "",
            f"const int g_sensor_calibration_model_data_len = {len(content)};",
            "",
        ]
    )
    source.write_text("\n".join(lines), encoding="utf-8")


def write_test_data(
    output_dir: Path,
    inputs: np.ndarray,
    outputs: np.ndarray,
    source_rows: np.ndarray,
    fc_tensor_indices: list[int],
    fc_outputs: np.ndarray,
) -> None:
    sample_count, input_size = inputs.shape
    output_count = outputs.shape[1]
    fc_count = len(fc_tensor_indices)
    header = output_dir / "sensor_calibration_test_data.h"
    source = output_dir / "sensor_calibration_test_data.cc"
    header.write_text(
        "#ifndef SENSOR_CALIBRATION_TEST_DATA_H_\n"
        "#define SENSOR_CALIBRATION_TEST_DATA_H_\n\n"
        "#include <cstdint>\n\n"
        f"constexpr int kSensorCalibrationSampleCount = {sample_count};\n"
        f"constexpr int kSensorCalibrationInputSize = {input_size};\n"
        f"constexpr int kSensorCalibrationOutputCount = {output_count};\n\n"
        f"constexpr int kSensorCalibrationFcCount = {fc_count};\n\n"
        "extern const int16_t g_sensor_calibration_test_inputs\n"
        "    [kSensorCalibrationSampleCount][kSensorCalibrationInputSize];\n"
        "extern const int16_t g_sensor_calibration_golden_outputs\n"
        "    [kSensorCalibrationSampleCount][kSensorCalibrationOutputCount];\n"
        "extern const uint32_t\n"
        "    g_sensor_calibration_source_rows[kSensorCalibrationSampleCount];\n\n"
        "extern const int32_t\n"
        "    g_sensor_calibration_fc_tensor_indices[kSensorCalibrationFcCount];\n"
        "extern const int16_t g_sensor_calibration_fc_golden_outputs\n"
        "    [kSensorCalibrationSampleCount][kSensorCalibrationFcCount];\n\n"
        "#endif  // SENSOR_CALIBRATION_TEST_DATA_H_\n",
        encoding="utf-8",
    )
    lines = [
        '#include "sensor_calibration/sensor_calibration_test_data.h"',
        "",
        "const int16_t g_sensor_calibration_test_inputs",
        "    [kSensorCalibrationSampleCount][kSensorCalibrationInputSize] = {",
    ]
    for row in inputs:
        lines.append("  {")
        lines.append(format_c_values(row, "    "))
        lines.append("  },")
    lines.extend(
        [
            "};",
            "",
            "const int16_t g_sensor_calibration_golden_outputs",
            "    [kSensorCalibrationSampleCount][kSensorCalibrationOutputCount] = {",
        ]
    )
    for row in outputs:
        lines.append("  {" + ", ".join(str(int(value)) for value in row) + "},")
    lines.extend(
        [
            "};",
            "",
            "const uint32_t g_sensor_calibration_source_rows",
            "    [kSensorCalibrationSampleCount] = {",
            format_c_values(source_rows, "  "),
            "};",
            "",
            "const int32_t g_sensor_calibration_fc_tensor_indices",
            "    [kSensorCalibrationFcCount] = {",
            format_c_values(np.asarray(fc_tensor_indices), "  "),
            "};",
            "",
            "const int16_t g_sensor_calibration_fc_golden_outputs",
            "    [kSensorCalibrationSampleCount][kSensorCalibrationFcCount] = {",
        ]
    )
    for row in fc_outputs:
        lines.append("  {" + ", ".join(str(int(value)) for value in row) + "},")
    lines.extend(["};", ""])
    source.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    args = parse_args()
    if args.model_dir is None:
        model_candidates = list(
            args.source_root.glob(f"calibration_model_*/{MODEL_FILENAME}")
        )
        if not model_candidates:
            raise FileNotFoundError(
                f"no {MODEL_FILENAME} found below {args.source_root}"
            )
        source_model = max(
            model_candidates, key=lambda path: path.stat().st_mtime_ns
        )
        source_model_dir = source_model.parent
    else:
        source_model_dir = args.source_root / args.model_dir
        source_model = source_model_dir / MODEL_FILENAME
    source_metadata = source_model_dir / "metadata.json"
    source_sidecar = source_model_dir / "tflite_int16_metadata.json"
    for path in (source_model, source_metadata, source_sidecar):
        if not path.is_file():
            raise FileNotFoundError(path)

    metadata = json.loads(source_metadata.read_text(encoding="utf-8"))
    sidecar = json.loads(source_sidecar.read_text(encoding="utf-8"))
    source_csv = args.csv or Path(sidecar["input_csv"])
    if not source_csv.is_absolute():
        source_csv = args.source_root / source_csv
    if not source_csv.is_file():
        raise FileNotFoundError(source_csv)
    model_content = source_model.read_bytes()
    model = model_from_bytes(model_content)
    values, source_rows = read_values(source_csv)
    features = make_features(values, metadata)
    eligible = np.flatnonzero(accepted_mask(values))
    seed = int(metadata.get("random_seed", 42))
    shuffled = np.random.default_rng(seed).permutation(eligible)
    holdout_count = max(1, round(0.15 * len(shuffled)))
    holdout_indices = shuffled[:holdout_count]
    if args.limit > 0:
        holdout_indices = holdout_indices[: args.limit]

    interpreter = tf.lite.Interpreter(
        model_content=model_content, experimental_preserve_all_tensors=True
    )
    interpreter.allocate_tensors()
    input_detail = interpreter.get_input_details()[0]
    input_scale, input_zero_point = input_detail["quantization"]
    if input_detail["dtype"] != np.dtype(np.int16):
        raise ValueError(f"expected INT16 input, got {input_detail['dtype']}")
    quantized_inputs = np.round(
        features[holdout_indices] / input_scale + input_zero_point
    ).clip(-32768, 32767).astype(np.int16)

    fc_output_indices = [
        int(operator.outputs[0])
        for operator in model.subgraphs[0].operators
        if model.operatorCodes[operator.opcodeIndex].builtinCode
        == schema.BuiltinOperator.FULLY_CONNECTED
    ]
    final_outputs, output_details, reference_tensors = run_final_outputs(
        interpreter, quantized_inputs, fc_output_indices
    )
    fc_contract, npu_tensors = evaluate_fc_contract(
        model, quantized_inputs, reference_tensors
    )
    npu_outputs = run_npu_software_tail(model, npu_tensors, output_details)
    tflite_metrics = physical_metrics(
        final_outputs,
        output_details,
        sidecar["output_order_in_interpreter"],
        metadata,
        values,
        holdout_indices,
    )
    npu_metrics = physical_metrics(
        npu_outputs,
        output_details,
        sidecar["output_order_in_interpreter"],
        metadata,
        values,
        holdout_indices,
    )
    final_difference = npu_outputs.astype(np.int32) - final_outputs.astype(np.int32)
    final_mismatch_count = int(np.count_nonzero(final_difference))
    final_max_difference = int(np.max(np.abs(final_difference), initial=0))
    metric_delta = {
        f"{channel}_{metric}": float(npu_metrics[channel][metric])
        - float(tflite_metrics[channel][metric])
        for channel in ("voltage", "current", "humidity")
        for metric in ("mae", "rmse", "max_abs_error")
    }

    builtin_names = {
        schema.BuiltinOperator.FULLY_CONNECTED: "FULLY_CONNECTED",
        schema.BuiltinOperator.ADD: "ADD",
    }
    operator_histogram: dict[str, int] = {}
    for operator in model.subgraphs[0].operators:
        code = model.operatorCodes[operator.opcodeIndex].builtinCode
        name = builtin_names.get(code, str(code))
        operator_histogram[name] = operator_histogram.get(name, 0) + 1

    soc_sample_count = min(args.soc_samples, len(holdout_indices))
    summary = {
        "source_model": str(source_model),
        "model_sha256": hashlib.sha256(model_content).hexdigest(),
        "model_bytes": len(model_content),
        "input_elements": int(quantized_inputs.shape[1]),
        "output_order": sidecar["output_order_in_interpreter"],
        "operator_histogram": operator_histogram,
        "eligible_samples": int(len(eligible)),
        "holdout_samples": int(len(holdout_indices)),
        "soc_test_vectors": {
            "source_rows": source_rows[
                holdout_indices[:soc_sample_count]
            ].astype(int).tolist(),
            "tflite_outputs": final_outputs[:soc_sample_count].astype(int).tolist(),
            "npu_outputs": npu_outputs[:soc_sample_count].astype(int).tolist(),
        },
        "tflite_int16_holdout_metrics": tflite_metrics,
        "npu_int16_holdout_metrics": npu_metrics,
        "npu_fc_contract": fc_contract,
        "npu_vs_tflite": {
            "final_output_mismatch_elements": final_mismatch_count,
            "final_output_max_abs_qdiff": final_max_difference,
            "final_outputs_bit_exact": final_mismatch_count == 0,
            "accuracy_metric_delta": metric_delta,
            "reason": (
                "The NPU uses the NMSIS reduced-Q15 requantizer for every "
                "INT16x8 FC; the regular TFLite kernel uses full-Q31 "
                "requantization for biasless FC nodes. ADD remains on the "
                "same TFLM software kernel."
            ),
        },
    }

    args.output_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_model, args.output_dir / MODEL_FILENAME)
    shutil.copy2(source_metadata, args.output_dir / "metadata.json")
    shutil.copy2(source_sidecar, args.output_dir / "tflite_int16_metadata.json")
    write_model_data(args.output_dir, model_content)
    write_test_data(
        args.output_dir,
        quantized_inputs[:soc_sample_count],
        npu_outputs[:soc_sample_count],
        source_rows[holdout_indices[:soc_sample_count]],
        fc_output_indices,
        np.column_stack(
            [npu_tensors[index].reshape(-1) for index in fc_output_indices]
        )[:soc_sample_count],
    )
    (args.output_dir / "regression_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
