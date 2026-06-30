#!/usr/bin/env python3
import argparse
import concurrent.futures
import csv
import itertools
import re
import shutil
import subprocess
import sys
from pathlib import Path


PASS_RE = re.compile(r"\[TEST_RESULT\]\s+TEST PASS")
CYCLES_RE = re.compile(r"soc_finish asserted after\s+(\d+)\s+cycles")


def parse_int_list(text):
    if text is None:
        return []
    out = []
    for item in re.split(r"[,\s]+", str(text).strip()):
        if item:
            out.append(int(item, 0))
    return out


def parse_dims(text):
    dims = []
    for item in re.split(r"[,\s]+", str(text).strip()):
        if not item:
            continue
        parts = re.split(r"[xX:]", item)
        if len(parts) != 3:
            raise ValueError(f"invalid dim tuple '{item}', expected KxNxM")
        dims.append(tuple(int(part, 0) for part in parts))
    return dims


def powers_of_two_upto(limit):
    values = []
    value = 1
    while value <= max(1, limit):
        values.append(value)
        value <<= 1
    return values


def ceil_div(a, b):
    return (a + b - 1) // b


def default_reuse_lists(size, cache_blocks, dataflow_mode, dims):
    k, _n, m = dims
    stream_cols = k if dataflow_mode == 1 else m
    output_col_tiles = max(1, ceil_div(stream_cols, size))
    ia_limit = max(1, cache_blocks // 2)
    w_limit = max(1, min(cache_blocks, output_col_tiles))
    return powers_of_two_upto(ia_limit), powers_of_two_upto(w_limit)


def effective_reuse(size, cache_blocks, dataflow_mode, dims, ia_reuse, w_reuse):
    k, _n, m = dims
    stream_cols = k if dataflow_mode == 1 else m
    output_col_tiles = max(1, ceil_div(stream_cols, size))
    ia_max = max(1, cache_blocks // 2)
    ia_raw = ia_max if ia_reuse == 0 else ia_reuse
    ia_eff = max(1, min(ia_raw, ia_max))
    w_raw = output_col_tiles if w_reuse == 0 else w_reuse
    w_eff = max(1, min(w_raw, output_col_tiles))
    if dataflow_mode == 1 and w_eff < ia_eff and output_col_tiles >= ia_eff:
        w_eff = ia_eff
    return ia_eff, w_eff


def build_sim_args(args):
    parts = []
    if args.sim_args:
        parts.append(args.sim_args)
    if args.ddr_rand_lat:
        parts.append("+DDR_RAND_LAT=1")
        parts.append(f"+DDR_CMD_MAX_LAT={args.ddr_cmd_max_lat}")
        parts.append(f"+DDR_W_MAX_LAT={args.ddr_w_max_lat}")
        parts.append(f"+DDR_RSP_MAX_LAT={args.ddr_rsp_max_lat}")
    return " ".join(parts)


def run_command(cmd, cwd, log_path, timeout):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", encoding="utf-8", errors="replace") as log_file:
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        output = []
        try:
            assert process.stdout is not None
            for line in process.stdout:
                output.append(line)
                log_file.write(line)
                log_file.flush()
            return_code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            output.append(f"\n[TIMEOUT] Command exceeded {timeout} seconds\n")
            log_file.write(output[-1])
            return_code = 124
    return return_code, "".join(output)


def make_vars(seed, case_name, case_dir, size, cache_blocks, ps_frame_count,
              dims, dataflow_mode, lhs_dtype, quant_mode, ia_reuse, w_reuse,
              sim_args):
    k, n, m = dims
    vars_for_make = [
        "DUT_MODE=axi_soc",
        "SOC_APP=runtime",
        "case=ai_axi_soc_c_test",
        f"seed={seed}",
        f"SOC_SEED={seed}",
        f"SOC_CASE={case_name}",
        f"SOC_CASE_DIR={case_dir}",
        f"MMA_SIZE={size}",
        f"MMA_IA_CACHE_BLOCKS={cache_blocks}",
        f"MMA_PS_FRAME_COUNT={ps_frame_count}",
        "SOC_RANDOM=0",
        "SOC_FIX_MODE=1",
        f"SOC_K={k}",
        f"SOC_N={n}",
        f"SOC_M={m}",
        f"SOC_LHS_DTYPE={lhs_dtype}",
        f"SOC_QUANT_MODE={quant_mode}",
        f"SOC_DATAFLOW_MODE={dataflow_mode}",
        f"SOC_IA_REUSE_NUM={ia_reuse}",
        f"SOC_W_REUSE_NUM={w_reuse}",
        "SOC_CPU_MEM_DP=524288",
        "DUMPOPTS=0",
    ]
    if sim_args:
        vars_for_make.append(f"SIM_ARGS={sim_args}")
    return vars_for_make


def passed(output):
    if not PASS_RE.search(output):
        return False
    if re.search(r"UVM_ERROR\s*:\s*[1-9]", output):
        return False
    if re.search(r"UVM_FATAL\s*:\s*[1-9]", output):
        return False
    return True


def parse_cycles(output):
    match = CYCLES_RE.search(output)
    return int(match.group(1)) if match else None


def write_summary(summary_path, rows):
    passed_rows = [row for row in rows if row["result"] == "pass" and row["cycles"]]
    with summary_path.open("w", encoding="utf-8") as f:
        f.write(f"total={len(rows)} pass={len(passed_rows)}\n")
        grouped = {}
        for row in passed_rows:
            key = (row["size"], row["cache_blocks"], row["dataflow"],
                   row["lhs_dtype"], row["quant_mode"], row["K"], row["N"], row["M"])
            grouped.setdefault(key, []).append(row)
        for key in sorted(grouped):
            best = min(grouped[key], key=lambda row: row["cycles"])
            size, cache_blocks, dataflow, lhs_dtype, quant_mode, k, n, m = key
            f.write(
                "best "
                f"S{size}_C{cache_blocks}_DF{dataflow}_D{lhs_dtype}_Q{quant_mode}_"
                f"{k}x{n}x{m}: cycles={best['cycles']} "
                f"ia_reuse={best['ia_reuse']} w_reuse={best['w_reuse']} "
                f"eff=R{best['ia_reuse_eff']}/W{best['w_reuse_eff']} "
                f"log={best['log']}\n"
            )


def run_perf_job(job, sim_dir, log_root, exception_root, timeout):
    label = job["label"]
    log_path = log_root / f"{label}.log"
    out_dir = log_root / "sim_out" / label
    case_name = f"axi_soc_perf_{label}"
    case_dir = f"../tb/{case_name}"
    vars_for_make = make_vars(
        job["seed"], case_name, case_dir, job["size"], job["cache_blocks"],
        job["ps_frame_count"], job["dims"], job["dataflow"], job["lhs_dtype"],
        job["quant_mode"], job["ia_reuse"], job["w_reuse"], job["sim_args"])
    vars_for_make.append(f"OUT_DIR={out_dir}")
    code, output = run_command(
        ["make", "sim", *vars_for_make], sim_dir, log_path, timeout)
    result = "pass" if code == 0 and passed(output) else "fail"
    cycles = parse_cycles(output)
    k, n, m = job["dims"]
    row = {
        "result": result,
        "cycles": cycles if cycles is not None else "",
        "size": job["size"],
        "cache_blocks": job["cache_blocks"],
        "ps_frame_count": job["ps_frame_count"],
        "dataflow": job["dataflow"],
        "lhs_dtype": job["lhs_dtype"],
        "quant_mode": job["quant_mode"],
        "K": k,
        "N": n,
        "M": m,
        "ia_reuse": job["ia_reuse"],
        "w_reuse": job["w_reuse"],
        "ia_reuse_eff": job["ia_reuse_eff"],
        "w_reuse_eff": job["w_reuse_eff"],
        "seed": job["seed"],
        "log": str(log_path),
    }
    if result != "pass":
        case_path = (sim_dir / case_dir).resolve()
        dst = exception_root / label
        if dst.exists():
            shutil.rmtree(dst)
        dst.mkdir(parents=True, exist_ok=True)
        if case_path.exists():
            shutil.copytree(case_path, dst / "case")
        if log_path.exists():
            shutil.copy2(log_path, dst / log_path.name)
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--log-root", type=Path, default=Path("runs/axi_soc_perf_sweep"))
    parser.add_argument("--seed", type=int, default=80000)
    parser.add_argument("--sizes", default="16")
    parser.add_argument("--cache-blocks", default="4")
    parser.add_argument("--ps-frame-counts", default="")
    parser.add_argument("--dataflow-modes", default="0 1")
    parser.add_argument("--lhs-dtypes", default="1")
    parser.add_argument("--quant-modes", default="0")
    parser.add_argument("--dims", default="32x32x32",
                        help="space/comma separated KxNxM tuples")
    parser.add_argument("--ia-reuse-list", default="",
                        help="empty means powers of two up to CACHE_BLOCKS/2")
    parser.add_argument("--w-reuse-list", default="",
                        help="empty means powers of two up to output col tiles")
    parser.add_argument("--include-auto", action="store_true",
                        help="also run ia_reuse=0,w_reuse=0 through the driver selector")
    parser.add_argument("--keep-going", action="store_true")
    parser.add_argument("--force-compile", action="store_true",
                        help="rebuild simv once per SIZE/CACHE/PS tuple instead of reusing it")
    parser.add_argument("--jobs", type=int, default=1,
                        help="number of simulation cases to run in parallel")
    parser.add_argument("--sim-args", default="")
    parser.add_argument("--ddr-rand-lat", action="store_true")
    parser.add_argument("--ddr-cmd-max-lat", type=int, default=3)
    parser.add_argument("--ddr-w-max-lat", type=int, default=2)
    parser.add_argument("--ddr-rsp-max-lat", type=int, default=8)
    args = parser.parse_args()

    sim_dir = Path(__file__).resolve().parent
    log_root = (sim_dir / args.log_root).resolve()
    log_root.mkdir(parents=True, exist_ok=True)
    csv_path = log_root / "perf.csv"
    summary_path = log_root / "summary.txt"
    exception_root = log_root / "exception_cases"

    sizes = parse_int_list(args.sizes)
    cache_blocks_list = parse_int_list(args.cache_blocks)
    ps_frame_counts = parse_int_list(args.ps_frame_counts)
    dataflow_modes = parse_int_list(args.dataflow_modes)
    lhs_dtypes = parse_int_list(args.lhs_dtypes)
    quant_modes = parse_int_list(args.quant_modes)
    dims_list = parse_dims(args.dims)
    explicit_ia_reuse = parse_int_list(args.ia_reuse_list)
    explicit_w_reuse = parse_int_list(args.w_reuse_list)
    sim_args = build_sim_args(args)
    jobs = max(1, args.jobs)

    rows = []
    compiled = set()
    case_jobs = []

    fieldnames = [
        "result", "cycles", "size", "cache_blocks", "ps_frame_count",
        "dataflow", "lhs_dtype", "quant_mode", "K", "N", "M",
        "ia_reuse", "w_reuse", "ia_reuse_eff", "w_reuse_eff", "seed", "log",
    ]
    with csv_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()

        for size, cache_blocks, dataflow, lhs_dtype, quant_mode, dims in itertools.product(
                sizes, cache_blocks_list, dataflow_modes, lhs_dtypes, quant_modes, dims_list):
            ps_values = ps_frame_counts if ps_frame_counts else [size]
            for ps_frame_count in ps_values:
                compile_key = (size, cache_blocks, ps_frame_count)
                if compile_key not in compiled:
                    combo_name = f"perf_compile_S{size}_C{cache_blocks}_P{ps_frame_count}"
                    build_log = log_root / f"{combo_name}.log"
                    build_vars = make_vars(
                        args.seed, combo_name, f"../tb/{combo_name}",
                        size, cache_blocks, ps_frame_count, dims,
                        dataflow, lhs_dtype, quant_mode, 0, 0, sim_args)
                    print(f"compile: S{size}_C{cache_blocks}_P{ps_frame_count}")
                    compile_target = "force_com" if args.force_compile else "com"
                    code, _ = run_command(
                        ["make", compile_target, "soc_runtime_c", *build_vars],
                        sim_dir, build_log, args.timeout)
                    if code != 0:
                        print(f"compile failed: {build_log}")
                        return 1
                    compiled.add(compile_key)

                if explicit_ia_reuse:
                    ia_values = explicit_ia_reuse
                else:
                    ia_values, _ = default_reuse_lists(size, cache_blocks, dataflow, dims)
                if explicit_w_reuse:
                    w_values = explicit_w_reuse
                else:
                    _, w_values = default_reuse_lists(size, cache_blocks, dataflow, dims)
                reuse_pairs = list(itertools.product(ia_values, w_values))
                if args.include_auto:
                    reuse_pairs.insert(0, (0, 0))

                for ia_reuse, w_reuse in reuse_pairs:
                    k, n, m = dims
                    ia_eff, w_eff = effective_reuse(
                        size, cache_blocks, dataflow, dims, ia_reuse, w_reuse)
                    label = (
                        f"S{size}_C{cache_blocks}_P{ps_frame_count}_DF{dataflow}_"
                        f"D{lhs_dtype}_Q{quant_mode}_{k}x{n}x{m}_R{ia_reuse}_W{w_reuse}"
                    )
                    case_name = f"axi_soc_perf_{label}"
                    case_dir = f"../tb/{case_name}"
                    case_jobs.append({
                        "label": label,
                        "seed": args.seed,
                        "size": size,
                        "cache_blocks": cache_blocks,
                        "ps_frame_count": ps_frame_count,
                        "dims": dims,
                        "dataflow": dataflow,
                        "lhs_dtype": lhs_dtype,
                        "quant_mode": quant_mode,
                        "ia_reuse": ia_reuse,
                        "w_reuse": w_reuse,
                        "ia_reuse_eff": ia_eff,
                        "w_reuse_eff": w_eff,
                        "sim_args": sim_args,
                    })

        def record_row(row):
            rows.append(row)
            writer.writerow(row)
            csv_file.flush()
            if row["result"] == "pass":
                if (row["ia_reuse_eff"] != row["ia_reuse"] or
                        row["w_reuse_eff"] != row["w_reuse"]):
                    print(
                        f"pass: {Path(row['log']).stem} cycles={row['cycles']} "
                        f"eff=R{row['ia_reuse_eff']}/W{row['w_reuse_eff']}"
                    )
                else:
                    print(f"pass: {Path(row['log']).stem} cycles={row['cycles']}")
            else:
                print(f"fail: {Path(row['log']).stem} log={row['log']}")

        if jobs == 1:
            for job in case_jobs:
                print(f"run: {job['label']}")
                row = run_perf_job(job, sim_dir, log_root, exception_root, args.timeout)
                record_row(row)
                if row["result"] != "pass" and not args.keep_going:
                    write_summary(summary_path, rows)
                    return 1
        else:
            print(f"running {len(case_jobs)} cases with jobs={jobs}")
            failed = False
            with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
                futures = {
                    executor.submit(
                        run_perf_job, job, sim_dir, log_root, exception_root,
                        args.timeout): job
                    for job in case_jobs
                }
                for future in concurrent.futures.as_completed(futures):
                    row = future.result()
                    record_row(row)
                    failed = failed or row["result"] != "pass"
            if failed and not args.keep_going:
                write_summary(summary_path, rows)
                return 1

    write_summary(summary_path, rows)
    print(f"wrote {csv_path}")
    print(f"wrote {summary_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
