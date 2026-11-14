#!/usr/bin/env python3
"""Generate Chinese-labelled plots for the FPGA area optimization report."""

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

    stages = [
        ("初始", 77837, 74469),
        ("同步RAM", 53573, 49262),
        ("PS宽FIFO", 48780, 44469),
        ("SRL反对角", 44867, 40556),
        ("bias优化", 42655, 38346),
        ("面积策略", 36499, 32980),
        ("OA索引", 35889, 32201),
        ("路由完成", 32844, 28183),
    ]

    fig, ax = plt.subplots(figsize=(9.2, 4.8), constrained_layout=True)
    xs = list(range(len(stages)))
    ax.plot(xs, [row[1] for row in stages], marker="o", linewidth=2, label="SoC 顶层 LUT")
    ax.plot(xs, [row[2] for row in stages], marker="s", linewidth=2, label="MMA 核心 LUT")
    ax.axhline(35000, color="#dc2626", linestyle="--", linewidth=1, label="35k 目标线")
    ax.axhline(40000, color="#f59e0b", linestyle="--", linewidth=1, label="40k 目标线")
    ax.set_xticks(xs, [row[0] for row in stages], rotation=15, ha="right")
    ax.set_ylabel("Slice LUT")
    ax.set_title("面积优化阶段 LUT 演进")
    style_axis(ax)
    ax.legend(frameon=False, ncols=2)
    fig.savefig(OUT_DIR / "area_opt_lut_evolution.png")
    plt.close(fig)

    modules = [
        ("计算核心", 7174),
        ("AXI DMA/仲裁", 4545),
        ("kernel loader", 2277),
        ("bias loader", 2020),
        ("IA loader", 1266),
        ("OA writer", 813),
        ("OA FIFO", 406),
    ]
    fig, ax = plt.subplots(figsize=(8.0, 4.8), constrained_layout=True)
    ax.barh([m[0] for m in modules], [m[1] for m in modules], color="#2563eb")
    ax.invert_yaxis()
    ax.set_xlabel("Slice LUT")
    ax.set_title("最终已完成实现中的 MMA 关键模块 LUT 构成")
    style_axis(ax)
    for idx, (_, value) in enumerate(modules):
        ax.text(value + 90, idx, f"{value}", va="center", fontsize=9)
    fig.savefig(OUT_DIR / "area_opt_key_modules.png")
    plt.close(fig)

    old_new = [
        ("OA FIFO", 20964, 406),
        ("kernel loader", 11432, 2277),
        ("bias loader", 3491, 2020),
        ("IA loader", 1637, 1266),
        ("MMA 核心", 74469, 28183),
    ]
    fig, ax = plt.subplots(figsize=(8.4, 4.8), constrained_layout=True)
    xs = list(range(len(old_new)))
    width = 0.34
    ax.bar([x - width / 2 for x in xs], [row[1] for row in old_new], width,
           label="优化前", color="#dc2626")
    ax.bar([x + width / 2 for x in xs], [row[2] for row in old_new], width,
           label="优化后", color="#16a34a")
    ax.set_yscale("log")
    ax.set_xticks(xs, [row[0] for row in old_new], rotation=12, ha="right")
    ax.set_ylabel("Slice LUT（对数坐标）")
    ax.set_title("关键模块优化前后面积对比")
    style_axis(ax)
    ax.legend(frameon=False)
    fig.savefig(OUT_DIR / "area_opt_module_before_after.png")
    plt.close(fig)


if __name__ == "__main__":
    main()
