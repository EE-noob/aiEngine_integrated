#!/usr/bin/env python3
"""Build and verify the PicoRV32/NPU SoC on the Artix-7 XC7A200T."""

import argparse
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEFAULT_PART = "xc7a200tfbg484-3"


def find_tool(name, directory=None):
    candidate = str(directory / name) if directory else name
    found = shutil.which(candidate)
    if not found:
        raise ValueError(f"Tool not found: {candidate}")
    return Path(found).resolve()


def run(command, cwd, log):
    args = [str(arg) for arg in command]
    with log.open("w", encoding="utf-8") as stream:
        stream.write(f"{subprocess.list2cmdline(args)}\n\n")
        stream.flush()
        result = subprocess.run(args, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        tail = log.read_text(encoding="utf-8", errors="replace").splitlines()[-20:]
        raise ValueError(f"{args[0]} exited {result.returncode}. {log}\n" + "\n".join(tail))


def rtl_sources():
    # The existing flists resolve entries relative to veri/sim, including nested -f entries.
    sim_dir = ROOT / "veri" / "sim"

    def expand(flist):
        for line in flist.read_text(encoding="utf-8").splitlines():
            entry = shlex.split(line, comments=True)
            if not entry or entry[0].startswith("//"):
                continue
            if len(entry) == 2 and entry[0] == "-f":
                yield from expand((sim_dir / entry[1]).resolve())
            elif len(entry) == 1 and Path(entry[0]).suffix in {".v", ".sv"}:
                yield (sim_dir / entry[0]).resolve(strict=True)
            else:
                raise ValueError(f"Unsupported entry in {flist}: {line}")

    return list(dict.fromkeys(expand(ROOT / "veri" / "flist" / "dut_axi_soc.f")))


def prepare_firmware(args, out, words):
    if args.firmware_bin:
        binary = args.firmware_bin.resolve(strict=True)
    else:
        gcc = args.riscv_gcc
        if not gcc:
            local_bin = ROOT / "build" / "riscv14" / "bin"
            gcc = (shutil.which(str(local_bin / "riscv-none-elf-gcc"))
                   or shutil.which("riscv-none-elf-gcc")
                   or shutil.which("riscv64-unknown-elf-gcc"))
        if not gcc:
            raise ValueError("Set --riscv-gcc or supply an already linked --firmware-bin")
        gcc = find_tool(gcc)
        objcopy = find_tool(gcc.stem.removesuffix("gcc") + "objcopy", gcc.parent)
        csrc = ROOT / "veri" / "soc_csrc"
        run([gcc, "-march=rv32im", "-mabi=ilp32", "-Os", "-ffreestanding", "-nostdlib",
             "-ffunction-sections", "-fdata-sections", "-I", csrc,
             f"-Wl,--defsym=__ram_length={words * 4}", "-T", csrc / "link.ld",
             "-Wl,--build-id=none,--gc-sections,-Map=smoke.map", csrc / "start.S",
             HERE / "a7_smoke.c", csrc / "dsa_accel_mmio.c", "-lgcc", "-o", "smoke.elf"],
            out, out / "firmware_build.log")
        binary = out / "smoke.bin"
        run([objcopy, "-O", "binary", "smoke.elf", binary], out, out / "objcopy.log")

    if not 0 < binary.stat().st_size <= words * 4:
        raise ValueError(f"Firmware size must be between 1 and {words * 4} bytes: {binary}")
    run([sys.executable, ROOT / "veri" / "tb" / "elf_to_mem.py", binary,
         out / "cpu.mem", "--depth", words], out, out / "mem_conversion.log")


def prepare_rtl(out, words, half_period_ps):
    wrapper = out / "a7_soc.sv"
    wrapper.write_text(f'''module a7_soc (
    input  wire clk, rst_n, uart_rx,
    output wire uart_tx, npu_busy, npu_irq, soc_finish, cpu_trap,
    output wire [31:0] soc_status
);
    soc_top #(
        .SIZE(16), .IA_CACHE_BLOCKS(4), .PS_FRAME_COUNT(16),
        .CPU_MEM_DP({words}), .CPU_MEM_INIT_EN(1), .CPU_MEM_PATH("cpu.mem")
    ) u_soc (
        .clk(clk), .rst_n(rst_n), .mem_reload_req(1'b0), .uart_rx(uart_rx),
        .uart_tx(uart_tx), .npu_busy(npu_busy), .npu_irq(npu_irq),
        .soc_finish(soc_finish), .soc_status(soc_status), .cpu_trap(cpu_trap)
    );
endmodule
''', encoding="ascii")
    sources = [*rtl_sources(), wrapper]
    (out / "rtl_sources.txt").write_text(
        "\n".join(p.as_posix() for p in [ROOT / "include", *sources]) + "\n",
        encoding="utf-8",
    )
    period_ns = 2 * half_period_ps / 1000
    (out / "clock.xdc").write_text(
        f"create_clock -name soc_clk -period {period_ns:.3f} [get_ports clk]\n",
        encoding="ascii",
    )
    return sources


def simulate(vivado_bin, out, stage, sources, half_period_ps, timeout_cycles):
    work = out / stage
    work.mkdir(exist_ok=True)
    glbl = vivado_bin.parent / "data" / "verilog" / "src" / "glbl.v"
    project = work / "smoke.prj"
    if stage == "rtl":
        shutil.copyfile(out / "cpu.mem", work / "cpu.mem")
    design = [("sv" if p.suffix == ".sv" else "verilog", p) for p in sources]
    design += [("sv", HERE / "a7_smoke_tb.sv"), ("verilog", glbl)]
    project.write_text(
        "".join(f'{language} work "{path.as_posix()}"\n' for language, path in design),
        encoding="utf-8",
    )
    (work / "a7_sim_config.vh").write_text(
        f"`define A7_HALF_PERIOD_PS {half_period_ps}\n"
        f"`define A7_TIMEOUT_CYCLES {timeout_cycles}\n", encoding="ascii",
    )
    print(f"[{stage}] XSim compilation and self-check: {work}", flush=True)
    compile_args = ["-prj", project.name, "-i", "."]
    if stage == "rtl":
        compile_args += ["-i", ROOT / "include", "-d", "XILINX_FPGA"]
    run([find_tool("xvlog", vivado_bin), *compile_args], work, work / "compile.log")
    run([find_tool("xelab", vivado_bin), "--timescale", "1ns/1ps",
         "-L", "unisims_ver", "-L", "unimacro_ver",
         "-s", "a7_smoke", "work.a7_smoke_tb", "work.glbl"],
        work, work / "elaborate.log")
    log = work / "simulate.log"
    run([find_tool("xsim", vivado_bin), "a7_smoke", "-runall", "-onfinish", "quit"], work, log)
    transcript = log.read_text(encoding="utf-8", errors="replace")
    passed = re.search(r"^A7_SOC_PASS cycle=\d+ status=00000001\s*$", transcript, re.MULTILINE)
    if not passed or re.search(r"^(?:Fatal:|ERROR:)", transcript, re.MULTILINE):
        tail = "\n".join(transcript.splitlines()[-18:])
        raise ValueError(f"{stage} simulation failed: {log}\n{tail}")
    print(f"[{stage}] {passed.group().strip()}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vivado-bin", type=Path, help="Vivado installation's bin directory")
    parser.add_argument("--riscv-gcc", help="Path to a RISC-V bare-metal GCC executable")
    parser.add_argument("--firmware-bin", type=Path, help="Optional RV32 raw image linked at 0")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--part", default=DEFAULT_PART)
    parser.add_argument("--ram-kib", type=int, default=512, choices=(128, 256, 512, 768, 1024))
    parser.add_argument("--clock-mhz", type=float, default=100)
    parser.add_argument("--timeout-cycles", type=int, default=100000)
    parser.add_argument("--threads", type=int, default=4, choices=range(1, 9))
    parser.add_argument("--stage", choices=("all", "rtl", "synth"), default="all")
    parser.add_argument("--implement", action="store_true", help="Also route and run routed functional simulation")
    args = parser.parse_args()
    if args.implement and args.stage != "all":
        parser.error("--implement requires --stage all")
    if not 0 < args.clock_mhz <= 1000:
        parser.error("--clock-mhz must be in (0, 1000]")
    if not 0 < args.timeout_cycles < 2**31 - 1:
        parser.error("--timeout-cycles must be a positive signed 32-bit cycle limit")
    if not re.fullmatch(r"xc7a200t[a-z0-9]+-[123]", args.part, re.IGNORECASE):
        parser.error("--part must be a Vivado XC7A200T part, including package and speed grade")

    words = args.ram_kib * 256
    half_period_ps = round(500000 / args.clock_mhz)
    out = (args.out or ROOT / "build" / f"fpga_a7_{args.ram_kib}k").resolve()
    if out.exists() and any(out.iterdir()):
        parser.error(f"Choose an empty build directory to keep run results separate: {out}")
    out.mkdir(parents=True, exist_ok=True)
    vivado_dir = args.vivado_bin or os.environ.get("XILINX_VIVADO")
    if vivado_dir and not args.vivado_bin:
        vivado_dir = Path(vivado_dir) / "bin"
    vivado = find_tool("vivado", vivado_dir)
    print(f"{args.part}, {args.ram_kib} KiB ({words} x 32), {2 * half_period_ps} ps clock: {out}", flush=True)
    prepare_firmware(args, out, words)
    sources = prepare_rtl(out, words, half_period_ps)
    if args.stage in {"all", "rtl"}:
        simulate(vivado.parent, out, "rtl", sources, half_period_ps, args.timeout_cycles)
    if args.stage in {"all", "synth"}:
        print(f"[synth] Vivado synthesis: {out / 'synth_console.log'}", flush=True)
        run([vivado, "-mode", "batch", "-source", HERE / "a7_flow.tcl",
             "-log", "synth_vivado.log", "-journal", "synth_vivado.jou",
             "-tclargs", "synth", args.part, args.threads], out, out / "synth_console.log")
    if args.stage == "all":
        simulate(vivado.parent, out, "post_synth", [out / "a7_synth_func.v"],
                 half_period_ps, args.timeout_cycles)
    if args.implement:
        print(f"[route] Vivado implementation: {out / 'route_console.log'}", flush=True)
        run([vivado, "-mode", "batch", "-source", HERE / "a7_flow.tcl",
             "-log", "route_vivado.log", "-journal", "route_vivado.jou",
             "-tclargs", "route", args.part, args.threads], out, out / "route_console.log")
        simulate(vivado.parent, out, "post_route", [out / "a7_route_func.v"],
                 half_period_ps, args.timeout_cycles)
    print(f"Completed: {out}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit(str(exc)) from exc
