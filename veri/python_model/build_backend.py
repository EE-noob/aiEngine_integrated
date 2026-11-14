#!/usr/bin/env python3
"""Build a Python-callable RTL snapshot and an independent --binary runner."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WARNINGS = [
    "GENUNNAMED", "VARHIDDEN", "WIDTHEXPAND", "UNUSEDSIGNAL", "UNUSED",
    "UNUSEDGENVAR", "UNDRIVEN", "PINMISSING", "STMTDLY", "DECLFILENAME",
    "CASEINCOMPLETE", "EOFNEWLINE", "PROCASSINIT", "SYNCASYNCNET", "COMBDLY",
    "PINCONNECTEMPTY", "WIDTHTRUNC", "ASCRANGE", "INITIALDLY", "BLKSEQ",
    "MULTIDRIVEN", "LATCH",
]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--size", type=int, default=16)
    ap.add_argument("--cache", type=int, default=4)
    ap.add_argument("--ps", type=int, default=16)
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--cxx", default="g++-13" if shutil.which("g++-13") else "g++")
    ap.add_argument("--reference", action="store_true")
    args = ap.parse_args()
    for value in [args.size, args.cache]:
        if value < 2 or value & (value-1):
            ap.error("size and cache must be powers of two >= 2")
    if args.ps < 1:
        ap.error("ps must be positive")
    tag = f"s{args.size}_c{args.cache}_p{args.ps}"
    work = HERE / "build" / tag
    dest = HERE / "backends" / tag
    work.mkdir(parents=True, exist_ok=True)
    dest.mkdir(parents=True, exist_ok=True)
    npu = ROOT / "rtl/axi_accelerator/npu"
    sources = sorted(npu.glob("*.sv")) + sorted(npu.glob("*.v"))
    sources += [ROOT / "veri/top_regression/ddr_axi_mem_model.sv",
                ROOT / "veri/top_regression/tb_npu_top.sv", HERE / "cycle_probe.sv"]
    flags = [
        "--timing", "-sv", "--top-module", "tb_npu_top", "-Wno-fatal",
        *[f"-Wno-{warning}" for warning in WARNINGS],
        f"-DTB_SIZE={args.size}", f"-DTB_IA_CACHE_BLOCKS={args.cache}",
        f"-DTB_PS_FRAME_COUNT={args.ps}", "-DTB_AXI_READ_OUTSTANDING=4",
        "-DTB_DATA_WIDTH=16", "-DTB_WEIGHT_WIDTH=16",
    ]
    env = dict(os.environ, CXX=args.cxx)
    subprocess.run(["verilator", "--cc", "--prefix", "VNpuPython",
                    "--Mdir", str(work), "-CFLAGS", "-fPIC -O2",
                    *flags, *map(str, sources)], env=env, check=True)
    subprocess.run(["make", "-C", str(work), "-f", "VNpuPython.mk",
                    f"-j{args.jobs}", "VNpuPython__ALL.a", f"CXX={args.cxx}",
                    "OPT_FAST=-O2", "OPT_SLOW=-O1"], env=env, check=True)
    text = subprocess.check_output(["verilator", "-V"], text=True)
    verilator_root = next(
        line.split("=", 1)[1].strip() for line in text.splitlines()
        if line.strip().startswith("VERILATOR_ROOT") and line.split("=",1)[1].strip()
    )
    inc = Path(verilator_root) / "include"
    runtime = [inc / name for name in [
        "verilated.cpp", "verilated_dpi.cpp", "verilated_timing.cpp",
        "verilated_threads.cpp",
    ]]
    lib = dest / "libnpu_model.so"
    subprocess.run([
        args.cxx, "-std=c++20", "-O2", "-fPIC", "-shared", "-pthread",
        "-static-libstdc++", "-static-libgcc", "-Wl,-Bsymbolic",
        "-I"+str(work), "-I"+str(inc), "-I"+str(inc/"vltstd"),
        str(HERE/"backend.cpp"), str(HERE/"capture.cpp"),
        *map(str,runtime), str(work/"VNpuPython__ALL.a"), "-o", str(lib),
    ], check=True)
    server = dest / "rtl_server"
    subprocess.run([
        args.cxx, "-std=c++20", "-O2", "-static", "-pthread",
        f"-DMODEL_SIZE={args.size}",
        "-I"+str(work), "-I"+str(inc), "-I"+str(inc/"vltstd"),
        str(HERE/"backend.cpp"), str(HERE/"capture.cpp"), str(HERE/"server.cpp"),
        *map(str,runtime), str(work/"VNpuPython__ALL.a"), "-latomic",
        "-o", str(server),
    ], check=True)
    if args.reference:
        ref = work / "reference"
        subprocess.run([
            "verilator", "--binary", "--Mdir", str(ref), "-j", str(args.jobs),
            "-CFLAGS", "-O2", "-LDFLAGS", "-static",
            "-MAKEFLAGS", f"CXX={args.cxx}",
            *flags, *map(str,sources), str(HERE/"capture.cpp"),
            "-o", "rtl_reference",
        ], env=env, check=True)
        shutil.copy2(ref/"rtl_reference", dest/"rtl_reference")
    for binary in [lib,server,dest/"rtl_reference"]:
        if binary.exists():
            subprocess.run(["strip","--strip-unneeded",str(binary)],check=True)
    manifest = {
        "schema": 1, "configuration_abi": 2, "external_tiling_required": True, "size": args.size, "ia_cache_blocks": args.cache,
        "ps_frame_count": args.ps, "bus_width": 32, "read_outstanding": 4,
        "data_width": 16, "weight_width": 16, "clock_period_ps": 10000,
        "engine": "original RTL + original tb_npu_top + original DDR model",
        "verilator_version": subprocess.check_output(["verilator","--version"],text=True).strip(),
        "runtime_platform": "Linux x86_64",
        "compiler": subprocess.check_output([args.cxx,"--version"],text=True).splitlines()[0],
        "sources": {str(p.relative_to(ROOT)):digest(p) for p in sources},
        "adapter_sources": {p.name:digest(p) for p in [
            HERE/"capture.hpp",HERE/"capture.cpp",HERE/"backend.cpp",
            HERE/"server.cpp",HERE/"build_backend.py"]},
        "library_sha256": digest(lib),
        "server_sha256": digest(server),
        "reference_sha256": digest(dest/"rtl_reference") if (dest/"rtl_reference").exists() else None,
    }
    (dest/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(f"Built {dest}")

if __name__ == "__main__":
    main()
