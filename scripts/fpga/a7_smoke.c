#include "dsa_accel_mmio.h"

extern uint8_t _stack_top[];

static const int8_t lhs[4] __attribute__((aligned(4))) = {1, 2, 3, 4};
static const int8_t rhs[4] __attribute__((aligned(4))) = {2, -1, 3, 1};
static const int32_t bias = 3;
static volatile int8_t dst[4] __attribute__((aligned(4)));

int main(void) {
    // Exercise the upper RAM bank and a byte write without touching the live stack.
    uintptr_t scratch = (uintptr_t)_stack_top - 4096u;
    volatile uint32_t *word = (volatile uint32_t *)scratch;
    volatile uint8_t *bytes = (volatile uint8_t *)scratch;
    *word = 0xa5c3e71bu;
    bytes[1] = 0x5au;
    if (*word != 0xa5c35a1bu) return 0xa701u;
    if (dsa_reg_read(NPU_REG_ID) != 0x4e505531u) return 0xa702u;

    dsa_matmul_config_t cfg;
    dsa_matmul_config_init(&cfg);
    cfg.lhs_ptr = (uintptr_t)lhs;
    cfg.rhs_ptr = (uintptr_t)rhs;
    cfg.bias_ptr = (uintptr_t)&bias;
    cfg.dst_ptr = (uintptr_t)dst;
    cfg.K = 1;
    cfg.N = 4;
    cfg.M = 1;
    cfg.lhs_row_stride = sizeof(lhs);
    cfg.rhs_row_stride = sizeof(rhs);
    cfg.dst_row_stride = sizeof(dst);
    cfg.dst_mult = 0x40000000;
    cfg.dst_shift = 1;
    cfg.ia_reuse_num = 1;
    cfg.w_reuse_num = 1;

    uint32_t result = dsa_matmul_execute(&cfg);
    if (result != DSA_SUCCESS) return 0xa7100000u | (result & 0xffffu);
    // Dot product plus bias, with identity requantization: 2 - 2 + 9 + 4 + 3.
    if (dst[0] != 16) return 0xa7200000u | (uint8_t)dst[0];
    return SOC_STATUS_PASS;
}
