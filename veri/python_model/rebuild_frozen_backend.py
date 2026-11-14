#!/usr/bin/env python3
"""Rebuild the frozen RTL C++ snapshot with g++ only; no Verilator is invoked."""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess

HERE=Path(__file__).resolve().parent

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--backend",default="s16_c4_p16")
    ap.add_argument("--cxx",default="g++")
    ap.add_argument("--jobs",type=int,default=4)
    args=ap.parse_args()
    cpp=HERE/"frozen_cpp"/args.backend
    inc=HERE/"cpp_runtime/include"
    dest=HERE/"backends"/args.backend
    if not cpp.is_dir() or not inc.is_dir():
        ap.error("Frozen C++ and runtime sources are provided in the handoff archive")
    manifest=json.loads((dest/"manifest.json").read_text())
    build=HERE/"build_frozen"/args.backend
    build.mkdir(parents=True,exist_ok=True)
    sources=sorted(cpp.glob("*.cpp"))
    sources += [inc/name for name in [
        "verilated.cpp","verilated_dpi.cpp","verilated_timing.cpp","verilated_threads.cpp"]]
    sources += [HERE/"backend.cpp",HERE/"capture.cpp",HERE/"server.cpp"]
    flags=[
        "-std=c++20","-O2","-fPIC","-pthread","-DVM_TIMING=1","-DVM_TRACE=0",
        "-DVM_COVERAGE=0","-DVM_SC=0",f"-DMODEL_SIZE={manifest['size']}",
        "-I"+str(cpp),"-I"+str(inc),"-I"+str(inc/"vltstd"),
        "-Wno-tautological-compare",
    ]
    def compile_one(item):
        index,source=item
        obj=build/f"{index:03}_{source.stem}.o"
        subprocess.run([args.cxx,*flags,"-c",str(source),"-o",str(obj)],check=True)
        return obj
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        objects=list(pool.map(compile_one,enumerate(sources)))
    binary=build/"rtl_server"
    subprocess.run([args.cxx,"-static","-pthread",*map(str,objects),"-latomic",
                    "-o",str(binary)],check=True)
    subprocess.run(["strip","--strip-unneeded",str(binary)],check=True)
    (dest/"rtl_server").write_bytes(binary.read_bytes())
    (dest/"rtl_server").chmod(0o755)
    manifest["server_sha256"]=hashlib.sha256(binary.read_bytes()).hexdigest()
    manifest["frozen_rebuild_compiler"]=subprocess.check_output([args.cxx,"--version"],text=True).splitlines()[0]
    (dest/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(f"Rebuilt {dest/'rtl_server'} without Verilator")

if __name__=="__main__":
    main()
