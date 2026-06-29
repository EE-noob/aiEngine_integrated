#include "dsa_accel_mmio.h"

#define DSA_MATMUL_TIMEOUT 2000000u

uint32_t dsa_build_cfg_word(const dsa_matmul_config_t *config) {
    uint32_t cfg = 0;
    cfg |= ((uint32_t)config->out_dtype & 0x7u);
    cfg |= (((uint32_t)config->bias_dtype & 0x3u) << 3);
    cfg |= (((uint32_t)config->rhs_dtype & 0x3u) << 5);
    cfg |= (((uint32_t)config->lhs_dtype & 0x3u) << 7);
    cfg |= (((uint32_t)config->quant_mode & 0x1u) << 9);
    return cfg;
}

void dsa_matmul_config_init(dsa_matmul_config_t *config) {
    unsigned int i;
    unsigned char *bytes;

    if (config == 0) {
        return;
    }

    bytes = (unsigned char *)config;
    for (i = 0; i < sizeof(*config); i++) {
        bytes[i] = 0;
    }

    config->lhs_dtype = DSA_DTYPE_S8;
    config->rhs_dtype = DSA_DTYPE_S8;
    config->bias_dtype = DSA_DTYPE_S32;
    config->out_dtype = DSA_DTYPE_S8;
    config->quant_mode = DSA_QUANT_PER_TENSOR;
    config->act_min = -128;
    config->act_max = 127;
}

static uint32_t configure_mmio_registers(const dsa_matmul_config_t *config) {
    if ((config->lhs_ptr == 0u) || (config->rhs_ptr == 0u) || (config->dst_ptr == 0u)) {
        return DSA_ERR_NULL_PTR;
    }

    if (config->quant_mode == DSA_QUANT_PER_CHANNEL) {
        if ((config->dst_mult_ptr == 0u) || (config->dst_shift_ptr == 0u)) {
            return DSA_ERR_NULL_PTR;
        }
    }

    dsa_reg_write(CSR_MULT_LHS_PTR, config->lhs_ptr);
    dsa_reg_write(CSR_MULT_RHS_PTR, config->rhs_ptr);
    dsa_reg_write(CSR_MULT_DST_PTR, config->dst_ptr);
    dsa_reg_write(CSR_MULT_BIAS_PTR, config->bias_ptr);

    dsa_reg_write(CSR_MULT_LHS_ROWS, config->K);
    dsa_reg_write(CSR_MULT_RHS_COLS, config->N);
    dsa_reg_write(CSR_MULT_RHS_ROWS, config->M);

    dsa_reg_write(CSR_MULT_LHS_COLS_OFFSET, config->lhs_row_stride);
    dsa_reg_write(CSR_MULT_RHS_ROW_STRIDE, config->rhs_row_stride);
    dsa_reg_write(CSR_MULT_ROW_ADDR_OFFSET, config->dst_row_stride);

    dsa_reg_write(CSR_MULT_LHS_OFFSET, (uint32_t)config->lhs_offset);
    dsa_reg_write(CSR_MULT_RHS_OFFSET, (uint32_t)config->rhs_offset);
    dsa_reg_write(CSR_MULT_DST_OFFSET, (uint32_t)config->dst_offset);

    if (config->quant_mode == DSA_QUANT_PER_TENSOR) {
        dsa_reg_write(CSR_MULT_DST_MULT, (uint32_t)config->dst_mult);
        dsa_reg_write(CSR_MULT_DST_SHIFT, (uint32_t)config->dst_shift);
    } else {
        dsa_reg_write(CSR_MULT_DST_MULT, config->dst_mult_ptr);
        dsa_reg_write(CSR_MULT_DST_SHIFT, config->dst_shift_ptr);
    }

    dsa_reg_write(CSR_MULT_ACT_MIN, (uint32_t)config->act_min);
    dsa_reg_write(CSR_MULT_ACT_MAX, (uint32_t)config->act_max);

    return DSA_SUCCESS;
}

uint32_t dsa_matmul_execute(const dsa_matmul_config_t *config) {
    uint32_t status;
    uint32_t ctrl;
    uint32_t cfg_word;
    uint32_t timeout = DSA_MATMUL_TIMEOUT;

    if (config == 0) {
        return DSA_ERR_NULL_PTR;
    }

    status = configure_mmio_registers(config);
    if (status != DSA_SUCCESS) {
        return status;
    }

    cfg_word = dsa_build_cfg_word(config);
    (void)cfg_word;

    ctrl = DSA_CTRL_START | DSA_CTRL_CLEAR_DONE | DSA_CTRL_CLEAR_WB_VALID;
    if (config->lhs_dtype == DSA_DTYPE_S16) {
        ctrl |= DSA_CTRL_CFG_16BITS_IA;
    }
    if (config->quant_mode == DSA_QUANT_PER_CHANNEL) {
        ctrl |= DSA_CTRL_PER_CHANNEL;
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
    dsa_mmio_write(SOC_CTRL_BASE, status);
    while (1) {
    }
}
