#include <stdio.h>
#include <string.h>

#include "dsa_accel.h"
#include "riscv_nn_mat_mult_acc.h"
#include "riscv_nnfunctions.h"
#include "riscv_nnsupportfunctions.h"

/*
 * Basic s8 convolution function with acceleration support, processing im2col in
 * batches of 16 rows.
 *
 * Refer header file for details. Optimal use case for the DSP implementation is
 * when input and output channels are multiples of 4 or atleast greater than 4.
 *
 */
riscv_nmsis_nn_status riscv_convolve_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_conv_params *conv_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input_data,
    const nmsis_nn_dims *filter_dims, const int8_t *filter_data,
    const nmsis_nn_dims *bias_dims, const int32_t *bias_data,
    const nmsis_nn_dims *upscale_dims, const nmsis_nn_dims *output_dims,
    int8_t *output_data)
{
    (void)bias_dims;

    if (ctx->buf == NULL) {
        return RISCV_NMSIS_NN_ARG_ERROR;
    }

    // 直接使用 s8 缓冲区，不再需要 s16 缓冲区
    int8_t *buffer_a = (int8_t *)ctx->buf;

    const int32_t input_batches = input_dims->n;
    const uint16_t input_x = input_dims->w;
    const uint16_t input_y = input_dims->h;
    const uint16_t input_ch = input_dims->c;
    const uint16_t kernel_x = filter_dims->w;
    const uint16_t kernel_y = filter_dims->h;
    const uint16_t kernel_ch = filter_dims->c;
    const uint16_t output_x = output_dims->w;
    const uint16_t output_y = output_dims->h;
    const uint16_t output_ch = output_dims->c;

    const uint16_t pad_x = conv_params->padding.w;
    const uint16_t pad_y = conv_params->padding.h;
    const uint16_t stride_x = conv_params->stride.w;
    const uint16_t stride_y = conv_params->stride.h;
    const int32_t dilation_x = conv_params->dilation.w;
    const int32_t dilation_y = conv_params->dilation.h;
    const int32_t out_offset = conv_params->output_offset;
    const int32_t out_activation_min = conv_params->activation.min;
    const int32_t out_activation_max = conv_params->activation.max;
    const int32_t input_offset = conv_params->input_offset;

    const int32_t groups = input_ch / kernel_ch;
    const int32_t rhs_cols = kernel_x * kernel_y * kernel_ch;
    const int32_t output_ch_per_group = output_ch / groups;

    const int32_t *output_mult = quant_params->multiplier;
    const int32_t *output_shift = quant_params->shift;

    if (input_ch % groups != 0 || output_ch % groups != 0) {
        return RISCV_NMSIS_NN_ARG_ERROR;
    }

    uint32_t y_rshift = 0;
    uint32_t x_rshift = 0;

    if (upscale_dims) {
        y_rshift = upscale_dims->h == 2 ? 1 : 0;
        x_rshift = upscale_dims->w == 2 ? 1 : 0;
    }

    const int32_t input_x_rshifted = input_x >> x_rshift;
    const int32_t input_y_rshifted = input_y >> y_rshift;

    const int32_t remainder = rhs_cols % 4;
    const int32_t aligned_rhs_cols =
        remainder != 0 ? rhs_cols + 4 - remainder : rhs_cols;

    // 批处理行数
    const int32_t batch_rows = 16;

    // im2col 缓冲区: batch_rows 行，每行 rhs_cols 个 s8 元素

    for (int i_batch = 0; i_batch < input_batches; i_batch++) {
        const int8_t *filter_data_ptr = &filter_data[0];
        const int32_t *bias_data_ptr = &bias_data[0];
        const int32_t *output_mult_ptr = &output_mult[0];
        const int32_t *output_shift_ptr = &output_shift[0];

        for (int32_t i_group = 0; i_group < groups; i_group++) {
            // 每个 group 开始时重置缓冲区指针和行计数
            int8_t *im2col_buf_ptr = buffer_a;
            int32_t lhs_rows = 0;

            int8_t *out = output_data + i_group * output_ch_per_group;

            for (int i_out_y = 0; i_out_y < output_y; i_out_y++) {
                for (int i_out_x = 0; i_out_x < output_x; i_out_x++) {
                    const int32_t base_idx_x = stride_x * i_out_x - pad_x;
                    const int32_t base_idx_y = stride_y * i_out_y - pad_y;

                    // 当前行的 im2col 缓冲区位置，按 aligned_rhs_cols 对齐
                    int8_t *current_im2col_row =
                        im2col_buf_ptr + lhs_rows * aligned_rhs_cols;

                    if (y_rshift == 1 || x_rshift == 1) {
                        riscv_memset_s8(
                            current_im2col_row, (int8_t)-input_offset,
                            sizeof(int8_t) * kernel_ch * kernel_x * kernel_y);
                        int8_t *im2col_ptr = current_im2col_row;
                        for (int32_t i_ker_y = 0; i_ker_y < kernel_y;
                             i_ker_y++) {
                            const int32_t k_y =
                                base_idx_y + dilation_y * i_ker_y;

                            if ((k_y < 0 || k_y >= input_y) ||
                                (k_y % 2 && y_rshift == 1)) {
                                im2col_ptr += kernel_ch * kernel_x;
                            } else {
                                const int32_t k_y_rshifted = k_y >> y_rshift;
                                for (int32_t i_ker_x = 0; i_ker_x < kernel_x;
                                     i_ker_x++) {
                                    const int32_t k_x =
                                        base_idx_x + dilation_x * i_ker_x;

                                    if ((k_x >= 0 && k_x < input_x) &&
                                        ((k_x % 2 == 0) || x_rshift == 0)) {
                                        const int32_t k_x_rshifted =
                                            k_x >> x_rshift;
                                        riscv_memcpy_s8_asm_unroll4(
                                            im2col_ptr,
                                            input_data +
                                                (k_y_rshifted *
                                                     input_x_rshifted +
                                                 k_x_rshifted) *
                                                    input_ch +
                                                i_group * kernel_ch,
                                            sizeof(int8_t) * kernel_ch);
                                    }
                                    im2col_ptr += kernel_ch;
                                }
                            }
                        }
                    } else {
                        int8_t *im2col_ptr = current_im2col_row;
                        for (int32_t i_ker_y = 0; i_ker_y < kernel_y;
                             i_ker_y++) {
                            for (int32_t i_ker_x = 0; i_ker_x < kernel_x;
                                 i_ker_x++) {
                                const int32_t k_y =
                                    base_idx_y + dilation_y * i_ker_y;
                                const int32_t k_x =
                                    base_idx_x + dilation_x * i_ker_x;

                                if (k_y < 0 || k_y >= input_y || k_x < 0 ||
                                    k_x >= input_x) {
                                    riscv_memset_s8(im2col_ptr,
                                                    (int8_t)-input_offset,
                                                    sizeof(int8_t) * kernel_ch);
                                } else {
                                    riscv_memcpy_s8_asm_unroll4(im2col_ptr,
                                                    input_data +
                                                        (k_y * input_x + k_x) *
                                                            input_ch +
                                                        i_group * kernel_ch,
                                                    sizeof(int8_t) * kernel_ch);
                                }
                                im2col_ptr += kernel_ch;
                            }
                        }
                    }

                    lhs_rows++;

                    if (lhs_rows == batch_rows) {
                        if (groups > 1) {
                            out = riscv_nn_mat_mult_kernel_row_offset_s8_acc(
                                filter_data_ptr, im2col_buf_ptr,
                                output_ch_per_group, output_shift_ptr,
                                output_mult_ptr, out_offset, input_offset,
                                out_activation_min, out_activation_max,
                                rhs_cols, aligned_rhs_cols, bias_data_ptr,
                                output_ch, out, batch_rows);
                        } else {
                            out = riscv_nn_mat_mult_kernel_s8_acc(
                                filter_data_ptr, im2col_buf_ptr,
                                output_ch_per_group, output_shift_ptr,
                                output_mult_ptr, out_offset, input_offset,
                                out_activation_min, out_activation_max,
                                rhs_cols, aligned_rhs_cols, bias_data_ptr, out,
                                batch_rows);
                        }

                        lhs_rows = 0;
                    }
                }
            }

            if (out == NULL) {
                return RISCV_NMSIS_NN_NO_IMPL_ERROR;
            }

            /* Handle left over columns */
            if (lhs_rows != 0) {
                if (groups > 1) {
                    out = riscv_nn_mat_mult_kernel_row_offset_s8_acc(
                        filter_data_ptr, im2col_buf_ptr, output_ch_per_group,
                        output_shift_ptr, output_mult_ptr, out_offset,
                        input_offset, out_activation_min, out_activation_max,
                        rhs_cols, aligned_rhs_cols, bias_data_ptr, output_ch,
                        out, lhs_rows);
                } else {
                    out = riscv_nn_mat_mult_kernel_s8_acc(
                        filter_data_ptr, im2col_buf_ptr, output_ch_per_group,
                        output_shift_ptr, output_mult_ptr, out_offset,
                        input_offset, out_activation_min, out_activation_max,
                        rhs_cols, aligned_rhs_cols, bias_data_ptr, out,
                        lhs_rows);
                }
            }

            filter_data_ptr += output_ch_per_group * rhs_cols;
            bias_data_ptr += output_ch_per_group;
            output_mult_ptr += output_ch_per_group;
            output_shift_ptr += output_ch_per_group;
        }
        /* Advance to the next batch */
        input_data += (input_x_rshifted * input_y_rshifted * input_ch);
        output_data += (output_x * output_y * output_ch);
    }

    /* Return to application */
    return RISCV_NMSIS_NN_SUCCESS;
}

/*
 * Accelerated s8 1x1 convolution function with no padding and stride of 1.
 */
riscv_nmsis_nn_status riscv_convolve_1x1_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_conv_params *conv_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input_data,
    const nmsis_nn_dims *filter_dims, const int8_t *filter_data,
    const nmsis_nn_dims *bias_dims, const int32_t *bias_data,
    const nmsis_nn_dims *output_dims, int8_t *output_data)
{
    (void)ctx;
    (void)filter_dims;
    (void)bias_dims;
    if (conv_params->padding.w != 0 || conv_params->padding.h != 0) {
        return RISCV_NMSIS_NN_ARG_ERROR;
    }

    const int32_t lhs_rows = output_dims->w;
    const int32_t rhs_rows = output_dims->c;
    const int32_t rhs_cols = input_dims->c;
    const int32_t stride_w = conv_params->stride.w;
    const int32_t input_inc = input_dims->w * conv_params->stride.h * rhs_cols;
    const int32_t output_inc = output_dims->w * rhs_rows;
    const int32_t output_h = output_dims->h;
    const int32_t batch = input_dims->n;
    const int8_t *input_data_ref = input_data;

    for (int i_batch = 0; i_batch < batch; i_batch++) {
        input_data = input_data_ref +
                     (i_batch * rhs_cols * input_dims->w * input_dims->h);
        for (int i_output_h = 0; i_output_h < output_h; i_output_h++) {
            // Process one input row
            riscv_nmsis_nn_status result = riscv_nn_mat_mult_nt_t_s8_acc(
                input_data, filter_data, bias_data, output_data,
                quant_params->multiplier, quant_params->shift, lhs_rows,
                rhs_rows, rhs_cols, conv_params->input_offset,
                conv_params->output_offset, conv_params->activation.min,
                conv_params->activation.max, rhs_rows, rhs_cols * stride_w);
            if (result != RISCV_NMSIS_NN_SUCCESS) {
                return result;
            }
            input_data += input_inc;
            output_data += output_inc;
        }
    }

    /* Return to application */
    return RISCV_NMSIS_NN_SUCCESS;
}

/*
 * Fast s8 version for 1x1 convolution (non-square shape)
 *
 * Refer header file for details.
 *
 */
riscv_nmsis_nn_status riscv_convolve_1x1_s8_fast_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_conv_params *conv_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input_data,
    const nmsis_nn_dims *filter_dims, const int8_t *filter_data,
    const nmsis_nn_dims *bias_dims, const int32_t *bias_data,
    const nmsis_nn_dims *output_dims, int8_t *output_data)
{
    if (conv_params->padding.w != 0 || conv_params->padding.h != 0 ||
        conv_params->stride.w != 1 || conv_params->stride.h != 1) {
        return RISCV_NMSIS_NN_ARG_ERROR;
    }

    (void)filter_dims;
    (void)bias_dims;

    const int32_t rhs_cols = input_dims->c;
    const int32_t rhs_rows = output_dims->c;
    int32_t lhs_rows = input_dims->w * input_dims->h * input_dims->n;

    (void)ctx;

    riscv_nn_mat_mult_nt_t_s8_acc(
        input_data, filter_data, bias_data, output_data,
        quant_params->multiplier, quant_params->shift, lhs_rows, rhs_rows,
        rhs_cols, conv_params->input_offset, conv_params->output_offset,
        conv_params->activation.min, conv_params->activation.max, rhs_rows,
        rhs_cols);

    /* Return to application */
    return RISCV_NMSIS_NN_SUCCESS;
}

/**
 * @} end of NNConv group
 */

int32_t riscv_convolve_s8_get_buffer_size_acc(const nmsis_nn_dims *input_dims,
                                              const nmsis_nn_dims *filter_dims)
{
    const int32_t rhs_cols = filter_dims->w * filter_dims->h * input_dims->c;
    const int32_t remainder = rhs_cols % 4;
    const int32_t aligned_rhs_cols =
        remainder != 0 ? rhs_cols + 4 - remainder : rhs_cols;

    // s8 缓冲区: 16 行 × aligned_rhs_cols 个 int8_t（保持对齐）
    const int32_t s8_buffer_size =
        (16 * aligned_rhs_cols) * (int32_t)sizeof(int8_t);

    return s8_buffer_size;
}

/*
 * Get the required buffer size for riscv_convolve_wrapper_s8. This is the
 * recommended function convolve wrapper s8 function.
 *
 * Refer to header file for details.
 *
 */
int32_t riscv_convolve_wrapper_s8_get_buffer_size_acc(
    const nmsis_nn_conv_params *conv_params, const nmsis_nn_dims *input_dims,
    const nmsis_nn_dims *filter_dims, const nmsis_nn_dims *output_dims)
{
#if defined(RISCV_MATH_DSP)
    return riscv_convolve_wrapper_s8_get_buffer_size_dsp(
        conv_params, input_dims, filter_dims, output_dims);
#else
    (void)output_dims;
    if ((conv_params->padding.w == 0) && (conv_params->padding.h == 0) &&
        (filter_dims->w == 1) && (filter_dims->h == 1) &&
        (conv_params->dilation.w == 1 && conv_params->dilation.h == 1)) {
        // 1x1 卷积统一使用加速版本，需要的缓冲区大小为 0
        return 0;
    } else {
        return riscv_convolve_s8_get_buffer_size_acc(input_dims, filter_dims);
    }
#endif
}

riscv_nmsis_nn_status riscv_convolve_wrapper_s8_acc(
    const nmsis_nn_context *ctx, const nmsis_nn_conv_params *conv_params,
    const nmsis_nn_per_channel_quant_params *quant_params,
    const nmsis_nn_dims *input_dims, const int8_t *input_data,
    const nmsis_nn_dims *filter_dims, const int8_t *filter_data,
    const nmsis_nn_dims *bias_dims, const int32_t *bias_data,
    const nmsis_nn_dims *output_dims, int8_t *output_data)
{
    if ((conv_params->padding.w == 0) && (conv_params->padding.h == 0) &&
        (filter_dims->w == 1) && (filter_dims->h == 1) &&
        (conv_params->dilation.w == 1 && conv_params->dilation.h == 1) &&
        (input_dims->c == filter_dims->c)) {
        // 所有 1x1 卷积统一使用加速版本
        return riscv_convolve_1x1_s8_acc(
            ctx, conv_params, quant_params, input_dims, input_data, filter_dims,
            filter_data, bias_dims, bias_data, output_dims, output_data);
    } else {
        // 其他卷积使用通用加速版本
        return riscv_convolve_s8_acc(
            ctx, conv_params, quant_params, input_dims, input_data, filter_dims,
            filter_data, bias_dims, bias_data, NULL, output_dims, output_data);
    }
}