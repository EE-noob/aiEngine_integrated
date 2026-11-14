#!/usr/bin/env python3
"""Deploy the current pre-release sensor models and produce a merged bitstream."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


WORKSPACE = Path(__file__).resolve().parents[2]
CANDIDATE_ROOT = Path("/home/yusen/公共的/sensor_calibration_data/pre_release")
PROJECT_ROOT = Path("/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2")
VITIS_ROOT = Path("/home/etc/FPGA/BIT_PROJ_S1/Vitis")
PLATFORM_ROOT = VITIS_ROOT / "sensor_hw_v2"
APP_ROOT = VITIS_ROOT / "sensor_sw_v2"
DEPLOY_DIR = APP_ROOT / "src/calibration/deploy_20261111_pre_release"
MODEL_DIR = PROJECT_ROOT / "model_sim"
BIT_DIR = PROJECT_ROOT / "bitstreams"
VIVADO = Path("/home/yusen/opt/Xilinx/Vivado/2024.2/bin/vivado")
VITIS = Path("/home/yusen/opt/Xilinx/Vitis/2024.2")
PYTHON = VITIS / "vcxx/third-party/python-linux/user/3.10.10/bin/python3.10"
RISCV_BIN = VITIS / "gnu/riscv/lin/riscv64-unknown-elf/bin"

MODELS = (
    (
        "V_v10_candidate",
        "voltage_calibrator_int16.tflite",
        "voltage_shared_channel_adapter_int16.tflite",
        "preprocessing_metadata.json",
        "voltage_preprocessing_metadata.json",
    ),
    (
        "I_v05_multi_candidate",
        "model_int16.tflite",
        "current_ina3_to_load_channel2_int16.tflite",
        "metadata.json",
        "current_metadata.json",
    ),
    (
        "H_v03_candidate",
        "humidity_calibrator_int16.tflite",
        "humidity_gxht45_to_hdc3020_int16.tflite",
        "preprocessing_metadata.json",
        "humidity_preprocessing_metadata.json",
    ),
)


def run(command: list[str], *, env: dict[str, str] | None = None) -> None:
    print("+", " ".join(map(str, command)), flush=True)
    subprocess.run(command, check=True, env=env)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def prepare_models() -> dict[str, object]:
    DEPLOY_DIR.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, str | int]] = []
    for directory, source_name, deployed_name, metadata_name, deployed_metadata in MODELS:
        source_dir = CANDIDATE_ROOT / directory
        source_model = source_dir / source_name
        source_metadata = source_dir / metadata_name
        if not source_model.is_file() or not source_metadata.is_file():
            raise FileNotFoundError(f"Missing model or metadata under {source_dir}")
        target_model = DEPLOY_DIR / deployed_name
        target_metadata = DEPLOY_DIR / deployed_metadata
        shutil.copy2(source_model, target_model)
        shutil.copy2(source_metadata, target_metadata)
        entries.append(
            {
                "candidate": directory,
                "source_model": str(source_model),
                "deployment_model": deployed_name,
                "bytes": target_model.stat().st_size,
                "sha256": sha256(target_model),
            }
        )

    ram_hdl = PROJECT_ROOT / "VU3P_oled.srcs/sources_1/new/dsa_npu/axi_inferred_shared_ram.sv"
    ram_source = ram_hdl.read_text(encoding="utf-8")
    capacity_match = re.search(
        r"MODEL_BRAM_BYTES\s*=\s*32'h([0-9a-fA-F_]+)", ram_source
    )
    if capacity_match is None or "byte_addra < (MODEL_BASE + MODEL_BRAM_BYTES)" not in ram_source:
        raise RuntimeError("Shared RAM model window is not defined by BRAM capacity")
    model_capacity = int(capacity_match.group(1).replace("_", ""), 16)
    model_bytes = sum(int(entry["bytes"]) for entry in entries)
    if model_bytes > model_capacity:
        raise RuntimeError(
            f"Model image is {model_bytes} bytes; shared model BRAM window is "
            f"{model_capacity} bytes"
        )
    print(
        f"Shared model BRAM window: image={model_bytes} bytes, "
        f"capacity={model_capacity} bytes",
        flush=True,
    )

    inspect = WORKSPACE / "build/board_artifacts/20261028/inspect_tflite_metadata"
    if not inspect.is_file():
        raise FileNotFoundError(f"TFLite inspection utility is missing: {inspect}")
    model_paths = [str(DEPLOY_DIR / item[2]) for item in MODELS]
    result = subprocess.run(
        [str(inspect), *model_paths], check=True, text=True, capture_output=True
    )
    print(result.stdout, end="", flush=True)
    expected_shapes = ("shape=[1,18]", "shape=[1,12]", "shape=[1,7]")
    output_lines = result.stdout.splitlines()
    for path, expected in zip(model_paths, expected_shapes, strict=True):
        try:
            model_index = output_lines.index(next(line for line in output_lines if line.startswith(path)))
        except (StopIteration, ValueError):
            raise RuntimeError(f"Could not inspect model metadata for {path}")
        input_line = output_lines[model_index + 1] if model_index + 1 < len(output_lines) else ""
        if "input tensor=" not in input_line or expected not in input_line:
            raise RuntimeError(f"Model input shape check failed for {path}; expected {expected}")

    manifest = {
        "models": entries,
        "input_shapes": [list(shape) for shape in ((1, 18), (1, 12), (1, 7))],
    }
    (DEPLOY_DIR / "deployment_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def vitis_environment() -> dict[str, str]:
    env = os.environ.copy()
    env["XILINX_VITIS"] = str(VITIS)
    env["PATH"] = f"{RISCV_BIN}:{VITIS / 'bin'}:{env.get('PATH', '')}"
    python_paths = [
        VITIS / "cli",
        VITIS / "cli/proto",
        VITIS / "cli/python-packages/lnx64/site-packages",
    ]
    env["PYTHONPATH"] = ":".join(map(str, python_paths)) + ":" + env.get("PYTHONPATH", "")
    env["PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION"] = "python"
    return env


def main() -> None:
    if not VIVADO.is_file() or not PYTHON.is_file():
        raise FileNotFoundError("Vivado or Vitis Python installation was not found")

    prepare_models()
    coe = MODEL_DIR / "sensor_models_20261111.coe"
    run(
        [
            sys.executable,
            str(WORKSPACE / "scripts/models/prepare_vu3p_sensor_models_20261108_coe.py"),
            "--model-dir",
            str(DEPLOY_DIR),
            "--out",
            str(coe),
        ]
    )

    xpr = PROJECT_ROOT / "VU3P_oled.xpr"
    run(
        [
            str(VIVADO),
            "-mode",
            "batch",
            "-source",
            str(WORKSPACE / "scripts/fpga/update_vu3p_sensor_model_bram.tcl"),
            "-tclargs",
            str(xpr),
            str(coe),
        ],
        env=os.environ.copy(),
    )
    run(
        [
            str(VIVADO),
            "-mode",
            "batch",
            "-source",
            str(WORKSPACE / "scripts/fpga/synthesize_vu3p_sensor_bmg_ip.tcl"),
        ],
        env=os.environ.copy(),
    )

    xsa_name = "sensor_hw_v2_20261111_pre_release_bit.xsa"
    xsa = PLATFORM_ROOT / "hw" / xsa_name
    run(
        [
            str(VIVADO),
            "-mode",
            "batch",
            "-source",
            str(WORKSPACE / "scripts/fpga/implement_export_vu3p_sensor_latest.tcl"),
            "-tclargs",
            str(xsa),
        ],
        env=os.environ.copy(),
    )

    staged_xsa = Path("/tmp") / xsa_name
    shutil.copy2(xsa, staged_xsa)
    run(
        [
            str(PYTHON),
            str(WORKSPACE / "scripts/fpga/update_vitis_sensor_platform.py"),
            str(VITIS_ROOT),
            str(staged_xsa),
        ],
        env=vitis_environment(),
    )

    platform_config = PLATFORM_ROOT / "vitis-comp.json"
    config = json.loads(platform_config.read_text(encoding="utf-8"))
    config["configuration"]["xsa"] = str(xsa)
    config["configuration"]["xsaPathInPlatform"] = f"sensor_hw_v2/hw/{xsa_name}"
    platform_config.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")

    bit = PROJECT_ROOT / "VU3P_oled.runs/impl_1/bit_soc_wrapper.bit"
    mmi = PROJECT_ROOT / "VU3P_oled.runs/impl_1/bit_soc_wrapper.mmi"
    elf = APP_ROOT / "build/sensor_sw_v2.elf"
    merge_dir = BIT_DIR / "final_20261111_pre_release"
    run(
        [
            sys.executable,
            str(WORKSPACE / "scripts/fpga/merge_vu3p_sensor_elf.py"),
            "--elf",
            str(elf),
            "--bit",
            str(bit),
            "--mmi",
            str(mmi),
            "--out-dir",
            str(merge_dir),
            "--objcopy",
            str(RISCV_BIN / "riscv64-unknown-elf-objcopy"),
            "--updatemem",
            "/home/yusen/opt/Xilinx/Vivado/2024.2/bin/updatemem",
        ]
    )
    final_bit = merge_dir / "sensor_sw_v2_merged.bit"
    top_level_bit = BIT_DIR / "sensor_sw_v2_merged_20261111_pre_release.bit"
    shutil.copy2(final_bit, top_level_bit)
    print(f"Final merged bitstream: {top_level_bit}", flush=True)
    print(f"SHA256: {sha256(top_level_bit)}", flush=True)


if __name__ == "__main__":
    main()
