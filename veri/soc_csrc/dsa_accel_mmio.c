#include "dsa_accel_mmio.h"

static inline void mmio_write(uint32_t addr, uint32_t data) {
    *(volatile uint32_t *)addr = data;
}

static inline uint32_t mmio_read(uint32_t addr) {
    return *(volatile uint32_t *)addr;
}

static inline void dsa_reg_write(uint32_t word_addr, uint32_t data) {
    mmio_write(DSA_MMIO_BASE + (word_addr << 2), data);
}

static inline uint32_t dsa_reg_read(uint32_t word_addr) {
    return mmio_read(DSA_MMIO_BASE + (word_addr << 2));
}

uint32_t dsa_build_cfg_word(const dsa_matmul_config_t *config) {
    uint32_t cfg = 0;
    cfg |= (config->out_dtype & 0x7u);
    cfg |= ((config->bias_dtype & 0x3u) << 3);
    cfg |= ((config->rhs_dtype & 0x3u) << 5);
    cfg |= ((config->lhs_dtype & 0x3u) << 7);
    cfg |= ((config->quant_mode & 0x1u) << 9);
    return cfg;
}

uint32_t dsa_matmul_execute(const dsa_matmul_config_t *config) {
    uint32_t status;
    uint32_t ctrl;
    uint32_t timeout = 2000000u;

    dsa_reg_write(CSR_MULT_LHS_PTR, config->lhs_ptr);
    dsa_reg_write(CSR_MULT_RHS_PTR, config->rhs_ptr);
    dsa_reg_write(CSR_MULT_DST_PTR, config->dst_ptr);
    dsa_reg_write(CSR_MULT_BIAS_PTR, config->bias_ptr);
    dsa_reg_write(CSR_MULT_LHS_ROWS, config->K);
    dsa_reg_write(CSR_MULT_RHS_COLS, config->N);
    dsa_reg_write(CSR_MULT_RHS_ROWS, config->M);
    dsa_reg_write(CSR_MULT_DST_ROW_STRIDE, config->dst_row_stride);
    dsa_reg_write(CSR_MULT_LHS_ROW_STRIDE, config->lhs_row_stride);
    dsa_reg_write(CSR_MULT_RHS_COL_STRIDE, config->rhs_row_stride);
    dsa_reg_write(CSR_MULT_LHS_OFFSET, (uint32_t)config->lhs_offset);
    dsa_reg_write(CSR_MULT_RHS_OFFSET, (uint32_t)config->rhs_offset);
    dsa_reg_write(CSR_MULT_DST_OFFSET, (uint32_t)config->dst_offset);

    if (config->quant_mode == DSA_QUANT_PER_CHANNEL) {
        dsa_reg_write(CSR_MULT_DST_MULT, config->dst_mult_ptr);
        dsa_reg_write(CSR_MULT_DST_SHIFT, config->dst_shift_ptr);
    } else {
        dsa_reg_write(CSR_MULT_DST_MULT, (uint32_t)config->dst_mult);
        dsa_reg_write(CSR_MULT_DST_SHIFT, (uint32_t)config->dst_shift);
    }

    dsa_reg_write(CSR_MULT_ACT_MIN, (uint32_t)config->act_min);
    dsa_reg_write(CSR_MULT_ACT_MAX, (uint32_t)config->act_max);

    ctrl = 1u;
    if (config->lhs_dtype == DSA_DTYPE_S16) {
        ctrl |= (1u << 1);
    }
    if (config->quant_mode == DSA_QUANT_PER_CHANNEL) {
        ctrl |= (1u << 2);
    }

    dsa_reg_write(DSA_REG_CTRL, ctrl);

    do {
        status = dsa_reg_read(DSA_REG_STATUS);
        if (status & DSA_STATUS_DONE) {
            break;
        }
    } while (--timeout != 0u);

    if (timeout == 0u) {
        return 0x80000001u;
    }

    if (status & DSA_STATUS_ERR_MASK) {
        return (status & DSA_STATUS_ERR_MASK) >> DSA_STATUS_ERR_SHIFT;
    }

    return dsa_reg_read(DSA_REG_WB_DATA);
}

void soc_finish(uint32_t status) {
    mmio_write(SOC_CTRL_BASE, status);
    while (1) {
    }
}
