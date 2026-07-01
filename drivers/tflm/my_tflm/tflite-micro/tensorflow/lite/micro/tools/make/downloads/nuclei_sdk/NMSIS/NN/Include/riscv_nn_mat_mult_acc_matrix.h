#ifndef RISCV_NN_MAT_MULT_ACC_MATRIX_H
#define RISCV_NN_MAT_MULT_ACC_MATRIX_H

#include <stdint.h>

#include "dsa_accel.h"
#include "riscv_nnfunctions.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief DSA hardware accelerated s8 matrix multiplication with non-transposed
 * LHS and transposed RHS
 *
 * @param[in]       lhs                     Pointer to the left-hand side matrix
 * (LHS). Data type: int8 Shape: [lhs_rows, rhs_rows] (K×N format)
 * @param[in]       rhs                     Pointer to the right-hand side
 * matrix (RHS). Data type: int8 Stored in row-major order as [rhs_cols,
 * rhs_rows] (M×N format)
 * @param[in]       bias                    Pointer to bias vector. Data type:
 * int32 Can be NULL if no bias is used.
 * @param[out]      dst                     Pointer to the output matrix. Data
 * type: int8
 * @param[in]       dst_multipliers         Pointer to per-channel multipliers
 * for output quantization
 * @param[in]       dst_shifts              Pointer to per-channel shifts for
 * output quantization
 * @param[in]       lhs_rows                Number of rows in LHS matrix (K
 * dimension)
 * @param[in]       rhs_rows                Number of rows in RHS matrix (N
 * dimension, accumulation depth)
 * @param[in]       rhs_cols                Number of columns in RHS matrix (M
 * dimension, output channels)
 * @param[in]       lhs_offset              Input offset to be added to LHS
 * elements. Range: [-127, 128]
 * @param[in]       dst_offset              Output offset to be added after
 * quantization. Range: [-128, 127]
 * @param[in]       activation_min          Minimum value to clamp output to.
 * Min: -128
 * @param[in]       activation_max          Maximum value to clamp output to.
 * Max: 127
 * @param[in]       row_address_offset      Stride (in elements) between
 * consecutive output rows Used for strided output storage
 * @param[in]       lhs_cols_offset         Column offset for LHS matrix
 * (typically 0)
 *
 * @return     The function returns either
 *                  <code>RISCV_NMSIS_NN_SUCCESS</code> on successful
 * completion, or <code>RISCV_NMSIS_NN_ARG_ERROR</code> if argument constraints
 * fail.
 *
 * @details
 *    - DSA accelerated version of riscv_nn_mat_mult_nt_t_s8
 *    - Performs matrix multiplication: dst = LHS × RHS^T + bias
 *    - Supports per-channel quantization with multipliers and shifts
 *    - Activation clamping applied to output values
 */
riscv_nmsis_nn_status riscv_nn_mat_mult_nt_t_s8_acc(
    const int8_t *lhs, const int8_t *rhs, const int32_t *bias, int8_t *dst,
    const int32_t *dst_multipliers, const int32_t *dst_shifts,
    const int32_t lhs_rows, const int32_t rhs_rows, const int32_t rhs_cols,
    const int32_t lhs_offset, const int32_t dst_offset,
    const int32_t activation_min, const int32_t activation_max,
    const int32_t row_address_offset, const int32_t lhs_cols_offset);

/**
 * @brief DSA hardware accelerated s8/s16 matrix multiplication kernel
 *
 * @param[in]       input_a                 Pointer to input matrix A. Data
 * type: int8
 * @param[in]       input_b                 Pointer to input matrix B. Data
 * type: int16
 * @param[in]       output_ch               Number of output channels
 * @param[in]       out_shift               Pointer to per-channel output shifts
 * @param[in]       out_mult                Pointer to per-channel output
 * multipliers
 * @param[in]       out_offset              Output offset. Range: [-128, 127]
 * @param[in]       activation_min          Minimum value to clamp output to.
 * Min: -128
 * @param[in]       activation_max          Maximum value to clamp output to.
 * Max: 127
 * @param[in]       num_col_a               Number of columns in matrix A
 * (accumulation depth)
 * @param[in]       aligned_num_col_a       Aligned number of columns (for
 * memory alignment)
 * @param[in]       output_bias             Pointer to output bias values. Data
 * type: int32
 * @param[in, out]  out_0                   Pointer to output buffer. Data type:
 * int8
 * @param[in]       num_row_b               Number of rows in matrix B
 *
 * @return          Pointer to the updated output buffer position
 *
 * @details
 *    - DSA accelerated version of riscv_nn_mat_mult_kernel_s8_s16
 *    - Processes matrix multiplication with mixed precision inputs (s8 × s16)
 *    - Output is quantized to int8 with per-channel scaling
 */
int8_t *riscv_nn_mat_mult_kernel_s8_s16_acc(
    const int8_t *input_a, const int16_t *input_b, const uint16_t output_ch,
    const int32_t *out_shift, const int32_t *out_mult, const int32_t out_offset,
    const int16_t activation_min, const int16_t activation_max,
    const int32_t num_col_a, const int32_t aligned_num_col_a,
    const int32_t *const output_bias, int8_t *out_0, const int32_t num_row_b);

/**
 * @brief DSA hardware accelerated s8/s16 matrix multiplication kernel with row
 * offset support
 *
 * @param[in]       input_a                 Pointer to input matrix A. Data
 * type: int8
 * @param[in]       input_b                 Pointer to input matrix B. Data
 * type: int16
 * @param[in]       output_ch               Number of output channels
 * @param[in]       out_shift               Pointer to per-channel output shifts
 * @param[in]       out_mult                Pointer to per-channel output
 * multipliers
 * @param[in]       out_offset              Output offset. Range: [-128, 127]
 * @param[in]       activation_min          Minimum value to clamp output to.
 * Min: -128
 * @param[in]       activation_max          Maximum value to clamp output to.
 * Max: 127
 * @param[in]       num_col_a               Number of columns in matrix A
 * (accumulation depth)
 * @param[in]       aligned_num_col_a       Aligned number of columns (for
 * memory alignment)
 * @param[in]       output_bias             Pointer to output bias values. Data
 * type: int32
 * @param[in]       row_address_offset      Stride (in bytes) between
 * consecutive output rows
 * @param[in, out]  out_0                   Pointer to output buffer. Data type:
 * int8
 * @param[in]       num_row_b               Number of rows in matrix B
 *
 * @return          Pointer to the updated output buffer position
 *
 * @details
 *    - DSA accelerated version of riscv_nn_mat_mult_kernel_row_offset_s8_s16
 *    - Similar to riscv_nn_mat_mult_kernel_s8_s16_acc but with custom output
 * row stride
 *    - Useful for writing to non-contiguous output memory regions
 */
int8_t *riscv_nn_mat_mult_kernel_row_offset_s8_s16_acc(
    const int8_t *input_a, const int16_t *input_b, const uint16_t output_ch,
    const int32_t *out_shift, const int32_t *out_mult, const int32_t out_offset,
    const int16_t activation_min, const int16_t activation_max,
    const int32_t num_col_a, const int32_t aligned_num_col_a,
    const int32_t *const output_bias, const int32_t row_address_offset,
    int8_t *out_0, const int32_t num_row_b);

/**
 * @brief DSA hardware accelerated s8/s16 matrix multiplication kernel (legacy
 * version)
 *
 * @note This is an older implementation. Consider using
 * riscv_nn_mat_mult_kernel_s8_s16_acc instead.
 *
 * @param[in]       input_a                 Pointer to input matrix A. Data
 * type: int8
 * @param[in]       input_b                 Pointer to input matrix B. Data
 * type: int16
 * @param[in]       output_ch               Number of output channels
 * @param[in]       out_shift               Pointer to per-channel output shifts
 * @param[in]       out_mult                Pointer to per-channel output
 * multipliers
 * @param[in]       out_offset              Output offset. Range: [-128, 127]
 * @param[in]       activation_min          Minimum value to clamp output to.
 * Min: -128
 * @param[in]       activation_max          Maximum value to clamp output to.
 * Max: 127
 * @param[in]       num_col_a               Number of columns in matrix A
 * (accumulation depth)
 * @param[in]       aligned_num_col_a       Aligned number of columns (for
 * memory alignment)
 * @param[in]       output_bias             Pointer to output bias values. Data
 * type: int32
 * @param[in, out]  out_0                   Pointer to output buffer. Data type:
 * int8
 *
 * @return          Pointer to the updated output buffer position
 */
int8_t *riscv_nn_mat_mult_kernel_s8_s16_acc_old(
    const int8_t *input_a, const int16_t *input_b, const uint16_t output_ch,
    const int32_t *out_shift, const int32_t *out_mult, const int32_t out_offset,
    const int16_t activation_min, const int16_t activation_max,
    const int32_t num_col_a, const int32_t aligned_num_col_a,
    const int32_t *const output_bias, int8_t *out_0);

/**
 * @brief DSA hardware accelerated s8/s16 matrix multiplication kernel with row
 * offset (legacy version)
 *
 * @note This is an older implementation. Consider using
 * riscv_nn_mat_mult_kernel_row_offset_s8_s16_acc instead.
 *
 * @param[in]       input_a                 Pointer to input matrix A. Data
 * type: int8
 * @param[in]       input_b                 Pointer to input matrix B. Data
 * type: int16
 * @param[in]       output_ch               Number of output channels
 * @param[in]       out_shift               Pointer to per-channel output shifts
 * @param[in]       out_mult                Pointer to per-channel output
 * multipliers
 * @param[in]       out_offset              Output offset. Range: [-128, 127]
 * @param[in]       activation_min          Minimum value to clamp output to.
 * Min: -128
 * @param[in]       activation_max          Maximum value to clamp output to.
 * Max: 127
 * @param[in]       num_col_a               Number of columns in matrix A
 * (accumulation depth)
 * @param[in]       aligned_num_col_a       Aligned number of columns (for
 * memory alignment)
 * @param[in]       output_bias             Pointer to output bias values. Data
 * type: int32
 * @param[in]       row_address_offset      Stride (in bytes) between
 * consecutive output rows
 * @param[in, out]  out_0                   Pointer to output buffer. Data type:
 * int8
 *
 * @return          Pointer to the updated output buffer position
 */
int8_t *riscv_nn_mat_mult_kernel_row_offset_s8_s16_acc_old(
    const int8_t *input_a, const int16_t *input_b, const uint16_t output_ch,
    const int32_t *out_shift, const int32_t *out_mult, const int32_t out_offset,
    const int16_t activation_min, const int16_t activation_max,
    const int32_t num_col_a, const int32_t aligned_num_col_a,
    const int32_t *const output_bias, const int32_t row_address_offset,
    int8_t *out_0);

/**
 * @brief DSA hardware accelerated s8 matrix multiplication kernel
 *
 * @param[in]       input_a                 Pointer to input matrix A. Data
 * type: int8
 * @param[in]       input_b                 Pointer to input matrix B. Data
 * type: int8
 * @param[in]       output_ch               Number of output channels
 * @param[in]       out_shift               Pointer to per-channel output shifts
 * @param[in]       out_mult                Pointer to per-channel output
 * multipliers
 * @param[in]       out_offset              Output offset. Range: [-128, 127]
 * @param[in]       input_offset            Input offset for matrix A. Range:
 * [-127, 128]
 * @param[in]       activation_min          Minimum value to clamp output to.
 * Min: -128
 * @param[in]       activation_max          Maximum value to clamp output to.
 * Max: 127
 * @param[in]       num_col_a               Number of columns in matrix A
 * (accumulation depth)
 * @param[in]       aligned_num_col_a       Aligned number of columns (for
 * memory alignment)
 * @param[in]       output_bias             Pointer to output bias values. Data
 * type: int32
 * @param[in, out]  out_0                   Pointer to output buffer. Data type:
 * int8
 * @param[in]       num_row_b               Number of rows in matrix B
 *
 * @return          Pointer to the updated output buffer position
 *
 * @details
 *    - DSA accelerated version of riscv_nn_mat_mult_kernel_s8
 *    - Performs s8 × s8 matrix multiplication with quantization
 *    - Supports input offset for asymmetric quantization
 */
int8_t *riscv_nn_mat_mult_kernel_s8_acc(
    const int8_t *input_a, const int8_t *input_b, const uint16_t output_ch,
    const int32_t *out_shift, const int32_t *out_mult, const int32_t out_offset,
    const int32_t input_offset, const int16_t activation_min,
    const int16_t activation_max, const int32_t num_col_a,
    const int32_t aligned_num_col_a, const int32_t *const output_bias,
    int8_t *out_0, const int32_t num_row_b);

/**
 * @brief DSA hardware accelerated s8 matrix multiplication kernel with row
 * offset
 *
 * @param[in]       input_a                 Pointer to input matrix A. Data
 * type: int8
 * @param[in]       input_b                 Pointer to input matrix B. Data
 * type: int8
 * @param[in]       output_ch               Number of output channels
 * @param[in]       out_shift               Pointer to per-channel output shifts
 * @param[in]       out_mult                Pointer to per-channel output
 * multipliers
 * @param[in]       out_offset              Output offset. Range: [-128, 127]
 * @param[in]       input_offset            Input offset for matrix A. Range:
 * [-127, 128]
 * @param[in]       activation_min          Minimum value to clamp output to.
 * Min: -128
 * @param[in]       activation_max          Maximum value to clamp output to.
 * Max: 127
 * @param[in]       num_col_a               Number of columns in matrix A
 * (accumulation depth)
 * @param[in]       aligned_num_col_a       Aligned number of columns (for
 * memory alignment)
 * @param[in]       output_bias             Pointer to output bias values. Data
 * type: int32
 * @param[in]       row_address_offset      Stride (in bytes) between
 * consecutive output rows
 * @param[in, out]  out_0                   Pointer to output buffer. Data type:
 * int8
 * @param[in]       num_row_b               Number of rows in matrix B
 *
 * @return          Pointer to the updated output buffer position
 *
 * @details
 *    - DSA accelerated version with custom output row addressing
 *    - Enables efficient handling of strided or tiled output layouts
 */
int8_t *riscv_nn_mat_mult_kernel_row_offset_s8_acc(
    const int8_t *input_a, const int8_t *input_b, const uint16_t output_ch,
    const int32_t *out_shift, const int32_t *out_mult, const int32_t out_offset,
    const int32_t input_offset, const int16_t activation_min,
    const int16_t activation_max, const int32_t num_col_a,
    const int32_t aligned_num_col_a, const int32_t *const output_bias,
    const int32_t row_address_offset, int8_t *out_0, const int32_t num_row_b);

#ifdef __cplusplus
}
#endif

#endif /* RISCV_NN_MAT_MULT_ACC_MATRIX_H */