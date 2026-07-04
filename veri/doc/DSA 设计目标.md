# DSA 设计目标与规格说明（Spec v2.0）

> 本文描述当前 AI-DSA / MMA 加速器的设计目标、软件映射、数据类型、内存布局、数据流和可实现性约束。当前版本以 `mma_top` 原生 AXI4 master、统一 `axi_dual_block_dma`、IA cache 分块复用和 WS/IS 数据流切换为准，旧版 ICB 多路器和单 tile 顺序执行模型不再作为顶层设计口径。

---

## 1. 系统定位

AI-DSA 的目标不是孤立的矩阵乘模块，而是在 PicoRV32 SoC 中为 TFLite Micro / NMSIS-NN 提供可配置的端侧推理加速后端。软件通过 AXI-Lite CSR 配置矩阵基址、尺寸、stride、量化参数、数据类型、数据流模式和 reuse 参数；硬件自主完成分块加载、片上缓存复用、脉动阵列计算、重量化、FIFO 打包和 AXI 写回。

核心目标如下：

| 目标 | 当前设计落点 |
|---|---|
| 兼容 NMSIS-NN / TFLM | 面向 matmul、fully connected、conv im2col 后端；软件侧通过 NMSIS-NN ExtraAccFunctions 调用 |
| 支持大矩阵高吞吐 | `SIZE x SIZE` 脉动阵列、分块外积式调度、IA cache、W reuse、PS buffer |
| 降低 DDR/AXI 访存压力 | IA tile 多槽缓存、W/IA 复用窗口、bias/quant 预取、读写 DMA 并行 |
| 支持 WS/IS 数据流 | `cfg_dataflow_mode=0` 为 WS，`cfg_dataflow_mode=1` 为 IS；顶层交换流式 K/M 视角并修正写回顺序 |
| 支持 s8 / s16 输入 | 内部 IA/weight 数据面为 16bit；WS 下 IA 可 s8/s16，IS 下 kernel 侧可按 `cfg_16bits_ia` 读取 16bit LHS |
| FPGA 可综合可收敛 | BRAM/SRL 化 buffer，避免硬件除法，控制预计算，AXI pingpong timing buffer，150 MHz Artix-7 目标 |

---

## 2. 适用范围

当前硬件统一加速逻辑 GEMM：

```text
C[K, M] = A[K, N] x B[N, M]
```

典型软件入口包括：

| 软件场景 | 硬件映射 |
|---|---|
| `riscv_nn_mat_mult_nt_t_s8` | WS/s8 LHS 与 s8 RHS 的矩阵乘 |
| `riscv_nn_mat_mult_kernel_s8_s16` | s16 LHS 与 s8 RHS 的矩阵乘；当前硬件通过 16bit 数据路径支持 |
| `riscv_nn_mat_mult_kernel_row_offset_s8_s16` | 同上，并使用 `dst_row_stride_b` 支持非致密输出行步进 |
| Fully Connected | 直接映射为 GEMM |
| Conv / 1x1 Conv / im2col | im2col 后的矩阵乘由 MMA 执行；小型或 int4 场景可由软件 fallback |

不在当前硬件直接目标内的内容：

- 非矩阵乘类算子仍由 TFLM/NMSIS-NN 软件路径执行。
- int4 当前按软件 fallback 处理，不要求硬件强制支持。
- 浮点和非对称 RHS 零点不是当前高优先级目标；硬件保留 `rhs_zp` 端口用于数据流交换和后续扩展。

---

## 3. 术语约定

本文中的 `L1 group`、`L2 group` 只表示 MMA 内部 IA cache 的分块复用调度层级，不表示 CPU 或 SoC cache 层级。PicoRV32 取指侧缓存统一写作 `CPU I-cache` 或 `PicoRV32 instruction cache`。

| 名称 | 含义 |
|---|---|
| `SIZE` | 脉动阵列边长，也是基本 tile 边长 |
| `IA_CACHE_BLOCKS` | IA cache slot 数，可同时驻留多少个 IA tile |
| `PS_FRAME_COUNT` | PS buffer / 输出 FIFO 可保留的输出帧窗口 |
| `ia_reuse_num` | IA cache group 深度，即一个 group 内连续 IA row-tile 数 |
| `w_reuse_num` | W 侧复用窗口，即同一 IA group 服务的输出列 tile 数 |
| IA cache group / L1 group | 同一归约 tile 下，沿输出行方向连续的一组 IA tile |
| L2 group | 更外层的 IA/W 遍历和回卷组，用于组织 reuse、预取和尾块 |
| WS | Weight Stationary，权重驻留 PE，IA 对角化流入 |
| IS | Input Stationary，输入驻留/交换流视角，需要输出侧转置写回 |

---

## 4. 逻辑矩阵与内存布局

### 4.1 逻辑维度

| 符号 | 含义 |
|---|---|
| `K` | 输出行数，逻辑 A 的行数 |
| `N` | 归约维度，逻辑 A 的列数和 B 的行数 |
| `M` | 输出列数，逻辑 B 的列数 |
| `A` / LHS | 逻辑输入矩阵，形状 `K x N` |
| `B` / RHS / W | 逻辑权重矩阵，形状 `N x M` |
| `C` / DST | 输出矩阵，形状 `K x M` |

### 4.2 物理布局

- LHS/IA 默认按行展平，`lhs_row_stride_b` 是相邻两行首地址的字节距离。
- RHS/W 默认按列展平，每个输出列/channel 对应一段连续的 N 维权重，`rhs_col_stride_b` 是相邻输出列/channel 的字节距离。
- DST 按行主序写回，`dst_row_stride_b` 是相邻输出行首地址的字节距离。
- AXI DMA 允许非对齐基址和 stride，非对齐拼接在 `axi_dual_block_dma` 内部处理。
- 尾行、尾列和尾 beat 由 loader、requant/FIFO 和 OA writer 共同生成 valid/mask，避免写回无效字节。

### 4.3 WS / IS 流视角

| 模式 | IA loader 读取 | kernel loader 读取 | 输出写回 |
|---|---|---|---|
| WS (`cfg_dataflow_mode=0`) | LHS/IA，行展平，可 s8/s16 | RHS/W，列展平，通常 s8 扩展到 16bit | 行主序直接写回 |
| IS (`cfg_dataflow_mode=1`) | RHS 侧数据作为 IA 流输入 | LHS 侧数据作为 kernel 流，可按 `cfg_16bits_ia` 读 16bit | FIFO/OA writer 按转置后的 tile 顺序写回 |

逻辑 GEMM 公式不因 WS/IS 改变。WS/IS 只改变硬件内部谁作为流式 IA、谁作为驻留 kernel，以及输出 tile 的产生顺序。顶层通过 `stream_k/stream_m`、`ia_base_eff/weight_base_eff`、`ia_stride_eff/weight_stride_eff` 和 `oa_writer.is_mode` 保持逻辑结果一致。

---

## 5. 数据类型与量化

| 数据 | 当前硬件语义 |
|---|---|
| IA / LHS | 内部为 signed 16bit；外存可 s8 或 s16，由 `cfg_16bits_ia` 和模式决定 |
| W / RHS | 内部为 signed 16bit；WS 下通常从 s8 RHS 符号扩展，IS 下 kernel 侧可读 s16 LHS |
| Accumulator | signed int32 |
| Bias | signed int32，`bias_base=0` 表示无 bias |
| Quant multiplier/shift | signed int32，支持 per-tensor 与 per-channel |
| Output | signed int8，写回时按 byte mask 处理尾列 |

计算语义为：

```text
acc[i,j] = bias[j] + sum_r ((A[i,r] + lhs_zp) * (B[r,j] + rhs_zp_eff))
out[i,j] = clamp(requant(acc[i,j]) + dst_zp, act_min, act_max, s8)
```

当前 NMSIS-NN 常用路径中 RHS 零点通常为 0；硬件仍保留 `rhs_zp` 以适配 WS/IS 交换和后续扩展。PE 内不做逐拍 int32 饱和，饱和/裁剪发生在 `vec_requant` 输出阶段，匹配 NMSIS-NN accumulator 语义。

---

## 6. 分块外积式数据流

当前硬件以 `SIZE x SIZE` tile 为基本单位，但调度不是简单 tile-by-tile，而是分块外积式复用：

```text
C[i : i+R-1, j : j+W-1] += A[i : i+R-1, r] x B[r, j : j+W-1]
```

其中：

- `R = ia_reuse_num`，由 IA cache 容量、输出行 tile 数和软件配置共同裁剪。
- `W = w_reuse_num`，由 PS/FIFO 窗口、输出列 tile 数和软件配置共同裁剪。
- 当 `cfg_ia_reuse_num=0` 或 `cfg_w_reuse_num=0` 时，硬件使用由参数派生的默认值。
- 非 0 配置会先限制到容量上限，再向下取 2 的幂，避免硬件除法和复杂取模。

复用收益：

- IA tile 读取一次，可服务多个 W/output-column tile。
- W tile 读取一次，可服务多个 IA/output-row tile。
- IA cache 已经缓存好的情况下，cache manager 可以连续输出多个 IA tile，减少 tile 边界气泡。
- PS buffer 保存归约方向 partial sum，后续归约 tile 回灌继续累加。

---

## 7. 顶层执行流程

一次任务的硬件流程如下：

1. 软件写 CSR，配置基址、维度、stride、量化、数据类型、WS/IS 和 reuse。
2. `calc_start` 在 `sa_ready=1` 时拉高一拍。
3. `mma_top` 对 reuse 参数做容量裁剪，并按 WS/IS 生成流式视角。
4. `mma_controller` 下发 `init_cfg_*`，各子模块锁存配置。
5. IA/kernel/bias/quant/OA writer 通过统一 `axi_block_dma_arbiter` 申请 DMA。
6. `axi_dual_block_dma` 通过 AXI4 发出读写 burst，读写通道可同时工作。
7. `ia_loader` 将 IA tile 写入 IA cache，并按 L1 group 连续对角化输出。
8. `kernel_loader` 连续读取 W/LHS block，在内部 RAM 中完成输出方向修正。
9. `compute_core` 完成脉动阵列乘加、bias/partial-sum 选择和 PS buffer 回灌。
10. `vec_requant` 完成 per-tensor/per-channel 重量化和 s8 裁剪。
11. `vec_s8_to_fifo` 打包 s8 结果；IS 模式下 FIFO/写回路径处理转置顺序。
12. `oa_writer` 生成 DMA 写回地址、mask 和数据流。
13. 所有 tile 写回完成后，`done_valid` 与 `sa_ready` 标识任务完成。

---

## 8. SoC 与总线目标

当前 SoC 集成目标：

- PicoRV32、UART、MMA 统一接入 AXI interconnect。
- Pico 和 UART 控制侧可使用 AXI-Lite 简化桥接。
- DMA 读写通道均支持 outstanding，读写能力对等。
- AXI RAM 保持同步一拍读取，不通过额外加 RAM 数据延迟换时序。
- interconnect/RAM 边界使用 pingpong/timing buffer 截断长 ready/valid 路径，同时保持 steady-state 吞吐。

总线优化的核心原则是：通过 outstanding、连续 burst、读写并行和片上复用提高有效 beat 利用率，而不是退回低吞吐状态机。

---

## 9. 参数化与约束

| 参数 | 约束/目标 |
|---|---|
| `SIZE` | 支持 4/8/16 等配置；当前主验证点为 16 |
| `IA_CACHE_BLOCKS` | 控制 IA cache slot 数；默认 IA reuse 上限为 `IA_CACHE_BLOCKS/2` |
| `PS_FRAME_COUNT` | 控制 PS/FIFO 输出窗口；影响 W reuse 上限 |
| `OA_FIFO_BANKS_MAX` | 写回 FIFO bank 上限，默认从 IA cache 深度派生 |
| `AXI_READ_OUTSTANDING` | AXI 读 outstanding 深度，当前常用 4 |
| `AXI_WRITE_OUTSTANDING` | AXI 写 outstanding 深度，默认等于读 outstanding |

设计规则：

- 运行期不使用硬件除法。
- reuse 配置按 2 的幂处理，便于移位和 mask。
- 大型 buffer 优先使用同步 RAM/BRAM。
- 规则延迟线优先使用 SRL。
- 大数据数组不做无意义全量复位，只复位 valid/tag/pointer。
- 插入流水必须保持 steady-state throughput，不允许为了时序降低总线或计算吞吐。

---

## 10. 验证目标

必须覆盖：

- 小尺寸、尾行、尾列、非整除 K/N/M。
- 不同 `SIZE`、`IA_CACHE_BLOCKS`、`PS_FRAME_COUNT`。
- `cfg_ia_reuse_num/cfg_w_reuse_num=0` 默认派生与非 0 配置。
- WS/IS 两种模式。
- s8 与 s16 数据路径。
- per-tensor 与 per-channel quant。
- 非对齐地址与非致密 stride。
- 随机 DDR 延迟模型和一拍同步 RAM 模型。
- SoC 大矩阵随机回归、TFLM MLP、MNIST CNN、Conv im2col batch32。
- 性能统计只统计推理计算窗口，避免把模型初始化时间计入 DSA 性能。

当前已验证的关键 smoke：

```text
SIZE=16, IA_CACHE_BLOCKS=4, PS_FRAME_COUNT=16
K=N=M=64, WS, s8, per-tensor
结果 PASS，dsa_execute_cycles=6149
```

当前选定的最终可综合实现状态：

```text
Vivado project: tflm_ai_dsa_soc_s16_c4_icache_pipe_syncrst_v6
Device: xc7a200tfbg484-3
Core clock: 150 MHz
Timing: WNS=+0.055 ns, TNS=0
DRC: bitstream generated；无 Error/Critical Warning；仍保留 REQP-1840 RAM async-control Warning
Utilization: Slice LUT=27755, Slice Registers=31339, BRAM Tile=173, DSP=320
Bitstream: generated successfully
```

最终基线选择理由：`syncrst_v6` 满足当前 `WNS >= +0.05ns` 目标，并且面积低于 `syncrst_v5`；`syncrst_v8` 清理了 REQP-1840，但 WNS 下降到 `+0.037ns`，低于本阶段余量目标。因此本阶段停止继续追 `+0.1ns`，以 `syncrst_v6` 作为可交付版本。

---

## 11. 设计完成判据

当前阶段的完成判据为：

- 功能：MMA 随机回归、SoC 大矩阵回归和 TFLM 模型回归通过。
- 性能：硬件加速相对纯软件有明确收益，并能解释不同 `SIZE/CACHE_BLOCKS` 下阵列利用率与总线利用率变化。
- 面积：MMA/SoC 资源在 Artix-7 上可实现，历史目标为 MMA 相关逻辑压到 35000 LUT 以内。
- 时序：150 MHz Vivado implementation WNS/TNS 转正，最终基线 WNS 达到 `+0.05ns` 级别；RAM async-control 类 DRC 继续作为后续清理项跟踪。
- 文档：设计目标、模块文档、性能报告、面积报告、时序报告与当前 RTL 一致。
