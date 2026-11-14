#!/usr/bin/env python3
"""Stage and archive the working-tree simulation handoff, including frozen RTL."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
PM=ROOT/"veri/python_model"
DEFAULT_LABEL="aiEngine_python_cycle_handoff_20261109"
BAD_DIRS={".git",".svn","__pycache__","obj_dir","out","runs","CMakeFiles",
          ".Xil",".cache",".github",".vscode","proofs"}
BAD_SUFFIXES={".o",".a",".so",".pyc",".log",".jou",".fsdb",".vcd",".elf",
              ".bin",".map",".zip",".tgz",".gz",".xz"}

def hash_file(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""): h.update(chunk)
    return h.hexdigest()

def copy_file(source,dest):
    source,dest=Path(source),Path(dest)
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,dest)
    # Keep executability, make all shipped content readable for the recipient.
    dest.chmod(0o755 if source.stat().st_mode & 0o111 else 0o644)

def source_tree(source,dest):
    if not source.is_dir(): raise FileNotFoundError(source)
    for current,dirs,files in os.walk(source,followlinks=False):
        dirs[:]=[d for d in dirs if d not in BAD_DIRS and
                 not d.startswith(("build","simv")) and
                 not d.endswith((".vdb",".csrc",".daidir")) and
                 not (Path(current)/d).is_symlink()]
        for name in files:
            path=Path(current)/name
            if path.suffix.lower() in BAD_SUFFIXES or name.endswith(("~",".swp",".ninja")):
                continue
            if path.name in {"cmake_install.cmake","CMakeCache.txt"}:
                continue
            if path.is_symlink() and not path.resolve().is_file(): continue
            if not path.is_file(): continue
            with path.open("rb") as f:
                if f.read(4)==b"\x7fELF": continue
            copy_file(path,dest/path.relative_to(source))

def stage(dest,resume=False):
    if dest.exists() and not resume:
        raise FileExistsError(f"{dest} exists; use a different --label or --finalize")
    dest.mkdir(parents=True,exist_ok=resume)
    for rel in ["rtl/axi_accelerator","picorv32","include",
                "veri/env","veri/interface","veri/uvc","veri/test","veri/flist",
                "veri/soc_csrc","veri/tools","veri/top_regression"]:
        source_tree(ROOT/rel,dest/rel)
    for folder in ["veri/sim","veri/tb"]:
        for p in (ROOT/folder).iterdir():
            if p.is_file() and (p.suffix in {".py",".sv",".svh",".sh",".json",".hier"} or p.name=="Makefile"):
                copy_file(p,dest/folder/p.name)
    source_tree(ROOT/"veri/tb/sram",dest/"veri/tb/sram")
    for folder in ["ai_mem_gen_smoke_test","ai_ral_mem_gen_on_calc_start_test"]:
        for p in (ROOT/"veri/tb"/folder).iterdir():
            if p.is_file() and not p.name.startswith(("actual","debug")):
                copy_file(p,dest/"veri/tb"/folder/p.name)
    for p in (ROOT/"drivers").iterdir():
        if p.is_file(): copy_file(p,dest/"drivers"/p.name)
    for rel in ["drivers/tflm/inc","drivers/tflm/src"]:
        source_tree(ROOT/rel,dest/rel)
    tflm=ROOT/"drivers/tflm/my_tflm"
    for p in tflm.iterdir():
        if p.is_file() and (p.name=="Makefile" or p.suffix in {".cc",".md",".cmake"}):
            if p.name!="cmake_install.cmake": copy_file(p,dest/p.relative_to(ROOT))
    micro=tflm/"tflite-micro"
    downloads=micro/"tensorflow/lite/micro/tools/make/downloads"
    for current,dirs,files in os.walk(micro):
        current=Path(current)
        dirs[:]=[d for d in dirs if d not in BAD_DIRS and not (current/d).is_symlink()]
        if current==downloads:
            dirs[:]=[d for d in dirs if d in {"flatbuffers","gemmlowp","kissfft","ruy","nuclei_sdk"}]
            files=[]
        if current==downloads/"nuclei_sdk":
            dirs[:]=[d for d in dirs if d=="NMSIS"]
        if current==downloads/"nuclei_sdk/NMSIS":
            dirs[:]=[d for d in dirs if d in {"Core","NN"}]
        for name in files:
            p=current/name
            if p.suffix.lower() in BAD_SUFFIXES or not p.is_file(): continue
            if p.name.endswith(("~",".swp")): continue
            with p.open("rb") as f:
                if f.read(4)==b"\x7fELF": continue
            copy_file(p,dest/p.relative_to(ROOT))
    # Python adapter, checked binaries, and the complete validation evidence.
    for p in PM.iterdir():
        if p.is_file() and p.suffix in {".py",".sv",".cpp",".hpp",".md"}:
            copy_file(p,dest/p.relative_to(ROOT))
    shutil.copytree(PM/"backends",dest/"veri/python_model/backends",copy_function=copy_file,dirs_exist_ok=True)
    shutil.copytree(PM/"validation",dest/"veri/python_model/validation",copy_function=copy_file,dirs_exist_ok=True)
    for name in ["ws_int8_tail","ws_s16_output","is_s16_per_channel"]:
        shutil.copytree(PM/"validation"/name/"case",
                        dest/"veri/python_model/examples"/name,copy_function=copy_file,dirs_exist_ok=True)
    for backend in sorted((PM/"backends").iterdir()):
        build=PM/"build"/backend.name
        frozen=dest/"veri/python_model/frozen_cpp"/backend.name
        for p in build.iterdir():
            if p.is_file() and (p.suffix in {".cpp",".h"} or p.name.endswith((".h.fast",".h.slow"))):
                copy_file(p,frozen/p.name)
    verilator_include=Path("/usr/local/share/verilator/include")
    source_tree(verilator_include,dest/"veri/python_model/cpp_runtime/include")
    # Current project design reports and the performance analysis with figures.
    for rel in ["doc/研究所项目/详细设计报告","doc/研究所项目/简明设计报告","doc/throughput_analysis"]:
        source_tree(ROOT/rel,dest/rel)
    doc_names=[
        "DSA 设计目标.md","DSA模块设计文档.md","mma_architecture_design_report_cn.md",
        "项目设计方案.md","项目设计方案v2.md","axi_soc_readme.md",
        "performance_report_cn.md","size_cache_hw_sw_perf_report_cn.md",
        "bus_optimization_report_cn.md","coverage_report_cn.md",
        "rtl_simulation_report.md","原版报告_技术报告.docx",
        "奶龙粉丝团-30017-芯片设计及评估报告.docx",
    ]
    for name in doc_names: copy_file(ROOT/"doc"/name,dest/"doc"/name)
    for rel in ["doc/perf_plots","doc/rtl_verification_figs"]:
        source_tree(ROOT/rel,dest/rel)
    copy_file(ROOT/"README.md",dest/"PROJECT_README.md")
    templates=ROOT/"scripts/packaging/handoff_templates"
    for p in templates.iterdir():
        if p.is_file(): copy_file(p,dest/p.name)
    # External model binaries referenced by the existing SoC build, now local.
    external_models={
        "sensor_calibration_20261016/sensor_calibrator_int16.tflite":
            Path("/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/calibration/sim_20261016/sensor_calibrator_int16.tflite"),
        "sensor_calibration_20261019/sensor_calibrator_complete_int16.tflite":
            Path("/home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/calibration/sim_20261019/sensor_calibrator_complete_int16.tflite"),
    }
    model_index=[]
    for rel,external in external_models.items():
        source=ROOT/"models"/rel if (ROOT/"models"/rel).is_file() else external
        copy_file(source,dest/"models"/rel)
        model_index.append({"file":"models/"+rel,"bytes":source.stat().st_size,"sha256":hash_file(source)})
    for p in sorted((dest/"drivers/tflm/my_tflm/tflite-micro").rglob("*.tflite")):
        model_index.append({"file":str(p.relative_to(dest)),"bytes":p.stat().st_size,"sha256":hash_file(p)})
    (dest/"models/INDEX.json").write_text(json.dumps(model_index,ensure_ascii=False,indent=2)+"\n")
    status=subprocess.check_output(["git","status","--short"],cwd=ROOT,text=True)
    (dest/"SOURCE_STATUS.txt").write_text(status)
    snapshot={
        "project":"aiEngine_integrated","snapshot_date":"2026-11-09",
        "base_commit":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        "snapshot_type":"current working files, including uncommitted changes",
        "source_directory":str(ROOT),"primary_entrypoint":"veri/python_model/run.py",
        "hardware":{"size":16,"cache_blocks":[4,8,16,32],"ps_frame_count":16,"bus_width":32},
        "cycle_validation":json.loads((PM/"validation/summary.json").read_text()),
    }
    (dest/"SOURCE_SNAPSHOT.json").write_text(json.dumps(snapshot,ensure_ascii=False,indent=2)+"\n")
    print(f"Staged {dest}",flush=True)

def shipped(path,dest):
    parts=path.relative_to(dest).parts
    return not any(part in {"build_frozen","__pycache__","results"} for part in parts)

def finalize(dest):
    files=sorted(p for p in dest.rglob("*") if p.is_file() and
                 p.name!="MANIFEST.sha256" and shipped(p,dest))
    manifest="\n".join(f"{hash_file(p)}  {p.relative_to(dest).as_posix()}" for p in files)+"\n"
    (dest/"MANIFEST.sha256").write_text(manifest)
    files.append(dest/"MANIFEST.sha256")
    archive=dest.with_suffix(".zip")
    with zipfile.ZipFile(archive,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in files: z.write(p,arcname=(Path(dest.name)/p.relative_to(dest)).as_posix())
    with zipfile.ZipFile(archive) as z:
        bad=z.testzip()
        if bad: raise RuntimeError(f"ZIP integrity failed at {bad}")
    digest=hash_file(archive)
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n")
    print(json.dumps({"archive":str(archive),"files":len(files),
                      "zip_bytes":archive.stat().st_size,"sha256":digest},indent=2),flush=True)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--label",default=DEFAULT_LABEL)
    ap.add_argument("--stage-only",action="store_true")
    ap.add_argument("--finalize",action="store_true")
    ap.add_argument("--resume-stage",action="store_true")
    args=ap.parse_args()
    dest=ROOT/"deliverables"/args.label
    if not args.finalize: stage(dest,resume=args.resume_stage)
    if not args.stage_only: finalize(dest)

if __name__=="__main__":
    main()
