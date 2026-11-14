#!/usr/bin/env python3
"""Build the VU3P model-BRAM COE from the active sensor firmware models."""

from __future__ import annotations

import argparse
from pathlib import Path


BMG_WORDS = 471_040  # Matches sensor_model_bram Write_Depth_A (0x73000 words)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    names = (
        "voltage_shared_channel_adapter_int16.tflite",
        "current_ina3_to_load_channel2_int16.tflite",
        "humidity_gxht45_to_hdc3020_int16.tflite",
    )
    image = bytearray()
    offsets: list[tuple[str, int, int]] = []
    for name in names:
        image.extend(b"\0" * (-len(image) % 16))
        payload = (args.model_dir / name).read_bytes()
        offsets.append((name, len(image), len(payload)))
        image.extend(payload)

    if len(image) > BMG_WORDS * 4:
        raise SystemExit("Model image exceeds the model BRAM capacity")
    image.extend(b"\0" * (-len(image) % 4))
    words = [f"{int.from_bytes(image[i:i + 4], 'little'):08X}" for i in range(0, len(image), 4)]
    words.extend(["00000000"] * (BMG_WORDS - len(words)))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        "memory_initialization_radix=16;\nmemory_initialization_vector=\n"
        + ",\n".join(words)
        + ";\n",
        encoding="ascii",
    )
    for name, offset, size in offsets:
        print(f"{name}: offset=0x{offset:X}, size={size}")
    print(f"Wrote {args.out}: model=0x{len(image):X} bytes, BRAM={BMG_WORDS * 4} bytes")


if __name__ == "__main__":
    main()
