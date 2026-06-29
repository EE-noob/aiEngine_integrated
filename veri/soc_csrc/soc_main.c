#include "dsa_accel_mmio.h"
#include "soc_case.h"

#define SOC_TEST_OK           0x00000000u
#define SOC_TEST_FAIL_CONFIG  0x81000000u
#define SOC_TEST_FAIL_DRIVER  0x82000000u
#define SOC_TEST_FAIL_COMPARE 0x83000000u

static void load_generated_config(dsa_matmul_config_t *config)
{
    dsa_matmul_config_init(config);

    config->lhs_ptr = SOC_LHS_ADDR;
    config->rhs_ptr = SOC_RHS_ADDR;
    config->dst_ptr = SOC_OUTPUT_BASE_ADDR;
    config->bias_ptr = SOC_BIAS_ADDR;
    config->K = SOC_K;
    config->N = SOC_N;
    config->M = SOC_M;
    config->lhs_row_stride = SOC_LHS_ROW_STRIDE;
    config->rhs_row_stride = SOC_RHS_ROW_STRIDE;
    config->dst_row_stride = SOC_DST_ROW_STRIDE;
    config->lhs_dtype = SOC_LHS_DTYPE;
    config->rhs_dtype = DSA_DTYPE_S8;
    config->bias_dtype = DSA_DTYPE_S32;
    config->out_dtype = DSA_DTYPE_S8;
    config->quant_mode = SOC_QUANT_MODE;
    config->lhs_offset = SOC_LHS_OFFSET;
    config->rhs_offset = SOC_RHS_OFFSET;
    config->dst_offset = SOC_DST_OFFSET;
    config->dst_mult = SOC_DST_MULT;
    config->dst_shift = SOC_DST_SHIFT;
    config->dst_mult_ptr = SOC_DST_MULT_ADDR;
    config->dst_shift_ptr = SOC_DST_SHIFT_ADDR;
    config->act_min = SOC_ACT_MIN;
    config->act_max = SOC_ACT_MAX;
}

static uint32_t validate_generated_case(void)
{
    uint32_t expected_size = SOC_K * SOC_M;
    uint32_t lhs_stride = (SOC_LHS_DTYPE == DSA_DTYPE_S16) ? (SOC_N * 2u) : SOC_N;

    if ((SOC_K == 0u) || (SOC_N == 0u) || (SOC_M == 0u)) {
        return SOC_TEST_FAIL_CONFIG | 0x01u;
    }

    if (SOC_EXPECTED_DST_SIZE != expected_size) {
        return SOC_TEST_FAIL_CONFIG | 0x02u;
    }

    if (SOC_OUTPUT_SIZE != SOC_EXPECTED_DST_SIZE) {
        return SOC_TEST_FAIL_CONFIG | 0x03u;
    }

    if (SOC_LHS_ROW_STRIDE != lhs_stride) {
        return SOC_TEST_FAIL_CONFIG | 0x04u;
    }

    if (SOC_RHS_ROW_STRIDE != SOC_N) {
        return SOC_TEST_FAIL_CONFIG | 0x05u;
    }

    if (SOC_DST_ROW_STRIDE != SOC_M) {
        return SOC_TEST_FAIL_CONFIG | 0x06u;
    }

    if ((SOC_QUANT_MODE == DSA_QUANT_PER_CHANNEL) &&
        ((SOC_DST_MULT_ADDR == 0u) || (SOC_DST_SHIFT_ADDR == 0u))) {
        return SOC_TEST_FAIL_CONFIG | 0x07u;
    }

    return SOC_TEST_OK;
}

static uint32_t compare_generated_output(void)
{
    uint32_t idx;

    for (idx = 0; idx < SOC_EXPECTED_DST_SIZE; idx++) {
        uint8_t actual = (uint8_t)dst_data[idx];
        uint8_t expected = (uint8_t)expected_dst_data[idx];

        if (actual != expected) {
            return SOC_TEST_FAIL_COMPARE | (idx & 0x00ffffffu);
        }
    }

    return SOC_TEST_OK;
}

static void clear_generated_output(void)
{
    uint32_t idx;

    for (idx = 0; idx < SOC_EXPECTED_DST_SIZE; idx++) {
        dst_data[idx] = 0;
    }
}

static uint32_t test_high_level_api(void)
{
    dsa_matmul_config_t config;
    uint32_t status;

    status = validate_generated_case();
    if (status != SOC_TEST_OK) {
        return status;
    }

    load_generated_config(&config);
    clear_generated_output();

    status = dsa_matmul_execute(&config);
    if (status != DSA_SUCCESS) {
        return SOC_TEST_FAIL_DRIVER | (status & 0x00ffffffu);
    }

    return compare_generated_output();
}

int main(void) {
    uint32_t status;

    status = test_high_level_api();
    soc_finish((status == SOC_TEST_OK) ? SOC_STATUS_PASS : status);
    return (int)status;
}
