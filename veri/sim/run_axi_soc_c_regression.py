#!/usr/bin/env python3
import argparse
import itertools
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


def parse_int_list(text):
    if text is None:
        return []
    values = []
    for item in re.split(r"[,\s]+", str(text).strip()):
        if item:
            values.append(int(item, 0))
    return values


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


def make_vars(seed, case_name, case_dir, min_dim, max_dim, dim_multiple,
              size, cache_blocks, ps_frame_count, dataflow_mode, sim_args,
              soc_app, soc_timeout_cycles=0, lhs_dtype=0, quant_mode=-1,
              unaligned_layout=False):
    vars_for_make = [
        "DUT_MODE=axi_soc",
        f"SOC_APP={soc_app}",
        "case=ai_axi_soc_c_test",
        f"seed={seed}",
        f"SOC_SEED={seed}",
        f"SOC_CASE={case_name}",
        f"SOC_CASE_DIR={case_dir}",
        f"MMA_SIZE={size}",
        f"MMA_IA_CACHE_BLOCKS={cache_blocks}",
        f"MMA_PS_FRAME_COUNT={ps_frame_count}",
        f"SOC_DATAFLOW_MODE={dataflow_mode}",
        "SOC_RANDOM=1",
        "SOC_FIX_MODE=0",
        f"SOC_MIN_DIM={min_dim}",
        f"SOC_MAX_DIM={max_dim}",
        f"SOC_DIM_MULTIPLE={dim_multiple}",
        "DUMPOPTS=0",
    ]
    if lhs_dtype:
        vars_for_make.append(f"SOC_RANDOM_LHS_DTYPE={lhs_dtype}")
    if quant_mode >= 0:
        vars_for_make.append(f"SOC_RANDOM_QUANT_MODE={quant_mode}")
    if unaligned_layout:
        vars_for_make.append("SOC_UNALIGNED_LAYOUT=1")
    if sim_args:
        vars_for_make.append(f"SIM_ARGS={sim_args}")
    if soc_timeout_cycles:
        vars_for_make.append(f"SOC_TIMEOUT_CYCLES={soc_timeout_cycles}")
    return vars_for_make


def copy_exception(case_path, log_path, exception_root, iteration, seed, tag=""):
    prefix = f"{tag}_" if tag else ""
    dst = exception_root / f"{prefix}iter_{iteration:04d}_seed_{seed}"
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
    parser.add_argument("--soc-timeout-cycles", type=int, default=0,
                        help="0 keeps the testbench default SOC_TIMEOUT_CYCLES")
    parser.add_argument("--log-root", type=Path, default=Path("runs/axi_soc_c_regression"))
    parser.add_argument("--min-dim", type=int, default=16)
    parser.add_argument("--max-dim", type=int, default=32)
    parser.add_argument("--dim-multiple", type=int, default=0,
                        help="0 means use the current MMA size for each parameter combo")
    parser.add_argument("--sizes", default="16",
                        help="Comma/space separated MMA SIZE values")
    parser.add_argument("--cache-blocks", "--cache-blocks-list", dest="cache_blocks",
                        default="4", help="Comma/space separated IA cache block counts")
    parser.add_argument("--ps-frame-counts", default="",
                        help="Comma/space separated PS frame counts; empty means one value equal to SIZE")
    parser.add_argument("--dataflow-modes", default="0",
                        help="Comma/space separated dataflow modes supported by the case generator")
    parser.add_argument("--lhs-dtypes", default="",
                        help="Comma/space separated LHS dtypes; empty means random")
    parser.add_argument("--quant-modes", default="",
                        help="Comma/space separated quant modes; empty means random")
    parser.add_argument("--soc-app", default="runtime",
                        choices=["runtime", "case"],
                        help="runtime reuses one O3 CPU program and overlays runtime_data.mem")
    parser.add_argument("--sim-args", default="")
    parser.add_argument("--ddr-rand-lat", action="store_true")
    parser.add_argument("--ddr-cmd-max-lat", type=int, default=3)
    parser.add_argument("--ddr-w-max-lat", type=int, default=2)
    parser.add_argument("--ddr-rsp-max-lat", type=int, default=8)
    parser.add_argument("--unaligned-layout", action="store_true",
                        help="place runtime data at byte offsets to exercise DMA unaligned access")
    args = parser.parse_args()

    sim_dir = Path(__file__).resolve().parent
    log_root = (sim_dir / args.log_root).resolve()
    exception_root = log_root / "exception_cases"
    summary_path = log_root / "summary.txt"
    log_root.mkdir(parents=True, exist_ok=True)

    sizes = parse_int_list(args.sizes)
    cache_blocks_list = parse_int_list(args.cache_blocks)
    ps_frame_counts = parse_int_list(args.ps_frame_counts)
    dataflow_modes = parse_int_list(args.dataflow_modes)
    lhs_dtypes = parse_int_list(args.lhs_dtypes) or [0]
    quant_modes = parse_int_list(args.quant_modes) or [-1]
    sim_args = build_sim_args(args)

    if not sizes:
        raise ValueError("--sizes must contain at least one value")
    if not cache_blocks_list:
        raise ValueError("--cache-blocks must contain at least one value")
    if not dataflow_modes:
        raise ValueError("--dataflow-modes must contain at least one value")

    pass_count = 0
    total_count = 0
    compiled = set()

    with summary_path.open("w", encoding="utf-8") as summary:
        for size, cache_blocks, dataflow_mode, lhs_dtype, quant_mode in itertools.product(
                sizes, cache_blocks_list, dataflow_modes, lhs_dtypes, quant_modes):
            ps_values = ps_frame_counts if ps_frame_counts else [size]
            for ps_frame_count in ps_values:
                combo = (size, cache_blocks, ps_frame_count, dataflow_mode)
                dtype_label = f"_D{lhs_dtype}" if lhs_dtype else "_Drand"
                quant_label = f"_Q{quant_mode}" if quant_mode >= 0 else "_Qrand"
                combo_label = f"S{size}_C{cache_blocks}_P{ps_frame_count}_DF{dataflow_mode}{dtype_label}{quant_label}"
                dim_multiple = args.dim_multiple if args.dim_multiple else size

                if combo not in compiled:
                    seed = args.start_seed
                    case_name = f"axi_soc_c_{combo_label}_compile"
                    case_dir = f"../tb/{case_name}"
                    compile_vars = make_vars(
                        seed, case_name, case_dir, args.min_dim, args.max_dim,
                        dim_multiple, size, cache_blocks, ps_frame_count,
                        dataflow_mode, sim_args, args.soc_app,
                        args.soc_timeout_cycles,
                        lhs_dtype, quant_mode, args.unaligned_layout)
                    build_log = log_root / f"compile_{combo_label}.log"
                    print(f"compile: {combo_label}")
                    compile_targets = ["com"]
                    if args.soc_app == "runtime":
                        compile_targets.append("soc_runtime_c")
                    build_code, _ = run_command(
                        ["make", *compile_targets, *compile_vars],
                        sim_dir,
                        build_log,
                        args.timeout,
                    )
                    if build_code != 0:
                        summary.write(f"combo {combo_label}: exception, compile failed\n")
                        summary.flush()
                        print(f"combo {combo_label}: exception, compile failed")
                        return 1
                    compiled.add(combo)

                for iteration in range(1, args.iterations + 1):
                    seed = args.start_seed + iteration - 1
                    case_name = f"axi_soc_c_{combo_label}_i{iteration:04d}"
                    case_dir = f"../tb/{case_name}"
                    case_path = (sim_dir / case_dir).resolve()
                    iter_log = log_root / f"{combo_label}_iter_{iteration:04d}_seed_{seed}.log"
                    vars_for_make = make_vars(
                        seed,
                        case_name,
                        case_dir,
                        args.min_dim,
                        args.max_dim,
                        dim_multiple,
                        size,
                        cache_blocks,
                        ps_frame_count,
                        dataflow_mode,
                        sim_args,
                        args.soc_app,
                        args.soc_timeout_cycles,
                        lhs_dtype,
                        quant_mode,
                        args.unaligned_layout,
                    )

                    print(f"iter {iteration}: {combo_label}, seed={seed}, running make sim")
                    return_code, output = run_command(
                        ["make", "sim", *vars_for_make], sim_dir, iter_log, args.timeout)

                    total_count += 1
                    if return_code == 0 and iteration_passed(output):
                        pass_count += 1
                        result = "pass"
                    else:
                        result = "fail" if return_code == 0 else "exception"
                        copy_exception(case_path, iter_log, exception_root,
                                       iteration, seed, combo_label)

                    accuracy = (pass_count / total_count) * 100.0
                    summary.write(
                        f"iter {iteration}: {result}, combo={combo_label}, seed={seed}, "
                        f"pass_rate={accuracy:.2f}%\n")
                    summary.flush()
                    print(
                        f"iter {iteration}: {result}, combo={combo_label}, "
                        f"seed={seed}, pass_rate={accuracy:.2f}%")

                    if result != "pass":
                        print(f"first failing log: {iter_log}")
                        return 1

        accuracy = (pass_count / total_count) * 100.0 if total_count else 0.0
        summary.write(f"\nfinal: total={total_count}, pass={pass_count}, pass_rate={accuracy:.2f}%\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
