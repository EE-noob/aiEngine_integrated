import numpy as np
import os
import random

# 随机生成矩阵尺寸 (128~256)
# K = random.randint(16, 256)
# N = random.randint(16, 256)
# M = random.randint(16, 256)

# # 随机选择 lhs 数据类型
# lhs_dtype = random.choice([1, 2])  # 1: S8, 2: S16

# 根据 riscv_nn_mat_mult_kernel_s8_s16 函数定义：
# - 通道定义：M 个通道，对应 RHS 的列数
# - input_a (RHS): int8, 形状 (N, M)，按列展平存储，output_ch 参数 = M
# - input_b (LHS): int16, 形状 (K, N) = (2, N)，按行展平存储
# - output: (K, M) = (2, M)
# - bias, mult, shift: 长度为 M (每个通道一个)

K = 28  # input_b的行数，固定为2
N = 146  # num_col_a，内积长度
M = 62  # output_ch，通道数，RHS的列数

# 随机选择 input_b (LHS) 的数据类型
lhs_dtype = 2  # S16

# 随机生成数据：
# - input_a (RHS): int8, (N, M)，按列展平存储
# - input_b (LHS): int16, (K, N) = (2, N)，按行展平存储
input_a = np.random.randint(-128, 128, size=(N, M), dtype=np.int8)
if lhs_dtype == 1:  # S8
    input_b = np.random.randint(-128, 128, size=(K, N), dtype=np.int8)
else:  # S16
    input_b = np.random.randint(-32768, 32768, size=(K, N), dtype=np.int16)

# 随机生成 bias (int32) - 长度是 M (每个通道一个)
bias = np.random.randint(-10000, 10000, size=M, dtype=np.int32)

# 计算累加结果 (int32): input_b @ input_a = (K, N) @ (N, M) = (K, M)
sum_result = np.dot(input_b.astype(np.int32), input_a.astype(np.int32))  # [K, M]
result = sum_result + bias.reshape(1, -1)  # broadcasting: bias是行向量

# 随机选择量化模式
quant_mode = 1  # 强制per-channel

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
    axis=0: per row (K)
    axis=1: per column (M channels)
    """
    if axis == 0:  # per row (K)
        mults = np.zeros(acc.shape[0], dtype=np.int32)
        shifts = np.zeros(acc.shape[0], dtype=np.int32)
        for i in range(acc.shape[0]):
            mult, shift = compute_requant_params(acc[i, :])
            mults[i] = mult
            shifts[i] = shift
        return mults, shifts
    elif axis == 1:  # per-channel on M (每列一个channel)
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

# 根据结果范围计算 dst_mult / dst_shift (per-channel, 每个通道一个参数，按M维度，即列)
dst_mults, dst_shifts = compute_requant_params_per_channel(result, axis=1)

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

def simulate_riscv_nn_mat_mult_kernel_s8_s16(input_a, input_b, output_ch, out_shift, out_mult, out_offset, activation_min, activation_max, num_col_a, aligned_num_col_a, num_row_b, bias):
    """
    模拟 riscv_nn_mat_mult_kernel_s8_s16 函数行为：
    - input_a: RHS, int8, (N, M)，按列展平存储
    - input_b: LHS, int16, (K, N)，按行展平存储
    - output_ch: M (通道数)
    - num_col_a: N (内积长度)
    - num_row_b: K (LHS的行数)
    - output: (K, M)，out_0存前M个，out_1存后M个，...
    """
    out_mult = np.asarray(out_mult)
    out_shift = np.asarray(out_shift)
    
    M = output_ch
    N = num_col_a
    K = num_row_b
    
    # input_a 是按列展平的，重塑为 (N, M)
    if len(input_a.shape) == 1:
        input_a_matrix = input_a.reshape((N, M), order='F')  # column-major
    else:
        input_a_matrix = input_a
    
    # input_b 是按行展平的 (K, N)
    if len(input_b.shape) == 1:
        input_b_matrix = input_b.reshape((K, N), order='C')  # row-major
    else:
        input_b_matrix = input_b
    
    out = np.zeros(M * K, dtype=np.int8)
    
    # 模拟C代码的输出布局：out_0[M], out_1[M], ..., out_{K-1}[M]
    # 循环处理每对通道（每次2个通道）
    mult_idx = 0
    bias_idx = 0
    row_count = M // 2
    
    # 为每个 LHS 行创建输出索引
    out_indices = [i * M for i in range(K)]
    
    # 每次处理2个通道
    for _ in range(row_count):
        # 初始化累加器：K行 x 2列（两个通道）
        accumulators = []
        for k_idx in range(K):
            ch_0_out = bias[bias_idx] if bias is not None else 0
            ch_1_out = bias[bias_idx + 1] if bias is not None else 0
            accumulators.append([ch_0_out, ch_1_out])
        
        # 内积计算
        for n in range(N):
            a0 = input_a_matrix[n, mult_idx]  # 第mult_idx通道
            a1 = input_a_matrix[n, mult_idx + 1]  # 第mult_idx+1通道
            
            for k_idx in range(K):
                b = input_b_matrix[k_idx, n]  # LHS第k_idx行
                accumulators[k_idx][0] += np.int32(a0) * np.int32(b)
                accumulators[k_idx][1] += np.int32(a1) * np.int32(b)
        
        # 量化并写入输出
        for k_idx in range(K):
            ch_0_out = riscv_nn_requantize(accumulators[k_idx][0], out_mult[mult_idx], out_shift[mult_idx])
            ch_0_out = np.clip(ch_0_out + out_offset, activation_min, activation_max)
            out[out_indices[k_idx]] = ch_0_out
            out_indices[k_idx] += 1
            
            ch_1_out = riscv_nn_requantize(accumulators[k_idx][1], out_mult[mult_idx + 1], out_shift[mult_idx + 1])
            ch_1_out = np.clip(ch_1_out + out_offset, activation_min, activation_max)
            out[out_indices[k_idx]] = ch_1_out
            out_indices[k_idx] += 1
        
        bias_idx += 2
        mult_idx += 2
    
    # 处理奇数通道
    if M & 0x1:
        accumulators = []
        for k_idx in range(K):
            ch_0_out = bias[bias_idx] if bias is not None else 0
            accumulators.append(ch_0_out)
        
        for n in range(N):
            a0 = input_a_matrix[n, mult_idx]
            
            for k_idx in range(K):
                b = input_b_matrix[k_idx, n]
                accumulators[k_idx] += np.int32(a0) * np.int32(b)
        
        for k_idx in range(K):
            ch_0_out = riscv_nn_requantize(accumulators[k_idx], out_mult[mult_idx], out_shift[mult_idx])
            ch_0_out = np.clip(ch_0_out + out_offset, activation_min, activation_max)
            out[out_indices[k_idx]] = ch_0_out
            out_indices[k_idx] += 1
    
    return out

# 使用同样公式生成预期输出
# input_a: RHS (N, M) int8, 按列展平
# input_b: LHS (K, N) int16, 按行展平
quantized = simulate_riscv_nn_mat_mult_kernel_s8_s16(input_a, input_b, M, dst_shifts, dst_mults, 0, -128, 127, N, N, K, bias)

# 输出目录：./eai_csrc
out_dir = "/home/etc/FPGA/e203_simulator/eai_csrc"
os.makedirs(out_dir, exist_ok=True)
c_path = os.path.join(out_dir, "test_case.c")
h_path = os.path.join(out_dir, "test_case.h")
debug_path = os.path.join(out_dir, "debug_output.txt")

# 生成调试文件：未经量化的累加结果 (int32)
with open(debug_path, 'w') as f:
    f.write(f"未经量化的矩阵乘法中间结果 (K={K}, M={M}, N={N})\n")
    f.write("格式: int32 矩阵，每行对应输出的一行\n")
    f.write("input_a (RHS): (N={}, M={}), input_b (LHS): (K={}, N={})\n".format(N, M, K, N))
    f.write("output: (K={}, M={})\n\n".format(K, M))
    for i in range(K):
        row_str = ' '.join(f'{result[i, j]:8d}' for j in range(M))
        f.write(f"行 {i}: {row_str}\n")
    f.write(f"\n量化模式: per-channel\n")
    f.write("量化参数 (per-channel, 按M维度，即通道维度):\n")
    for j in range(M):
        f.write(f"  通道 {j}: dst_mult={dst_mults[j]}, dst_shift={dst_shifts[j]}\n")

# 生成C文件
with open(c_path, 'w') as f:
    f.write('#include "test_case.h"\n\n')
    # input_b (LHS): (K, N) = (2, N)，按行展平存储
    lhs_type_str = 'int8_t' if lhs_dtype == 1 else 'int16_t'
    f.write(f'// input_b (LHS) data: (K={K}, N={N}), row-major, {lhs_type_str}\n')
    f.write(f'{lhs_type_str} input_b_data[{K * N}] = {{\n')
    input_b_flat = input_b.flatten(order='C')  # 行展平
    for i in range(K * N):
        f.write(f'  {int(input_b_flat[i])}')
        if i < K * N - 1:
            f.write(',')
        if (i + 1) % N == 0:
            f.write('\n')
        else:
            f.write(' ')
    f.write('};\n\n')

    # input_a (RHS): (N, M)，按列展平存储
    f.write(f'// input_a (RHS) data: (N={N}, M={M}), column-major, int8_t\n')
    f.write('int8_t input_a_data[{}] = {{\n'.format(N * M))
    input_a_flat = input_a.flatten(order='F')  # 列展平
    for i in range(N * M):
        f.write(f'  {int(input_a_flat[i])}')
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

    # Expected output
    f.write('// Expected output data: (K={}, M={}), layout: out_0[M] then out_1[M]\n'.format(K, M))
    f.write('int8_t expected_output_data[{}] = {{\n'.format(K * M))
    for i in range(K * M):
        f.write(f'  {int(quantized[i])}')
        if i < K * M - 1:
            f.write(',')
        if (i + 1) % M == 0:
            f.write('\n')
        else:
            f.write(' ')
    f.write('};\n\n')

    # 输出缓冲区
    f.write('// Output buffer: (K={}, M={})\n'.format(K, M))
    f.write('int8_t output_data[{}];\n\n'.format(K * M))

    # Quantization mult/shift data (per-channel, 按M维度)
    if quant_mode == 1:
        f.write('// Quantization mult data (length M, per-channel)\n')
        f.write('int32_t out_mult_data[{}] = {{\n'.format(M))
        for i in range(M):
            f.write(f'  {int(dst_mults[i])}')
            if i < M - 1:
                f.write(',')
            f.write('\n')
        f.write('};\n\n')

        f.write('// Quantization shift data (length M, per-channel)\n')
        f.write('int32_t out_shift_data[{}] = {{\n'.format(M))
        for i in range(M):
            f.write(f'  {int(dst_shifts[i])}')
            if i < M - 1:
                f.write(',')
            f.write('\n')
        f.write('};\n\n')

    # Test parameters
    f.write('// Test parameters\n')
    f.write('const uint16_t output_ch = %d;  // M\n' % M)
    f.write('const int32_t num_col_a = %d;  // N\n' % N)
    f.write('const int32_t aligned_num_col_a = %d;  // N (aligned)\n' % N)
    f.write('const int32_t out_offset = 0;\n')
    f.write('const int16_t activation_min = -128;\n')
    f.write('const int16_t activation_max = 127;\n')

# 生成头文件
with open(h_path, 'w') as f:
    f.write('#ifndef TEST_CASE_H\n')
    f.write('#define TEST_CASE_H\n\n')
    f.write('#include <stdint.h>\n\n')
    
    # Data arrays
    lhs_type_str = 'int8_t' if lhs_dtype == 1 else 'int16_t'
    f.write(f'// input_b (LHS): ({K}, {N}), row-major\n')
    f.write(f'extern {lhs_type_str} input_b_data[{K * N}];\n\n')
    f.write(f'// input_a (RHS): ({N}, {M}), column-major\n')
    f.write(f'extern int8_t input_a_data[{N * M}];\n\n')
    f.write(f'// bias: length {M}\n')
    f.write('extern int32_t bias_data[%d];\n\n' % M)
    f.write(f'// Expected output: ({K}, {M})\n')
    f.write('extern int8_t expected_output_data[%d];\n\n' % (K * M))
    f.write(f'// Output buffer: ({K}, {M})\n')
    f.write('extern int8_t output_data[%d];\n\n' % (K * M))
    
    if quant_mode == 1:
        f.write(f'// Quantization parameters: length {M}\n')
        f.write('extern int32_t out_mult_data[%d];\n' % M)
        f.write('extern int32_t out_shift_data[%d];\n\n' % M)
    
    # Test parameters
    f.write('// Test parameters\n')
    f.write('extern const uint16_t output_ch;\n')
    f.write('extern const int32_t num_col_a;\n')
    f.write('extern const int32_t aligned_num_col_a;\n')
    f.write('extern const int32_t out_offset;\n')
    f.write('extern const int16_t activation_min;\n')
    f.write('extern const int16_t activation_max;\n\n')
    
    f.write('#endif // TEST_CASE_H\n')

