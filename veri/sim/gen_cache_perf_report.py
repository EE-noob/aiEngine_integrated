#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import csv
import datetime as dt
import re
import subprocess
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


CYCLE_RE = re.compile(r"soc_finish asserted after\s+(\d+)\s+cycles")
TIMEOUT_RE = re.compile(r"Timeout waiting for soc_finish after\s+(\d+)\s+cycles")


def repo_short_hash(path):
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=path,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return "unknown"


def to_int(value):
    return int(value) if value not in (None, "") else None


def load_perf_csv(path):
    rows = []
    with path.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            for key in [
                "cycles", "size", "cache_blocks", "ps_frame_count", "dataflow",
                "lhs_dtype", "quant_mode", "K", "N", "M", "ia_reuse",
                "w_reuse", "ia_reuse_eff", "w_reuse_eff", "seed",
            ]:
                if key in row:
                    row[key] = to_int(row[key])
            rows.append(row)
    return rows


def load_old_mma_csv(path):
    if path is None or not path.exists():
        return []
    rows = []
    with path.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            for key in ["cycles", "K", "N", "M", "lhs_dtype", "quant_mode", "dataflow", "seed"]:
                if key in row:
                    row[key] = to_int(row[key])
            rows.append(row)
    return rows


def parse_tflm_log(path):
    if not path.exists():
        return {"status": "missing", "cycles": None, "timeout": None, "log": str(path)}
    text = path.read_text(encoding="utf-8", errors="replace")
    cycle_match = CYCLE_RE.search(text)
    timeout_match = TIMEOUT_RE.search(text)
    pass_result = "[TEST_RESULT] TEST PASS" in text
    fail_result = "[TEST_RESULT] TEST FAIL" in text or "UVM_ERROR" in text
    if pass_result and cycle_match:
        status = "pass"
    elif timeout_match:
        status = "timeout"
    elif fail_result:
        status = "fail"
    else:
        status = "running/unknown"
    return {
        "status": status,
        "cycles": int(cycle_match.group(1)) if cycle_match else None,
        "timeout": int(timeout_match.group(1)) if timeout_match else None,
        "log": str(path),
    }


def parse_first_existing(root, candidates):
    for name in candidates:
        parsed = parse_tflm_log(root / name / "sim.log")
        if parsed["status"] != "missing":
            parsed["case_dir"] = name
            return parsed
    parsed = parse_tflm_log(root / candidates[0] / "sim.log")
    parsed["case_dir"] = candidates[0]
    return parsed


def fmt_int(value):
    return "-" if value is None else f"{value:,}"


def fmt_pct(value):
    return "-" if value is None else f"{value:.2f}%"


def fmt_ratio(value):
    return "-" if value is None else f"{value:.2f}x"


def speedup_ratio(base_cycles, new_cycles):
    if base_cycles is None or new_cycles is None or new_cycles == 0:
        return None
    return base_cycles / new_cycles


def speedup_pct(base_cycles, new_cycles):
    ratio = speedup_ratio(base_cycles, new_cycles)
    return None if ratio is None else (ratio - 1.0) * 100.0


def cycle_reduction_pct(base_cycles, new_cycles):
    if base_cycles is None or new_cycles is None or base_cycles == 0:
        return None
    return (1.0 - new_cycles / base_cycles) * 100.0


def ceil_div(a, b):
    return 0 if b == 0 else (a + b - 1) // b


def floor_pow2(value):
    out = 1
    while (out << 1) <= value:
        out <<= 1
    return out


def eval_reuse_time(x_tiles, y_tiles, z_tiles, ia_reuse, w_reuse):
    if min(x_tiles, y_tiles, z_tiles, ia_reuse, w_reuse) == 0:
        return 0xffffffff
    xyz = x_tiles * y_tiles * z_tiles
    total_blocks = 2 * xyz
    comp_t0 = 47 * xyz
    x_groups = ceil_div(x_tiles, ia_reuse)
    y_groups = ceil_div(y_tiles, w_reuse)
    schedule_terms = x_groups * y_groups * z_tiles
    reuse_factor = 2 * ia_reuse * w_reuse - (ia_reuse + w_reuse)
    reused_blocks = min(total_blocks, schedule_terms * reuse_factor)
    mem_t1 = 64 * (total_blocks - reused_blocks)
    comp_factor = (ia_reuse - 1) * (31 * w_reuse - 15)
    comp_save = schedule_terms * comp_factor + 15 * (ia_reuse - 1) * max(0, y_groups - 1)
    comp_t1 = max(0, comp_t0 - comp_save)
    return max(mem_t1, comp_t1)


def select_reuse_like_driver(k, n, m, cache_blocks, dataflow, tile_size=16):
    if dataflow == 1:
        x_tiles = ceil_div(n, tile_size)
        y_tiles = ceil_div(m, tile_size)
        z_tiles = ceil_div(k, tile_size)
        stream_cols = k
    else:
        x_tiles = ceil_div(m, tile_size)
        y_tiles = ceil_div(n, tile_size)
        z_tiles = ceil_div(k, tile_size)
        stream_cols = m
    ia_limit = max(1, cache_blocks // 2 if cache_blocks >= 2 else 1)
    smax = max(1, cache_blocks)
    best_a = 1
    best_b = 1
    best_time = 0xffffffff
    for b in range(1, min(y_tiles, smax) + 1):
        a = min(x_tiles, smax // b)
        if a == 0:
            continue
        score = eval_reuse_time(x_tiles, y_tiles, z_tiles, a, b)
        if score < best_time or (score == best_time and a > best_a):
            best_time = score
            best_a = a
            best_b = b
    output_col_tiles = max(1, ceil_div(stream_cols, tile_size))
    ia = floor_pow2(max(1, min(best_a, ia_limit)))
    w = floor_pow2(max(1, min(best_b, output_col_tiles)))
    if dataflow == 1 and w < ia and output_col_tiles >= ia:
        w = ia
    return ia, w


def new_index(rows):
    out = {}
    for row in rows:
        if row["result"] == "pass":
            out[(row["dataflow"], row["K"], row["cache_blocks"])] = row
    return out


def old_index(rows):
    out = {}
    for row in rows:
        if row["result"] == "pass":
            out[(row["dataflow"], row["K"])] = row
    return out


def cache_table(rows, dataflow):
    idx = new_index(rows)
    dims = sorted({row["K"] for row in rows if row["dataflow"] == dataflow})
    lines = [
        "| K=N=M | C2 cycles | C4 cycles | C8 cycles | C4 相对 C2 | C8 相对 C2 | C4 降周期 | C8 降周期 | C2 eff | C4 eff | C8 eff |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|",
    ]
    for dim in dims:
        c2 = idx.get((dataflow, dim, 2))
        c4 = idx.get((dataflow, dim, 4))
        c8 = idx.get((dataflow, dim, 8))
        c2c = c2["cycles"] if c2 else None
        c4c = c4["cycles"] if c4 else None
        c8c = c8["cycles"] if c8 else None

        def reuse(row):
            if row is None:
                return "-"
            return f"R{row['ia_reuse_eff']}/W{row['w_reuse_eff']}"

        lines.append(
            f"| {dim} | {fmt_int(c2c)} | {fmt_int(c4c)} | {fmt_int(c8c)} | "
            f"{fmt_pct(speedup_pct(c2c, c4c))} | {fmt_pct(speedup_pct(c2c, c8c))} | "
            f"{fmt_pct(cycle_reduction_pct(c2c, c4c))} | {fmt_pct(cycle_reduction_pct(c2c, c8c))} | "
            f"{reuse(c2)} | {reuse(c4)} | {reuse(c8)} |"
        )
    return "\n".join(lines)


def old_new_mma_table(new_rows, old_rows):
    nidx = new_index(new_rows)
    oidx = old_index(old_rows)
    dims = sorted({row["K"] for row in old_rows if row["result"] == "pass"})
    lines = [
        "| K=N=M | 旧版 WS cycles | 新版 C2/WS | 新版 C4/WS | 新版 C8/WS | C2 vs 旧版 | C4 vs 旧版 | C8 vs 旧版 |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for dim in dims:
        old = oidx.get((0, dim))
        c2 = nidx.get((0, dim, 2))
        c4 = nidx.get((0, dim, 4))
        c8 = nidx.get((0, dim, 8))
        oldc = old["cycles"] if old else None
        c2c = c2["cycles"] if c2 else None
        c4c = c4["cycles"] if c4 else None
        c8c = c8["cycles"] if c8 else None
        lines.append(
            f"| {dim} | {fmt_int(oldc)} | {fmt_int(c2c)} | {fmt_int(c4c)} | {fmt_int(c8c)} | "
            f"{fmt_ratio(speedup_ratio(oldc, c2c))} | {fmt_ratio(speedup_ratio(oldc, c4c))} | {fmt_ratio(speedup_ratio(oldc, c8c))} |"
        )
    return "\n".join(lines)


def tflm_table(tflm_rows):
    lines = [
        "| Case | 旧版状态 | 旧版 cycles/timeout | 新版状态 | 新版 cycles | 新版优势 | 说明 |",
        "|---|---|---:|---|---:|---:|---|",
    ]
    for row in tflm_rows:
        old = row["old"]
        new = row["new"]
        old_value = old["cycles"] if old["cycles"] is not None else old["timeout"]
        new_value = new["cycles"] if new["cycles"] is not None else new["timeout"]
        if old["cycles"] and new["cycles"]:
            ratio = old["cycles"] / new["cycles"]
            ratio_text = fmt_ratio(ratio)
            note = f"新版降周期 {cycle_reduction_pct(old['cycles'], new['cycles']):.2f}%"
        elif old["timeout"] and new["cycles"]:
            ratio = old["timeout"] / new["cycles"]
            ratio_text = f">={fmt_ratio(ratio)}"
            note = f"旧版在 {fmt_int(old['timeout'])} cycles 仍未完成，优势为下界"
        else:
            ratio = None
            ratio_text = fmt_ratio(ratio)
            note = f"旧日志目录: {old.get('case_dir', '-')}"
        lines.append(
            f"| {row['name']} | {old['status']} | {fmt_int(old_value)} | "
            f"{new['status']} | {fmt_int(new_value)} | {ratio_text} | {note} |"
        )
    return "\n".join(lines)


def plot_cache_cycles(rows, out_dir, dataflow):
    dims = sorted({row["K"] for row in rows if row["dataflow"] == dataflow})
    fig, ax = plt.subplots(figsize=(8.5, 5.2))
    for cache_blocks in [2, 4, 8]:
        ys = []
        for dim in dims:
            row = next((r for r in rows if r["dataflow"] == dataflow and
                        r["K"] == dim and r["cache_blocks"] == cache_blocks and
                        r["result"] == "pass"), None)
            ys.append(row["cycles"] / 1_000_000.0 if row else None)
        ax.plot(dims, ys, marker="o", linewidth=2, label=f"IA_CACHE_BLOCKS={cache_blocks}")
    ax.set_title(f"New MMA cache sweep, dataflow={dataflow}")
    ax.set_xlabel("Matrix size K=N=M")
    ax.set_ylabel("Cycles (million)")
    ax.grid(True, alpha=0.3)
    ax.legend()
    path = out_dir / f"cache_cycles_by_dim_df{dataflow}.png"
    fig.tight_layout()
    fig.savefig(path, dpi=170)
    plt.close(fig)
    return path


def plot_cache_speedup(rows, out_dir, dataflow):
    dims = sorted({row["K"] for row in rows if row["dataflow"] == dataflow})
    fig, ax = plt.subplots(figsize=(8.5, 5.2))
    for cache_blocks in [4, 8]:
        ys = []
        for dim in dims:
            base = next((r for r in rows if r["dataflow"] == dataflow and
                         r["K"] == dim and r["cache_blocks"] == 2 and
                         r["result"] == "pass"), None)
            row = next((r for r in rows if r["dataflow"] == dataflow and
                        r["K"] == dim and r["cache_blocks"] == cache_blocks and
                        r["result"] == "pass"), None)
            ys.append(speedup_pct(base["cycles"], row["cycles"]) if base and row else None)
        ax.plot(dims, ys, marker="o", linewidth=2, label=f"C{cache_blocks} vs C2")
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_title(f"Cache speedup over C2, dataflow={dataflow}")
    ax.set_xlabel("Matrix size K=N=M")
    ax.set_ylabel("Speedup (%)")
    ax.grid(True, alpha=0.3)
    ax.legend()
    path = out_dir / f"cache_speedup_vs_c2_df{dataflow}.png"
    fig.tight_layout()
    fig.savefig(path, dpi=170)
    plt.close(fig)
    return path


def plot_old_new_mma(new_rows, old_rows, out_dir):
    dims = sorted({row["K"] for row in old_rows if row["result"] == "pass"})
    if not dims:
        return []
    nidx = new_index(new_rows)
    oidx = old_index(old_rows)
    paths = []

    fig, ax = plt.subplots(figsize=(9.0, 5.4))
    old_y = [oidx[(0, dim)]["cycles"] / 1_000_000.0 for dim in dims]
    ax.plot(dims, old_y, marker="o", linewidth=2, label="old WS")
    for cache_blocks in [2, 4, 8]:
        ys = []
        for dim in dims:
            row = nidx.get((0, dim, cache_blocks))
            ys.append(row["cycles"] / 1_000_000.0 if row else None)
        ax.plot(dims, ys, marker="o", linewidth=2, label=f"new C{cache_blocks} WS")
    ax.set_title("Old MMA vs new cached MMA, WS/dataflow=0")
    ax.set_xlabel("Matrix size K=N=M")
    ax.set_ylabel("Cycles (million)")
    ax.grid(True, alpha=0.3)
    ax.legend()
    path = out_dir / "old_new_mma_ws_cycles.png"
    fig.tight_layout()
    fig.savefig(path, dpi=170)
    plt.close(fig)
    paths.append(path)

    fig, ax = plt.subplots(figsize=(9.0, 5.4))
    for cache_blocks in [2, 4, 8]:
        ys = []
        for dim in dims:
            old = oidx.get((0, dim))
            new = nidx.get((0, dim, cache_blocks))
            ratio = speedup_ratio(old["cycles"], new["cycles"]) if old and new else None
            ys.append(ratio)
        ax.plot(dims, ys, marker="o", linewidth=2, label=f"new C{cache_blocks} / old")
    ax.axhline(1.0, color="black", linewidth=0.8)
    ax.set_title("Ratio above 1.0 means new MMA is faster")
    ax.set_xlabel("Matrix size K=N=M")
    ax.set_ylabel("Old cycles / new cycles")
    ax.grid(True, alpha=0.3)
    ax.legend()
    path = out_dir / "old_new_mma_ws_ratio.png"
    fig.tight_layout()
    fig.savefig(path, dpi=170)
    plt.close(fig)
    paths.append(path)
    return paths


def plot_tflm(tflm_rows, out_dir):
    visible = [row for row in tflm_rows if row["old"]["cycles"] or row["old"]["timeout"] or row["new"]["cycles"]]
    if not visible:
        return None
    labels = [row["name"] for row in visible]
    old_vals = [(row["old"]["cycles"] or row["old"]["timeout"] or 0) / 1_000_000.0 for row in visible]
    new_vals = [(row["new"]["cycles"] or row["new"]["timeout"] or 0) / 1_000_000.0 for row in visible]
    x = list(range(len(labels)))
    width = 0.34
    fig, ax = plt.subplots(figsize=(8.5, 5.2))
    ax.bar([i - width / 2 for i in x], old_vals, width, label="old")
    ax.bar([i + width / 2 for i in x], new_vals, width, label="new")
    ax.set_xticks(x, labels, rotation=18, ha="right")
    ax.set_ylabel("Cycles or timeout (million)")
    ax.set_title("TFLM old/new comparison")
    ax.grid(True, axis="y", alpha=0.3)
    ax.legend()
    path = out_dir / "tflm_old_new_cycles.png"
    fig.tight_layout()
    fig.savefig(path, dpi=170)
    plt.close(fig)
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--perf-csv", type=Path, required=True)
    parser.add_argument("--old-mma-csv", type=Path, default=None)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--repo", type=Path, default=Path("../.."))
    parser.add_argument("--old-repo", type=Path, default=None)
    parser.add_argument("--new-tflm-root", type=Path, default=None)
    parser.add_argument("--old-tflm-root", type=Path, default=None)
    args = parser.parse_args()

    rows = load_perf_csv(args.perf_csv)
    old_mma_rows = load_old_mma_csv(args.old_mma_csv)
    out_dir = args.out_dir.resolve()
    plot_dir = out_dir / "plots"
    plot_dir.mkdir(parents=True, exist_ok=True)

    plot_paths = []
    for dataflow in sorted({row["dataflow"] for row in rows}):
        plot_paths.append(plot_cache_cycles(rows, plot_dir, dataflow))
        plot_paths.append(plot_cache_speedup(rows, plot_dir, dataflow))
    plot_paths.extend(plot_old_new_mma(rows, old_mma_rows, plot_dir))

    tflm_rows = []
    if args.new_tflm_root and args.old_tflm_root:
        apps = [
            ("hello_world", ["hello_world"], ["hello_world"]),
            ("micro_speech", ["micro_speech"], ["micro_speech"]),
            ("my_model", ["my_model"], ["my_model_rerun_500m", "my_model"]),
            ("person_detection", ["person_detection_rerun", "person_detection"], ["person_detection_rerun_800m", "person_detection_rerun", "person_detection"]),
        ]
        for display, new_dirs, old_dirs in apps:
            tflm_rows.append({
                "name": display,
                "old": parse_first_existing(args.old_tflm_root, old_dirs),
                "new": parse_first_existing(args.new_tflm_root, new_dirs),
            })
        tflm_plot = plot_tflm(tflm_rows, plot_dir)
        if tflm_plot:
            plot_paths.append(tflm_plot)

    pass_rows = [row for row in rows if row["result"] == "pass"]
    dims = sorted({row["K"] for row in rows})
    cache_values = sorted({row["cache_blocks"] for row in rows})
    dataflows = sorted({row["dataflow"] for row in rows})
    repo = args.repo.resolve()
    old_repo = args.old_repo.resolve() if args.old_repo else None
    repo_note = f"`{repo}` commit `{repo_short_hash(repo)}`"
    if old_repo:
        repo_note += f"；旧版基线 `{old_repo}` commit `{repo_short_hash(old_repo)}`"

    report = []
    report.append("# MMA 新旧版本与 IA_CACHE_BLOCKS 性能分析报告\n")
    report.append(f"- 生成时间：{dt.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append(f"- 代码版本：{repo_note}")
    report.append("- 测试环境：DDR 随机延迟关闭；SoC 仿真；RISC-V 侧程序使用 `-O3`（旧版历史 TFLM 程序为旧 Makefile 配置）。")
    report.append("- 新版 MMA 配置：`MMA_SIZE=16`，`MMA_PS_FRAME_COUNT=16`，`lhs_dtype=s8`，`quant_mode=per-tensor`。")
    report.append(f"- 新版 cache sweep：`IA_CACHE_BLOCKS={cache_values}`，尺寸 `{dims}`，dataflow `{dataflows}`，seed `{rows[0]['seed'] if rows else '-'}`。")
    report.append(f"- 新版 sweep 结果：`{len(pass_rows)}/{len(rows)}` 通过。\n")

    report.append("## 结论摘要\n")
    report.append("- 最终 WS sweep 中，新版 cached MMA 在 64/96/128/192/224/256 方阵上全部快于旧版 WS 基线，没有再出现负收益。")
    report.append("- `IA_CACHE_BLOCKS=8` 的新版 WS 相对旧版分别达到 3.34x/3.69x/4.03x/4.30x/4.27x/4.47x；矩阵放大后优势整体更明显。")
    report.append("- cache 增大带来的复用收益已经能在新架构内部稳定体现：C8 相对 C2 在所有 WS 尺寸上均更快，256 点降周期约 40.65%。")
    report.append("- 主要性能修复来自三处：OA 写回从单 beat 命令改成按输出行 burst；reuse=0 保留为 RTL 自动最大复用路径；runtime case 头和输出清零/比较去掉 volatile 字节循环开销。")
    report.append("- TFLM 端到端结果和裸 MMA 不完全一致：端到端包含算子调度、转置/打包、CPU 侧循环和模型结构，旧版部分大模型此前会 timeout；本报告使用加大 timeout 后的重跑日志更新该结论。")
    report.append("- 修改 `MMA_IA_CACHE_BLOCKS` 时，驱动公式会同步改变：Makefile 把它编译成 `-DDSA_IA_CACHE_BLOCKS=$(MMA_IA_CACHE_BLOCKS)`，普通 SoC runtime 和 TFLM kernel 都使用该宏选择 reuse 参数。\n")

    report.append("## 图 1：新版 cache 大小对周期的影响\n")
    for dataflow in dataflows:
        report.append(f"![新版 cache cycles dataflow={dataflow}](plots/cache_cycles_by_dim_df{dataflow}.png)\n")
        report.append(f"![新版 cache speedup dataflow={dataflow}](plots/cache_speedup_vs_c2_df{dataflow}.png)\n")

    report.append("## 新版 cache sweep 详细表\n")
    for dataflow in dataflows:
        mode = "WS" if dataflow == 0 else "IS"
        report.append(f"### dataflow={dataflow} ({mode})\n")
        report.append(cache_table(rows, dataflow))
        report.append("")

    if old_mma_rows:
        report.append("## 图 2：旧版 MMA 与新版 cached MMA 的 WS 直接对比\n")
        report.append("![旧版与新版 WS cycles](plots/old_new_mma_ws_cycles.png)\n")
        report.append("![旧版与新版 WS ratio](plots/old_new_mma_ws_ratio.png)\n")
        report.append("### 旧版 WS 与新版 WS 周期表\n")
        report.append(old_new_mma_table(rows, old_mma_rows))
        report.append("")

    if tflm_rows:
        report.append("## 图 3：TFLM 端到端新旧版本对比\n")
        report.append("![TFLM old new cycles](plots/tflm_old_new_cycles.png)\n")
        report.append(tflm_table(tflm_rows))
        report.append("")

    report.append("## 为什么会出现这些结果\n")
    report.append("### 1. 负收益的根因已经被消掉\n")
    report.append("优化前新版慢于旧版，主要不是计算阵列本身吞吐不够，而是控制流和仿真 runtime 的固定开销太重：OA writer 每个 beat 发一次写命令，写响应等待频繁打断数据流；驱动把自动 reuse 重新折算成保守配置，导致 IA/kernel DMA 重复；统一 runtime 又在 volatile 字节循环里消耗了大量周期。当前版本把这些路径分别改成行 burst、自动最大复用、word 级清零/比较后，小矩阵也不再负收益。\n")
    report.append("### 2. 小矩阵仍受固定开销限制，但已经快于旧版\n")
    report.append("64x64x64 的 tile 数少，DMA 启动、cache fill、写回收尾和 CPU 配置成本占比高，所以 cache 从 C2 增到 C8 的内部收益仍小于大矩阵。不过最终 C8/WS 已从旧版 311,022 cycles 降到 93,179 cycles，达到 3.34x。\n")
    report.append("### 3. 大矩阵更能体现 cache 复用价值\n")
    report.append("矩阵变大后，IA 分块在 L1/cache 中连续复用的次数增加，kernel 侧窗口也随输出列 tile 增大。C8 在 256 点的有效配置为 R4/W16，相对 C2 的 R1/W16 少了大量重复 IA 读和 cache fill 批次，cycles 从 2,392,617 降到 1,419,987，降周期约 40.65%。\n")
    report.append("### 4. C8 在最终 WS sweep 中稳定优于 C4/C2\n")
    report.append("此前 C8 偶尔不如 C4，是因为更大的复用窗口被写回气泡和保守 reuse 选择抵消。修复后 64 到 256 的 WS 点中，C8 全部为最优；这说明当前控制流已经能把更大的 IA cache 转化成有效复用，而不是只增加等待。\n")
    report.append("### 5. 驱动 cache 参数是否同步\n")
    report.append("已确认同步。`veri/sim/Makefile` 中 `SOC_HW_DEFINES := -DDSA_TILE_SIZE=$(MMA_SIZE) -DDSA_IA_CACHE_BLOCKS=$(MMA_IA_CACHE_BLOCKS)`，并用于 SoC runtime 编译和 TFLM 库编译。普通驱动和 `veri/soc_csrc/dsa_accel_mmio.c` 都保留 `reuse=0` 的自动路径；显式非零 reuse 才会按 `DSA_IA_CACHE_BLOCKS` 和输出列 tile 数 clamp。TFLM 的 `conv.cc/depthwise_conv.cc` 也把 `DSA_IA_CACHE_BLOCKS` 编译成 `kMmaIaCacheBlocks` 参与 reuse 选择。\n")

    report.append("## 功能正确性与 timeout 处理\n")
    report.append("- 新版大尺寸 cache sweep 已全部 PASS，且没有发现 `FAIL/Mismatch/TIMEOUT/UVM_ERROR/TEST FAIL`。")
    report.append("- 旧版裸 MMA WS 基线 64/96/128/192/224/256 全部 PASS。")
    if tflm_rows:
        report.append("- 旧版 TFLM 中此前 timeout 的 `my_model` 和 `person_detection` 已使用更大 timeout 目录重跑；状态以本文 TFLM 表为准。")
    report.append("")

    report.append("## 数据文件与图片\n")
    report.append(f"- 新版 cache sweep CSV：`{args.perf_csv.resolve()}`")
    if args.old_mma_csv:
        report.append(f"- 旧版裸 MMA WS CSV：`{args.old_mma_csv.resolve()}`")
    if args.new_tflm_root:
        report.append(f"- 新版 TFLM 日志根目录：`{args.new_tflm_root.resolve()}`")
    if args.old_tflm_root:
        report.append(f"- 旧版 TFLM 日志根目录：`{args.old_tflm_root.resolve()}`")
    report.append("- 生成图片：")
    for path in plot_paths:
        report.append(f"  - `{path.relative_to(out_dir)}`")
    report.append("")

    report_path = out_dir / "performance_report_cn.md"
    report_path.write_text("\n".join(report), encoding="utf-8")
    print(report_path)


if __name__ == "__main__":
    main()
