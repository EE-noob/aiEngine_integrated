# AI-DSA MMA 模块设计文档（v2.0）

> 本文面向 RTL 联调、驱动编写、验证和综合实现，记录当前 `mma_top` 及其主要子模块的端口语义、握手约定、数据流和实现约束。当前顶层为原生 AXI4 master，多个 loader/writer 通过统一 `axi_block_dma_arbiter + axi_dual_block_dma` 访问内存；旧版 `icb_mux_5to1` 顶层仲裁模型已废弃。

---

## 0. 全局约定

### 0.1 时钟、复位与编码

- `clk` 上升沿有效。
- 顶层复位为 `rst_n`，低有效。为便于 BRAM 推断和时序收敛，关键 RAM 地址、使能、valid、tag、pointer 等控制寄存器尽量使用同步复位语义。
- 顶层控制寄存器、基址、维度、stride、zero point、multiplier、shift 均使用 `REG_WIDTH`，当前默认 32bit。
- 总线数据宽度为 `BUS_WIDTH`，当前默认 32bit。
- 内部 IA 和 kernel 数据面为 signed 16bit，accumulator / bias 为 signed 32bit，输出为 signed 8bit。

### 0.2 L1/L2 术语

本文中的 L1/L2 只表示 MMA 内部 IA cache 的分块复用调度层级，不表示 CPU 或 SoC cache 层级。CPU 取指缓存统一写作 `CPU I-cache` 或 `PicoRV32 instruction cache`。

| 术语 | 当前含义 |
|---|---|
| IA cache | `ia_loader_cache_mgr` 内部多 slot 同步 RAM，用于保存 IA tile |
| L1 group / IA cache group | 同一归约 tile 下，沿输出行方向连续的一组 IA tile |
| L2 group | 更外层的 IA/W 遍历和回卷组 |
| `ia_reuse_num` | L1 group 中 IA tile 数 |
| `w_reuse_num` | 同一 IA group 服务的输出列 tile 数 |

### 0.3 握手语义

| 信号类型 | 语义 |
|---|---|
| `init_cfg_*` | 单拍配置锁存脉冲，子模块必须在该拍采样配置 |
| `load_*_req` | 子模块向 DMA 仲裁器/控制器申请访存 |
| `load_*_granted` | 仲裁器/控制器授权该模块发起 DMA 事务 |
| `send_*_trigger` | 控制器触发已经缓存好的流开始输出 |
| `*_done` / `*_sending_done` | 单拍或短脉冲完成指示，用于推进控制状态 |
| `valid/ready` | 数据流握手，只有 `valid && ready` 同拍为 1 才完成传输 |

### 0.4 数据流总览

```text
CSR/calc_start
  -> mma_top 配置裁剪与 WS/IS 视角生成
  -> mma_controller 下发 init_cfg 与 send_trigger
  -> ia_loader / kernel_loader / bias_loader / vec_requant / oa_writer 请求 DMA
  -> axi_block_dma_arbiter 选择读 client，OA writer 独占写 client
  -> axi_dual_block_dma 发 AXI4 AR/R/AW/W/B
  -> IA cache 连续对角化输出 + kernel 权重输出
  -> compute_core / PS buffer
  -> vec_requant
  -> vec_s8_to_fifo
  -> oa_writer DMA 写回
  -> done_valid / sa_ready
```

---

## 1. 顶层 `mma_top`

### 1.1 参数

| 参数 | 当前默认 | 说明 |
|---|---:|---|
| `WEIGHT_WIDTH` | 16 | kernel 输出到阵列的内部位宽；WS 下 s8 RHS 符号扩展，IS 下可承接 16bit LHS |
| `DATA_WIDTH` | 16 | IA 内部位宽 |
| `SIZE` | 16 | 脉动阵列边长和 tile 边长 |
| `BUS_WIDTH` | 32 | AXI 数据宽度 |
| `REG_WIDTH` | 32 | 地址/配置寄存器位宽 |
| `IA_CACHE_BLOCKS` | 4 | IA cache slot 数，默认 IA reuse 上限为 `IA_CACHE_BLOCKS/2` |
| `PS_FRAME_COUNT` | `SIZE` | PS/FIFO 可保留的输出列 tile 窗口 |
| `AXI_READ_OUTSTANDING` | 4 | AXI 读 outstanding 深度 |
| `AXI_WRITE_OUTSTANDING` | `AXI_READ_OUTSTANDING` | AXI 写 outstanding 深度 |
| `OA_FIFO_BANKS_MAX` | `max(4, IA_CACHE_BLOCKS)` | 写回 FIFO bank 上限 |

`ICB_LEN_W` 仅为 legacy wrapper 参数，原生 AXI 数据通路不使用。

### 1.2 主要外部端口

| 端口 | 方向 | 说明 |
|---|---|---|
| `calc_start` | In | 单拍任务启动。只有 `sa_ready=1` 时会被接受 |
| `cfg_16bits_ia` | In | LHS/IA 16bit 使能。WS 下作用于 IA 侧，IS 下作用于 kernel 侧 |
| `cfg_dataflow_mode` | In | `0=WS`，`1=IS` |
| `cfg_ia_reuse_num` | In | IA cache group 深度。0 表示使用硬件默认派生 |
| `cfg_w_reuse_num` | In | W 侧复用窗口。0 表示使用硬件默认派生 |
| `sa_ready` | Out | 顶层可接受下一任务 |
| `done_valid/done_ready/err_code` | Out/In | 任务完成与状态返回 |
| `lhs_base/rhs_base/dst_base/bias_base` | In | LHS/RHS/DST/Bias 字节基址 |
| `lhs_zp/rhs_zp/dst_zp` | In | zero point / output offset |
| `q_mult_pt/q_shift_pt/use_per_channel` | In | per-tensor 或 per-channel 量化配置 |
| `k/n/m` | In | 逻辑 GEMM 维度，`C[K,M]=A[K,N]xB[N,M]` |
| `lhs_row_stride_b/rhs_col_stride_b/dst_row_stride_b` | In | LHS 行步长、RHS 列/channel 步长、DST 行步长 |
| `m_axi_*` | AXI4 master | MMA 对 SoC RAM/DDR 的原生 AXI4 读写接口 |

### 1.3 配置裁剪

`mma_top` 在接受 `calc_start` 后用三级配置流水生成运行配置：

1. 根据 `cfg_dataflow_mode` 生成流式视角：
   - WS：`stream_k = k`，`stream_m = m`
   - IS：`stream_k = m`，`stream_m = k`
2. 根据矩阵 tile 数、`IA_CACHE_BLOCKS` 和 `PS_FRAME_COUNT` 计算 reuse 容量上限。
3. 对 `cfg_ia_reuse_num/cfg_w_reuse_num` 做裁剪和向下取 2 的幂。

默认规则：

```text
IA_REUSE_NUM_MAX = max(1, IA_CACHE_BLOCKS / 2)
W_REUSE_NUM_MAX  = max(1, PS_FRAME_COUNT)
cfg_*_reuse_num = 0 时使用对应容量上限
```

### 1.4 WS/IS 地址视角

| 模式 | IA 侧 | kernel 侧 |
|---|---|---|
| WS | `lhs_base/lhs_row_stride_b/lhs_zp/cfg_16bits_ia` | `rhs_base/rhs_col_stride_b/rhs_zp/s8` |
| IS | `rhs_base/rhs_col_stride_b/rhs_zp/s8` | `lhs_base/lhs_row_stride_b/lhs_zp/cfg_16bits_ia` |

逻辑结果仍是 `C[K,M]`。IS 模式只改变内部数据驻留和输出产生顺序，最终由 FIFO/OA writer 修正写回布局。

---

## 2. 控制器 `mma_controller`

`mma_controller` 是任务级调度器，不直接产生 AXI 命令。它负责：

- 接受 `ctrl_calc_start`，拉低 `sa_ready`。
- 下发 `init_cfg_ia/init_cfg_weight/init_cfg_bias/init_cfg_requant/init_cfg_oa`。
- 根据 `ia_data_valid`、`weight_data_valid`、`bias_group_valid`、`quant_params_valid`、`fifo_full_flag`、`oa_calc_over` 推进状态。
- 产生 `send_ia_trigger` 和 `send_weight_trigger`。
- 通过 `done_valid/done_ready/err_code` 上报任务完成。

当前访存仲裁不再由控制器的 `icb_sel` 完成，而是由 `axi_block_dma_arbiter` 负责。控制器仍保留“先加载、后触发、写回完成再推进”的上层语义。

---

## 3. 统一 DMA

### 3.1 `axi_block_dma_arbiter`

`axi_block_dma_arbiter` 将 IA、kernel、bias、quant 四个读 client 和 OA writer 写 client 接到一个 `axi_dual_block_dma`。

读 client 优先级当前为：

```text
kernel -> quant -> IA -> bias
```

OA writer 使用独立写通道，读 DMA 和写 DMA 可以同时活跃。这样 loader 读和输出写回不再互相串行阻塞。

主要 client 接口：

| client | 方向 | 说明 |
|---|---|---|
| IA | Read | 读取 IA tile，写入 IA cache slot |
| kernel | Read | 读取 W/LHS block，写入 kernel buffer |
| bias | Read | 读取 int32 bias group |
| quant | Read raw | 读取 per-channel multiplier/shift |
| OA | Write | 接收 FIFO 打包数据并写回 DST |

### 3.2 `axi_dual_block_dma`

`axi_dual_block_dma` 是原生 AXI4 读写 DMA：

- Read engine：AXI `AR/R`，支持 row stride、burst、s8/s16 解包、zero point 加法、非对齐拼接、read outstanding。
- Write engine：AXI `AW/W/B`，支持 row stride、byte mask、write outstanding。
- Raw read：用于 quant 等 32bit 参数读取，不走 IA/kernel 解包。
- 非对齐访问在 DMA 内部处理，外部模块不再需要额外非对齐补丁端口。

读侧输出：

| 信号 | 说明 |
|---|---|
| `wr_slot` | IA cache slot 或 client slot |
| `wr_row` | tile 内行号 |
| `wr_col_base` | 本 beat 对应的 tile 内列起点 |
| `wr_data[]` | 解包后的 signed 16bit 数据 |
| `wr_valid[]` | lane 有效标记 |
| `rd_raw_data/rd_raw_valid` | raw 32bit 参数读流 |

---

## 4. IA Loader

IA loader 由顶层 `ia_loader`、控制器 `ia_loader_ctrl`、缓存管理器 `ia_loader_cache_mgr` 和可选内部 `block_dma` 组成。当前 SoC 集成使用 `EXTERNAL_DMA=1`，由统一 AXI DMA 供数。

### 4.1 端口摘要

| 端口 | 方向 | 说明 |
|---|---|---|
| `init_cfg` | In | 锁存维度、基址、stride、zero point、reuse |
| `load_ia_req/load_ia_granted` | Out/In | 申请并获得 IA 读 DMA |
| `send_ia_trigger` | In | 触发当前已缓存 IA group 输出 |
| `k/n/m` | In | 流式视角下的矩阵维度 |
| `lhs_base/lhs_row_stride_b/lhs_zp` | In | 当前 IA 侧基址、行步长和 zero point |
| `use_16bits` | In | 当前 IA 侧外存元素是否为 s16 |
| `bias_by_row_mode` | In | IS 下 bias 以行/group 方式组织 |
| `ia_reuse_num/w_reuse_num` | In | 已裁剪 reuse 参数 |
| `ext_dma_*` | Out/In | 外部统一 DMA 接口 |
| `ia_out[SIZE]` | Out | 对角化后的 IA 向量 |
| `ia_row_valid` | Out | 对齐到最后一列的数据有效 |
| `ia_tile_start` | Out | 单 tile 首行发射标记 |
| `ia_sending_done` | Out | 整个 IA cache group 输出完成 |
| `ia_l1_switch` | Out | IA cache group 切换边界 |

### 4.2 IA cache

`ia_loader_cache_mgr` 使用 `CACHE_BLOCKS` 个 slot 保存 IA tile。每个 slot 逻辑上为 `SIZE x SIZE`，内部按列 bank 使用同步 RAM。写入来自 DMA 解包，读取按对角化顺序输出到脉动阵列。

状态语义：

- `blk_valid`：slot 数据已经加载完成。
- `blk_busy`：slot 正在输出或仍在 reuse 生命周期内。
- `wr_slot_ptr`：下一组加载起始 slot。
- `rd_slot_base`：当前 IA cache group 输出起始 slot。

### 4.3 L1 group 连续输出

旧版 IA loader 每次只发送一个 tile，tile 之间有空拍。当前 cache manager 接收：

```text
l1_start, l1_slot_start, l1_slot_end, l1_is_init, l1_calc_done
```

之后自主完成整个 IA cache group 输出。col0 每拍发射下一行，其余列通过 shift-register 延迟形成对角化。一个 tile 最后一行发出后的下一拍可以直接发下一个 tile 第一行，从而减少脉动阵列重新填充气泡。

完成信号语义：

- `tile_done`：单个 tile 最后一行到达最后一列。
- `l1_done` / `ia_sending_done`：整个 L1 group 最后一行到达最后一列。

### 4.4 预取与释放

IA loader 支持在 S_SEND 阶段预取下一组 IA tile。`spare_capacity` 满足时，下一组可在当前组复用期间后台加载；最后一次 reuse 完成后当前 group slot 立即释放。配置必须保证不会覆盖仍在输出或仍需 reuse 的 slot。

---

## 5. Kernel Loader

`kernel_loader` 负责读取 W/RHS 或 IS 模式下的 LHS，并向 `ws_systolic_array` 输出权重行。当前使用 `EXTERNAL_DMA=1`。

### 5.1 端口摘要

| 端口 | 方向 | 说明 |
|---|---|---|
| `init_cfg` | In | 锁存维度、基址、stride、zero point、reuse |
| `load_weight_req/load_weight_granted` | Out/In | 申请并获得 kernel 读 DMA |
| `send_weight_trigger` | In | 触发当前 block 输出到阵列 |
| `rhs_base/rhs_row_stride_b/rhs_zp` | In | 当前 kernel 侧基址、步长和 zero point |
| `use_16bits` | In | 当前 kernel 侧外存元素是否为 s16 |
| `ia_reuse_num/w_reuse_num` | In | 复用调度参数 |
| `ext_dma_*` | Out/In | 外部统一 DMA 接口 |
| `weight_out[SIZE]` | Out | 输出给阵列的 signed 16bit 权重向量 |
| `store_weight_req` | Out | 与 `weight_out` 同拍，阵列锁存权重 |
| `weight_sending_done` | Out | 当前 block 输出完成 |
| `weight_data_valid` | Out | 当前 block 已加载可发送 |

### 5.2 列展平到阵列输出

硬件约定 RHS/W 侧按列/channel 展平，使 DMA 能沿 N 方向连续读取。`kernel_loader_buffer` 用同步 RAM 保存读取结果，并在发送时按阵列需要的方向输出，完成“连续 DMA 读取”和“阵列转置输出”之间的映射。

关键点：

- 不要求软件对 RHS 做大规模 repack。
- s8 数据在 DMA 中符号扩展并加 zero point。
- s16 数据用于 IS 下 kernel 侧读取 LHS。
- buffer 只保存当前 W block，不维护 IA loader 那样的多 slot cache，以控制面积。

---

## 6. Bias Loader

`bias_loader` 读取 signed int32 bias，支持 WS 的单列 tile bias，也支持 IS 下按 IA reuse group 读取多行 bias。

主要接口：

| 端口 | 说明 |
|---|---|
| `bias_base` | bias 字节基址，0 表示无 bias |
| `bias_step_blocks` | IS 下每次切换的 bias group block 数 |
| `bias_switch` | IA group 切换时驱动 bias group 更新 |
| `bias_sleep` | 非 init 累加阶段屏蔽 bias |
| `bias_last_loop` | 最后一轮 bias loop 标记 |
| `bias_valid` | 当前单 tile bias 有效 |
| `bias_group_valid` | 当前 group bias 有效 |
| `data_out[SIZE]` | WS 下当前输出列 tile bias |
| `group_data_out[]` | IS 下 group bias 数据 |

面积和时序约束：

- 大 bias bank 不做全量异步复位。
- 写入侧有本地流水，截断 DMA 响应到 bank RAM 的长路径。
- valid/tag 与 data 分离，避免用 valid 组合门控大数据总线。

---

## 7. Compute Core 与 PS Buffer

`compute_core` 连接 IA 对角化流、kernel 权重流、bias/partial-sum 和脉动阵列。

### 7.1 `ws_systolic_array`

- `SIZE x SIZE` PE 阵列。
- `store_weight_req` 同拍锁存 `weight_out[SIZE]`。
- `ia_row_valid` 驱动 IA 对角化流进入阵列。
- PE 内使用 DSP 乘加，输出 int32 accumulator。
- 不在 PE 内做逐拍饱和，保持 NMSIS-NN int32 accumulator 语义。

### 7.2 `ps_buffer`

PS buffer 保存归约方向 partial sum，并在后续 K/N tile 中回灌：

- init group 使用 bias 作为 `sum_in`。
- 非 init group 从 PS buffer 读取上一轮 partial sum。
- IA cache group 切换由 `ia_l1_switch` / `ia_tile_start` 辅助对齐。
- 最终结果送入 `vec_requant`。
- 存储采用同步 RAM/BRAM，避免大规模寄存器 FIFO。

---

## 8. Vec Requant

`vec_requant` 将 int32 accumulator 转换为 int8 输出，支持 per-tensor 和 per-channel。

输入配置：

| 端口 | 说明 |
|---|---|
| `cfg_per_channel` | 1 表示 per-channel quant |
| `cfg_dataflow_mode` | WS/IS 下选择量化参数索引方向 |
| `activation_min/max` | 激活裁剪范围 |
| `dst_offset_in` | 输出 zero point |
| `multiplier_in/shift_in` | per-tensor 参数 |
| `dma_* raw` | per-channel 参数读取接口 |
| `ia_reuse_num_in` | IS/复用场景下的索引辅助 |

流水阶段：

1. 接收 `in_vec_s32[SIZE]`。
2. 选择 per-tensor 或 per-channel multiplier/shift。
3. 多级乘法和 rounding shift。
4. 加 `dst_offset`。
5. clamp 到 activation 区间并饱和到 int8。

配置寄存器按 lane 局部复制，降低跨 16 lane 的长扇出。

---

## 9. `vec_s8_to_fifo`

`vec_s8_to_fifo` 将 `SIZE` 个 s8 输出打包成 32bit AXI 写数据，并在 tile 级别暂存输出。

主要功能：

- 输入 `requant_out[SIZE]` 和 `requant_out_valid`。
- 以 4 个 s8 为一个 32bit beat 打包。
- 根据 `vec_valid_num_col/row` 产生尾列 byte mask。
- `transpose_mode=is_mode` 时按 IS 写回顺序调整 FIFO 输出。
- `reserve_banks=ia_reuse_num_eff` 保留必要 bank，避免 deep reuse 下覆盖未写回结果。
- 存储使用 banked 同步 RAM/BRAM，避免寄存器海。

---

## 10. OA Writer

`oa_writer` 是当前 DMA 兼容写回模块，不再假设 tile 连续线性写。

### 10.1 端口摘要

| 端口 | 说明 |
|---|---|
| `init_cfg` | 锁存输出基址、stride、K/M、reuse、模式 |
| `write_oa_req/write_oa_granted` | 向 DMA 仲裁器申请写通道 |
| `oa_fifo_req` | 请求 FIFO 输出数据 |
| `vec_valid_num_col/row` | 当前 tile 有效列/行数 |
| `output_valid/output_ready` | FIFO 到 writer 的 beat 级握手 |
| `output_mask/output_data` | 32bit 写数据和 byte mask |
| `dma_*` | 写 DMA 命令和写数据流 |
| `write_done/oa_calc_over` | 单次写事务完成与整个输出完成 |

### 10.2 写回顺序

WS 模式：

- 输出 tile 按逻辑 row tile、col tile 遍历。
- `dst_base + row * dst_row_stride_b + col` 生成行主序地址。
- 尾列由 `output_mask` 屏蔽。

IS 模式：

- FIFO 不能简单流式连续输出。
- writer 根据 `is_mode`、`ia_reuse_num`、tile row/col 和 row stride 重新组织地址。
- 目标仍是最终 `C[K,M]` 行主序布局。

---

## 11. SoC 侧模块

当前 SoC 集成由以下模块组成：

| 模块 | 作用 |
|---|---|
| `soc_top.sv` | 顶层只保留实例化和连接 |
| `pico_native_to_axi.sv` | Pico native memory 访问转 AXI，尽量按通道 ready/valid 直接握手 |
| `soc_axi_interconnect.sv` | CPU、UART、MMA 到 RAM 的 AXI 仲裁，支持 outstanding |
| `soc_axi_pingpong_buffer.sv` | 截断 interconnect/RAM 边界长路径 |
| `soc_axi_ram.sv` | 同步一拍读 AXI RAM，支持 read/write outstanding |
| `soc_axil_ctrl.sv` | 软件 CSR 到 MMA 配置口 |
| `soc_axil_simpleuart.sv` | UART AXI-Lite 外设 |

原则：

- RAM 不额外增加数据返回延迟。
- 时序优化主要放在 pingpong/timing buffer 和本地控制寄存。
- CPU I-cache 是 CPU 取指优化，和 MMA IA cache 概念分开。

---

## 12. 参数化与边界处理

必须保持真正参数化：

| 维度 | 要求 |
|---|---|
| `SIZE` | 地址宽度、valid 行列、FIFO 打包、PS buffer、kernel buffer 均随参数变化 |
| `IA_CACHE_BLOCKS` | IA cache slot、reuse 上限、OA FIFO bank 上限同步变化 |
| `PS_FRAME_COUNT` | W reuse 和 PS/FIFO 窗口同步变化 |
| s8/s16 | DMA 解包、列起点、burst 长度、zero point 都要随元素字节数变化 |
| 非整除 K/N/M | loader 补零、requant tile done、FIFO mask、OA writer 地址均正确 |
| 非对齐地址 | `axi_dual_block_dma` 内部拼接处理 |
| WS/IS | 顶层基址交换、kernel 数据位宽、bias group、quant 索引、FIFO/OA writer 转置均一致 |

---

## 13. 面积与时序实现规则

### 13.1 面积规则

- 大型 buffer 使用同步 RAM/BRAM。
- 规则延迟使用 SRL。
- 大数组不做全量复位，只复位 valid/tag/pointer。
- 避免多层嵌套 `for` 组合展开形成巨型 mux。
- FIFO bank 数随 `IA_CACHE_BLOCKS` 派生，不为小 cache 配置实例化过多 bank。

### 13.2 时序规则

- 不使用硬件除法。
- 运行期 group 计算使用移位、mask、比较和配置期预计算。
- 总线路径用 pingpong/timing buffer 截断。
- RAM 地址、使能、写数据尽量本地打一拍。
- 插入流水必须保持 steady-state throughput，不能因时序优化降低持续吞吐。
- BRAM 相关控制寄存器尽量同步复位，减少 Vivado RAMB async control DRC。

---

## 14. 验证与性能统计接口

仿真环境以 VCS + Verilator 兼容统一 TB 为目标。SoC C runtime 生成 memory image，仿真中直接检查内存结果。

常用统计：

| plusarg | 说明 |
|---|---|
| `+MMA_UTIL_TRACE` | MMA active window、IA/acc/requant/FIFO/AXI 周期统计 |
| `+MMA_CTRL_UTIL` | 控制器状态与 stall 统计 |
| `+SOC_AXI_STATS` | SoC AXI 仲裁等待、MMA/CPU 争用 |
| `+SOC_CPU_AXI_STATS` | CPU 取指/数据访问、CPU I-cache hit/miss |
| `+MMA_DMA_TRACE` | DMA AR/R/AW/W/B 事务统计 |

性能统计口径：

- DSA 性能只统计推理计算窗口，不把模型初始化和数据准备计入。
- 对比纯软件时，可通过关闭 NMSIS 加速宏走软件 fallback。
- 大矩阵、不同 `SIZE/CACHE_BLOCKS`、不同随机 DDR 延迟都需要单独扫。

当前 smoke 参考：

```text
SIZE=16, IA_CACHE_BLOCKS=4, PS_FRAME_COUNT=16
K=N=M=64, WS, s8, per-tensor
PASS, dsa_execute_cycles=6149
```

---

## 15. 当前 Vivado 实现状态

当前选定最终基线为 `syncrst_v6`，已完成 route、report 和 bitstream 导出：

| 指标 | 结果 |
|---|---:|
| 目标频率 | 150 MHz |
| WNS | +0.055 ns |
| TNS | 0.000 ns |
| Slice LUT | 27755 |
| Slice Registers | 31339 |
| BRAM Tile | 173 |
| DSP | 320 |

最终基线选择比较：

| 候选 | WNS | 面积/告警 | 结论 |
|---|---:|---|---|
| `syncrst_v5` | +0.073 ns | LUT 略高，REQP-1839/1840 均保留 | 时序最好，但面积和 DRC 口径不如 v6 |
| `syncrst_v6` | +0.055 ns | 27755 LUT / 31339 FF，仅保留 REQP-1840 Warning | 当前最终版本 |
| `syncrst_v8` | +0.037 ns | 27722 LUT / 31376 FF，REQP-1840 已清理 | DRC 更干净，但低于 `+0.05ns` 余量目标 |

本阶段不再继续追 `+0.1ns`。为了优先保证时序余量、面积目标和可复现的 bitstream，当前 RTL 已回到 `syncrst_v6` 基线。该版本仍有 RAM async-control Warning，需要在下一阶段用更细粒度的同步 RAM 控制清理，但它不阻塞 bitstream 生成，也不影响当前功能 smoke。

---

## 16. 旧文档口径清理

以下旧口径不再适用于当前设计：

- 顶层 `icb_mux_5to1` 统一主口模型。
- `sa_icb_cmd/sa_icb_rsp` 作为当前 MMA 顶层主接口。
- `data_setup` 作为主要对角化模块。当前 IA loader 已内置对角化输出。
- RHS 永远固定 s8 且硬件不能处理 kernel 侧 16bit 的说法。
- OA writer 连续线性写 tile 的假设。
- IA loader 单 tile 发送、`ia_sending_done` 每 tile 拉高的语义。

当前 RTL、驱动、TB 和报告应统一按本 v2.0 文档维护。
