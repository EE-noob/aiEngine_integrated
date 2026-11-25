from pathlib import Path
import urllib.request
import zipfile
import sys
root=Path(sys.argv[1]).resolve()
root.mkdir(parents=True,exist_ok=True)
url='https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v14.2.0-3/xpack-riscv-none-elf-gcc-14.2.0-3-win32-x64.zip'
archive=root/'xpack-riscv-14.zip'
if not archive.exists():
    print('Downloading Windows RISC-V GCC 14.2.0...',flush=True)
    with urllib.request.urlopen(url,timeout=120) as response,archive.open('wb') as out:
        while chunk:=response.read(4*1024*1024): out.write(chunk)
print('Extracting...',flush=True)
with zipfile.ZipFile(archive) as z:
    for info in z.infolist():
        target=(root/info.filename).resolve()
        if not target.is_relative_to(root): raise ValueError(info.filename)
        z.extract(info,root)
print('Installed',root,flush=True)
