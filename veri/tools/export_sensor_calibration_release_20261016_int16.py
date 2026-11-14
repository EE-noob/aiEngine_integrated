#!/usr/bin/env python3
"""Export and quantify the 2026-10-16 float release as TFLite int16x8."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
os.environ.setdefault("TF_NUM_INTRAOP_THREADS", "2")
os.environ.setdefault("TF_NUM_INTEROP_THREADS", "2")

import numpy as np
import pandas as pd
import tensorflow as tf
import keras


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--representative-count", type=int, default=1024)
    parser.add_argument("--evaluation-count", type=int, default=256)
    parser.add_argument("--fixed-pga-code", type=int, choices=range(8),
                        help="Specialize the V4 branch to one PGA code")
    args = parser.parse_args()
    if args.output.exists():
        parser.error(f"Refusing to overwrite existing file: {args.output}")
    if args.representative_count < 8 or args.evaluation_count < 1:
        parser.error("Invalid representative/evaluation sample count")

    release = args.release_dir.resolve()
    scripts = release / "training" / "scripts"
    sys.path.insert(0, str(scripts))
    # Register the custom Keras feature layers used by the release model.
    import train_voltage_specialist_branch  # noqa: F401,E402
    import train_voltage_shared_monotonic  # noqa: F401,E402
    import train_voltage_dual_temperature  # noqa: F401,E402
    import train_voltage_compact_residual  # noqa: F401,E402
    from sensor_inputs import physical_rows  # noqa: E402

    metadata = json.loads((release / "models" / "metadata.json").read_text(encoding="utf-8"))
    if len(metadata["input_names"]) != 15 or len(metadata["output_names"]) != 9:
        raise ValueError("Unexpected model interface in release metadata")

    model_path = release / "models" / "sensor_calibrator.keras"
    model = keras.models.load_model(model_path, compile=False)
    if tuple(model.input_shape[1:]) != (15,) or tuple(model.output_shape[1:]) != (9,):
        raise ValueError(f"Unexpected Keras shape {model.input_shape} -> {model.output_shape}")

    csv_paths = sorted((release / "data").glob("*.csv"))
    candidates = []
    for csv_path in csv_paths:
        if csv_path.name == "数据集说明.csv":
            continue
        frame = pd.read_csv(csv_path, low_memory=False)
        current = 1 if csv_path.name.startswith("train_02") else 2
        rows = physical_rows(frame, source_name=csv_path.name, active_voltage=4,
                             active_current=current,
                             include_gxht45_temperature=True).astype(np.float32)
        if len(rows):
            candidates.append(rows)
    if not candidates:
        raise ValueError("Release package contains no representative sensor rows")
    candidates = np.concatenate(candidates, axis=0)

    model_for_export = model
    if args.fixed_pga_code is not None:
        inputs = keras.Input((15,), name="sensor_inputs_fixed_v4_pga")
        voltage_input = model.get_layer("voltage4_input_selector")(inputs)
        fixed_code = keras.layers.Rescaling(
            scale=0.0, offset=float(args.fixed_pga_code), name="fixed_v4_pga_code"
        )(voltage_input[:, 3:4])
        voltage_input = keras.layers.Concatenate(name="voltage4_inputs_fixed_pga")(
            [voltage_input[:, :3], fixed_code, voltage_input[:, 4:5]])
        outputs = [None] * 9
        outputs[0] = model.get_layer("humidity_independent_branch")(
            model.get_layer("humidity_input_selector")(inputs))
        for index in (1, 2, 3, 7, 8):
            outputs[index] = model.get_layer(f"unsupported_output_{index}")(inputs)
        outputs[4] = model.get_layer("voltage4_dual_temperature_independent_branch")(
            voltage_input)
        outputs[5] = model.get_layer("current1_independent_branch")(
            model.get_layer("current1_input_selector")(inputs))
        outputs[6] = model.get_layer("current2_independent_branch")(
            model.get_layer("current2_input_selector")(inputs))
        model_for_export = keras.Model(
            inputs, keras.layers.Concatenate(name="calibrated_readings_fixed_pga")(outputs),
            name=f"sensor_calibrator_fixed_v4_pga{args.fixed_pga_code}")

    # Keep all V4 gain codes represented, then fill from a deterministic sample
    # of the release's actual, reference-free sensor inputs.
    rng = np.random.default_rng(20261016)
    code_values = np.rint(candidates[:, 13]).astype(np.int32)
    selected: list[int] = []
    per_code = max(1, args.representative_count // 16)
    for code in range(8):
        indices = np.flatnonzero(code_values == code)
        take = min(per_code, len(indices))
        if take:
            selected.extend(rng.choice(indices, size=take, replace=False).tolist())
    selected = sorted(set(selected))
    remaining = np.setdiff1d(np.arange(len(candidates)), np.asarray(selected, dtype=np.int64),
                              assume_unique=True)
    fill_count = min(args.representative_count - len(selected), len(remaining))
    if fill_count:
        selected.extend(rng.choice(remaining, size=fill_count, replace=False).tolist())
    rep = candidates[np.asarray(sorted(selected), dtype=np.int64)]
    if args.fixed_pga_code is not None:
        rep[:, 13] = args.fixed_pga_code
    if len(rep) < 8:
        raise ValueError("Not enough representative rows")

    converter = tf.lite.TFLiteConverter.from_keras_model(model_for_export)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = lambda: ([row[None, :]] for row in rep)
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.EXPERIMENTAL_TFLITE_BUILTINS_ACTIVATIONS_INT16_WEIGHTS_INT8
    ]
    converter.inference_input_type = tf.int16
    converter.inference_output_type = tf.int16
    model_bytes = converter.convert()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(model_bytes)
    interpreter = tf.lite.Interpreter(model_path=str(args.output), num_threads=2)
    interpreter.allocate_tensors()
    input_detail = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()
    if input_detail["dtype"] != np.int16 or any(d["dtype"] != np.int16 for d in output_details):
        raise RuntimeError("TFLite converter did not produce int16 model input/output")
    if len(output_details) != 1 or tuple(output_details[0]["shape"][-1:]) != (9,):
        raise RuntimeError(f"Unexpected TFLite output tensors: {output_details}")

    eval_rows = candidates[np.linspace(0, len(candidates) - 1,
                                       num=min(args.evaluation_count, len(candidates)),
                                       dtype=np.int64)]
    if args.fixed_pga_code is not None:
        eval_rows[:, 13] = args.fixed_pga_code
    scale, zero = input_detail["quantization"]
    output_detail = output_details[0]
    output_scale, output_zero = output_detail["quantization"]
    keras_values = np.asarray(model_for_export(eval_rows, training=False), dtype=np.float32)
    specialization_delta = np.asarray(model(eval_rows, training=False), dtype=np.float32) - keras_values
    tflite_values = []
    for row in eval_rows:
        quantized = np.clip(np.rint(row / scale + zero), -32768, 32767).astype(np.int16)
        interpreter.set_tensor(input_detail["index"], quantized[None, :])
        interpreter.invoke()
        result = interpreter.get_tensor(output_detail["index"])[0].astype(np.float32)
        tflite_values.append((result - output_zero) * output_scale)
    tflite_values = np.asarray(tflite_values, dtype=np.float32)
    absolute = np.abs(tflite_values - keras_values)
    op_names = [str(op["op_name"]) for op in interpreter._get_ops_details()]
    report = {
        "source_model": str(model_path),
        "source_model_sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(),
        "keras_parameters": int(model.count_params()),
        "export_parameters": int(model_for_export.count_params()),
        "fixed_pga_code": args.fixed_pga_code,
        "specialization_max_abs_delta": float(np.max(np.abs(specialization_delta))),
        "input_shape": [1, 15],
        "output_shape": [1, 9],
        "representative_rows": int(len(rep)),
        "evaluation_rows": int(len(eval_rows)),
        "tflite_bytes": int(len(model_bytes)),
        "tflite_sha256": hashlib.sha256(model_bytes).hexdigest(),
        "input_dtype": str(input_detail["dtype"]),
        "input_quantization": {"scale": float(scale), "zero_point": int(zero)},
        "output_quantization": {"scale": float(output_scale), "zero_point": int(output_zero)},
        "output_names": metadata["output_names"],
        "quantization_error": {
            metadata["output_names"][i]: {
                "mae": float(np.mean(absolute[:, i])),
                "p99_abs": float(np.quantile(absolute[:, i], 0.99)),
                "max_abs": float(np.max(absolute[:, i])),
            } for i in range(9)
        },
        "operators": {name: op_names.count(name) for name in sorted(set(op_names))},
        "all_outputs_finite": bool(np.isfinite(tflite_values).all()),
    }
    report_path = args.output.with_suffix(args.output.suffix + ".json")
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
