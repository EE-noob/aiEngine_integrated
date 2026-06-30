#include "dsa_accel_mmio.h"
#include "picosoc_bsp.h"

#define SOC_TEST_OK           0x00000000u
#define SOC_TEST_FAIL_CONFIG  0x81000000u
#define SOC_TEST_FAIL_DRIVER  0x82000000u
#define SOC_TEST_FAIL_COMPARE 0x83000000u

#ifndef SOC_RUNTIME_CASE_BASE
#define SOC_RUNTIME_CASE_BASE 0x00080000u
#endif

#define SOC_RUNTIME_MAGIC 0x4d4d4152u

typedef struct {
    uint32_t magic;
    uint32_t version;
    uint32_t header_bytes;
    uint32_t total_bytes;
    uint32_t seed;
    uint32_t random_case;
    uint32_t K;
    uint32_t N;
    uint32_t M;
    uint32_t lhs_dtype;
    uint32_t quant_mode;
    uint32_t dataflow_mode;
    uint32_t ia_reuse_num;
    uint32_t w_reuse_num;
    uint32_t lhs_addr;
    uint32_t rhs_addr;
    uint32_t bias_addr;
    uint32_t output_addr;
    uint32_t expected_addr;
    uint32_t dst_mult_addr;
    uint32_t dst_shift_addr;
    uint32_t lhs_row_stride;
    uint32_t rhs_row_stride;
    uint32_t dst_row_stride;
    uint32_t output_size;
    uint32_t expected_dst_size;
    int32_t lhs_offset;
    int32_t rhs_offset;
    int32_t dst_offset;
    int32_t dst_mult;
    int32_t dst_shift;
    int32_t act_min;
    int32_t act_max;
    uint32_t lhs_size;
    uint32_t rhs_size;
    uint32_t bias_size;
    uint32_t dst_mult_size;
    uint32_t dst_shift_size;
} soc_runtime_case_t;

static const volatile soc_runtime_case_t *runtime_case_src(void)
{
    return (const volatile soc_runtime_case_t *)(uintptr_t)SOC_RUNTIME_CASE_BASE;
}

static void load_runtime_case_snapshot(soc_runtime_case_t *dst)
{
    const volatile uint32_t *src = (const volatile uint32_t *)runtime_case_src();
    uint32_t *out = (uint32_t *)dst;
    uint32_t words = sizeof(*dst) / sizeof(uint32_t);
    uint32_t idx;

    for (idx = 0; idx < words; idx++) {
        out[idx] = src[idx];
    }
}

static uint32_t runtime_lhs_dtype(const soc_runtime_case_t *c)
{
    return (c->lhs_dtype == 2u) ? (uint32_t)DSA_DTYPE_S16 : (uint32_t)DSA_DTYPE_S8;
}

static uint32_t validate_runtime_case(const soc_runtime_case_t *c)
{
    uint32_t expected_size;
    uint32_t lhs_elem_bytes;
    uint32_t lhs_stride;
    uint32_t rhs_stride;

    if (c->magic != SOC_RUNTIME_MAGIC) {
        return SOC_TEST_FAIL_CONFIG | 0x01u;
    }

    if (c->version != 1u) {
        return SOC_TEST_FAIL_CONFIG | 0x02u;
    }

    if ((c->K == 0u) || (c->N == 0u) || (c->M == 0u)) {
        return SOC_TEST_FAIL_CONFIG | 0x03u;
    }

    expected_size = c->K * c->M;
    if ((c->expected_dst_size != expected_size) || (c->output_size != expected_size)) {
        return SOC_TEST_FAIL_CONFIG | 0x04u;
    }

    lhs_elem_bytes = (runtime_lhs_dtype(c) == (uint32_t)DSA_DTYPE_S16) ? 2u : 1u;
    lhs_stride = (c->dataflow_mode == 0u) ? (c->N * lhs_elem_bytes) :
                                           (c->K * lhs_elem_bytes);
    rhs_stride = (c->dataflow_mode == 0u) ? c->M : c->N;

    if (c->lhs_row_stride != lhs_stride) {
        return SOC_TEST_FAIL_CONFIG | 0x05u;
    }

    if (c->rhs_row_stride != rhs_stride) {
        return SOC_TEST_FAIL_CONFIG | 0x06u;
    }

    if (c->dst_row_stride != c->M) {
        return SOC_TEST_FAIL_CONFIG | 0x07u;
    }

    if ((c->quant_mode == (uint32_t)DSA_QUANT_PER_CHANNEL) &&
        ((c->dst_mult_addr == 0u) || (c->dst_shift_addr == 0u))) {
        return SOC_TEST_FAIL_CONFIG | 0x08u;
    }

    return SOC_TEST_OK;
}

static void load_runtime_config(const soc_runtime_case_t *c,
                                dsa_matmul_config_t *config)
{
    dsa_matmul_config_init(config);

    config->lhs_ptr = c->lhs_addr;
    config->rhs_ptr = c->rhs_addr;
    config->dst_ptr = c->output_addr;
    config->bias_ptr = c->bias_addr;
    config->K = c->K;
    config->N = c->N;
    config->M = c->M;
    config->lhs_row_stride = c->lhs_row_stride;
    config->rhs_row_stride = c->rhs_row_stride;
    config->dst_row_stride = c->dst_row_stride;
    config->lhs_dtype = (dsa_dtype_t)runtime_lhs_dtype(c);
    config->rhs_dtype = DSA_DTYPE_S8;
    config->bias_dtype = DSA_DTYPE_S32;
    config->out_dtype = DSA_DTYPE_S8;
    config->dataflow_mode = (c->dataflow_mode == 0u) ? DSA_DATAFLOW_WS : DSA_DATAFLOW_IS;
    config->quant_mode = (c->quant_mode == 0u) ? DSA_QUANT_PER_TENSOR :
                                                 DSA_QUANT_PER_CHANNEL;
    config->lhs_offset = c->lhs_offset;
    config->rhs_offset = c->rhs_offset;
    config->dst_offset = c->dst_offset;
    config->dst_mult = c->dst_mult;
    config->dst_shift = c->dst_shift;
    config->dst_mult_ptr = c->dst_mult_addr;
    config->dst_shift_ptr = c->dst_shift_addr;
    config->act_min = c->act_min;
    config->act_max = c->act_max;
    config->ia_reuse_num = c->ia_reuse_num;
    config->w_reuse_num = c->w_reuse_num;
}

static void clear_runtime_output(const soc_runtime_case_t *c)
{
    int8_t *dst = (int8_t *)(uintptr_t)c->output_addr;
    uint32_t idx;

    if (((c->output_addr | c->output_size) & 3u) == 0u) {
        uint32_t *dst32 = (uint32_t *)(uintptr_t)c->output_addr;
        uint32_t words = c->output_size >> 2;

        for (idx = 0; idx < words; idx++) {
            dst32[idx] = 0u;
        }
        return;
    }

    for (idx = 0; idx < c->output_size; idx++) {
        dst[idx] = 0;
    }
}

static uint32_t compare_runtime_output(const soc_runtime_case_t *c)
{
    const int8_t *dst = (const int8_t *)(uintptr_t)c->output_addr;
    const int8_t *expected = (const int8_t *)(uintptr_t)c->expected_addr;
    uint32_t idx;

    if (((c->output_addr | c->expected_addr | c->expected_dst_size) & 3u) == 0u) {
        const uint32_t *dst32 = (const uint32_t *)(uintptr_t)c->output_addr;
        const uint32_t *expected32 = (const uint32_t *)(uintptr_t)c->expected_addr;
        uint32_t words = c->expected_dst_size >> 2;

        for (idx = 0; idx < words; idx++) {
            if (dst32[idx] != expected32[idx]) {
                uint32_t base = idx << 2;
                uint32_t byte_idx;

                for (byte_idx = 0; byte_idx < 4u; byte_idx++) {
                    uint32_t elem_idx = base + byte_idx;
                    uint8_t actual = (uint8_t)dst[elem_idx];
                    uint8_t expect = (uint8_t)expected[elem_idx];

                    if (actual != expect) {
                        uint32_t row = elem_idx / c->M;
                        uint32_t col;
                        printf("[soc_rt] MISMATCH idx=%u row=%u col=%u actual=%d expected=%d actual_u=0x%02x expected_u=0x%02x\n",
                               elem_idx, row, elem_idx % c->M,
                               (int)((int8_t)actual), (int)((int8_t)expect),
                               actual, expect);
                        printf("[soc_rt] actual_row:");
                        for (col = 0; col < c->M; col++) {
                            printf(" %d", (int)dst[row * c->M + col]);
                        }
                        printf("\n[soc_rt] expect_row:");
                        for (col = 0; col < c->M; col++) {
                            printf(" %d", (int)expected[row * c->M + col]);
                        }
                        printf("\n");
                        return SOC_TEST_FAIL_COMPARE | (elem_idx & 0x00ffffffu);
                    }
                }
            }
        }

        return SOC_TEST_OK;
    }

    for (idx = 0; idx < c->expected_dst_size; idx++) {
        uint8_t actual = (uint8_t)dst[idx];
        uint8_t expect = (uint8_t)expected[idx];

        if (actual != expect) {
            uint32_t row = idx / c->M;
            uint32_t col;
            printf("[soc_rt] MISMATCH idx=%u row=%u col=%u actual=%d expected=%d actual_u=0x%02x expected_u=0x%02x\n",
                   idx, row, idx % c->M,
                   (int)((int8_t)actual), (int)((int8_t)expect),
                   actual, expect);
            printf("[soc_rt] actual_row:");
            for (col = 0; col < c->M; col++) {
                printf(" %d", (int)dst[row * c->M + col]);
            }
            printf("\n[soc_rt] expect_row:");
            for (col = 0; col < c->M; col++) {
                printf(" %d", (int)expected[row * c->M + col]);
            }
            printf("\n");
            return SOC_TEST_FAIL_COMPARE | (idx & 0x00ffffffu);
        }
    }

    return SOC_TEST_OK;
}

static uint32_t test_runtime_case(const soc_runtime_case_t *c)
{
    dsa_matmul_config_t config;
    uint32_t status;

    status = validate_runtime_case(c);
    if (status != SOC_TEST_OK) {
        return status;
    }

    load_runtime_config(c, &config);
    clear_runtime_output(c);

    status = dsa_matmul_execute(&config);
    if (status != DSA_SUCCESS) {
        return SOC_TEST_FAIL_DRIVER | (status & 0x00ffffffu);
    }

    return compare_runtime_output(c);
}

int main(void)
{
    soc_runtime_case_t c;
    uint32_t status;

    picosoc_uart_init();
    load_runtime_case_snapshot(&c);
    printf("[soc_rt] case seed=%u random=%u K=%u N=%u M=%u lhs_dtype=%u quant=%u dataflow=%u R=%u W=%u base=0x%08x\n",
           c.seed, c.random_case, c.K, c.N, c.M, c.lhs_dtype,
           c.quant_mode, c.dataflow_mode, c.ia_reuse_num, c.w_reuse_num,
           (uint32_t)SOC_RUNTIME_CASE_BASE);

    status = test_runtime_case(&c);
    if (status == SOC_TEST_OK) {
        printf("[soc_rt] PASS\n");
    } else {
        printf("[soc_rt] FAIL status=0x%08x\n", status);
    }

    soc_finish((status == SOC_TEST_OK) ? SOC_STATUS_PASS : status);
    return (int)status;
}
