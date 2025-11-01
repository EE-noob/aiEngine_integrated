#!/usr/bin/env python3
# 生成输入测试图像并从仿真输出恢复图像

import os
import sys
from time import sleep
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print('Please install pillow: pip install pillow')
    sys.exit(1)

IN_W = 1280
IN_H = 960
OUT_W = 64
OUT_H = 64
SCALE = 15
LEFT_TRIM = (IN_W - 960)//2
SAMPLE_OFFS = 7

FONT_CANDIDATES = [
    "DejaVuSans-Bold.ttf",
    "Arial Bold.ttf",
    "Arialbd.ttf",
    "arialbd.ttf",
    os.path.join(os.environ.get("WINDIR", ""), "Fonts", "arialbd.ttf"),
    os.path.join(os.environ.get("WINDIR", ""), "Fonts", "arial.ttf"),
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
]

def pix_func(r, c):
    return (3*r + 5*c) & 0xFF

def _text_size(draw, text, font):
    try:
        if font is not None:
            if hasattr(font, 'getbbox'):
                bbox = font.getbbox(text)
                return (bbox[2]-bbox[0], bbox[3]-bbox[1])
            if hasattr(font, 'getsize'):
                return font.getsize(text)
        if hasattr(draw, 'textbbox'):
            bbox = draw.textbbox((0,0), text, font=font)
            return (bbox[2]-bbox[0], bbox[3]-bbox[1])
        if hasattr(draw, 'textsize'):
            return draw.textsize(text, font=font)
    except Exception:
        pass
    try:
        fsize = getattr(font, 'size', None)
        if fsize:
            approx = int(fsize * 0.6)
            return (approx, approx)
    except Exception:
        pass
    return (len(text)*10, 20)

def load_large_font(pixels):
    for cand in FONT_CANDIDATES:
        if not cand:
            continue
        try:
            return ImageFont.truetype(cand, pixels)
        except Exception:
            continue
    return None

def draw_fallback_digit(img, digit, fill=255):
    tmp_size = 128
    tmp = Image.new('L', (tmp_size, tmp_size), color=0)
    tmp_draw = ImageDraw.Draw(tmp)
    tmp_draw.text((10, 0), digit, fill=fill)
    scale = max(1, int(min(IN_W, IN_H) * 0.85 / tmp_size))
    big = tmp.resize((tmp_size * scale, tmp_size * scale), Image.BILINEAR)
    x = (IN_W - big.width) // 2
    y = (IN_H - big.height) // 2
    img.paste(big, (x, y))

def gen_input_raw(path_raw, path_png=None, mode='digit', digit='7'):
    if mode == 'pattern':
        buf = bytearray(IN_W * IN_H)
        for r in range(IN_H):
            for c in range(IN_W):
                buf[r*IN_W + c] = pix_func(r, c)
        if path_png:
            img = Image.frombytes('L', (IN_W, IN_H), bytes(buf))
    else:
        bg = bytearray(IN_W * IN_H)
        for r in range(IN_H):
            v = int(50 + (r * 150) / max(1, IN_H-1))
            for c in range(IN_W):
                bg[r*IN_W + c] = v
        img = Image.frombytes('L', (IN_W, IN_H), bytes(bg))
        draw = ImageDraw.Draw(img)
        try:
            fsize = int(min(IN_W, IN_H) * 0.9)
            font = load_large_font(fsize)
        except Exception:
            font = None
        txt = str(digit)[0]
        if font is not None:
            tw, th = _text_size(draw, txt, font)
            x = (IN_W - tw) // 2
            y = (IN_H - th) // 2
            draw.text((x, y), txt, fill=255, font=font)
        else:
            draw_fallback_digit(img, txt, fill=255)
        buf = img.tobytes()

    with open(path_raw, 'wb') as f:
        f.write(buf)
    
    try:
        with open('in_image.mem', 'w') as mf:
            for i in range(0, len(buf)):
                mf.write(f"%02X\n" % buf[i])
        print('Generated in_image.mem')
    except Exception as e:
        print('Failed to write in_image.mem:', e)
    
    if path_png:
        img.save(path_png)
    print(f'Generated input raw -> {path_raw} (mode={mode})')

def build_expected_out():
    buf = bytearray(OUT_W * OUT_H)
    for oy in range(OUT_H):
        for ox in range(OUT_W):
            r = SAMPLE_OFFS + SCALE*oy
            c = (LEFT_TRIM + SAMPLE_OFFS) + SCALE*ox
            buf[oy*OUT_W + ox] = pix_func(r, c)
    return bytes(buf)

def wait_for_file(path, timeout=10.0):
    waited = 0.0
    while waited < timeout:
        if os.path.exists(path) and os.path.getsize(path) >= OUT_W*OUT_H:
            return True
        sleep(0.1)
        waited += 0.1
    return False

def reconstruct_image(in_raw_path, out_png, label=''):
    """通用图像重建函数"""
    if not os.path.exists(in_raw_path):
        print(f'Error: {in_raw_path} not found')
        return False
    
    with open(in_raw_path, 'rb') as f:
        data = f.read()
    
    if len(data) < OUT_W*OUT_H:
        print(f'Error: {in_raw_path} too small: {len(data)} bytes')
        return False
    
    data = data[:OUT_W*OUT_H]
    img = Image.frombytes('L', (OUT_W, OUT_H), data)
    img.save(out_png)
    print(f'{label}Image saved to {out_png}')
    return True

def compare_images(file1, file2, label1='Image 1', label2='Image 2'):
    """比较两个图像文件"""
    if not os.path.exists(file1) or not os.path.exists(file2):
        print(f'Error: Cannot compare - one or both files missing')
        print(f'  {file1}: {"exists" if os.path.exists(file1) else "missing"}')
        print(f'  {file2}: {"exists" if os.path.exists(file2) else "missing"}')
        return -1
    
    with open(file1, 'rb') as f:
        data1 = f.read(OUT_W*OUT_H)
    with open(file2, 'rb') as f:
        data2 = f.read(OUT_W*OUT_H)
    
    diffs = sum(1 for i in range(min(len(data1), len(data2))) if data1[i] != data2[i])
    
    if diffs == 0:
        print(f'  ✓ {label1} == {label2}: MATCH (100%)')
    else:
        match_pct = (1 - diffs/(OUT_W*OUT_H)) * 100
        print(f'  ✗ {label1} != {label2}: {diffs}/{OUT_W*OUT_H} pixels differ ({match_pct:.2f}% match)')
    return diffs

def reconstruct_all():
    """重建所有输出图像"""
    print("\n========================================")
    print("  Reconstructing Output Images")
    print("========================================\n")
    
    files_ok = []
    
    # 1. SRAM after write (OV5640 -> SRAM)
    print("1. Reconstructing sram_after_write.raw...")
    if reconstruct_image('sram_after_write.raw', 
                        'sram_after_write.png', 
                        '   '):
        print('   └─ OV5640 写入内部 SRAM 的数据')
        files_ok.append('sram')
    
    # 2. CPU read image (CPU <- SRAM)
    print("\n2. Reconstructing cpu_read_image.raw...")
    if reconstruct_image('cpu_read_image.raw', 
                        'cpu_read_image.png', 
                        '   '):
        print('   └─ CPU 从内部 SRAM 读取的数据')
        files_ok.append('cpu_read')
    
    # 3. CPU write to external SRAM
    print("\n3. Reconstructing cpu_write_sram.raw...")
    if reconstruct_image('cpu_write_sram.raw', 
                        'cpu_write_sram.png', 
                        '   '):
        print('   └─ CPU 写入外部 512KB SRAM 的数据')
        files_ok.append('cpu_write')
    
    # 4. 三方对比
    print("\n========================================")
    print("  Three-Way Comparison Results")
    print("========================================\n")
    
    if 'sram' in files_ok and 'cpu_read' in files_ok:
        print("Comparison 1: Internal SRAM vs CPU Read")
        compare_images('sram_after_write.raw', 'cpu_read_image.raw', 
                      'Internal SRAM', 'CPU Read')
    
    if 'sram' in files_ok and 'cpu_write' in files_ok:
        print("\nComparison 2: Internal SRAM vs CPU Write (External SRAM)")
        compare_images('sram_after_write.raw', 'cpu_write_sram.raw',
                      'Internal SRAM', 'CPU Write')
    
    if 'cpu_read' in files_ok and 'cpu_write' in files_ok:
        print("\nComparison 3: CPU Read vs CPU Write")
        compare_images('cpu_read_image.raw', 'cpu_write_sram.raw',
                      'CPU Read', 'CPU Write')
    
    # 5. 总结
    print("\n========================================")
    print("  Reconstruction Summary")
    print("========================================")
    print("\nGenerated PNG files:")
    if 'sram' in files_ok:
        print("  ✓ sram_after_write.png")
    if 'cpu_read' in files_ok:
        print("  ✓ cpu_read_image.png")
    if 'cpu_write' in files_ok:
        print("  ✓ cpu_write_sram.png")
    
    if len(files_ok) < 3:
        print("\n⚠ Warning: Some files were not generated")
        if 'sram' not in files_ok:
            print("  - sram_after_write.raw missing")
        if 'cpu_read' not in files_ok:
            print("  - cpu_read_image.raw missing")
        if 'cpu_write' not in files_ok:
            print("  - cpu_write_sram.raw missing")
    
    print("\nData flow verification:")
    print("  Camera → OV5640 → Internal SRAM → CPU Read → External SRAM")
    print("           (sram_after_write)      (cpu_read)   (cpu_write)")
    print("========================================\n")

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate test image and reconstruct outputs')
    parser.add_argument('--mode', choices=['digit', 'pattern'], default='digit',
                       help='Generation mode: digit or pattern')
    parser.add_argument('--digit', default='7',
                       help='Digit to display (for digit mode)')
    parser.add_argument('--reconstruct-only', action='store_true',
                       help='Only reconstruct existing output files')
    
    args = parser.parse_args()
    
    if not args.reconstruct_only:
        # 生成输入图像
        print("Generating input image...")
        gen_input_raw('in_image.raw', 'in_image.png', 
                     mode=args.mode, digit=args.digit)
        print('\nInput image generated: in_image.raw, in_image.png')
        print('Now run the simulation:')
        print('  iverilog -g2012 -o sim tb_ov5640_icb_top.v ...')
        print('  vvp sim')
        print('\nAfter simulation, run:')
        print('  python generate_and_reconstruct.py --reconstruct-only')
    else:
        # 仅重建输出图像
        reconstruct_all()

