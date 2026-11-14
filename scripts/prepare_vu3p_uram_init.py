#!/usr/bin/env python3
"""Split a VU3P .dsa_model ELF section into 80 64-bit URAM init files."""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path


BANKS = 80
BANK_BYTES = 128 * 1024
BANK_WORDS_64 = BANK_BYTES // 8
CAPACITY_BYTES = BANKS * BANK_BYTES


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--elf", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--objcopy", default="objcopy")
    args = parser.parse_args()

    if not args.elf.is_file():
        raise SystemExit(f"ELF does not exist: {args.elf}")
    args.out_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="sensor_uram_mem_") as temp_dir:
        model_bin = Path(temp_dir) / "dsa_model.bin"
        subprocess.run(
            [args.objcopy, "--dump-section", f".dsa_model={model_bin}", str(args.elf)],
            check=True,
        )
        model = model_bin.read_bytes()

    if not model:
        raise SystemExit("ELF .dsa_model section is empty")
    if len(model) > CAPACITY_BYTES:
        raise SystemExit(
            f"Model is {len(model)} bytes; 10 MiB URAM capacity is {CAPACITY_BYTES}"
        )
    if len(model) % 4:
        raise SystemExit("ELF .dsa_model section is not 32-bit word aligned")

    # Each XPM bank is 64 bits wide.  The low 32-bit half is the lower
    # 32-bit address and the high half is address + 4, matching addra_hi muxing.
    padded = model + bytes(CAPACITY_BYTES - len(model))
    for bank in range(BANKS):
        start = bank * BANK_BYTES
        bank_data = padded[start : start + BANK_BYTES]
        words = []
        for offset in range(0, BANK_BYTES, 8):
            low = int.from_bytes(bank_data[offset : offset + 4], "little")
            high = int.from_bytes(bank_data[offset + 4 : offset + 8], "little")
            words.append(f"{high:08X}{low:08X}\n")
        (args.out_dir / f"uram_bank_{bank:02d}.mem").write_text(
            "".join(words), encoding="ascii"
        )

    print(
        f"Wrote {BANKS} URAM init files: model={len(model)} bytes, "
        f"capacity={CAPACITY_BYTES} bytes, 64-bit words/bank={BANK_WORDS_64}"
    )


if __name__ == "__main__":
    main()
