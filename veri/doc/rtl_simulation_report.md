# 面向 TFLM 端侧推理的 NPU 仿真验证报告（CPU + NPU 异构处理器赛题版）

## 0. 交付说明与五轮迭代记录

本文只记录 RTL 仿真验证，不重复设计文档中的结构说明。验证对象包括独立 MMA/NPU 顶层、AXI block DMA、带随机延迟的 DDR 仿真模型、PicoRV32 SoC 集成环境、TFLM/NMSIS NN 调用路径以及性能计数器输出。仿真环境按当前仓库实际情况编写为 VCS + Verilator：独立 MMA 随机回归主要使用 Verilator，SoC/TFLM 集成回归主要使用 VCS。资料不足处标记为【待补充】，不把未运行的内容写成已通过。

五轮迭代记录如下。

| 轮次 | 工作内容 | 已读取或运行的资料 | 结论 |
|---|---|---|---|
| 第 1 轮 | 验证资料盘点 | `test/mma_top/Makefile`、`test/mma_top/tb_mma_top.sv`、`/media/proj_tmp/aiEngine_integrated/veri/sim`、已有 `runs` 日志 | 明确当前环境为 VCS + Verilator |
| 第 2 轮 | 用例和证据归类 | 4×4 本地随机回归、固定容量 SIZE/CACHE sweep、MNIST MLP/CNN SoC 日志 | 可支撑矩阵计算、随机延迟、CPU/NPU 协同和标准数据集小样本验证 |
| 第 3 轮 | 报告主体整理 | AXI-Lite、AXI Burst、DMA、4×4 阵列、AI 推理、性能计数器章节 | 将功能验证与性能统计拆开描述 |
| 第 4 轮 | 缺口检查 | 覆盖率目录、VCS `.daidir`、FSDB/VCD 路径、日志状态 | 未找到可引用覆盖率汇总，因此覆盖率 ≥95% 不能写达成 |
| 第 5 轮 | 最终检查 | 禁用词扫描、旧仿真环境扫描、低功耗状态检查 | 本文按实际证据写 VCS + Verilator，低功耗只写未覆盖 |

## 1. 验证目标与赛题要求映射

本次 RTL 仿真面向赛题中“CPU + NPU 异构处理器”的基础验收点，重点检查 CPU 能否通过寄存器或 MMIO 配置 NPU，NPU 能否通过 AXI Burst 地址递增访问共享 RAM，4×4 脉动阵列能否完成 INT8 矩阵运算，写回数据能否通过 `WSTRB` 和 memory compare 保证 tail 位置不被污染，SoC 程序能否在标准 MNIST/TFLM 样例上给出正确输出。

| 赛题验证要求 | 验证用例 | 检查点 | 通过标准 | 当前状态 |
|---|---|---|---|---|
| 复位和启动 | TC_RESET_001 | `calc_start`、`sa_ready`、错误码、完成状态 | 复位后空闲，启动后进入计算，完成后 PASS | 已通过基础回归 |
| AXI-Lite 单拍传输 | TC_AXIL_001 / TC_AXIL_002 | AW/W/B/AR/R 握手、`WSTRB`、状态读取 | 控制寄存器和 UART MMIO 读写正常 | 部分通过，NPU 寄存器逐地址波形【待补充】 |
| AXI Burst 地址递增 | TC_AXI_BURST_001 / TC_AXI_BURST_002 | `ARLEN/AWLEN`、INCR burst、`RLAST/WLAST`、写掩码 | memory compare 无错误 | 已通过随机回归和 SoC 回归 |
| CPU/NPU 协同 | TC_HETERO_001 | CPU 配置、NPU 执行、CPU 检查输出 | TFLM 程序 PASS，`UVM_ERROR=0` | 已通过 MNIST MLP/CNN 小样本 |
| 4×4 脉动阵列 | TC_SA_001 / TC_SA_002 | `SIZE=4`、tail tile、s8 输入、WS 模式 | RTL 输出与 golden mem 一致 | 已通过 2 个本地随机 case |
| DMA 验证 | TC_DMA_001 | 读写 DMA、随机 DDR 延迟、非对齐/尾块 | memory compare PASS | 已在顶层回归中覆盖，独立最大 outstanding 用例【待补充】 |
| 总线仲裁验证 | TC_AXI_ARB_001 | CPU/NPU 读等待、NPU 读客户端仲裁 | 无死锁，SoC 正常结束 | 已通过 SoC 日志，公平性证明【待补充】 |
| 标准数据集推理 | TC_AI_001 / TC_AI_002 | MNIST MLP、MNIST CNN | 标签预测正确，程序 PASS | 已通过小样本仿真 |
| 性能计数器 | TC_PERF_001 | `MMA_UTIL`、`SOC_AXI_STATS`、周期统计 | 日志有输出，字段可解释 | 已采集，独立 monitor 对照【待补充】 |
| 代码覆盖率 ≥95% | TC_COV_ALL | line/branch/toggle | 覆盖率报告 ≥95% | 【待补充：覆盖率汇总】 |
| 低功耗验证 | TC_LOWPOWER_001 | 当前 RTL 未实现 | 不建立通过项 | 未覆盖 |

## 2. 被测对象简述

独立 MMA/NPU 被测顶层为 `top/mma_top.sv`，参数包括 `SIZE`、`IA_CACHE_BLOCKS`、`PS_FRAME_COUNT`、`BUS_WIDTH`、`ADDR_WIDTH` 等。报告中的基础赛题配置使用 `SIZE=4`，因此阵列为 4 行 × 4 列，共 16 个 PE。该顶层连接 controller、IA loader、kernel loader、bias loader、vec requant、ps buffer/fifo、OA writer、AXI DMA arbiter 和 `axi_dual_block_dma`。testbench 通过 mem 文件加载输入、权重、bias、量化参数和 golden 输出，再启动 `calc_start`，等待 `sa_ready` 返回，最后直接比较仿真 RAM 中的输出区域。

SoC 集成被测对象位于 `/media/proj_tmp/aiEngine_integrated`，CPU 为 PicoRV32，CPU 原生存储接口经 `pico_native_to_axi.sv` 转成 AXI，NPU 作为 AXI master 访问共享 RAM。TFLM/NMSIS NN 程序被编译成 `cpu.mem`，VCS SoC testbench 加载该镜像，运行 C 程序，程序通过 UART 风格日志打印 `[tflm_perf]`、`PASS/FAIL`、`SOC_AXI_STATS` 和 `MMA_UTIL`。硬件加速路径由 NMSIS NN 调用加速器，纯软件路径通过关闭加速宏或使用软件 case 作为对照。

## 3. VCS + Verilator 仿真环境

本地工具版本已经确认。Verilator 版本为 `Verilator 5.040 2025-08-30 rev v5.040`。VCS 版本为 `VCS W-2024.09-SP1`，脚本版本 `W-2024.09`。独立 MMA 回归使用 `make -C test/mma_top run_random`，可通过 `SIZE`、`IA_CACHE_BLOCKS`、`PS_FRAME_COUNT`、`COUNT`、`SEED`、`BUILD_ROOT`、`OUT_DIR`、`RANDOM_GEN_ARGS`、`SIM_ARGS` 参数复用编译产物并生成多组随机 case。SoC 回归使用 `/media/proj_tmp/aiEngine_integrated/veri/sim` 下的 VCS 编译结果，例如 `simv_axi_soc_S16_C4_P16`，通过 plusarg 指定 `SOC_CASE_DIR`、`SOC_CPU_MEM`、`MMA_UTIL_TRACE`、`MMA_UTIL_SUMMARY`、`SOC_AXI_STATS`、`SOC_CPU_AXI_STATS` 和 FSDB 输出路径。

本次可复现的独立 MMA 命令如下。

```bash
make -C test/mma_top run_random \
  SIZE=4 IA_CACHE_BLOCKS=4 PS_FRAME_COUNT=8 \
  COUNT=2 SEED=41000 TRACE=0 \
  BUILD_ROOT=/tmp/tflm_ai_dsa_report_obj \
  OUT_DIR=/tmp/tflm_ai_dsa_report_s4 \
  RANDOM_GEN_ARGS='--random --random_quant --lhs_dtype 1 --min_dim 1 --max_dim 12 --ps_frame_count 8' \
  SIM_ARGS='+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8'
```

可引用的 SoC 命令来自 VCS 日志开头，例如 MNIST MLP 硬件路径：

```bash
/media/proj_tmp/aiEngine_integrated/veri/sim/./simv_axi_soc_S16_C4_P16 \
  +SOC_TIMEOUT_CYCLES=320000000 \
  +DUT_SEL=axi_soc \
  +SOC_CASE_DIR=../tb/axi_soc_tflm_mnist_mlp_hw \
  +SOC_CPU_MEM=../tb/axi_soc_tflm_mnist_mlp_hw/cpu.mem \
  +MMA_UTIL_TRACE +MMA_CTRL_UTIL +SOC_AXI_STATS +SOC_CPU_AXI_STATS \
  +fsdbfile+runs/ai_axi_soc_c_test/seed_1/tb_top.fsdb \
  +UVM_TESTNAME=ai_axi_soc_c_test +case=ai_axi_soc_c_test \
  +ntb_random_seed=1 +vcs+initreg+0
```

波形方面，独立 Verilator 回归默认可按 `TRACE=1` 生成波形；SoC/VCS 日志中使用 `+dump_fsdb` 或 `+fsdbfile+.../tb_top.fsdb`。本文已读取日志证据，但没有打开逐拍 FSDB 截图，因此涉及 AXI 地址逐拍列表的位置标为【待补充：波形地址序列】。覆盖率方面，仅发现 VCS 编译目录和覆盖相关生成物片段，未找到 line/branch/toggle 汇总表，因此不能声称覆盖率达到 95%。

## 4. 测试用例设计

测试用例分为 directed、random、SoC C 程序和性能 sweep 四类。directed 用例用于复位、AXI-Lite、边界配置；random 用例由 `gen_mem.py` 生成矩阵、量化参数和 golden mem，适合检查 tail、随机量化、随机 DDR 延迟；SoC C 程序用于验证 CPU/NPU 协同和 TFLM 调用；性能 sweep 用于采集 SIZE/CACHE、总线等待、阵列利用率和有效算力。

| TC ID | 名称 | 目标模块 | 激励类型 | 检查方式 | 证据 |
|---|---|---|---|---|---|
| TC_RESET_001 | 复位与启动完成 | `mma_top`、controller | directed/random | `sa_ready`、PASS 日志 | `/tmp/tflm_ai_dsa_report_s4/random_41000.log` |
| TC_AXIL_001 | AXI-Lite 写控制寄存器 | SoC MMIO/UART/control | directed C 程序 | 程序完成状态、UART 输出 | MNIST/TFLM VCS 日志；逐地址波形【待补充】 |
| TC_AXIL_002 | AXI-Lite 读状态 | SoC MMIO/UART/control | directed C 程序 | CPU 读完成状态 | `soc_finish`、`soc_status=0x00000001` |
| TC_AXI_BURST_001 | AXI Burst 读 | DMA read engine | random + SoC | memory compare、`axi_ar/axi_r` | MMA PASS、`MMA_UTIL` |
| TC_AXI_BURST_002 | AXI Burst 写 | OA writer + DMA write | random + SoC | `WSTRB` 写回、memory compare | MMA PASS、`axi_aw/axi_w/axi_b` |
| TC_HETERO_001 | CPU 配置 NPU | PicoRV32 + NPU | SoC C 程序 | TFLM PASS、`UVM_ERROR=0` | MNIST MLP/CNN 日志 |
| TC_SA_001 | 4×4 阵列基础计算 | systolic array | random | golden mem | K=8/N=2/M=5 PASS |
| TC_SA_002 | tail tile 边界 | loader/requant/OA | random | golden mem | K=5/N=7/M=7 PASS |
| TC_DMA_001 | 随机 DDR 延迟 | AXI DMA + DDR model | random | PASS，无死锁 | `+DDR_RAND_LAT=1` |
| TC_PERF_001 | 性能计数器采集 | controller/NPU/SoC | perf run | 计数字段存在且与任务规模相关 | `MMA_UTIL`、`SOC_AXI_STATS` |
| TC_AI_001 | MNIST MLP | TFLM/NMSIS NN | dataset sample | 标签正确、PASS | MLP HW/SW 日志 |
| TC_AI_002 | MNIST CNN | TFLM/NMSIS NN | dataset sample | 标签正确、PASS | CNN HW/SW 日志 |
| TC_COV_ALL | 覆盖率 | 全 RTL | coverage run | ≥95% 汇总 | 【待补充】 |
| TC_LOWPOWER_001 | 低功耗状态 | 全 RTL | source audit | 未实现则未覆盖 | 未覆盖 |

## 5. AXI-Lite 单拍传输验证

AXI-Lite 单拍访问主要出现在 SoC 控制寄存器、UART 和 C 程序 MMIO。SoC 程序能够启动、打印日志、读取完成状态并退出，说明 CPU 到外设/控制区域的基本 MMIO 读写可用。MNIST MLP 硬件日志给出 `soc_finish asserted after 8455926 cycles, soc_status=0x00000001 progress=0x5e100005 cpu_trap=0`，最终 `TEST PASS: no UVM_ERROR or UVM_FATAL reported`，`UVM_ERROR : 0`。MNIST CNN 硬件 batch32 日志给出 `soc_finish asserted after 15166819 cycles, soc_status=0x00000001 progress=0x6e100005 cpu_trap=0`，同样 `UVM_ERROR : 0`。

AXI-Lite 写操作的目标行为是：CPU 发出 AW/W，slave 接收地址与数据，按 `WSTRB` 更新对应字节，然后返回 B 响应。读操作的目标行为是：CPU 发出 AR，slave 返回 R 数据和 OKAY 响应。当前可引用证据主要来自 SoC 程序级完成状态与 UART 输出；NPU 控制寄存器的逐地址 decode 波形、非法地址响应、读回字段对照尚未整理成单独日志，因此该项状态为“部分通过”。后续补齐时应增加一个 directed AXI-Lite testbench，逐个写入 NPU base address、dimension、quant、start、status 寄存器，并对比寄存器内部值。

AXI-Lite 写控制寄存器 WaveDrom：

```json
{
  "signal": [
    {"name": "clk", "wave": "p........."},
    {"name": "awvalid", "wave": "0.10......"},
    {"name": "awready", "wave": "1........."},
    {"name": "awaddr", "wave": "x.=x......", "data": ["REG"]},
    {"name": "wvalid", "wave": "0.10......"},
    {"name": "wready", "wave": "1........."},
    {"name": "wstrb", "wave": "x.=x......", "data": ["1111"]},
    {"name": "bvalid", "wave": "0..10....."},
    {"name": "bready", "wave": "1........."}
  ],
  "head": {"text": "AXI-Lite single write"}
}
```

## 6. AXI Burst 地址递增传输验证

AXI Burst 是 NPU 访问 IA、weight、bias、quant 和 output 的主数据通道。RTL 中 `axi_dual_block_dma.sv` 将 `ARBURST/AWBURST` 固定为 INCR 模式，`ARLEN/AWLEN` 为 burst beat 数减 1。验证时不只检查 RTL 代码，还检查在随机 DDR 延迟下输出是否与 golden mem 一致，因为地址递增、`RLAST/WLAST`、beat 顺序、写掩码或 tail 长度任一错误都会直接导致 memory compare 失败。

本地 4×4 随机回归启用了 DDR 随机读写延迟：`+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8`。两组 case 均 PASS：

| 日志 | 配置 | DDR 延迟 | 完成时间 | 结论 |
|---|---|---|---:|---|
| `/tmp/tflm_ai_dsa_report_s4/random_41000.log` | `SIZE=4 CACHE=4 K=5 N=7 M=7 mode=WS R=2 W=2` | cmd≤3, w≤2, rsp≤8 | 4735000 | PASS |
| `/tmp/tflm_ai_dsa_report_s4/random_41001.log` | `SIZE=4 CACHE=4 K=8 N=2 M=5 mode=WS R=1 W=2` | cmd≤3, w≤2, rsp≤8 | 4075000 | PASS |

这两个用例覆盖了非 4 倍数的 K/N/M 组合，其中 `K=5,N=7,M=7` 同时包含 K tail、N tail 和 M tail。testbench 直接比较 `GOLDEN_MEM` 和仿真输出区域，说明读 burst 的地址递增、写 burst 的地址递增、输出 mask 以及 tail 写回都没有破坏最终 memory。

SoC 性能日志提供了 AXI 计数器侧证据。MNIST MLP 硬件路径第一层 `MMA_UTIL` 记录 `axi_ar=25252 axi_r=101800 axi_aw=32 axi_w=128 axi_b=32`；CNN batch32 summary 记录 `axi_ar=17586 axi_r=68064 axi_aw=2955 axi_w=7113 axi_b=2955`。这些字段说明仿真中存在大量读写 burst 传输，而不是 CPU 逐字节搬运。逐拍 `ARADDR = BASE + i*4`、`AWADDR = BASE + i*4` 的地址列表尚未从 FSDB 中导出，故地址波形证据标记为【待补充：波形地址序列】。

AXI Burst 读 WaveDrom：

```json
{
  "signal": [
    {"name": "clk", "wave": "p............"},
    {"name": "arvalid", "wave": "0.10........."},
    {"name": "arready", "wave": "1............"},
    {"name": "araddr", "wave": "x.=x.........", "data": ["BASE"]},
    {"name": "arlen", "wave": "x.=x.........", "data": ["LEN-1"]},
    {"name": "arburst", "wave": "x.=x.........", "data": ["INCR"]},
    {"name": "rvalid", "wave": "0..11110...."},
    {"name": "rready", "wave": "1............"},
    {"name": "rlast", "wave": "0.....10...."}
  ],
  "head": {"text": "AXI Burst read address increment"}
}
```

AXI Burst 写回 WaveDrom：

```json
{
  "signal": [
    {"name": "clk", "wave": "p............"},
    {"name": "awvalid", "wave": "0.10........."},
    {"name": "awready", "wave": "1............"},
    {"name": "awaddr", "wave": "x.=x.........", "data": ["DST"]},
    {"name": "awlen", "wave": "x.=x.........", "data": ["LEN-1"]},
    {"name": "wvalid", "wave": "0..11110...."},
    {"name": "wstrb", "wave": "x..====x....", "data": ["F", "F", "F", "MASK"]},
    {"name": "wlast", "wave": "0.....10...."},
    {"name": "bvalid", "wave": "0......10..."}
  ],
  "head": {"text": "AXI Burst write with byte mask"}
}
```

## 7. CPU 与 NPU 协同任务验证

CPU/NPU 协同验证的关键不是单个 RTL 信号，而是完整 SoC 程序能否经过“CPU 配置参数、NPU 读共享 RAM、NPU 计算和写回、CPU 读取结果、C 程序判定 PASS”的全流程。MNIST MLP 硬件路径日志显示，程序加载 `../tb/axi_soc_tflm_mnist_mlp_hw/cpu.mem`，运行 3 个样本，预测分别为 `7/2/1`，与标签一致，`total_invoke_cycles=1331710 avg=443903 samples=3`，最终 `mnist_mlp PASS`，`UVM_ERROR : 0`。同一模型的软件路径日志显示 `total_invoke_cycles=132379807 avg=44126602 samples=3`，也 PASS。由此可见，硬件路径与软件路径功能一致，且硬件路径在该小样本统计下约为 `44126602 / 443903 = 99.4` 倍速度。

MNIST CNN 硬件路径也通过了 SoC C 程序验证。batch32 summary 日志运行 3 个样本，预测 `7/2/1` 均正确，`total_invoke_cycles=12601271 avg=4200423 samples=3`，最终 `mnist_cnn PASS`，`UVM_ERROR : 0`。软件对照已有 sample1 日志，单样本 `invoke_cycles=60410324`，预测 `7` 正确，PASS。以单样本硬件 batch32_sample1 的 `4198745` 周期与软件 sample1 的 `60410324` 周期比较，硬件路径约为 `14.39` 倍速度。

SoC 总线统计说明 CPU/NPU 协同时确实存在共享读资源竞争。MNIST MLP 硬件路径记录 `SOC_AXI_STATS cpu_ar_wait=726153 mma_ar_wait=705726 rd_yield=792114`；MNIST CNN batch32 记录 `cpu_ar_wait=113685 mma_ar_wait=104505 rd_yield=124341`。软件路径中这些字段为 0，是因为没有 NPU master 发起读写。该对照能说明性能瓶颈的一部分来自 CPU 和 NPU 共享 RAM/AXI 的等待，而不是纯计算时间。

## 8. NPU 矩阵运算与 4×4 脉动阵列验证

基础 4×4 阵列的功能验证使用 `SIZE=4` 编译参数。`random_41000` 的矩阵配置为 `K=5,N=7,M=7`，覆盖了大于 4×4 的分块和三个维度的 tail；`random_41001` 的配置为 `K=8,N=2,M=5`，覆盖了 N 小于 4 和 M tail。两者均使用 s8 IA、WS 模式、随机量化参数和随机 DDR 延迟。testbench 从 `init.mem` 初始化仿真 RAM，从 `golden.mem` 读取期望结果，从 `config.mem` 读取 case 配置，完成后比较输出区域。

| 用例 | SIZE | K | N | M | IA 类型 | 模式 | 检查区域 | 结论 |
|---|---:|---:|---:|---:|---|---|---|---|
| TC_SA_002 / seed 41000 | 4 | 5 | 7 | 7 | s8 | WS | `dst` | PASS |
| TC_SA_001 / seed 41001 | 4 | 8 | 2 | 5 | s8 | WS | `dst` | PASS |

这两个 case 的价值在于它们不是规则的 4×4 整块。`K=5` 会让最后一次 K 分块只含 1 个有效深度；`N=7` 会让输出列最后一块只有 3 个有效列；`M=7` 会让输出行最后一块只有 3 个有效行。如果 IA loader、kernel loader、ps buffer、requant 或 OA writer 的边界处理有错，通常表现为 golden compare 失败或无效字节被写坏。当前日志均 PASS，说明基础 4×4 分块、tail mask 和写回流程在这两组随机参数下工作正常。

固定容量 SIZE/CACHE sweep 提供了更大规模矩阵的额外证据。`/media/proj_tmp/aiEngine_integrated/veri/sim/runs/fixed_capacity_size_cache_sweep_burst8_fix/summary.txt` 记录 `total=12 pass=12`，覆盖 `SIZE=4/CACHE=256`、`SIZE=8/CACHE=64`、`SIZE=16/CACHE=16`、`SIZE=32/CACHE=4`，矩阵尺寸覆盖 128³、256³、512³。这说明阵列参数化、IA cache 参数化、burst length 和写回在这些组合上没有出现功能错误。

## 9. DMA 验证

DMA 验证覆盖读和写两部分。读侧服务 IA、kernel、bias、quant；写侧服务 OA writer。独立 MMA 回归中，DDR model 对命令、写数据和读响应都插入随机延迟，能够暴露 `valid/ready` 握手遗漏、burst 长度错误和响应乱序处理问题。`random_41000` 与 `random_41001` 在随机延迟下均 PASS，说明 DMA 在当前 `SIZE=4`、`CACHE=4`、tail 矩阵下没有死锁，也没有因为延迟造成数据错位。

SoC 日志中的 `MMA_UTIL` 进一步证明 DMA 读写路径在真实 C 程序中被频繁使用。MNIST MLP 硬件路径第一层记录 `dma_busy_ia=1175 dma_busy_kernel=251853 dma_busy_bias=1184 dma_busy_quant=1156 dma_busy_oa=384`，说明 kernel 读是主要等待来源；CNN batch32 summary 记录 `dma_busy_ia=47691 dma_busy_kernel=117036 dma_busy_bias=2757 dma_busy_quant=5085 dma_busy_oa=11475`，说明卷积类任务中 IA 和 OA 写回占比也明显上升。DMA 最大 outstanding、错误响应和超长 burst 的 dedicated directed 用例还未整理成单独报告，标记为【待补充：DMA 极限用例】。

## 10. AXI 共享总线与仲裁验证

共享总线验证分两层。第一层是 NPU 内部的 block DMA 读客户端仲裁，覆盖 IA、kernel、bias、quant 多个请求源，输出为同一 AXI read master。第二层是 SoC 层 CPU 与 NPU 共享 AXI RAM。日志中 `SOC_AXI_STATS` 对 CPU 和 NPU 的读等待、写等待以及读让出次数进行了统计，可以用于确认不存在长期挂起。

MNIST MLP 硬件路径 `cpu_ar_wait=726153 mma_ar_wait=705726 rd_yield=792114`，说明 CPU 与 NPU 都经历了读等待，但程序最终 PASS，没有出现死锁。CNN batch32 `cpu_ar_wait=113685 mma_ar_wait=104505 rd_yield=124341`，同样 PASS。软件路径的 `cpu_ar_wait=0 mma_ar_wait=0 rd_yield=0` 与硬件路径形成对照，说明这些等待来自 NPU 加入共享总线后的竞争。

当前证据能证明“共享访问下可完成任务”，但还不能证明严格公平性或所有优先级组合均覆盖。后续应补一个 directed stress：CPU 持续取指/数据读，NPU 同时发起 IA/kernel/bias/quant 读和 OA 写，随机拉低 RAM ready，并检查每个请求源在有限周期内完成。

## 11. 标准测试集 AI 推理仿真验证

标准数据集验证使用 MNIST MLP 和 MNIST CNN 两类模型，均运行在 SoC/VCS 环境中。统计周期只记录 `interpreter.Invoke()` 包围的推理计算段，不包含模型初始化和 tensor arena 分配时间。MLP 大模型硬件路径 3 个样本预测全部正确：

| 样本 | 标签 | 硬件预测 | 硬件周期 |
|---:|---:|---:|---:|
| 0 | 7 | 7 | 452109 |
| 1 | 2 | 2 | 421758 |
| 2 | 1 | 1 | 457843 |

MLP 大模型对照：

| 路径 | 样本数 | 总周期 | 平均周期 | PASS | 速度提升 |
|---|---:|---:|---:|---|---:|
| 硬件加速 | 3 | 1331710 | 443903 | 是 | 99.4× |
| 纯软件 | 3 | 132379807 | 44126602 | 是 | 1× |

CNN 小样本对照：

| 路径 | 样本数 | 总周期 | 平均周期 | PASS | 速度提升 |
|---|---:|---:|---:|---|---:|
| 硬件加速 batch32 | 3 | 12601271 | 4200423 | 是 | 约 14.39×，按 sample1 对照 |
| 纯软件 sample1 | 1 | 60410324 | 60410324 | 是 | 1× |

当前 AI 推理验证是小样本标准数据集验证，能够证明硬件路径接入 TFLM/NMSIS NN 后输出正确并显著缩短推理计算周期。但样本数较少，不能替代完整测试集准确率评估。完整 MNIST/CIFAR-10 多样本准确率表、混淆矩阵和长时间回归日志标记为【待补充：完整数据集准确率】。

## 12. 性能计数器与关键指标验证

性能统计使用两类数据。第一类是 NPU 内部计数器，如 `active`、`ia_row`、`ia_row_util_bp`、`acc_valid`、`acc_util_bp`、`tile_start`、`dma_busy_*`、`axi_ar/axi_r/axi_aw/axi_w/axi_b`。第二类是 SoC AXI 统计，如 `cpu_ar_wait`、`mma_ar_wait`、`rd_yield`。这些字段可以分析阵列利用率、总线等待和 DMA 忙时比例。

固定容量 sweep 的 512³ 矩阵给出了 SIZE/CACHE 变化时的关键趋势：

| 配置 | 周期 | `mma_active` | `mma_ia_row_util_bp` | `mma_acc_util_bp` | `axi_r` | `axi_w` |
|---|---:|---:|---:|---:|---:|---:|
| S4/C256 | 11734391 | 8692416 | 9650 | 75 | 590978 | 65536 |
| S8/C64 | 5391466 | 2349509 | 8925 | 139 | 196737 | 32768 |
| S16/C16 | 3923125 | 881398 | 5948 | 185 | 98433 | 16384 |
| S32/C4 | 4247601 | 1205700 | 1087 | 67 | 73857 | 8192 |

从该表可见，S4/C256 的 `ia_row` 级利用率最高，说明小阵列配大 cache 更容易持续喂数，但绝对并行度小，周期较长。S16/C16 在 512³ 上周期最短，说明在当前 32 位 AXI 总线和 IA cache 容量下，16×16 阵列取得了更好的绝对吞吐。S32/C4 理论峰值更高，但 `mma_ia_row_util_bp=1087`，阵列经常等待数据，周期反而略高于 S16/C16。这一结果验证了前期性能分析中的判断：总线带宽不足时，盲目扩大阵列会降低有效利用率。

按 200MHz 计算，4×4 理论峰值为 `4*4*2*200MHz = 6.4 GOPS`。以固定 sweep 的 512³ 为例，矩阵乘 ops 约为 `2*K*N*M = 268435456 ops`。S4/C256 周期 `11734391`，等效吞吐约 `268435456 / 11734391 * 200MHz = 4.58 GOPS`；S16/C16 周期 `3923125`，等效吞吐约 `13.68 GOPS`；S32/C4 周期 `4247601`，等效吞吐约 `12.64 GOPS`。这些数值用于 RTL 仿真性能分析，不等同于硬件板卡运行结果。

性能计数器本身还缺少独立 monitor 逐拍对照。例如 `axi_r` 是否等于 monitor 观察到的 R handshake 次数，`active` 是否与 controller busy 周期完全一致，仍需补一个 scoreboard。当前状态为“计数字段已采集、趋势可信，逐拍等价检查待补充”。

## 13. 压力测试与边界条件测试

边界覆盖包括小矩阵、tail tile、随机量化、随机 DDR 延迟、不同 SIZE/CACHE 组合和 SoC 标准模型。`random_41000` 覆盖 K/N/M 全部非整块；`random_41001` 覆盖 N 小于 4；固定容量 sweep 覆盖 128³、256³、512³ 和 S4/S8/S16/S32；MNIST MLP/CNN 覆盖 TFLM/NMSIS NN 调用、多个 kernel 层和 output 写回。

已通过的压力类结果：

| 压力点 | 证据 | 状态 |
|---|---|---|
| DDR 随机命令/写/读响应延迟 | `/tmp/tflm_ai_dsa_report_s4/random_41000.log`、`random_41001.log` | PASS |
| SIZE/CACHE 参数扫描 | `fixed_capacity_size_cache_sweep_burst8_fix/summary.txt` | 12/12 PASS |
| 大矩阵 512³ | S4/C256、S8/C64、S16/C16、S32/C4 日志 | PASS |
| SoC TFLM MLP | `mnist_mlp_big_hw_s16_c4_p16.log` | PASS |
| SoC TFLM CNN | `mnist_cnn_hw_s16_c4_p16_batch32_summary.log` | PASS |

仍需补齐的边界用例包括：零维或非法维度配置、非法地址、AXI `BRESP/RRESP` 错误响应、最大 burst 长度、最大 outstanding、bias 缺失和 quant 参数极值的定向组合。这些项目不是当前报告的已通过项，统一标为【待补充：边界 directed 回归】。

## 14. 代码覆盖率统计

覆盖率是当前最大缺口。仓库中能看到 VCS 相关编译目录和覆盖生成物片段，但没有找到可以引用的 line/branch/toggle 覆盖率汇总，也没有找到达到 ≥95% 的最终报告。因此本文不能写覆盖率已达标。

建议补充流程如下：

1. 独立 MMA 使用 Verilator coverage 或 VCS coverage 编译，覆盖 `SIZE=4` 基础配置和若干扩展配置。
2. SoC/TFLM 使用 VCS coverage 跑 MLP、CNN、随机矩阵和 AXI directed 用例。
3. 将 line、branch、toggle 分开统计，过滤仿真模型、未使用 debug 代码和明确不在本版本支持范围内的低功耗/DFS RTL。
4. 生成可引用的 HTML/text summary，并把每个未覆盖模块对应到具体原因。

当前结论：`TC_COV_ALL` 状态为【待补充：覆盖率报告】，覆盖率 ≥95% 不能写达成。

## 15. 未覆盖功能说明

低功耗当前未实现，因此本 RTL 仿真报告不包含时钟关闭、DFS、电源域、多电压或功耗相关验证。该项作为未覆盖功能记录，不设置通过结论。

未覆盖或部分覆盖项目如下。

| 项目 | 状态 | 原因 |
|---|---|---|
| 低功耗 | 未覆盖 | RTL 未实现相关控制 |
| DFS | 未覆盖 | RTL 未实现频率切换 |
| 覆盖率 ≥95% | 待补充 | 无可引用覆盖率汇总 |
| NPU AXI-Lite 逐寄存器 directed 波形 | 待补充 | 当前证据主要来自 SoC 程序级 PASS |
| AXI 错误响应 | 待补充 | 现有回归主要覆盖 OKAY 响应 |
| 完整数据集准确率 | 待补充 | 当前为 MNIST 小样本 |
| 总线严格公平性证明 | 待补充 | 现有日志证明无死锁，不证明所有组合 |

## 16. 问题与修复记录

本轮报告引用了前期修复后的结果。已在回归中体现的修复方向包括：分块写回顺序调整、OA writer 与 DMA 写接口对齐、IA cache 参数化、SIZE/CACHE 组合下的 burst 长度处理、SIZE=64 相关相位问题、W 列展平输出方向修正、SoC UART 打印修复、TFLM 路径转向 NMSIS NN 调用以及 CNN im2col batch32 调整。报告没有把这些修复逐条重新证明，只在对应回归 PASS 和性能日志中引用最终状态。

仍需专门回归的 bug 风险包括：更大 SIZE 与更小 CACHE 组合下的长期随机回归、IS 模式 s16 kernel 侧组合、非对齐地址与最大 burst 同时出现、CPU/NPU 高冲突访问时的 starvation 风险。这些项目建议作为下一轮 directed regressions 输入。

## 17. 验证结论

| 验证项 | 当前结论 | 证据 |
|---|---|---|
| RTL 仿真环境 | 明确为 VCS + Verilator | VCS W-2024.09-SP1，Verilator 5.040 |
| 4×4 脉动阵列功能 | 通过基础随机回归 | `random_41000.log`、`random_41001.log` |
| AXI Burst 读写 | 通过 memory compare 和 SoC 计数器验证 | 随机 DDR 延迟 PASS、`MMA_UTIL` |
| CPU/NPU 协同 | 通过 SoC C 程序验证 | MNIST MLP/CNN PASS，`UVM_ERROR=0` |
| 标准数据集小样本推理 | 通过 | MLP 3/3，CNN 3/3 |
| 推理速度对比 | 硬件显著快于纯软件 | MLP 约 99.4×，CNN sample1 约 14.39× |
| 性能计数器 | 已采集，可用于趋势分析 | `MMA_UTIL`、`SOC_AXI_STATS` |
| 覆盖率 ≥95% | 未证明 | 【待补充：覆盖率报告】 |
| 低功耗 | 未覆盖 | 当前未实现 |

总体结论：当前 RTL 在独立 MMA 和 SoC/TFLM 两个层面已经有可引用的 VCS + Verilator 仿真证据。4×4 基础阵列、AXI Burst 数据访问、随机 DDR 延迟下的 memory compare、CPU/NPU 协同、MNIST MLP/CNN 小样本推理均有 PASS 日志。性能统计显示硬件加速能显著减少推理计算周期，同时也揭示当前 32 位总线和共享 RAM 会限制大阵列利用率。未完成项主要是覆盖率汇总、AXI-Lite 逐寄存器波形、AXI 错误响应和完整数据集准确率，这些需要在后续回归中补齐。

## 18. 附录：关键日志清单

| 类型 | 路径 |
|---|---|
| 4×4 随机回归 | `/tmp/tflm_ai_dsa_report_s4/random_41000.log` |
| 4×4 随机回归 | `/tmp/tflm_ai_dsa_report_s4/random_41001.log` |
| 固定容量 SIZE/CACHE sweep | `/media/proj_tmp/aiEngine_integrated/veri/sim/runs/fixed_capacity_size_cache_sweep_burst8_fix/summary.txt` |
| 固定容量 perf CSV | `/media/proj_tmp/aiEngine_integrated/veri/sim/runs/fixed_capacity_size_cache_sweep_burst8_fix/perf.csv` |
| MNIST MLP 硬件 | `/media/proj_tmp/aiEngine_integrated/veri/sim/runs/mnist_mlp_hw_sw/mnist_mlp_big_hw_s16_c4_p16.log` |
| MNIST MLP 软件 | `/media/proj_tmp/aiEngine_integrated/veri/sim/runs/mnist_mlp_hw_sw/mnist_mlp_big_sw_s16_c4_p16.log` |
| MNIST CNN 硬件 | `/media/proj_tmp/aiEngine_integrated/veri/sim/runs/mnist_cnn_hw_sw/mnist_cnn_hw_s16_c4_p16_batch32_summary.log` |
| MNIST CNN 软件 | `/media/proj_tmp/aiEngine_integrated/veri/sim/runs/mnist_cnn_hw_sw/mnist_cnn_sw_s16_c4_p16_sample1.log` |

## 19. 硬约束补丁执行审计

本章依据 `docs/tflm_npu_agent_hard_constraints.md` 追加。补丁要求每个核心测试用例必须包含“用例编号、验证目标、初始条件、输入配置、输入数据来源、激励步骤、关键观察信号、预期行为、实际行为、波形或日志证据、Golden 对比方式、结论”十二项，不允许只写“通过”。当前报告早期版本已经给出了总体结果和关键日志，但用例信息卡不够完整，因此本章补齐核心用例的证据卡，并明确哪些项目仍需波形或 coverage 数据。

### 19.1 测试资料清单

| 类别 | 文件或目录 | 说明 |
|---|---|---|
| 独立 MMA TB | `test/mma_top/tb_mma_top.sv` | 加载 `init.mem/golden.mem/config.mem`，启动 `calc_start`，等待 `sa_ready`，直接比较 memory |
| case 生成 | `test/mma_top/gen_mem.py` | 生成随机矩阵、量化参数、golden 输出和配置 mem |
| Verilator 入口 | `test/mma_top/Makefile` | `run_random` 支持 `SIZE/IA_CACHE_BLOCKS/COUNT/SEED/SIM_ARGS` |
| DDR AXI 模型 | `test/dep_modules/ddr_axi_mem_model.sv` | 支持随机命令、写、读响应延迟 |
| SoC VCS 入口 | `/media/proj_tmp/aiEngine_integrated/veri/sim/Makefile` | 生成 `simv_axi_soc_S16_C4_P16` 等 VCS 仿真程序 |
| MLP 日志 | `runs/mnist_mlp_hw_sw/mnist_mlp_big_hw_s16_c4_p16.log` | 硬件路径 3 样本 PASS、性能计数器 |
| MLP 软件日志 | `runs/mnist_mlp_hw_sw/mnist_mlp_big_sw_s16_c4_p16.log` | 软件对照 3 样本 PASS |
| CNN 日志 | `runs/mnist_cnn_hw_sw/mnist_cnn_hw_s16_c4_p16_batch32_summary.log` | 硬件路径 3 样本 PASS、summary 计数器 |
| CNN 软件日志 | `runs/mnist_cnn_hw_sw/mnist_cnn_sw_s16_c4_p16_sample1.log` | 软件对照 sample1 PASS |
| SIZE/CACHE sweep | `runs/fixed_capacity_size_cache_sweep_burst8_fix/summary.txt`、`perf.csv` | 12/12 PASS，性能表 |
| 覆盖率资料 | 【待补充】 | 未找到可引用 line/branch/toggle 汇总 |

### 19.2 核心用例信息卡：TC_RESET_001 复位与启动完成

| 项目 | 内容 |
|---|---|
| 用例编号 | TC_RESET_001 |
| 验证目标 | 验证 `mma_top` 复位后处于空闲，`calc_start` 后能够进入计算，完成后 `sa_ready` 回到 1，testbench 能结束 |
| 初始条件 | Verilator 编译 `SIZE=4 IA_CACHE_BLOCKS=4 PS_FRAME_COUNT=8`，DDR 随机延迟开启 |
| 输入配置 | seed 41000：`K=5,N=7,M=7,mode=WS,R=2,W=2`；seed 41001：`K=8,N=2,M=5,mode=WS,R=1,W=2` |
| 输入数据来源 | `/tmp/tflm_ai_dsa_report_s4/init.mem`、`golden.mem`、`config.mem` |
| 激励步骤 | TB 加载 mem，复位释放后写入配置，`calc_start triggered at time 95000`，等待 `sa_ready` 变低再变高 |
| 关键观察信号 | `calc_start`、`sa_ready`、`wb_valid`、`err_code`、TB PASS/FAIL |
| 预期行为 | `calc_start` 后控制器离开 idle，计算完成后 `sa_ready=1`，无错误码，输出 memory 与 golden 一致 |
| 实际行为 | seed 41000 在 time 4735000 完成并 PASS；seed 41001 在 time 4075000 完成并 PASS |
| 波形或日志证据 | `/tmp/tflm_ai_dsa_report_s4/random_41000.log`、`random_41001.log` |
| Golden 对比方式 | TB 比较 `dst` 区域 memory words，日志中 `check= dst` 且最终 `[TB] PASS` |
| 结论 | 通过。逐拍 `sa_ready` 波形截图仍可补充，当前日志足以证明基本启动完成流程 |

### 19.3 核心用例信息卡：TC_AXI_BURST_001/002 AXI Burst 读写

| 项目 | 内容 |
|---|---|
| 用例编号 | TC_AXI_BURST_001 / TC_AXI_BURST_002 |
| 验证目标 | 验证 NPU 通过 `axi_dual_block_dma` 发起 INCR burst 读 IA/W/bias/quant，并通过 OA writer 发起 INCR burst 写输出 |
| 初始条件 | 同 TC_RESET_001，DDR 模型使用 `+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8` |
| 输入配置 | 4×4 随机矩阵和 tail 矩阵；SoC MLP/CNN VCS 日志额外提供大量 AXI 计数字段 |
| 输入数据来源 | Verilator mem case；VCS SoC `cpu.mem` 与共享 RAM |
| 激励步骤 | loader 发 `load_ia_req/load_weight_req/load_bias_req/load_quant_req`，arbiter grant 后 DMA 发 `m_axi_arvalid`；OA writer 发 `write_oa_req`，DMA 发 `m_axi_awvalid/m_axi_wvalid` |
| 关键观察信号 | `m_axi_arvalid/arready/araddr/arlen/arburst`、`m_axi_rvalid/rready/rlast`、`m_axi_awvalid/awready/awaddr/awlen`、`m_axi_wstrb/wlast`、`m_axi_bvalid/bready` |
| 预期行为 | `arburst/awburst=INCR`，`arlen/awlen` 为 beat 数减 1，响应延迟不造成数据错位，tail 写回不覆盖无效字节 |
| 实际行为 | 两个随机 case 均 PASS；MLP 日志第一层 `axi_ar=25252 axi_r=101800 axi_aw=32 axi_w=128 axi_b=32`；CNN summary `axi_ar=17586 axi_r=68064 axi_aw=2955 axi_w=7113 axi_b=2955` |
| 波形或日志证据 | 随机回归日志、MLP/CNN `MMA_UTIL`；逐拍地址序列【待补充：FSDB 导出】 |
| Golden 对比方式 | Verilator TB memory compare；SoC C 程序检查 TFLM 输出标签 |
| 结论 | 功能通过，逐拍 AXI 地址递增波形待补充 |

### 19.4 核心用例信息卡：TC_SA_001/002 4×4 脉动阵列与 tail tile

| 项目 | 内容 |
|---|---|
| 用例编号 | TC_SA_001 / TC_SA_002 |
| 验证目标 | 验证 `SIZE=4` 下 16 个 PE 的矩阵乘、partial sum、requant、FIFO 和写回在整块和尾块下正确 |
| 初始条件 | `SIZE=4`，WS 模式，s8 IA，随机量化，随机 DDR 延迟 |
| 输入配置 | TC_SA_001：`K=8,N=2,M=5`；TC_SA_002：`K=5,N=7,M=7` |
| 输入数据来源 | `gen_mem.py` 生成随机输入、权重、bias/quant 和 golden memory |
| 激励步骤 | TB 启动 NPU，controller 触发 `send_weight_trigger/send_ia_trigger`，阵列输出 `acc_data_valid`，requant 输出 s8，writer 写回 |
| 关键观察信号 | `store_weight_req`、`weight_data_valid`、`ia_row_valid`、`ia_tile_start`、`acc_data_valid`、`out_valid`、`output_mask`、`dma_src_wmask` |
| 预期行为 | K/N/M 不是 4 倍数时，无效 lane 补零或屏蔽；输出只写有效行列；最终 memory 等于 golden |
| 实际行为 | seed 41000 覆盖 K/N/M tail，seed 41001 覆盖 N 小于 4 和 M tail，两个日志均 `[TB] PASS` |
| 波形或日志证据 | `/tmp/tflm_ai_dsa_report_s4/random_41000.log`、`random_41001.log` |
| Golden 对比方式 | TB 直接比较输出 memory，不通过 UART 文本间接判断 |
| 结论 | 通过。缺少逐 PE waveform 截图，但 end-to-end memory compare 覆盖了阵列、量化和写回组合 |

### 19.5 核心用例信息卡：TC_HETERO_001 CPU/NPU 协同

| 项目 | 内容 |
|---|---|
| 用例编号 | TC_HETERO_001 |
| 验证目标 | 验证 PicoRV32 C 程序配置 NPU、NPU 访问共享 RAM、CPU 读取完成状态并判定输出 |
| 初始条件 | VCS SoC 仿真，`simv_axi_soc_S16_C4_P16`，`+SOC_TIMEOUT_CYCLES=320000000` |
| 输入配置 | MNIST MLP/CNN TFLM 程序，硬件加速路径和软件对照路径 |
| 输入数据来源 | `../tb/axi_soc_tflm_mnist_mlp_hw/cpu.mem`、`../tb/axi_soc_tflm_mnist_cnn_hw/cpu.mem` |
| 激励步骤 | CPU 启动 TFLM，NMSIS NN 调用 ExtraAccFunctions，驱动写 `DSA_REG_CTRL`，轮询 `DSA_REG_STATUS`，读取 `DSA_REG_WB_DATA` |
| 关键观察信号 | `[tflm_perf]`、`[MMA_UTIL]`、`[SOC_AXI_STATS]`、`soc_finish`、`soc_status`、`cpu_trap`、`UVM_ERROR` |
| 预期行为 | 样本标签预测正确，C 程序返回 PASS，SoC 无 trap，UVM 无 error |
| 实际行为 | MLP 3 样本 `7/2/1` 全部正确，CNN 3 样本 `7/2/1` 全部正确，`UVM_ERROR : 0` |
| 波形或日志证据 | `mnist_mlp_big_hw_s16_c4_p16.log`、`mnist_cnn_hw_s16_c4_p16_batch32_summary.log` |
| Golden 对比方式 | TFLM 程序将 pred 与 label 比较；软件路径同样 PASS 作为功能对照 |
| 结论 | 通过。完整数据集准确率仍需补充 |

### 19.6 核心用例信息卡：TC_PERF_001 性能计数器和推理速度

| 项目 | 内容 |
|---|---|
| 用例编号 | TC_PERF_001 |
| 验证目标 | 验证日志能采集推理周期、MMA 活跃周期、阵列利用率相关字段、AXI beat 和 SoC 总线等待 |
| 初始条件 | VCS 加 `+MMA_UTIL_TRACE` 或 `+MMA_UTIL_SUMMARY`，加 `+SOC_AXI_STATS +SOC_CPU_AXI_STATS` |
| 输入配置 | MLP 3 样本、CNN 3 样本、固定容量 SIZE/CACHE sweep |
| 输入数据来源 | VCS SoC 日志和 `perf.csv` |
| 激励步骤 | 运行 SoC 程序，硬件路径每次 NPU 调用打印 `MMA_UTIL`，推理结束打印 `tflm_perf` |
| 关键观察信号 | `active`、`ia_row_util_bp`、`acc_util_bp`、`dma_busy_*`、`axi_ar/axi_r/axi_aw/axi_w/axi_b`、`cpu_ar_wait/mma_ar_wait/rd_yield` |
| 预期行为 | 计数字段随任务规模变化，硬件路径推理周期显著少于软件路径，SIZE/CACHE sweep 均 PASS |
| 实际行为 | MLP 硬件 avg 443903 cycles，软件 avg 44126602 cycles；CNN 硬件 avg 4200423 cycles，软件 sample1 60410324 cycles；fixed sweep `total=12 pass=12` |
| 波形或日志证据 | MLP/CNN 日志、`fixed_capacity_size_cache_sweep_burst8_fix/perf.csv` |
| Golden 对比方式 | 性能用周期和计数器，不是数值 golden；功能 correctness 由同一日志 PASS 保证 |
| 结论 | 已采集并可用于趋势分析。计数器逐拍 monitor 对照【待补充】 |

### 19.7 核心用例信息卡：TC_COV_ALL 覆盖率

| 项目 | 内容 |
|---|---|
| 用例编号 | TC_COV_ALL |
| 验证目标 | 验证 line/branch/toggle 覆盖率是否达到 95% |
| 初始条件 | 需要 VCS coverage 或 Verilator coverage 编译 |
| 输入配置 | 应覆盖 4×4 基础、SIZE/CACHE 参数、WS/IS、per-tensor/per-channel、随机 DDR 延迟、异常配置 |
| 输入数据来源 | 【待补充：coverage run 输出】 |
| 激励步骤 | 【待补充：coverage 命令】 |
| 关键观察信号 | coverage summary 中 line、branch、toggle、exclude 列表 |
| 预期行为 | 合法 RTL 覆盖率 ≥95%，低功耗/DFS 未实现部分不计入已完成项 |
| 实际行为 | 当前仓库未找到可引用覆盖率汇总 |
| 波形或日志证据 | 【待补充：覆盖率报告】 |
| Golden 对比方式 | 不适用，覆盖率由工具报告证明 |
| 结论 | 待补充，不能写达成 |

## 20. 未达标验证项与后续回归清单

| 补丁要求 | 当前状态 | 影响 | 后续动作 |
|---|---|---|---|
| 每个核心模块验证小节不少于 1200 中文字 | 部分达标 | 早期章节偏短 | 扩写 controller、IA loader、DMA、OA writer、vec_requant 的波形分析 |
| 每个测试用例必须有 12 项信息 | 本章已补核心用例 | 非核心用例仍可细分 | 增加 AXI-Lite directed、非法地址、错误响应用例 |
| 核心模块均有波形或日志分析 | 部分达标 | 目前主要依赖日志和 memory compare | 导出 FSDB 中 AXI 地址、`output_mask`、`fifo_full_flag` 波形 |
| 性能计数器有波形统计对比 | 待补充 | 计数字段可信度需加强 | 增加 scoreboard 统计 AXI handshake 和 active cycles |
| 异常、边界、反压场景覆盖 | 部分达标 | 随机 DDR/tail 已有，错误响应不足 | 增加 `BRESP/RRESP` error、最大 outstanding、FIFO full directed |
| 覆盖率 ≥95% | 待补充 | 不能满足赛题覆盖率条目 | 建立 VCS coverage 或 Verilator coverage 汇总 |

## 21. Golden Model 对比方式补充

独立 MMA 回归的 Golden Model 在 `gen_mem.py` 中生成，输出为 `golden.mem`。testbench 不通过打印文本判断数值，而是直接比较仿真 memory 中 `dst` 区域。该方式比 UART 日志更快，也能发现 tail mask、stride、非对齐写或量化舍入造成的单字节错误。SoC/TFLM 回归的 Golden 判断分两层：第一层是模型样本标签，MLP/CNN 程序打印 `label` 与 `pred`，预测一致才 PASS；第二层是软件路径对照，同一模型在纯软件日志中也 PASS，推理输出标签一致。当前尚未把每层 tensor dump 与 Python reference 做逐元素比较，因此完整中间 tensor golden 标记为【待补充：tensor dump 对比】。

## 22. 低功耗与非 RTL 范围声明

当前项目未实现低功耗控制，因此本报告不包含低功耗通过项；也没有硬件板卡运行和芯片物理实现类检查。仿真报告的结论只来自 RTL 仿真、testbench、VCS/Verilator 日志、memory compare、TFLM 程序 PASS 和性能计数器。凡缺少 coverage、FSDB 导出或 directed 用例的项目均在表中标为【待补充】，不扩写成已完成结论。
