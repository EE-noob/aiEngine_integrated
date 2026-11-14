#!/usr/bin/env python3
"""Run the packaged RTL model with Python; no Verilator or pip is needed."""
import argparse
import json
from pathlib import Path
import sys

from runtime import NpuModel, available_backends

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list",action="store_true")
    parser.add_argument("--case",type=Path)
    parser.add_argument("--backend",type=Path)
    parser.add_argument("--trace",type=Path)
    parser.add_argument("--result",type=Path)
    parser.add_argument("--dump-memory",type=Path)
    parser.add_argument("--max-cycles",type=int,default=2_000_000)
    parser.add_argument("--single-step",action="store_true",
                        help="drive every cycle through the Python step() API")
    parser.add_argument("--plusarg",action="append",default=[])
    args = parser.parse_args()
    if args.list:
        for path in available_backends():
            print(path.name)
        return 0
    if args.case is None:
        parser.error("--case is required unless --list is given")
    try:
        with NpuModel(args.case,backend=args.backend,trace=args.trace,
                      plusargs=args.plusarg,timeout_cycles=args.max_cycles) as model:
            if args.single_step:
                while not model.finished and model.cycles < args.max_cycles:
                    model.step()
                result = model.result()
            else:
                result = model.run(args.max_cycles)
            if args.dump_memory:
                args.dump_memory.parent.mkdir(parents=True,exist_ok=True)
                args.dump_memory.write_text("".join(f"{word:08x}\n" for word in model.memory()))
        text = json.dumps(result,ensure_ascii=False,indent=2)
        if args.result:
            args.result.parent.mkdir(parents=True,exist_ok=True)
            args.result.write_text(text+"\n",encoding="utf-8")
        print(text,flush=True)
        return 0 if result["passed"] else 1
    except (ValueError,OSError,RuntimeError) as exc:
        print(f"[PY_MODEL] ERROR: {exc}",file=sys.stderr)
        return 2

if __name__ == "__main__":
    raise SystemExit(main())
