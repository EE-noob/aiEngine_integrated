#ifndef SOC_CASE_H
#define SOC_CASE_H

#include <stdint.h>
#include "dsa_accel_mmio.h"

extern int8_t lhs_data[256];
extern int8_t rhs_data[256];
extern int32_t bias_data[16];
extern const int8_t expected_dst_data[256];
extern volatile int8_t dst_data[256];

#define SOC_K 16
#define SOC_N 16
#define SOC_M 16
#define SOC_LHS_ADDR ((uint32_t)(uintptr_t)lhs_data)
#define SOC_RHS_ADDR ((uint32_t)(uintptr_t)rhs_data)
#define SOC_BIAS_ADDR ((uint32_t)(uintptr_t)bias_data)
#define SOC_OUTPUT_BASE_ADDR ((uint32_t)(uintptr_t)dst_data)
#define SOC_DST_MULT_ADDR 0u
#define SOC_DST_SHIFT_ADDR 0u
#define SOC_LHS_ROW_STRIDE 16
#define SOC_RHS_ROW_STRIDE 16
#define SOC_DST_ROW_STRIDE 16
#define SOC_LHS_DTYPE DSA_DTYPE_S8
#define SOC_QUANT_MODE 0
#define SOC_DATAFLOW_MODE 0
#define SOC_IA_REUSE_NUM 0
#define SOC_W_REUSE_NUM 0
#define SOC_LHS_OFFSET 0
#define SOC_RHS_OFFSET 0
#define SOC_DST_OFFSET 0
#define SOC_DST_MULT 1255150260
#define SOC_DST_SHIFT -8
#define SOC_ACT_MIN -128
#define SOC_ACT_MAX 127
#define SOC_OUTPUT_SIZE 256
#define SOC_EXPECTED_DST_SIZE 256
#define SOC_CASE_SEED 1
#define SOC_CASE_RANDOM 0

#endif
