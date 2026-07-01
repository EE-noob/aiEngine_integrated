#include <stdio.h>
#include <string.h>

#include "dsa_accel.h"
#include "riscv_nn_mat_mult_acc.h"
#include "riscv_nnfunctions.h"
#include "riscv_nnsupportfunctions.h"

/*
 * Accelerated s8 depthwise convolution function.
 *
 * 深度可分离卷积：每个输入通道独立卷积，产生 depth_multiplier 个输出通道
 * 卷积核布局: [1, kernel_y, kernel_x, input_ch * depth_multiplier]
 *
 * 使用 im2col + 矩阵乘法加速，每次处理一个输入通道的所有输出位置
 */
riscv_nmsis_nn_status
riscv_depthwise_conv_s8_acc(const nmsis_nn_context *ctx,
                        const nmsis_nn_dw_conv_params *dw_conv_params,
                        const nmsis_nn_per_channel_quant_params *quant_params,
                        const nmsis_nn_dims *input_dims, const int8_t *input,
                        const nmsis_nn_dims *filter_dims, const int8_t *kernel,
                        const nmsis_nn_dims *bias_dims, const int32_t *bias,
                        const nmsis_nn_dims *output_dims, int8_t *output)
{
    (void)bias_dims;

    if (ctx->buf == NULL) {
        return RISCV_NMSIS_NN_ARG_ERROR;
    }

    int8_t *buffer_a = (int8_t *)ctx->buf;

    const int32_t input_batches = input_dims->n;
    const int32_t input_x = input_dims->w;
    const int32_t input_y = input_dims->h;
    const int32_t input_ch = input_dims->c;
    const int32_t kernel_x = filter_dims->w;
    const int32_t kernel_y = filter_dims->h;
    const int32_t output_x = output_dims->w;
    const int32_t output_y = output_dims->h;
    const int32_t output_ch = output_dims->c;

    const int32_t pad_x = dw_conv_params->padding.w;
    const int32_t pad_y = dw_conv_params->padding.h;
    const int32_t stride_x = dw_conv_params->stride.w;
    const int32_t stride_y = dw_conv_params->stride.h;
    const int32_t dilation_x = dw_conv_params->dilation.w;
    const int32_t dilation_y = dw_conv_params->dilation.h;
    const int32_t out_offset = dw_conv_params->output_offset;
    const int32_t out_activation_min = dw_conv_params->activation.min;
    const int32_t out_activation_max = dw_conv_params->activation.max;
    const int32_t input_offset = dw_conv_params->input_offset;
    const int32_t depth_multiplier = dw_conv_params->ch_mult;

    const int32_t *output_mult = quant_params->multiplier;
    const int32_t *output_shift = quant_params->shift;

    // 验证输出通道数
    if (output_ch != input_ch * depth_multiplier) {
        return RISCV_NMSIS_NN_ARG_ERROR;
    }

    // 每个输入通道的卷积核大小
    const int32_t rhs_cols = kernel_x * kernel_y;
    const int32_t remainder = rhs_cols % 4;
    const int32_t aligned_rhs_cols = remainder != 0 ? rhs_cols + 4 - remainder : rhs_cols;

    // 批处理行数
    const int32_t batch_rows = 16;

    int8_t *im2col_buf_base = buffer_a;
    int8_t *kernel_pack_base = im2col_buf_base + batch_rows * aligned_rhs_cols;

    for (int i_batch = 0; i_batch < input_batches; i_batch++) {
        // 对每个输入通道进行处理
        for (int32_t i_in_ch = 0; i_in_ch < input_ch; i_in_ch++) {
            // 当前输入通道对应的输出通道起始索引
            const int32_t out_ch_start = i_in_ch * depth_multiplier;

            // 当前输入通道对应的卷积核
            // 卷积核布局: [ker_y, ker_x, out_ch] -> 对于当前输入通道，需要提取对应的列
            // 重新组织卷积核: 提取 kernel[ker_y * ker_x * output_ch + out_ch_start : out_ch_start + depth_multiplier]

            // 量化参数指针
            const int32_t *output_mult_ptr = &output_mult[out_ch_start];
            const int32_t *output_shift_ptr = &output_shift[out_ch_start];
            const int32_t *bias_ptr = bias ? &bias[out_ch_start] : NULL;

            for (int32_t i_ch_mult = 0; i_ch_mult < depth_multiplier;
                 i_ch_mult++) {
                int8_t *dst_kernel =
                    kernel_pack_base + i_ch_mult * rhs_cols;
                const int32_t out_ch = out_ch_start + i_ch_mult;
                for (int32_t i_ker_y = 0; i_ker_y < kernel_y; i_ker_y++) {
                    for (int32_t i_ker_x = 0; i_ker_x < kernel_x;
                         i_ker_x++) {
                        const int32_t k_idx =
                            (i_ker_y * kernel_x + i_ker_x) * output_ch +
                            out_ch;
                        *dst_kernel++ = kernel[k_idx];
                    }
                }
            }

            // 输出起始位置: 第一个输出位置的第 out_ch_start 个通道
            int8_t *out = output + out_ch_start;

            int32_t lhs_rows = 0;

            for (int i_out_y = 0; i_out_y < output_y; i_out_y++) {
                for (int i_out_x = 0; i_out_x < output_x; i_out_x++) {
                    const int32_t base_idx_y = stride_y * i_out_y - pad_y;
                    const int32_t base_idx_x = stride_x * i_out_x - pad_x;

                    // 当前行的 im2col 缓冲区位置
                    int8_t *current_im2col_row = im2col_buf_base + lhs_rows * aligned_rhs_cols;

                    // 执行 im2col：提取当前输入通道的卷积窗口
                    int8_t *im2col_ptr = current_im2col_row;
                    for (int32_t i_ker_y = 0; i_ker_y < kernel_y; i_ker_y++) {
                        const int32_t k_y = base_idx_y + dilation_y * i_ker_y;

                        for (int32_t i_ker_x = 0; i_ker_x < kernel_x; i_ker_x++) {
                            const int32_t k_x = base_idx_x + dilation_x * i_ker_x;

                            if (k_y < 0 || k_y >= input_y || k_x < 0 || k_x >= input_x) {
                                // 填充区域
                                *im2col_ptr = (int8_t)(-input_offset);
                            } else {
                                // 提取单个输入通道的值
                                *im2col_ptr = input[(k_y * input_x + k_x) * input_ch + i_in_ch];
                            }
                            im2col_ptr++;
                        }
                    }

                    // 填充对齐部分
                    for (int32_t i = rhs_cols; i < aligned_rhs_cols; i++) {
                        *im2col_ptr++ = 0;
                    }

                    lhs_rows++;

                    // 当批次满时，执行矩阵乘法
                    if (lhs_rows == batch_rows) {
                        // 使用 row_offset 版本处理交错输出
                        out = riscv_nn_mat_mult_kernel_row_offset_s8_acc(
                            kernel_pack_base,
                            im2col_buf_base,     // im2col 数据
                            depth_multiplier,    // 每个输入通道产生的输出通道数
                            output_shift_ptr,
                            output_mult_ptr,
                            out_offset,
                            input_offset,
                            out_activation_min,
                            out_activation_max,
                            rhs_cols,
                            aligned_rhs_cols,
                            bias_ptr,
                            output_ch,           // row_address_offset = output_ch
                            out,
                            batch_rows);

                        if (out == NULL) {
                            return RISCV_NMSIS_NN_NO_IMPL_ERROR;
                        }

                        lhs_rows = 0;
                    }
                }
            }

            // 处理剩余的行
            if (lhs_rows != 0) {
                out = riscv_nn_mat_mult_kernel_row_offset_s8_acc(
                    kernel_pack_base,
                    im2col_buf_base,
                    depth_multiplier,
                    output_shift_ptr,
                    output_mult_ptr,
                    out_offset,
                    input_offset,
                    out_activation_min,
                    out_activation_max,
                    rhs_cols,
                    aligned_rhs_cols,
                    bias_ptr,
                    output_ch,
                    out,
                    lhs_rows);

                if (out == NULL) {
                    return RISCV_NMSIS_NN_NO_IMPL_ERROR;
                }
            }
        }

        // 移动到下一个 batch
        input += (input_x * input_y * input_ch);
        output += (output_x * output_y * output_ch);
    }

    return RISCV_NMSIS_NN_SUCCESS;
}

/*
 * Get the required buffer size for riscv_depthwise_conv_s8_acc.
 */
int32_t riscv_depthwise_conv_wrapper_s8_get_buffer_size_acc(
    const nmsis_nn_dw_conv_params *dw_conv_params,
    const nmsis_nn_dims *input_dims,
    const nmsis_nn_dims *filter_dims,
    const nmsis_nn_dims *output_dims)
{
    (void)dw_conv_params;
    (void)input_dims;
    (void)output_dims;

    const int32_t rhs_cols = filter_dims->w * filter_dims->h;
    const int32_t remainder = rhs_cols % 4;
    const int32_t aligned_rhs_cols = remainder != 0 ? rhs_cols + 4 - remainder : rhs_cols;

    const int32_t depth_multiplier = dw_conv_params->ch_mult;
    const int32_t im2col_size =
        16 * aligned_rhs_cols * (int32_t)sizeof(int8_t);
    const int32_t kernel_pack_size =
        depth_multiplier * rhs_cols * (int32_t)sizeof(int8_t);
    const int32_t buffer_size = im2col_size + kernel_pack_size;

    return buffer_size;
}

/*
 * Wrapper function for depthwise convolution s8.
 */
riscv_nmsis_nn_status riscv_depthwise_conv_wrapper_s8_acc(
    const nmsis_nn_context *ctx,
    const nmsis_nn_dw_conv_params *dw_conv_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims,
    const int8_t *input,
    const nmsis_nn_dims *filter_dims,
    const int8_t *filter,
    const nmsis_nn_dims *bias_dims,
    const int32_t *bias,
    const nmsis_nn_dims *output_dims,
    int8_t *output)
{
    return riscv_depthwise_conv_s8_acc(ctx, dw_conv_params, quant_params,
                                       input_dims, input, filter_dims, filter,
                                       bias_dims, bias, output_dims, output);
}
