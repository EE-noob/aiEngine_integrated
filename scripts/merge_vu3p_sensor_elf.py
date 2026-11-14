#!/usr/bin/env python3
"""Merge CPU firmware into a bitstream whose model is initialized by BMG MEM."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


def run(command: list[str]) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--elf", type=Path, required=True)
    parser.add_argument("--bit", type=Path, required=True)
    parser.add_argument("--mmi", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--objcopy", default="objcopy")
    parser.add_argument("--updatemem", default="updatemem")
    args = parser.parse_args()

    for path in (args.elf, args.bit, args.mmi):
        if not path.is_file():
            raise SystemExit(f"Required input does not exist: {path}")
    args.out_dir.mkdir(parents=True, exist_ok=True)

    local_elf = args.out_dir / "sensor_sw_v2_cpu_local.elf"
    run([
        args.objcopy,
        "--remove-section", ".dsa_model",
        "--remove-section", ".dsa_arena",
        str(args.elf), str(local_elf),
    ])

    final_bit = args.out_dir / "sensor_sw_v2_merged.bit"
    run([
        args.updatemem,
        "-meminfo", str(args.mmi),
        "-bit", str(args.bit),
        "-data", str(local_elf),
        "-proc", "bit_soc_i/microblaze_riscv_0",
        "-out", str(final_bit),
        "-force",
    ])
    print(f"Merged bitstream: {final_bit}")
    print("Model contents are embedded in the BMG MEM initialization data.")


if __name__ == "__main__":
    main()
