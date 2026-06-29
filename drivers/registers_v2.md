# DSA 新版 AXI/MMIO 寄存器说明

## 1. 说明

新版驱动不再通过自定义指令访问外设，而是通过 AXI-Lite/MMIO 直接读写寄存器。

当前驱动默认基地址如下：

```c
#define DSA_MMIO_BASE 0xA0000000u
```

寄存器按 32-bit word 编址，实际物理地址计算方式为：

```text
physical_addr = DSA_MMIO_BASE + (word_addr << 2)
```

如果接入 `axi_soc` 仿真 SoC，`rtl/nice_coprocessor/soc_top.sv` 里的 MMA 窗口基地址目前是 `0x1000_0000`，需要和 RTL 地址映射保持一致。

## 2. 地址窗口

### 2.1 控制窗口

| Word 地址 | 物理偏移 | 名称 | 访问 | 说明 |
| --- | --- | --- | --- | --- |
| `0x000` | `0x0000` | `DSA_REG_CTRL` | RW | 控制寄存器，写 1 触发启动 |
| `0x001` | `0x0004` | `DSA_REG_STATUS` | RO | 状态寄存器，读取忙闲/完成/错误信息 |
| `0x002` | `0x0008` | `DSA_REG_WB_DATA` | RO | 最后一次 write-back 数据 |
| `0x003` | `0x000C` | `DSA_REG_WB_INFO` | RO | write-back 附加信息，当前 bit0 为有效标志 |

### 2.2 矩阵配置窗口

| Word 地址 | 物理偏移 | 名称 | 访问 | 说明 |
| --- | --- | --- | --- | --- |
| `0x7C0` | `0x1F00` | `CSR_MULT_LHS_PTR` | RW | 左矩阵基地址 |
| `0x7C1` | `0x1F04` | `CSR_MULT_RHS_PTR` | RW | 右矩阵基地址 |
| `0x7C2` | `0x1F08` | `CSR_MULT_DST_PTR` | RW | 输出矩阵基地址 |
| `0x7C3` | `0x1F0C` | `CSR_MULT_BIAS_PTR` | RW | Bias 数组基地址 |
| `0x7C4` | `0x1F10` | `CSR_MULT_LHS_ROWS` | RW | 左矩阵行数 `K` |
| `0x7C5` | `0x1F14` | `CSR_MULT_RHS_COLS` | RW | 内积长度 `N` |
| `0x7C6` | `0x1F18` | `CSR_MULT_RHS_ROWS` | RW | 右矩阵列数 / 输出通道数 `M` |
| `0x7C7` | `0x1F1C` | `CSR_MULT_DST_ROW_STRIDE` | RW | 输出行步长，单位字节 |
| `0x7C8` | `0x1F20` | `CSR_MULT_LHS_ROW_STRIDE` | RW | 左矩阵行步长，单位字节 |
| `0x7C9` | `0x1F24` | `CSR_MULT_RHS_COL_STRIDE` | RW | 右矩阵列步长，单位字节 |
| `0x7CA` | `0x1F28` | `CSR_MULT_LHS_OFFSET` | RW | 左矩阵零点 / offset |
| `0x7CB` | `0x1F2C` | `CSR_MULT_RHS_OFFSET` | RW | 右矩阵零点 / offset |
| `0x7CC` | `0x1F30` | `CSR_MULT_DST_OFFSET` | RW | 输出零点 / offset |
| `0x7CD` | `0x1F34` | `CSR_MULT_DST_MULT` | RW | per-tensor mult，或 per-channel mult 指针 |
| `0x7CE` | `0x1F38` | `CSR_MULT_DST_SHIFT` | RW | per-tensor shift，或 per-channel shift 指针 |
| `0x7CF` | `0x1F3C` | `CSR_MULT_ACT_MIN` | RW | 激活下限 |
| `0x7D0` | `0x1F40` | `CSR_MULT_ACT_MAX` | RW | 激活上限 |

## 3. 控制寄存器

`DSA_REG_CTRL` 是启动和状态清理入口。写入时的主要位定义如下：

| 位 | 名称 | 方向 | 说明 |
| --- | --- | --- | --- |
| `0` | `START` | W | 写 1 启动一次计算，硬件按脉冲处理 |
| `1` | `CFG_16BITS_IA` | W | 1 表示左矩阵输入采用 s16 |
| `2` | `PER_CHANNEL` | W | 1 表示使用 per-channel 量化参数 |
| `8` | `CLEAR_DONE` | W | 写 1 清除 sticky done 标志 |
| `9` | `CLEAR_WB_VALID` | W | 写 1 清除最后一次 write-back 有效标志 |

未定义位保留，建议写 0。

推荐的启动写法是：

```c
uint32_t ctrl = DSA_CTRL_START | DSA_CTRL_CLEAR_DONE | DSA_CTRL_CLEAR_WB_VALID;
if (config->lhs_dtype == DSA_DTYPE_S16) {
    ctrl |= DSA_CTRL_CFG_16BITS_IA;
}
if (config->quant_mode == DSA_QUANT_PER_CHANNEL) {
    ctrl |= DSA_CTRL_PER_CHANNEL;
}
dsa_reg_write(DSA_REG_CTRL, ctrl);
```

## 4. 状态寄存器

`DSA_REG_STATUS` 读取到的是 8 个低位状态信息。当前 RTL 的位定义如下：

| 位 | 名称 | 方向 | 说明 |
| --- | --- | --- | --- |
| `0` | `SA_READY` | RO | SA 侧就绪 |
| `1` | `BUSY` | RO | 外设忙 |
| `2` | `DONE` | RO | 完成标志，sticky 位 |
| `3` | `WB_VALID` | RO | 最后一次 write-back 有效 |
| `5:4` | `ERR_CODE` | RO | 错误码 |
| `6` | `RSP_ERR` | RO | 返回响应错误标志 |
| `7` | `CSR_READY` | RO | CSR 通道就绪 |

建议驱动轮询条件为 `DONE == 1`，同时检查 `ERR_CODE` 是否为 0。

示例：

```c
while (1) {
    uint32_t status = dsa_reg_read(DSA_REG_STATUS);
    if (status & DSA_STATUS_DONE) {
        if ((status & DSA_STATUS_ERR_MASK) != 0) {
            break;
        }
        break;
    }
}
```

## 5. Write-back 寄存器

### 5.1 `DSA_REG_WB_DATA`

该寄存器保存最近一次 write-back 的数据值。当前驱动中的 `dsa_matmul_execute()` 在计算完成后会读取这个寄存器并作为返回值。

### 5.2 `DSA_REG_WB_INFO`

当前仅使用 bit0：

| 位 | 名称 | 方向 | 说明 |
| --- | --- | --- | --- |
| `0` | `LAST_WB_VALID` | RO | 最近一次 write-back 是否有效 |

## 6. 矩阵配置寄存器

### 6.1 指针类寄存器

这四个寄存器写入的是物理地址，不是偏移：

| 寄存器 | 说明 |
| --- | --- |
| `CSR_MULT_LHS_PTR` | 左矩阵基址 |
| `CSR_MULT_RHS_PTR` | 右矩阵基址 |
| `CSR_MULT_DST_PTR` | 输出矩阵基址 |
| `CSR_MULT_BIAS_PTR` | Bias 数组基址，可为空指针 |

### 6.2 尺寸寄存器

| 寄存器 | 说明 |
| --- | --- |
| `CSR_MULT_LHS_ROWS` | `K`，左矩阵行数 |
| `CSR_MULT_RHS_COLS` | `N`，内积长度 |
| `CSR_MULT_RHS_ROWS` | `M`，输出列数 |

### 6.3 步长寄存器

| 寄存器 | 说明 |
| --- | --- |
| `CSR_MULT_DST_ROW_STRIDE` | 输出矩阵每行跨度，单位字节 |
| `CSR_MULT_LHS_ROW_STRIDE` | 左矩阵每行跨度，单位字节 |
| `CSR_MULT_RHS_COL_STRIDE` | 右矩阵每列跨度，单位字节 |

兼容别名已经保留：

| 兼容名 | 实际寄存器 |
| --- | --- |
| `CSR_MULT_ROW_ADDR_OFFSET` | `CSR_MULT_DST_ROW_STRIDE` |
| `CSR_MULT_LHS_COLS_OFFSET` | `CSR_MULT_LHS_ROW_STRIDE` |
| `CSR_MULT_RHS_ROW_STRIDE` | `CSR_MULT_RHS_COL_STRIDE` |

### 6.4 量化与激活寄存器

| 寄存器 | 说明 |
| --- | --- |
| `CSR_MULT_LHS_OFFSET` | 左矩阵零点 |
| `CSR_MULT_RHS_OFFSET` | 右矩阵零点 |
| `CSR_MULT_DST_OFFSET` | 输出零点 |
| `CSR_MULT_DST_MULT` | per-tensor mult 或 per-channel mult 指针 |
| `CSR_MULT_DST_SHIFT` | per-tensor shift 或 per-channel shift 指针 |
| `CSR_MULT_ACT_MIN` | 激活下限 |
| `CSR_MULT_ACT_MAX` | 激活上限 |

## 7. 推荐访问顺序

1. 写入所有矩阵参数寄存器。
2. 写入 `DSA_REG_CTRL`，拉起 `START` 位并按需设置 `CFG_16BITS_IA` 和 `PER_CHANNEL`。
3. 轮询 `DSA_REG_STATUS` 的 `DONE` 位。
4. 若 `ERR_CODE != 0`，按错误路径处理。
5. 若完成正常，读取 `DSA_REG_WB_DATA`，必要时再读 `DSA_REG_WB_INFO`。
6. 下一次任务开始前，写 `CLEAR_DONE` 和 `CLEAR_WB_VALID` 清理 sticky 状态。

## 8. 现有驱动约定

当前 `drivers/dsa_accel.c` 的高层 API 已封装上述流程：

- `dsa_reg_write()` / `dsa_reg_read()` 负责 MMIO 访问。
- `dsa_matmul_execute()` 负责写入矩阵配置、触发 `START`、轮询 `DONE` 和读取 `WB_DATA`。
- `DSA_CSRWR()` / `DSA_CSRRD()` 目前是兼容宏，底层仍然走 MMIO。

## 9. 快速示例

```c
dsa_reg_write(CSR_MULT_LHS_PTR, (uint32_t)(uintptr_t)lhs);
dsa_reg_write(CSR_MULT_RHS_PTR, (uint32_t)(uintptr_t)rhs);
dsa_reg_write(CSR_MULT_DST_PTR, (uint32_t)(uintptr_t)dst);
dsa_reg_write(CSR_MULT_BIAS_PTR, (uint32_t)(uintptr_t)bias);

dsa_reg_write(CSR_MULT_LHS_ROWS, k);
dsa_reg_write(CSR_MULT_RHS_COLS, n);
dsa_reg_write(CSR_MULT_RHS_ROWS, m);

dsa_reg_write(DSA_REG_CTRL, DSA_CTRL_START | DSA_CTRL_CLEAR_DONE | DSA_CTRL_CLEAR_WB_VALID);

while ((dsa_reg_read(DSA_REG_STATUS) & DSA_STATUS_DONE) == 0) {
}
```
