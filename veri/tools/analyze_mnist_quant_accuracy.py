#!/usr/bin/env python3
"""Compare INT8 and INT16x8 TFLM MNIST model accuracy."""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
from pathlib import Path

import numpy as np


def run_model(
    runner: Path,
    model: Path,
    images: Path,
    labels: Path,
    count: int,
    dump: Path,
) -> dict:
    result = subprocess.run(
        [str(runner), str(model), str(images), str(labels), str(count), str(dump)],
        check=True,
        text=True,
        capture_output=True,
    )
    return json.loads(result.stdout.strip().splitlines()[-1])


def read_predictions(path: Path) -> tuple[list[int], list[int]]:
    labels: list[int] = []
    predictions: list[int] = []
    with path.open(newline="") as stream:
        for row in csv.reader(stream):
            labels.append(int(row[1]))
            predictions.append(int(row[2]))
    return labels, predictions


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runner", type=Path, required=True)
    parser.add_argument("--model_dir", type=Path, required=True)
    parser.add_argument(
        "--dataset", type=Path, default=Path.home() / ".keras/datasets/mnist.npz"
    )
    parser.add_argument("--count", type=int, default=10000)
    parser.add_argument("--out_dir", type=Path, required=True)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    with np.load(args.dataset) as dataset:
        images = dataset["x_test"].astype(np.uint8).reshape(-1, 784)
        labels = dataset["y_test"].astype(np.uint8)
    count = min(args.count, len(labels))
    image_path = args.out_dir / "images_u8.bin"
    label_path = args.out_dir / "labels_u8.bin"
    image_path.write_bytes(images[:count].tobytes())
    label_path.write_bytes(labels[:count].tobytes())

    int8_dump = args.out_dir / "int8_outputs.csv"
    int16_dump = args.out_dir / "int16x8_outputs.csv"
    int8_result = run_model(
        args.runner,
        args.model_dir / "mnist_mlp_int8.tflite",
        image_path,
        label_path,
        count,
        int8_dump,
    )
    int16_result = run_model(
        args.runner,
        args.model_dir / "mnist_mlp_int16x8.tflite",
        image_path,
        label_path,
        count,
        int16_dump,
    )

    labels_ref, int8_predictions = read_predictions(int8_dump)
    _, int16_predictions = read_predictions(int16_dump)
    changed = [
        index
        for index, pair in enumerate(zip(int8_predictions, int16_predictions))
        if pair[0] != pair[1]
    ]
    int8_only = sum(
        int8_predictions[index] == labels_ref[index]
        and int16_predictions[index] != labels_ref[index]
        for index in changed
    )
    int16_only = sum(
        int16_predictions[index] == labels_ref[index]
        and int8_predictions[index] != labels_ref[index]
        for index in changed
    )
    summary = {
        "samples": count,
        "int8": int8_result,
        "int16x8": int16_result,
        "accuracy_delta": int16_result["accuracy"] - int8_result["accuracy"],
        "prediction_changes": len(changed),
        "int8_only_correct": int8_only,
        "int16x8_only_correct": int16_only,
        "net_correct_delta": int16_only - int8_only,
        "first_changed_indices": changed[:20],
    }
    (args.out_dir / "summary.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
