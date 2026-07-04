#!/usr/bin/env python3
import argparse
import csv
import json
import re
from pathlib import Path


FIELDS = [
    "case",
    "seed",
    "result",
    "size",
    "ia_cache_blocks",
    "ps_frame_count",
    "k",
    "n",
    "m",
    "lhs_dtype",
    "dataflow",
    "per_channel",
    "ia_reuse_num",
    "w_reuse_num",
    "done_time",
    "ram_latency",
    "reason",
    "log",
]


def result_from_log(log_path):
    if not log_path or not Path(log_path).exists():
        return "FAIL", "", "", "missing_log"

    text = Path(log_path).read_text(encoding="utf-8", errors="replace")
    result = "PASS" if "[TB] PASS" in text else "FAIL"

    done_time = ""
    match = re.search(r"Computation done .* time\s+([0-9]+)", text)
    if match:
        done_time = match.group(1)

    ram_latency = ""
    match = re.search(r"\[RAM_AXI_MEM\]\s+([^\n]+)", text)
    if match:
        ram_latency = match.group(1).strip()

    reason = ""
    if result != "PASS":
        for pattern in (r"\[TB\] FATAL:[^\n]+", r"\[TB\] FAIL[^\n]*"):
            match = re.search(pattern, text)
            if match:
                reason = match.group(0).strip()
                break
        if not reason:
            reason = "pass_string_not_found"

    return result, done_time, ram_latency, reason


def normalize_row(args):
    cfg = {}
    if args.config:
        cfg_path = Path(args.config)
        if cfg_path.exists():
            cfg = json.loads(cfg_path.read_text(encoding="utf-8"))

    result, done_time, ram_latency, reason = result_from_log(args.log)
    if args.status:
        result = args.status
    if args.reason:
        reason = args.reason

    lhs_dtype = cfg.get("lhs_dtype", args.lhs_dtype)
    if lhs_dtype == 2:
        lhs_dtype = "int16"
    elif lhs_dtype == 1:
        lhs_dtype = "int8"
    elif lhs_dtype in (0, "0"):
        lhs_dtype = "auto"
    else:
        lhs_dtype = str(lhs_dtype)

    dataflow_mode = cfg.get("dataflow_mode", args.dataflow_mode)
    dataflow = "IS" if int(dataflow_mode or 0) else "WS"

    return {
        "case": args.case,
        "seed": str(cfg.get("seed", args.seed)),
        "result": result,
        "size": str(cfg.get("size", args.size)),
        "ia_cache_blocks": str(cfg.get("ia_cache_blocks", args.cache)),
        "ps_frame_count": str(cfg.get("ps_frame_count", args.ps_frame_count)),
        "k": str(cfg.get("k", args.k)),
        "n": str(cfg.get("n", args.n)),
        "m": str(cfg.get("m", args.m)),
        "lhs_dtype": lhs_dtype,
        "dataflow": dataflow,
        "per_channel": str(int(bool(cfg.get("use_per_channel", args.per_channel)))),
        "ia_reuse_num": str(cfg.get("ia_reuse_num", args.ia_reuse_num)),
        "w_reuse_num": str(cfg.get("w_reuse_num", args.w_reuse_num)),
        "done_time": done_time,
        "ram_latency": ram_latency,
        "reason": reason,
        "log": args.log or "",
    }


def paths(prefix):
    p = Path(prefix)
    return p.with_suffix(".jsonl"), p.with_suffix(".csv"), p.with_suffix(".md")


def cmd_init(args):
    jsonl_path, csv_path, md_path = paths(args.prefix)
    jsonl_path.parent.mkdir(parents=True, exist_ok=True)
    jsonl_path.write_text("", encoding="utf-8")

    with csv_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()

    md_path.write_text(
        f"# {args.title}\n\n"
        "| Case | Seed | Result | SIZE | IA cache blocks | K | N | M | LHS dtype | Dataflow | Done time | Reason |\n"
        "|---|---:|---|---:|---:|---:|---:|---:|---|---|---:|---|\n",
        encoding="utf-8",
    )


def cmd_append(args):
    jsonl_path, csv_path, md_path = paths(args.prefix)
    row = normalize_row(args)

    with jsonl_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")

    with csv_path.open("a", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writerow(row)

    with md_path.open("a", encoding="utf-8") as f:
        f.write(
            f"| {row['case']} | {row['seed']} | {row['result']} | {row['size']} | "
            f"{row['ia_cache_blocks']} | {row['k']} | {row['n']} | {row['m']} | "
            f"{row['lhs_dtype']} | {row['dataflow']} | {row['done_time']} | {row['reason']} |\n"
        )

    print(
        "[REGRESS_RESULT] "
        f"case={row['case']} seed={row['seed']} result={row['result']} "
        f"SIZE={row['size']} CACHE={row['ia_cache_blocks']} "
        f"K={row['k']} N={row['n']} M={row['m']} "
        f"lhs={row['lhs_dtype']} mode={row['dataflow']} done_time={row['done_time']} "
        f"reason={row['reason'] or '-'}"
    )


def load_rows(jsonl_path):
    if not jsonl_path.exists():
        return []
    rows = []
    for line in jsonl_path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            rows.append(json.loads(line))
    return rows


def cmd_finish(args):
    jsonl_path, csv_path, md_path = paths(args.prefix)
    rows = load_rows(jsonl_path)
    passed = sum(1 for r in rows if r["result"] == "PASS")
    failed = len(rows) - passed

    print("")
    print("[REGRESS_SUMMARY]")
    print(f"  total={len(rows)} pass={passed} fail={failed}")
    print(f"  summary_md={md_path}")
    print(f"  summary_csv={csv_path}")
    print(f"  summary_jsonl={jsonl_path}")
    print("")
    print("| Case | Seed | Result | SIZE | Cache | K | N | M | LHS | Mode | Done time | Reason |")
    print("|---|---:|---|---:|---:|---:|---:|---:|---|---|---:|---|")
    for row in rows:
        print(
            f"| {row['case']} | {row['seed']} | {row['result']} | {row['size']} | "
            f"{row['ia_cache_blocks']} | {row['k']} | {row['n']} | {row['m']} | "
            f"{row['lhs_dtype']} | {row['dataflow']} | {row['done_time']} | {row['reason']} |"
        )

    with md_path.open("a", encoding="utf-8") as f:
        f.write(f"\nSummary: total={len(rows)} pass={passed} fail={failed}\n")


def add_append_args(parser):
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--case", required=True)
    parser.add_argument("--config")
    parser.add_argument("--log")
    parser.add_argument("--seed", default="")
    parser.add_argument("--size", default="")
    parser.add_argument("--cache", default="")
    parser.add_argument("--ps-frame-count", default="")
    parser.add_argument("--k", default="")
    parser.add_argument("--n", default="")
    parser.add_argument("--m", default="")
    parser.add_argument("--lhs-dtype", default="")
    parser.add_argument("--dataflow-mode", default=0)
    parser.add_argument("--per-channel", action="store_true")
    parser.add_argument("--ia-reuse-num", default="")
    parser.add_argument("--w-reuse-num", default="")
    parser.add_argument("--status", choices=["PASS", "FAIL"])
    parser.add_argument("--reason", default="")


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_init = sub.add_parser("init")
    p_init.add_argument("--prefix", required=True)
    p_init.add_argument("--title", default="NPU top regression summary")
    p_init.set_defaults(func=cmd_init)

    p_append = sub.add_parser("append")
    add_append_args(p_append)
    p_append.set_defaults(func=cmd_append)

    p_finish = sub.add_parser("finish")
    p_finish.add_argument("--prefix", required=True)
    p_finish.set_defaults(func=cmd_finish)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
