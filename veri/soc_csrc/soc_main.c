#include "dsa_accel_mmio.h"
#include "picosoc_bsp.h"
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
    config->dataflow_mode = (SOC_DATAFLOW_MODE == 0u) ? DSA_DATAFLOW_WS : DSA_DATAFLOW_IS;
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
    config->ia_reuse_num = SOC_IA_REUSE_NUM;
    config->w_reuse_num = SOC_W_REUSE_NUM;
}

static uint32_t validate_generated_case(void)
{
    uint32_t expected_size = SOC_K * SOC_M;
    uint32_t lhs_elem_bytes = (SOC_LHS_DTYPE == DSA_DTYPE_S16) ? 2u : 1u;
    uint32_t lhs_stride = (SOC_DATAFLOW_MODE == 0u) ?
                          (SOC_N * lhs_elem_bytes) : (SOC_K * lhs_elem_bytes);
    uint32_t rhs_stride = (SOC_DATAFLOW_MODE == 0u) ? SOC_M : SOC_N;

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

    if (SOC_RHS_ROW_STRIDE != rhs_stride) {
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
            uint32_t row = idx / SOC_M;
            uint32_t col;
            printf("[soc] MISMATCH idx=%u row=%u col=%u actual=%d expected=%d actual_u=0x%02x expected_u=0x%02x\n",
                   idx, row, idx % SOC_M,
                   (int)((int8_t)actual), (int)((int8_t)expected),
                   actual, expected);
            printf("[soc] actual_row:");
            for (col = 0; col < SOC_M; col++) {
                printf(" %d", (int)((int8_t)((uint8_t)dst_data[row * SOC_M + col])));
            }
            printf("\n[soc] expect_row:");
            for (col = 0; col < SOC_M; col++) {
                printf(" %d", (int)((int8_t)((uint8_t)expected_dst_data[row * SOC_M + col])));
            }
            printf("\n");
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

    picosoc_uart_init();
    printf("[soc] case seed=%u random=%u K=%u N=%u M=%u lhs_dtype=%u quant=%u dataflow=%u R=%u W=%u\n",
           SOC_CASE_SEED, SOC_CASE_RANDOM, SOC_K, SOC_N, SOC_M,
           (uint32_t)SOC_LHS_DTYPE, (uint32_t)SOC_QUANT_MODE,
           SOC_DATAFLOW_MODE, SOC_IA_REUSE_NUM, SOC_W_REUSE_NUM);

    status = test_high_level_api();
    if (status == SOC_TEST_OK) {
        printf("[soc] PASS\n");
    } else {
        printf("[soc] FAIL status=0x%08x\n", status);
    }

    soc_finish((status == SOC_TEST_OK) ? SOC_STATUS_PASS : status);
    return (int)status;
}
