# aiEngine Integrated

本仓库是 NPU 加速器的 SoC 集成、验证和软件适配工程。当前代码包含 AXI 化后的 PicoRV32 SoC、NPU AXI-Lite 配置接口、共享 AXI RAM/UART、VCS/UVM 验证平台、Verilator NPU 顶层回归、TFLM/NMSIS-NN 适配代码以及 FPGA 综合/仿真辅助脚本。

仿真层级、最短运行命令和实际检查项见 [how2run 快速指南](how2run.md)。
各 make target 的用途、原理、产物及依赖关系见 [Makefile target 详解](veri/sim/MAKE_TARGETS.md)。

## GEMPACT 配置 ABI 2（2026-11-11）

分组数和尾组大小由 CPU 或模型编译器预先计算。启动前必须写入 `0x060`～`0x06c` 四个配置寄存器，RTL 不包含配置除法器或除法回退。驱动已同步更新；旧软件和旧独立仿真输入需更新。见 [寄存器与外部预计算说明](drivers/registers_v2.md)；C 计算函数在 [gempact_tiling.h](drivers/gempact_tiling.h)，仿真输入转换工具在 [host_tiling.py](veri/top_regression/host_tiling.py)。

## 目录

- [aiEngine Integrated](#aiengine-integrated)
  - [目录](#目录)
  - [仓库结构](#仓库结构)
  - [工具环境](#工具环境)
  - [关键参数](#关键参数)
  - [快速冒烟测试](#快速冒烟测试)
  - [VCS 统一仿真入口](#vcs-统一仿真入口)
  - [AXI-Lite 寄存器测试](#axi-lite-寄存器测试)
  - [SoC C 程序测试](#soc-c-程序测试)
    - [runtime 模式](#runtime-模式)
    - [case 模式](#case-模式)
    - [常用定向组合](#常用定向组合)
  - [随机回归](#随机回归)
  - [NPU 顶层 Verilator 回归](#npu-顶层-verilator-回归)
  - [TFLM / NMSIS-NN 推理测试](#tflm--nmsis-nn-推理测试)
    - [MNIST MLP 硬件路径](#mnist-mlp-硬件路径)
    - [MNIST MLP 纯软件路径](#mnist-mlp-纯软件路径)
    - [MNIST CNN 硬件路径](#mnist-cnn-硬件路径)
    - [MNIST CNN 纯软件路径](#mnist-cnn-纯软件路径)
    - [其他 TFLM 示例](#其他-tflm-示例)
    - [只生成 FPGA 用 MNIST firmware](#只生成-fpga-用-mnist-firmware)
  - [性能扫描](#性能扫描)
    - [SIZE 与 IA cache 扫描](#size-与-ia-cache-扫描)
    - [固定大延迟测试](#固定大延迟测试)
    - [固定容量 SIZE/cache 扫描](#固定容量-sizecache-扫描)
  - [覆盖率](#覆盖率)
  - [Vivado SoC 综合入口](#vivado-soc-综合入口)
  - [日志与调试](#日志与调试)
  - [清理生成文件](#清理生成文件)
  - [推荐提交前检查](#推荐提交前检查)
  - [参考文档](#参考文档)

## 仓库结构

```text
aiEngine_integrated/
  rtl/axi_accelerator/
    npu/                       # NPU RTL，同步后的 loader/compute/DMA/writeback
    axi_top/                   # NPU AXI-Lite 寄存器封装
    soc/                       # Pico native to AXI、互连、RAM、UART、控制寄存器
    soc_top.sv                 # SoC 顶层
  drivers/
    dsa_accel.c/.h             # 独立 NPU MMIO 驱动
    registers_v2.md            # NPU AXI-Lite 寄存器表
    tflm/my_tflm/              # TFLM/NMSIS-NN 集成树
  picorv32/                    # PicoRV32 与 simpleuart 源码
  veri/
    sim/                       # VCS 统一 Makefile、回归脚本、覆盖率脚本
    tb/                        # case 生成脚本与生成后的 memory image
    soc_csrc/                  # 裸机 SoC C/C++ 测试程序
    flist/                     # VCS filelist
    env/ interface/ uvc/ test/ # UVM 环境、sequence、scoreboard、coverage
    top_regression/            # 直接例化 npu_top 的 Verilator 回归
    python_model/              # Python 仿真接口与 RTL 后端源码
    ram_axi_vip/               # 共享 RAM 验证源码和 Vivado 仿真脚本
    legacy/                    # 历史验证源码
  doc/                        # 设计、验证、性能和实现报告及插图
  scripts/
    fpga/                      # Vivado 综合、实现和 Vitis 部署
    models/                    # 模型元数据与存储初始化文件生成
    packaging/                 # 仿真代码导出与说明模板
    maintenance/               # 临时工具日志清理
    utils/                     # 文本格式和源码文件名转换工具
  build/                      # 构建产物、FPGA 中间文件与实现报告
  deliverables/               # 生成的发布包
  paper/                      # 论文和实验工作目录，单独管理
```

其中 `veri/sim/Makefile` 是最常用入口。VCS、TFLM、随机回归、性能扫描、覆盖率和 Verdi 打开波形都从这里调用。

脚本分类和构建产物位置见 [目录与工具说明](scripts/README.md)。设计文档集中存放在 `doc/`；`paper/` 不参与项目源码提交。

## 工具环境

推荐在 Linux shell 下运行。默认路径假设：

```bash
cd /media/proj_tmp/aiEngine_integrated
```

需要的主要工具：

| 用途 | 工具 |
|---|---|
| SoC/UVM 仿真 | Synopsys VCS、UVM 1.2 |
| 覆盖率 | Synopsys URG |
| 波形调试 | Verdi/Novas，可选 |
| NPU 顶层轻量回归 | Verilator、g++、make |
| case 生成和脚本 | Python 3 |
| firmware 编译 | `riscv64-unknown-elf-gcc/g++/ar/objcopy` |
| FPGA 综合检查 | Vivado |

常用环境变量：

```bash
export VCS_HOME=/path/to/vcs
export NOVAS_HOME=/path/to/novas       # 需要 FSDB/Verdi 时设置
export PATH=/path/to/riscv/bin:$PATH   # 若交叉编译器不在默认路径
```

`veri/sim/Makefile` 会优先使用 PATH 中的 RISC-V 工具链；如果找不到，会尝试默认路径：

```text
/media/proj_tmp/alioth_simulator/deps/software-level/bin/gcc_open/bin
```

默认仿真运行器为：

```text
veri/sim/run_simv_lxc.sh
```

如果本机直接运行 `simv`，可覆盖：

```bash
make run SIM_LAUNCHER= ...
```

性能测试和大回归建议关闭波形：

```bash
DUMPOPTS=0
```

## 关键参数

Makefile 中保留了一些历史变量名。`MMA_SIZE`、`MMA_IA_CACHE_BLOCKS`、`MMA_PS_FRAME_COUNT` 当前实际控制 NPU 的阵列规模、IA cache block 数和 PS frame 数。

| 变量 | 默认值 | 说明 |
|---|---:|---|
| `DUT_MODE` | `axil` | `axil` 运行 NPU AXI-Lite 外设测试，`axi_soc` 运行 PicoRV32 SoC 测试 |
| `case` | `ai_mem_gen_smoke_test` | UVM test 名称 |
| `seed` | `1` | UVM 随机种子 |
| `MMA_SIZE` | `16` | NPU 脉动阵列边长 |
| `MMA_IA_CACHE_BLOCKS` | `4` | IA cache block 数 |
| `MMA_PS_FRAME_COUNT` | `MMA_SIZE` | PS buffer / output FIFO frame 数 |
| `SOC_CPU_MEM_DP` | `65536` | SoC RAM 深度，单位 32-bit word |
| `SOC_AXI_READ_OUTSTANDING` | `4` | SoC/NPU AXI 读 outstanding 深度 |
| `SOC_AXI_WRITE_OUTSTANDING` | 同读通道 | SoC/NPU AXI 写 outstanding 深度 |
| `SOC_CPU_ENABLE_ICACHE` | `0` | PicoRV32 指令 cache 开关 |
| `SOC_BYPASS_RAM_PINGPONG` | `1` | 是否旁路 RAM 侧 ping-pong timing buffer |
| `SOC_RAM_WRITE_TIMING_BUFFER` | `1` | RAM 写路径 timing buffer |
| `SOC_UART_CLKDIV` | `8` | firmware 写入 simpleuart 的分频值，VCS 快速仿真使用 8 |

SoC case 生成参数：

| 变量 | 说明 |
|---|---|
| `SOC_K/SOC_N/SOC_M` | 矩阵尺寸，输出为 `K x M` |
| `SOC_LHS_DTYPE` | `1=int8`，`2=int16` |
| `SOC_QUANT_MODE` | `0=per-tensor`，`1=per-channel` |
| `SOC_DATAFLOW_MODE` | `0=WS`，`1=IS` |
| `SOC_IA_REUSE_NUM` | IA cache 复用深度，0 表示自动选择 |
| `SOC_W_REUSE_NUM` | W 侧复用窗口，0 表示自动选择 |
| `SOC_RANDOM` | 1 时由脚本随机生成尺寸和数据 |
| `SOC_FIX_MODE` | 1 时生成确定性输入，0 时生成随机输入 |
| `SOC_UNALIGNED_LAYOUT` | 1 时生成非对齐数据布局 |
| `SOC_TIMEOUT_CYCLES` | SoC 程序超时周期 |

RAM 响应延迟 plusarg：

| plusarg | 说明 |
|---|---|
| `+DDR_RAND_LAT=1` | 打开 RAM 随机响应延迟 |
| `+DDR_CMD_MAX_LAT=<n>` | 命令通道最大等待周期 |
| `+DDR_W_MAX_LAT=<n>` | 写数据通道最大等待周期 |
| `+DDR_RSP_MAX_LAT=<n>` | 读/写响应最大等待周期 |
| `+RAM_FIXED_LAT=<n>` | 固定 RAM 响应延迟，burst 内数据连续返回 |

## 快速冒烟测试

进入统一仿真目录：

```bash
cd /media/proj_tmp/aiEngine_integrated/veri/sim
make help
```

推荐第一次同步后先跑三类测试：

```bash
# 1. AXI-Lite 寄存器和基础 memory case
make run DUT_MODE=axil case=ai_mem_gen_smoke_test seed=20260413 DUMPOPTS=0

# 2. SoC 裸机 runtime case，CPU 配置 NPU 并检查输出 memory
make run DUT_MODE=axi_soc SOC_APP=runtime case=ai_axi_soc_c_test \
  MMA_SIZE=4 MMA_IA_CACHE_BLOCKS=32 MMA_PS_FRAME_COUNT=16 \
  SOC_K=32 SOC_N=32 SOC_M=32 \
  SOC_LHS_DTYPE=1 SOC_QUANT_MODE=0 SOC_DATAFLOW_MODE=0 \
  SOC_CPU_MEM_DP=65536 SOC_CPU_ENABLE_ICACHE=1 \
  SOC_TIMEOUT_CYCLES=50000000 DUMPOPTS=0

# 3. 不经过 CPU 的 NPU 顶层 Verilator 回归
make npu_top_regress \
  TOP_REGRESS_SIZE=4 \
  TOP_REGRESS_IA_CACHE_BLOCKS=32 \
  TOP_REGRESS_PS_FRAME_COUNT=16 \
  TOP_REGRESS_COUNT=10 \
  TOP_REGRESS_SEED=1000 \
  TOP_REGRESS_TRACE=0
```

通过判据：

- VCS 日志中出现 `TEST PASS`，无 `UVM_ERROR`、`UVM_FATAL`、`TRAP`、`TIMEOUT`。
- SoC 测试中 `soc_status=0x00000001`，`cpu_trap=0`。
- Verilator NPU 顶层回归中出现 `[TB] PASS` 和 `[run_random] PASS=<N> FAIL=0`。

## VCS 统一仿真入口

所有 VCS 命令建议在 `veri/sim` 目录执行：

```bash
cd /media/proj_tmp/aiEngine_integrated/veri/sim
```

常用 target：

| target | 作用 |
|---|---|
| `make run` | 编译并运行 |
| `make com` | 只编译 VCS `simv` |
| `make sim` | 只运行已有 `simv`，会先生成所需 case/mem |
| `make force_com` | 删除当前 `simv` 时间戳并强制重编 |
| `make vd` | 使用 Verdi 打开当前 FSDB |
| `make clean` | 清理 `simv_*`、`.daidir`、`.csrc`、`runs` 等生成物 |
| `make help` | 打印 Makefile 支持的入口 |

输出目录：

```text
veri/sim/runs/<case>/seed_<seed>/compile.log
veri/sim/runs/<case>/seed_<seed>/sim.log
veri/sim/runs/<case>/seed_<seed>/tb_top.fsdb
```

关闭波形：

```bash
DUMPOPTS=0
```

打开波形后查看：

```bash
make vd DUT_MODE=axi_soc case=ai_axi_soc_c_test seed=1
```

重新编译常见写法：

```bash
make force_com DUT_MODE=axi_soc \
  MMA_SIZE=4 MMA_IA_CACHE_BLOCKS=32 MMA_PS_FRAME_COUNT=16 \
  SOC_CPU_MEM_DP=65536 DUMPOPTS=0
```

`SIMV` 名称会包含 `DUT_MODE/SIZE/CACHE/PS/CPU_MEM_DP/outstanding/icache/buffer` 等参数，因此不同硬件参数可以复用各自的编译结果。

## AXI-Lite 寄存器测试

AXI-Lite 模式只验证 NPU 外设和寄存器接口，不启动 PicoRV32。

基础 memory 生成 smoke：

```bash
make run DUT_MODE=axil case=ai_mem_gen_smoke_test seed=20260413 DUMPOPTS=0
```

RAL 写寄存器并触发 start：

```bash
make run DUT_MODE=axil case=ai_ral_mem_gen_on_calc_start_test seed=20260414 DUMPOPTS=0
```

寄存器定向测试：

```bash
make run DUT_MODE=axil case=ai_axil_reg_directed_test seed=20260415 DUMPOPTS=0
```

覆盖重点：

- NPU ID、CTRL、STATUS、矩阵尺寸、stride、zero point、reuse、dataflow 等寄存器。
- `STATUS[2] done` 写 1 清除语义。
- `CTRL.start` 单周期启动语义。
- per-tensor/per-channel 配置字段。
- AXI-Lite 读写响应和寄存器默认值。

## SoC C 程序测试

SoC 模式会例化 PicoRV32、AXI 互连、AXI RAM、UART、NPU AXI-Lite 外设和 NPU AXI master。CPU firmware 通过 MMIO 配置 NPU，NPU 完成后 testbench 直接检查 RAM 输出结果。

### runtime 模式

`SOC_APP=runtime` 只编译一次 O3 裸机程序，case 数据放在 `runtime_data.mem`，适合随机回归和性能扫描。

```bash
make run DUT_MODE=axi_soc SOC_APP=runtime case=ai_axi_soc_c_test \
  SOC_CASE=axi_soc_runtime_ws_int8 \
  MMA_SIZE=4 MMA_IA_CACHE_BLOCKS=32 MMA_PS_FRAME_COUNT=16 \
  SOC_K=64 SOC_N=64 SOC_M=64 \
  SOC_LHS_DTYPE=1 SOC_QUANT_MODE=0 SOC_DATAFLOW_MODE=0 \
  SOC_CPU_MEM_DP=65536 \
  SOC_CPU_ENABLE_ICACHE=1 \
  SOC_TIMEOUT_CYCLES=80000000 \
  DUMPOPTS=0
```

### case 模式

`SOC_APP=case` 会把 case 数据编进同一个 `cpu.mem`，适合导出到 FPGA bitstream 或做单个定向复现。

```bash
make run DUT_MODE=axi_soc SOC_APP=case case=ai_axi_soc_c_test \
  SOC_CASE=axi_soc_case_ws_int8 \
  MMA_SIZE=4 MMA_IA_CACHE_BLOCKS=32 MMA_PS_FRAME_COUNT=16 \
  SOC_K=64 SOC_N=64 SOC_M=64 \
  SOC_LHS_DTYPE=1 SOC_QUANT_MODE=0 SOC_DATAFLOW_MODE=0 \
  SOC_CPU_MEM_DP=65536 \
  SOC_TIMEOUT_CYCLES=80000000 \
  DUMPOPTS=0
```

### 常用定向组合

int8 WS per-tensor：

```bash
make run DUT_MODE=axi_soc SOC_APP=runtime case=ai_axi_soc_c_test \
  MMA_SIZE=4 MMA_IA_CACHE_BLOCKS=32 MMA_PS_FRAME_COUNT=16 \
  SOC_K=64 SOC_N=64 SOC_M=64 \
  SOC_LHS_DTYPE=1 SOC_QUANT_MODE=0 SOC_DATAFLOW_MODE=0 \
  DUMPOPTS=0
```

int16 IS per-tensor：

```bash
make run DUT_MODE=axi_soc SOC_APP=runtime case=ai_axi_soc_c_test \
  MMA_SIZE=16 MMA_IA_CACHE_BLOCKS=4 MMA_PS_FRAME_COUNT=16 \
  SOC_K=32 SOC_N=64 SOC_M=48 \
  SOC_LHS_DTYPE=2 SOC_QUANT_MODE=0 SOC_DATAFLOW_MODE=1 \
  SOC_TIMEOUT_CYCLES=100000000 DUMPOPTS=0
```

per-channel：

```bash
make run DUT_MODE=axi_soc SOC_APP=runtime case=ai_axi_soc_c_test \
  MMA_SIZE=16 MMA_IA_CACHE_BLOCKS=4 MMA_PS_FRAME_COUNT=16 \
  SOC_K=32 SOC_N=64 SOC_M=48 \
  SOC_LHS_DTYPE=1 SOC_QUANT_MODE=1 SOC_DATAFLOW_MODE=0 \
  SOC_TIMEOUT_CYCLES=100000000 DUMPOPTS=0
```

非对齐布局：

```bash
make run DUT_MODE=axi_soc SOC_APP=runtime case=ai_axi_soc_c_test \
  MMA_SIZE=4 MMA_IA_CACHE_BLOCKS=32 MMA_PS_FRAME_COUNT=16 \
  SOC_K=17 SOC_N=31 SOC_M=19 \
  SOC_LHS_DTYPE=1 SOC_QUANT_MODE=0 SOC_DATAFLOW_MODE=0 \
  SOC_UNALIGNED_LAYOUT=1 \
  SOC_TIMEOUT_CYCLES=100000000 DUMPOPTS=0
```

RAM 随机响应延迟：

```bash
make run DUT_MODE=axi_soc SOC_APP=runtime case=ai_axi_soc_c_test \
  MMA_SIZE=4 MMA_IA_CACHE_BLOCKS=32 MMA_PS_FRAME_COUNT=16 \
  SOC_K=64 SOC_N=64 SOC_M=64 \
  SIM_ARGS='+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8' \
  SOC_TIMEOUT_CYCLES=100000000 DUMPOPTS=0
```

## 随机回归

`soc_regress` 会调用 `run_axi_soc_c_regression.py`，自动生成 case、编译/复用 `simv`、运行 VCS 并汇总日志。

推荐基础随机回归：

```bash
make soc_regress \
  SOC_REGRESS_ITERS=50 \
  SOC_REGRESS_START_SEED=10000 \
  SOC_SIZE_LIST='4 8 16' \
  SOC_CACHE_BLOCKS_LIST='4 8 16 32' \
  SOC_PS_FRAME_COUNT_LIST='8 16' \
  SOC_DATAFLOW_MODE_LIST='0 1' \
  SOC_REGRESS_LHS_DTYPE_LIST='1 2' \
  SOC_REGRESS_QUANT_MODE_LIST='0 1' \
  SOC_MIN_DIM=1 \
  SOC_MAX_DIM=128 \
  SOC_REGRESS_DIM_MULTIPLE=0 \
  SOC_REGRESS_DDR_RAND_LAT=1 \
  SOC_REGRESS_UNALIGNED_LAYOUT=1 \
  SOC_REGRESS_TIMEOUT=300 \
  SOC_REGRESS_SOC_TIMEOUT_CYCLES=120000000 \
  DUMPOPTS=0
```

边界小尺寸回归：

```bash
make soc_regress \
  SOC_REGRESS_ITERS=40 \
  SOC_REGRESS_START_SEED=20000 \
  SOC_SIZE_LIST='4 8 16' \
  SOC_CACHE_BLOCKS_LIST='4 16 32' \
  SOC_MIN_DIM=1 \
  SOC_MAX_DIM=17 \
  SOC_REGRESS_DIM_MULTIPLE=0 \
  SOC_DATAFLOW_MODE_LIST='0 1' \
  SOC_REGRESS_DDR_RAND_LAT=1 \
  SOC_REGRESS_UNALIGNED_LAYOUT=1 \
  DUMPOPTS=0
```

大矩阵压力回归：

```bash
make soc_regress \
  SOC_REGRESS_ITERS=20 \
  SOC_REGRESS_START_SEED=30000 \
  SOC_SIZE_LIST='4 8 16 32' \
  SOC_CACHE_BLOCKS_LIST='4 16 32 64' \
  SOC_MIN_DIM=64 \
  SOC_MAX_DIM=256 \
  SOC_REGRESS_DIM_MULTIPLE=0 \
  SOC_DATAFLOW_MODE_LIST='0' \
  SOC_REGRESS_LHS_DTYPE_LIST='1' \
  SOC_REGRESS_QUANT_MODE_LIST='0 1' \
  SOC_REGRESS_TIMEOUT=600 \
  SOC_REGRESS_SOC_TIMEOUT_CYCLES=300000000 \
  DUMPOPTS=0
```

回归输出默认在：

```text
veri/sim/runs/axi_soc_c_regression/
```

脚本会输出总览，不需要逐个打开单 case log。若失败，应先保留 seed、参数、`SOC_CASE` 目录和 `sim.log`。

## NPU 顶层 Verilator 回归

该回归位于 `veri/top_regression`，直接例化 `rtl/axi_accelerator/npu/npu_top.sv`，不经过 PicoRV32 和 AXI-Lite shell。测试平台读取 Python 生成的 `init.mem/config.mem/golden.mem`，NPU 完成后直接比较 RAM 输出区域，适合快速定位 NPU 本体 bug。

从 `veri/sim` 调用：

```bash
make npu_top_regress \
  TOP_REGRESS_SIZE=4 \
  TOP_REGRESS_IA_CACHE_BLOCKS=32 \
  TOP_REGRESS_PS_FRAME_COUNT=16 \
  TOP_REGRESS_AXI_READ_OUTSTANDING=4 \
  TOP_REGRESS_COUNT=100 \
  TOP_REGRESS_SEED=1000 \
  TOP_REGRESS_TRACE=0 \
  TOP_REGRESS_RANDOM_GEN_ARGS='--random --random_quant --lhs_dtype 0 --min_dim 1 --max_dim 64' \
  TOP_REGRESS_SIM_ARGS='+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8'
```

从 `veri/top_regression` 目录直接运行：

```bash
cd /media/proj_tmp/aiEngine_integrated/veri/top_regression

make run_random \
  SIZE=4 IA_CACHE_BLOCKS=32 PS_FRAME_COUNT=16 \
  COUNT=100 SEED=1000 TRACE=0 \
  RANDOM_GEN_ARGS='--random --random_quant --lhs_dtype 0 --min_dim 1 --max_dim 64' \
  SIM_ARGS='+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8'
```

参数化随机回归：

```bash
make run_param_random \
  SIZES='4 8 16 32' \
  CACHE_BLOCKS_LIST='4 8 16 32 64' \
  PS_FRAME_COUNT=16 \
  COUNT=20 \
  SEED=40000 \
  TRACE=0
```

输出：

```text
veri/top_regression/out/random_summary.md
veri/top_regression/out/random_summary.csv
veri/top_regression/out/random_summary.jsonl
veri/top_regression/out/param_summary.md
veri/top_regression/out/param_summary.csv
veri/top_regression/out/param_summary.jsonl
```

## TFLM / NMSIS-NN 推理测试

TFLM 入口同样在 `veri/sim`。硬件加速通过 NMSIS-NN 的定制函数调用 NPU；关闭 `TFLM_NMSIS_NN_ENABLE` 后走纯软件路径。

### MNIST MLP 硬件路径

```bash
make tflm_mnist_mlp_run \
  MMA_SIZE=4 \
  MMA_IA_CACHE_BLOCKS=32 \
  MMA_PS_FRAME_COUNT=4 \
  SOC_CPU_MEM_DP=65536 \
  SOC_CPU_ENABLE_ICACHE=1 \
  TFLM_SOC_MMA_ENABLE=1 \
  TFLM_NMSIS_NN_ENABLE=1 \
  SOC_TIMEOUT_CYCLES=320000000 \
  DUMPOPTS=0
```

### MNIST MLP 纯软件路径

```bash
make tflm_mnist_mlp_run \
  MMA_SIZE=4 \
  MMA_IA_CACHE_BLOCKS=32 \
  MMA_PS_FRAME_COUNT=4 \
  SOC_CPU_MEM_DP=65536 \
  SOC_CPU_ENABLE_ICACHE=1 \
  TFLM_SOC_MMA_ENABLE=0 \
  TFLM_NMSIS_NN_ENABLE=0 \
  SOC_TIMEOUT_CYCLES=320000000 \
  DUMPOPTS=0
```

### MNIST CNN 硬件路径

```bash
make tflm_mnist_cnn_run \
  MMA_SIZE=4 \
  MMA_IA_CACHE_BLOCKS=32 \
  MMA_PS_FRAME_COUNT=16 \
  SOC_CPU_MEM_DP=65536 \
  SOC_CPU_ENABLE_ICACHE=1 \
  TFLM_SOC_MMA_ENABLE=1 \
  TFLM_NMSIS_NN_ENABLE=1 \
  SOC_TIMEOUT_CYCLES=320000000 \
  DUMPOPTS=0
```

### MNIST CNN 纯软件路径

```bash
make tflm_mnist_cnn_run \
  MMA_SIZE=4 \
  MMA_IA_CACHE_BLOCKS=32 \
  MMA_PS_FRAME_COUNT=16 \
  SOC_CPU_MEM_DP=65536 \
  SOC_CPU_ENABLE_ICACHE=1 \
  TFLM_SOC_MMA_ENABLE=0 \
  TFLM_NMSIS_NN_ENABLE=0 \
  SOC_TIMEOUT_CYCLES=320000000 \
  DUMPOPTS=0
```

### 其他 TFLM 示例

```bash
make tflm_hello_world_run DUMPOPTS=0
make tflm_micro_speech_run DUMPOPTS=0
make tflm_person_detection_run DUMPOPTS=0
make tflm_my_model_run DUMPOPTS=0
```

### 只生成 FPGA 用 MNIST firmware

FPGA 150 MHz、UART 115200 bps 时，firmware 要写入 `SOC_UART_CLKDIV=1300`。只生成 `cpu.mem` 不运行仿真：

```bash
make tflm_mnist_mlp_soc_c \
  SOC_CASE=axi_soc_tflm_mnist_mlp_hw \
  TFLM_SOC_MMA_ENABLE=1 \
  TFLM_NMSIS_NN_ENABLE=1 \
  MMA_SIZE=4 \
  MMA_IA_CACHE_BLOCKS=32 \
  MMA_PS_FRAME_COUNT=4 \
  SOC_CPU_MEM_DP=65536 \
  SOC_UART_CLKDIV=1300
```

输出：

```text
veri/tb/axi_soc_tflm_mnist_mlp_hw/cpu.mem
veri/tb/axi_soc_tflm_mnist_mlp_hw/cpu.elf
veri/tb/axi_soc_tflm_mnist_mlp_hw/cpu.map
```

检查 UART 分频：

```bash
riscv64-unknown-elf-objdump -d \
  veri/tb/axi_soc_tflm_mnist_mlp_hw/cpu.elf \
  | rg -n 'picosoc_uart_init|li\\s+.*1300|2000004'
```

## 性能扫描

性能扫描使用 `run_axi_soc_perf_sweep.py`，支持并行运行多个 case。建议关闭波形并充分利用 CPU 核心。

### SIZE 与 IA cache 扫描

```bash
make soc_perf_sweep \
  SOC_PERF_DIMS='128x128x128 256x256x256 512x512x512' \
  SOC_PERF_SIZE_LIST='4 8 16 32 64' \
  SOC_PERF_CACHE_BLOCKS_LIST='4 8 16 32 64 128 256' \
  SOC_PERF_DATAFLOW_MODE_LIST='0' \
  SOC_PERF_LHS_DTYPE_LIST='1' \
  SOC_PERF_QUANT_MODE_LIST='0' \
  SOC_PERF_JOBS=8 \
  SOC_PERF_KEEP_GOING=1 \
  SOC_PERF_TIMEOUT=900 \
  SOC_PERF_SOC_TIMEOUT_CYCLES=300000000 \
  DUMPOPTS=0
```

### 固定大延迟测试

用于分析 IA cache 在高内存响应延迟下的收益。`RAM_FIXED_LAT=50` 表示 burst 之间固定等待 50 周期，burst 内连续返回。

```bash
make soc_perf_sweep \
  SOC_PERF_DIMS='256x256x256 512x512x512' \
  SOC_PERF_SIZE_LIST='4 8 16' \
  SOC_PERF_CACHE_BLOCKS_LIST='4 16 32 64' \
  SOC_PERF_RAM_FIXED_LAT=50 \
  SOC_PERF_JOBS=8 \
  SOC_PERF_KEEP_GOING=1 \
  SOC_PERF_TIMEOUT=900 \
  SOC_PERF_SOC_TIMEOUT_CYCLES=300000000 \
  DUMPOPTS=0
```

### 固定容量 SIZE/cache 扫描

若需要手动指定 `SIZE:CACHE_BLOCKS` 组合，可直接调用脚本：

```bash
python3 run_axi_soc_perf_sweep.py \
  --dims '256x256x256 512x512x512' \
  --size-cache-pairs '4:64 8:16 16:4 32:1' \
  --dataflow-modes '0' \
  --lhs-dtypes '1' \
  --quant-modes '0' \
  --jobs 8 \
  --timeout 900 \
  --soc-timeout-cycles 300000000 \
  --log-root runs/axi_soc_perf_fixed_capacity
```

性能输出目录默认：

```text
veri/sim/runs/axi_soc_perf_sweep/
```

日志中通常包含任务周期、NPU 执行周期、AXI read/write beat、等待计数、总线利用率、阵列利用率和等效 GOPS/TOPS。性能报告参考：

```text
doc/throughput_analysis/脉动阵列吞吐量与TileCache瓶颈分析.md
doc/performance_report_cn.md
doc/size_cache_hw_sw_perf_report_cn.md
doc/original_docx_report_md/性能分析.md
doc/bus_optimization_report_cn.md
```

## 覆盖率

覆盖率入口在 `veri/sim`，默认只收加速器相关层级。

模块级覆盖率：

```bash
make coverage_module COVERAGE_GOAL=95 DUMPOPTS=0
```

SoC 级覆盖率：

```bash
make coverage_soc COVERAGE_GOAL=95 DUMPOPTS=0
```

只跑覆盖率计划，不合并报告：

```bash
make cov_plan COVERAGE_GOAL=95 COV_PLAN_ARGS='--keep-going --skip-report' DUMPOPTS=0
```

手动合并：

```bash
make cov_code_report COVERAGE_GOAL=95 COV_ROOT=runs/coverage_module
make cov_code_report COVERAGE_GOAL=95 COV_ROOT=runs/coverage_soc
```

输出文件：

```text
runs/coverage_module/coverage_code_report_summary.md
runs/coverage_module/coverage_code_report_summary.json
runs/coverage_soc/coverage_code_report_summary.md
runs/coverage_soc/coverage_code_report_summary.json
```

单个测试收 coverage：

```bash
make run COV=1 DUT_MODE=axil case=ai_mem_gen_smoke_test seed=1 DUMPOPTS=0
make cov_report COVERAGE_GOAL=95
```

常用变量：

| 变量 | 说明 |
|---|---|
| `COV=1` | 单次仿真打开 VCS coverage |
| `COV_TYPES` | 默认 `line+cond+tgl+branch+fsm` |
| `COV_ACCEL_SCOPE=1` | 使用层级文件限制到加速器相关范围 |
| `COV_HIER_FILE` | 覆盖率层级文件 |
| `COV_ROOT` | coverage 输出根目录 |
| `COV_ALLOW_URG_FAIL=1` | URG 报告失败时保留日志兜底汇总 |

## Vivado SoC 综合入口

本仓库包含 SoC 顶层 batch 综合脚本：

```bash
cd /media/proj_tmp/aiEngine_integrated
mkdir -p build/logs
vivado -mode batch -source scripts/fpga/vivado_synth_soc.tcl \
  -log build/logs/vivado_soc_synth.log -journal build/logs/vivado_soc_synth.jou
```

指定输出目录：

```bash
mkdir -p build/logs
vivado -mode batch -source scripts/fpga/vivado_synth_soc.tcl \
  -log build/logs/vivado_soc_synth.log -journal build/logs/vivado_soc_synth.jou \
  -tclargs build/vivado_soc_synth_150mhz_check
```

脚本默认：

- Top 为 `soc_top`。
- FPGA part 为 `xc7a200tfbg484-3`。
- 时钟周期为 `6.667 ns`，即 150 MHz。
- `CPU_MEM_DP=65536`。
- 报告输出到指定 build 目录。

生成报告：

```text
soc_top_utilization.rpt
soc_top_utilization_hier.rpt
soc_top_timing_summary.rpt
soc_top_timing_paths.rpt
soc_top_high_fanout.rpt
soc_top_synth.dcp
```

FPGA 用 `cpu.mem` 可由 TFLM 章节的 `tflm_mnist_mlp_soc_c` 命令生成。生成后需要保证 RAM 深度与 FPGA 顶层 `CPU_MEM_DP` 一致，UART 分频与核心时钟一致。

## 日志与调试

快速查找失败：

```bash
rg -n 'FAIL|UVM_ERROR|UVM_FATAL|TRAP|TIMEOUT|mismatch|cpu_trap' veri/sim/runs
```

查找性能统计：

```bash
rg -n 'dsa_execute_cycles|soc_finish|axi_|bus|util|GOPS|TOPS|cycles' veri/sim/runs
```

查看最新 VCS 日志：

```bash
find veri/sim/runs -path '*/sim.log' -printf '%T@ %p\n' | sort -n | tail
```

查看生成的 SoC case：

```bash
ls -la veri/tb/<SOC_CASE>
sed -n '1,120p' veri/tb/<SOC_CASE>/config.txt
```

打开 FSDB：

```bash
cd veri/sim
make vd DUT_MODE=axi_soc case=ai_axi_soc_c_test seed=1
```

Verilator 回归失败时，保留以下文件：

```text
veri/top_regression/out/config.json
veri/top_regression/out/init.mem
veri/top_regression/out/golden.mem
veri/top_regression/out/random_<seed>.log
```

常见问题：

1. 纯软件测试仍然调用硬件  
   确认同时设置 `TFLM_SOC_MMA_ENABLE=0` 和 `TFLM_NMSIS_NN_ENABLE=0`，并确认 TFLM 库已经按新的 build tag 重编。

2. 修改 RTL 后 VCS 没有重新编译  
   使用 `make force_com ...`，或者删除对应 `simv_*`、`*.daidir`、`*.csrc`。

3. FPGA UART 输出异常  
   150 MHz、115200 bps 使用 `SOC_UART_CLKDIV=1300` 重新生成 firmware；VCS 快速仿真默认使用 `SOC_UART_CLKDIV=8`。

4. SoC full case 超时  
   增大 `SOC_TIMEOUT_CYCLES`；TFLM MNIST 默认超时较大，导出 FPGA 工程时也要同步增大 testbench 超时。

5. 随机 RAM 延迟下失败  
   记录 `SIM_ARGS`、`SOC_SEED`、`SOC_CASE` 和 `sim.log`。先关闭延迟复现功能正确性，再打开延迟定位 ready/valid、outstanding 或 FIFO 排空问题。

6. `cpu.mem` 放不下  
   增大 `SOC_CPU_MEM_DP`，同时确保 link script 的 `__ram_length`、仿真顶层参数和 FPGA 顶层参数一致。

## 清理生成文件

查看可清理的 EDA 临时日志和综合崩溃转储，随后执行删除：

```bash
python3 scripts/maintenance/clean_tool_outputs.py
python3 scripts/maintenance/clean_tool_outputs.py --apply
```

清理脚本保留 Git 已跟踪的文件、仿真结果日志、设计文档、发布包及 `paper/`。

VCS：

```bash
cd /media/proj_tmp/aiEngine_integrated/veri/sim
make clean
```

覆盖率：

```bash
make cov_clean COV_ROOT=runs/coverage
make cov_clean COV_ROOT=runs/coverage_module
make cov_clean COV_ROOT=runs/coverage_soc
```

Verilator NPU 顶层：

```bash
make -C /media/proj_tmp/aiEngine_integrated/veri/top_regression clean
```

Vivado：

```bash
rm -rf /media/proj_tmp/aiEngine_integrated/build/vivado_soc_synth*
rm -rf /media/proj_tmp/aiEngine_integrated/.Xil
```

生成目录 `veri/sim/runs/`、`veri/top_regression/out/`、`veri/top_regression/obj_dir/`、`build/`、`.Xil/`、`*.log`、`*.fsdb`、`*.vcd` 不应作为源码提交。

## 推荐提交前检查

小范围 RTL 修改：

```bash
cd /media/proj_tmp/aiEngine_integrated/veri/sim
make npu_top_regress TOP_REGRESS_SIZE=4 TOP_REGRESS_IA_CACHE_BLOCKS=32 \
  TOP_REGRESS_PS_FRAME_COUNT=16 TOP_REGRESS_COUNT=20 TOP_REGRESS_TRACE=0
```

寄存器或 AXI-Lite 修改：

```bash
make run DUT_MODE=axil case=ai_mem_gen_smoke_test seed=20260413 DUMPOPTS=0
make run DUT_MODE=axil case=ai_ral_mem_gen_on_calc_start_test seed=20260414 DUMPOPTS=0
make run DUT_MODE=axil case=ai_axil_reg_directed_test seed=20260415 DUMPOPTS=0
```

SoC 互连、RAM、DMA、loader 或 writer 修改：

```bash
make soc_regress \
  SOC_REGRESS_ITERS=30 \
  SOC_SIZE_LIST='4 8 16' \
  SOC_CACHE_BLOCKS_LIST='4 16 32' \
  SOC_DATAFLOW_MODE_LIST='0 1' \
  SOC_REGRESS_DDR_RAND_LAT=1 \
  SOC_REGRESS_UNALIGNED_LAYOUT=1 \
  SOC_REGRESS_TIMEOUT=300 \
  SOC_REGRESS_SOC_TIMEOUT_CYCLES=120000000 \
  DUMPOPTS=0
```

TFLM/NMSIS-NN 修改：

```bash
make tflm_mnist_mlp_run TFLM_SOC_MMA_ENABLE=1 TFLM_NMSIS_NN_ENABLE=1 DUMPOPTS=0
make tflm_mnist_mlp_run TFLM_SOC_MMA_ENABLE=0 TFLM_NMSIS_NN_ENABLE=0 DUMPOPTS=0
make tflm_mnist_cnn_run TFLM_SOC_MMA_ENABLE=1 TFLM_NMSIS_NN_ENABLE=1 DUMPOPTS=0
make tflm_mnist_cnn_run TFLM_SOC_MMA_ENABLE=0 TFLM_NMSIS_NN_ENABLE=0 DUMPOPTS=0
```

覆盖率检查：

```bash
make coverage_module COVERAGE_GOAL=95 DUMPOPTS=0
make coverage_soc COVERAGE_GOAL=95 DUMPOPTS=0
```

FPGA 前准备：

```bash
make tflm_mnist_mlp_soc_c \
  SOC_CASE=axi_soc_tflm_mnist_mlp_hw \
  TFLM_SOC_MMA_ENABLE=1 TFLM_NMSIS_NN_ENABLE=1 \
  MMA_SIZE=4 MMA_IA_CACHE_BLOCKS=32 MMA_PS_FRAME_COUNT=4 \
  SOC_CPU_MEM_DP=65536 SOC_UART_CLKDIV=1300
```

## 参考文档

项目文档统一放在仓库根目录的 `doc/`；性能分析与实现记录仍由 `veri/sim` 和 RTL 源目录承载。

```text
drivers/README.md
drivers/registers_v2.md
veri/top_regression/README.md
doc/axi_soc_readme.md
doc/rtl_simulation_report.md
doc/coverage_report_cn.md
doc/performance_report_cn.md
doc/size_cache_hw_sw_perf_report_cn.md
doc/bus_optimization_report_cn.md
doc/original_docx_report_md/rtl_fpga_validation_report_cn.md
doc/original_docx_report_md/性能分析.md
```
