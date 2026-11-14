# 设计报告配图与图表清单

本文档列出可插入《基于 PicoRV32 与优化 NPU 的异构处理器设计报告》的图形源文件、用途、绘图提示词和建议替换位置。图形风格统一为白色背景、工程报告样式、中文标签与英文信号名混排，架构图使用多色区分控制、存储、计算和 DMA 单元。

## 1. 系统与模块架构图

| 编号 | 图名 | 源文件 | 用途 | 建议插入位置 |
| --- | --- | --- | --- | --- |
| 图 3-1 | PicoRV32 与 NPU 异构 SoC 总体架构图 | `mermaid/fig01_system_arch.mmd` | 展示 CPU、AXI 互连、RAM、外设、AXI-Lite CSR 与 MMA/NPU 数据面的连接关系。 | `## 3. CPU 与 NPU 异构 SoC 总体架构` 开头段落之后，可补充或替换现有 Mermaid 架构草图。 |
| 图 5-1 | MMA/NPU 内部模块结构图 | `mermaid/fig02_npu_module_arch.mmd` | 展示 `mma_axil_top`、`csr_unit`、`mma_controller`、loader、compute、requant、writer 与 DMA 的组成关系。 | `## 5. NPU 总体架构` 首段之后，用于替代过长的模块枚举文字。 |
| 图 9-1 | 分块矩阵乘数据通路图 | `mermaid/fig03_blocked_dataflow.mmd` | 表达 LHS、RHS、bias、partial sum、重量化和输出写回的数据流向。 | `## 9. 性能优化结构与访存瓶颈缓解设计` 之前，或 `### 16.3` 至 `### 16.7` 的连续时序说明之前。 |
| 图 11-1 | CPU/NPU 协同执行流程图 | `mermaid/fig04_cpu_npu_flow.mmd` | 展示 CPU 配置、NPU 锁存配置、DMA、计算、写回、done/error 状态返回的完整控制过程。 | `## 11. CPU/NPU 协同执行流程` 开头段落之后。 |
| 图 7-1 | `mma_controller` 状态机图 | `mermaid/fig05_mma_controller_fsm.mmd` | 展示控制器从 `IDLE` 到配置、加载、计算、重量化、写回、完成和错误退出的状态转移。 | `### 7.8 mma_controller模块设计` 中 `7.8.4 工作流程与状态机` 之后。 |

AI 绘图 Prompt 可用于生成不可编辑的位图版本；报告正文优先插入 Mermaid 渲染图。

图 3-1 Prompt：

```text
白色背景的数字 IC 工程报告架构图，主题为 PicoRV32 与矩阵计算 NPU 异构 SoC。图中包含 PicoRV32、pico_native_to_axi、soc_axi_interconnect、soc_axi_ram、UART、SOC 控制寄存器、mma_axil_top、csr_unit、mma_top、axi_dual_block_dma。使用中文模块说明，信号名使用英文，箭头清晰表示 AXI-Lite 控制访问和 AXI4 数据访问，控制模块为蓝色，互连为黄色，存储为绿色，NPU 为紫色，线条细致，适合 Word 和 PDF。
```

图 5-1 Prompt：

```text
白色背景的数字 IC 模块结构图，主题为 MMA/NPU 内部组成。图中包含 CSR、控制状态机、IA loader、IA cache、kernel loader、weight buffer、bias loader、compute core、16x16 脉动阵列、partial sum buffer、vec_requant、vec_s8_to_fifo、oa_writer、DMA arbiter 和 axi_dual_block_dma。图形采用工程方框与方向箭头，中文标签，英文信号名，使用不同颜色区分配置、控制、加载、计算和 DMA 单元。
```

图 9-1 Prompt：

```text
白色背景的数据通路图，主题为量化 GEMM 分块计算。左侧为 LHS/RHS/bias 外存，中心为统一块 DMA、IA cache、权重缓存、bias buffer、16x16 脉动阵列和 partial sum buffer，右侧为重量化、输出 FIFO、写掩码生成和 DST 写回。箭头表现数据读取、累加回灌、最终输出写回，中文标签，线条清晰，适合正式技术报告。
```

图 11-1 Prompt：

```text
白色背景的 CPU-NPU 协同流程图，主题为 PicoRV32 配置矩阵计算任务并读取完成状态。流程包含写输入数据、写 CSR、写 start、NPU 锁存配置、DMA 读取、脉动阵列计算、partial sum、重量化、DMA 写回、done/status/error 返回、CPU 清除状态。中文节点，英文寄存器和信号名，流程方向自上而下，工程风格。
```

图 7-1 Prompt：

```text
白色背景的硬件状态机图，主题为 mma_controller。状态包括 IDLE、CONFIG、LOAD_IA、LOAD_W、LOAD_BIAS、COMPUTE、REQUANT、WRITE_BACK、DONE、ERROR。箭头标注 start、cfg_valid、tile_ready、final reduction tile、write response、dma_resp_error、clear_done、soft_reset 等条件，中文说明，英文状态名和信号名，适合 IC 设计报告。
```

## 2. 时序图

| 编号 | 图名 | 源文件 | 用途 | 建议插入位置 |
| --- | --- | --- | --- | --- |
| 图 10-1 | AXI-Lite 寄存器写读时序 | `wavedrom/fig08_axil_write_read.json` | 表示 CSR 写入和读取过程中 AW/W/B 与 AR/R 通道的有效、就绪和响应关系。 | `## 10. 寄存器、指令与软件接口` 中寄存器访问规则之后，或 `### 16.1 配置写入数据通路` 之后。 |
| 图 16-1 | AXI4 burst 读写时序 | `wavedrom/fig09_axi_burst_read_write.json` | 表示 DMA 读请求、连续 RDATA、RLAST、写地址、WDATA/WSTRB/WLAST 和 BRESP 的时序关系。 | `### 16.14 AXI-Lite 与 AXI4 数据面分离` 之后，或 `### 7.21 axi_dual_block_dma模块设计` 的时序行为之后。 |
| 图 16-2 | valid-ready 反压与数据保持时序 | `wavedrom/fig10_valid_ready_handshake.json` | 表示 valid 在 ready 变低期间保持 payload，计数器只在传输完成周期推进。 | `### 16.9 反压传播与寄存保持规则` 之后。 |

AI 绘图 Prompt：

图 10-1 Prompt：

```text
白色背景的 WaveDrom 风格数字时序图，主题为 AXI-Lite 寄存器访问。信号包括 aclk、aresetn、AWVALID、AWREADY、AWADDR、WVALID、WREADY、WDATA、WSTRB、BVALID、BREADY、BRESP、ARVALID、ARREADY、ARADDR、RVALID、RREADY、RDATA、RRESP。突出写地址与写数据同周期握手、B 通道响应、读地址握手和 R 通道返回，中文标题，英文信号名，线条清晰。
```

图 16-1 Prompt：

```text
白色背景的 WaveDrom 风格 AXI4 burst 时序图。信号包括 ARVALID、ARREADY、ARADDR、ARLEN、RVALID、RREADY、RDATA、RLAST、AWVALID、AWREADY、AWADDR、WVALID、WREADY、WDATA、WSTRB、WLAST、BVALID、BREADY、BRESP。突出 burst 读返回、最后一个 beat、写数据字节掩码和写响应等待，中文标题，英文信号名，适合数字 IC 设计报告。
```

图 16-2 Prompt：

```text
白色背景的 valid-ready 握手时序图。信号包括 clk、rst_n、valid、ready、payload、transfer、counter_en。表现 ready 拉低时 payload 保持不变，valid 保持到同周期 ready 为高，transfer 与 counter_en 仅在 valid 和 ready 同时为高时产生，中文标题，英文信号名。
```

## 3. 仿真与用例组织图

| 编号 | 图名 | 源文件 | 用途 | 建议插入位置 |
| --- | --- | --- | --- | --- |
| 图 V-1 | 仿真流程图 | `mermaid/fig06_simulation_flow.mmd` | 展示 RTL、软件镜像、配置、编译、执行、日志采集、结果比对、性能提取与覆盖率汇总流程。 | 建议用于单独的验证报告；如设计报告需要简述结果，可放在 `## 19. 实现结果总结` 前的结果来源说明处。 |
| 图 V-2 | 测试用例组织图 | `mermaid/fig07_testcase_organization.mmd` | 展示 AXI-Lite、DMA、控制状态机、矩阵数据面、SoC 集成、TFLM、性能扫描和覆盖率回归的用例分组。 | 建议用于单独的验证报告；设计报告中不建议插入大量验证组织细节。 |

AI 绘图 Prompt：

图 V-1 Prompt：

```text
白色背景的仿真流程图，主题为 RTL 与软件联合仿真。流程包含 RTL 与软件镜像、仿真配置、编译 testbench 与固件、执行 AXI-Lite/DMA/controller/SoC/TFLM/performance 用例、采集 sim.log、比对输出矩阵和状态位、提取 cycle/beat/active utilization、汇总覆盖率、生成图形源文件。中文节点，工程报告风格。
```

图 V-2 Prompt：

```text
白色背景的测试用例组织图，主题为异构处理器设计的用例分组。根节点为测试用例组织，分支包括 AXI-Lite 寄存器、DMA 传输、控制状态机、矩阵数据面、SoC 集成、TFLM/NMSIS-NN 入口、性能扫描、覆盖率回归。每个分支包含 2 至 3 个叶节点，中文标签，线条清晰，适合验证报告。
```

## 4. 结果图表

结果图表由 `scripts/generate_result_charts.py` 生成，输出目录为 `charts/`。脚本同时生成 `chart_data_summary.csv` 和 `chart_data_summary.md`，便于核对图表数据。

| 编号 | 图名 | 生成文件 | 用途 | 建议插入位置 |
| --- | --- | --- | --- | --- |
| 图 16-5 | 阵列规模参数与实测吞吐 | `charts/fig11_tops_param_curve.png` | 展示 IA cache 块数固定为 4 时，阵列规模 4x4、8x8、16x16、32x32 和 64x64 在 64x64x64 任务中的理想上限、DSA 执行吞吐与 SoC 完成吞吐。 | `### 16.8 系统吞吐量分析` 表格之前。 |
| 图 19-2 | 推理时间对比图（Invoke 周期数） | `charts/fig12_inference_time_compare.png` | 展示 MNIST MLP 与 MNIST CNN 的 NPU Invoke 周期和 CPU 软件 Invoke 周期对比，周期数作为同频条件下的时间度量。 | `### 19.4 主要指标结果` 中性能表之后。 |
| 图 19-3 | 准确率与样本运行正确率对比 | `charts/fig13_accuracy_compare.png` | 展示浮点测试集准确率与样本级运行正确率。 | `### 19.4 主要指标结果` 中功能正确性描述之后。 |
| 图 19-4 | 不同阵列与缓存配置下的总线带宽利用率曲线 | `charts/fig14_bus_util_curve.png` | 展示 512x512x512 任务下读写 beat 占 NPU active 周期比例。 | `### 9.4 统一 DMA 与二维 Burst` 或 `### 19.4 主要指标结果` 中总线数据之后。 |
| 图 19-5 | NPU 算力与阵列利用率柱状图 | `charts/fig15_npu_compute_util_bar.png` | 展示 MLP/CNN 的 MMA active GOPS 与 active 阵列利用率。 | `### 19.4 主要指标结果` 中 MMA active 指标之后。 |
| 图 V-3 | 覆盖率结果直方图 | `charts/fig16_coverage_histogram.png` | 展示功能覆盖率、URG group、URG overall 与 95% 目标线。 | 建议用于验证报告；如设计报告仅需结果摘要，可放在 `## 19. 实现结果总结` 的验证结果引用段落。 |

AI 绘图 Prompt：

图 19-1 Prompt：

```text
白色背景的工程数据图表，主题为固定 IA cache 块数下的 64x64x64 任务吞吐。横轴为阵列规模 NxN，取值 4、8、16、32、64；纵轴为 TOPS@200MHz，使用对数坐标。使用橙色折线展示理想上限，蓝色柱状图展示 DSA 执行吞吐，绿色柱状图展示 SoC 完成吞吐，加入 0.5 TOPS 和 1.0 TOPS 虚线，中文坐标轴和标题。
```

图 19-2 Prompt：

```text
白色背景的工程柱状图，主题为推理时间对比，使用 Invoke 周期数作为同频条件下的时间度量。模型包括 MNIST MLP 和 MNIST CNN，每组包含 NPU Invoke 和 CPU 软件 Invoke 两个柱，纵轴使用 log scale，标注加速比 99.4x 和 14.39x，中文标题和坐标轴，适合技术报告。
```

图 19-3 Prompt：

```text
白色背景的准确率对比柱状图。模型包括 MNIST MLP 和 MNIST CNN，每组包含浮点测试集准确率和样本级运行正确率，数值分别为 96.93%、100%、97.74%、100%。纵轴范围 90% 至 101.5%，中文标题和图例，工程报告风格。
```

图 19-4 Prompt：

```text
白色背景的总线带宽利用率曲线图。横轴为阵列规模与 IA cache 分块数，包含 4x4 且 IA 分块数为 256、8x8 且 IA 分块数为 64、16x16 且 IA 分块数为 16、32x32 且 IA 分块数为 4；纵轴为占 NPU active 周期比例。绘制读 beat/active 与写 beat/active 两条曲线，数值分别为 6.80、16.78、44.85、49.26 和 0.75、2.79、7.44、5.44，中文标题、图例和坐标轴。
```

图 19-5 Prompt：

```text
白色背景的双栏工程柱状图，主题为 NPU 算力与阵列利用率。左图显示 MNIST MLP 和 MNIST CNN 的 MMA active GOPS，数值为 0.6110 和 2.0281；右图显示 active 阵列利用率，数值为 0.60% 和 1.98%。中文标题、图例、坐标轴，适合 Word/PDF。
```

图 V-3 Prompt：

```text
白色背景的覆盖率直方图。横轴为功能覆盖率、URG group、URG overall，纵轴为覆盖率百分比，三项均为 100%，加入 95% 目标虚线。中文标题、坐标轴和图例，简洁工程风格。
```

## 5. 原文替换与补图建议

1. `## 3. CPU 与 NPU 异构 SoC 总体架构` 中关于 CPU、互连、RAM、CSR 和 MMA/NPU 关系的多段文字可保留首段说明，后续连接关系用图 3-1 支撑。图后保留地址空间和配置字段说明。

2. `## 5. NPU 总体架构` 中模块枚举内容适合由图 5-1 承担主要视觉说明，正文可集中描述各模块的职责和控制状态传播。

3. `### 9.1` 至 `### 9.6` 连续描述权重固定、IA cache、partial sum、DMA、输出打包和反压规则，建议在本组小节前插入图 9-1。正文中每个小节保留精确寄存器、握手和状态更新规则。

4. `## 11. CPU/NPU 协同执行流程` 当前内容适合插入图 11-1。图能够替代部分顺序性叙述，正文保留 CSR 写入顺序、done/error 清除规则和软件 fallback 条件。

5. `### 7.8.4 工作流程与状态机` 建议插入图 7-1。状态机图应与文字表述一致，若 RTL 后续增加状态，需要同步更新 Mermaid 源文件。

6. `## 10. 寄存器、指令与软件接口` 与 `### 16.1 配置写入数据通路` 建议补充图 10-1，减少 AXI-Lite 通道文字说明的篇幅。

7. `### 16.9 反压传播与寄存保持规则` 建议补充图 16-2，用于直观说明 payload 在 ready 拉低期间保持不变、计数器仅在传输完成周期推进。

8. `### 19.5 0.5TOPS 至 1TOPS 参数探索结果` 表格后建议插入图 19-1，使评阅者直接看到参数区间覆盖关系。

9. `### 19.4 主要指标结果` 中的推理周期、准确率、总线带宽利用率和 active utilization 表格建议分别补充图 19-2 至图 19-5。表格保留精确数值，图表用于表达趋势和对比。

10. 验证流程图、测试用例组织图和覆盖率直方图更适合放在单独的验证报告中。若设计报告只保留设计内容，可在实现结果总结中引用覆盖率结果，不展开用例组织细节。

## 6. 生成命令

在仓库根目录执行以下命令可重新生成结果图表：

```bash
python3 doc/report_figures/scripts/generate_result_charts.py
```

Mermaid 源文件可由 Markdown 渲染器直接渲染，也可使用 Mermaid CLI 导出为 SVG/PNG。WaveDrom JSON 可由 WaveDrom 在线工具或本地 CLI 导出为 SVG/PNG。本目录已经导出可直接插入 Word/PDF 的图片文件：

| 类型 | 源目录 | 可插入图片目录 | 说明 |
| --- | --- | --- | --- |
| Mermaid 架构图与流程图 | `mermaid/` | `rendered/mermaid/` | 每张图均包含 SVG 和高分辨率 PNG。 |
| WaveDrom 时序图 | `wavedrom/` | `rendered/wavedrom/` | 每张时序图均包含 SVG 和 PNG。 |
| Matplotlib 结果图表 | `charts/` | `charts/` | 结果图表为 300 dpi PNG，并生成 CSV/Markdown 数据摘要。 |
