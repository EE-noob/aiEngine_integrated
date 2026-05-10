import argparse
import struct


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("binary")
    parser.add_argument("mem")
    parser.add_argument("--depth", type=int, default=65536)
    args = parser.parse_args()

    with open(args.binary, "rb") as f:
        data = f.read()

    words = []
    for offset in range(0, len(data), 4):
        chunk = data[offset:offset + 4]
        if len(chunk) < 4:
            chunk += b"\x00" * (4 - len(chunk))
        words.append(struct.unpack("<I", chunk)[0])

    if len(words) > args.depth:
        raise SystemExit(f"{args.binary} needs {len(words)} words, depth is {args.depth}")

    with open(args.mem, "w", encoding="utf-8") as f:
        for word in words:
            f.write(f"{word:08x}\n")


if __name__ == "__main__":
    main()
