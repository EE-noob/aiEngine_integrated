#!/usr/bin/env python3
"""Convert the model section of a VU3P sensor ELF to a BMG initialization COE."""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path


BMG_WORDS = 491_520  # 1.875 MiB at 32 bits per word


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--elf", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--objcopy", default="objcopy")
    args = parser.parse_args()

    if not args.elf.is_file():
        raise SystemExit(f"ELF does not exist: {args.elf}")
    args.out.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="sensor_bmg_mem_") as temp_dir:
        model_bin = Path(temp_dir) / "dsa_model.bin"
        subprocess.run(
            [args.objcopy, "--dump-section", f".dsa_model={model_bin}", str(args.elf)],
            check=True,
        )
        model = model_bin.read_bytes()

    if not model:
        raise SystemExit("ELF .dsa_model section is empty")
    if len(model) > BMG_WORDS * 4:
        raise SystemExit(f"Model is {len(model)} bytes; BMG capacity is {BMG_WORDS * 4}")
    if len(model) % 4:
        raise SystemExit("ELF .dsa_model section is not 32-bit word aligned")

    words = [
        f"{int.from_bytes(model[offset:offset + 4], 'little'):08X}"
        for offset in range(0, len(model), 4)
    ]
    words.extend(["00000000"] * (BMG_WORDS - len(words)))
    body = ",\n".join(words) + ";\n"
    args.out.write_text(
        "memory_initialization_radix=16;\n"
        "memory_initialization_vector=\n" + body,
        encoding="ascii",
    )
    print(f"Wrote {args.out}: model={len(model)} bytes, BMG={BMG_WORDS * 4} bytes")


if __name__ == "__main__":
    main()
