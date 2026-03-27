import numpy as np
import os
import random

# 随机生成矩阵尺寸 (128~256)
# K = random.randint(16, 256)
# N = random.randint(16, 256)
# M = random.randint(16, 256)

# # 随机选择 lhs 数据类型
# lhs_dtype = random.choice([1, 2])  # 1: S8, 2: S16

K = 28  
N = 146 
M = 62  # output_ch，通道数，RHS的列数

# 随机选择 lhs 数据类型
lhs_dtype = 2

# 随机生成 lhs (A)、rhs (B) 的 int8/int16 内容
if lhs_dtype == 1:  # S8
    lhs = np.random.randint(-128, 128, size=(K, N), dtype=np.int8)
else:  # S16
    lhs = np.random.randint(-32768, 32768, size=(K, N), dtype=np.int16)
rhs = np.random.randint(-128, 128, size=(N, M), dtype=np.int8)

# 随机生成 bias (int32)
bias = np.random.randint(-10000, 10000, size=M, dtype=np.int32)

# 计算累加结果 (int32)
sum_result = np.dot(lhs.astype(np.int32), rhs.astype(np.int32))  # [K, M]
result = sum_result + bias  # broadcasting

# 随机选择量化模式
quant_mode = random.choice([0, 1])  # 0: per-tensor, 1: per-channel

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

# 根据结果范围计算 dst_mult / dst_shift
if quant_mode == 0:  # per-tensor
    dst_mult, dst_shift = compute_requant_params(result)
    dst_mults = dst_mult
    dst_shifts = dst_shift
else:  # per-channel
    dst_mults, dst_shifts = compute_requant_params_per_channel(result, axis=1)

# 使用同样公式生成预期输出
quantized = requantize_array(result, dst_mults, dst_shifts)

# 输出目录：./eai_csrc_api
out_dir = "/home/etc/FPGA/e203_simulator/eai_csrc_api"
os.makedirs(out_dir, exist_ok=True)
c_path = os.path.join(out_dir, "test_case.c")
h_path = os.path.join(out_dir, "test_case.h")
debug_path = os.path.join(out_dir, "debug_output.txt")

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

# 生成C文件
with open(c_path, 'w') as f:
    f.write('#include "test_case.h"\n\n')
    # LHS
    lhs_type_str = 'int8_t' if lhs_dtype == 1 else 'int16_t'
    f.write(f'// LHS data (K x N, {lhs_type_str})\n')
    f.write(f'{lhs_type_str} lhs_data[{K * N}] = {{\n')
    for i in range(K * N):
        f.write(f'  {int(lhs.flatten()[i])}')
        if i < K * N - 1:
            f.write(',')
        if (i + 1) % N == 0:
            f.write('\n')
        else:
            f.write(' ')
    f.write('};\n\n')

    # RHS
    f.write('// RHS data (N x M, column-major)\n')
    f.write('int8_t rhs_data[{}] = {{\n'.format(N * M))
    rhs_flat = rhs.flatten(order='F')  # 列展平
    for i in range(N * M):
        f.write(f'  {int(rhs_flat[i])}')
        if i < N * M - 1:
            f.write(',')
        if (i + 1) % N == 0:  # 每列 N 个元素后换行（列优先）
            f.write('\n')
        else:
            f.write(' ')
    f.write('};\n\n')

    # Bias
    f.write('// Bias data (length M)\n')
    f.write('int32_t bias_data[{}] = {{\n'.format(M))
    for i in range(M):
        f.write(f'  {int(bias[i])}')
        if i < M - 1:
            f.write(',')
        f.write('\n' if (i + 1) % M == 0 else ' ')
    f.write('};\n\n')

    # Expected DST
    f.write('// Expected DST data (K x M)\n')
    f.write('int8_t expected_dst_data[{}] = {{\n'.format(K * M))
    for i in range(K * M):
        f.write(f'  {int(quantized.flatten()[i])}')
        if i < K * M - 1:
            f.write(',')
        if (i + 1) % M == 0:
            f.write('\n')
        else:
            f.write(' ')
    f.write('};\n\n')

    # 输出缓冲区（由 Python 固定大小生成）
    f.write('// DST buffer (K x M), used as output buffer\n')
    f.write('int8_t dst_data[{}];\n\n'.format(K * M))

    # DST mult/shift data (per-channel)
    if quant_mode == 1:
        f.write('// DST mult data (length M, per-channel)\n')
        f.write('int32_t dst_mult_data[{}] = {{\n'.format(M))
        for i in range(M):
            f.write(f'  {int(dst_mults[i])}')
            if i < M - 1:
                f.write(',')
            f.write('\n')
        f.write('};\n\n')

        f.write('// DST shift data (length M, per-channel)\n')
        f.write('int32_t dst_shift_data[{}] = {{\n'.format(M))
        for i in range(M):
            f.write(f'  {int(dst_shifts[i])}')
            if i < M - 1:
                f.write(',')
            f.write('\n')
        f.write('};\n\n')

    # Config
    f.write('// Auto-generated matmul config\n')
    f.write('dsa_matmul_config_t test_config = {\n')
    f.write('  .lhs_ptr = lhs_data,\n')
    f.write('  .rhs_ptr = rhs_data,\n')
    f.write('  .dst_ptr = dst_data,\n')
    f.write('  .bias_ptr = bias_data,\n')
    f.write('  .K = %d,\n' % K)
    f.write('  .N = %d,\n' % N)
    f.write('  .M = %d,\n' % M)
    # 计算步进（字节）
    lhs_row_stride = N * (1 if lhs_dtype == 1 else 2)
    rhs_row_stride = N * 1  # rhs是int8_t
    dst_row_stride = M * 1  # dst是int8_t
    f.write('  .lhs_row_stride = %d,\n' % lhs_row_stride)
    f.write('  .rhs_row_stride = %d,\n' % rhs_row_stride)
    f.write('  .dst_row_stride = %d,\n' % dst_row_stride)
    # 数据类型
    lhs_dtype_macro = 'DSA_DTYPE_S8' if lhs_dtype == 1 else 'DSA_DTYPE_S16'
    f.write('  .lhs_dtype = %s,\n' % lhs_dtype_macro)
    f.write('  .rhs_dtype = DSA_DTYPE_S8,\n')
    f.write('  .bias_dtype = DSA_DTYPE_S32,\n')
    f.write('  .out_dtype = DSA_DTYPE_S8,\n')
    # 量化模式与零点
    f.write('  .quant_mode = %d,\n' % quant_mode)
    f.write('  .lhs_offset = 0,\n')
    f.write('  .rhs_offset = 0,\n')
    f.write('  .dst_offset = 0,\n')
    # per-tensor 量化
    if quant_mode == 0:
        f.write('  .dst_mult = %d,\n' % dst_mult)
        f.write('  .dst_shift = %d,\n' % dst_shift)
        f.write('  .dst_mult_ptr = NULL,\n')
        f.write('  .dst_shift_ptr = NULL,\n')
    else:
        f.write('  .dst_mult = 0,\n')
        f.write('  .dst_shift = 0,\n')
        f.write('  .dst_mult_ptr = dst_mult_data,\n')
        f.write('  .dst_shift_ptr = dst_shift_data,\n')
    # 激活范围
    f.write('  .act_min = -128,\n')
    f.write('  .act_max = 127,\n')
    f.write('};\n')

# 生成头文件
with open(h_path, 'w') as f:
    f.write('#ifndef TEST_CASE_H\n')
    f.write('#define TEST_CASE_H\n\n')
    f.write('#include <stdint.h>\n')
    f.write('#include "dsa_accel.h"\n\n')
    lhs_type_str = 'int8_t' if lhs_dtype == 1 else 'int16_t'
    f.write(f'extern {lhs_type_str} lhs_data[{K * N}];\n')
    f.write('extern int8_t rhs_data[%d];\n' % (N * M))
    f.write('extern int32_t bias_data[%d];\n' % M)
    f.write('extern int8_t expected_dst_data[%d];\n' % (K * M))
    f.write('extern int8_t dst_data[%d];\n' % (K * M))
    if quant_mode == 1:
        f.write('extern int32_t dst_mult_data[%d];\n' % M)
        f.write('extern int32_t dst_shift_data[%d];\n' % M)
    f.write('extern dsa_matmul_config_t test_config;\n\n')
    f.write('#endif // TEST_CASE_H\n')
