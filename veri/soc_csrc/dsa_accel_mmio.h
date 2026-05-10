#ifndef DSA_ACCEL_MMIO_H
#define DSA_ACCEL_MMIO_H

#include <stdint.h>

#define DSA_MMIO_BASE 0x10000000u
#define SOC_CTRL_BASE 0x20000000u

#define DSA_SUCCESS 0x00000000u

#define DSA_DTYPE_S4  0u
#define DSA_DTYPE_S8  1u
#define DSA_DTYPE_S16 2u
#define DSA_DTYPE_S32 3u
#define DSA_DTYPE_S64 4u

#define DSA_QUANT_PER_TENSOR  0u
#define DSA_QUANT_PER_CHANNEL 1u

#define CSR_MULT_LHS_PTR        0x7C0u
#define CSR_MULT_RHS_PTR        0x7C1u
#define CSR_MULT_DST_PTR        0x7C2u
#define CSR_MULT_BIAS_PTR       0x7C3u
#define CSR_MULT_LHS_ROWS       0x7C4u
#define CSR_MULT_RHS_COLS       0x7C5u
#define CSR_MULT_RHS_ROWS       0x7C6u
#define CSR_MULT_DST_ROW_STRIDE 0x7C7u
#define CSR_MULT_LHS_ROW_STRIDE 0x7C8u
#define CSR_MULT_RHS_COL_STRIDE 0x7C9u
#define CSR_MULT_LHS_OFFSET     0x7CAu
#define CSR_MULT_RHS_OFFSET     0x7CBu
#define CSR_MULT_DST_OFFSET     0x7CCu
#define CSR_MULT_DST_MULT       0x7CDu
#define CSR_MULT_DST_SHIFT      0x7CEu
#define CSR_MULT_ACT_MIN        0x7CFu
#define CSR_MULT_ACT_MAX        0x7D0u

#define DSA_REG_CTRL            0x000u
#define DSA_REG_STATUS          0x001u
#define DSA_REG_WB_DATA         0x002u

#define DSA_STATUS_DONE         (1u << 2)
#define DSA_STATUS_ERR_SHIFT    4
#define DSA_STATUS_ERR_MASK     (3u << DSA_STATUS_ERR_SHIFT)

#define SOC_STATUS_PASS         1u
#define SOC_STATUS_FAIL         2u

typedef struct {
    uint32_t lhs_ptr;
    uint32_t rhs_ptr;
    uint32_t dst_ptr;
    uint32_t bias_ptr;
    uint32_t K;
    uint32_t N;
    uint32_t M;
    uint32_t lhs_row_stride;
    uint32_t rhs_row_stride;
    uint32_t dst_row_stride;
    uint32_t lhs_dtype;
    uint32_t rhs_dtype;
    uint32_t bias_dtype;
    uint32_t out_dtype;
    uint32_t quant_mode;
    int32_t lhs_offset;
    int32_t rhs_offset;
    int32_t dst_offset;
    int32_t dst_mult;
    int32_t dst_shift;
    uint32_t dst_mult_ptr;
    uint32_t dst_shift_ptr;
    int32_t act_min;
    int32_t act_max;
} dsa_matmul_config_t;

uint32_t dsa_build_cfg_word(const dsa_matmul_config_t *config);
uint32_t dsa_matmul_execute(const dsa_matmul_config_t *config);
void soc_finish(uint32_t status);

#endif
