"""Portable replacement for find/grep in the host and RV32 library builds."""
from pathlib import Path
import sys

print(' '.join(p.as_posix() for p in sorted(Path(sys.argv[1]).rglob('*'))
               if p.suffix in ('.cc', '.c') and
               not {'micro', 'experimental'}.intersection(p.parts)))
