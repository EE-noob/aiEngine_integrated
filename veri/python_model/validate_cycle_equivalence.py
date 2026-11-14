#!/usr/bin/env python3
"""Compare Python stepping with an independently built native RTL testbench."""
import argparse
import csv
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
TESTS = [
    ("ws_int8_tail",4,["--K","5","--N","19","--M","7","--lhs_dtype","1",
        "--random_quant","--tight_strides"],[]),
    ("is_s16_per_channel",4,["--K","3","--N","33","--M","5","--lhs_dtype","2",
        "--dataflow_mode","1","--per_channel","--random_quant","--random_unaligned_strides"],[]),
    ("ws_s16_output",4,["--K","3","--N","494","--M","7","--lhs_dtype","2",
        "--int16_output","--random_quant","--tight_strides"],[]),
    ("ws_s16_no_bias",4,["--K","1","--N","494","--M","1","--lhs_dtype","2",
        "--int16_output","--no_bias","--tight_strides"],[]),
    ("ws_reuse_groups",4,["--K","64","--N","32","--M","64","--lhs_dtype","1",
        "--ia_reuse_num","2","--w_reuse_num","2"],[]),
    ("ws_fixed_latency",4,["--K","5","--N","19","--M","7","--lhs_dtype","1"],
        ["+RAM_FIXED_LAT=8"]),
    ("ws_random_latency",4,["--K","17","--N","33","--M","19","--lhs_dtype","1",
        "--random","--random_quant","--random_unaligned_strides"],
        ["+DDR_RAND_LAT=1","+DDR_CMD_MAX_LAT=3","+DDR_W_MAX_LAT=2",
         "+DDR_RSP_MAX_LAT=8","+DDR_SEED=88400"]),
    ("is_random_latency",4,["--K","17","--N","31","--M","19","--lhs_dtype","1",
        "--dataflow_mode","1","--per_channel","--random","--random_quant"],
        ["+DDR_RAND_LAT=1","+DDR_CMD_MAX_LAT=2","+DDR_W_MAX_LAT=2",
         "+DDR_RSP_MAX_LAT=5","+DDR_SEED=88401"]),
    ("cache8_auto",8,["--K","128","--N","32","--M","128","--lhs_dtype","1"],[]),
    ("cache16_auto",16,["--K","128","--N","32","--M","128","--lhs_dtype","1"],[]),
    ("cache16_is_s16",16,["--K","64","--N","33","--M","128","--lhs_dtype","2",
        "--dataflow_mode","1","--per_channel","--random_quant"],[]),
    ("cache32_auto",32,["--K","256","--N","32","--M","128","--lhs_dtype","1"],[]),
]

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def compare_trace(left,right):
    # Include inactive cycles and all data lanes; do not reduce to checksums.
    with left.open() as a,right.open() as b:
        header_a=a.readline(); header_b=b.readline()
        if header_a != header_b: return False,0,"CSV headers differ"
        count=0
        while True:
            line_a=a.readline(); line_b=b.readline()
            if line_a != line_b:
                return False,count,f"First difference at sample {count}: {line_a.strip()} != {line_b.strip()}"
            if not line_a: return True,count,""
            count+=1

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,default=HERE/"validation")
    parser.add_argument("--only",action="append")
    parser.add_argument("--quick",action="store_true")
    parser.add_argument("--keep-csv",action="store_true")
    args=parser.parse_args()
    output=args.output.resolve(); output.mkdir(parents=True,exist_ok=True)
    selected=set(args.only or [])
    if args.quick: selected.update(["ws_int8_tail","ws_random_latency","cache16_auto"])
    cases=[case for case in TESTS if not selected or case[0] in selected]
    if selected-set(case[0] for case in cases): parser.error("Unknown --only case")
    records=[]
    for name,cache,extra,plusargs in cases:
        folder=output/name; folder.mkdir(parents=True,exist_ok=True)
        case=folder/"case"
        backend=HERE/"backends"/f"s16_c{cache}_p16"
        reference=backend/"rtl_reference"
        if reference.is_file() and not os.access(reference,os.X_OK):
            reference.chmod(reference.stat().st_mode | 0o100)
        generate=[sys.executable,str(ROOT/"veri/top_regression/gen_mem.py"),
            "--out_dir",str(case),"--size","16","--ia_cache_blocks",str(cache),
            "--ps_frame_count","16","--seed","88400",
            "--ia_reuse_num","0","--w_reuse_num","0",*extra]
        subprocess.run(generate,check=True,stdout=subprocess.DEVNULL)
        python_csv=folder/"python.csv"; native_csv=folder/"native.csv"
        py_command=[sys.executable,str(HERE/"run.py"),"--case",str(case),
            "--trace",str(python_csv),"--result",str(folder/"python_result.json")]
        if name == "ws_int8_tail": py_command.append("--single-step")
        for arg in plusargs: py_command.append("--plusarg="+arg)
        with (folder/"python.log").open("w") as log:
            py_run=subprocess.run(py_command,stdout=log,stderr=subprocess.STDOUT)
        native_command=[str(backend/"rtl_reference"),
            f"+INIT_MEM={case/'init.mem'}",f"+GOLDEN_MEM={case/'golden.mem'}",
            f"+CASE_MEM={case/'config.mem'}",f"+PY_TRACE={native_csv}",
            "+FULL_MEM_CHECK","+TB_TIMEOUT_CYCLES=2000000",*plusargs]
        with (folder/"native.log").open("w") as log:
            native_run=subprocess.run(native_command,stdout=log,stderr=subprocess.STDOUT)
        py_result=json.loads((folder/"python_result.json").read_text()) if (folder/"python_result.json").exists() else {}
        native_log=(folder/"native.log").read_text(errors="replace")
        py_log=(folder/"python.log").read_text(errors="replace")
        same,count,reason=compare_trace(python_csv,native_csv) if python_csv.exists() and native_csv.exists() else (False,0,"Missing trace")
        native_pass=native_run.returncode==0 and "[TB] PASS" in native_log and "[TB] FAIL" not in native_log and "[TB] FATAL" not in native_log
        passed=bool(py_run.returncode==0 and py_result.get("passed") and
                    "[TB] PASS" in py_log and native_pass and same)
        row={
            "case":name,"backend":backend.name,"passed":passed,
            "python_full_memory_pass":bool(py_result.get("passed")),
            "native_rtl_full_memory_pass":native_pass,
            "all_cycle_signals_identical":same,"compared_cycles":count,
            "start_to_ready_cycles":py_result.get("start_to_ready_cycles"),
            "python_trace_sha256":sha256(python_csv) if python_csv.exists() else None,
            "native_trace_sha256":sha256(native_csv) if native_csv.exists() else None,
            "failure_reason":reason,
            "python_command":py_command,"native_command":native_command,
        }
        records.append(row)
        print(f"{'PASS' if passed else 'FAIL'} {name}: {count} cycles, exact_trace={same}",flush=True)
        for trace in [python_csv,native_csv]:
            if trace.exists():
                with trace.open("rb") as src,gzip.open(trace.with_suffix(".csv.gz"),"wb") as dst:
                    for chunk in iter(lambda:src.read(1<<20),b""): dst.write(chunk)
                if not args.keep_csv: trace.unlink()
    summary={
        "scope":"NPU top + original AXI DDR + original tb_npu_top; Verilator two-state semantics",
        "comparison":"Python-driven timing event queue vs separately generated --binary RTL simulation",
        "all_passed":all(r["passed"] for r in records),
        "case_count":len(records),"total_compared_cycles":sum(r["compared_cycles"] for r in records),
        "fields_per_cycle":98,"results":records,
    }
    (output/"summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    with (output/"summary.csv").open("w",newline="") as f:
        keys=["case","backend","passed","all_cycle_signals_identical","compared_cycles","start_to_ready_cycles"]
        writer=csv.DictWriter(f,fieldnames=keys,extrasaction="ignore"); writer.writeheader(); writer.writerows(records)
    print(f"Summary: {output/'summary.json'}",flush=True)
    return 0 if summary["all_passed"] else 1

if __name__=="__main__":
    raise SystemExit(main())
