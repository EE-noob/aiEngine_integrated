#include "riscv_nn_mat_mult_acc.h"

#include <stdio.h>
#include <string.h>

#include "dsa_accel.h"
#include "riscv_nnfunctions.h"
#include "riscv_nnsupportfunctions.h"

// 公共 helper: 填充基础 DSA config (不含步进)
static void dsa_matmul_common_init(dsa_matmul_config_t* cfg) {
  dsa_matmul_config_init(cfg);
  cfg->rhs_dtype = DSA_DTYPE_S8;
  cfg->bias_dtype = DSA_DTYPE_S32;
  cfg->out_dtype = DSA_DTYPE_S8;
  cfg->rhs_offset = 0;  // 权重对称量化
}

// 对应 riscv_nn_mat_mult_nt_t_s8
riscv_nmsis_nn_status riscv_nn_mat_mult_nt_t_s8_acc(
    const int8_t* lhs, const int8_t* rhs, const int32_t* bias, int8_t* dst,
    const int32_t* dst_multipliers, const int32_t* dst_shifts,
    const int32_t lhs_rows, const int32_t rhs_rows, const int32_t rhs_cols,
    const int32_t lhs_offset, const int32_t dst_offset,
    const int32_t activation_min, const int32_t activation_max,
    const int32_t row_address_offset, const int32_t lhs_cols_offset) {
  (void)row_address_offset;
  (void)lhs_cols_offset;

  dsa_matmul_config_t cfg;
  dsa_matmul_common_init(&cfg);

  cfg.lhs_ptr = lhs;
  cfg.rhs_ptr = rhs;
  cfg.dst_ptr = dst;
  cfg.bias_ptr = bias;

  cfg.K = (uint32_t)lhs_rows;
  cfg.N = (uint32_t)rhs_cols;
  cfg.M = (uint32_t)rhs_rows;

  cfg.lhs_dtype = DSA_DTYPE_S8;

  // 行步长: LHS dense, RHS 每行 N, DST 每行 M
  cfg.lhs_row_stride = cfg.N * sizeof(int8_t);
  cfg.rhs_row_stride = cfg.N * sizeof(int8_t);
  cfg.dst_row_stride = cfg.M * sizeof(int8_t);

  // 量化
  cfg.quant_mode = DSA_QUANT_PER_CHANNEL;
  cfg.lhs_offset = lhs_offset;
  cfg.dst_offset = dst_offset;
  cfg.act_min = activation_min;
  cfg.act_max = activation_max;

  cfg.dst_mult_ptr = dst_multipliers;
  cfg.dst_shift_ptr = dst_shifts;

  // printf("K=%d, N=%d, M=%d\n", cfg.K, cfg.N, cfg.M);
  // printf("lhs_row_stride=%d, rhs_row_stride=%d, dst_row_stride=%d\n",
  //        cfg.lhs_row_stride, cfg.rhs_row_stride, cfg.dst_row_stride);

  uint32_t status = dsa_matmul_execute(&cfg);
  return (status == DSA_SUCCESS) ? RISCV_NMSIS_NN_SUCCESS
                                 : RISCV_NMSIS_NN_FAILURE;
}

int8_t* riscv_nn_mat_mult_kernel_s8_s16_acc_old(
    const int8_t* input_a, const int16_t* input_b, const uint16_t output_ch,
    const int32_t* out_shift, const int32_t* out_mult, const int32_t out_offset,
    const int16_t activation_min, const int16_t activation_max,
    const int32_t num_col_a, const int32_t aligned_num_col_a,
    const int32_t* const output_bias, int8_t* out_0) {
  dsa_matmul_config_t cfg;
  dsa_matmul_common_init(&cfg);

  cfg.lhs_ptr = input_b;  // s16, LHS
  cfg.rhs_ptr = input_a;  // s8, RHS
  cfg.dst_ptr = out_0;
  cfg.bias_ptr = output_bias;

  cfg.K = 2;                    // 该内核一次处理2“行”输入, 由调用者循环
  cfg.N = (uint32_t)num_col_a;  // 累加深度
  cfg.M = (uint32_t)output_ch;  // output_ch

  cfg.lhs_dtype = DSA_DTYPE_S16;
  cfg.rhs_dtype = DSA_DTYPE_S8;

  // 行步长:
  cfg.lhs_row_stride = aligned_num_col_a * sizeof(int16_t);  // input_b 行步长
  cfg.rhs_row_stride = cfg.N * sizeof(int8_t);               // input_a 行步长
  cfg.dst_row_stride = cfg.M * sizeof(int8_t);               // 单行输出

  // 量化: per-channel
  cfg.quant_mode = DSA_QUANT_PER_CHANNEL;
  cfg.lhs_offset = 0;  // 原 SW 内核不加 lhs_offset
  cfg.dst_offset = out_offset;
  cfg.act_min = activation_min;
  cfg.act_max = activation_max;

  cfg.dst_mult_ptr = out_mult;
  cfg.dst_shift_ptr = out_shift;

  uint32_t status = dsa_matmul_execute(&cfg);
  if (status != DSA_SUCCESS) {
    return NULL;
  }

  // 与原内核保持接口: 返回 out_0 行尾后指针 (C 行主序, 长度=output_ch)
  return out_0 + output_ch * 2;
}

int8_t* riscv_nn_mat_mult_kernel_row_offset_s8_s16_acc_old(
    const int8_t* input_a, const int16_t* input_b, const uint16_t output_ch,
    const int32_t* out_shift, const int32_t* out_mult, const int32_t out_offset,
    const int16_t activation_min, const int16_t activation_max,
    const int32_t num_col_a, const int32_t aligned_num_col_a,
    const int32_t* const output_bias, const int32_t row_address_offset,
    int8_t* out_0) {
  dsa_matmul_config_t cfg;
  dsa_matmul_common_init(&cfg);

  cfg.lhs_ptr = input_b;
  cfg.rhs_ptr = input_a;
  cfg.dst_ptr = out_0;
  cfg.bias_ptr = output_bias;

  cfg.K = 2;
  cfg.N = (uint32_t)num_col_a;
  cfg.M = (uint32_t)output_ch;

  cfg.lhs_dtype = DSA_DTYPE_S16;
  cfg.rhs_dtype = DSA_DTYPE_S8;

  cfg.lhs_row_stride = aligned_num_col_a * sizeof(int16_t);
  cfg.rhs_row_stride = cfg.N * sizeof(int8_t);

  // 特殊: 输出行步长由 row_address_offset 控制
  cfg.dst_row_stride = (uint32_t)row_address_offset;

  cfg.quant_mode = DSA_QUANT_PER_CHANNEL;
  cfg.lhs_offset = 0;
  cfg.dst_offset = out_offset;
  cfg.act_min = activation_min;
  cfg.act_max = activation_max;

  cfg.dst_mult_ptr = out_mult;
  cfg.dst_shift_ptr = out_shift;

  uint32_t status = dsa_matmul_execute(&cfg);
  if (status != DSA_SUCCESS) {
    return NULL;
  }

  // 与原内核保持接口: out_0 最终返回值 = 当前行首 + 2*row_address_offset -
  // output_ch
  return out_0 + row_address_offset * 2;
}

int8_t* riscv_nn_mat_mult_kernel_s8_s16_acc(
    const int8_t* input_a, const int16_t* input_b, const uint16_t output_ch,
    const int32_t* out_shift, const int32_t* out_mult, const int32_t out_offset,
    const int16_t activation_min, const int16_t activation_max,
    const int32_t num_col_a, const int32_t aligned_num_col_a,
    const int32_t* const output_bias, int8_t* out_0, const int32_t num_row_b) {
  dsa_matmul_config_t cfg;
  dsa_matmul_common_init(&cfg);

  cfg.lhs_ptr = input_b;  // s16, LHS
  cfg.rhs_ptr = input_a;  // s8, RHS
  cfg.dst_ptr = out_0;
  cfg.bias_ptr = output_bias;

  cfg.K = (uint32_t)num_row_b;
  cfg.N = (uint32_t)num_col_a;
  cfg.M = (uint32_t)output_ch;

  cfg.lhs_dtype = DSA_DTYPE_S16;
  cfg.rhs_dtype = DSA_DTYPE_S8;

  cfg.lhs_row_stride = aligned_num_col_a * sizeof(int16_t);
  cfg.rhs_row_stride = cfg.N * sizeof(int8_t);
  cfg.dst_row_stride = cfg.M * sizeof(int8_t);

  cfg.quant_mode = DSA_QUANT_PER_CHANNEL;
  cfg.lhs_offset = 0;
  cfg.dst_offset = out_offset;
  cfg.act_min = activation_min;
  cfg.act_max = activation_max;

  cfg.dst_mult_ptr = out_mult;
  cfg.dst_shift_ptr = out_shift;

  uint32_t status = dsa_matmul_execute(&cfg);
  if (status != DSA_SUCCESS) {
    return NULL;
  }

  return out_0 + output_ch * num_row_b;
}

int8_t* riscv_nn_mat_mult_kernel_row_offset_s8_s16_acc(
    const int8_t* input_a, const int16_t* input_b, const uint16_t output_ch,
    const int32_t* out_shift, const int32_t* out_mult, const int32_t out_offset,
    const int16_t activation_min, const int16_t activation_max,
    const int32_t num_col_a, const int32_t aligned_num_col_a,
    const int32_t* const output_bias, const int32_t row_address_offset,
    int8_t* out_0, const int32_t num_row_b) {
  dsa_matmul_config_t cfg;
  dsa_matmul_common_init(&cfg);

  cfg.lhs_ptr = input_b;
  cfg.rhs_ptr = input_a;
  cfg.dst_ptr = out_0;
  cfg.bias_ptr = output_bias;

  cfg.K = (uint32_t)num_row_b;
  cfg.N = (uint32_t)num_col_a;
  cfg.M = (uint32_t)output_ch;

  cfg.lhs_dtype = DSA_DTYPE_S16;
  cfg.rhs_dtype = DSA_DTYPE_S8;

  cfg.lhs_row_stride = aligned_num_col_a * sizeof(int16_t);
  cfg.rhs_row_stride = cfg.N * sizeof(int8_t);

  // 特殊: 输出行步长由 row_address_offset 控制
  cfg.dst_row_stride = (uint32_t)row_address_offset;

  cfg.quant_mode = DSA_QUANT_PER_CHANNEL;
  cfg.lhs_offset = 0;
  cfg.dst_offset = out_offset;
  cfg.act_min = activation_min;
  cfg.act_max = activation_max;

  cfg.dst_mult_ptr = out_mult;
  cfg.dst_shift_ptr = out_shift;

  uint32_t status = dsa_matmul_execute(&cfg);
  if (status != DSA_SUCCESS) {
    return NULL;
  }

  // 与原内核保持接口: out_0 最终返回值 = 当前行首 +
  // num_row_b*row_address_offset
  return out_0 + (num_row_b * row_address_offset);
}

int8_t* riscv_nn_mat_mult_kernel_s8_acc(
    const int8_t* input_a, const int8_t* input_b, const uint16_t output_ch,
    const int32_t* out_shift, const int32_t* out_mult, const int32_t out_offset,
    const int32_t input_offset, const int16_t activation_min,
    const int16_t activation_max, const int32_t num_col_a,
    const int32_t aligned_num_col_a, const int32_t* const output_bias,
    int8_t* out_0, const int32_t num_row_b) {
  dsa_matmul_config_t cfg;
  dsa_matmul_common_init(&cfg);

  cfg.lhs_ptr = input_b;  // s8, LHS
  cfg.rhs_ptr = input_a;  // s8, RHS
  cfg.dst_ptr = out_0;
  cfg.bias_ptr = output_bias;

  cfg.K = (uint32_t)num_row_b;
  cfg.N = (uint32_t)num_col_a;
  cfg.M = (uint32_t)output_ch;

  cfg.lhs_dtype = DSA_DTYPE_S8;
  cfg.rhs_dtype = DSA_DTYPE_S8;

  cfg.lhs_row_stride = aligned_num_col_a * sizeof(int8_t);
  cfg.rhs_row_stride = cfg.N * sizeof(int8_t);
  cfg.dst_row_stride = cfg.M * sizeof(int8_t);

  cfg.quant_mode = DSA_QUANT_PER_CHANNEL;
  cfg.lhs_offset = input_offset;
  cfg.dst_offset = out_offset;
  cfg.act_min = activation_min;
  cfg.act_max = activation_max;

  cfg.dst_mult_ptr = out_mult;
  cfg.dst_shift_ptr = out_shift;

  uint32_t status = dsa_matmul_execute(&cfg);
  if (status != DSA_SUCCESS) {
    return NULL;
  }

  return out_0 + output_ch * num_row_b;
}

int8_t* riscv_nn_mat_mult_kernel_row_offset_s8_acc(
    const int8_t* input_a, const int8_t* input_b, const uint16_t output_ch,
    const int32_t* out_shift, const int32_t* out_mult, const int32_t out_offset,
    const int32_t input_offset, const int16_t activation_min,
    const int16_t activation_max, const int32_t num_col_a,
    const int32_t aligned_num_col_a, const int32_t* const output_bias,
    const int32_t row_address_offset, int8_t* out_0, const int32_t num_row_b) {
  dsa_matmul_config_t cfg;
  dsa_matmul_common_init(&cfg);

  cfg.lhs_ptr = input_b;
  cfg.rhs_ptr = input_a;
  cfg.dst_ptr = out_0;
  cfg.bias_ptr = output_bias;

  cfg.K = (uint32_t)num_row_b;
  cfg.N = (uint32_t)num_col_a;
  cfg.M = (uint32_t)output_ch;

  cfg.lhs_dtype = DSA_DTYPE_S8;
  cfg.rhs_dtype = DSA_DTYPE_S8;

  cfg.lhs_row_stride = aligned_num_col_a * sizeof(int8_t);
  cfg.rhs_row_stride = cfg.N * sizeof(int8_t);

  cfg.dst_row_stride = (uint32_t)row_address_offset;

  cfg.quant_mode = DSA_QUANT_PER_CHANNEL;
  cfg.lhs_offset = input_offset;
  cfg.dst_offset = out_offset;
  cfg.act_min = activation_min;
  cfg.act_max = activation_max;

  cfg.dst_mult_ptr = out_mult;
  cfg.dst_shift_ptr = out_shift;

  uint32_t status = dsa_matmul_execute(&cfg);
  if (status != DSA_SUCCESS) {
    return NULL;
  }

  return out_0 + (num_row_b * row_address_offset);
}

// 对应 riscv_nn_vec_mat_mult_t_s8 (per-tensor quantization)
riscv_nmsis_nn_status riscv_nn_vec_mat_mult_t_s8_acc(
    const int8_t* lhs, const int8_t* rhs, const int32_t* kernel_sum,
    const int32_t* bias, int8_t* dst, const int32_t lhs_offset,
    const int32_t dst_offset, const int32_t dst_multiplier,
    const int32_t dst_shift, const int32_t rhs_cols, const int32_t rhs_rows,
    const int32_t activation_min, const int32_t activation_max,
    const int32_t address_offset, const int32_t rhs_offset) {
  (void)kernel_sum;

  dsa_matmul_config_t cfg;
  dsa_matmul_common_init(&cfg);

  cfg.lhs_ptr = lhs;    // 向量输入
  cfg.rhs_ptr = rhs;    // 权重矩阵(转置)
  cfg.dst_ptr = dst;
  cfg.bias_ptr = bias;

  // 向量-矩阵乘法: lhs 是 1×rhs_cols, rhs 是 rhs_rows×rhs_cols
  cfg.K = 1;                        // 向量只有1行
  cfg.N = (uint32_t)rhs_cols;       // 累加深度
  cfg.M = (uint32_t)rhs_rows;       // 输出通道数

  cfg.lhs_dtype = DSA_DTYPE_S8;
  cfg.rhs_dtype = DSA_DTYPE_S8;

  // 行步长
  cfg.lhs_row_stride = cfg.N * sizeof(int8_t);  // 向量步长
  cfg.rhs_row_stride = cfg.N * sizeof(int8_t);  // 权重每行步长
  cfg.dst_row_stride = (uint32_t)address_offset;  // 输出步长

  // Per-tensor 量化
  cfg.quant_mode = DSA_QUANT_PER_TENSOR;
  cfg.lhs_offset = lhs_offset;
  cfg.rhs_offset = rhs_offset;
  cfg.dst_offset = dst_offset;
  cfg.act_min = activation_min;
  cfg.act_max = activation_max;

  // Per-tensor: 单个 multiplier 和 shift
  cfg.dst_mult = dst_multiplier;
  cfg.dst_shift = dst_shift;

  uint32_t status = dsa_matmul_execute(&cfg);
  return (status == DSA_SUCCESS) ? RISCV_NMSIS_NN_SUCCESS
                                 : RISCV_NMSIS_NN_FAILURE;
}

// 对应 riscv_nn_vec_mat_mult_t_per_ch_s8 (per-channel quantization)
riscv_nmsis_nn_status riscv_nn_vec_mat_mult_t_per_ch_s8_acc(
    const int8_t* lhs, const int8_t* rhs, const int32_t* kernel_sum,
    const int32_t* bias, int8_t* dst, const int32_t lhs_offset,
    const int32_t dst_offset, const int32_t* dst_multiplier,
    const int32_t* dst_shift, const int32_t rhs_cols, const int32_t rhs_rows,
    const int32_t activation_min, const int32_t activation_max,
    const int32_t address_offset, const int32_t rhs_offset) {
  (void)kernel_sum;

  dsa_matmul_config_t cfg;
  dsa_matmul_common_init(&cfg);

  cfg.lhs_ptr = lhs;    // 向量输入
  cfg.rhs_ptr = rhs;    // 权重矩阵(转置)
  cfg.dst_ptr = dst;
  cfg.bias_ptr = bias;

  // 向量-矩阵乘法: lhs 是 1×rhs_cols, rhs 是 rhs_rows×rhs_cols
  cfg.K = 1;                        // 向量只有1行
  cfg.N = (uint32_t)rhs_cols;       // 累加深度
  cfg.M = (uint32_t)rhs_rows;       // 输出通道数

  cfg.lhs_dtype = DSA_DTYPE_S8;
  cfg.rhs_dtype = DSA_DTYPE_S8;

  // 行步长
  cfg.lhs_row_stride = cfg.N * sizeof(int8_t);  // 向量步长
  cfg.rhs_row_stride = cfg.N * sizeof(int8_t);  // 权重每行步长
  cfg.dst_row_stride = (uint32_t)address_offset;  // 输出步长

  // Per-channel 量化
  cfg.quant_mode = DSA_QUANT_PER_CHANNEL;
  cfg.lhs_offset = lhs_offset;
  cfg.rhs_offset = rhs_offset;
  cfg.dst_offset = dst_offset;
  cfg.act_min = activation_min;
  cfg.act_max = activation_max;

  // Per-channel: 每个输出通道一个 multiplier 和 shift
  cfg.dst_mult_ptr = dst_multiplier;
  cfg.dst_shift_ptr = dst_shift;

  uint32_t status = dsa_matmul_execute(&cfg);
  return (status == DSA_SUCCESS) ? RISCV_NMSIS_NN_SUCCESS
                                 : RISCV_NMSIS_NN_FAILURE;
}
