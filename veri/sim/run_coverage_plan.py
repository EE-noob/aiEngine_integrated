#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


PASS_RE = re.compile(r"\[TEST_RESULT\]\s+TEST PASS")


def run_conpund(cmd, cwd, log_path, timeout):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    output = []
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
        try:
            assert proc.stdout is not None
            for line in proc.stdout:
                output.append(line)
                log_file.write(line)
                log_file.flush()
            rc = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            rc = 124
            line = f"\n[TIMEOUT] conpund exceeded {timeout} seconds\n"
            output.append(line)
            log_file.write(line)
    return rc, "".join(output)


def make_var_items(item):
    vars_for_make = []
    for key, value in item.get("vars", {}).items():
        vars_for_make.append(f"{key}={value}")
    return vars_for_make


def make_var_value(assignments, name, default):
    prefix = f"{name}="
    for item in reversed(assignments):
        if item.startswith(prefix):
            return item[len(prefix) :]
    return default


def item_passed(item, output):
    if item.get("expect_pass_banner", True) and not PASS_RE.search(output):
        return False
    if re.search(r"UVM_ERROR\s*:\s*[1-9]", output):
        return False
    if re.search(r"UVM_FATAL\s*:\s*[1-9]", output):
        return False
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", type=Path, default=Path("coverage_plan.json"))
    parser.add_argument("--goal", type=float, default=95.0)
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--only", action="append", default=[], help="Run only named plan entries")
    parser.add_argument("--keep-going", action="store_true")
    parser.add_argument("--skip-report", action="store_true")
    parser.add_argument(
        "--report-target",
        default=os.environ.get("COV_REPORT_TARGET", "cov_report"),
        help="Make target used to merge coverage after the plan has run",
    )
    parser.add_argument(
        "--report-var",
        action="append",
        default=[],
        help="Extra VAR=VALUE assignment passed to the coverage report target",
    )
    parser.add_argument(
        "--make-var",
        action="append",
        default=[],
        help="Extra VAR=VALUE assignment passed to every make invocation",
    )
    args = parser.parse_args()

    sim_dir = Path(__file__).resolve().parent
    plan = json.loads(args.plan.read_text(encoding="utf-8"))
    items = plan.get("tests", [])
    cov_root = make_var_value(args.make_var, "COV_ROOT", "runs/coverage")
    if args.only:
        only = set(args.only)
        available = {item["name"] for item in items}
        missing = sorted(only - available)
        if missing:
            raise SystemExit(
                "coverage plan --only entries not found: "
                + ", ".join(missing)
            )
        items = [item for item in items if item["name"] in only]
    if not items:
        raise SystemExit("coverage plan contains no selected tests")

    results = []
    run_results = []
    compiled_simv = set()
    for item in items:
        name = item["name"]
        mode = item["vars"].get("DUT_MODE", "axil")
        simv = item.get("simv", f"simv_cov_{mode}_{item.get('compile_tag', 'default')}")
        out_dir = item.get("out_dir", f"{cov_root}/cases/{name}")
        cov_name = item.get("cov_name", name)
        timeout = int(item.get("timeout", args.timeout))
        collect_code_coverage = bool(item.get("code_coverage", True))
        cov_flag = "1" if collect_code_coverage else "0"
        compile_vdb = f"{cov_root}/vdb/{simv}.vdb"
        run_vdb = compile_vdb

        if simv not in compiled_simv:
            vdb_path = sim_dir / compile_vdb
            shutil.rmtree(vdb_path, ignore_errors=True)
            compile_cmd = [
                "make",
                "force_com",
                f"COV={cov_flag}",
                f"COVERAGE_GOAL={args.goal}",
                f"SIMV={simv}",
                f"OUT_DIR={out_dir}",
                f"COV_COMPILE_DB={compile_vdb}",
                *args.make_var,
                *make_var_items(item),
            ]
            compile_log = sim_dir / cov_root / "plan_logs" / f"{name}_compile.log"
            print(f"[COV_PLAN] compile {simv}: {' '.join(compile_cmd)}")
            compile_rc, _ = run_conpund(compile_cmd, sim_dir, compile_log, timeout)
            compile_ok = compile_rc == 0
            results.append(
                {
                    "name": f"{name}__compile",
                    "returncode": compile_rc,
                    "passed": compile_ok,
                    "log": str(compile_log.relative_to(sim_dir)),
                    "conpund": compile_cmd,
                }
            )
            print(f"[COV_PLAN] compile {simv}: {'PASS' if compile_ok else 'FAIL'} rc={compile_rc} log={compile_log.relative_to(sim_dir)}")
            if not compile_ok:
                if not args.keep_going:
                    break
            else:
                compiled_simv.add(simv)

        cmd = [
            "make",
            item.get("target", "run"),
            f"COV={cov_flag}",
            f"COVERAGE_GOAL={args.goal}",
            "DUMPOPTS=0",
            f"SIMV={simv}",
            f"OUT_DIR={out_dir}",
            f"COV_NAME={cov_name}",
            f"COV_COMPILE_DB={compile_vdb}",
            f"COV_DB={run_vdb}",
            *args.make_var,
            *make_var_items(item),
        ]
        log_path = sim_dir / cov_root / "plan_logs" / f"{name}.log"
        print(f"[COV_PLAN] run {name}: {' '.join(cmd)}")
        rc, output = run_conpund(cmd, sim_dir, log_path, timeout)
        passed = rc == 0 and item_passed(item, output)
        results.append(
            {
                "name": name,
                "returncode": rc,
                "passed": passed,
                "log": str(log_path.relative_to(sim_dir)),
                "conpund": cmd,
            }
        )
        run_results.append(results[-1])
        print(f"[COV_PLAN] {name}: {'PASS' if passed else 'FAIL'} rc={rc} log={log_path.relative_to(sim_dir)}")
        if not passed and not args.keep_going:
            break

    report_rc = None
    if not args.skip_report:
        cmd = ["make", args.report_target, f"COVERAGE_GOAL={args.goal}", *args.make_var, *args.report_var]
        log_path = sim_dir / cov_root / "plan_logs" / "cov_report.log"
        print(f"[COV_PLAN] merge/report: {' '.join(cmd)}")
        report_rc, _ = run_conpund(cmd, sim_dir, log_path, args.timeout)
        print(f"[COV_PLAN] report rc={report_rc} log={log_path.relative_to(sim_dir)}")

    compile_results = [item for item in results if item["name"].endswith("__compile")]
    compile_ok = all(item["passed"] for item in compile_results)
    runs_ok = all(item["passed"] for item in run_results) and len(run_results) == len(items)
    report_ok = (report_rc == 0) if report_rc is not None else True

    result_doc = {
        "goal": args.goal,
        "results": results,
        "report_returncode": report_rc,
        "compile_passed": compile_ok,
        "all_tests_passed": runs_ok,
        "report_passed": report_ok,
        "coverage_plan_passed": compile_ok and runs_ok and report_ok,
    }
    result_path = sim_dir / cov_root / "coverage_plan_results.json"
    result_path.write_text(json.dumps(result_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    md = ["# Coverage Plan Results", ""]
    md.append(f"- Goal: {args.goal:.2f}%")
    md.append(f"- Report return code: {report_rc}")
    md.extend(["", "| Test | Result | Return Code | Log |", "|---|---|---:|---|"])
    for item in results:
        md.append(f"| {item['name']} | {'PASS' if item['passed'] else 'FAIL'} | {item['returncode']} | `{item['log']}` |")
    md_path = sim_dir / cov_root / "coverage_plan_results.md"
    md_path.write_text("\n".join(md) + "\n", encoding="utf-8")

    return 0 if compile_ok and runs_ok and report_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
