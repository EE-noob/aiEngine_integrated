#!/usr/bin/env python3
"""Generate Chinese-labelled plots for the FPGA timing optimization report."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib import font_manager


OUT_DIR = Path(__file__).resolve().parent / "perf_plots"


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


def style_axis(ax) -> None:
    ax.grid(True, axis="y", alpha=0.25)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    configure_chinese_font()

    wns_stages = [
        ("paramfifo\n路由后", -0.069),
        ("bias流水\n路由后", 0.004),
        ("本轮放置\nphys-opt", 0.021),
        ("本轮初始\nroute", -0.279),
        ("本轮post-route\nphys-opt", 0.000),
    ]
    fig, ax = plt.subplots(figsize=(8.4, 4.6), constrained_layout=True)
    xs = list(range(len(wns_stages)))
    ys = [row[1] for row in wns_stages]
    ax.plot(xs, ys, marker="o", linewidth=2.2, color="#2563eb")
    ax.axhline(0.0, color="#16a34a", linestyle="--", linewidth=1.2, label="时序通过线")
    ax.fill_between(xs, ys, 0.0, where=[y < 0 for y in ys], color="#dc2626", alpha=0.12)
    ax.set_xticks(xs, [row[0] for row in wns_stages])
    ax.set_ylabel("WNS(ns)")
    ax.set_title("150 MHz 约束下 WNS 收敛过程")
    style_axis(ax)
    for x, y in zip(xs, ys):
        ax.text(x, y + (0.018 if y >= 0 else -0.028), f"{y:+.3f}", ha="center", va="center")
    ax.legend(frameon=False, loc="lower left")
    fig.savefig(OUT_DIR / "timing_opt_wns_evolution.png")
    plt.close(fig)

    before_after = [
        ("整体WNS", -0.069, 0.000),
        ("DMA到bias缓存", -0.069, 0.091),
        ("脉动阵列到PS FIFO", -0.036, 0.042),
        ("AXI RAM读使能", -0.010, 0.000),
    ]
    fig, ax = plt.subplots(figsize=(8.2, 4.8), constrained_layout=True)
    xs = list(range(len(before_after)))
    width = 0.34
    ax.bar([x - width / 2 for x in xs], [row[1] for row in before_after], width,
           label="优化前", color="#dc2626")
    ax.bar([x + width / 2 for x in xs], [row[2] for row in before_after], width,
           label="优化后", color="#16a34a")
    ax.axhline(0.0, color="#111827", linewidth=0.9)
    ax.set_xticks(xs, [row[0] for row in before_after], rotation=10, ha="right")
    ax.set_ylabel("最差 slack(ns)")
    ax.set_title("关键路径族优化前后 slack 对比")
    style_axis(ax)
    ax.legend(frameon=False)
    fig.savefig(OUT_DIR / "timing_opt_path_slack_before_after.png")
    plt.close(fig)

    current_paths = [
        ("AXI RAM读使能", 0.000, 78.2),
        ("kernel DMA写BRAM数据", 0.003, 94.2),
        ("kernel group宽度控制", 0.003, 49.0),
        ("kernel DMA写BRAM地址", 0.009, 90.4),
        ("kernel BRAM到PE", 0.013, 59.4),
        ("PS FIFO写RAM", 0.042, 94.7),
        ("bias缓存写入", 0.091, 64.8),
    ]
    fig, ax = plt.subplots(figsize=(8.8, 5.0), constrained_layout=True)
    labels = [row[0] for row in current_paths]
    slacks = [row[1] for row in current_paths]
    colors = ["#dc2626" if value <= 0.003 else "#2563eb" for value in slacks]
    ax.barh(labels, slacks, color=colors)
    ax.invert_yaxis()
    ax.set_xlabel("最差 slack(ns)")
    ax.set_title("当前通过实现中的剩余紧路径族")
    style_axis(ax)
    for idx, (_, slack, route_pct) in enumerate(current_paths):
        ax.text(slack + 0.004, idx, f"{slack:.3f} ns, route {route_pct:.1f}%", va="center", fontsize=8)
    fig.savefig(OUT_DIR / "timing_opt_current_path_families.png")
    plt.close(fig)

    resources = [
        ("biaspipe\nprphys", 32474, 33315),
        ("pathbatch\nv1", 27534, 27786),
    ]
    fig, ax = plt.subplots(figsize=(6.6, 4.4), constrained_layout=True)
    xs = list(range(len(resources)))
    width = 0.34
    ax.bar([x - width / 2 for x in xs], [row[1] for row in resources], width,
           label="Slice LUT", color="#2563eb")
    ax.bar([x + width / 2 for x in xs], [row[2] for row in resources], width,
           label="Slice FF", color="#f59e0b")
    ax.set_xticks(xs, [row[0] for row in resources])
    ax.set_ylabel("资源数量")
    ax.set_title("时序优化后资源未反弹")
    style_axis(ax)
    ax.legend(frameon=False)
    fig.savefig(OUT_DIR / "timing_opt_resource_check.png")
    plt.close(fig)


if __name__ == "__main__":
    main()
