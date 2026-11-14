#!/usr/bin/env python3
"""Verify the handoff using only the Python standard library."""
import hashlib
from pathlib import Path
import sys

root=Path(__file__).resolve().parent
manifest=root/"MANIFEST.sha256"
if not manifest.exists():
    raise SystemExit("MANIFEST.sha256 is missing")
checked=0
for line in manifest.read_text().splitlines():
    expected,name=line.split("  ",1)
    path=root/name
    if not path.is_file(): raise SystemExit(f"MISSING {name}")
    digest=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1<<20),b""): digest.update(chunk)
    if digest.hexdigest()!=expected: raise SystemExit(f"MISMATCH {name}")
    checked+=1
print(f"PASS: {checked} files match MANIFEST.sha256")
