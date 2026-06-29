#include "dsa_accel.h"
#include <string.h>

#define DSA_MATMUL_TIMEOUT 2000000u

/**
 * 构建配置字
 */
uint32_t dsa_build_cfg_word(const dsa_matmul_config_t *config) {
    uint32_t cfg = 0;
    
    /* OUT_W [2:0] */
    cfg |= (config->out_dtype & 0x7);
    
    /* BIAS_W [4:3] */
    cfg |= ((config->bias_dtype & 0x3) << 3);
    
    /* B_W [6:5] */
    cfg |= ((config->rhs_dtype & 0x3) << 5);
    
    /* A_W [8:7] */
    cfg |= ((config->lhs_dtype & 0x3) << 7);
    
    /* PER_CH [9] */
    cfg |= ((config->quant_mode & 0x1) << 9);
    
    /* [31:10] 保留为0 */
    
    return cfg;
}

/**
 * 初始化配置结构
 */
void dsa_matmul_config_init(dsa_matmul_config_t *config) {
    memset(config, 0, sizeof(dsa_matmul_config_t));
    
    /* 设置默认数据类型 */
    config->lhs_dtype = DSA_DTYPE_S8;
    config->rhs_dtype = DSA_DTYPE_S8;   // B固定s8
    config->bias_dtype = DSA_DTYPE_S32;
    config->out_dtype = DSA_DTYPE_S8;   // 输出固定s8
    
    /* 默认per-tensor量化 */
    config->quant_mode = DSA_QUANT_PER_TENSOR;
    
    /* 默认激活范围(int8) */
    config->act_min = -128;
    config->act_max = 127;
}

/**
 * 配置所有CSR寄存器
 */
static uint32_t configure_mmio_registers(const dsa_matmul_config_t *config) {
    /* 检查必需指针 */
    if (!config->lhs_ptr || !config->rhs_ptr || !config->dst_ptr) {
        return DSA_ERR_NULL_PTR;
    }
    
    /* Per-channel模式需要mult/shift数组 */
    if (config->quant_mode == DSA_QUANT_PER_CHANNEL) {
        if (!config->dst_mult_ptr || !config->dst_shift_ptr) {
            return DSA_ERR_NULL_PTR;
        }
    }
    
    /* 配置指针寄存器 */
    dsa_reg_write(CSR_MULT_LHS_PTR, (uint32_t)(uintptr_t)config->lhs_ptr);
    dsa_reg_write(CSR_MULT_RHS_PTR, (uint32_t)(uintptr_t)config->rhs_ptr);
    dsa_reg_write(CSR_MULT_DST_PTR, (uint32_t)(uintptr_t)config->dst_ptr);
    dsa_reg_write(CSR_MULT_BIAS_PTR, (uint32_t)(uintptr_t)config->bias_ptr);
    
    /* 配置尺寸寄存器 (注意：K/N/M 的语义映射) */
    dsa_reg_write(CSR_MULT_LHS_ROWS, config->K);  // K: A的行数
    dsa_reg_write(CSR_MULT_RHS_COLS, config->N);  // N: B的行数/内积长度
    dsa_reg_write(CSR_MULT_RHS_ROWS, config->M);  // M: B的列数/输出通道数
    
    /* 步进配置 (字节，0表示自动推导) */
    dsa_reg_write(CSR_MULT_LHS_COLS_OFFSET, config->lhs_row_stride);  // A行步距
    dsa_reg_write(CSR_MULT_RHS_ROW_STRIDE, config->rhs_row_stride);   // B行步距
    dsa_reg_write(CSR_MULT_ROW_ADDR_OFFSET, config->dst_row_stride);  // 输出行步距
    
    /* 量化参数 */
    dsa_reg_write(CSR_MULT_LHS_OFFSET, (uint32_t)config->lhs_offset);  // A零点
    dsa_reg_write(CSR_MULT_RHS_OFFSET, (uint32_t)config->rhs_offset);  // B零点(通常为0)
    dsa_reg_write(CSR_MULT_DST_OFFSET, (uint32_t)config->dst_offset);  // 输出零点
    
    /* Mult/Shift配置 */
    if (config->quant_mode == DSA_QUANT_PER_TENSOR) {
        /* Per-tensor: 标量值 */
        dsa_reg_write(CSR_MULT_DST_MULT, (uint32_t)config->dst_mult);
        dsa_reg_write(CSR_MULT_DST_SHIFT, (uint32_t)config->dst_shift);
    } else {
        /* Per-channel: 指针(长度M) */
        dsa_reg_write(CSR_MULT_DST_MULT, (uint32_t)(uintptr_t)config->dst_mult_ptr);
        dsa_reg_write(CSR_MULT_DST_SHIFT, (uint32_t)(uintptr_t)config->dst_shift_ptr);
    }
    
    /* 激活限制 */
    dsa_reg_write(CSR_MULT_ACT_MIN, (uint32_t)config->act_min);
    dsa_reg_write(CSR_MULT_ACT_MAX, (uint32_t)config->act_max);
    
    return DSA_SUCCESS;
}

/**
 * 执行矩阵乘法
 */
uint32_t dsa_matmul_execute(const dsa_matmul_config_t *config) {
    uint32_t status;
    
    /* 参数校验 */
    if (!config) {
        return DSA_ERR_NULL_PTR;
    }
    
    /* 配置CSR寄存器 */
    status = configure_mmio_registers(config);
    if (status != DSA_SUCCESS) {
        return status;
    }
    
    /* 构建配置字 */
    uint32_t cfg_word = dsa_build_cfg_word(config);

    /* 触发外设启动并清理上一次状态 */
    uint32_t ctrl = DSA_CTRL_START | DSA_CTRL_CLEAR_DONE | DSA_CTRL_CLEAR_WB_VALID;
    if (config->lhs_dtype == DSA_DTYPE_S16) {
        ctrl |= DSA_CTRL_CFG_16BITS_IA;
    }
    if (config->quant_mode == DSA_QUANT_PER_CHANNEL) {
        ctrl |= DSA_CTRL_PER_CHANNEL;
    }
    dsa_reg_write(DSA_REG_CTRL, ctrl);

    /* 等待完成 */
    uint32_t timeout = DSA_MATMUL_TIMEOUT;
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

    (void)cfg_word;
    return dsa_reg_read(DSA_REG_WB_DATA);
}
