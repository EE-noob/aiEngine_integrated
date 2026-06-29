#include "dsa_accel.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ========== 测试辅助宏 ========== */
#define TEST_PASS "\033[32m[PASS]\033[0m"
#define TEST_FAIL "\033[31m[FAIL]\033[0m"
#define TEST_INFO "\033[34m[INFO]\033[0m"
#define DSA_ADDR(ptr) ((uint32_t)(uintptr_t)(ptr))

#define ASSERT_EQ(actual, expected, msg) \
    do { \
        if ((actual) == (expected)) { \
            printf("%s %s: 0x%08X == 0x%08X\n", TEST_PASS, msg, (uint32_t)(actual), (uint32_t)(expected)); \
        } else { \
            printf("%s %s: 0x%08X != 0x%08X\n", TEST_FAIL, msg, (uint32_t)(actual), (uint32_t)(expected)); \
            test_failed++; \
        } \
    } while(0)

/* ========== 全局测试计数器 ========== */
static int test_failed = 0;

/* ========== CSR 读写测试 ========== */
void test_csr_read_write(void) {
    printf("\n========================================\n");
    printf("CSR 读写测试\n");
    printf("========================================\n");
    
    uint32_t read_val;
    
    /* 测试指针类 CSR */
    printf("\n--- 指针类 CSR 测试 ---\n");
    
    DSA_CSRWR(CSR_MULT_LHS_PTR, 0x80001000);
    DSA_CSRRD(CSR_MULT_LHS_PTR, read_val);
    ASSERT_EQ(read_val, 0x80001000, "MULT_LHS_PTR (0x7C0)");
    
    DSA_CSRWR(CSR_MULT_RHS_PTR, 0x80002000);
    DSA_CSRRD(CSR_MULT_RHS_PTR, read_val);
    ASSERT_EQ(read_val, 0x80002000, "MULT_RHS_PTR (0x7C1)");
    
    DSA_CSRWR(CSR_MULT_DST_PTR, 0x80003000);
    DSA_CSRRD(CSR_MULT_DST_PTR, read_val);
    ASSERT_EQ(read_val, 0x80003000, "MULT_DST_PTR (0x7C2)");
    
    DSA_CSRWR(CSR_MULT_BIAS_PTR, 0x80004000);
    DSA_CSRRD(CSR_MULT_BIAS_PTR, read_val);
    ASSERT_EQ(read_val, 0x80004000, "MULT_BIAS_PTR (0x7C3)");
    
    /* 测试尺寸/步进类 CSR */
    printf("\n--- 尺寸/步进类 CSR 测试 ---\n");
    
    DSA_CSRWR(CSR_MULT_LHS_ROWS, 16);
    DSA_CSRRD(CSR_MULT_LHS_ROWS, read_val);
    ASSERT_EQ(read_val, 16, "MULT_LHS_ROWS/K (0x7C4)");
    
    DSA_CSRWR(CSR_MULT_RHS_COLS, 32);
    DSA_CSRRD(CSR_MULT_RHS_COLS, read_val);
    ASSERT_EQ(read_val, 32, "MULT_RHS_COLS/N (0x7C5)");
    
    DSA_CSRWR(CSR_MULT_RHS_ROWS, 64);
    DSA_CSRRD(CSR_MULT_RHS_ROWS, read_val);
    ASSERT_EQ(read_val, 64, "MULT_RHS_ROWS/M (0x7C6)");
    
    DSA_CSRWR(CSR_MULT_ROW_ADDR_OFFSET, 128);
    DSA_CSRRD(CSR_MULT_ROW_ADDR_OFFSET, read_val);
    ASSERT_EQ(read_val, 128, "MULT_ROW_ADDR_OFFSET (0x7C7)");
    
    DSA_CSRWR(CSR_MULT_LHS_COLS_OFFSET, 256);
    DSA_CSRRD(CSR_MULT_LHS_COLS_OFFSET, read_val);
    ASSERT_EQ(read_val, 256, "MULT_LHS_COLS_OFFSET (0x7C8)");
    
    DSA_CSRWR(CSR_MULT_RHS_ROW_STRIDE, 512);
    DSA_CSRRD(CSR_MULT_RHS_ROW_STRIDE, read_val);
    ASSERT_EQ(read_val, 512, "MULT_RHS_ROW_STRIDE (0x7C9)");
    
    /* 测试量化/激活类 CSR */
    printf("\n--- 量化/激活类 CSR 测试 ---\n");
    
    DSA_CSRWR(CSR_MULT_LHS_OFFSET, 0xFFFFFF80);  // -128
    DSA_CSRRD(CSR_MULT_LHS_OFFSET, read_val);
    ASSERT_EQ(read_val, 0xFFFFFF80, "MULT_LHS_OFFSET (0x7CA)");
    
    DSA_CSRWR(CSR_MULT_RHS_OFFSET, 0x00000000);  // 0
    DSA_CSRRD(CSR_MULT_RHS_OFFSET, read_val);
    ASSERT_EQ(read_val, 0x00000000, "MULT_RHS_OFFSET (0x7CB)");
    
    DSA_CSRWR(CSR_MULT_DST_OFFSET, 0x0000007F);  // 127
    DSA_CSRRD(CSR_MULT_DST_OFFSET, read_val);
    ASSERT_EQ(read_val, 0x0000007F, "MULT_DST_OFFSET (0x7CC)");
    
    DSA_CSRWR(CSR_MULT_DST_MULT, 0x12345678);
    DSA_CSRRD(CSR_MULT_DST_MULT, read_val);
    ASSERT_EQ(read_val, 0x12345678, "MULT_DST_MULT (0x7CD)");
    
    DSA_CSRWR(CSR_MULT_DST_SHIFT, 0x87654321);
    DSA_CSRRD(CSR_MULT_DST_SHIFT, read_val);
    ASSERT_EQ(read_val, 0x87654321, "MULT_DST_SHIFT (0x7CE)");
    
    DSA_CSRWR(CSR_MULT_ACT_MIN, 0xFFFFFF80);  // -128
    DSA_CSRRD(CSR_MULT_ACT_MIN, read_val);
    ASSERT_EQ(read_val, 0xFFFFFF80, "MULT_ACT_MIN (0x7CF)");
    
    DSA_CSRWR(CSR_MULT_ACT_MAX, 0x0000007F);  // 127
    DSA_CSRRD(CSR_MULT_ACT_MAX, read_val);
    ASSERT_EQ(read_val, 0x0000007F, "MULT_ACT_MAX (0x7D0)");
    
    /* 测试零值写入 */
    printf("\n--- 零值写入测试 ---\n");
    
    DSA_CSRWR(CSR_MULT_LHS_PTR, 0x00000000);
    DSA_CSRRD(CSR_MULT_LHS_PTR, read_val);
    ASSERT_EQ(read_val, 0x00000000, "MULT_LHS_PTR 零值");
    
    DSA_CSRWR(CSR_MULT_LHS_ROWS, 0x00000000);
    DSA_CSRRD(CSR_MULT_LHS_ROWS, read_val);
    ASSERT_EQ(read_val, 0x00000000, "MULT_LHS_ROWS 零值");
}

/* ========== 矩阵乘法指令测试 (Per-Tensor) ========== */
void test_matmul_instruction_per_tensor(void) {
    printf("\n========================================\n");
    printf("矩阵乘法指令测试 (Per-Tensor)\n");
    printf("========================================\n");
    
    /* 分配测试数据缓冲区 */
    int8_t lhs_data[16 * 32];     // K=16, N=32
    int8_t rhs_data[32 * 64];     // N=32, M=64
    int8_t dst_data[16 * 64];     // K=16, M=64
    int32_t bias_data[64];        // M=64
    
    /* 初始化测试数据 */
    memset(lhs_data, 1, sizeof(lhs_data));
    memset(rhs_data, 2, sizeof(rhs_data));
    memset(dst_data, 0, sizeof(dst_data));
    memset(bias_data, 0, sizeof(bias_data));
    
    printf("%s 测试数据缓冲区已分配\n", TEST_INFO);
    printf("  LHS: %p (16x32 s8)\n", (void*)lhs_data);
    printf("  RHS: %p (32x64 s8)\n", (void*)rhs_data);
    printf("  DST: %p (16x64 s8)\n", (void*)dst_data);
    printf("  BIAS: %p (64 s32)\n", (void*)bias_data);
    
    dsa_matmul_config_t config;
    dsa_matmul_config_init(&config);
    config.lhs_ptr = DSA_ADDR(lhs_data);
    config.rhs_ptr = DSA_ADDR(rhs_data);
    config.dst_ptr = DSA_ADDR(dst_data);
    config.bias_ptr = DSA_ADDR(bias_data);
    config.K = 16;
    config.N = 32;
    config.M = 64;
    config.lhs_row_stride = 0;
    config.rhs_row_stride = 0;
    config.dst_row_stride = 0;
    config.lhs_dtype = DSA_DTYPE_S8;
    config.rhs_dtype = DSA_DTYPE_S8;
    config.bias_dtype = DSA_DTYPE_S32;
    config.out_dtype = DSA_DTYPE_S8;
    config.quant_mode = DSA_QUANT_PER_TENSOR;
    config.lhs_offset = 0;
    config.rhs_offset = 0;
    config.dst_offset = 0;
    config.dst_mult = 0x40000000;
    config.dst_shift = 0;
    config.act_min = -128;
    config.act_max = 127;

    printf("\n%s 调用 dsa_matmul_execute() 触发 AXI 外设...\n", TEST_INFO);
    uint32_t status = dsa_matmul_execute(&config);

    printf("%s 调用完成\n", TEST_INFO);
    printf("  返回状态码: 0x%08X\n", status);
    
    if (status == DSA_SUCCESS) {
        printf("%s 矩阵乘法指令执行成功\n", TEST_PASS);
    } else {
        printf("%s 矩阵乘法指令执行失败 (状态码: 0x%08X)\n", TEST_FAIL, status);
        test_failed++;
    }
}

/* ========== 矩阵乘法指令测试 (Per-Channel) ========== */
void test_matmul_instruction_per_channel(void) {
    printf("\n========================================\n");
    printf("矩阵乘法指令测试 (Per-Channel)\n");
    printf("========================================\n");
    
    /* 分配测试数据缓冲区 */
    int16_t lhs_data[8 * 16];     // K=8, N=16 (s16)
    int8_t rhs_data[16 * 32];     // N=16, M=32 (s8)
    int8_t dst_data[8 * 32];      // K=8, M=32 (s8)
    int32_t bias_data[32];        // M=32
    int32_t mult_array[32];       // Per-channel mult
    int32_t shift_array[32];      // Per-channel shift
    
    /* 初始化测试数据 */
    memset(lhs_data, 0, sizeof(lhs_data));
    memset(rhs_data, 0, sizeof(rhs_data));
    memset(dst_data, 0, sizeof(dst_data));
    memset(bias_data, 0, sizeof(bias_data));
    
    /* 初始化 per-channel 参数 */
    for (int i = 0; i < 32; i++) {
        mult_array[i] = 0x40000000 + i * 0x1000;  // 不同的 mult 值
        shift_array[i] = i % 8;                    // 不同的 shift 值
    }
    
    printf("%s 测试数据缓冲区已分配\n", TEST_INFO);
    printf("  LHS: %p (8x16 s16)\n", (void*)lhs_data);
    printf("  RHS: %p (16x32 s8)\n", (void*)rhs_data);
    printf("  DST: %p (8x32 s8)\n", (void*)dst_data);
    printf("  BIAS: %p (32 s32)\n", (void*)bias_data);
    printf("  MULT: %p (32 s32)\n", (void*)mult_array);
    printf("  SHIFT: %p (32 s32)\n", (void*)shift_array);
    
    dsa_matmul_config_t config;
    dsa_matmul_config_init(&config);
    config.lhs_ptr = DSA_ADDR(lhs_data);
    config.rhs_ptr = DSA_ADDR(rhs_data);
    config.dst_ptr = DSA_ADDR(dst_data);
    config.bias_ptr = DSA_ADDR(bias_data);
    config.K = 8;
    config.N = 16;
    config.M = 32;
    config.lhs_row_stride = 0;
    config.rhs_row_stride = 0;
    config.dst_row_stride = 0;
    config.lhs_dtype = DSA_DTYPE_S16;
    config.rhs_dtype = DSA_DTYPE_S8;
    config.bias_dtype = DSA_DTYPE_S32;
    config.out_dtype = DSA_DTYPE_S8;
    config.quant_mode = DSA_QUANT_PER_CHANNEL;
    config.lhs_offset = -10;
    config.rhs_offset = 0;
    config.dst_offset = 5;
    config.dst_mult_ptr = DSA_ADDR(mult_array);
    config.dst_shift_ptr = DSA_ADDR(shift_array);
    config.act_min = -128;
    config.act_max = 127;

    printf("\n%s 调用 dsa_matmul_execute() 触发 AXI 外设 (Per-Channel)...\n", TEST_INFO);
    uint32_t status = dsa_matmul_execute(&config);

    printf("%s 调用完成\n", TEST_INFO);
    printf("  返回状态码: 0x%08X\n", status);
    
    if (status == DSA_SUCCESS) {
        printf("%s 矩阵乘法指令执行成功 (Per-Channel)\n", TEST_PASS);
    } else {
        printf("%s 矩阵乘法指令执行失败 (状态码: 0x%08X)\n", TEST_FAIL, status);
        test_failed++;
    }
}

/* ========== 使用高层 API 测试 ========== */
void test_high_level_api(void) {
    printf("\n========================================\n");
    printf("高层 API 测试\n");
    printf("========================================\n");
    
    dsa_matmul_config_t config;
    
    /* 分配测试数据 */
    int8_t lhs_data[4 * 8];
    int8_t rhs_data[8 * 16];
    int8_t dst_data[4 * 16];
    int32_t bias_data[16];
    
    memset(lhs_data, 1, sizeof(lhs_data));
    memset(rhs_data, 2, sizeof(rhs_data));
    memset(dst_data, 0, sizeof(dst_data));
    memset(bias_data, 100, sizeof(bias_data));
    
    /* 初始化配置 */
    dsa_matmul_config_init(&config);
    
    config.lhs_ptr = DSA_ADDR(lhs_data);
    config.rhs_ptr = DSA_ADDR(rhs_data);
    config.dst_ptr = DSA_ADDR(dst_data);
    config.bias_ptr = DSA_ADDR(bias_data);
    
    config.K = 4;
    config.N = 8;
    config.M = 16;
    
    config.dst_mult = 0x40000000;
    config.dst_shift = 0;
    
    printf("%s 配置结构已初始化\n", TEST_INFO);
    printf("  矩阵尺寸: K=%u, N=%u, M=%u\n", config.K, config.N, config.M);
    
    /* 执行矩阵乘法 */
    printf("\n%s 调用 dsa_matmul_execute()...\n", TEST_INFO);
    uint32_t status = dsa_matmul_execute(&config);
    
    printf("%s API 调用完成\n", TEST_INFO);
    printf("  返回状态码: 0x%08X\n", status);
    
    if (status == DSA_SUCCESS) {
        printf("%s 高层 API 执行成功\n", TEST_PASS);
    } else {
        printf("%s 高层 API 执行失败 (状态码: 0x%08X)\n", TEST_FAIL, status);
        test_failed++;
    }
}

/* ========== 主函数 ========== */
int main(void) {
    printf("\n");
    printf("========================================\n");
    printf("DSA 加速器驱动测试程序\n");
    printf("========================================\n");
    
    test_failed = 0;
    
    /* 运行所有测试 */
    test_csr_read_write();
    test_matmul_instruction_per_tensor();
    test_matmul_instruction_per_channel();
    test_high_level_api();
    
    /* 输出测试结果摘要 */
    printf("\n========================================\n");
    printf("测试结果摘要\n");
    printf("========================================\n");
    
    if (test_failed == 0) {
        printf("%s 所有测试通过!\n", TEST_PASS);
        return 0;
    } else {
        printf("%s %d 个测试失败\n", TEST_FAIL, test_failed);
        return 1;
    }
}
