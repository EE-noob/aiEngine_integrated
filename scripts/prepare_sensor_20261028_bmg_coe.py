#!/usr/bin/env python3
"""Pack the 2026-10-28 three-model release into BMG + URAM initialization."""

from __future__ import annotations

import argparse
from pathlib import Path

BMG_WORDS = 471_040  # 460 RAMB36 blocks at 32 bits per word
BMG_BYTES = BMG_WORDS * 4
URAM_TAIL_BYTES = 128 * 1024
ALIGNMENT = 16


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--voltage", type=Path, required=True)
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--humidity", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--uram-tail", type=Path, required=True)
    args = parser.parse_args()

    voltage = args.voltage.read_bytes()
    current = args.current.read_bytes()
    humidity = args.humidity.read_bytes()
    if not voltage or not current or not humidity:
        raise SystemExit("All three TFLite model files must be non-empty")
    current_offset = (len(voltage) + ALIGNMENT - 1) & ~(ALIGNMENT - 1)
    humidity_offset = (current_offset + len(current) + ALIGNMENT - 1) & ~(ALIGNMENT - 1)
    image = (voltage + bytes(current_offset - len(voltage)) + current +
             bytes(humidity_offset - current_offset - len(current)) + humidity)
    if len(image) > BMG_BYTES + URAM_TAIL_BYTES:
        raise SystemExit(
            f"Packed models require {len(image)} bytes; BMG+URAM capacity is "
            f"{BMG_BYTES + URAM_TAIL_BYTES} bytes"
        )
    bmg_image = image[:BMG_BYTES]
    bmg_image += bytes(BMG_BYTES - len(bmg_image))
    tail = image[BMG_BYTES:]
    if len(tail) > URAM_TAIL_BYTES:
        raise SystemExit("URAM model tail exceeds the reserved 128 KiB bank")
    tail += bytes(URAM_TAIL_BYTES - len(tail))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.uram_tail.parent.mkdir(parents=True, exist_ok=True)
    words = [
        f"{int.from_bytes(bmg_image[i:i + 4], 'little'):08X}"
        for i in range(0, BMG_BYTES, 4)
    ]
    args.out.write_text(
        "memory_initialization_radix=16;\n"
        "memory_initialization_vector=\n"
        + ",\n".join(words)
        + ";\n",
        encoding="ascii",
    )
    tail_words = []
    for i in range(0, URAM_TAIL_BYTES, 8):
        low = int.from_bytes(tail[i:i + 4], "little")
        high = int.from_bytes(tail[i + 4:i + 8], "little")
        tail_words.append(f"{high:08X}{low:08X}\n")
    args.uram_tail.write_text("".join(tail_words), encoding="ascii")
    print(
        f"COE={args.out} voltage={len(voltage)} current={len(current)} "
        f"humidity={len(humidity)} current_offset={current_offset} "
        f"humidity_offset={humidity_offset} "
        f"packed={len(image)} BMG={BMG_BYTES} URAM_tail={len(image) - BMG_BYTES}/"
        f"{URAM_TAIL_BYTES}"
    )


if __name__ == "__main__":
    main()
