#ifndef RISCV_NN_MAT_MULT_ACC_FC_H
#define RISCV_NN_MAT_MULT_ACC_FC_H

#include <stdint.h>

#include "dsa_accel.h"
#include "riscv_nnfunctions.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief DSA hardware accelerated s8 fully connected layer (legacy version)
 *
 * @note This is an older implementation. Consider using
 * riscv_fully_connected_s8_acc instead.
 *
 * @param[in]      ctx             Function context (e.g. temporary buffer).
 * @param[in]      fc_params       Fully connected layer parameters.
 * @param[in]      quant_params    Per-tensor quantization info.
 * @param[in]      input_dims      Input (activation) tensor dimensions. Format:
 * [N, H, W, C_IN]
 * @param[in]      input           Input (activation) data pointer. Data type:
 * int8
 * @param[in]      filter_dims     Filter tensor dimensions.
 * @param[in]      kernel          Filter data pointer. Data type: int8
 * @param[in]      bias_dims       Bias tensor dimensions.
 * @param[in]      bias            Bias data pointer. Data type: int32
 * @param[in]      output_dims     Output tensor dimensions.
 * @param[out]     output          Output data pointer. Data type: int8
 *
 * @return     The function returns either
 *                  <code>RISCV_NMSIS_NN_ARG_ERROR</code> if argument
 * constraints fail, or <code>RISCV_NMSIS_NN_SUCCESS</code> on successful
 * completion.
 */
riscv_nmsis_nn_status riscv_fully_connected_s8_acc_old(
    const nmsis_nn_context *ctx, const nmsis_nn_fc_params *fc_params,
    const nmsis_nn_per_tensor_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input,
    const nmsis_nn_dims *filter_dims, const int8_t *kernel,
    const nmsis_nn_dims *bias_dims, const int32_t *bias,
    const nmsis_nn_dims *output_dims, int8_t *output);

/**
 * @brief DSA hardware accelerated s8 fully connected layer
 *
 * @param[in]      ctx             Function context (e.g. temporary buffer).
 *                                The caller is expected to clear the buffer, if
 * applicable, for security reasons.
 * @param[in]      fc_params       Fully connected layer parameters.
 *                                Range of fc_params->input_offset: [-127, 128]
 *                                Range of fc_params->output_offset: [-128, 127]
 * @param[in]      quant_params    Per-tensor quantization info.
 * @param[in]      input_dims      Input (activation) tensor dimensions. Format:
 * [N, H, W, C_IN]
 * @param[in]      input           Input (activation) data pointer. Data type:
 * int8
 * @param[in]      filter_dims     Filter tensor dimensions. Format: [N, C]
 * @param[in]      kernel          Filter data pointer. Data type: int8
 * @param[in]      bias_dims       Bias tensor dimensions. Format: [C_OUT]
 * @param[in]      bias            Bias data pointer. Data type: int32
 * @param[in]      output_dims     Output tensor dimensions. Format: [N, C_OUT]
 * @param[out]     output          Output data pointer. Data type: int8
 *
 * @return     The function returns either
 *                  <code>RISCV_NMSIS_NN_ARG_ERROR</code> if argument
 * constraints fail, or <code>RISCV_NMSIS_NN_SUCCESS</code> on successful
 * completion.
 *
 * @details
 *    - DSA accelerated version of riscv_fully_connected_s8
 *    - Uses DSA hardware for efficient matrix multiplication
 *    - Supported framework: TensorFlow Lite
 */
riscv_nmsis_nn_status riscv_fully_connected_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_fc_params *fc_params,
    const nmsis_nn_per_tensor_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input,
    const nmsis_nn_dims *filter_dims, const int8_t *kernel,
    const nmsis_nn_dims *bias_dims, const int32_t *bias,
    const nmsis_nn_dims *output_dims, int8_t *output);

riscv_nmsis_nn_status riscv_fully_connected_wrapper_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_fc_params *fc_params,
    const nmsis_nn_quant_params *quant_params, const nmsis_nn_dims *input_dims,
    const int8_t *input_data, const nmsis_nn_dims *filter_dims,
    const int8_t *filter_data, const nmsis_nn_dims *bias_dims,
    const int32_t *bias_data, const nmsis_nn_dims *output_dims,
    int8_t *output_data);

/**
 * @brief DSA hardware accelerated s8 fully connected layer with per-channel
 * quantization
 *
 * @param[in]      ctx             Function context (e.g. temporary buffer).
 *                                The caller is expected to clear the buffer, if
 * applicable, for security reasons.
 * @param[in]      fc_params       Fully connected layer parameters.
 *                                Range of fc_params->input_offset: [-127, 128]
 *                                Range of fc_params->output_offset: [-128, 127]
 * @param[in]      quant_params    Per-channel quantization info.
 *                                It contains the multiplier and shift values
 * for each output channel.
 * @param[in]      input_dims      Input (activation) tensor dimensions. Format:
 * [N, H, W, C_IN]
 * @param[in]      input_data      Input (activation) data pointer. Data type:
 * int8
 * @param[in]      filter_dims     Filter tensor dimensions. Format: [N, C]
 * @param[in]      kernel          Filter data pointer. Data type: int8
 * @param[in]      bias_dims       Bias tensor dimensions. Format: [C_OUT]
 * @param[in]      bias_data       Bias data pointer. Data type: int32
 * @param[in]      output_dims     Output tensor dimensions. Format: [N, C_OUT]
 * @param[out]     output_data     Output data pointer. Data type: int8
 *
 * @return     The function returns either
 *                  <code>RISCV_NMSIS_NN_ARG_ERROR</code> if argument
 * constraints fail, or <code>RISCV_NMSIS_NN_SUCCESS</code> on successful
 * completion.
 *
 * @details
 *    - DSA accelerated version of riscv_fully_connected_per_channel_s8
 *    - Supports per-channel quantization for improved accuracy
 *    - Supported framework: TensorFlow Lite
 */
riscv_nmsis_nn_status riscv_fully_connected_per_channel_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_fc_params *fc_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input_data,
    const nmsis_nn_dims *filter_dims, const int8_t *kernel,
    const nmsis_nn_dims *bias_dims, const int32_t *bias_data,
    const nmsis_nn_dims *output_dims, int8_t *output_data);

#ifdef __cplusplus
}
#endif

#endif /* RISCV_NN_MAT_MULT_ACC_FC_H */