#!/usr/bin/env python3
"""Train and export a fully-quantized MNIST CNN for TFLM SoC tests."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

os.environ.setdefault("CUDA_VISIBLE_DEVICES", "")
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "1")

import numpy as np
import tensorflow as tf


def c_array_u8(name: str, data: bytes, cols: int = 12) -> str:
    values = list(data)
    lines = [f"alignas(16) const unsigned char {name}[] = {{"]
    for i in range(0, len(values), cols):
        chunk = ", ".join(f"0x{v:02x}" for v in values[i : i + cols])
        suffix = "," if i + cols < len(values) else ""
        lines.append(f"  {chunk}{suffix}")
    lines.append("};")
    return "\n".join(lines)


def c_array_i8(name: str, data: np.ndarray, shape: str, cols: int = 16) -> str:
    flat = data.astype(np.int8).reshape(-1)
    lines = [f"alignas(16) const int8_t {name}{shape} = {{"]
    for i in range(0, flat.size, cols):
        chunk = ", ".join(str(int(v)) for v in flat[i : i + cols])
        suffix = "," if i + cols < flat.size else ""
        lines.append(f"  {chunk}{suffix}")
    lines.append("};")
    return "\n".join(lines)


def c_array_i32(name: str, data: np.ndarray, shape: str, cols: int = 12) -> str:
    flat = data.astype(np.int32).reshape(-1)
    lines = [f"const int32_t {name}{shape} = {{"]
    for i in range(0, flat.size, cols):
        chunk = ", ".join(str(int(v)) for v in flat[i : i + cols])
        suffix = "," if i + cols < flat.size else ""
        lines.append(f"  {chunk}{suffix}")
    lines.append("};")
    return "\n".join(lines)


def build_model(conv_channels: tuple[int, int], dense_units: int) -> tf.keras.Model:
    inputs = tf.keras.Input(shape=(28, 28, 1), name="mnist_image")
    x = tf.keras.layers.Conv2D(
        conv_channels[0], kernel_size=3, padding="same", activation="relu", name="conv1"
    )(inputs)
    x = tf.keras.layers.MaxPooling2D(pool_size=2, name="pool1")(x)
    x = tf.keras.layers.Conv2D(
        conv_channels[1], kernel_size=3, padding="same", activation="relu", name="conv2"
    )(x)
    x = tf.keras.layers.MaxPooling2D(pool_size=2, name="pool2")(x)
    x = tf.keras.layers.Flatten(name="flatten")(x)
    x = tf.keras.layers.Dense(dense_units, activation="relu", name="fc1")(x)
    outputs = tf.keras.layers.Dense(10, activation="softmax", name="predictions")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="mnist_cnn")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def estimate_macs(conv_channels: tuple[int, int], dense_units: int) -> int:
    conv1 = 28 * 28 * conv_channels[0] * 3 * 3 * 1
    conv2 = 14 * 14 * conv_channels[1] * 3 * 3 * conv_channels[0]
    fc1 = 7 * 7 * conv_channels[1] * dense_units
    fc2 = dense_units * 10
    return conv1 + conv2 + fc1 + fc2


def representative_dataset(x_train: np.ndarray, count: int):
    for i in range(min(count, x_train.shape[0])):
        yield [x_train[i : i + 1]]


def quantize_inputs(x_float: np.ndarray, scale: float, zero_point: int) -> np.ndarray:
    quantized = np.round(x_float / scale + zero_point)
    return np.clip(quantized, -128, 127).astype(np.int8)


def select_samples(
    tflite_model: bytes,
    x_test: np.ndarray,
    y_test: np.ndarray,
    sample_count: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, dict]:
    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    interpreter.allocate_tensors()
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    if input_detail["dtype"] != np.int8 or output_detail["dtype"] != np.int8:
        raise RuntimeError(
            f"expected int8 input/output, got {input_detail['dtype']} / {output_detail['dtype']}"
        )

    input_scale, input_zero_point = input_detail["quantization"]
    if input_scale == 0:
        raise RuntimeError("input scale is zero")

    selected_images: list[np.ndarray] = []
    selected_labels: list[int] = []
    selected_indices: list[int] = []
    counts = {digit: 0 for digit in range(10)}

    for idx in range(x_test.shape[0]):
        label = int(y_test[idx])
        image_q = quantize_inputs(x_test[idx : idx + 1], input_scale, input_zero_point)
        interpreter.set_tensor(input_detail["index"], image_q)
        interpreter.invoke()
        output = interpreter.get_tensor(output_detail["index"])[0]
        pred = int(np.argmax(output))
        if pred != label:
            continue
        selected_images.append(image_q.reshape(28 * 28))
        selected_labels.append(label)
        selected_indices.append(idx)
        counts[label] += 1
        if len(selected_labels) == sample_count:
            break

    if len(selected_labels) != sample_count:
        raise RuntimeError(f"only selected {len(selected_labels)} correct samples, need {sample_count}")

    meta = {
        "input_scale": float(input_scale),
        "input_zero_point": int(input_zero_point),
        "output_scale": float(output_detail["quantization"][0]),
        "output_zero_point": int(output_detail["quantization"][1]),
        "selected_counts": counts,
    }
    return (
        np.stack(selected_images).astype(np.int8),
        np.asarray(selected_labels, dtype=np.int8),
        np.asarray(selected_indices, dtype=np.int32),
        meta,
    )


def write_outputs(
    out_dir: Path,
    tflite_model: bytes,
    images: np.ndarray,
    labels: np.ndarray,
    indices: np.ndarray,
    metadata: dict,
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "mnist_cnn_int8.tflite").write_bytes(tflite_model)

    (out_dir / "mnist_cnn_model_data.h").write_text(
        """#ifndef MNIST_CNN_MODEL_DATA_H_
#define MNIST_CNN_MODEL_DATA_H_

extern const unsigned char g_mnist_cnn_model_data[];
extern const int g_mnist_cnn_model_data_len;

#endif  // MNIST_CNN_MODEL_DATA_H_
""",
        encoding="utf-8",
    )
    (out_dir / "mnist_cnn_model_data.cc").write_text(
        '#include "mnist_cnn/mnist_cnn_model_data.h"\n\n'
        + c_array_u8("g_mnist_cnn_model_data", tflite_model)
        + f"\n\nconst int g_mnist_cnn_model_data_len = {len(tflite_model)};\n",
        encoding="utf-8",
    )

    sample_count, input_size = images.shape
    (out_dir / "mnist_cnn_test_data.h").write_text(
        f"""#ifndef MNIST_CNN_TEST_DATA_H_
#define MNIST_CNN_TEST_DATA_H_

#include <cstdint>

constexpr int kMnistCnnInputSize = {input_size};
constexpr int kMnistCnnClassCount = 10;
constexpr int kMnistCnnSampleCount = {sample_count};

extern const int8_t g_mnist_cnn_test_images[kMnistCnnSampleCount][kMnistCnnInputSize];
extern const int8_t g_mnist_cnn_test_labels[kMnistCnnSampleCount];
extern const int32_t g_mnist_cnn_test_indices[kMnistCnnSampleCount];

#endif  // MNIST_CNN_TEST_DATA_H_
""",
        encoding="utf-8",
    )
    (out_dir / "mnist_cnn_test_data.cc").write_text(
        '#include "mnist_cnn/mnist_cnn_test_data.h"\n\n'
        + c_array_i8(
            "g_mnist_cnn_test_images",
            images,
            "[kMnistCnnSampleCount][kMnistCnnInputSize]",
        )
        + "\n\n"
        + c_array_i8("g_mnist_cnn_test_labels", labels, "[kMnistCnnSampleCount]")
        + "\n\n"
        + c_array_i32("g_mnist_cnn_test_indices", indices, "[kMnistCnnSampleCount]")
        + "\n",
        encoding="utf-8",
    )

    (out_dir / "metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True), encoding="utf-8"
    )


def parse_channels(text: str) -> tuple[int, int]:
    values = [int(item) for item in text.replace(",", " ").split()]
    if len(values) != 2 or any(value <= 0 for value in values):
        raise argparse.ArgumentTypeError("conv_channels must contain two positive integers")
    return values[0], values[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out_dir", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--seed", type=int, default=20260701)
    parser.add_argument("--train_samples", type=int, default=30000)
    parser.add_argument("--epochs", type=int, default=4)
    parser.add_argument("--batch_size", type=int, default=128)
    parser.add_argument("--conv_channels", type=parse_channels, default=parse_channels("8,16"))
    parser.add_argument("--dense_units", type=int, default=64)
    parser.add_argument("--representative_samples", type=int, default=1024)
    parser.add_argument("--sample_count", type=int, default=3)
    args = parser.parse_args()

    np.random.seed(args.seed)
    tf.random.set_seed(args.seed)

    (x_train, y_train), (x_test, y_test) = tf.keras.datasets.mnist.load_data()
    x_train = x_train[..., np.newaxis].astype(np.float32) / 255.0
    x_test = x_test[..., np.newaxis].astype(np.float32) / 255.0

    train_samples = min(args.train_samples, x_train.shape[0])
    model = build_model(args.conv_channels, args.dense_units)
    model.fit(
        x_train[:train_samples],
        y_train[:train_samples],
        epochs=args.epochs,
        batch_size=args.batch_size,
        validation_split=0.1,
        verbose=2,
    )
    float_loss, float_acc = model.evaluate(x_test, y_test, verbose=0)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = lambda: representative_dataset(
        x_train, args.representative_samples
    )
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.int8
    converter.inference_output_type = tf.int8
    tflite_model = converter.convert()

    images, labels, indices, quant_meta = select_samples(
        tflite_model, x_test, y_test, args.sample_count
    )
    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    op_names = [op["op_name"] for op in interpreter._get_ops_details()]
    macs = estimate_macs(args.conv_channels, args.dense_units)
    metadata = {
        "seed": args.seed,
        "train_samples": train_samples,
        "epochs": args.epochs,
        "batch_size": args.batch_size,
        "conv_channels": list(args.conv_channels),
        "dense_units": args.dense_units,
        "macs_per_sample": macs,
        "int8_ops_per_sample": 2 * macs,
        "float_test_loss": float(float_loss),
        "float_test_accuracy": float(float_acc),
        "tflite_bytes": len(tflite_model),
        "ops": op_names,
        "selected_labels": labels.astype(int).tolist(),
        "selected_test_indices": indices.astype(int).tolist(),
    }
    metadata.update(quant_meta)
    write_outputs(args.out_dir, tflite_model, images, labels, indices, metadata)
    print(json.dumps(metadata, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
