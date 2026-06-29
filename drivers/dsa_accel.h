#ifndef DSA_ACCEL_H
#define DSA_ACCEL_H

#include <stddef.h>
#include <stdint.h>

/* ========== AXI-Lite MMIO 基地址 ========== */
#define DSA_MMIO_BASE 0xA0000000u

/* ========== 寄存器地址（按 word 编址） ========== */
#define DSA_REG_CTRL    0x000u
#define DSA_REG_STATUS  0x001u
#define DSA_REG_WB_DATA 0x002u
#define DSA_REG_WB_INFO 0x003u

#define DSA_CTRL_START          (1u << 0)
#define DSA_CTRL_CFG_16BITS_IA  (1u << 1)
#define DSA_CTRL_PER_CHANNEL    (1u << 2)
#define DSA_CTRL_CLEAR_DONE     (1u << 8)
#define DSA_CTRL_CLEAR_WB_VALID (1u << 9)

#define DSA_STATUS_DONE      (1u << 2)
#define DSA_STATUS_ERR_SHIFT 4u
#define DSA_STATUS_ERR_MASK  (3u << DSA_STATUS_ERR_SHIFT)

static inline void dsa_mmio_write(uint32_t addr, uint32_t data)
{
    *(volatile uint32_t *)(uintptr_t)addr = data;
}

static inline uint32_t dsa_mmio_read(uint32_t addr)
{
    return *(volatile uint32_t *)(uintptr_t)addr;
}

static inline void dsa_reg_write(uint32_t word_addr, uint32_t data)
{
    dsa_mmio_write(DSA_MMIO_BASE + (word_addr << 2), data);
}

static inline uint32_t dsa_reg_read(uint32_t word_addr)
{
    return dsa_mmio_read(DSA_MMIO_BASE + (word_addr << 2));
}

#define DSA_CSRWR(csr, val) dsa_reg_write((uint32_t)(csr), (uint32_t)(val))
#define DSA_CSRRD(csr, out_var) do { (out_var) = dsa_reg_read((uint32_t)(csr)); } while (0)

/* ========== CSR/配置寄存器地址 ========== */
#define CSR_MULT_LHS_PTR    0x7C0u
#define CSR_MULT_RHS_PTR    0x7C1u
#define CSR_MULT_DST_PTR    0x7C2u
#define CSR_MULT_BIAS_PTR   0x7C3u

#define CSR_MULT_LHS_ROWS       0x7C4u
#define CSR_MULT_RHS_COLS       0x7C5u
#define CSR_MULT_RHS_ROWS       0x7C6u
#define CSR_MULT_DST_ROW_STRIDE 0x7C7u
#define CSR_MULT_LHS_ROW_STRIDE 0x7C8u
#define CSR_MULT_RHS_COL_STRIDE 0x7C9u
#define CSR_MULT_ROW_ADDR_OFFSET CSR_MULT_DST_ROW_STRIDE
#define CSR_MULT_LHS_COLS_OFFSET CSR_MULT_LHS_ROW_STRIDE
#define CSR_MULT_RHS_ROW_STRIDE  CSR_MULT_RHS_COL_STRIDE

#define CSR_MULT_LHS_OFFSET 0x7CAu
#define CSR_MULT_RHS_OFFSET 0x7CBu
#define CSR_MULT_DST_OFFSET 0x7CCu
#define CSR_MULT_DST_MULT   0x7CDu
#define CSR_MULT_DST_SHIFT  0x7CEu
#define CSR_MULT_ACT_MIN    0x7CFu
#define CSR_MULT_ACT_MAX    0x7D0u

/* ========== 配置字位域定义 ========== */
#define CFG_OUT_W_S4   0x0
#define CFG_OUT_W_S8   0x1
#define CFG_OUT_W_S16  0x2
#define CFG_OUT_W_S32  0x3
#define CFG_OUT_W_S64  0x4

#define CFG_BIAS_W_S8  (0x0 << 3)
#define CFG_BIAS_W_S16 (0x1 << 3)
#define CFG_BIAS_W_S32 (0x2 << 3)
#define CFG_BIAS_W_S64 (0x3 << 3)

#define CFG_B_W_S4  (0x0 << 5)
#define CFG_B_W_S8  (0x1 << 5)
#define CFG_B_W_S16 (0x2 << 5)

#define CFG_A_W_S4  (0x0 << 7)
#define CFG_A_W_S8  (0x1 << 7)
#define CFG_A_W_S16 (0x2 << 7)

#define CFG_PER_TENSOR  (0x0 << 9)
#define CFG_PER_CHANNEL (0x1 << 9)

/* ========== 返回状态码 ========== */
#define DSA_SUCCESS         0x00000000u
#define DSA_ERR_NULL_PTR    0x00000002u
#define DSA_ERR_INVALID_DIM 0x00000003u

/* ========== 数据类型枚举 ========== */
typedef enum {
    DSA_DTYPE_S4 = 0,
    DSA_DTYPE_S8,
    DSA_DTYPE_S16,
    DSA_DTYPE_S32,
    DSA_DTYPE_S64
} dsa_dtype_t;

typedef enum {
    DSA_QUANT_PER_TENSOR = 0,
    DSA_QUANT_PER_CHANNEL = 1
} dsa_quant_mode_t;

/* ========== 矩阵乘法配置结构 ========== */
typedef struct {
    const void *lhs_ptr;
    const void *rhs_ptr;
    void *dst_ptr;
    const int32_t *bias_ptr;

    uint32_t K;
    uint32_t N;
    uint32_t M;

    uint32_t lhs_row_stride;
    uint32_t rhs_row_stride;
    uint32_t dst_row_stride;

    dsa_dtype_t lhs_dtype;
    dsa_dtype_t rhs_dtype;
    dsa_dtype_t bias_dtype;
    dsa_dtype_t out_dtype;

    dsa_quant_mode_t quant_mode;
    int32_t lhs_offset;
    int32_t rhs_offset;
    int32_t dst_offset;

    int32_t dst_mult;
    int32_t dst_shift;

    const int32_t *dst_mult_ptr;
    const int32_t *dst_shift_ptr;

    int32_t act_min;
    int32_t act_max;
} dsa_matmul_config_t;

/* ========== 高层API ========== */
uint32_t dsa_matmul_execute(const dsa_matmul_config_t *config);
uint32_t dsa_build_cfg_word(const dsa_matmul_config_t *config);
void dsa_matmul_config_init(dsa_matmul_config_t *config);

#endif /* DSA_ACCEL_H */
