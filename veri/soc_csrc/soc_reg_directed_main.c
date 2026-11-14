#include "dsa_accel_mmio.h"
#include "picosoc_bsp.h"

#define SOC_REG_TEST_OK           0x00000000u
#define SOC_REG_TEST_FAIL_ID      0x84000001u
#define SOC_REG_TEST_FAIL_STATUS  0x84000002u
#define SOC_REG_TEST_FAIL_READ    0x84000003u

static void dsa_reg_write8(uint32_t offset, uint8_t data)
{
    *(volatile uint8_t *)(uintptr_t)(DSA_MMIO_BASE + offset) = data;
}

static uint32_t check_reg(uint32_t offset, uint32_t expected)
{
    uint32_t actual = dsa_reg_read(offset);

    if (actual != expected) {
        printf("[soc_reg] MISMATCH off=0x%03x actual=0x%08x expected=0x%08x\n",
               offset, actual, expected);
        return SOC_REG_TEST_FAIL_READ | (offset & 0x00000fffu);
    }

    return SOC_REG_TEST_OK;
}

static uint32_t run_reg_directed(void)
{
    uint32_t status;
    uint32_t ctrl_flags;

    if (dsa_reg_read(NPU_REG_ID) != 0x4e505531u) {
        return SOC_REG_TEST_FAIL_ID;
    }

    if ((dsa_reg_read(NPU_REG_STATUS) & (1u << 5)) == 0u) {
        return SOC_REG_TEST_FAIL_STATUS;
    }

    status = check_reg(NPU_REG_CTRL, 0u);
    if (status != SOC_REG_TEST_OK) return status;

    dsa_reg_write(NPU_REG_LHS_BASE, 0x00020100u);
    dsa_reg_write(NPU_REG_RHS_BASE, 0x00020300u);
    dsa_reg_write(NPU_REG_DST_BASE, 0x00020500u);
    dsa_reg_write(NPU_REG_BIAS_BASE, 0x00020700u);
    dsa_reg_write(NPU_REG_K, 17u);
    dsa_reg_write(NPU_REG_N, 19u);
    dsa_reg_write(NPU_REG_M, 23u);
    dsa_reg_write(NPU_REG_LHS_STRIDE_B, 38u);
    dsa_reg_write(NPU_REG_RHS_STRIDE_B, 19u);
    dsa_reg_write(NPU_REG_DST_STRIDE_B, 23u);
    dsa_reg_write(NPU_REG_LHS_ZP, (uint32_t)(int32_t)-7);
    dsa_reg_write(NPU_REG_RHS_ZP, 11u);
    dsa_reg_write(NPU_REG_DST_ZP, (uint32_t)(int32_t)-3);
    dsa_reg_write(NPU_REG_Q_MULT, 0x40000000u);
    dsa_reg_write(NPU_REG_Q_SHIFT, (uint32_t)(int32_t)-2);
    dsa_reg_write(NPU_REG_ACT_MIN, (uint32_t)(int32_t)-64);
    dsa_reg_write(NPU_REG_ACT_MAX, 63u);
    dsa_reg_write(NPU_REG_IA_REUSE, 2u);
    dsa_reg_write(NPU_REG_W_REUSE, 4u);
    dsa_reg_write(NPU_REG_ROW_GROUPS, 1u);
    dsa_reg_write(NPU_REG_ROW_TAIL_TILES, 2u);
    dsa_reg_write(NPU_REG_COL_GROUPS, 1u);
    dsa_reg_write(NPU_REG_COL_TAIL_TILES, 2u);

    ctrl_flags = NPU_CTRL_CFG_16BITS_IA |
                 NPU_CTRL_PER_CHANNEL |
                 NPU_CTRL_DATAFLOW_IS |
                 NPU_CTRL_IRQ_ENABLE;
    dsa_reg_write(NPU_REG_CTRL, ctrl_flags);
    dsa_reg_write(NPU_REG_STATUS, NPU_STATUS_DONE);

    status = check_reg(NPU_REG_CTRL, ctrl_flags);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_LHS_BASE, 0x00020100u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_RHS_BASE, 0x00020300u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_DST_BASE, 0x00020500u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_BIAS_BASE, 0x00020700u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_K, 17u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_N, 19u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_M, 23u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_LHS_STRIDE_B, 38u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_RHS_STRIDE_B, 19u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_DST_STRIDE_B, 23u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_LHS_ZP, (uint32_t)(int32_t)-7);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_RHS_ZP, 11u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_DST_ZP, (uint32_t)(int32_t)-3);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_Q_MULT, 0x40000000u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_Q_SHIFT, (uint32_t)(int32_t)-2);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_ACT_MIN, (uint32_t)(int32_t)-64);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_ACT_MAX, 63u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_IA_REUSE, 2u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_W_REUSE, 4u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_CONFIG_ABI, 2u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_ROW_GROUPS, 1u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_ROW_TAIL_TILES, 2u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_COL_GROUPS, 1u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_COL_TAIL_TILES, 2u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_DATAFLOW, 1u);
    if (status != SOC_REG_TEST_OK) return status;

    dsa_reg_write8(NPU_REG_CTRL + 1u, 0u);
    status = check_reg(NPU_REG_CTRL, ctrl_flags);
    if (status != SOC_REG_TEST_OK) return status;
    dsa_reg_write8(NPU_REG_STATUS + 1u, 0u);
    dsa_reg_write8(NPU_REG_DATAFLOW + 1u, 0u);
    status = check_reg(NPU_REG_DATAFLOW, 1u);
    if (status != SOC_REG_TEST_OK) return status;

    dsa_reg_write(NPU_REG_DATAFLOW, 0u);
    status = check_reg(NPU_REG_DATAFLOW, 0u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_CTRL, ctrl_flags & ~NPU_CTRL_DATAFLOW_IS);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(NPU_REG_WB_DATA, 0u);
    if (status != SOC_REG_TEST_OK) return status;
    status = check_reg(0x0f0u, 0u);
    if (status != SOC_REG_TEST_OK) return status;

    return SOC_REG_TEST_OK;
}

int main(void)
{
    uint32_t status;

    picosoc_uart_init();
    status = run_reg_directed();
    if (status == SOC_REG_TEST_OK) {
        printf("[soc_reg] PASS\n");
    } else {
        printf("[soc_reg] FAIL status=0x%08x\n", status);
    }

    soc_finish((status == SOC_REG_TEST_OK) ? SOC_STATUS_PASS : status);
    return (int)status;
}
