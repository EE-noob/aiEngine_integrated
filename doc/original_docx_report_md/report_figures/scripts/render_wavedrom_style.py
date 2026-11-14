#!/usr/bin/env python3
import html
import json
import subprocess
import sys
from pathlib import Path


HIGH = 28
LOW = 54
MID = 41
CELL = 48
LEFT = 190
TOP = 78
ROW_H = 48


def esc(value):
    return html.escape(str(value), quote=True)


def wave_value(chars, index):
    current = "x"
    for pos in range(index + 1):
        char = chars[pos] if pos < len(chars) else "."
        if char != ".":
            current = char
    return current


def y_for(value):
    if value == "1":
        return HIGH
    if value == "0":
        return LOW
    return MID


def draw_digital(chars, y0, color):
    points = []
    last = wave_value(chars, 0)
    x = LEFT
    y = y0 + y_for(last)
    points.append(f"M{x},{y}")
    for index in range(len(chars)):
        value = wave_value(chars, index)
        next_x = LEFT + (index + 1) * CELL
        new_y = y0 + y_for(value)
        if new_y != y:
            points.append(f"L{x},{new_y}")
            y = new_y
        points.append(f"L{next_x},{y}")
        x = next_x
    return f'<path d="{" ".join(points)}" fill="none" stroke="{color}" stroke-width="2.6" stroke-linejoin="round"/>'


def draw_clock(chars, y0):
    points = []
    x = LEFT
    y = y0 + LOW
    points.append(f"M{x},{y}")
    for index in range(len(chars)):
        x0 = LEFT + index * CELL
        x1 = x0 + CELL / 2
        x2 = x0 + CELL
        points.append(f"L{x0},{y0 + LOW} L{x0},{y0 + HIGH} L{x1},{y0 + HIGH} L{x1},{y0 + LOW} L{x2},{y0 + LOW}")
    return f'<path d="{" ".join(points)}" fill="none" stroke="#263238" stroke-width="2.4"/>'


def draw_bus(chars, data, y0):
    output = []
    data_index = 0
    active = False
    start = 0
    label = ""
    def close_segment(end_index):
        x = LEFT + start * CELL
        width = max(CELL, (end_index - start) * CELL)
        y = y0 + 24
        output.append(f'<rect x="{x}" y="{y}" width="{width}" height="32" rx="6" fill="#FFF8E1" stroke="#B88300" stroke-width="1.8"/>')
        output.append(f'<text x="{x + width / 2}" y="{y + 21}" class="buslabel" text-anchor="middle">{esc(label)}</text>')

    for index, char in enumerate(chars + "x"):
        if char == "=" and not active:
            active = True
            start = index
            label = data[data_index] if data_index < len(data) else "data"
            data_index += 1
        elif char == "=" and active:
            close_segment(index)
            start = index
            label = data[data_index] if data_index < len(data) else "data"
            data_index += 1
        elif char != "." and active:
            close_segment(index)
            active = False
    output.append(f'<line x1="{LEFT}" y1="{y0 + MID}" x2="{LEFT + len(chars) * CELL}" y2="{y0 + MID}" stroke="#B88300" stroke-width="1.4" stroke-dasharray="4 4"/>')
    return "\n".join(output)


def render(input_path, output_svg):
    doc = json.loads(Path(input_path).read_text(encoding="utf-8"))
    signals = doc.get("signal", [])
    rows = [sig for sig in signals if sig]
    max_len = max(len(sig.get("wave", "")) for sig in rows)
    width = LEFT + max_len * CELL + 50
    height = TOP + len(signals) * ROW_H + 36
    title = doc.get("head", {}).get("text", Path(input_path).stem)
    body = []
    body.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">')
    body.append('<style>text{font-family:"Noto Sans CJK SC","Microsoft YaHei",Arial,sans-serif}.title{font-size:28px;font-weight:700}.name{font-size:18px;font-weight:600}.tick{font-size:13px;fill:#607D8B}.buslabel{font-size:15px;font-weight:700;fill:#3A2A00}</style>')
    body.append('<rect width="100%" height="100%" fill="white"/>')
    body.append(f'<text x="{width / 2}" y="38" class="title" text-anchor="middle">{esc(title)}</text>')
    for index in range(max_len + 1):
        x = LEFT + index * CELL
        body.append(f'<line x1="{x}" y1="58" x2="{x}" y2="{height - 24}" stroke="#ECEFF1" stroke-width="1"/>')
        if index < max_len:
            body.append(f'<text x="{x + CELL / 2}" y="64" class="tick" text-anchor="middle">T{index}</text>')
    row_index = 0
    for signal in signals:
        y0 = TOP + row_index * ROW_H
        if not signal:
            body.append(f'<line x1="24" y1="{y0 + ROW_H / 2}" x2="{width - 24}" y2="{y0 + ROW_H / 2}" stroke="#CFD8DC" stroke-width="1"/>')
            row_index += 1
            continue
        name = signal.get("name", "")
        wave = signal.get("wave", "").ljust(max_len, ".")
        data = signal.get("data", [])
        body.append(f'<text x="22" y="{y0 + 45}" class="name">{esc(name)}</text>')
        if wave.startswith("p"):
            body.append(draw_clock(wave, y0))
        elif "=" in wave:
            body.append(draw_bus(wave, data, y0))
        else:
            body.append(draw_digital(wave, y0, "#1565C0"))
        row_index += 1
    body.append('</svg>')
    Path(output_svg).write_text("\n".join(body), encoding="utf-8")


def main():
    if len(sys.argv) < 3:
        print("usage: render_wavedrom_style.py input.json output.svg [output.png]", file=sys.stderr)
        return 2
    render(sys.argv[1], sys.argv[2])
    if len(sys.argv) >= 4:
        try:
            subprocess.run(["convert", "-density", "180", sys.argv[2], sys.argv[3]], check=True)
        except (FileNotFoundError, subprocess.CalledProcessError) as exc:
            print(f"warning: png conversion skipped: {exc}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
