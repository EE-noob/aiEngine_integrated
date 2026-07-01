#include "dsa_accel.h"

#define DSA_MATMUL_TIMEOUT 2000000u

static uint32_t ceil_div_u32(uint32_t a, uint32_t b) {
    return (b == 0u) ? 0u : ((a + b - 1u) / b);
}

static uint32_t min_u32(uint32_t a, uint32_t b) {
    return (a < b) ? a : b;
}

static uint32_t max_u32(uint32_t a, uint32_t b) {
    return (a > b) ? a : b;
}

static uint32_t floor_pow2_u32(uint32_t value) {
    uint32_t out = 1u;
    while ((out << 1) != 0u && (out << 1) <= value) {
        out <<= 1;
    }
    return out;
}

static uint32_t sat_mul_u32(uint32_t a, uint32_t b) {
    if ((a != 0u) && (b > (0xffffffffu / a))) {
        return 0xffffffffu;
    }
    return a * b;
}

static void dsa_memory_barrier(void) {
#if defined(__riscv)
    __asm__ volatile ("fence rw, rw" ::: "memory");
#else
    __asm__ volatile ("" ::: "memory");
#endif
}

static uint32_t eval_reuse_time(uint32_t x_int, uint32_t y_int,
                                uint32_t z_int, uint32_t a,
                                uint32_t b) {
    uint32_t xyz;
    uint32_t total_blocks;
    uint32_t mem_t0;
    uint32_t comp_t0;
    uint32_t p;
    uint32_t l;
    uint32_t term;
    uint32_t factor1;
    uint32_t b_reuse;
    uint32_t mem_t1;
    uint32_t comp_factor;
    uint32_t comp_save;
    uint32_t comp_t1;

    if ((x_int == 0u) || (y_int == 0u) || (z_int == 0u) ||
        (a == 0u) || (b == 0u)) {
        return 0xffffffffu;
    }

    xyz = sat_mul_u32(sat_mul_u32(x_int, y_int), z_int);
    total_blocks = sat_mul_u32(2u, xyz);
    mem_t0 = sat_mul_u32(64u, total_blocks);
    comp_t0 = sat_mul_u32(47u, xyz);
    (void)mem_t0;

    p = ceil_div_u32(x_int, a);
    l = ceil_div_u32(y_int, b);
    term = sat_mul_u32(sat_mul_u32(p, l), z_int);

    factor1 = sat_mul_u32(2u, sat_mul_u32(a, b)) - (a + b);
    b_reuse = sat_mul_u32(term, factor1);
    if (b_reuse > total_blocks) {
        b_reuse = total_blocks;
    }
    mem_t1 = sat_mul_u32(64u, total_blocks - b_reuse);

    comp_factor = sat_mul_u32(a - 1u, sat_mul_u32(31u, b) - 15u);
    comp_save = sat_mul_u32(term, comp_factor);
    comp_save += sat_mul_u32(sat_mul_u32(15u, a - 1u), (l > 0u) ? (l - 1u) : 0u);
    comp_t1 = (comp_t0 > comp_save) ? (comp_t0 - comp_save) : 0u;

    return max_u32(mem_t1, comp_t1);
}

static void dsa_matmul_legalize_reuse(uint32_t K, uint32_t M,
                                      uint32_t ia_cache_blocks,
                                      dsa_dataflow_mode_t dataflow_mode,
                                      uint32_t *ia_reuse_num,
                                      uint32_t *w_reuse_num) {
    uint32_t stream_m;
    uint32_t stream_k;
    uint32_t output_row_tiles;
    uint32_t output_col_tiles;
    uint32_t ia_limit;
    uint32_t w_limit;

    if ((ia_reuse_num == 0) || (w_reuse_num == 0)) {
        return;
    }

    if (ia_cache_blocks == 0u) {
        ia_cache_blocks = DSA_IA_CACHE_BLOCKS;
    }

    stream_k = (dataflow_mode == DSA_DATAFLOW_IS) ? M : K;
    stream_m = (dataflow_mode == DSA_DATAFLOW_IS) ? K : M;
    output_row_tiles = max_u32(1u, ceil_div_u32(stream_k, DSA_TILE_SIZE));
    output_col_tiles = max_u32(1u, ceil_div_u32(stream_m, DSA_TILE_SIZE));
    ia_limit = (ia_cache_blocks < 2u) ? 1u : (ia_cache_blocks / 2u);
    ia_limit = floor_pow2_u32(min_u32(output_row_tiles, max_u32(1u, ia_limit)));
    w_limit = max_u32(1u, DSA_PS_FRAME_COUNT);
    w_limit = floor_pow2_u32(min_u32(output_col_tiles, w_limit));
    if (dataflow_mode == DSA_DATAFLOW_IS) {
        ia_limit = min_u32(ia_limit, w_limit);
    }

    if (*ia_reuse_num != 0u) {
        *ia_reuse_num = floor_pow2_u32(min_u32(*ia_reuse_num, ia_limit));
    }
    if (*w_reuse_num != 0u) {
        *w_reuse_num = floor_pow2_u32(min_u32(*w_reuse_num, w_limit));
    }
    if ((dataflow_mode == DSA_DATAFLOW_IS) &&
        (*ia_reuse_num != 0u) && (*w_reuse_num != 0u) &&
        (*w_reuse_num < *ia_reuse_num) &&
        (output_col_tiles >= *ia_reuse_num)) {
        *w_reuse_num = *ia_reuse_num;
    }
}

void dsa_matmul_select_reuse(uint32_t K, uint32_t N, uint32_t M,
                             uint32_t ia_cache_blocks,
                             dsa_dataflow_mode_t dataflow_mode,
                             uint32_t *ia_reuse_num,
                             uint32_t *w_reuse_num) {
    uint32_t stream_cols;
    uint32_t stream_rows;
    uint32_t output_row_tiles;
    uint32_t output_col_tiles;
    uint32_t ia_limit;
    uint32_t w_limit;

    if ((ia_reuse_num == 0) || (w_reuse_num == 0)) {
        return;
    }

    if ((K == 0u) || (N == 0u) || (M == 0u)) {
        *ia_reuse_num = 1u;
        *w_reuse_num = 1u;
        return;
    }

    if (ia_cache_blocks == 0u) {
        ia_cache_blocks = DSA_IA_CACHE_BLOCKS;
    }

    stream_rows = (dataflow_mode == DSA_DATAFLOW_IS) ? M : K;
    stream_cols = (dataflow_mode == DSA_DATAFLOW_IS) ? K : M;
    output_row_tiles = max_u32(1u, ceil_div_u32(stream_rows, DSA_TILE_SIZE));
    output_col_tiles = max_u32(1u, ceil_div_u32(stream_cols, DSA_TILE_SIZE));
    ia_limit = (ia_cache_blocks < 2u) ? 1u : (ia_cache_blocks / 2u);
    ia_limit = floor_pow2_u32(min_u32(output_row_tiles, max_u32(1u, ia_limit)));
    w_limit = max_u32(1u, DSA_PS_FRAME_COUNT);
    w_limit = floor_pow2_u32(min_u32(output_col_tiles, w_limit));
    if (dataflow_mode == DSA_DATAFLOW_IS) {
        ia_limit = min_u32(ia_limit, w_limit);
    }

    (void)N;
    *ia_reuse_num = ia_limit;
    *w_reuse_num = w_limit;
    dsa_matmul_legalize_reuse(K, M, ia_cache_blocks, dataflow_mode,
                              ia_reuse_num, w_reuse_num);
}

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
    config->dataflow_mode = DSA_DATAFLOW_WS;
    config->quant_mode = DSA_QUANT_PER_TENSOR;
    config->act_min = -128;
    config->act_max = 127;
}

static uint32_t configure_mmio_registers(const dsa_matmul_config_t *config,
                                         uint32_t ia_reuse_num,
                                         uint32_t w_reuse_num) {
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
    dsa_reg_write(DSA_REG_IA_REUSE, ia_reuse_num);
    dsa_reg_write(DSA_REG_W_REUSE, w_reuse_num);

    return DSA_SUCCESS;
}

uint32_t dsa_matmul_execute(const dsa_matmul_config_t *config) {
    uint32_t status;
    uint32_t ctrl;
    uint32_t cfg_word;
    uint32_t timeout = DSA_MATMUL_TIMEOUT;
    uint32_t ia_reuse_num;
    uint32_t w_reuse_num;

    if (config == 0) {
        return DSA_ERR_NULL_PTR;
    }

    ia_reuse_num = config->ia_reuse_num;
    w_reuse_num = config->w_reuse_num;
    dsa_matmul_legalize_reuse(config->K, config->M, DSA_IA_CACHE_BLOCKS,
                              config->dataflow_mode,
                              &ia_reuse_num, &w_reuse_num);

    status = configure_mmio_registers(config, ia_reuse_num, w_reuse_num);
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
    if (config->dataflow_mode == DSA_DATAFLOW_IS) {
        ctrl |= DSA_CTRL_DATAFLOW_IS;
    }
    dsa_memory_barrier();
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

    dsa_memory_barrier();
    return dsa_reg_read(DSA_REG_WB_DATA);
}
