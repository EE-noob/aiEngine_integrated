#!/usr/bin/env python3
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


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


def make_vars(seed, case_name, case_dir, min_dim, max_dim, dim_multiple):
    return [
        "DUT_MODE=axi_soc",
        "case=ai_axi_soc_c_test",
        f"seed={seed}",
        f"SOC_SEED={seed}",
        f"SOC_CASE={case_name}",
        f"SOC_CASE_DIR={case_dir}",
        "SOC_RANDOM=1",
        "SOC_FIX_MODE=0",
        f"SOC_MIN_DIM={min_dim}",
        f"SOC_MAX_DIM={max_dim}",
        f"SOC_DIM_MULTIPLE={dim_multiple}",
        "DUMPOPTS=0",
    ]


def copy_exception(case_path, log_path, exception_root, iteration, seed):
    dst = exception_root / f"iter_{iteration:04d}_seed_{seed}"
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True, exist_ok=True)
    if case_path.exists():
        shutil.copytree(case_path, dst / "case")
    if log_path.exists():
        shutil.copy2(log_path, dst / log_path.name)


def iteration_passed(output):
    if "[TEST_RESULT] TEST PASS" not in output:
        return False
    if re.search(r"UVM_ERROR\s*:\s*[1-9]", output):
        return False
    if re.search(r"UVM_FATAL\s*:\s*[1-9]", output):
        return False
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--start-seed", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--log-root", type=Path, default=Path("runs/axi_soc_c_regression"))
    parser.add_argument("--min-dim", type=int, default=16)
    parser.add_argument("--max-dim", type=int, default=32)
    parser.add_argument("--dim-multiple", type=int, default=16)
    args = parser.parse_args()

    sim_dir = Path(__file__).resolve().parent
    log_root = (sim_dir / args.log_root).resolve()
    exception_root = log_root / "exception_cases"
    summary_path = log_root / "summary.txt"
    log_root.mkdir(parents=True, exist_ok=True)

    pass_count = 0
    total_count = 0

    with summary_path.open("w", encoding="utf-8") as summary:
        for iteration in range(1, args.iterations + 1):
            seed = args.start_seed + iteration - 1
            case_name = f"axi_soc_c_regress_{iteration:04d}"
            case_dir = f"../tb/{case_name}"
            case_path = (sim_dir / case_dir).resolve()
            iter_log = log_root / f"iter_{iteration:04d}_seed_{seed}.log"
            vars_for_make = make_vars(
                seed,
                case_name,
                case_dir,
                args.min_dim,
                args.max_dim,
                args.dim_multiple,
            )

            build_target = "com" if iteration == 1 else "soc_c"
            build_log = log_root / f"iter_{iteration:04d}_seed_{seed}_{build_target}.log"
            build_code, build_output = run_command(
                ["make", build_target, *vars_for_make],
                sim_dir,
                build_log,
                args.timeout,
            )
            if build_code != 0:
                total_count += 1
                result = "exception"
                copy_exception(case_path, build_log, exception_root, iteration, seed)
                summary.write(f"iter {iteration}: {result}, seed={seed}, {build_target} failed\n")
                summary.flush()
                print(f"iter {iteration}: {result}, seed={seed}")
                continue

            print(f"iter {iteration}: seed={seed}, running make sim")
            return_code, output = run_command(["make", "sim", *vars_for_make], sim_dir, iter_log, args.timeout)

            total_count += 1
            if return_code == 0 and iteration_passed(output):
                pass_count += 1
                result = "pass"
            else:
                result = "fail" if return_code == 0 else "exception"
                copy_exception(case_path, iter_log, exception_root, iteration, seed)

            accuracy = (pass_count / total_count) * 100.0
            summary.write(f"iter {iteration}: {result}, seed={seed}, pass_rate={accuracy:.2f}%\n")
            summary.flush()
            print(f"iter {iteration}: {result}, seed={seed}, pass_rate={accuracy:.2f}%")

            if result != "pass":
                print(f"first failing log: {iter_log}")
                return 1

        accuracy = (pass_count / total_count) * 100.0 if total_count else 0.0
        summary.write(f"\nfinal: total={total_count}, pass={pass_count}, pass_rate={accuracy:.2f}%\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
