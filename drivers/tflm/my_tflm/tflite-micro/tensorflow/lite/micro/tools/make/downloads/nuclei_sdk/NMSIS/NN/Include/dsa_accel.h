#ifndef DSA_ACCEL_H
#define DSA_ACCEL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

/* axi_soc maps the accelerator AXI-Lite window at 0x1000_0000. */
#define DSA_MMIO_BASE 0x10000000u

#define NPU_REG_CTRL         0x000u
#define NPU_REG_STATUS       0x004u
#define NPU_REG_WB_DATA      0x008u
#define NPU_REG_LHS_BASE     0x010u
#define NPU_REG_RHS_BASE     0x014u
#define NPU_REG_DST_BASE     0x018u
#define NPU_REG_BIAS_BASE    0x01Cu
#define NPU_REG_K            0x020u
#define NPU_REG_N            0x024u
#define NPU_REG_M            0x028u
#define NPU_REG_LHS_STRIDE_B 0x02Cu
#define NPU_REG_RHS_STRIDE_B 0x030u
#define NPU_REG_DST_STRIDE_B 0x034u
#define NPU_REG_LHS_ZP       0x038u
#define NPU_REG_RHS_ZP       0x03Cu
#define NPU_REG_DST_ZP       0x040u
#define NPU_REG_Q_MULT       0x044u
#define NPU_REG_Q_SHIFT      0x048u
#define NPU_REG_ACT_MIN      0x04Cu
#define NPU_REG_ACT_MAX      0x050u
#define NPU_REG_IA_REUSE     0x054u
#define NPU_REG_W_REUSE      0x058u
#define NPU_REG_DATAFLOW     0x05Cu
#define NPU_REG_ROW_GROUPS       0x060u
#define NPU_REG_ROW_TAIL_TILES   0x064u
#define NPU_REG_COL_GROUPS       0x068u
#define NPU_REG_COL_TAIL_TILES   0x06Cu
#define NPU_REG_ID           0x0FCu

#define DSA_REG_CTRL     NPU_REG_CTRL
#define DSA_REG_STATUS   NPU_REG_STATUS
#define DSA_REG_WB_DATA  NPU_REG_WB_DATA
#define DSA_REG_IA_REUSE NPU_REG_IA_REUSE
#define DSA_REG_W_REUSE  NPU_REG_W_REUSE

#define DSA_CTRL_START          (1u << 0)
#define DSA_CTRL_CFG_16BITS_IA  (1u << 1)
#define DSA_CTRL_PER_CHANNEL    (1u << 2)
#define DSA_CTRL_DATAFLOW_IS    (1u << 3)
#define DSA_CTRL_IRQ_ENABLE     (1u << 4)
#define DSA_CTRL_CFG_16X8       (1u << 5)

#define DSA_STATUS_DONE      (1u << 2)
#define DSA_STATUS_ERR_SHIFT 3u
#define DSA_STATUS_ERR_MASK  (3u << DSA_STATUS_ERR_SHIFT)

#ifndef DSA_TILE_SIZE
#define DSA_TILE_SIZE 16u
#endif

#ifndef DSA_IA_CACHE_BLOCKS
#define DSA_IA_CACHE_BLOCKS 4u
#endif

#ifndef DSA_PS_FRAME_COUNT
#define DSA_PS_FRAME_COUNT DSA_TILE_SIZE
#endif

static inline void dsa_mmio_write(uint32_t addr, uint32_t data)
{
    *(volatile uint32_t *)(uintptr_t)addr = data;
}

static inline uint32_t dsa_mmio_read(uint32_t addr)
{
    return *(volatile uint32_t *)(uintptr_t)addr;
}

static inline void dsa_reg_write(uint32_t byte_offset, uint32_t data)
{
    dsa_mmio_write(DSA_MMIO_BASE + byte_offset, data);
}

static inline uint32_t dsa_reg_read(uint32_t byte_offset)
{
    return dsa_mmio_read(DSA_MMIO_BASE + byte_offset);
}

#define DSA_CSRWR(csr, val) \
    dsa_reg_write((uint32_t)(csr), (uint32_t)(val))
#define DSA_CSRRD(csr, out_var) \
    do { (out_var) = dsa_reg_read((uint32_t)(csr)); } while (0)

/* Compatibility aliases for old ExtraAccFunctions call sites. */
#define CSR_MULT_LHS_PTR  NPU_REG_LHS_BASE
#define CSR_MULT_RHS_PTR  NPU_REG_RHS_BASE
#define CSR_MULT_DST_PTR  NPU_REG_DST_BASE
#define CSR_MULT_BIAS_PTR NPU_REG_BIAS_BASE

#define CSR_MULT_LHS_ROWS       NPU_REG_K
#define CSR_MULT_RHS_COLS       NPU_REG_N
#define CSR_MULT_RHS_ROWS       NPU_REG_M
#define CSR_MULT_DST_ROW_STRIDE NPU_REG_DST_STRIDE_B
#define CSR_MULT_LHS_ROW_STRIDE NPU_REG_LHS_STRIDE_B
#define CSR_MULT_RHS_COL_STRIDE NPU_REG_RHS_STRIDE_B
#define CSR_MULT_ROW_ADDR_OFFSET CSR_MULT_DST_ROW_STRIDE
#define CSR_MULT_LHS_COLS_OFFSET CSR_MULT_LHS_ROW_STRIDE
#define CSR_MULT_RHS_ROW_STRIDE  CSR_MULT_RHS_COL_STRIDE

#define CSR_MULT_LHS_OFFSET NPU_REG_LHS_ZP
#define CSR_MULT_RHS_OFFSET NPU_REG_RHS_ZP
#define CSR_MULT_DST_OFFSET NPU_REG_DST_ZP
#define CSR_MULT_DST_MULT   NPU_REG_Q_MULT
#define CSR_MULT_DST_SHIFT  NPU_REG_Q_SHIFT
#define CSR_MULT_ACT_MIN    NPU_REG_ACT_MIN
#define CSR_MULT_ACT_MAX    NPU_REG_ACT_MAX
#define CSR_MULT_IA_REUSE   NPU_REG_IA_REUSE
#define CSR_MULT_W_REUSE    NPU_REG_W_REUSE

#define CFG_OUT_W_S4  0x0u
#define CFG_OUT_W_S8  0x1u
#define CFG_OUT_W_S16 0x2u
#define CFG_OUT_W_S32 0x3u
#define CFG_OUT_W_S64 0x4u

#define CFG_BIAS_W_S8  (0x0u << 3)
#define CFG_BIAS_W_S16 (0x1u << 3)
#define CFG_BIAS_W_S32 (0x2u << 3)
#define CFG_BIAS_W_S64 (0x3u << 3)

#define CFG_B_W_S4  (0x0u << 5)
#define CFG_B_W_S8  (0x1u << 5)
#define CFG_B_W_S16 (0x2u << 5)

#define CFG_A_W_S4  (0x0u << 7)
#define CFG_A_W_S8  (0x1u << 7)
#define CFG_A_W_S16 (0x2u << 7)

#define CFG_PER_TENSOR  (0x0u << 9)
#define CFG_PER_CHANNEL (0x1u << 9)

#define DSA_SUCCESS         0x00000000u
#define DSA_ERR_NULL_PTR    0x00000002u
#define DSA_ERR_INVALID_DIM 0x00000003u

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

typedef enum {
    DSA_DATAFLOW_WS = 0,
    DSA_DATAFLOW_IS = 1
} dsa_dataflow_mode_t;

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
    uint32_t n_aligned;

    dsa_dtype_t lhs_dtype;
    dsa_dtype_t rhs_dtype;
    dsa_dtype_t bias_dtype;
    dsa_dtype_t out_dtype;
    dsa_dataflow_mode_t dataflow_mode;

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

    uint32_t ia_reuse_num;
    uint32_t w_reuse_num;
} dsa_matmul_config_t;

uint32_t dsa_matmul_execute(const dsa_matmul_config_t *config);
uint32_t dsa_build_cfg_word(const dsa_matmul_config_t *config);
void dsa_matmul_config_init(dsa_matmul_config_t *config);
void dsa_matmul_select_reuse(uint32_t K, uint32_t N, uint32_t M,
                             uint32_t ia_cache_blocks,
                             dsa_dataflow_mode_t dataflow_mode,
                             uint32_t *ia_reuse_num,
                             uint32_t *w_reuse_num);

static inline void dsa_matmul_set_strides(dsa_matmul_config_t *cfg,
                                          uint32_t lhs_elem_size,
                                          uint32_t rhs_row_elems,
                                          uint32_t dst_row_elems)
{
    cfg->lhs_row_stride = cfg->N * lhs_elem_size;
    cfg->rhs_row_stride = rhs_row_elems * (uint32_t)sizeof(int8_t);
    cfg->dst_row_stride = dst_row_elems * (uint32_t)sizeof(int8_t);
}

#ifdef __cplusplus
}
#endif

#endif /* DSA_ACCEL_H */
