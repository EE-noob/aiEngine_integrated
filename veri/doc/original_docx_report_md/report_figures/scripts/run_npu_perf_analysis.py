#!/usr/bin/env python3
import argparse
import csv
import math
import os
import re
import subprocess
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


DOC_ROOT = Path(__file__).resolve().parents[2]
CHART_DIR = DOC_ROOT / "report_figures" / "charts"
DATA_DIR = DOC_ROOT / "perf_data"
DEFAULT_REPO = Path(os.environ.get("TFLM_DSA_ROOT", "/home/etc/FPGA/tflm_ai_dsa"))
FREQ_MHZ = 200.0
WORD_BYTES = 4
SIZES = [4, 8, 16, 32, 64]
MAIN_DIM = 256

KV_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)=(-?\d+)")
NPU_UTIL_RE = re.compile(r"\[NPU_UTIL\]\s+(.*)")
NPU_CTRL_UTIL_RE = re.compile(r"\[NPU_CTRL_UTIL\]\s+(.*)")
PASS_RE = re.compile(r"\[TB\]\s+PASS")


CSV_COLUMNS = [
    "experiment",
    "label",
    "size",
    "cache_blocks",
    "ps_frame_count",
    "target_capacity_bytes",
    "actual_capacity_bytes",
    "capacity_exact",
    "K",
    "N",
    "M",
    "result",
    "cycles",
    "ops",
    "gops_200mhz",
    "ideal_gops_200mhz",
    "array_util_pct",
    "bus_beat_util_pct",
    "bus_read_util_pct",
    "bus_write_util_pct",
    "read_beats",
    "write_beats",
    "total_beats",
    "bytes_per_op",
    "acc_util_pct",
    "ia_row_util_pct",
    "fifo_full",
    "weight_data_stall",
    "fifo_stall",
    "ia_done_wait",
    "log",
]


def ceil_div(a, b):
    return (a + b - 1) // b


def parse_kv(text):
    return {key: int(value) for key, value in KV_RE.findall(text)}


def run_command(cmd, cwd, log_path, timeout):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", encoding="utf-8", errors="replace") as log_file:
        proc = subprocess.Popen(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        lines = []
        try:
            assert proc.stdout is not None
            for line in proc.stdout:
                lines.append(line)
                log_file.write(line)
            code = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            code = 124
            lines.append(f"\n[TIMEOUT] exceeded {timeout} seconds\n")
            log_file.write(lines[-1])
    return code, "".join(lines)


def build_jobs():
    jobs = []

    # 1. 固定 cache 块数，观察阵列规模上限趋势。
    for size in SIZES:
        jobs.append(
            {
                "experiment": "scale_c32",
                "label": f"scale_c32_S{size}",
                "size": size,
                "cache_blocks": 32,
                "ps_frame_count": ceil_div(MAIN_DIM, size),
                "target_capacity_bytes": 0,
                "K": MAIN_DIM,
                "N": MAIN_DIM,
                "M": MAIN_DIM,
            }
        )

    # 2. 固定 IA cache 存储容量。4 KiB 对应 SIZE=16、IA_CACHE_BLOCKS=4；
    #    16 KiB 对应 SIZE=4、IA_CACHE_BLOCKS=256；64 KiB 作为更深缓存参考。
    for cap in [4 * 1024, 16 * 1024, 64 * 1024]:
        for size in SIZES:
            block_bytes = size * size * WORD_BYTES
            cache_blocks = max(2, cap // block_bytes)
            jobs.append(
                {
                    "experiment": f"fixed_{cap // 1024}kib",
                    "label": f"fixed_{cap // 1024}kib_S{size}_C{cache_blocks}",
                    "size": size,
                    "cache_blocks": cache_blocks,
                    "ps_frame_count": ceil_div(MAIN_DIM, size),
                    "target_capacity_bytes": cap,
                    "K": MAIN_DIM,
                    "N": MAIN_DIM,
                    "M": MAIN_DIM,
                }
            )

    # 3. 额外总线供给工况：固定 SIZE=16，改变矩阵尺寸和 IA cache 深度。
    for dim in [64, 128, 256]:
        for cache_blocks in [4, 16, 32]:
            jobs.append(
                {
                    "experiment": "s16_dim_cache_bus",
                    "label": f"bus_S16_C{cache_blocks}_{dim}",
                    "size": 16,
                    "cache_blocks": cache_blocks,
                    "ps_frame_count": ceil_div(dim, 16),
                    "target_capacity_bytes": 0,
                    "K": dim,
                    "N": dim,
                    "M": dim,
                }
            )

    return jobs


def read_existing(csv_path):
    if not csv_path.exists():
        return {}
    rows = {}
    with csv_path.open("r", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            rows[row["label"]] = row
    return rows


def write_rows(csv_path, rows):
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    ordered = sorted(rows.values(), key=lambda r: (r["experiment"], int(r["K"]), int(r["size"]), int(r["cache_blocks"])))
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_COLUMNS)
        writer.writeheader()
        for row in ordered:
            writer.writerow({key: row.get(key, "") for key in CSV_COLUMNS})


def run_one(job, repo_root, build_root, case_root, log_root, build_jobs_value, timeout):
    sim_dir = repo_root / "test" / "npu_top"
    size = job["size"]
    cache_blocks = job["cache_blocks"]
    ps_frame_count = job["ps_frame_count"]
    label = job["label"]

    build_log = log_root / f"{label}_build.log"
    build_cmd = [
        "make",
        "build_only",
        f"SIZE={size}",
        f"IA_CACHE_BLOCKS={cache_blocks}",
        f"PS_FRAME_COUNT={ps_frame_count}",
        "AXI_READ_OUTSTANDING=4",
        "TRACE=0",
        f"BUILD_ROOT={build_root}",
        f"VERILATOR_BUILD_JOBS={build_jobs_value}",
    ]
    code, build_output = run_command(build_cmd, sim_dir, build_log, timeout)
    if code != 0:
        return failure_row(job, "compile_fail", build_log)

    case_dir = case_root / label
    case_dir.mkdir(parents=True, exist_ok=True)
    gen_log = log_root / f"{label}_gen.log"
    gen_cmd = [
        "python3",
        "gen_mem.py",
        "--out_dir",
        str(case_dir),
        "--size",
        str(size),
        "--ia_cache_blocks",
        str(cache_blocks),
        "--ps_frame_count",
        str(ps_frame_count),
        "--K",
        str(job["K"]),
        "--N",
        str(job["N"]),
        "--M",
        str(job["M"]),
        "--lhs_dtype",
        "1",
        "--ia_reuse_num",
        "0",
        "--w_reuse_num",
        "0",
        "--seed",
        "20260703",
    ]
    code, gen_output = run_command(gen_cmd, sim_dir, gen_log, timeout)
    if code != 0:
        return failure_row(job, "gen_fail", gen_log)

    bin_path = (
        sim_dir
        / build_root
        / f"s{size}_c{cache_blocks}_ps{ps_frame_count}_ro4_notrace"
        / "sim_npu_top"
    )
    sim_log = log_root / f"{label}_sim.log"
    sim_cmd = [
        str(bin_path),
        f"+INIT_MEM={case_dir / 'init.mem'}",
        f"+GOLDEN_MEM={case_dir / 'golden.mem'}",
        f"+CASE_MEM={case_dir / 'config.mem'}",
        "+NPU_UTIL_TRACE",
        "+NPU_UTIL_SUNPURY",
        "+TB_TIMEOUT_CYCLES=20000000",
    ]
    code, sim_output = run_command(sim_cmd, sim_dir, sim_log, timeout)
    if code != 0 or not PASS_RE.search(sim_output):
        return failure_row(job, "sim_fail", sim_log)

    util = {}
    ctrl = {}
    for line in sim_output.splitlines():
        match = NPU_UTIL_RE.search(line)
        if match:
            util = parse_kv(match.group(1))
        match = NPU_CTRL_UTIL_RE.search(line)
        if match:
            ctrl = parse_kv(match.group(1))
    if not util:
        return failure_row(job, "missing_util", sim_log)
    return result_row(job, util, ctrl, sim_log)


def failure_row(job, result, log_path):
    size = job["size"]
    cache_blocks = job["cache_blocks"]
    return {
        **job,
        "actual_capacity_bytes": size * size * cache_blocks * WORD_BYTES,
        "capacity_exact": "no",
        "result": result,
        "log": str(log_path),
    }


def result_row(job, util, ctrl, log_path):
    size = job["size"]
    cache_blocks = job["cache_blocks"]
    cycles = util["active"]
    ops = 2 * job["K"] * job["N"] * job["M"]
    gops = ops * FREQ_MHZ / (cycles * 1000.0)
    ideal_gops = 2 * size * size * FREQ_MHZ / 1000.0
    read_beats = util.get("axi_r", 0)
    write_beats = util.get("axi_w", 0)
    total_beats = read_beats + write_beats
    actual_capacity = size * size * cache_blocks * WORD_BYTES
    target_capacity = job["target_capacity_bytes"]
    return {
        **job,
        "actual_capacity_bytes": actual_capacity,
        "capacity_exact": "yes" if (not target_capacity or target_capacity == actual_capacity) else "no",
        "result": "pass",
        "cycles": cycles,
        "ops": ops,
        "gops_200mhz": f"{gops:.3f}",
        "ideal_gops_200mhz": f"{ideal_gops:.3f}",
        "array_util_pct": f"{100.0 * gops / ideal_gops:.2f}",
        "bus_beat_util_pct": f"{100.0 * total_beats / cycles:.2f}",
        "bus_read_util_pct": f"{100.0 * read_beats / cycles:.2f}",
        "bus_write_util_pct": f"{100.0 * write_beats / cycles:.2f}",
        "read_beats": read_beats,
        "write_beats": write_beats,
        "total_beats": total_beats,
        "bytes_per_op": f"{WORD_BYTES * total_beats / ops:.6f}",
        "acc_util_pct": f"{util.get('acc_util_bp', 0) / 100.0:.2f}",
        "ia_row_util_pct": f"{util.get('ia_row_util_bp', 0) / 100.0:.2f}",
        "fifo_full": util.get("fifo_full", 0),
        "weight_data_stall": ctrl.get("weight_data_stall", ""),
        "fifo_stall": ctrl.get("fifo_stall", ""),
        "ia_done_wait": ctrl.get("ia_done_wait", ""),
        "log": str(log_path),
    }


def setup_plot_style():
    plt.rcParams["font.sans-serif"] = ["Noto Sans CJK SC", "Source Han Sans CN", "SimHei", "DejaVu Sans"]
    plt.rcParams["axes.unicode_minus"] = False
    plt.rcParams["figure.dpi"] = 140


def plot_results(csv_path):
    setup_plot_style()
    CHART_DIR.mkdir(parents=True, exist_ok=True)
    df = pd.read_csv(csv_path)
    df = df[df["result"] == "pass"].copy()
    for col in [
        "size",
        "cache_blocks",
        "target_capacity_bytes",
        "actual_capacity_bytes",
        "cycles",
        "gops_200mhz",
        "ideal_gops_200mhz",
        "array_util_pct",
        "bus_beat_util_pct",
        "bus_read_util_pct",
        "bus_write_util_pct",
        "read_beats",
        "write_beats",
        "total_beats",
        "bytes_per_op",
        "acc_util_pct",
        "fifo_full",
    ]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    scale = df[df["experiment"] == "scale_c32"].sort_values("size")
    fig, ax1 = plt.subplots(figsize=(8.8, 5.1))
    x = range(len(scale))
    measured_tops = scale["gops_200mhz"] / 1000.0
    ideal_tops = scale["ideal_gops_200mhz"] / 1000.0
    bars = ax1.bar(
        [idx - 0.16 for idx in x],
        measured_tops,
        width=0.32,
        color="#5b8def",
        edgecolor="#2f62b6",
        linewidth=1.2,
        alpha=0.92,
        label="NPU执行吞吐",
    )
    ax1.plot(
        list(x),
        ideal_tops,
        marker="o",
        markersize=7.5,
        linewidth=2.4,
        color="#d95f02",
        label="理想上限",
    )
    ax1.axhline(0.5, color="#2ca25f", linestyle="--", linewidth=1.8, label="0.5 TOPS")
    ax1.axhline(1.0, color="#d62728", linestyle="--", linewidth=1.8, label="1.0 TOPS")
    for bar, value in zip(bars, measured_tops):
        ax1.text(
            bar.get_x() + bar.get_width() / 2,
            value * 1.12,
            f"{value:.4f}",
            ha="center",
            va="bottom",
            fontsize=10,
        )
    ax1.set_yscale("log")
    ax1.set_xticks(list(x), [str(v) for v in scale["size"]])
    ax1.set_xlabel("阵列规模 N×N")
    ax1.set_ylabel("吞吐（TOPS，200 MHz）")
    ax1.set_title("固定 IA_CACHE_BLOCKS=32 时的 256×256×256 任务吞吐")
    ax1.grid(True, which="major", axis="both", alpha=0.25)
    ax1.set_ylim(max(0.001, measured_tops.min() * 0.55), max(2.5, ideal_tops.max() * 1.25))
    ax1.legend(loc="upper left")
    fig.tight_layout()
    fig.savefig(CHART_DIR / "fig_perf_size_scaling_c32.png")
    fig.savefig(CHART_DIR / "fig11_tops_param_curve.png")
    plt.close(fig)

    fixed = df[df["experiment"].str.startswith("fixed_")].sort_values(["target_capacity_bytes", "size"])
    fig, ax = plt.subplots(figsize=(8.2, 4.8))
    for cap, group in fixed.groupby("target_capacity_bytes"):
        ax.plot(group["size"], group["gops_200mhz"], marker="o", linewidth=2.1, label=f"{int(cap // 1024)} KiB")
    ax.set_xscale("log", base=2)
    ax.set_xticks(SIZES, [str(x) for x in SIZES])
    ax.set_xlabel("脉动阵列 SIZE")
    ax.set_ylabel("实测算力 @200MHz (GOPS)")
    ax.set_title("固定 IA cache 容量下的 SIZE 扫描")
    ax.grid(True, which="both", alpha=0.25)
    ax.legend(title="目标容量")
    fig.tight_layout()
    fig.savefig(CHART_DIR / "fig_perf_fixed_capacity_gops.png")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8.2, 4.8))
    for cap, group in fixed.groupby("target_capacity_bytes"):
        ax.plot(group["size"], group["array_util_pct"], marker="o", linewidth=2.1, label=f"{int(cap // 1024)} KiB")
    ax.set_xscale("log", base=2)
    ax.set_xticks(SIZES, [str(x) for x in SIZES])
    ax.set_xlabel("脉动阵列 SIZE")
    ax.set_ylabel("阵列利用率 (%)")
    ax.set_title("固定 IA cache 容量下的阵列利用率")
    ax.grid(True, which="both", alpha=0.25)
    ax.legend(title="目标容量")
    fig.tight_layout()
    fig.savefig(CHART_DIR / "fig_perf_fixed_capacity_array_util.png")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8.2, 4.8))
    for cap, group in fixed.groupby("target_capacity_bytes"):
        ax.plot(group["size"], group["bus_beat_util_pct"], marker="o", linewidth=2.1, label=f"{int(cap // 1024)} KiB")
    ax.set_xscale("log", base=2)
    ax.set_xticks(SIZES, [str(x) for x in SIZES])
    ax.set_xlabel("脉动阵列 SIZE")
    ax.set_ylabel("AXI 有效 beat / NPU 活跃周期 (%)")
    ax.set_title("固定 IA cache 存储容量、扫描阵列 SIZE 时的总线压力")
    ax.grid(True, which="both", alpha=0.25)
    ax.legend(title="目标容量")
    fig.tight_layout()
    fig.savefig(CHART_DIR / "fig_perf_fixed_capacity_bus_util.png")
    plt.close(fig)

    bus = df[df["experiment"] == "s16_dim_cache_bus"].sort_values(["K", "cache_blocks"])
    fig, ax = plt.subplots(figsize=(8.4, 4.9))
    for cache_blocks, group in bus.groupby("cache_blocks"):
        ax.plot(
            group["K"],
            group["bus_beat_util_pct"],
            marker="o",
            linewidth=2.1,
            label=f"IA_CACHE_BLOCKS={cache_blocks}",
        )
    ax.set_xlabel("方阵尺寸 K=N=M")
    ax.set_ylabel("AXI 有效 beat / NPU 活跃周期 (%)")
    ax.set_title("SIZE=16 时矩阵尺寸与 IA cache 深度对总线利用率的影响")
    ax.grid(True, alpha=0.25)
    ax.legend(title="IA cache 块数")
    fig.tight_layout()
    fig.savefig(CHART_DIR / "fig_perf_s16_bus_util_by_dim_cache.png")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8.4, 4.9))
    for cache_blocks, group in bus.groupby("cache_blocks"):
        ax.plot(
            group["K"],
            group["gops_200mhz"],
            marker="o",
            linewidth=2.1,
            label=f"IA_CACHE_BLOCKS={cache_blocks}",
        )
    ax.set_xlabel("方阵尺寸 K=N=M")
    ax.set_ylabel("实测算力 @200MHz (GOPS)")
    ax.set_title("SIZE=16 时矩阵尺寸与 IA cache 深度对算力的影响")
    ax.grid(True, alpha=0.25)
    ax.legend(title="IA cache 块数")
    fig.tight_layout()
    fig.savefig(CHART_DIR / "fig_perf_s16_gops_by_dim_cache.png")
    plt.close(fig)

    scale.to_csv(CHART_DIR / "table_perf_size_scaling_c32.csv", index=False)
    fixed.to_csv(CHART_DIR / "table_perf_fixed_capacity.csv", index=False)
    bus.to_csv(CHART_DIR / "table_perf_s16_bus_dim_cache.csv", index=False)
    return df


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--csv", type=Path, default=DATA_DIR / "npu_module_perf_20260703.csv")
    parser.add_argument("--force-run", action="store_true")
    parser.add_argument("--skip-run", action="store_true")
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("--build-jobs", type=int, default=int(os.environ.get("VERILATOR_BUILD_JOBS", "8")))
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    sim_dir = repo_root / "test" / "npu_top"
    if not sim_dir.exists():
        raise SystemExit(f"missing NPU top test dir: {sim_dir}")

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    CHART_DIR.mkdir(parents=True, exist_ok=True)
    csv_path = args.csv.resolve()
    rows = read_existing(csv_path)
    expected_jobs = build_jobs()
    expected_labels = {job["label"] for job in expected_jobs}
    rows = {label: row for label, row in rows.items() if label in expected_labels}

    build_root = Path("obj_dir/perf_analysis")
    case_root = sim_dir / "out_perf_analysis"
    log_root = case_root / "logs"

    if not args.skip_run:
        for job in expected_jobs:
            label = job["label"]
            if label in rows and rows[label].get("result") == "pass" and not args.force_run:
                print(f"skip existing pass: {label}")
                continue
            print(f"run {label}: S{job['size']} C{job['cache_blocks']} P{job['ps_frame_count']} "
                  f"{job['K']}x{job['N']}x{job['M']}")
            row = run_one(job, repo_root, build_root, case_root, log_root, args.build_jobs, args.timeout)
            rows[label] = row
            write_rows(csv_path, rows)
            print(f"  -> {row.get('result')} cycles={row.get('cycles', '')} gops={row.get('gops_200mhz', '')}")
            if row.get("result") != "pass":
                raise SystemExit(f"job failed: {label}, log={row.get('log')}")

    write_rows(csv_path, rows)
    plot_results(csv_path)
    print(f"wrote {csv_path}")
    print(f"wrote charts in {CHART_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
