# DSA AXI/MMIO 加速器驱动

## 概述

本驱动提供了对新版 AXI 外设的 C 语言接口封装，支持：
- MMIO 寄存器访问
- 矩阵乘法启动/轮询
- Per-tensor和per-channel量化
- 灵活的数据类型配置（s4/s8/s16/s32/s64）

## 文件说明

- `dsa_accel.h` - 驱动头文件，定义所有接口
- `dsa_accel.c` - 驱动实现文件
- `registers_v2.md` - 新版 AXI/MMIO 寄存器说明

## 寄存器文档

新版外设的详细寄存器定义见 [registers_v2.md](registers_v2.md)。文档按基地址、控制/状态位、矩阵配置寄存器和访问顺序整理，适合驱动联调时直接查阅。

## 使用示例

### 1. 基本矩阵乘法（Per-Tensor量化）

```c
#include "dsa_accel.h"

int8_t A[128 * 256];  // K=128, N=256
int8_t B[256 * 64];   // N=256, M=64, column-major
int8_t C[128 * 64];   // K=128, M=64
int32_t bias[64];     // M=64

dsa_matmul_config_t config;
dsa_matmul_config_init(&config);

config.lhs_ptr = (uint32_t)(uintptr_t)A;
config.rhs_ptr = (uint32_t)(uintptr_t)B;
config.dst_ptr = (uint32_t)(uintptr_t)C;
config.bias_ptr = (uint32_t)(uintptr_t)bias;

config.K = 128;
config.N = 256;
config.M = 64;
config.lhs_row_stride = 256;  // 每行 256 字节
config.rhs_row_stride = 256;  // 每列 256 字节
config.dst_row_stride = 64;   // 每行 64 字节

config.lhs_offset = 128;  // 零点偏移
config.dst_mult = 1234567;
config.dst_shift = 10;

uint32_t status = dsa_matmul_execute(&config);
if (status != DSA_SUCCESS) {
    // 错误处理
}
```

### 2. Per-Channel量化

```c
int32_t mult_per_ch[64];   // 每通道mult
int32_t shift_per_ch[64];  // 每通道shift

dsa_matmul_config_init(&config);
// ...existing code...

config.quant_mode = DSA_QUANT_PER_CHANNEL;
config.dst_mult_ptr = (uint32_t)(uintptr_t)mult_per_ch;
config.dst_shift_ptr = (uint32_t)(uintptr_t)shift_per_ch;

uint32_t status = dsa_matmul_execute(&config);
```

### 3. 底层 MMIO 直接访问

```c
// 写入寄存器
dsa_reg_write(CSR_MULT_LHS_PTR, (uint32_t)(uintptr_t)A);

// 读取寄存器
uint32_t value = dsa_reg_read(CSR_MULT_LHS_ROWS);

// 直接调用高层 API
uint32_t status = dsa_matmul_execute(&config);
```

## 返回状态码

- `DSA_SUCCESS (0x00000000)` - 执行成功
- `DSA_ERR_NULL_PTR (0x00000002)` - 必需指针为空
- `DSA_ERR_INVALID_DIM (0x00000003)` - 尺寸不满足对齐要求

## 编译说明

```bash
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -c dsa_accel.c -o dsa_accel.o
```

## 注意事项

1. `DSA_MMIO_BASE` 当前与 `soc_top.sv` 保持一致，为 `0x10000000u`
2. 配置结构中的地址字段是 RV32 物理地址值，赋值时使用 `(uint32_t)(uintptr_t)ptr`
3. Per-channel模式下，mult/shift数组长度必须等于M
4. 激活范围需根据输出数据类型合理设置
5. 步进值按字节配置；当前 SoC 回归使用显式 stride
