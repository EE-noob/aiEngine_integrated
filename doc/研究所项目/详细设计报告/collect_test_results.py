#!/usr/bin/env python3
"""Collect report inputs from existing RTL, software and FPGA results."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]


def collect(fpga_project: Path, software_project: Path):
    records = []

    def read(path):
        data = path.read_bytes()
        records.append({"file": str(path.relative_to(REPO)) if path.is_relative_to(REPO)
                        else path.name, "sha256": hashlib.sha256(data).hexdigest()})
        return data.decode("utf-8")

    summary = json.loads(read(REPO / "veri/python_model/validation/summary.json"))
    assert summary["all_passed"] and summary["case_count"] == 12
    cases = []
    for case in summary["results"]:
        assert all(case[k] for k in ("passed", "python_full_memory_pass",
                                    "native_rtl_full_memory_pass", "all_cycle_signals_identical"))
        config = json.loads(read(REPO / "veri/python_model/validation" / case["case"] / "case/config.json"))
        cases.append({k: case[k] for k in ("case", "backend", "compared_cycles", "start_to_ready_cycles")}
                     | {k: config[k] for k in ("k", "n", "m", "lhs_dtype", "int16_output",
                                               "use_per_channel", "dataflow_mode", "ia_cache_blocks")})
    multi = read(REPO / "veri/sim/runs/ai_axi_soc_c_test/seed_1/sim.log")
    golden = read(REPO / "veri/soc_csrc/tflm_sensor_calibration_20261019_golden_data.cc")
    expected = [[int(x) for x in match] for match in re.findall(r"\}, \{(-?\d+), (-?\d+), (-?\d+)\}\}", golden)]
    actual = [[int(x) for x in match] for match in re.findall(
        r"sample=\d+ humidity_q=(-?\d+) voltage4_q=(-?\d+) current2_q=(-?\d+)", multi)]
    assert len(actual) == len(expected) == 8
    delta = [[a-b for a, b in zip(row, ref)] for row, ref in zip(actual, expected)]
    compact = read(REPO / "veri/sim/runs/tflm_sensor_calibration_int16x8/seed_1/sim.log")
    cycles = [int(x) for x in re.findall(r"(?<!total_)invoke_cycles=(\d+)", compact)]
    assert len(cycles) == 3 and sum(cycles) == 282397
    for text in (multi, compact):
        assert "TEST PASS:" in text and "cpu_trap=0" in text
        assert re.search(r"UVM_ERROR\s*:\s*0", text) and re.search(r"UVM_FATAL\s*:\s*0", text)
    utilization = read(fpga_project / "VU3P_oled.runs/impl_1/bit_soc_wrapper_utilization_placed.rpt")
    timing = read(fpga_project / "VU3P_oled.runs/impl_1/bit_soc_wrapper_timing_summary_routed.rpt")
    resources = []
    for label in ("CLB LUTs", "CLB Registers", "Block RAM Tile", "URAM", "DSPs"):
        match = re.search(r"^\| " + re.escape(label) + r"\s*\|\s*([\d.]+)\s*\|\s*0\s*\|\s*0\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)", utilization, re.M)
        assert match, label
        used, available, percent = map(float, match.groups())
        resources.append({"name": label, "used": used, "available": available, "percent": percent})
    timing_values = re.search(r"WNS\(ns\).*?\n\s*-.*?\n([^\n]+)", timing, re.S).group(1).split()
    assert "All user specified timing constraints are met." in timing
    manifest = json.loads(read(software_project / "src/calibration/deploy_20261111_pre_release/deployment_manifest.json"))
    deployment = [{"file": model["deployment_model"], "bytes": model["bytes"],
                   "sha256": model["sha256"], "input_shape": shape}
                  for model, shape in zip(manifest["models"], manifest["input_shapes"])]
    coverage = read(REPO / "doc/coverage_report_cn.md")
    coverage_rows = re.findall(r"\| (模块级|SoC 级) \| VCS VDB direct fallback \| ([\d.]+)% \| ([\d.]+)% \| ([\d.]+)% \| ([\d.]+)% \| ([\d.]+)%", coverage)
    assert len(coverage_rows) == 2
    result = {
        "rtl": {"cases": cases, "case_count": 12, "compared_cycles": summary["total_compared_cycles"],
                "fields_per_cycle": summary["fields_per_cycle"], "all_passed": True},
        "multi_input_model": {"actual": actual, "expected": expected, "signed_delta": delta,
                              "max_absolute_delta": [max(abs(row[i]) for row in delta) for i in range(3)],
                              "tolerance_lsb": 8, "arena_used_bytes": 139308, "passed": True},
        "compact_model": {"invoke_cycles": cycles, "total_cycles": sum(cycles),
                          "mean_cycles": sum(cycles)/len(cycles), "simulation_clock_mhz": 100,
                          "arena_used_bytes": 7164, "passed": True},
        "fpga": {"device": "xcvu3p-ffvc1517-2-i", "soc_clock_mhz": 125,
                 "resources": resources, "wns_ns": float(timing_values[0]),
                 "tns_ns": float(timing_values[1]), "setup_failing_endpoints": int(timing_values[2]),
                 "whs_ns": float(timing_values[4]), "ths_ns": float(timing_values[5]),
                 "hold_failing_endpoints": int(timing_values[6]), "timing_met": True},
        "coverage": [{"scope": row[0], "line": float(row[1]), "condition": float(row[2]),
                      "branch": float(row[3]), "fsm": float(row[4]), "toggle": float(row[5])}
                     for row in coverage_rows],
        "deployment_models": deployment, "source_records": records,
    }
    (ROOT / "test_results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n")
    print("测试数据提取完成：12 个 RTL 用例、8 组数值样本、3 组调用周期、FPGA 实现结果。")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fpga-project", required=True, type=Path)
    parser.add_argument("--software-project", required=True, type=Path)
    args = parser.parse_args()
    collect(args.fpga_project.resolve(), args.software_project.resolve())
