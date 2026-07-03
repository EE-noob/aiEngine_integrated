#!/usr/bin/env python3
"""Generate Chinese-labelled plots for bus optimization report."""

from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib import font_manager


DOC_DIR = Path(__file__).resolve().parent
ROOT = DOC_DIR.parents[1]
SIM_DIR = ROOT / "veri" / "sim"
OUT_DIR = DOC_DIR / "perf_plots"


def configure_chinese_font() -> None:
    candidates = [
        "/usr/share/fonts/Fonts/simhei.ttf",
        "/usr/share/fonts/truetype/SourceHanSansCN-Regular.otf",
        "/usr/share/fonts/MiSans/MiSans/ttf/MiSans-Normal.ttf",
        "/usr/share/fonts/truetype/wqy-zenhei.ttc",
    ]
    for font_path in candidates:
        if Path(font_path).exists():
            font_manager.fontManager.addfont(font_path)
            plt.rcParams["font.family"] = font_manager.FontProperties(fname=font_path).get_name()
            break
    plt.rcParams["axes.unicode_minus"] = False
    plt.rcParams.update({"figure.dpi": 150, "savefig.dpi": 180, "font.size": 9})


def to_int(row: dict[str, str], key: str, default: int = 0) -> int:
    value = row.get(key, "")
    return int(value) if value not in ("", None) else default


def read_perf(path: Path, stage: str | None = None) -> list[dict[str, float | int | str]]:
    rows: list[dict[str, float | int | str]] = []
    with path.open(newline="") as f:
        for raw in csv.DictReader(f):
            if raw.get("result") != "pass":
                continue
            row: dict[str, float | int | str] = dict(raw)
            for key, value in raw.items():
                if key in {"result", "log"} or value == "":
                    continue
                try:
                    row[key] = int(value)
                except ValueError:
                    pass
            active = to_int(raw, "mma_active") or to_int(raw, "ctrl_active")
            cycles = to_int(raw, "cycles")
            axi_r = to_int(raw, "mma_axi_r")
            axi_w = to_int(raw, "mma_axi_w")
            k = to_int(raw, "K")
            size = max(1, to_int(raw, "size", 1))
            ops = 2 * k * to_int(raw, "N") * to_int(raw, "M")
            row["dim"] = k
            row["active"] = active
            row["total_beats"] = axi_r + axi_w
            row["read_util_pct"] = 100.0 * axi_r / active if active else 0.0
            row["write_util_pct"] = 100.0 * axi_w / active if active else 0.0
            row["beat_util_pct"] = 100.0 * (axi_r + axi_w) / active if active else 0.0
            row["gops_200m"] = ops * 200e6 / cycles / 1e9 if cycles else 0.0
            row["array_util_pct"] = 100.0 * ((ops / 2) / cycles) / (size * size) if cycles else 0.0
            if stage is not None:
                row["stage"] = stage
            rows.append(row)
    return rows


def style_axis(ax) -> None:
    ax.grid(True, alpha=0.25)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)


def main() -> None:
    configure_chinese_font()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    current = read_perf(SIM_DIR / "runs/bus_report_fifo_watermark_current_trace/perf.csv")
    randlat = read_perf(SIM_DIR / "runs/bus_report_fifo_watermark_randlat_trace/perf.csv")
    is_rows = read_perf(SIM_DIR / "runs/bus_report_fifo_watermark_is_trace/perf.csv")
    evolution = (
        read_perf(SIM_DIR / "runs/bus_util_s16_c4_current/perf.csv", "旧 interconnect/旧 RAM")
        + read_perf(SIM_DIR / "runs/bus_util_s16_c4_mma_prio/perf.csv", "MMA 优先仲裁")
        + read_perf(SIM_DIR / "runs/bus_util_s16_c4_mma_prio_ram_fullpipe_ic1/perf.csv", "RAM 流水 + 指令 cache")
        + [dict(row, stage="当前实现") for row in current if row["cache_blocks"] == 4]
    )
    colors = {4: "#3662b0", 8: "#4b9f77", 16: "#c2673a"}

    fig, ax = plt.subplots(figsize=(7.0, 4.2))
    for cache in sorted({int(r["cache_blocks"]) for r in current}):
        rows = sorted([r for r in current if r["cache_blocks"] == cache], key=lambda r: int(r["dim"]))
        ax.plot([r["dim"] for r in rows], [r["cycles"] / 1e6 for r in rows],
                marker="o", label=f"IA cache={cache}", color=colors.get(cache))
    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    ax.set_xlabel("矩阵尺寸 K=N=M")
    ax.set_ylabel("SoC 周期（百万，对数坐标）")
    ax.set_title("当前总线与数据流下的周期变化")
    style_axis(ax)
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "bus_opt_current_cycles_by_dim.png")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7.0, 4.2))
    for cache in sorted({int(r["cache_blocks"]) for r in current}):
        rows = sorted([r for r in current if r["cache_blocks"] == cache], key=lambda r: int(r["dim"]))
        ax.plot([r["dim"] for r in rows], [r["beat_util_pct"] for r in rows],
                marker="o", label=f"IA cache={cache}", color=colors.get(cache))
    ax.axhline(90, color="#888888", linestyle="--", linewidth=1, label="90% 参考线")
    ax.set_xscale("log", base=2)
    ax.set_ylim(0, 105)
    ax.set_xlabel("矩阵尺寸 K=N=M")
    ax.set_ylabel("AXI 有效 beat / MMA 活跃周期（%）")
    ax.set_title("MMA 活跃窗口内的总线 beat 压力")
    style_axis(ax)
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "bus_opt_current_util_by_dim.png")
    plt.close(fig)

    rows512 = sorted([r for r in current if r["dim"] == 512], key=lambda r: int(r["cache_blocks"]))
    fig, ax = plt.subplots(figsize=(6.5, 4.0))
    xs = list(range(len(rows512)))
    read = [r["read_util_pct"] for r in rows512]
    write = [r["write_util_pct"] for r in rows512]
    ax.bar(xs, read, label="读通道", color="#4d79b6")
    ax.bar(xs, write, bottom=read, label="写通道", color="#c27a4a")
    ax.set_xticks(xs, [f"C={r['cache_blocks']}\nR={r['ia_reuse_eff']}" for r in rows512])
    ax.set_ylim(0, 105)
    ax.set_ylabel("活跃窗口占用率（%）")
    ax.set_title("512^3 下读写 beat 组成")
    style_axis(ax)
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "bus_opt_read_write_512.png")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7.0, 4.2))
    entries = []
    for dim in [128, 256]:
        for cache in [4, 8, 16]:
            det = next(r for r in current if r["dim"] == dim and r["cache_blocks"] == cache)
            rnd = next(r for r in randlat if r["dim"] == dim and r["cache_blocks"] == cache)
            entries.append((dim, cache, det["cycles"] / 1e6, rnd["cycles"] / 1e6))
    width = 0.32
    xs = list(range(len(entries)))
    ax.bar([x - width / 2 for x in xs], [e[2] for e in entries], width, label="同步 1 拍 RAM")
    ax.bar([x + width / 2 for x in xs], [e[3] for e in entries], width, label="随机 DDR 延迟")
    ax.set_xticks(xs, [f"{e[0]}^3\nC={e[1]}" for e in entries])
    ax.set_ylabel("SoC 周期（百万）")
    ax.set_title("Outstanding/流水总线对随机延迟的敏感度")
    style_axis(ax)
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "bus_opt_randlat_cycles.png")
    plt.close(fig)

    stages = ["旧 interconnect/旧 RAM", "MMA 优先仲裁", "RAM 流水 + 指令 cache", "当前实现"]
    fig, ax = plt.subplots(figsize=(7.2, 4.2))
    for dim, marker in [(128, "o"), (256, "s")]:
        ys = []
        for stage in stages:
            ys.append(next(r for r in evolution if r["stage"] == stage and r["dim"] == dim)["cycles"] / 1e6)
        ax.plot(stages, ys, marker=marker, label=f"{dim}^3")
    ax.set_ylabel("SoC 周期（百万）")
    ax.set_title("总线优化阶段演进（SIZE=16, IA cache=4）")
    style_axis(ax)
    ax.legend(title="矩阵尺寸")
    plt.xticks(rotation=12, ha="right")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "bus_opt_evolution_cycles.png")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7.0, 4.2))
    stall_xs = list(range(len(rows512)))
    stall_keys = [
        ("ctrl_weight_data_stall", "W 数据等待"),
        ("ctrl_ia_data_stall", "IA 数据等待"),
        ("ctrl_fifo_stall", "OA FIFO 等待"),
        ("ctrl_bias_stall", "bias 等待"),
        ("ctrl_weight_done_wait", "W 完成等待"),
    ]
    bottom = [0.0] * len(rows512)
    for key, label in stall_keys:
        vals = [100.0 * int(r.get(key) or 0) / int(r["ctrl_active"]) for r in rows512]
        ax.bar(stall_xs, vals, bottom=bottom, label=label)
        bottom = [a + b for a, b in zip(bottom, vals)]
    ax.set_xticks(stall_xs, [f"C={r['cache_blocks']}\nR={r['ia_reuse_eff']}" for r in rows512])
    ax.set_ylabel("等待 / 控制器活跃周期（%）")
    ax.set_title("512^3 下主要等待组成")
    style_axis(ax)
    ax.legend(ncols=3, fontsize=8)
    fig.tight_layout()
    fig.savefig(OUT_DIR / "bus_opt_stall_breakdown_512.png")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(6.8, 4.0))
    for cache in [8, 16]:
        rows = sorted([r for r in is_rows if r["cache_blocks"] == cache], key=lambda r: int(r["dim"]))
        ax.plot([r["dim"] for r in rows], [r["cycles"] / 1e6 for r in rows],
                marker="o", label=f"IS s16 C={cache}", color=colors.get(cache))
    ax.set_xscale("log", base=2)
    ax.set_xlabel("矩阵尺寸 K=N=M")
    ax.set_ylabel("SoC 周期（百万）")
    ax.set_title("IS/s16 数据流子集性能")
    style_axis(ax)
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "bus_opt_is_s16_cycles.png")
    plt.close(fig)


if __name__ == "__main__":
    main()
