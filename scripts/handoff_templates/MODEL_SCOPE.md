# 仿真范围与待核查条件

## 周期精确性的依据

Python 入口推进的是原 RTL 经过 Verilator 编译得到的离散事件模型，连同原 AXI DDR 和原 testbench 一起执行。它保留所有 NPU 控制状态、流水级、cache、仲裁、回压和 RAM 等待。静态运行后端已经打包，接收方运行时不依赖 Verilator。

包内逐周期对照对象为同一源码快照、同一硬件参数、同一输入、同一 RAM plusarg 的独立 `--binary` 原 RTL testbench。发送方检查全部 98 个观察字段的完整 CSV 和 golden 内存，并不只比较总周期。该记录覆盖 12 个具体工况，不构成对所有配置或四态仿真的形式证明。

观察器在上升沿后 1 ps 读取稳定值，时钟仍为原 testbench 的 10 ns 周期。它不写入任何 DUT、RAM 或 stimulus 状态。`run()` 和 `step()` 都使用同一事件队列；没有另设 Python 的 DMA 延迟表或近似 FIFO。

## 硬件与模型能力

- 已预编译：SIZE=16，IA_CACHE_BLOCKS=4/8/16/32，PS_FRAME_COUNT=16，BUS_WIDTH=32，AXI_READ_OUTSTANDING=4。
- 支持原生成器提供的配置和原 RAM plusarg；不改变生成器的尺寸、数据类型及 s16 输出限制。
- 模型范围是 NPU 顶层；PicoRV32、AXI-Lite 软件配置和 TFLM 整网另由原 SoC/VCS 平台测试。
- 后端使用 Verilator 二态执行语义，不能用于研究未初始化 X/Z 的传播，也不模拟门延迟或板上电气时序。
- 预编译后端与原始 SV、testbench、适配器通过 SHA-256 绑定。冻结 C++ 可以不经 Verilator重新编译，但无法吸收后续 SV 修改。

## 吞吐报告需要复核的具体条件

`ws_systolic_cell.sv` 在 `store_weight_req` 时更新权重寄存器，随后计算区间保持权重。报告中“每拍同时注入 SIZE 个 IA 与 SIZE 个 W”的简化供数描述，应当结合权重装载阶段、驻留计算阶段和分块遍历重新核查；不能直接把 32/64 bit 的 8×/4× 推导当作所有 WS 工况的已证带宽要求。实际计算、权重装载、AXI 读取与回压均可在包内周期轨迹中观察。

IA cache 的逻辑数据容量可由当前 RTL 算出：`blocks × SIZE² × 16 bit`；SIZE=16 时 C4/C8/C16/C32 分别为 2/4/8/16 KiB。历史文档以每元素 32 bit 估算“固定容量”的表格，不能直接当成当前 IA 单侧 RAM 的物理容量或器件实际 BRAM 使用量；需要分别统计 IA、权重、部分和、输出 FIFO 及 RAM 实际配置。

既有报告给出的一些 sweep 原始 perf.csv 未随当前工作树保存，本包保留原报告并注明来源。新结果以 Python/RTL 实际执行为准。旧报告中的大 MNIST MLP 与本包当前 784→64→10 模型不是同一规模，比较前须核对模型文件校验值。
