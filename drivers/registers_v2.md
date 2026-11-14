# NPU AXI-Lite Register Map

当前 NPU 配置接口已经统一为标准 AXI-Lite MMIO。寄存器从 NPU 窗口基地址 `0x1000_0000` 的 `0x000` 偏移开始连续定义，驱动侧使用字节偏移，验证侧 UVM 寄存器模型使用等价的 word offset。

## 地址表

| Byte offset | Word offset | Name | Access | Description |
|---:|---:|---|---|---|
| `0x000` | `0x000` | `NPU_REG_CTRL` | RW | 启动、数据位宽、量化模式、数据流和中断使能控制 |
| `0x004` | `0x001` | `NPU_REG_STATUS` | RO/WC | ready/busy/done/error 状态，done 使用写清除 |
| `0x008` | `0x002` | `NPU_REG_WB_DATA` | RO | 最近一次完成状态写回 |
| `0x010` | `0x004` | `NPU_REG_LHS_BASE` | RW | LHS/IA 基地址 |
| `0x014` | `0x005` | `NPU_REG_RHS_BASE` | RW | RHS/W 基地址 |
| `0x018` | `0x006` | `NPU_REG_DST_BASE` | RW | 输出基地址 |
| `0x01c` | `0x007` | `NPU_REG_BIAS_BASE` | RW | bias 基地址，可为 0 |
| `0x020` | `0x008` | `NPU_REG_K` | RW | 输出行数 / LHS rows |
| `0x024` | `0x009` | `NPU_REG_N` | RW | 内积长度 |
| `0x028` | `0x00a` | `NPU_REG_M` | RW | 输出列数 / RHS cols |
| `0x02c` | `0x00b` | `NPU_REG_LHS_STRIDE_B` | RW | LHS 行跨度，单位字节 |
| `0x030` | `0x00c` | `NPU_REG_RHS_STRIDE_B` | RW | RHS 列跨度，单位字节 |
| `0x034` | `0x00d` | `NPU_REG_DST_STRIDE_B` | RW | 输出行跨度，单位字节 |
| `0x038` | `0x00e` | `NPU_REG_LHS_ZP` | RW | LHS zero point |
| `0x03c` | `0x00f` | `NPU_REG_RHS_ZP` | RW | RHS zero point |
| `0x040` | `0x010` | `NPU_REG_DST_ZP` | RW | 输出 zero point |
| `0x044` | `0x011` | `NPU_REG_Q_MULT` | RW | per-tensor multiplier 或 per-channel multiplier 指针 |
| `0x048` | `0x012` | `NPU_REG_Q_SHIFT` | RW | per-tensor shift 或 per-channel shift 指针 |
| `0x04c` | `0x013` | `NPU_REG_ACT_MIN` | RW | 激活下限 |
| `0x050` | `0x014` | `NPU_REG_ACT_MAX` | RW | 激活上限 |
| `0x054` | `0x015` | `NPU_REG_IA_REUSE` | RW | IA cache 复用深度 |
| `0x058` | `0x016` | `NPU_REG_W_REUSE` | RW | W 侧复用窗口 |
| `0x05c` | `0x017` | `NPU_REG_DATAFLOW` | RW | `0=WS`，`1=IS` |
| `0x060` | `0x018` | `NPU_REG_ROW_GROUPS` | RW | 内部流行工作组总数，外部预计算 |
| `0x064` | `0x019` | `NPU_REG_ROW_TAIL_TILES` | RW | 最后一行工作组的 tile 数，整除时写 R |
| `0x068` | `0x01a` | `NPU_REG_COL_GROUPS` | RW | 内部流列工作组总数，外部预计算 |
| `0x06c` | `0x01b` | `NPU_REG_COL_TAIL_TILES` | RW | 最后一列工作组的 tile 数，整除时写 W |
| `0x070` | `0x01c` | `NPU_REG_CONFIG_ABI` | RO | 配置 ABI 版本，当前为 2 |
| `0x0fc` | `0x03f` | `NPU_REG_ID` | RO | 固定为 `0x4e50_5531` |

## CTRL 位定义

| Bit | Name | Description |
|---:|---|---|
| 0 | `NPU_CTRL_START` | 写 1 产生单周期 start pulse |
| 1 | `NPU_CTRL_CFG_16BITS_IA` | LHS/IA 使用 int16 |
| 2 | `NPU_CTRL_PER_CHANNEL` | 量化参数按 channel 读取 |
| 3 | `NPU_CTRL_DATAFLOW_IS` | `1=IS`，`0=WS` |
| 4 | `NPU_CTRL_IRQ_ENABLE` | `1` 表示任务完成后允许 `irq` 拉高 |

## STATUS 位定义

| Bit | Name | Description |
|---:|---|---|
| 0 | `SA_READY` | NPU 计算阵列 ready |
| 1 | `BUSY` | NPU 正在执行 |
| 2 | `NPU_STATUS_DONE` | 本次任务完成，写 1 清除 |
| 4:3 | `NPU_STATUS_ERR_MASK` | `00=正常`，`01=配置错误`，`10=资源缺失` |
| 5 | `REG_READY` | AXI-Lite 寄存器通路 ready |

## 软件访问示例

```c
dsa_reg_write(NPU_REG_LHS_BASE, (uint32_t)(uintptr_t)lhs);
dsa_reg_write(NPU_REG_RHS_BASE, (uint32_t)(uintptr_t)rhs);
dsa_reg_write(NPU_REG_DST_BASE, (uint32_t)(uintptr_t)dst);
dsa_reg_write(NPU_REG_K, k);
dsa_reg_write(NPU_REG_N, n);
dsa_reg_write(NPU_REG_M, m);

dsa_reg_write(NPU_REG_STATUS, NPU_STATUS_DONE);
dsa_reg_write(NPU_REG_CTRL, NPU_CTRL_START | NPU_CTRL_IRQ_ENABLE);

while ((dsa_reg_read(NPU_REG_STATUS) & NPU_STATUS_DONE) == 0u) {
}

dsa_reg_write(NPU_REG_STATUS, NPU_STATUS_DONE);
```

## ABI 2：外部预计算分组参数

本版没有内置配置除法器或硬件除法回退。CPU、模型编译器或外部调度器在 START 之前写入上述四个字段。配置参数从 START 到完成期间必须保持不变。`NPU_REG_ID` 保留设备系列标识；软件用 `NPU_REG_CONFIG_ABI == 2` 判断新配置接口。

设公开 GEMM 形状为 `C[M,N] = A[M,K] × B[K,N]`。本项目旧寄存器命名为 `REG_K=M`（输出行数）、`REG_N=K`（归约维）、`REG_M=N`（输出列数）。WS 内部流行／列对应 M／N；IS 对应 N／M。计算分组时使用内部流维度以及外部计算得到的最终 R、W，包括容量裁剪、支持尺寸取整和 IS 调整。ABI 2 的 R/W 寄存器必须写入非零最终值，支持二次幂及 25，且不能超过对应硬件容量；RTL 检查合法性，不再自动修正 R/W。软件函数仍允许以 0 表示请求自动选择，然后返回非零最终值。

```
row_tiles = ceil(stream_rows / array_size)
col_tiles = ceil(stream_cols / array_size)
ROW_GROUPS = ceil(row_tiles / R)
ROW_TAIL_TILES = row_tiles % R; 若为 0，则写 R
COL_GROUPS = ceil(col_tiles / W)
COL_TAIL_TILES = col_tiles % W; 若为 0，则写 W
```

`drivers/gempact_tiling.h` 提供独立 C 计算函数；`veri/top_regression/host_tiling.py` 提供相同的 Python 实现。驱动已在配置寄存器时调用 C 函数，写入显式 R、W 及四个字段。固定形状可以保存这些结果并直接配置，无须每次运行除法。

RTL 只检查非零、尾组不超过生效 R/W，以及组数字段能否放入计数器；无效配置返回 `err_code=01`。乘积关系和完整维度一致性由外部保证，RTL 不重新做除法验证。

独立 RTL 仿真的 32 字 `config.mem` 保留 word29 的原有取数模式；word30 的低／高 16 位分别为行／列组数，word31 的低／高 16 位分别为行／列尾组大小。旧输入应先通过 `host_tiling.py SOURCE DESTINATION` 转换。硬件寄存器为 32 位，当前仿真描述符及计数器配置最多支持 65535 组。

论文端到端结果应单独记录 CPU 参数计算和四次新增 MMIO 写入成本；仅计 `calc_start` 到完成的 NPU 周期不含这部分时间。

容量策略应先选择 R/W，再调用本计算函数。该函数检查逻辑 tile、IA 槽数及 PS 帧上限，不预测运行数据的压缩比例；它不保证任意压缩工作集都能放入物理 sector pool。压缩容量检查与异常处理仍按原设计执行。


## v14：编码 PS 的容量准入

主机新增 `gempact_plan_capacity()`，按完整 INT32、斜置填充和额外备用帧的最坏占用选择合法 R/W，再计算四个 ABI 2 分组字段。通用驱动的 `DSA_PS_POOL_BYTES=0` 对应旧非编码 PS RAM；编码实验必须指定实际 pool，当前专用驱动配置为 SIZE16/IA64/PS25/pool500736。NPU 未增加配置除法器。该主机修复不提供运行中的换出/checkpoint/恢复，绕过安全规划仍可能报原容量错误。
