"""Fetch pinned upstream dependencies omitted from this checkout (no admin install)."""
from pathlib import Path
import hashlib
import io
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def archive(url, dest, md5=None, subdir=None):
    if (dest/'.setup_complete').exists():
        print('present:', dest, flush=True)
        return
    print('download:', url, flush=True)
    data = urllib.request.urlopen(url, timeout=120).read()
    if md5 and hashlib.md5(data).hexdigest() != md5:
        raise RuntimeError('Dependency checksum mismatch: ' + url)
    cache = ROOT/'build/downloads'
    cache.mkdir(parents=True, exist_ok=True)
    (cache/(dest.name + '.sha256')).write_text(url + '\n' + hashlib.sha256(data).hexdigest() + '\n')
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        prefix = z.namelist()[0].split('/')[0] + '/'
        if subdir:
            prefix += subdir.strip('/') + '/'
        for name in z.namelist():
            if not name.startswith(prefix) or name.endswith('/'):
                continue
            relative = name[len(prefix):]
            if dest.name == 'flatbuffers' and not relative.startswith('include/'):
                continue
            target = (dest / relative).resolve()
            if not target.is_relative_to(dest.resolve()):
                raise ValueError(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(z.read(name))
    (dest/'.setup_complete').write_text(hashlib.sha256(data).hexdigest())


def main():
    pico = ROOT/'picorv32'
    if not (pico/'.git').exists():
        archive('https://codeload.github.com/YosysHQ/picorv32/zip/ef203c2b0a3fb793280f5114941416c425c5b461', pico)
    base = ROOT/'drivers/tflm/my_tflm/tflite-micro'
    downloads = base/'tensorflow/lite/micro/tools/make/downloads'
    entries = [
        ('google/flatbuffers', 'v23.5.26', 'flatbuffers', 'e87e8acd8e2d53653387ad78720316e2'),
        ('google/gemmlowp', '719139ce755a0f31cbf1c37f7f98adcc7fc9f425', 'gemmlowp', '7e8191b24853d75de2af87622ad293ba'),
        ('google/ruy', 'd37128311b445e758136b8602d1bbd2a755e115d', 'ruy', 'abf7a91eb90d195f016ebe0be885bb6e'),
        ('mborgerding/kissfft', 'v130', 'kissfft', '438ba1fef5783cc5f5f201395cc477ca'),
    ]
    for repo, version, name, md5 in entries:
        archive(f'https://codeload.github.com/{repo}/zip/{version}', downloads/name, md5)
    archive('https://codeload.github.com/Nuclei-Software/NMSIS/zip/refs/tags/1.3.0',
            downloads/'nuclei_sdk/NMSIS/Core', subdir='NMSIS/Core')
    for name, patch in [('flatbuffers', base/'tensorflow/lite/micro/tools/make/flatbuffers.patch'),
                        ('kissfft', base/'third_party/kissfft/kissfft.patch')]:
        prefix = (downloads/name).relative_to(ROOT).as_posix()
        command = ['git','apply','--ignore-whitespace','--directory='+prefix]
        if subprocess.run([*command,'--check',str(patch)],cwd=ROOT,capture_output=True).returncode == 0:
            subprocess.run([*command,str(patch)],cwd=ROOT,check=True)
        elif subprocess.run([*command,'--reverse','--check',str(patch)],cwd=ROOT,capture_output=True).returncode:
            raise RuntimeError('Cannot apply required patch: '+str(patch))


if __name__ == '__main__':
    main()
