# NPU 中断与门控时钟修改记录

日期：2026-07-04

本文记录 NPU AXI-Lite 控制寄存器、中断语义以及 `npu_top` 主动门控时钟的本轮修改。修改目标是精简控制信号、统一软件清除方式，并在 NPU 空闲时关闭核心时钟，降低 FPGA 实现中的无效翻转。

## 1. 修改范围

本次修改涉及以下几类文件：

| 类型 | 主要文件 |
|---|---|
| AXI-Lite 寄存器 | `rtl/axi_accelerator/axi_top/npu_axil_reg_if.sv` |
| NPU 顶层封装 | `rtl/axi_accelerator/axi_top/npu_axil_top.sv` |
| SoC/FPGA 顶层 | `rtl/axi_accelerator/soc_top.sv`、`fpga/vivado/tflm_ai_dsa_soc/rtl/fpga_top.sv` |
| 驱动 | `drivers/dsa_accel.c`、`drivers/dsa_accel.h`、`veri/soc_csrc/dsa_accel_mmio.c`、`veri/soc_csrc/dsa_accel_mmio.h` |
| 仿真环境 | `veri/interface/axil_if.sv`、`veri/tb/top_tb.sv`、`veri/uvc/axil/ai_axil_monitor.sv`、`veri/test/sequence/ai_mem_gen_smoke_seq.sv` |
| Vivado 脚本 | `fpga/vivado/tflm_ai_dsa_soc/scripts/*.tcl`、`scripts/fpga/vivado_synth_soc.tcl` |
| 寄存器说明 | `drivers/registers_v2.md` |

## 2. 中断语义修改

### 2.1 原设计问题

旧版中断控制保留了较多历史信号，包括 32 bit 中断状态、`eoi` 清除输入以及 `CTRL` 寄存器中的清除位。该设计对当前 NPU 只需要完成中断的场景偏复杂，并且软件轮询、中断清除和额外状态位的含义不够统一。

### 2.2 新设计

中断输出精简为单 bit `irq`，并由 `CTRL[4]` 中断使能位控制：

```systemverilog
assign irq = done_sticky && irq_enable;
```

`STATUS` 寄存器保持状态读取，同时对完成状态位支持写清除：

| 寄存器 | 地址 | 权限 | 位 | 含义 |
|---|---:|---|---:|---|
| `NPU_REG_STATUS` | `0x004` | RO/WC | `[2]` | `done_sticky`，写 1 清除 |

`CTRL` 寄存器保留启动、模式配置和中断使能，不再承载中断清除功能。删除冗余状态位后，错误码前移到 `STATUS[4:3]`，寄存器通路 ready 前移到 `STATUS[5]`。软件在启动前清理历史完成状态，在完成读取后再次清理状态；若需要中断输出，启动控制字需要置位 `NPU_CTRL_IRQ_ENABLE`：

```c
dsa_reg_write(NPU_REG_STATUS, NPU_STATUS_DONE);
dsa_reg_write(NPU_REG_CTRL, NPU_CTRL_START | NPU_CTRL_IRQ_ENABLE | mode_bits);
...
dsa_reg_write(NPU_REG_STATUS, NPU_STATUS_DONE);
```

该方式使中断清除和轮询状态保持一致。旧软件若仍使用 `CTRL` 中的清除位，需要同步更新到 `STATUS` 写清除方式。

### 2.3 功能影响

本次中断修改没有裁剪 NPU 的计算功能，也不影响 int8/int16、WS/IS 或 per-channel 量化功能。功能影响主要体现在软件访问协议：完成中断必须通过 `STATUS[2]` 写 1 清除，错误码字段为 `STATUS[4:3]`，中断输出由 `CTRL[4]` 使能。

## 3. 主动门控时钟修改

### 3.1 参数与默认配置

`npu_axil_top` 增加门控参数：

```systemverilog
parameter ENABLE_CLOCK_GATING = 1
```

SoC/FPGA 顶层使用统一参数：

```systemverilog
parameter NPU_ENABLE_CLOCK_GATING = 1
```

Vivado 导出脚本支持通过环境变量覆盖：

```bash
VIVADO_NPU_ENABLE_CLOCK_GATING=0
```

默认值为 `1`，即开启 `npu_top` 主动门控时钟。

### 3.2 门控范围

门控对象是完整 `npu_top` 计算核心。AXI-Lite 寄存器模块保持在系统时钟下工作，因此 CPU 仍可读写配置寄存器、发起启动和清除状态。

门控时钟开启条件包括：

- 复位后的预热周期；
- 存在待启动请求；
- 启动脉冲预热周期；
- NPU 正在计算；
- NPU AXI master 仍存在读写事务。

门控时钟关闭条件为：NPU 已完成、计算核心 ready，并且 AXI master 读写通道空闲。

### 3.3 启动保护

为避免门控时钟关闭时丢失启动脉冲，`calc_start` 不直接送入 `npu_top`。寄存器侧收到启动请求后先保持 `npu_start_pending_q`，打开门控时钟并等待预热，然后在核心时钟可用且 `npu_sa_ready` 为 1 时发出 `npu_core_calc_start`。

该处理会在空闲后首次启动时引入少量固定启动延迟，但不改变计算阶段吞吐。连续任务若核心时钟尚未关闭，启动开销更小。

### 3.4 FPGA 与仿真实现

FPGA 综合使用 Xilinx `BUFGCE`：

```systemverilog
BUFGCE #(
    .SIM_DEVICE("7SERIES")
) u_npu_clk_bufgce (...);
```

Vivado 脚本已增加：

```tcl
set_property verilog_define {SYNTHESIS=1 XILINX_FPGA=1} [current_fileset]
```

通用仿真分支使用锁存式门控模型，避免门控使能在时钟高电平期间变化造成毛刺。

## 4. 验证结果

### 4.1 AXI-Lite 模块级冒烟测试

执行 VCS AXI-Lite 冒烟测试，结果通过：

```bash
make -C /media/proj_tmp/aiEngine_integrated/veri/sim run \
  DUT_MODE=axil case=ai_mem_gen_smoke_test seed=20260704
```

关键结果：

- NPU 正常完成计算；
- 矩阵结果比较通过；
- `STATUS[2]` 写清除验证通过；
- `irq` 在写清除后正确拉低；
- 无 UVM_ERROR / UVM_FATAL。

### 4.2 SoC 运行时测试

执行 SoC C runtime 测试，结果通过：

```bash
make -C /media/proj_tmp/aiEngine_integrated/veri/sim run \
  DUT_MODE=axi_soc SOC_APP=runtime case=ai_axi_soc_c_test
```

关键结果：

- UART 输出 `[soc_rt] PASS`；
- NPU 调用完成；
- `dsa_execute_cycles=2445`；
- 无 UVM_ERROR / UVM_FATAL。

### 4.3 Vivado 综合冒烟测试

执行 Vivado 综合冒烟测试，结果：

- `synth_design completed successfully`；
- 0 Critical Warnings；
- 0 Errors；
- 识别到 1 个 NPU 门控用 `BUFGCE`；
- 综合阶段资源约为 29511 LUT、27808 FF、172.5 BRAM、320 DSP。

该结果为综合阶段检查，最终时序仍以实现后的 timing report 为准。

## 5. 使用注意事项

1. 若软件直接访问 NPU 寄存器，需要使用 `STATUS[2]` 写清除方式，不再使用 `CTRL` 清除位。
2. 若需要排查门控相关问题，可通过 `NPU_ENABLE_CLOCK_GATING=0` 或 `VIVADO_NPU_ENABLE_CLOCK_GATING=0` 暂时关闭。
3. FPGA 工程需要定义 `XILINX_FPGA=1`，以确保使用 `BUFGCE` 实现门控时钟。
4. 门控时钟只关闭 NPU 计算核心，不关闭 AXI-Lite 寄存器，因此配置访问和状态清除不受影响。
5. 本修改不改变 NPU DMA 地址宽度、数据位宽和计算数据流。
