#!/usr/bin/env python3
"""Regenerate Chinese-labelled legacy plots referenced by performance_report_cn.md."""

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


def style(ax) -> None:
    ax.grid(True, alpha=0.25)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)


def plot_cache_sweep() -> None:
    dims = [64, 96, 128, 192, 224, 256]
    data = {
        "IA cache=2": [108577, 241008, 453189, 1173994, 1713502, 2392617],
        "IA cache=4": [98283, 206528, 371787, 900206, 1279170, 1744729],
        "IA cache=8": [93179, 194957, 331013, 762978, 1092294, 1419987],
    }
    fig, ax = plt.subplots(figsize=(7.2, 4.2), constrained_layout=True)
    for label, cycles in data.items():
        ax.plot(dims, [v / 1e6 for v in cycles], marker="o", linewidth=2, label=label)
    ax.set_xlabel("矩阵尺寸 K=N=M")
    ax.set_ylabel("周期（百万）")
    ax.set_title("新版 IA cache 大小对周期的影响（WS）")
    style(ax)
    ax.legend()
    fig.savefig(OUT_DIR / "cache_cycles_by_dim_df0.png")
    plt.close(fig)

    base = data["IA cache=2"]
    fig, ax = plt.subplots(figsize=(7.2, 4.2), constrained_layout=True)
    for label in ["IA cache=4", "IA cache=8"]:
        ax.plot(dims, [base[i] / data[label][i] for i in range(len(dims))],
                marker="o", linewidth=2, label=f"{label} 相对 C2")
    ax.set_xlabel("矩阵尺寸 K=N=M")
    ax.set_ylabel("加速比")
    ax.set_title("IA cache 增大后的周期加速比（WS）")
    style(ax)
    ax.legend()
    fig.savefig(OUT_DIR / "cache_speedup_vs_c2_df0.png")
    plt.close(fig)


def plot_tflm_old_new() -> None:
    cases = ["HelloWorld", "MicroSpeech", "自定义模型", "PersonDetection"]
    old_cycles = [2337257, 16295115, 500000000, 800000000]
    new_cycles = [425071, 15590371, 77111410, 238905507]
    x = range(len(cases))
    width = 0.34
    fig, ax = plt.subplots(figsize=(8.2, 4.4), constrained_layout=True)
    ax.bar([i - width / 2 for i in x], old_cycles, width, label="旧版/timeout 上限", color="#dc2626")
    ax.bar([i + width / 2 for i in x], new_cycles, width, label="新版", color="#2563eb")
    ax.set_yscale("log")
    ax.set_xticks(list(x), cases, rotation=12, ha="right")
    ax.set_ylabel("SoC 周期（对数坐标）")
    ax.set_title("TFLM 模型新旧版本周期对比")
    style(ax)
    ax.legend()
    fig.savefig(OUT_DIR / "tflm_old_new_cycles.png")
    plt.close(fig)


def plot_rand_latency() -> None:
    dims = ["7x13x5", "17x31x33", "33x47x29"]
    s8 = {
        "C2": [24133, 86368, 145948],
        "C4": [24134, 80221, 129071],
        "C8": [24134, 73928, 120806],
    }
    s16 = {
        "C2": [24131, 79319, 127676],
        "C4": [24132, 73201, 119441],
        "C8": [24132, 73201, 111205],
    }
    fig, axes = plt.subplots(1, 2, figsize=(11.0, 4.2), constrained_layout=True)
    for ax, title, data in zip(axes, ["SIZE=8", "SIZE=16"], [s8, s16]):
        for label, cycles in data.items():
            ax.plot(dims, [v / 1000.0 for v in cycles], marker="o", linewidth=2, label=f"IA cache={label[1:]}")
        ax.set_ylabel("周期（千）")
        ax.set_title(f"随机 DDR 延迟下 {title} cache 对比")
        style(ax)
        ax.legend()
        ax.tick_params(axis="x", rotation=15)
    fig.savefig(OUT_DIR / "cache_rand_latency_cycles.png")
    plt.close(fig)


def plot_tflm_threshold() -> None:
    thresholds = ["0", "8192", "12288", "16384", "32768"]
    soc_cycles = [77016232, 76566886, 79017550, 79017550, 95263158]
    mma_active = [469134, 469134, 447670, 447670, 368318]
    x = range(len(thresholds))
    fig, ax0 = plt.subplots(figsize=(8.0, 4.3), constrained_layout=True)
    ax0.bar(x, [v / 1e6 for v in soc_cycles], color="#2563eb", label="SoC 周期")
    ax0.set_xticks(list(x), thresholds)
    ax0.set_xlabel("TFLM_SOC_MMA_MIN_MACS")
    ax0.set_ylabel("SoC 周期（百万）")
    ax0.set_title("my_model 最小 MAC 阈值扫描")
    style(ax0)
    ax1 = ax0.twinx()
    ax1.plot(x, [v / 1000 for v in mma_active], marker="o", color="#dc2626", label="MMA 活跃周期")
    ax1.set_ylabel("MMA 活跃周期（千）")
    lines, labels = ax0.get_legend_handles_labels()
    lines2, labels2 = ax1.get_legend_handles_labels()
    ax0.legend(lines + lines2, labels + labels2, loc="upper left")
    fig.savefig(OUT_DIR / "tflm_min_macs_threshold_sweep.png")
    plt.close(fig)


def plot_soc_tflm_fc() -> None:
    cases = ["HelloWorld", "MicroSpeech", "自定义模型"]
    before = [430815, 15720062, 77016620]
    after = [372504, 13659301, 74079370]
    x = range(len(cases))
    width = 0.34
    fig, ax = plt.subplots(figsize=(8.0, 4.3), constrained_layout=True)
    ax.bar([i - width / 2 for i in x], before, width, label="修复前", color="#dc2626")
    ax.bar([i + width / 2 for i in x], after, width, label="noinit + FC-MMA 后", color="#2563eb")
    ax.set_yscale("log")
    ax.set_xticks(list(x), cases, rotation=12, ha="right")
    ax.set_ylabel("SoC 周期（对数坐标）")
    ax.set_title("SoC TFLM noinit 与 FC-MMA 优化效果")
    style(ax)
    ax.legend()
    fig.savefig(OUT_DIR / "soc_tflm_fc_noinit_cycles.png")
    plt.close(fig)


def plot_bias_prefetch() -> None:
    configs = ["基线", "trigger 旁路 + bias 预取"]
    weight_stall = [127844, 132198]
    ia_stall = [382, 382]
    bias_stall = [14037, 11218]
    x = range(len(configs))
    fig, ax = plt.subplots(figsize=(7.0, 4.2), constrained_layout=True)
    ax.bar(x, weight_stall, label="W 数据等待", color="#4d79b6")
    ax.bar(x, ia_stall, bottom=weight_stall, label="IA 数据等待", color="#69a77b")
    bottom = [a + b for a, b in zip(weight_stall, ia_stall)]
    ax.bar(x, bias_stall, bottom=bottom, label="bias 等待", color="#cc6f4a")
    ax.set_xticks(list(x), configs)
    ax.set_ylabel("周期")
    ax.set_title("控制器旁路与 bias 预取的等待分解")
    style(ax)
    ax.legend()
    fig.savefig(OUT_DIR / "soc_bias_prefetch_stalls.png")
    plt.close(fig)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    configure_chinese_font()
    plot_cache_sweep()
    plot_tflm_old_new()
    plot_rand_latency()
    plot_tflm_threshold()
    plot_soc_tflm_fc()
    plot_bias_prefetch()


if __name__ == "__main__":
    main()
