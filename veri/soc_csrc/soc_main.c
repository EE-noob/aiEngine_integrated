#include "dsa_accel_mmio.h"
#include "soc_case.h"

int main(void) {
    dsa_matmul_config_t config;
    uint32_t status;

    config.lhs_ptr = SOC_LHS_ADDR;
    config.rhs_ptr = SOC_RHS_ADDR;
    config.dst_ptr = SOC_OUTPUT_BASE_ADDR;
    config.bias_ptr = SOC_BIAS_ADDR;
    config.K = SOC_K;
    config.N = SOC_N;
    config.M = SOC_M;
    config.lhs_row_stride = SOC_LHS_ROW_STRIDE;
    config.rhs_row_stride = SOC_RHS_ROW_STRIDE;
    config.dst_row_stride = SOC_DST_ROW_STRIDE;
    config.lhs_dtype = SOC_LHS_DTYPE;
    config.rhs_dtype = DSA_DTYPE_S8;
    config.bias_dtype = DSA_DTYPE_S32;
    config.out_dtype = DSA_DTYPE_S8;
    config.quant_mode = SOC_QUANT_MODE;
    config.lhs_offset = SOC_LHS_OFFSET;
    config.rhs_offset = SOC_RHS_OFFSET;
    config.dst_offset = SOC_DST_OFFSET;
    config.dst_mult = SOC_DST_MULT;
    config.dst_shift = SOC_DST_SHIFT;
    config.dst_mult_ptr = SOC_DST_MULT_ADDR;
    config.dst_shift_ptr = SOC_DST_SHIFT_ADDR;
    config.act_min = SOC_ACT_MIN;
    config.act_max = SOC_ACT_MAX;

    status = dsa_matmul_execute(&config);
    soc_finish((status == DSA_SUCCESS) ? SOC_STATUS_PASS : SOC_STATUS_FAIL);
    return (int)status;
}
