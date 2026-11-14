#!/usr/bin/env python3
"""List or remove transient EDA logs and synthesis crash dumps."""

import argparse
from fnmatch import fnmatchcase
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[2]
EXCLUDED = {".git", "paper", "deliverables", "doc", "drivers", "picorv32"}
LOG_PATTERNS = (
    "*.backup.log", "*.backup.jou", "vivado*.log", "vivado*.jou",
    "updatemem*.log", "updatemem*.jou", "hs_err_pid*.log",
    "xvlog.log", "xelab.log", "xsim.log", "xsimcrash.log", "xsimkernel.log",
)
ROOT_DUMP_PATTERNS = (
    "beforepop*.blif", "beforepop*.v", "afterpop*.blif", "afterpop*.v",
    "clockInfo.txt", "tight_setup_hold_pins.txt", "xvlog.pb", "-.d",
)


def candidates():
    tracked = {
        os.fsdecode(name)
        for name in subprocess.check_output(
            ["git", "ls-files", "-z"], cwd=ROOT
        ).split(b"\0") if name
    }
    for current, directories, files in os.walk(ROOT, followlinks=False):
        directories[:] = sorted(
            name for name in directories
            if name not in EXCLUDED and not (Path(current) / name).is_symlink()
        )
        for name in sorted(files):
            path = Path(current) / name
            relative = path.relative_to(ROOT)
            if path.is_symlink() or relative.as_posix() in tracked:
                continue
            patterns = LOG_PATTERNS
            if Path(current) == ROOT:
                patterns += ROOT_DUMP_PATTERNS
            if any(fnmatchcase(name, pattern) for pattern in patterns):
                yield path
            elif ".Xil" in relative.parts and name.endswith(".pb.log"):
                yield path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="remove listed files")
    args = parser.parse_args()
    count = size = 0
    for path in candidates():
        size += path.stat().st_size
        count += 1
        print(path.relative_to(ROOT))
        if args.apply:
            path.unlink()
    action = "Removed" if args.apply else "Selected"
    print(f"{action} {count} files ({size:,} bytes).")


if __name__ == "__main__":
    main()
