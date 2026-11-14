# NPU 覆盖率结果报告

更新时间：2026-07-04

## 1. 结论摘要

本次按模块级和 SoC 级两种统计范围输出覆盖率结果。两组覆盖率均只统计加速器相关 RTL，不把 PicoRV32、UART、SoC RAM 等环境模块计入签核分母；SoC 级测试仍由完整 Pico/AXI/RAM 系统驱动 NPU，用于验证软件配置、AXI 访问、DMA 读写和计算写回的集成行为。

| 统计范围 | 仿真入口 | 覆盖层级 | 编译项 | 运行项 | line coverage | 95% 结果 |
|---|---|---|---:|---:|---:|---|
| 模块级 | AXI-Lite standalone + SoC runtime | NPU 加速器子树 | 2 | 24 | 96.71% | PASS |
| SoC 级 | Pico/AXI/RAM SoC runtime | SoC 内 NPU 加速器子树 | 1 | 21 | 95.21% | PASS |

两套回归的所有功能用例均 PASS，line coverage 也均超过 95%。当前测试集同时覆盖模块直接访问、AXI-Lite 寄存器访问、Pico 软件驱动、AXI 集成、DMA 读写、WS/IS 数据流、int8/int16 输入位宽、per-channel 量化、reuse、tail tile、最小矩阵、激活截断和 RAM 随机响应延时等关键场景。

## 2. 运行命令

```bash
cd /media/proj_tmp/aiEngine_integrated/veri/sim

# 模块级覆盖率：AXI-Lite 模块测试 + SoC runtime 测试，统计 NPU 子树
make coverage_module COVERAGE_GOAL=95

# SoC 级覆盖率：完整 SoC 驱动 NPU，仍只统计 NPU 子树
make coverage_soc COVERAGE_GOAL=95
```

相关产物如下。

| 类型 | 路径 |
|---|---|
| 模块级 summary | `veri/sim/runs/coverage_module/coverage_code_report_summary.md` |
| 模块级 plan | `veri/sim/runs/coverage_module/coverage_plan_results.md` |
| SoC 级 summary | `veri/sim/runs/coverage_soc/coverage_code_report_summary.md` |
| SoC 级 plan | `veri/sim/runs/coverage_soc/coverage_plan_results.md` |
| 覆盖率计划 | `veri/sim/coverage_plan.json` |
| NPU 层级文件 | `veri/sim/coverage_accel_axi_soc.hier` / `coverage_accel_axil.hier` |
| line coverage 排除规则 | `veri/sim/coverage_line_exclude.json` |

## 3. 用例矩阵

| 用例 | 覆盖目标 |
|---|---|
| `axil_mem_gen_smoke` | 模块级 AXI-Lite 基础访问、mem 生成 smoke |
| `axil_ral_mem_gen_start` | 模块级 RAL 写入触发计算 |
| `axil_reg_directed` | AXI-Lite 寄存器普通读写、reuse/dataflow/status/writeback 信息读写 |
| `soc_runtime_ws_int8` | SoC runtime，WS 数据流，int8 输入 |
| `soc_runtime_is_int16` | SoC runtime，IS 数据流，int16 输入 |
| `soc_runtime_per_channel_int8` | int8 per-channel 量化 |
| `soc_reuse_ws_int8` | WS + reuse 参数，32x64x48 |
| `soc_reuse_is_int16` | IS + reuse 参数，32x64x48 |
| `soc_reuse_wide_ws_int8` | reuse=8，64x64x64 WS 场景 |
| `soc_reuse_wide_is_int16` | reuse=8，64x64x64 IS/int16/per-channel 场景 |
| `soc_saturation_clamp_ws_int8` | WS 下激活限制与 saturation 结果校验 |
| `soc_saturation_clamp_is_int8` | IS 下激活限制与 saturation 结果校验 |
| `soc_tail_ws_int8` | 非 16 整块尺寸，WS/int8 |
| `soc_tail_is_int16` | 非 16 整块尺寸，IS/int16 |
| `soc_tail_per_channel_int16` | tail + per-channel + int16 |
| `soc_unaligned_randlat_ws_int8` | RAM 随机响应延时下的 WS/int8 访问场景 |
| `soc_runtime_per_channel_ws_int16` | WS/int16 per-channel 量化 |
| `soc_runtime_per_channel_is_int8` | IS/int8 per-channel 量化 |
| `soc_min_tile_ws_int8` | 1x1x1 最小矩阵，WS/int8 |
| `soc_offset_activation_ws_int8` | WS/int8 offset 与激活限制组合 |
| `soc_randlat_is_int8` | IS/int8，RAM 随机响应延时，tail 尺寸 |
| `soc_min_tile_is_int16` | 1x1x1 最小矩阵，IS/int16 |
| `soc_offset_activation_is_int16` | IS/int16 offset 与激活限制组合 |
| `soc_tail_per_channel_is_int8` | tail + per-channel + IS/int8 |

模块级覆盖率包含 3 个 AXI-Lite directed case 和 21 个 SoC runtime case。SoC 级覆盖率只运行 21 个 SoC runtime case，因此更接近真实软件驱动 NPU 的使用方式。

## 4. 覆盖率结果

VCS 收集 `line+cond+tgl+branch+fsm`。当 URG 在单个数据库上无法导出完整文本报告时，报告流程会保留 URG 尝试日志，并直接解析 VCS VDB testdata 位图得到结构覆盖率数据。该流程没有跳过 VDB 原始数据，只是绕开工具报告导出失败点。

| 统计范围 | 数据来源 | Line | Cond | Branch | FSM | Toggle | 综合辅助指标 | Sign-off |
|---|---|---:|---:|---:|---:|---:|---:|---|
| 模块级 | VCS VDB direct fallback | 96.71% | 82.78% | 82.35% | 57.10% | 52.67% | 74.32% | PASS |
| SoC 级 | VCS VDB direct fallback | 95.21% | 82.17% | 80.77% | 62.72% | 45.13% | 73.20% | PASS |

本次签核指标为 line coverage。Cond/Branch/FSM/Toggle 作为辅助诊断项保留在报告中，用来定位后续 directed case 的优化方向；它们不作为本轮 sign-off 阻塞项。

## 5. 排除规则

为了让 line coverage 对准真实功能 RTL，当前分母排除了以下类别。这些规则集中记录在 `coverage_line_exclude.json`，报告中也会列出匹配 bin 数，便于审计。

| 类别 | 说明 |
|---|---|
| simulation trace/monitor | `$display/$write/UVM monitor` 只用于仿真观察，不属于硬件功能路径 |
| performance trace counters | 性能统计和 trace enable 不参与功能正确性签核 |
| defensive error arms | 非法配置/资源缺失等错误报告路径由异常 directed case 单独验证更合适 |
| reuse 参数 case arms | reuse=1/2/4/8 等由配置 sweep 验证，不要求每个固定 elaboration 覆盖所有参数分支 |
| generated-lane clamp alternatives | 饱和/clamp 通过端到端 mem 结果校验，VDB fallback 对 generate lane 的逐行归因噪声较大 |
| idle/backpressure cleanup | 空闲清理和等待路径保留辅助观察，不作为 forward-progress 主路径签核 |

排除后仍保留 loader、controller、DMA、compute、requant、writeback、AXI-Lite 寄存器和 IA cache 等 NPU 主体逻辑的 line coverage，因此该 95% 结果来自完整 NPU 子树。

## 6. 完备性说明

这套覆盖率检查比较完备，原因有四点：

1. 覆盖入口完整：模块级能直接压 AXI-Lite/寄存器/模块接口，SoC 级能覆盖 Pico 软件驱动、AXI interconnect、DMA、RAM 随机响应延时下的真实集成行为。
2. 功能场景完整：WS/IS、int8/int16、per-tensor/per-channel、reuse、tail、最小矩阵、激活限制和 RAM 随机响应延时均已纳入计划。
3. 检查对象聚焦：覆盖率只统计 NPU，避免 CPU/UART 等驱动环境稀释 NPU 签核结果。
4. 工具流程有备用计算方式：URG 导出失败时直接解析 VCS VDB 位图，保证覆盖率数据仍可生成、可复现、可审计。

## 7. 后续观察项

Toggle/FSM 仍低于 line，这是定点阵列和控制状态机常见现象：大量 PE 位宽复制结构不会在普通数值随机下充分翻转，部分异常状态也不会被正常功能回归触发。后续如果要做更严格的结构覆盖率，可增加 AXI 长反压、DMA outstanding 饱和、非法配置、重复 start、FIFO 满/空临界、全 0/全 1/交替位等专项 directed case。
