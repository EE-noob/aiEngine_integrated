import numpy as np
import os
import random
import struct
import shutil
#python ./generate_test_case_complex_mem.py --K 64 --N 32 --M 128 --lhs_dtype 1 --quant_mode 0 --out_dir ./test_case0
def compute_requant_params(acc: np.ndarray):
    """
    根据累加结果范围，生成 dst_mult 和 dst_shift，使得
      output = (acc * dst_mult + (1 << (shift-1))) >> shift
    落在 int8 范围内且不完全溢出。
    """
    acc_min = int(acc.min())
    acc_max = int(acc.max())
    max_abs = max(abs(acc_min), abs(acc_max))
    if max_abs == 0:
        # 全 0，任意量化都行，返回恒等
        return 1, 0

    # 我们使用右移 (shift >= 0)，不进行小数放大，保证简单可靠
    # 目标：max_abs * mult / 2^shift <= 127 且 mult 尽量大
    # 先枚举适当范围的 shift，选出最大的 mult
    best_mult = 1
    best_shift = 0
    max_shift = 31  # int32 足够
    for s in range(max_shift + 1):
        # mult <= 127 * 2^s / max_abs
        num = 127 * (1 << s)
        mult = num // max_abs  # floor
        if mult < 1:
            continue
        # 记录 mult 最大的组合
        if mult > best_mult:
            best_mult = mult
            best_shift = s

    return int(best_mult), int(best_shift)

def compute_requant_params_per_channel(acc: np.ndarray, axis=1):
    """
    Per-channel 量化参数计算，返回 mults 和 shifts 数组。
    """
    if axis == 1:  # per-channel on M
        mults = np.zeros(acc.shape[1], dtype=np.int32)
        shifts = np.zeros(acc.shape[1], dtype=np.int32)
        for j in range(acc.shape[1]):
            mult, shift = compute_requant_params(acc[:, j])
            mults[j] = mult
            shifts[j] = shift
        return mults, shifts
    else:
        raise ValueError("Unsupported axis")

def requantize_array(acc: np.ndarray, mults, shifts) -> np.ndarray:
    """
    使用 CMSIS-NN 公式对整个 acc 数组做 requant：
      output = (acc * mult + (1 << (shift-1))) / 2^shift
    支持 mults 和 shifts 为标量或数组（广播）。
    """
    acc_int64 = acc.astype(np.int64)
    mults = np.broadcast_to(mults, acc.shape).astype(np.int64)
    shifts = np.broadcast_to(shifts, acc.shape).astype(np.int32)
    prod = acc_int64 * mults
    mask = shifts > 0
    if np.any(mask):
        prod[mask] += (1 << (shifts[mask] - 1))
        prod[mask] >>= shifts[mask]
    prod = np.clip(prod, -128, 127)
    return prod.astype(np.int8)

def generate_test_case(
    K=None,
    N=None,
    M=None,
    lhs_dtype=None,
    fix_mode=False,
    quant_mode=None,
    out_dir="./test_case",
):
    # 随机生成矩阵尺寸 (128~256)
    if K is None:
        K = random.randint(16, 256)
    if N is None:
        N = random.randint(16, 256)
    if M is None:
        M = random.randint(16, 256)

    # 随机选择 lhs 数据类型
    if lhs_dtype is None:
        lhs_dtype = random.choice([1, 2])  # 1: S8, 2: S16

    # 生成模式：False=随机，True=fix模式
    # fix_mode 参数直接使用

    # 随机选择量化模式
    if quant_mode is None:
        quant_mode = random.choice([0, 1])  # 0: per-tensor, 1: per-channel

    # 随机生成 lhs (A)、rhs (B) 的 int8/int16 内容
    if not fix_mode:
        if lhs_dtype == 1:  # S8
            lhs = np.random.randint(-128, 128, size=(K, N), dtype=np.int8)
        else:  # S16
            lhs = np.random.randint(-32768, 32768, size=(K, N), dtype=np.int16)
        rhs = np.random.randint(-128, 128, size=(N, M), dtype=np.int8)
    else:
        # fix模式：
        # - 16bit：高8位为行号，低8位为列号（对16bit取模）
        # - 8bit：按行展平后的序号（对8bit取模）
        if lhs_dtype == 2:  # S16
            r = np.arange(K, dtype=np.uint16)[:, None]
            c = np.arange(N, dtype=np.uint16)[None, :]
            lhs_u16 = ((r << 8) | c) & 0xFFFF
            lhs = lhs_u16.view(np.int16)
        else:  # S8
            lhs_u8 = (np.arange(K * N, dtype=np.uint16) & 0xFF).astype(np.uint8).reshape(K, N)
            lhs = lhs_u8.view(np.int8)

        rhs_u8 = (np.arange(N * M, dtype=np.uint16) & 0xFF).astype(np.uint8).reshape(N, M)
        rhs = rhs_u8.view(np.int8)

    # 随机生成 bias (int32)
    bias = np.random.randint(-10000, 10000, size=M, dtype=np.int32)
    # bias 随机或为 0，这里先简单设为 0
    # bias = np.zeros(M, dtype=np.int32)

    # 计算累加结果 (int32)
    sum_result = np.dot(lhs.astype(np.int32), rhs.astype(np.int32))  # [K, M]
    result = sum_result + bias  # broadcasting

    # 随机选择量化模式
    quant_mode = random.choice([0, 1])  # 0: per-tensor, 1: per-channel


    # 根据结果范围计算 dst_mult / dst_shift
    if quant_mode == 0:  # per-tensor
        dst_mult, dst_shift = compute_requant_params(result)
        dst_mults = dst_mult
        dst_shifts = dst_shift
    else:  # per-channel
        dst_mults, dst_shifts = compute_requant_params_per_channel(result, axis=1)

    # 使用同样公式生成预期输出
    quantized = requantize_array(result, dst_mults, dst_shifts)

    # 输出目录：./test_case
    os.makedirs(out_dir, exist_ok=True)
    data_mem_path = os.path.join(out_dir, "data.mem")
    expected_mem_path = os.path.join(out_dir, "expected.mem")
    config_path = os.path.join(out_dir, "config.txt")
    debug_path = os.path.join(out_dir, "debug_output.txt")

    # 保存数组原始内容到txt文件
    np.savetxt(os.path.join(out_dir, "lhs.txt"), lhs, fmt='%d')
    np.savetxt(os.path.join(out_dir, "rhs.txt"), rhs, fmt='%d')
    np.savetxt(os.path.join(out_dir, "bias.txt"), bias, fmt='%d')
    np.savetxt(os.path.join(out_dir, "expected_dst.txt"), quantized, fmt='%d')
    if quant_mode == 1:
        np.savetxt(os.path.join(out_dir, "dst_mult.txt"), dst_mults, fmt='%d')
        np.savetxt(os.path.join(out_dir, "dst_shift.txt"), dst_shifts, fmt='%d')
        
    # 生成调试文件：未经量化的累加结果 (int32)
    with open(debug_path, 'w') as f:
        f.write(f"未经量化的矩阵乘法中间结果 (K={K}, N={N}, M={M})\n")
        f.write("格式: int32 矩阵，每行对应输出的一行\n\n")
        for i in range(K):
            row_str = ' '.join(f'{result[i, j]:8d}' for j in range(M))
            f.write(f"行 {i}: {row_str}\n")
        f.write(f"\n量化模式: {'per-tensor' if quant_mode == 0 else 'per-channel'}\n")
        if quant_mode == 0:
            f.write(f"量化参数: dst_mult={dst_mult}, dst_shift={dst_shift}\n")
        else:
            f.write("量化参数 (per-channel):\n")
            for j in range(M):
                f.write(f"  通道 {j}: dst_mult={dst_mults[j]}, dst_shift={dst_shifts[j]}\n")

    # 辅助函数：将字节数组打包为32位小端字，写入mem文件
    def write_mem(file, data_bytes):
        for i in range(0, len(data_bytes), 4):
            chunk = data_bytes[i:i+4]
            if len(chunk) < 4:
                chunk += b'\x00' * (4 - len(chunk))  # 填充0
            word = struct.unpack('<I', chunk)[0]  # 小端32位
            file.write(f"{word:08x}\n")

    # 准备数据mem：lhs, rhs, bias, quant params
    with open(data_mem_path, 'w') as f:
        # LHS
        lhs_bytes = lhs.tobytes()
        write_mem(f, lhs_bytes)
        lhs_addr = 0
        lhs_size = len(lhs_bytes)
        
        # RHS (列优先)
        rhs_bytes = rhs.flatten(order='F').tobytes()
        write_mem(f, rhs_bytes)
        rhs_addr = lhs_size
        rhs_size = len(rhs_bytes)
        
        # Bias
        bias_bytes = bias.tobytes()
        write_mem(f, bias_bytes)
        bias_addr = rhs_addr + rhs_size
        bias_size = len(bias_bytes)
        
        # Quant params (if per-channel)
        if quant_mode == 1:
            mult_bytes = dst_mults.tobytes()
            write_mem(f, mult_bytes)
            mult_addr = bias_addr + bias_size
            mult_size = len(mult_bytes)
            
            shift_bytes = dst_shifts.tobytes()
            write_mem(f, shift_bytes)
            shift_addr = mult_addr + mult_size
            shift_size = len(shift_bytes)
        else:
            mult_addr = shift_addr = 0
            mult_size = shift_size = 0

    # 准备expected mem：expected_dst_data
    with open(expected_mem_path, 'w') as f:
        expected_bytes = quantized.tobytes()
        write_mem(f, expected_bytes)
        expected_addr = 0
        expected_size = len(expected_bytes)

    # 复制 data.mem 到 ../veri/memInfo/main_extram.mem
    dest_dir = "./"#os.path.join(os.path.dirname(out_dir), "veri", "memInfo")
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.join(dest_dir, "main_extram.mem")
    shutil.copy2(data_mem_path, dest_path)

    # 生成配置文件
    with open(config_path, 'w') as f:
        f.write("# Human-readable config file\n")
        f.write(f"K = {K}\n")
        f.write(f"N = {N}\n")
        f.write(f"M = {M}\n")
        f.write(f"lhs_dtype = {lhs_dtype}  # 1: S8, 2: S16\n")
        f.write(f"quant_mode = {quant_mode}  # 0: per-tensor, 1: per-channel\n")
        f.write("\n# Addresses in data.mem (bytes)\n")
        f.write(f"lhs_addr = {lhs_addr}\n")
        f.write(f"rhs_addr = {rhs_addr}\n")
        f.write(f"bias_addr = {bias_addr}\n")
        if quant_mode == 1:
            f.write(f"dst_mult_addr = {mult_addr}\n")
            f.write(f"dst_shift_addr = {shift_addr}\n")
        f.write("\n# Sizes (bytes)\n")
        f.write(f"lhs_size = {lhs_size}\n")
        f.write(f"rhs_size = {rhs_size}\n")
        f.write(f"bias_size = {bias_size}\n")
        f.write(f"expected_dst_size = {expected_size}\n")
        if quant_mode == 1:
            f.write(f"dst_mult_size = {mult_size}\n")
            f.write(f"dst_shift_size = {shift_size}\n")
        f.write("\n# Config struct fields\n")
        f.write(f"K = {K}\n")
        f.write(f"N = {N}\n")
        f.write(f"M = {M}\n")
        lhs_row_stride = N * (1 if lhs_dtype == 1 else 2)
        rhs_row_stride = N * 1
        dst_row_stride = M * 1
        f.write(f"lhs_row_stride = {lhs_row_stride}\n")
        f.write(f"rhs_row_stride = {rhs_row_stride}\n")
        f.write(f"dst_row_stride = {dst_row_stride}\n")
        lhs_dtype_macro = 'DSA_DTYPE_S8' if lhs_dtype == 1 else 'DSA_DTYPE_S16'
        f.write(f"lhs_dtype = {lhs_dtype_macro}\n")
        f.write("rhs_dtype = DSA_DTYPE_S8\n")
        f.write("bias_dtype = DSA_DTYPE_S32\n")
        f.write("out_dtype = DSA_DTYPE_S8\n")
        f.write(f"quant_mode = {quant_mode}\n")
        f.write("lhs_offset = 0\n")
        f.write("rhs_offset = 0\n")
        f.write("dst_offset = 0\n")
        if quant_mode == 0:
            f.write(f"dst_mult = {dst_mult}\n")
            f.write(f"dst_shift = {dst_shift}\n")
        else:
            f.write("dst_mult = 0\n")
            f.write("dst_shift = 0\n")
        f.write("act_min = -128\n")
        f.write("act_max = 127\n")

    return {
        "K": K,
        "N": N,
        "M": M,
        "lhs_dtype": lhs_dtype,
        "fix_mode": fix_mode,
        "quant_mode": quant_mode,
        "out_dir": out_dir,
    }

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--K", type=int, default=None)
    parser.add_argument("--N", type=int, default=None)
    parser.add_argument("--M", type=int, default=None)
    parser.add_argument("--lhs_dtype", type=int, choices=[1, 2], default=None)
    parser.add_argument("--fix_mode", action="store_true")
    parser.add_argument("--quant_mode", type=int, choices=[0, 1], default=None)
    parser.add_argument("--out_dir", type=str, default="./test_case")
    args = parser.parse_args()

    generate_test_case(
        K=args.K,
        N=args.N,
        M=args.M,
        lhs_dtype=args.lhs_dtype,
        fix_mode=args.fix_mode,
        quant_mode=args.quant_mode,
        out_dir=args.out_dir,
    )