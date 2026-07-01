#include "riscv_nn_mat_mult_acc.h"
#include "riscv_nnfunctions.h"
#include "riscv_nnsupportfunctions.h"
#include <stdio.h>
#include <string.h>

#include "dsa_accel.h"

riscv_nmsis_nn_status riscv_fully_connected_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_fc_params *fc_params,
    const nmsis_nn_per_tensor_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input,
    const nmsis_nn_dims *filter_dims, const int8_t *kernel,
    const nmsis_nn_dims *bias_dims, const int32_t *bias,
    const nmsis_nn_dims *output_dims, int8_t *output)
{
    (void)ctx; // DSA 不使用缓冲区
    (void)bias_dims;

    int32_t batch_cnt = input_dims->n;

    dsa_matmul_config_t cfg;
    dsa_matmul_config_init(&cfg);
    cfg.lhs_dtype = DSA_DTYPE_S8;
    cfg.rhs_dtype = DSA_DTYPE_S8;
    cfg.bias_dtype = DSA_DTYPE_S32;
    cfg.out_dtype = DSA_DTYPE_S8;

    cfg.lhs_ptr = input;
    cfg.rhs_ptr = kernel;
    cfg.dst_ptr = output;
    cfg.bias_ptr = bias;

    cfg.K = (uint32_t)batch_cnt;      // 直接使用batch_cnt作为K尺寸
    cfg.N = (uint32_t)filter_dims->n; // 累加深度
    cfg.M = (uint32_t)output_dims->c; // 输出深度

    cfg.lhs_row_stride = cfg.N * sizeof(int8_t); // 输入向量步长（每行N元素）
    cfg.rhs_row_stride = cfg.N * sizeof(int8_t); // kernel 行步长
    cfg.dst_row_stride = cfg.M * sizeof(int8_t); // 输出行步长

    cfg.quant_mode = DSA_QUANT_PER_TENSOR; // per-tensor 量化
    cfg.lhs_offset = fc_params->input_offset;
    cfg.rhs_offset = fc_params->filter_offset;
    cfg.dst_offset = fc_params->output_offset;
    cfg.act_min = fc_params->activation.min;
    cfg.act_max = fc_params->activation.max;

    cfg.dst_mult = quant_params->multiplier; // per-tensor multiplier
    cfg.dst_shift = quant_params->shift;     // per-tensor shift

    uint32_t status = dsa_matmul_execute(&cfg);
    if (status != DSA_SUCCESS) {
        return RISCV_NMSIS_NN_FAILURE;
    }

    return RISCV_NMSIS_NN_SUCCESS;
}

/*
 * S8 basic fully-connected and matrix multiplication layer function using
 * per-channel quantization for TensorFlow Lite
 *
 * Refer header file for details.
 *
 */
riscv_nmsis_nn_status riscv_fully_connected_per_channel_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_fc_params *fc_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input_data,
    const nmsis_nn_dims *filter_dims, const int8_t *kernel,
    const nmsis_nn_dims *bias_dims, const int32_t *bias_data,
    const nmsis_nn_dims *output_dims, int8_t *output_data)
{
    (void)ctx; // DSA 不使用缓冲区
    (void)bias_dims;

    int32_t batch_cnt = input_dims->n;

    dsa_matmul_config_t cfg;
    dsa_matmul_config_init(&cfg);
    cfg.lhs_dtype = DSA_DTYPE_S8;
    cfg.rhs_dtype = DSA_DTYPE_S8;
    cfg.bias_dtype = DSA_DTYPE_S32;
    cfg.out_dtype = DSA_DTYPE_S8;

    cfg.lhs_ptr = input_data;
    cfg.rhs_ptr = kernel;
    cfg.dst_ptr = output_data;
    cfg.bias_ptr = bias_data;

    cfg.K = (uint32_t)batch_cnt;      // 直接使用batch_cnt作为K尺寸
    cfg.N = (uint32_t)filter_dims->n; // 累加深度
    cfg.M = (uint32_t)output_dims->c; // 输出深度

    cfg.lhs_row_stride = cfg.N * sizeof(int8_t); // 输入向量步长（每行N元素）
    cfg.rhs_row_stride = cfg.N * sizeof(int8_t); // kernel 行步长
    cfg.dst_row_stride = cfg.M * sizeof(int8_t); // 输出行步长

    cfg.quant_mode = DSA_QUANT_PER_CHANNEL; // per-channel 量化
    cfg.lhs_offset = fc_params->input_offset;
    cfg.rhs_offset = fc_params->filter_offset;
    cfg.dst_offset = fc_params->output_offset;
    cfg.act_min = fc_params->activation.min;
    cfg.act_max = fc_params->activation.max;

    cfg.dst_mult_ptr = quant_params->multiplier; // per-channel multiplier
    cfg.dst_shift_ptr = quant_params->shift;     // per-channel shift

    uint32_t status = dsa_matmul_execute(&cfg);
    if (status != DSA_SUCCESS) {
        return RISCV_NMSIS_NN_FAILURE;
    }

    return RISCV_NMSIS_NN_SUCCESS;
}

riscv_nmsis_nn_status riscv_fully_connected_wrapper_s8_acc(const nmsis_nn_context *ctx,
                                                   const nmsis_nn_fc_params *fc_params,
                                                   const nmsis_nn_quant_params *quant_params,
                                                   const nmsis_nn_dims *input_dims,
                                                   const int8_t *input_data,
                                                   const nmsis_nn_dims *filter_dims,
                                                   const int8_t *filter_data,
                                                   const nmsis_nn_dims *bias_dims,
                                                   const int32_t *bias_data,
                                                   const nmsis_nn_dims *output_dims,
                                                   int8_t *output_data)
{

    if (quant_params->is_per_channel)
    {
        const nmsis_nn_per_channel_quant_params per_channel_quant_params = {quant_params->multiplier,
                                                                            quant_params->shift};

        return riscv_fully_connected_per_channel_s8_acc(ctx,
                                                  fc_params,
                                                  &per_channel_quant_params,
                                                  input_dims,
                                                  input_data,
                                                  filter_dims,
                                                  filter_data,
                                                  bias_dims,
                                                  bias_data,
                                                  output_dims,
                                                  output_data);
    }
    else
    {
        const nmsis_nn_per_tensor_quant_params per_tensor_quant_params = {*quant_params->multiplier,
                                                                          *quant_params->shift};
        return riscv_fully_connected_s8_acc(ctx,
                                      fc_params,
                                      &per_tensor_quant_params,
                                      input_dims,
                                      input_data,
                                      filter_dims,
                                      filter_data,
                                      bias_dims,
                                      bias_data,
                                      output_dims,
                                      output_data);
    }
}

