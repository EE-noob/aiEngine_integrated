#!/usr/bin/env python3
"""Generate vector and raster figures used by the throughput report."""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
import numpy as np
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

HERE = Path(__file__).resolve().parent
OUT = HERE / "figures"
OUT.mkdir(exist_ok=True)
for font in ["Source Han Sans CN", "Noto Sans CJK SC", "WenQuanYi Zen Hei", "MiSans"]:
    try:
        f = font_manager.findfont(font, fallback_to_default=False)
        plt.rcParams["font.family"] = font_manager.FontProperties(fname=f).get_name()
        break
    except Exception:
        continue
plt.rcParams.update({"axes.unicode_minus": False, "font.size": 10, "svg.fonttype": "none"})

def save(fig, name):
    fig.savefig(OUT / f"{name}.svg", bbox_inches="tight")
    fig.savefig(OUT / f"{name}.png", dpi=220, bbox_inches="tight")
    plt.close(fig)

# 1. Data movement and tile reuse.
fig, ax = plt.subplots(figsize=(11, 4.8)); ax.set_xlim(0, 11); ax.set_ylim(0, 5); ax.axis("off")
boxes = [
 (0.25,2.0,1.75,1.15,"外部存储器\nAXI 32/64 bit","#e8eef7"),
 (2.65,3.15,2.2,1.15,"IA tile cache\nA tile 驻留并复用","#d9eee7"),
 (2.65,.75,2.2,1.15,"W tile buffer\n权重按输出列复用","#f8e8ce"),
 (6.0,1.55,2.2,1.65,"16 × 16\n脉动阵列\n256 MAC/cycle","#e9ddf3"),
 (9.1,1.8,1.65,1.15,"部分和 /\n输出缓存","#f4dddd")]
for x,y,w,h,label,color in boxes:
 ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0.04,rounding_size=0.08",facecolor=color,edgecolor="#344054",linewidth=1.3))
 ax.text(x+w/2,y+h/2,label,ha="center",va="center",fontsize=11,weight="medium")
def arrow(a,b,text,dy=0,color="#344054"):
 ax.add_patch(FancyArrowPatch(a,b,arrowstyle="-|>",mutation_scale=13,linewidth=1.5,color=color))
 ax.text((a[0]+b[0])/2,(a[1]+b[1])/2+dy,text,ha="center",va="center",fontsize=9,color=color,bbox={"facecolor":"white","edgecolor":"none","alpha":.85,"pad":1})
arrow((2.0,2.65),(2.65,3.55),"每 tile 搬入",.22); arrow((2.0,2.45),(2.65,1.35),"每 tile 搬入",-.22)
arrow((4.85,3.7),(6.0,2.7),"A：向多个输出列 tile 重放",.3,"#26734d")
arrow((4.85,1.35),(6.0,2.05),"W：跨多个输出行 tile 复用",-.34,"#9a5b00")
arrow((8.2,2.35),(9.1,2.35),"累加结果",.2)
ax.text(5.5,4.65,"一次外存读取，片上缓存保存 tile；调度把同一 tile 分发给多个计算 tile",ha="center",fontsize=12,weight="bold")
ax.text(5.5,.25,"缓存降低外部搬运量；阵列内部的行/列传播完成每个操作数对 16 个 PE 的空间复用。",ha="center",fontsize=9,color="#475467")
save(fig,"fig01_dataflow_reuse")

# 2. Peak input requirement vs one-beat bus bandwidth.
fig, ax = plt.subplots(figsize=(9.4,5.2)); labels=["阵列峰值输入需求","32 bit 总线\n1 beat/cycle","64 bit 总线\n1 beat/cycle"]
vals=[32,4,8]; colors=["#6741a5","#3c78a8","#e29a34"]
bars=ax.bar(labels,vals,color=colors,width=.58); ax.set_ylabel("外部 s8 数据需求 / 带宽（byte/cycle）")
ax.set_title("16×16 int8 脉动阵列的峰值供数需求与单拍总线能力",weight="bold",pad=14)
ax.set_ylim(0,37); ax.grid(axis="y",alpha=.25)
for bar,v in zip(bars,vals): ax.text(bar.get_x()+bar.get_width()/2,v+.7,f"{v} B/cycle",ha="center",weight="bold")
ax.text(0,23,"256 MAC/cycle\n每拍注入 16 个 A + 16 个 W\n= 32 byte/cycle",ha="center",va="center",color="white",fontsize=10,weight="bold")
ax.annotate("需要 8× 时间复用\n（理想总线效率）",xy=(1,4),xytext=(1,12),ha="center",arrowprops={"arrowstyle":"->","color":"#344054"},fontsize=9)
ax.annotate("需要 4× 时间复用\n（理想总线效率）",xy=(2,8),xytext=(2,16),ha="center",arrowprops={"arrowstyle":"->","color":"#344054"},fontsize=9)
ax.text(.5,-.20,"若有效传输效率为 η，需求倍率分别为 8/η 与 4/η；AXI outstanding 隐藏延迟，但不改变每拍带宽。",transform=ax.transAxes,ha="center",fontsize=9,color="#475467")
save(fig,"fig02_bandwidth_requirement")

# 3. Capacity and default reuse as cache blocks grow.
fig, ax1 = plt.subplots(figsize=(9.5,5.3)); c=np.array([2,4,8,16,32,64]); cap=c*16*16*2/1024; reuse=c/2
ax1.plot(c,cap,"o-",lw=2.4,color="#26734d",label="IA cache 容量（每元素 16 bit）")
ax1.set_xscale("log",base=2); ax1.set_xticks(c,labels=[str(x) for x in c]); ax1.set_xlabel("IA_CACHE_BLOCKS（每块一个 16×16 tile）")
ax1.set_ylabel("IA cache 容量（KiB）",color="#26734d"); ax1.tick_params(axis="y",labelcolor="#26734d"); ax1.grid(alpha=.22)
ax2=ax1.twinx(); ax2.plot(c,reuse,"s--",lw=2.2,color="#b35c00",label="默认 IA reuse 上限约为 blocks/2")
ax2.set_ylabel("IA reuse 深度（tile）",color="#b35c00"); ax2.tick_params(axis="y",labelcolor="#b35c00")
ax1.set_title("阵列为 16×16 时 cache 容量与可配置复用深度",weight="bold",pad=14)
ax1.axvline(16,color="#475467",ls=":",lw=1.5); ax1.text(16.7,1.2,"C16：8 KiB IA cache\n默认 reuse=8",fontsize=9,color="#344054")
ax1.axvline(32,color="#475467",ls=":",lw=1.5); ax1.text(33.5,2.55,"C32：16 KiB IA cache\n默认 reuse=16",fontsize=9,color="#344054")
h1,l1=ax1.get_legend_handles_labels(); h2,l2=ax2.get_legend_handles_labels(); ax1.legend(h1+h2,l1+l2,loc="upper left",frameon=True)
fig.text(.5,.01,"单独 IA cache 容量 = blocks × SIZE² × 2 byte；配对 A/W tile 的逻辑预算约为其两倍。",ha="center",fontsize=9,color="#475467")
save(fig,"fig03_cache_capacity_reuse")

# 4. Recorded project sweep results at 512^3.
fig, ax1 = plt.subplots(figsize=(9.5,5.1)); configs=["S4/C256","S8/C64","S16/C16","S32/C4"]
gops=[6.18,22.85,60.91,44.53]; util=[96.50,89.26,59.48,10.87]; x=np.arange(len(configs))
bars=ax1.bar(x,gops,color=["#80bfa1","#5ca6a0","#506fa8","#cb7956"],width=.58)
ax1.set_xticks(x,configs); ax1.set_ylabel("MMA active 吞吐（GOPS，200 MHz 等效）")
ax1.set_title("固定约 16 KiB A/W tile 存储预算下的 512³ sweep",weight="bold",pad=14)
ax1.grid(axis="y",alpha=.22); ax1.set_ylim(0,75)
for b,v in zip(bars,gops): ax1.text(b.get_x()+b.get_width()/2,v+1,f"{v:.2f}",ha="center",fontsize=9,weight="bold")
ax2=ax1.twinx(); ax2.plot(x,util,"D--",color="#a34747",lw=2,ms=7,label="阵列活跃利用率")
ax2.set_ylabel("阵列活跃利用率（%）",color="#a34747"); ax2.tick_params(axis="y",labelcolor="#a34747"); ax2.set_ylim(0,110)
for xi,v in zip(x,util): ax2.text(xi,v+4,f"{v:.1f}%",ha="center",fontsize=8,color="#8b3434")
ax2.legend(loc="upper right")
fig.text(.5,.01,"数据摘自项目既有性能报告的固定容量 sweep 表；原始 perf.csv 当前未随工作树提供。",ha="center",fontsize=8.5,color="#475467")
save(fig,"fig04_sweep_evidence")
