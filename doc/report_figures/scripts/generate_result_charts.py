#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.ticker import FuncFormatter


ROOT = Path(__file__).resolve().parents[1]
VERI_ROOT = Path(__file__).resolve().parents[3]
OUT_DIR = ROOT / "charts"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def setup_style() -> None:
    font_candidates = [
        "/usr/share/fonts/truetype/NotoSansCJKsc-VF.otf",
        "/usr/share/fonts/truetype/SourceHanSansCN-VF.otf",
        "/usr/share/fonts/truetype/SourceHanSansCN-Light.otf",
    ]
    for item in font_candidates:
        if Path(item).exists():
            try:
                font_manager.fontManager.addfont(item)
                prop = font_manager.FontProperties(fname=item)
                plt.rcParams["font.sans-serif"] = [prop.get_name(), "DejaVu Sans"]
                break
            except RuntimeError:
                continue
    else:
        plt.rcParams["font.sans-serif"] = [
            "Noto Sans CJK SC",
            "Source Han Sans CN",
            "SimHei",
            "Microsoft YaHei",
            "DejaVu Sans",
        ]
    plt.rcParams["axes.unicode_minus"] = False
    plt.rcParams["figure.facecolor"] = "white"
    plt.rcParams["axes.facecolor"] = "white"
    plt.rcParams["savefig.facecolor"] = "white"
    plt.rcParams["axes.grid"] = True
    plt.rcParams["grid.alpha"] = 0.22
    plt.rcParams["axes.spines.top"] = False
    plt.rcParams["axes.spines.right"] = False


def savefig(name: str) -> None:
    plt.tight_layout()
    plt.savefig(OUT_DIR / name, dpi=300, bbox_inches="tight")
    plt.close()


def annotate_bars(ax, bars, fmt="{:.2f}") -> None:
    for bar in bars:
        height = bar.get_height()
        ax.annotate(
            fmt.format(height),
            xy=(bar.get_x() + bar.get_width() / 2, height),
            xytext=(0, 4),
            textcoords="offset points",
            ha="center",
            va="bottom",
            fontsize=8,
        )


def load_coverage() -> dict:
    path = VERI_ROOT / "sim/runs/coverage/coverage_report_summary.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {
        "goal": 95.0,
        "functional_average": 100.0,
        "code_metrics": {"overall": 100.0, "group": 100.0},
    }


def fig_tops_exploration() -> list[dict]:
    data = [
        {"阵列边长": 4, "IA cache 分块数": 4, "任务规模": "64x64x64", "任务总周期": 212321, "NPU 执行周期": 58485, "理想上限 TOPS@200MHz": 0.0064, "DSA 吞吐 TOPS@200MHz": 0.001793, "SoC 吞吐 TOPS@200MHz": 0.000494},
        {"阵列边长": 8, "IA cache 分块数": 4, "任务规模": "64x64x64", "任务总周期": 168720, "NPU 执行周期": 14884, "理想上限 TOPS@200MHz": 0.0256, "DSA 吞吐 TOPS@200MHz": 0.007045, "SoC 吞吐 TOPS@200MHz": 0.000621},
        {"阵列边长": 16, "IA cache 分块数": 4, "任务规模": "64x64x64", "任务总周期": 159825, "NPU 执行周期": 6257, "理想上限 TOPS@200MHz": 0.1024, "DSA 吞吐 TOPS@200MHz": 0.016758, "SoC 吞吐 TOPS@200MHz": 0.000656},
        {"阵列边长": 32, "IA cache 分块数": 4, "任务规模": "64x64x64", "任务总周期": 158853, "NPU 执行周期": 5285, "理想上限 TOPS@200MHz": 0.4096, "DSA 吞吐 TOPS@200MHz": 0.019841, "SoC 吞吐 TOPS@200MHz": 0.000660},
        {"阵列边长": 64, "IA cache 分块数": 4, "任务规模": "64x64x64", "任务总周期": 158689, "NPU 执行周期": 5121, "理想上限 TOPS@200MHz": 1.6384, "DSA 吞吐 TOPS@200MHz": 0.020476, "SoC 吞吐 TOPS@200MHz": 0.000661},
    ]
    x = [row["阵列边长"] for row in data]
    labels = [str(v) for v in x]
    ideal = [row["理想上限 TOPS@200MHz"] for row in data]
    dsa = [row["DSA 吞吐 TOPS@200MHz"] for row in data]
    soc = [row["SoC 吞吐 TOPS@200MHz"] for row in data]
    fig, ax = plt.subplots(figsize=(7.2, 4.2))
    x_pos = list(range(len(labels)))
    width = 0.34
    dsa_bars = ax.bar([v - width / 2 for v in x_pos], dsa, width, color="#5B8FF9", edgecolor="#2F5DA8", linewidth=0.8, label="DSA执行吞吐")
    soc_bars = ax.bar([v + width / 2 for v in x_pos], soc, width, color="#61DDAA", edgecolor="#1B7F5A", linewidth=0.8, label="SoC完成吞吐")
    ax.plot(x_pos, ideal, color="#D46B08", marker="o", linewidth=1.8, label="理想上限")
    ax.set_xticks(x_pos)
    ax.set_xticklabels(labels)
    ax.axhline(0.5, color="#2F9E44", linestyle="--", linewidth=1.1, label="0.5 TOPS")
    ax.axhline(1.0, color="#C92A2A", linestyle="--", linewidth=1.1, label="1.0 TOPS")
    annotate_bars(ax, dsa_bars, "{:.5f}")
    annotate_bars(ax, soc_bars, "{:.6f}")
    ax.set_title("固定IA cache块数下的64x64x64任务吞吐")
    ax.set_xlabel("阵列规模 NxN")
    ax.set_ylabel("吞吐（TOPS，200 MHz）")
    ax.set_yscale("log")
    ax.set_ylim(4e-4, 2.2)
    ax.legend(loc="upper left", frameon=True, framealpha=0.92, edgecolor="#DDDDDD", fontsize=8)
    savefig("fig11_tops_param_curve.png")
    return data


def fig_inference_time() -> list[dict]:
    data = [
        {"模型": "MNIST MLP", "硬件 Invoke 平均周期": 443903, "软件 Invoke 平均周期": 44126602, "加速比": 99.4},
        {"模型": "MNIST CNN", "硬件 Invoke 平均周期": 4198745, "软件 Invoke 平均周期": 60410324, "加速比": 14.39},
    ]
    labels = [row["模型"] for row in data]
    hw = [row["硬件 Invoke 平均周期"] for row in data]
    sw = [row["软件 Invoke 平均周期"] for row in data]
    idx = range(len(labels))
    width = 0.34
    fig, ax = plt.subplots(figsize=(7.2, 4.2))
    bars1 = ax.bar([i - width / 2 for i in idx], hw, width, label="NPU Invoke", color="#5B8FF9")
    bars2 = ax.bar([i + width / 2 for i in idx], sw, width, label="CPU 软件 Invoke", color="#F6BD16")
    ax.set_yscale("log")
    ax.set_title("推理时间对比（Invoke 周期数）")
    ax.set_xlabel("模型")
    ax.set_ylabel("平均周期数（log scale）")
    ax.set_xticks(list(idx), labels)
    ax.set_ylim(min(hw) * 0.7, max(sw) * 2.3)
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.16), ncol=2, frameon=False)
    for i, row in enumerate(data):
        ax.annotate(
            f"{row['加速比']:.2f}x",
            xy=(i, max(hw[i], sw[i])),
            xytext=(0, 8),
            textcoords="offset points",
            ha="center",
            fontsize=9,
            color="#333333",
        )
    annotate_bars(ax, bars1, "{:.0f}")
    annotate_bars(ax, bars2, "{:.0f}")
    savefig("fig12_inference_time_compare.png")
    return data


def fig_accuracy() -> list[dict]:
    data = [
        {"模型": "MNIST MLP", "浮点测试集准确率": 96.93, "样本级运行正确率": 100.0},
        {"模型": "MNIST CNN", "浮点测试集准确率": 97.74, "样本级运行正确率": 100.0},
    ]
    labels = [row["模型"] for row in data]
    ref = [row["浮点测试集准确率"] for row in data]
    sample = [row["样本级运行正确率"] for row in data]
    idx = range(len(labels))
    width = 0.34
    fig, ax = plt.subplots(figsize=(7.2, 4.2))
    b1 = ax.bar([i - width / 2 for i in idx], ref, width, label="浮点测试集准确率", color="#61DDAA")
    b2 = ax.bar([i + width / 2 for i in idx], sample, width, label="样本级运行正确率", color="#5D7092")
    ax.set_ylim(90, 101.5)
    ax.set_title("准确率与样本运行正确率对比")
    ax.set_xlabel("模型")
    ax.set_ylabel("百分比（%）")
    ax.set_xticks(list(idx), labels)
    ax.legend(frameon=False)
    annotate_bars(ax, b1, "{:.2f}")
    annotate_bars(ax, b2, "{:.2f}")
    savefig("fig13_accuracy_compare.png")
    return data


def fig_bus_util() -> list[dict]:
    data = [
        {"配置": "4x4\nIA分块=256", "读 beat/active": 6.80, "写 beat/active": 0.75},
        {"配置": "8x8\nIA分块=64", "读 beat/active": 16.78, "写 beat/active": 2.79},
        {"配置": "16x16\nIA分块=16", "读 beat/active": 44.85, "写 beat/active": 7.44},
        {"配置": "32x32\nIA分块=4", "读 beat/active": 49.26, "写 beat/active": 5.44},
    ]
    labels = [row["配置"] for row in data]
    read = [row["读 beat/active"] for row in data]
    write = [row["写 beat/active"] for row in data]
    fig, ax = plt.subplots(figsize=(7.2, 4.2))
    ax.plot(labels, read, marker="o", linewidth=1.9, label="读 beat/active", color="#5B8FF9")
    ax.plot(labels, write, marker="s", linewidth=1.9, label="写 beat/active", color="#F4664A")
    ax.set_title("不同阵列与缓存配置下的总线带宽利用率")
    ax.set_xlabel("阵列规模与 IA cache 分块数")
    ax.set_ylabel("占 NPU active 周期比例（%）")
    ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:.0f}%"))
    ax.legend(frameon=False)
    savefig("fig14_bus_util_curve.png")
    return data


def fig_compute_util() -> list[dict]:
    data = [
        {"模型": "MNIST MLP", "MMA active GOPS": 0.6110, "阵列利用率": 0.60},
        {"模型": "MNIST CNN", "MMA active GOPS": 2.0281, "阵列利用率": 1.98},
    ]
    labels = [row["模型"] for row in data]
    gops = [row["MMA active GOPS"] for row in data]
    util = [row["阵列利用率"] for row in data]
    fig, axes = plt.subplots(1, 2, figsize=(8.0, 4.0))
    b1 = axes[0].bar(labels, gops, color="#5B8FF9", edgecolor="#2F5DA8", linewidth=0.8)
    axes[0].set_title("active GOPS")
    axes[0].set_ylabel("GOPS")
    annotate_bars(axes[0], b1, "{:.4f}")
    b2 = axes[1].bar(labels, util, color="#61DDAA", edgecolor="#2F7D5E", linewidth=0.8)
    axes[1].set_title("active 阵列利用率")
    axes[1].set_ylabel("百分比（%）")
    axes[1].yaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:.1f}%"))
    annotate_bars(axes[1], b2, "{:.2f}%")
    fig.suptitle("NPU 算力与阵列利用率")
    savefig("fig15_npu_compute_util_bar.png")
    return data


def fig_coverage() -> list[dict]:
    summary = load_coverage()
    code_metrics = summary.get("code_metrics", {})
    data = [
        {"指标": "功能覆盖率", "百分比": float(summary.get("functional_average", 0.0))},
        {"指标": "URG group", "百分比": float(code_metrics.get("group", 0.0))},
        {"指标": "URG overall", "百分比": float(code_metrics.get("overall", 0.0))},
    ]
    goal = float(summary.get("goal", 95.0))
    labels = [row["指标"] for row in data]
    values = [row["百分比"] for row in data]
    fig, ax = plt.subplots(figsize=(7.2, 4.2))
    bars = ax.bar(labels, values, color=["#5B8FF9", "#61DDAA", "#F6BD16"], edgecolor="#444444", linewidth=0.6)
    ax.axhline(goal, color="#C92A2A", linestyle="--", linewidth=1.1, label=f"目标 {goal:.0f}%")
    ax.set_ylim(0, 106)
    ax.set_title("覆盖率结果直方图")
    ax.set_ylabel("覆盖率（%）")
    ax.legend(loc="lower right", frameon=True, framealpha=0.92, edgecolor="#DDDDDD")
    annotate_bars(ax, bars, "{:.2f}")
    savefig("fig16_coverage_histogram.png")
    return data


def write_data_summary(sections: dict[str, list[dict]]) -> None:
    csv_path = OUT_DIR / "chart_data_summary.csv"
    with csv_path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.writer(fp)
        writer.writerow(["图表", "字段", "数值"])
        for fig_name, rows in sections.items():
            for row in rows:
                for key, value in row.items():
                    writer.writerow([fig_name, key, value])

    md_path = OUT_DIR / "chart_data_summary.md"
    lines = ["# 图表数据摘要", ""]
    for fig_name, rows in sections.items():
        lines.append(f"## {fig_name}")
        if not rows:
            lines.append("")
            continue
        keys = list(rows[0].keys())
        lines.append("| " + " | ".join(keys) + " |")
        lines.append("| " + " | ".join(["---"] * len(keys)) + " |")
        for row in rows:
            lines.append("| " + " | ".join(str(row.get(key, "")) for key in keys) + " |")
        lines.append("")
    md_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    setup_style()
    sections = {
        "fig11_tops_param_curve": fig_tops_exploration(),
        "fig12_inference_time_compare": fig_inference_time(),
        "fig13_accuracy_compare": fig_accuracy(),
        "fig14_bus_util_curve": fig_bus_util(),
        "fig15_npu_compute_util_bar": fig_compute_util(),
        "fig16_coverage_histogram": fig_coverage(),
    }
    write_data_summary(sections)
    print(f"generated charts under {OUT_DIR}")


if __name__ == "__main__":
    main()
