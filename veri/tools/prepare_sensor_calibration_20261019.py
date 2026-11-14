#!/usr/bin/env python3
"""Generate deterministic TFLM/DSA SoC vectors for the 20261019 release."""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf


RELEASE = Path(
    "/home/yusen/公共的/sensor_calibration_data/"
    "calibration_release_20261019_complete_voltage_current_humidity_int16"
)
ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "veri/soc_csrc/tflm_sensor_calibration_20261019_golden_data.cc"


def load_inference_module():
    path = RELEASE / "infer_complete_sensor_calibration.py"
    spec = importlib.util.spec_from_file_location("sensor_calibration_20261019", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load inference contract from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def float_literal(value: float) -> str:
    literal = f"{float(value):.9g}"
    if "." not in literal and "e" not in literal.lower():
        literal += ".0"
    return literal + "f"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=Path, default=RELEASE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--samples", type=int, default=8)
    args = parser.parse_args()
    if args.samples < 1:
        raise ValueError("--samples must be positive")

    release = args.release.resolve()
    contract = load_inference_module()
    model = release / "sensor_calibrator_complete_int16.tflite"
    csv_path = release / "data/calibration_20261018.csv"
    frame = pd.read_csv(csv_path, low_memory=False)
    raw_rows: list[np.ndarray] = []
    chosen_indices = np.linspace(0, len(frame) - 1, args.samples * 4, dtype=np.int64)
    for index in chosen_indices:
        try:
            raw_rows.append(contract.preprocess_sample(frame.iloc[int(index)].to_dict()))
        except (ValueError, KeyError):
            continue
        if len(raw_rows) == args.samples:
            break
    if len(raw_rows) != args.samples:
        raise RuntimeError(f"found only {len(raw_rows)} valid rows for {args.samples} samples")

    interpreter = tf.lite.Interpreter(model_path=str(model), num_threads=1)
    interpreter.allocate_tensors()
    details = interpreter.get_input_details()
    input_by_width = {int(item["shape"][-1]): item for item in details}
    if set(input_by_width) != {2, 3, 5}:
        raise RuntimeError(f"unexpected input widths: {sorted(input_by_width)}")
    output_details = interpreter.get_output_details()
    output_index = {
        "humidity": next(d["index"] for d in output_details if d["name"].endswith(":0")),
        "voltage": next(d["index"] for d in output_details if d["name"].endswith(":1")),
        "current": next(d["index"] for d in output_details if d["name"].endswith(":2")),
    }
    cases: list[tuple[np.ndarray, tuple[int, int, int]]] = []
    for raw in raw_rows:
        features = {
            5: np.asarray(
                [(raw[0] - 40.0) / 40.0, (raw[1] - 60.0) / 50.0,
                 raw[5] / 40.0, raw[13] / 7.0, (raw[14] - 40.0) / 40.0],
                dtype=np.float32,
            ),
            3: raw[[0, 1, 7]].astype(np.float32),
            2: raw[[0, 1]].astype(np.float32),
        }
        for width, detail in input_by_width.items():
            scale, zero = detail["quantization"]
            q = np.clip(np.rint(features[width] / scale + zero), -32768, 32767)
            interpreter.set_tensor(detail["index"], q.astype(np.int16)[None, :])
        interpreter.invoke()
        golden = tuple(
            int(interpreter.get_tensor(output_index[name]).reshape(-1)[0])
            for name in ("humidity", "voltage", "current")
        )
        cases.append((raw, golden))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as stream:
        stream.write('#include "tflm_sensor_calibration_20261019_golden_data.h"\n\n')
        stream.write("const SensorCalibration20261019Case "
                     f"g_sensor_calibration_20261019_cases[{len(cases)}] = {{\n")
        for raw, expected in cases:
            values = ", ".join(float_literal(value) for value in raw)
            stream.write(f"    {{{{{values}}}, {{{expected[0]}, {expected[1]}, {expected[2]}}}}},\n")
        stream.write("};\n")
        stream.write(f"const unsigned int g_sensor_calibration_20261019_case_count = {len(cases)};\n")
    print(f"wrote {len(cases)} cases to {args.output}")


if __name__ == "__main__":
    main()
