"""Write an ignored machine-local configuration; preserve existing license settings."""
import argparse
import os
from pathlib import Path
import shutil

HERE = Path(__file__).absolute().parent
parser = argparse.ArgumentParser()
parser.add_argument('--gcc-bin', type=Path, default=HERE/'../../build/riscv14/bin')
parser.add_argument('--make', default='C:/msys64/usr/bin/make.exe')
parser.add_argument('--build-root', type=Path, default=HERE/'../../build/windows')
opt = parser.parse_args()
compiler = opt.gcc_bin.absolute()
prefix = next((p for p in ['riscv-none-elf-', 'riscv64-unknown-elf-', 'riscv-none-embed-']
               if (compiler/(p+'gcc.exe')).is_file()), None)
if prefix is None:
    raise SystemExit('No RISC-V GCC in ' + str(compiler))
if not Path(opt.make).is_file():
    raise SystemExit('GNU make 4.x not found: ' + opt.make)
build = opt.build_root.absolute()
build.mkdir(parents=True,exist_ok=True)
(build/'tmp').mkdir(exist_ok=True)
tflm = HERE/'../../drivers/tflm/my_tflm'
relative = os.path.relpath(build,tflm).replace(chr(92),'/')
lines = [f'{var} := {(compiler/(prefix+suffix)).as_posix()}' for var,suffix in
         [('SOC_GCC','gcc'),('SOC_GXX','g++'),('SOC_AR','ar'),('SOC_OBJCOPY','objcopy')]]
lines += ['SOC_ARCH_FLAGS := -march=rv32im_zicsr -mabi=ilp32',
          f'TFLM_BUILD_DIR = {relative}/tflm-$(SOC_ARCH_TAG)-$(TFLM_ACCEL_TAG)-S$(MMA_SIZE)-C$(MMA_IA_CACHE_BLOCKS)-P$(MMA_PS_FRAME_COUNT)',
          f'TFLM_HOST_BUILD_DIR := {relative}/tflm-host-sw',
          'MAKE := '+opt.make.replace(chr(92),'/'),
          'SHELL := '+(Path(opt.make).parent/'bash.exe').as_posix(),
          'export MODELSIM_BUILD_ROOT := '+(build/'modelsim').as_posix()]
for key in ['TEMP','TMP','TMPDIR']:
    lines.append(f'export {key} := {(build/"tmp").as_posix()}')
packages = build/'python-packages'
if packages.is_dir():
    lines.append('export PYTHONPATH := '+packages.as_posix())
for key in ['MGLS_LICENSE_FILE','MGLS_LICENSEFILE','USERPROFILE','COMSPEC','APPDATA','LOCALAPPDATA']:
    if key in os.environ:
        lines.append('export '+key+' := '+os.environ[key].replace(chr(92),'/'))
(HERE/'windows.local.mk').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Wrote windows.local.mk; license contents unchanged. Do not commit this local file.')
