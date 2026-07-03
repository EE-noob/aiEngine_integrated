# NPU AXI-Lite Register Map

当前 NPU 配置接口已经统一为标准 AXI-Lite MMIO。寄存器从 NPU 窗口基地址 `0x1000_0000` 的 `0x000` 偏移开始连续定义，驱动侧使用字节偏移，验证侧 UVM 寄存器模型使用等价的 word offset。

## 地址表

| Byte offset | Word offset | Name | Access | Description |
|---:|---:|---|---|---|
| `0x000` | `0x000` | `NPU_REG_CTRL` | RW | 启动、数据位宽、量化模式和 dataflow 控制 |
| `0x004` | `0x001` | `NPU_REG_STATUS` | RO | ready/busy/done/error 状态 |
| `0x008` | `0x002` | `NPU_REG_WB_DATA` | RO | 最近一次完成状态写回 |
| `0x00c` | `0x003` | `NPU_REG_WB_INFO` | RO | bit0 表示写回数据有效 |
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
| `0x0fc` | `0x03f` | `NPU_REG_ID` | RO | 固定为 `0x4e50_5531` |

## CTRL 位定义

| Bit | Name | Description |
|---:|---|---|
| 0 | `NPU_CTRL_START` | 写 1 产生单周期 start pulse |
| 1 | `NPU_CTRL_CFG_16BITS_IA` | LHS/IA 使用 int16 |
| 2 | `NPU_CTRL_PER_CHANNEL` | 量化参数按 channel 读取 |
| 3 | `NPU_CTRL_DATAFLOW_IS` | `1=IS`，`0=WS` |
| 8 | `NPU_CTRL_CLEAR_DONE` | 清除 done sticky |
| 9 | `NPU_CTRL_CLEAR_WB_VALID` | 清除 writeback valid |

## STATUS 位定义

| Bit | Name | Description |
|---:|---|---|
| 0 | `SA_READY` | NPU 计算阵列 ready |
| 1 | `BUSY` | NPU 正在执行 |
| 2 | `NPU_STATUS_DONE` | 本次任务完成 |
| 3 | `WB_VALID` | `NPU_REG_WB_DATA` 有效 |
| 5:4 | `NPU_STATUS_ERR_MASK` | `00=正常`，`01=配置错误`，`10=资源缺失` |
| 7 | `REG_READY` | AXI-Lite 寄存器通路 ready |

## 软件访问示例

```c
dsa_reg_write(NPU_REG_LHS_BASE, (uint32_t)(uintptr_t)lhs);
dsa_reg_write(NPU_REG_RHS_BASE, (uint32_t)(uintptr_t)rhs);
dsa_reg_write(NPU_REG_DST_BASE, (uint32_t)(uintptr_t)dst);
dsa_reg_write(NPU_REG_K, k);
dsa_reg_write(NPU_REG_N, n);
dsa_reg_write(NPU_REG_M, m);

uint32_t ctrl = NPU_CTRL_START | NPU_CTRL_CLEAR_DONE | NPU_CTRL_CLEAR_WB_VALID;
dsa_reg_write(NPU_REG_CTRL, ctrl);

while ((dsa_reg_read(NPU_REG_STATUS) & NPU_STATUS_DONE) == 0u) {
}
```
