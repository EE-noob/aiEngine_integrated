#include "dsa_accel.h"

#define DSA_MATMUL_TIMEOUT 2000000u

static uint32_t ceil_div_u32(uint32_t a, uint32_t b)
{
    return (b == 0u) ? 0u : ((a + b - 1u) / b);
}

static uint32_t min_u32(uint32_t a, uint32_t b)
{
    return (a < b) ? a : b;
}

static uint32_t max_u32(uint32_t a, uint32_t b)
{
    return (a > b) ? a : b;
}

static uint32_t floor_pow2_u32(uint32_t value)
{
    uint32_t out = 1u;
    while ((out << 1) != 0u && (out << 1) <= value) {
        out <<= 1;
    }
    return out;
}

static void dsa_memory_barrier(void)
{
#if defined(__riscv)
    __asm__ volatile("fence rw, rw" ::: "memory");
#else
    __asm__ volatile("" ::: "memory");
#endif
}

static void dsa_matmul_legalize_reuse(uint32_t K, uint32_t M,
                                      uint32_t ia_cache_blocks,
                                      dsa_dataflow_mode_t dataflow_mode,
                                      uint32_t *ia_reuse_num,
                                      uint32_t *w_reuse_num)
{
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
                             uint32_t *w_reuse_num)
{
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

uint32_t dsa_build_cfg_word(const dsa_matmul_config_t *config)
{
    uint32_t cfg = 0u;
    cfg |= ((uint32_t)config->out_dtype & 0x7u);
    cfg |= (((uint32_t)config->bias_dtype & 0x3u) << 3);
    cfg |= (((uint32_t)config->rhs_dtype & 0x3u) << 5);
    cfg |= (((uint32_t)config->lhs_dtype & 0x3u) << 7);
    cfg |= (((uint32_t)config->quant_mode & 0x1u) << 9);
    return cfg;
}

void dsa_matmul_config_init(dsa_matmul_config_t *config)
{
    unsigned int i;
    unsigned char *bytes;

    if (config == 0) {
        return;
    }

    bytes = (unsigned char *)config;
    for (i = 0; i < sizeof(*config); i++) {
        bytes[i] = 0u;
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
                                         uint32_t w_reuse_num)
{
    if ((config->lhs_ptr == 0) || (config->rhs_ptr == 0) ||
        (config->dst_ptr == 0)) {
        return DSA_ERR_NULL_PTR;
    }

    if (config->quant_mode == DSA_QUANT_PER_CHANNEL) {
        if ((config->dst_mult_ptr == 0) || (config->dst_shift_ptr == 0)) {
            return DSA_ERR_NULL_PTR;
        }
    }

    dsa_reg_write(CSR_MULT_LHS_PTR, (uint32_t)(uintptr_t)config->lhs_ptr);
    dsa_reg_write(CSR_MULT_RHS_PTR, (uint32_t)(uintptr_t)config->rhs_ptr);
    dsa_reg_write(CSR_MULT_DST_PTR, (uint32_t)(uintptr_t)config->dst_ptr);
    dsa_reg_write(CSR_MULT_BIAS_PTR, (uint32_t)(uintptr_t)config->bias_ptr);

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
        dsa_reg_write(CSR_MULT_DST_MULT,
                      (uint32_t)(uintptr_t)config->dst_mult_ptr);
        dsa_reg_write(CSR_MULT_DST_SHIFT,
                      (uint32_t)(uintptr_t)config->dst_shift_ptr);
    }

    dsa_reg_write(CSR_MULT_ACT_MIN, (uint32_t)config->act_min);
    dsa_reg_write(CSR_MULT_ACT_MAX, (uint32_t)config->act_max);
    dsa_reg_write(DSA_REG_IA_REUSE, ia_reuse_num);
    dsa_reg_write(DSA_REG_W_REUSE, w_reuse_num);

    return DSA_SUCCESS;
}

uint32_t dsa_matmul_execute(const dsa_matmul_config_t *config)
{
    uint32_t status;
    uint32_t ctrl;
    uint32_t cfg_word;
    uint32_t timeout = DSA_MATMUL_TIMEOUT;
    uint32_t ia_reuse_num;
    uint32_t w_reuse_num;
    dsa_matmul_config_t cfg_local;

    if (config == 0) {
        return DSA_ERR_NULL_PTR;
    }

    cfg_local = *config;

    ia_reuse_num = cfg_local.ia_reuse_num;
    w_reuse_num = cfg_local.w_reuse_num;
    if ((ia_reuse_num == 0u) || (w_reuse_num == 0u)) {
        uint32_t auto_ia = 1u;
        uint32_t auto_w = 1u;
        dsa_matmul_select_reuse(cfg_local.K, cfg_local.N, cfg_local.M,
                                DSA_IA_CACHE_BLOCKS,
                                cfg_local.dataflow_mode,
                                &auto_ia, &auto_w);
        if (ia_reuse_num == 0u) {
            ia_reuse_num = auto_ia;
        }
        if (w_reuse_num == 0u) {
            w_reuse_num = auto_w;
        }
    }
    dsa_matmul_legalize_reuse(cfg_local.K, cfg_local.M, DSA_IA_CACHE_BLOCKS,
                              cfg_local.dataflow_mode,
                              &ia_reuse_num, &w_reuse_num);

    status = configure_mmio_registers(&cfg_local, ia_reuse_num, w_reuse_num);
    if (status != DSA_SUCCESS) {
        return status;
    }

    cfg_word = dsa_build_cfg_word(&cfg_local);
    (void)cfg_word;

    ctrl = DSA_CTRL_START | DSA_CTRL_CLEAR_DONE | DSA_CTRL_CLEAR_WB_VALID;
    if (cfg_local.lhs_dtype == DSA_DTYPE_S16) {
        ctrl |= DSA_CTRL_CFG_16BITS_IA;
    }
    if (cfg_local.quant_mode == DSA_QUANT_PER_CHANNEL) {
        ctrl |= DSA_CTRL_PER_CHANNEL;
    }
    if (cfg_local.dataflow_mode == DSA_DATAFLOW_IS) {
        ctrl |= DSA_CTRL_DATAFLOW_IS;
    }

    dsa_memory_barrier();
    dsa_reg_write(DSA_REG_CTRL, ctrl);

    do {
        status = dsa_reg_read(DSA_REG_STATUS);
        if ((status & DSA_STATUS_DONE) != 0u) {
            break;
        }
    } while (--timeout != 0u);

    if (timeout == 0u) {
        return 0x80000001u;
    }

    if ((status & DSA_STATUS_ERR_MASK) != 0u) {
        return (status & DSA_STATUS_ERR_MASK) >> DSA_STATUS_ERR_SHIFT;
    }

    dsa_memory_barrier();
    return dsa_reg_read(DSA_REG_WB_DATA);
}
