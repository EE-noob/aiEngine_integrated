#!/usr/bin/env python3
"""Generate editable verification diagrams and measured-result plots."""
from pathlib import Path
import json

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.colors import ListedColormap
import numpy as np

import draw_figures as diagram

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "test_figures"


def save_plot(fig, name):
    fig.savefig(OUT / (name + ".svg"), bbox_inches="tight", facecolor="white")
    fig.savefig(OUT / (name + ".png"), dpi=300, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def main():
    OUT.mkdir(exist_ok=True)
    diagram.OUT = OUT
    results = json.loads((ROOT / "test_results.json").read_text())
    audits = []
    d = diagram.Diagram("图01-分层测试结构", 1480, 700)
    for x, key, title, line, color in (
        (40, "rtl", "NPU RTL 验证", "矩阵计算与 AXI 访问", "blue"),
        (540, "soc", "PicoRV32 联合仿真", "TFLM 与硬件共同执行", "yellow"),
        (1040, "fpga", "MicroBlaze FPGA 实现", "资源统计与时序检查", "green")):
        d.node(key, x, 60, 400, 140, title, line, color=color, size=31)
        d.node(key+"_out", x, 350, 400, 140,
               {"rtl":"12 个 RTL 用例", "soc":"8 组数值、3 组周期", "fpga":"125 MHz 主时钟"}[key],
               {"rtl":"72 461 周期逐项比较", "soc":"模型输出与调用统计", "fpga":"布局及布线结果"}[key],
               color=color, size=30)
        d.edge(key, key+"_out", (x+200, 200), (x+200, 350))
    d.label(740, 590, "结果按测试对象、模型结构和时钟条件分别统计", size=32)
    audits.append(d.render())

    d = diagram.Diagram("图02-模型数值比较流程", 1500, 660)
    d.node("samples", 40, 240, 280, 150, "固定输入样本", "相同特征与量化参数", color="blue", size=29)
    d.node("dut", 500, 70, 430, 150, "PicoRV32 + TFLM + NPU", "执行原始 RTL 并写回输出", color="yellow", size=30)
    d.node("expected", 500, 440, 430, 150, "电脑端预期结果", "预先生成量化整数输出", color="green", size=30)
    d.node("compare", 1110, 240, 350, 150, "逐样本、逐输出比较", "统计整数差异与最大值", color="blue", size=30)
    d.edge("samples", "dut", (180,240), (180,145), (500,145))
    d.edge("samples", "expected", (180,390), (180,515), (500,515), color="green")
    d.edge("dut", "compare", (930,145), (1285,145), (1285,240))
    d.edge("expected", "compare", (930,515), (1285,515), (1285,390), color="green")
    audits.append(d.render())

    plot_font = "/usr/share/fonts/Fonts/simhei.ttf"
    font_manager.fontManager.addfont(plot_font)
    plt.rcParams.update({"font.family":font_manager.FontProperties(fname=plot_font).get_name(), "font.size":14,
                         "svg.fonttype":"none", "axes.spines.top":False,
                         "axes.spines.right":False, "axes.unicode_minus":False})
    values = np.abs(np.array(results["multi_input_model"]["signed_delta"]))
    fig, ax = plt.subplots(figsize=(9.6,4.1), layout="constrained")
    ax.imshow(values.T, cmap=ListedColormap(["#E8F3E5", "#FFD97D"]), vmin=0, vmax=1, aspect="auto")
    ax.set_xticks(range(8), [str(i) for i in range(8)])
    ax.set_yticks(range(3), ["湿度", "电压", "电流"])
    ax.set_xlabel("样本编号")
    for i in range(3):
        for j in range(8):
            ax.text(j, i, str(values[j,i]), ha="center", va="center", fontsize=20, weight="bold")
    ax.set_xticks(np.arange(-.5,8,1), minor=True)
    ax.set_yticks(np.arange(-.5,3,1), minor=True)
    ax.grid(which="minor", color="white", linewidth=3)
    ax.tick_params(which="minor", bottom=False, left=False)
    fig.suptitle("量化整数输出绝对差异 / LSB", weight="bold")
    save_plot(fig, "图03-模型输出整数差异")

    fig, ax = plt.subplots(figsize=(10.8,5.3), layout="constrained")
    resources = results["fpga"]["resources"]
    labels = ["LUT", "寄存器", "BRAM", "UltraRAM", "DSP"]
    ypos = np.arange(len(labels))
    percentages = [r["percent"] for r in resources]
    ax.barh(ypos, [100]*5, color="#F0F0F0", height=.57)
    ax.barh(ypos, percentages, color=["#8AC5DF", "#8AC5DF", "#F6D46C", "#93C78F", "#8AC5DF"], height=.57)
    ax.set_yticks(ypos, labels)
    ax.invert_yaxis()
    ax.set_xlim(0,147)
    ax.set_xticks([0,25,50,75,100], ["0", "25", "50", "75", "100"])
    ax.set_xlabel("相对于器件可用总量的使用比例 / %")
    ax.spines[["bottom", "left"]].set_visible(False)
    ax.tick_params(axis="y", length=0)
    for i,r in enumerate(resources):
        ax.text(104, i, f'{r["percent"]:.2f}%  ({r["used"]:g}/{r["available"]:g})', va="center", fontsize=13)
    save_plot(fig, "图05-FPGA资源使用比例")

    fig, ax = plt.subplots(figsize=(9.6,4.0), layout="constrained")
    cycles = results["compact_model"]["invoke_cycles"]
    ax.bar(range(3), cycles, width=.5, color=["#8AC5DF", "#F6D46C", "#93C78F"])
    ax.set_ylim(0,112000)
    ax.set_xticks(range(3), ["样本 0", "样本 1", "样本 2"])
    ax.set_yticks([0,25000,50000,75000,100000])
    ax.set_ylabel("Invoke 调用周期数")
    ax.grid(axis="y", alpha=.2)
    ax.set_axisbelow(True)
    for i,v in enumerate(cycles):
        ax.text(i,v+3000, f"{v:,}", ha="center", weight="bold")
    save_plot(fig, "图04-模型调用周期统计")
    (ROOT / "test_diagram_audit.json").write_text(json.dumps({"diagrams":audits,
        "result_plots":3,"source_data":"test_results.json"}, ensure_ascii=False,indent=2)+"\n")
    print("测试插图生成完成：2 幅流程图、3 幅结果图，均包含 SVG 与 PNG。")


if __name__ == "__main__":
    main()
