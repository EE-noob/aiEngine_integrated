import numpy as np
import os
import random
import struct
import shutil
#python ./generate_test_case_complex_mem.py --K 64 --N 32 --M 128 --lhs_dtype 1 --quant_mode 0 --out_dir ./test_case0
def compute_requant_params(acc: np.ndarray):
    """
    根据累加结果范围，生成 dst_mult 和 dst_shift，使得
    量化后的输出在 int8 范围内有良好的分布。
    
    CMSIS-NN 使用的公式：
    result = (acc << left_shift) * mult 的高32位 (doubling) >> right_shift
    其中 mult 在 [0x40000000, 0x7FFFFFFF] 范围内（即 0.5 到 1.0 的定点数）
    """
    acc_min = float(acc.min())
    acc_max = float(acc.max())
    
    if acc_min == 0 and acc_max == 0:
        return 1073741824, 0  # 0x40000000, shift=0 (恒等映射)
    
    # 确定输出范围：使用 [-127, 127] 以避免饱和
    out_min = -127.0
    out_max = 127.0
    
    # 计算缩放因子：将 [acc_min, acc_max] 映射到 [out_min, out_max]
    # 考虑对称性，使用最大绝对值
    acc_abs_max = max(abs(acc_min), abs(acc_max))
    
    # 目标缩放比例
    scale = 127.0 / acc_abs_max
    
    # CMSIS-NN doubling_high_mult 的特性：
    # - mult 在 [0x40000000, 0x7FFFFFFF] 范围（对应 [0.5, 1.0)）
    # - 结果会 doubling（相当于乘以2）
    # - 所以实际缩放是 2 * mult / 2^31 * 2^left_shift / 2^right_shift
    
    # 简化：scale = mult / 2^30 * 2^left_shift / 2^right_shift
    # 即：scale = mult * 2^(left_shift - right_shift - 30)
    
    # 寻找最佳的 shift 和 mult
    best_mult = 1073741824  # 0x40000000
    best_shift = 0
    best_error = float('inf')
    
    # shift > 0 表示左移，shift < 0 表示右移
    for shift in range(-31, 32):
        # mult = scale * 2^(30 - shift)
        mult_float = scale * (2 ** (30 - shift))
        
        # mult 必须在 [0x40000000, 0x7FFFFFFF] 范围内
        mult = int(round(mult_float))
        if mult < 0x40000000 or mult > 0x7FFFFFFF:
            continue
        
        # 计算实际的缩放比例
        actual_scale = mult / (2 ** (30 - shift))
        error = abs(actual_scale - scale)
        
        if error < best_error:
            best_error = error
            best_mult = mult
            best_shift = shift
    
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

def riscv_nn_requantize(acc, mult, shift):
    """
    精确模拟 CMSIS-NN 的 riscv_nn_requantize 函数
    
    C 实现：
    __STATIC_FORCEINLINE int32_t riscv_nn_requantize(const int32_t val, const int32_t multiplier, const int32_t shift) {
        return riscv_nn_divide_by_power_of_two(
            riscv_nn_doubling_high_mult_no_sat(val * (1 << LEFT_SHIFT(shift)), multiplier),
            RIGHT_SHIFT(shift));
    }
    
    __STATIC_FORCEINLINE int32_t riscv_nn_doubling_high_mult_no_sat(const int32_t m1, const int32_t m2) {
        int64_t mult = (1LL << 30) + (int64_t)m1 * m2;
        return (int32_t)(mult >> 31);
    }
    """
    # 转换为 Python int（无限精度）
    acc = int(acc)
    mult = int(mult)
    shift = int(shift)
    
    # LEFT_SHIFT 和 RIGHT_SHIFT 宏
    left_shift = shift if shift > 0 else 0
    right_shift = 0 if shift > 0 else -shift
    
    # 步骤 1: 应用左移
    val = acc * (1 << left_shift)
    
    # 步骤 2: riscv_nn_doubling_high_mult_no_sat
    # 64 位乘法 + rounding offset
    prod = (1 << 30) + val * mult
    # 右移 31 位（相当于除以 2^31，这是 doubling high mult 的关键）
    result = prod >> 31
    
    # 步骤 3: riscv_nn_divide_by_power_of_two (应用右移)
    # 注意：这里需要带 rounding 的右移
    if right_shift > 0:
        # 带 rounding 的右移：加上 (1 << (right_shift - 1)) 再右移
        mask = (1 << right_shift) - 1
        remainder = result & mask
        result = result >> right_shift
        # 如果余数 >= 一半，则向上舍入（考虑符号）
        if remainder > (1 << (right_shift - 1)):
            result += 1
        elif remainder == (1 << (right_shift - 1)):
            # 正好一半时，根据符号决定舍入方向
            # 标准的 round-to-nearest-even，但 CMSIS-NN 使用 round-half-up
            if result >= 0:
                result += 1
    
    # 限制在 int32 范围内
    if result > 2147483647:
        result = 2147483647
    elif result < -2147483648:
        result = -2147483648
    
    return int(result)

def requantize_array(acc: np.ndarray, mults, shifts) -> np.ndarray:
    """
    使用 CMSIS-NN 兼容的量化函数对整个 acc 数组做 requant。
    支持 mults 和 shifts 为标量或数组（广播）。
    """
    output = np.zeros_like(acc, dtype=np.int8)
    
    # 转换为数组以支持广播
    mults_array = np.broadcast_to(mults, acc.shape)
    shifts_array = np.broadcast_to(shifts, acc.shape)
    
    # 逐元素应用量化
    for idx in np.ndindex(acc.shape):
        quantized_val = riscv_nn_requantize(acc[idx], mults_array[idx], shifts_array[idx])
        output[idx] = np.clip(quantized_val, -128, 127)
    
    return output

def generate_test_case(
    K=None,
    N=None,
    M=None,
    lhs_dtype=None,
    fix_mode=False,
    quant_mode=None,
    seed=None,
    out_dir="./test_case",
):
    if seed is not None:
        random.seed(seed)
        np.random.seed(seed)

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
    # quant_mode 在前面已确定（随机或由参数指定），此处不再覆盖。


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
    expected_dst_mem_path = os.path.join(out_dir, "expected_dst.mem")
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
        #BF 
        # LHS
        lhs_bytes = lhs.tobytes()
        #lhs_addr = 0
        
        fill0_bytes = 16
        lhs_addr =2*fill0_bytes # 预留32字节的 config struct + 4字节的填充0
        write_mem(f, b'\x00' *31)

        write_mem(f, lhs_bytes)
        lhs_size = len(lhs_bytes)
        
        # RHS (列优先)
        rhs_bytes = rhs.flatten(order='F').tobytes()
        write_mem(f, rhs_bytes)
        #rhs_addr = lhs_size
        rhs_addr = lhs_size+lhs_addr
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

        # Output matrix base in data.mem address space (bytes).
        # The DUT writes output to this region, so place it after all input/config blobs.
        output_base_addr = bias_addr + bias_size + mult_size + shift_size
        output_size = K * M

    # 准备expected mem：expected_dst_data
    with open(expected_mem_path, 'w') as f:
        expected_bytes = quantized.tobytes()
        write_mem(f, expected_bytes)
        expected_addr = 0
        expected_size = len(expected_bytes)

    # 另存一份 expected_dst.mem，便于直接查看输出矩阵对应的 memory image。
    with open(expected_dst_mem_path, 'w') as f:
        write_mem(f, quantized.tobytes())

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
        f.write(f"output_base_addr = {output_base_addr}\n")
        f.write("\n# Sizes (bytes)\n")
        f.write(f"lhs_size = {lhs_size}\n")
        f.write(f"rhs_size = {rhs_size}\n")
        f.write(f"bias_size = {bias_size}\n")
        f.write(f"output_size = {output_size}\n")
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
        "seed": seed,
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
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--out_dir", type=str, default="./test_case")
    args = parser.parse_args()

    generate_test_case(
        K=args.K,
        N=args.N,
        M=args.M,
        lhs_dtype=args.lhs_dtype,
        fix_mode=args.fix_mode,
        quant_mode=args.quant_mode,
        seed=args.seed,
        out_dir=args.out_dir,
    )
