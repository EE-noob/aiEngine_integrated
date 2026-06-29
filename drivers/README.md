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

int8_t A[128 * 256];  // M=128, K=256
int8_t B[256 * 64];   // K=256, N=64
int8_t C[128 * 64];   // M=128, N=64
int32_t bias[64];     // N=64

dsa_matmul_config_t config;
dsa_matmul_config_init(&config);

config.lhs_ptr = A;
config.rhs_ptr = B;
config.dst_ptr = C;
config.bias_ptr = bias;

config.M = 128;
config.K = 256;
config.N = 64;
config.lhs_row_stride = 256;  // 每行 256 字节

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
config.dst_mult_ptr = mult_per_ch;
config.dst_shift_ptr = shift_per_ch;

uint32_t status = dsa_matmul_execute(&config);
```

### 3. 底层 MMIO 直接访问

```c
// 写入寄存器
dsa_reg_write(CSR_MULT_LHS_PTR, (uint32_t)A);

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
riscv32-unknown-elf-gcc -c dsa_accel.c -o dsa_accel.o
```

## 注意事项

1. `DSA_MMIO_BASE` 目前先预设为 `0xA0000000u`，实际接入 SoC 时需要和地址映射保持一致
2. 所有指针必须是有效的物理地址
3. Per-channel模式下，mult/shift数组长度必须等于N
4. 激活范围需根据输出数据类型合理设置
5. 步进值为0时，驱动会自动计算默认步进