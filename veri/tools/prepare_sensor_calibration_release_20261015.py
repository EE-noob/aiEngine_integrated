#!/usr/bin/env python3
"""Package the 2026-10-15 sensor calibration release for TFLM regressions.

The release is a two-stage model: a 10-input/9-output int16x8 base model and
a 980-input V4 residual adapter.  This tool copies the frozen model artifacts
into the repository and emits a full host test set plus a small, stratified
SoC test set.  TensorFlow is only needed while preparing the artifacts.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import shutil
import sys
from pathlib import Path

import numpy as np
import tensorflow as tf


DEFAULT_RELEASE = Path(
    "/home/yusen/公共的/sensor_calibration_data/calibration_release_20261015"
)
BASE_DIR_NAME = "calibration_model_20161013_pair_range_feedback_valmae_20261014"
ADAPTER_DIR_NAME = "calibration_model_20161013_bestweight_randomcell_lut_adapter_20261015"
SOURCE_FILES = ["calibration_20161013_h60(1).csv", "calibration_20161013_h70.csv"]
SEED = 20261015


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot import helper module {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def c_float(value: float) -> str:
    literal = f"{float(value):.9g}"
    if "." not in literal and "e" not in literal.lower():
        literal += ".0"
    return literal + "f"


def write_bytes_array(path: Path, symbol: str, content: bytes) -> None:
    values = [f"0x{byte:02x}" for byte in content]
    lines = [", ".join(values[index : index + 12]) for index in range(0, len(values), 12)]
    path.write_text(
        '#include "sensor_calibration_release_data.h"\n\n'
        f"alignas(16) const unsigned char {symbol}[] = {{\n"
        + ",\n".join(f"    {line}" for line in lines)
        + "\n};\n"
        f"const unsigned int {symbol}_len = sizeof({symbol});\n",
        encoding="utf-8",
    )


def write_cases(path: Path, symbol: str, rows: list[dict], count_macro: str) -> None:
    entries = []
    for row in rows:
        inputs = ", ".join(c_float(value) for value in row["inputs"])
        entries.append(
            "    {{"
            + inputs
            + "}, "
            + ", ".join(
                [
                    c_float(row["reference"]),
                    c_float(row["baseline"]),
                    c_float(row["candidate"]),
                    str(row["pga"]),
                    str(row["source_file_id"]),
                    str(row["source_row"]),
                ]
            )
            + "}"
        )
    path.write_text(
        '#include "sensor_calibration_release_data.h"\n\n'
        f"const SensorCalibrationReleaseTestCase {symbol}[{count_macro}] = {{\n"
        + ",\n".join(entries)
        + "\n};\n",
        encoding="utf-8",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release-root", type=Path, default=DEFAULT_RELEASE)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[2]
        / "drivers/tflm/my_tflm/tflite-micro/sensor_calibration_20261015",
    )
    parser.add_argument("--soc-samples", type=int, default=16)
    parser.add_argument("--force", action="store_true", help="Replace generated release assets")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    tf.config.set_visible_devices([], "GPU")
    release_root = args.release_root.resolve()
    output_dir = args.output_dir.resolve()
    base_src = release_root / BASE_DIR_NAME
    adapter_src = release_root / ADAPTER_DIR_NAME
    required = [
        release_root / "README.md",
        release_root / "train_sensor_calibration_multichannel.py",
        release_root / "train_sensor_residual_cell_adapter.py",
        base_src / "sensor_calibrator_int16.tflite",
        base_src / "metadata.json",
        adapter_src / "cell_residual_adapter_int16.tflite",
        adapter_src / "metadata.json",
        adapter_src / "test_predictions.csv",
    ]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise FileNotFoundError("Release package is incomplete:\n" + "\n".join(missing))
    if output_dir.exists() and any(output_dir.iterdir()) and not args.force:
        raise FileExistsError(
            f"Refusing to replace non-empty output directory {output_dir}; pass --force to regenerate"
        )
    if args.soc_samples < 1:
        raise ValueError("--soc-samples must be at least 1")

    trainer = load_module(
        "sensor_calibration_release_trainer",
        release_root / "train_sensor_calibration_multichannel.py",
    )
    residual = load_module(
        "sensor_calibration_release_residual",
        release_root / "train_sensor_residual_cell_adapter.py",
    )
    base_metadata = json.loads((base_src / "metadata.json").read_text(encoding="utf-8"))
    adapter_metadata = json.loads((adapter_src / "metadata.json").read_text(encoding="utf-8"))

    x, y, mask, groups, source_rows, file_metadata, _, pga_codes = trainer.load_sources(
        release_root / "source_data", "hdc3020_ref_temp_c", SOURCE_FILES
    )
    split = residual.random_row_split(groups, SEED)
    valid_test = np.flatnonzero(split["test"] & (mask[:, 4] > 0.5))
    if len(valid_test) < 100 or args.soc_samples > len(valid_test):
        raise ValueError(
            f"Invalid test data size {len(valid_test)} for {args.soc_samples} SoC samples"
        )

    packaged_predictions = {}
    with (adapter_src / "test_predictions.csv").open(
        newline="", encoding="utf-8"
    ) as stream:
        for row in csv.DictReader(stream):
            key = (Path(row["source_file"]).name, int(row["source_row"]))
            packaged_predictions[key] = row

    file_ids = {name: index for index, name in enumerate(SOURCE_FILES)}
    cases = []
    for index in valid_test:
        filename = Path(str(groups[index])).name
        source_row = int(source_rows[index])
        prediction = packaged_predictions.get((filename, source_row))
        if prediction is None:
            raise ValueError(f"No packaged prediction for {filename} row {source_row}")
        cases.append(
            {
                "inputs": np.asarray(x[index], dtype=np.float32),
                "reference": float(y[index, 4]),
                "baseline": float(prediction["baseline_tflite_v4_v"]),
                "candidate": float(prediction["candidate_tflite_v4_v"]),
                "pga": int(round(float(pga_codes[index]))),
                "source_file_id": file_ids[filename],
                "source_row": source_row,
            }
        )

    selected_positions = np.unique(
        np.linspace(0, len(cases) - 1, args.soc_samples, dtype=np.int64)
    )
    soc_cases = [cases[int(position)] for position in selected_positions]
    output_dir.mkdir(parents=True, exist_ok=True)

    base_tflite = (base_src / "sensor_calibrator_int16.tflite").read_bytes()
    adapter_tflite = (adapter_src / "cell_residual_adapter_int16.tflite").read_bytes()
    (output_dir / "sensor_calibrator_int16.tflite").write_bytes(base_tflite)
    (output_dir / "cell_residual_adapter_int16.tflite").write_bytes(adapter_tflite)
    shutil.copy2(base_src / "metadata.json", output_dir / "base_metadata.json")
    shutil.copy2(adapter_src / "metadata.json", output_dir / "adapter_metadata.json")
    write_bytes_array(
        output_dir / "sensor_calibration_release_model_data.cc",
        "g_sensor_calibration_release_base_model_data",
        base_tflite,
    )
    with (output_dir / "sensor_calibration_release_model_data.cc").open(
        "a", encoding="utf-8"
    ) as stream:
        values = [f"0x{byte:02x}" for byte in adapter_tflite]
        lines = [", ".join(values[i : i + 12]) for i in range(0, len(values), 12)]
        stream.write(
            "\nalignas(16) const unsigned char "
            "g_sensor_calibration_release_adapter_model_data[] = {\n"
            + ",\n".join(f"    {line}" for line in lines)
            + "\n};\nconst unsigned int "
            "g_sensor_calibration_release_adapter_model_data_len = "
            "sizeof(g_sensor_calibration_release_adapter_model_data);\n"
        )

    input_mean = base_metadata["input_mean"]
    input_std = base_metadata["input_std"]
    cell_keys = adapter_metadata["cell_key_to_onehot_column"]
    adapter_dir = output_dir
    import tensorflow.lite as tflite

    base_interpreter = tflite.Interpreter(
        model_path=str(output_dir / "sensor_calibrator_int16.tflite"), num_threads=2
    )
    adapter_interpreter = tflite.Interpreter(
        model_path=str(output_dir / "cell_residual_adapter_int16.tflite"), num_threads=2
    )
    base_interpreter.allocate_tensors()
    adapter_interpreter.allocate_tensors()
    base_details = base_interpreter.get_output_details()
    adapter_input = adapter_interpreter.get_input_details()[0]
    base_tensor_names = [detail["name"] for detail in base_details]
    logical_tensor_names = base_metadata["tflite_output_tensor_names"]
    output_map = []
    for name in logical_tensor_names:
        try:
            output_map.append(base_tensor_names.index(name))
        except ValueError as exc:
            raise ValueError(f"Model output tensor {name!r} is not present") from exc

    header = [
        "#pragma once",
        "#include <stdint.h>",
        "#include <stddef.h>",
        "",
        "struct SensorCalibrationReleaseTestCase {",
        "  float sensor_inputs[10];",
        "  float reference_v4_v;",
        "  float package_tflite_baseline_v4_v;",
        "  float package_tflite_candidate_v4_v;",
        "  uint8_t pga_code;",
        "  uint8_t source_file_id;",
        "  uint32_t source_row;",
        "};",
        "",
        f"#define SENSOR_CALIBRATION_RELEASE_HOST_SAMPLE_COUNT {len(cases)}",
        f"#define SENSOR_CALIBRATION_RELEASE_SOC_SAMPLE_COUNT {len(soc_cases)}",
        f"#define SENSOR_CALIBRATION_RELEASE_CELL_COUNT {len(cell_keys)}",
        "",
        "extern const unsigned char g_sensor_calibration_release_base_model_data[];",
        "extern const unsigned int g_sensor_calibration_release_base_model_data_len;",
        "extern const unsigned char g_sensor_calibration_release_adapter_model_data[];",
        "extern const unsigned int g_sensor_calibration_release_adapter_model_data_len;",
        "extern const SensorCalibrationReleaseTestCase g_sensor_calibration_release_host_cases[SENSOR_CALIBRATION_RELEASE_HOST_SAMPLE_COUNT];",
        "extern const SensorCalibrationReleaseTestCase g_sensor_calibration_release_soc_cases[SENSOR_CALIBRATION_RELEASE_SOC_SAMPLE_COUNT];",
        "extern const int16_t g_sensor_calibration_release_cell_keys[SENSOR_CALIBRATION_RELEASE_CELL_COUNT][5];",
        "extern const float g_sensor_calibration_release_input_mean[10];",
        "extern const float g_sensor_calibration_release_input_std[10];",
        "extern const int g_sensor_calibration_release_output_map[9];",
        "extern const char* const g_sensor_calibration_release_source_files[2];",
        "",
    ]
    (output_dir / "sensor_calibration_release_data.h").write_text(
        "\n".join(header), encoding="utf-8"
    )
    constants = [
        '#include "sensor_calibration_release_data.h"',
        "",
        "const int16_t g_sensor_calibration_release_cell_keys[SENSOR_CALIBRATION_RELEASE_CELL_COUNT][5] = {",
        *["    {" + ", ".join(str(int(v)) for v in key) + "}," for key in cell_keys],
        "};",
        "const float g_sensor_calibration_release_input_mean[10] = {",
        "    " + ", ".join(c_float(v) for v in input_mean),
        "};",
        "const float g_sensor_calibration_release_input_std[10] = {",
        "    " + ", ".join(c_float(v) for v in input_std),
        "};",
        "const int g_sensor_calibration_release_output_map[9] = {",
        "    " + ", ".join(str(value) for value in output_map),
        "};",
        "const char* const g_sensor_calibration_release_source_files[2] = {",
        "    \"" + SOURCE_FILES[0] + "\", \"" + SOURCE_FILES[1] + "\"",
        "};",
        "",
    ]
    (output_dir / "sensor_calibration_release_data.cc").write_text(
        "\n".join(constants), encoding="utf-8"
    )
    write_cases(
        output_dir / "sensor_calibration_release_host_test_data.cc",
        "g_sensor_calibration_release_host_cases",
        cases,
        "SENSOR_CALIBRATION_RELEASE_HOST_SAMPLE_COUNT",
    )
    write_cases(
        output_dir / "sensor_calibration_release_soc_test_data.cc",
        "g_sensor_calibration_release_soc_cases",
        soc_cases,
        "SENSOR_CALIBRATION_RELEASE_SOC_SAMPLE_COUNT",
    )

    summary = {
        "release_root": str(release_root),
        "base_model_sha256": hashlib.sha256(base_tflite).hexdigest(),
        "adapter_model_sha256": hashlib.sha256(adapter_tflite).hexdigest(),
        "base_model_bytes": len(base_tflite),
        "adapter_model_bytes": len(adapter_tflite),
        "base_ops": {"FULLY_CONNECTED": 24, "ADD": 8, "CONCATENATION": 1, "MUL": 17, "LOGISTIC": 10, "QUANTIZE": 6},
        "nmsis_per_channel_int16_fc_policy": "TFLM per-channel reference fallback; per-tensor FC and residual adapter use NPU",
        "soc_max_allowed_package_delta_uv": 2500,
        "test_split_valid_v4_count": len(cases),
        "soc_sample_count": len(soc_cases),
        "soc_test_positions": [int(index) for index in selected_positions],
        "source_files": SOURCE_FILES,
        "package_test_v4_baseline_mae_mv": float(
            np.mean([abs(row["baseline"] - row["reference"]) for row in cases]) * 1000
        ),
        "package_test_v4_candidate_mae_mv": float(
            np.mean([abs(row["candidate"] - row["reference"]) for row in cases]) * 1000
        ),
        "tflite_base_output_map_logical_to_raw": output_map,
        "base_input_quantization": list(base_interpreter.get_input_details()[0]["quantization"]),
        "adapter_input_quantization": list(adapter_input["quantization"]),
        "adapter_output_quantization": list(adapter_interpreter.get_output_details()[0]["quantization"]),
        "soc_sources": [
            {"file": SOURCE_FILES[row["source_file_id"]], "row": row["source_row"]}
            for row in soc_cases
        ],
    }
    (output_dir / "regression_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
