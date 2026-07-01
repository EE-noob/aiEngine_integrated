#ifndef RISCV_NN_MAT_MULT_ACC_CONV_H
#define RISCV_NN_MAT_MULT_ACC_CONV_H

#include <stdint.h>

#include "dsa_accel.h"
#include "riscv_nnfunctions.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief DSA hardware accelerated 1x1 s8 convolution with non-unity stride
 * support
 *
 * @param[in, out] ctx           Function context with optional buffer.
 * @param[in]      conv_params   Convolution parameters (e.g., strides, pads).
 *                               Range of conv_params->input_offset: [-127, 128]
 *                               Range of conv_params->output_offset: [-128,
 * 127]
 * @param[in]      quant_params  Per-channel quantization parameters.
 * @param[in]      input_dims    Dimensions of the input tensor. Format: [N, H,
 * W, C_IN]
 * @param[in]      input_data    Pointer to input data. Data type: int8
 * @param[in]      filter_dims   Dimensions of the filter tensor. Format:
 * [C_OUT, 1, 1, C_IN]
 * @param[in]      filter_data   Pointer to filter data. Data type: int8
 * @param[in]      bias_dims     Dimensions of the bias tensor. Format: [C_OUT]
 * @param[in]      bias_data     Pointer to bias data (optional). Data type:
 * int32
 * @param[in]      output_dims   Dimensions of the output tensor. Format: [N, H,
 * W, C_OUT]
 * @param[out]     output_data   Pointer to output data. Data type: int8
 *
 * @return     The function returns either
 *                  <code>RISCV_NMSIS_NN_SUCCESS</code> on successful
 * completion, or <code>RISCV_NMSIS_NN_ARG_ERROR</code> if argument constraints
 * fail.
 *
 * @details
 *    - DSA accelerated version of 1x1 convolution
 *    - Optimized for point-wise convolution operations
 *    - Supports non-unity strides
 */
riscv_nmsis_nn_status riscv_convolve_1x1_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_conv_params *conv_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input_data,
    const nmsis_nn_dims *filter_dims, const int8_t *filter_data,
    const nmsis_nn_dims *bias_dims, const int32_t *bias_data,
    const nmsis_nn_dims *output_dims, int8_t *output_data);

/**
 * @brief Get buffer size for riscv_convolve_s8_acc
 *
 * @param[in]      conv_params    Convolution parameters (e.g. strides,
 * dilations, pads,...).
 * @param[in]      input_dims     Input (activation) dimensions. Format: [N, H,
 * W, C_IN]
 * @param[in]      filter_dims    Filter dimensions. Format: [C_OUT, HK, WK,
 * C_IN]
 * @param[in]      output_dims    Output tensor dimensions. Format: [N, H, W,
 * C_OUT]
 *
 * @return         The function returns required buffer size in bytes
 *
 * @details
 *    - Provides the scratch buffer size needed by riscv_convolve_wrapper_s8_acc
 */
int32_t riscv_convolve_wrapper_s8_get_buffer_size_acc(
    const nmsis_nn_conv_params *conv_params, const nmsis_nn_dims *input_dims,
    const nmsis_nn_dims *filter_dims, const nmsis_nn_dims *output_dims);

/**
 * @brief DSA hardware accelerated s8 convolution
 *
 * @param[in]      ctx             Function context (e.g. temporary buffer).
 * @param[in]      conv_params     Convolution parameters (e.g. strides,
 * dilations, pads,...).
 * @param[in]      quant_params    Per-channel quantization info.
 * @param[in]      input_dims      Input (activation) tensor dimensions. Format:
 * [N, H, W, C_IN]
 * @param[in]      input_data      Input (activation) data pointer. Data type:
 * int8
 * @param[in]      filter_dims     Filter tensor dimensions. Format: [C_OUT, HK,
 * WK, C_IN]
 * @param[in]      filter_data     Filter data pointer. Data type: int8
 * @param[in]      bias_dims       Bias tensor dimensions. Format: [C_OUT]
 * @param[in]      bias_data       Bias data pointer. Data type: int32
 * @param[in]      upscale_dims    Upscaling dimensions for transposed
 * convolution
 * @param[in]      output_dims     Output tensor dimensions. Format: [N, H, W,
 * C_OUT]
 * @param[out]     output_data     Output data pointer. Data type: int8
 *
 * @return     The function returns either
 *                  <code>RISCV_NMSIS_NN_ARG_ERROR</code> if argument
 * constraints fail, or <code>RISCV_NMSIS_NN_SUCCESS</code> on successful
 * completion.
 *
 * @details
 *    - DSA accelerated version of riscv_convolve_s8
 */
riscv_nmsis_nn_status riscv_convolve_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_conv_params *conv_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input_data,
    const nmsis_nn_dims *filter_dims, const int8_t *filter_data,
    const nmsis_nn_dims *bias_dims, const int32_t *bias_data,
    const nmsis_nn_dims *upscale_dims, const nmsis_nn_dims *output_dims,
    int8_t *output_data);

/**
 * @brief DSA hardware accelerated fast 1x1 s8 convolution
 *
 * @param[in, out] ctx           Function context with optional buffer.
 * @param[in]      conv_params   Convolution parameters (e.g., strides, pads).
 *                               Range of conv_params->input_offset: [-127, 128]
 *                               Range of conv_params->output_offset: [-128,
 * 127]
 * @param[in]      quant_params  Per-channel quantization parameters.
 * @param[in]      input_dims    Dimensions of the input tensor. Format: [N, H,
 * W, C_IN]
 * @param[in]      input_data    Pointer to input data. Data type: int8
 * @param[in]      filter_dims   Dimensions of the filter tensor. Format:
 * [C_OUT, 1, 1, C_IN]
 * @param[in]      filter_data   Pointer to filter data. Data type: int8
 * @param[in]      bias_dims     Dimensions of the bias tensor. Format: [C_OUT]
 * @param[in]      bias_data     Pointer to bias data (optional). Data type:
 * int32
 * @param[in]      output_dims   Dimensions of the output tensor. Format: [N, H,
 * W, C_OUT]
 * @param[out]     output_data   Pointer to output data. Data type: int8
 *
 * @return     The function returns either
 *                  <code>RISCV_NMSIS_NN_SUCCESS</code> on successful
 * completion, or <code>RISCV_NMSIS_NN_ARG_ERROR</code> if argument constraints
 * fail.
 *
 * @details
 *    - DSA accelerated fast version of 1x1 convolution
 *    - Optimized for performance with potential trade-offs in accuracy
 *    - Supports point-wise convolution operations
 */
riscv_nmsis_nn_status riscv_convolve_1x1_s8_fast_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_conv_params *conv_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input_data,
    const nmsis_nn_dims *filter_dims, const int8_t *filter_data,
    const nmsis_nn_dims *bias_dims, const int32_t *bias_data,
    const nmsis_nn_dims *output_dims, int8_t *output_data);

/**
 * @brief DSA hardware accelerated s8 convolution wrapper function
 *
 * @param[in]      ctx             Function context (e.g. temporary buffer).
 * @param[in]      conv_params     Convolution parameters (e.g. strides,
 * dilations, pads,...).
 * @param[in]      quant_params    Per-channel quantization info.
 * @param[in]      input_dims      Input (activation) tensor dimensions. Format:
 * [N, H, W, C_IN]
 * @param[in]      input_data      Input (activation) data pointer. Data type:
 * int8
 * @param[in]      filter_dims     Filter tensor dimensions. Format: [C_OUT, HK,
 * WK, C_IN]
 * @param[in]      filter_data     Filter data pointer. Data type: int8
 * @param[in]      bias_dims       Bias tensor dimensions. Format: [C_OUT]
 * @param[in]      bias_data       Bias data pointer. Data type: int32
 * @param[in]      output_dims     Output tensor dimensions. Format: [N, H, W,
 * C_OUT]
 * @param[out]     output_data     Output data pointer. Data type: int8
 *
 * @return     The function returns either
 *                  <code>RISCV_NMSIS_NN_ARG_ERROR</code> if argument
 * constraints fail, or <code>RISCV_NMSIS_NN_SUCCESS</code> on successful
 * completion.
 *
 * @details
 *    - DSA accelerated wrapper that selects optimal convolution implementation
 *    - May call specialized kernels (e.g., 1x1 convolution) based on filter
 * dimensions
 */
riscv_nmsis_nn_status riscv_convolve_wrapper_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_conv_params *conv_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input_data,
    const nmsis_nn_dims *filter_dims, const int8_t *filter_data,
    const nmsis_nn_dims *bias_dims, const int32_t *bias_data,
    const nmsis_nn_dims *output_dims, int8_t *output_data);

/**
 * @brief DSA hardware accelerated s8 depthwise convolution wrapper
 *
 * @param[in]      ctx             Function context (e.g. temporary buffer).
 * @param[in]      dw_conv_params  Depthwise convolution parameters (e.g. strides, pads, dilations).
 * @param[in]      quant_params    Per-channel quantization parameters.
 * @param[in]      input_dims      Input (activation) tensor dimensions. Format: [N, H, W, C_IN]
 * @param[in]      input           Input (activation) data pointer. Data type: int8
 * @param[in]      filter_dims     Filter tensor dimensions. Format: [1, HK, WK, C_IN]
 * @param[in]      filter          Filter data pointer. Data type: int8
 * @param[in]      bias_dims       Bias tensor dimensions. Format: [C_OUT]
 * @param[in]      bias            Bias data pointer. Data type: int32
 * @param[in]      output_dims     Output tensor dimensions. Format: [N, H, W, C_OUT]
 * @param[out]     output          Output data pointer. Data type: int8
 *
 * @return     The function returns either
 *                  <code>RISCV_NMSIS_NN_ARG_ERROR</code> if argument constraints fail,
 *                  or <code>RISCV_NMSIS_NN_SUCCESS</code> on successful completion.
 *
 * @details
 *    - DSA accelerated wrapper for depthwise convolution
 *    - Applies separate convolution to each input channel
 *    - Optimized for depthwise separable convolution operations
 */
riscv_nmsis_nn_status riscv_depthwise_conv_wrapper_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_dw_conv_params *dw_conv_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input,
    const nmsis_nn_dims *filter_dims, const int8_t *filter,
    const nmsis_nn_dims *bias_dims, const int32_t *bias,
    const nmsis_nn_dims *output_dims, int8_t *output);
    
/**
 * @brief Get buffer size for riscv_depthwise_conv_wrapper_s8_acc
 *
 * @param[in]      dw_conv_params  Depthwise convolution parameters (e.g. strides, dilations, pads).
 * @param[in]      input_dims      Input (activation) dimensions. Format: [N, H, W, C_IN]
 * @param[in]      filter_dims     Filter dimensions. Format: [1, HK, WK, C_IN]
 * @param[in]      output_dims     Output tensor dimensions. Format: [N, H, W, C_OUT]
 *
 * @return         The function returns required buffer size in bytes
 *
 * @details
 *    - Provides the scratch buffer size needed by riscv_depthwise_conv_wrapper_s8_acc
 *    - Calculates buffer requirements for depthwise convolution operations
 */
int32_t riscv_depthwise_conv_wrapper_s8_get_buffer_size_acc(
    const nmsis_nn_dw_conv_params *dw_conv_params,
    const nmsis_nn_dims *input_dims, const nmsis_nn_dims *filter_dims,
    const nmsis_nn_dims *output_dims);

#ifdef __cplusplus
}
#endif

#endif /* RISCV_NN_MAT_MULT_ACC_CONV_H */