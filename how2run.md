# how2run：SoC 仿真速查

主线有 **4 个层级**，另有 NPU 周期观察接口和板级 RAM 专项。下面的 check 指代码实际检查项；本机实际验证记录见 [Windows ModelSim 指南](veri/sim/WINDOWS_MODELSIM.md)。

需要了解每个 make target 的内部流程和相互关系，见 [Makefile target 详解](veri/sim/MAKE_TARGETS.md)。

列表回归入口：在 `veri/sim` 执行 `make regr regrlist=smoke simtool=modelsim`。可换成 `soc`、`directed`、`tflm`、`random`、`all` 或自定义 `.list`；逐行注释、实时彩色结果、独立目录和判据配置见 [列表回归说明](veri/sim/MAKE_TARGETS.md#列表回归make-regr)。

| 层级 | 仿真范围 | 实际 check |
|---|---|---|
| 1. NPU 本体 | `npu_top` + AXI DDR 行为模型；无 CPU、AXI-Lite shell | 启动/完成、`err_code=0`、输出矩阵逐元素与 Python golden 一致；超时检测 |
| 2. NPU 外设 | AXI-Lite shell + NPU + RAM，UVM 充当 host | 寄存器读回；运算输出与 golden；done/IRQ 清除；RAL 配置路径 |
| 3. SoC 裸机 | PicoRV32 + 互连 + RAM/UART + NPU，CPU 执行 C 驱动 | firmware 检查配置/驱动返回值并比对输出；UVM 检查 finish、status、trap、超时 |
| 4. SoC 整网 | 上述 SoC + TFLM/NMSIS-NN + 模型 | 初始化、张量约定、Invoke 成功、样本输出/分类；具体精度判据依模型而异 |

## 先准备环境

Windows Git Bash 下，当前 Makefile 默认 `simtool=modelsim`，下面四层均可使用本机 ModelSim，不需要 VCS/Verilator。本机工具链和 GNU make 4 已配置在忽略提交的 `windows.local.mk`，外层 GNUWin make 3.81 可继续作为入口。完整配置见 [Windows ModelSim 指南](veri/sim/WINDOWS_MODELSIM.md)。

Linux/WSL Bash 下默认 `simtool=vcs`：第 1 层保留 Verilator/g++，第 2～4 层使用 VCS/UVM，CPU firmware 还需要 RISC-V GCC/G++/ar/objcopy。两种后端均需 Python 3、GNU make、NumPy。

```bash
cd /path/to/aiEngine_integrated/veri/sim
make help
# VCS/交叉编译工具链加入 PATH；需要时设置 VCS_HOME。
# 默认 SIM_LAUNCHER=./run_simv_lxc.sh；本机直接执行 simv 时附加 SIM_LAUNCHER=
```

已有模型推理不要求安装 TensorFlow；重新训练/转换模型才使用 TF 环境。`DUMPOPTS=0` 关闭波形；ModelSim 的 `DUMPOPTS=1` 记录 WLF，VCS 记录 FSDB 还需配置 `NOVAS_HOME`。

可在任意命令后附加 `simtool=modelsim` 或 `simtool=vcs` 显式选择。Git Bash 本身不提供仿真器。

## 1. NPU 本体：先快速排查计算/DMA

在 `veri/sim`：

```bash
make npu_top_regress TOP_REGRESS_SIZE=4 TOP_REGRESS_IA_CACHE_BLOCKS=32 \
  TOP_REGRESS_PS_FRAME_COUNT=16 TOP_REGRESS_COUNT=10 TOP_REGRESS_SEED=1000 \
  TOP_REGRESS_TRACE=0
```

默认随机尺寸/量化/int8或int16输入，WS 数据流，RAM 随机延迟。**IS 需显式指定**：

```bash
make npu_top_regress TOP_REGRESS_COUNT=10 \
  TOP_REGRESS_RANDOM_GEN_ARGS='--random --random_quant --lhs_dtype 0 --min_dim 1 --max_dim 32 --dataflow_mode 1'
```

check：默认只比输出有效元素（支持 s8/s16 输出）；`TOP_REGRESS_SIM_ARGS='+FULL_MEM_CHECK'` 可改为比较 `compare_words` 指定的完整内存区，同时会替换默认随机延迟参数。通过看 `[TB] PASS` 和 `[run_random] PASS=10 FAIL=0`；ModelSim 汇总在 `veri/sim/runs/modelsim_npu_top/summary.json`，Verilator 汇总在 `veri/top_regression/out/random_summary.md`。

## 2. NPU AXI-Lite 外设：寄存器与运算

在 `veri/sim`：

```bash
make run DUT_MODE=axil case=ai_axil_reg_directed_test DUMPOPTS=0
make run DUT_MODE=axil case=ai_mem_gen_smoke_test DUMPOPTS=0
make run DUT_MODE=axil case=ai_ral_mem_gen_on_calc_start_test DUMPOPTS=0
```

- `reg_directed`：地址、尺寸、stride、offset、量化/激活、CTRL、reuse 写读回，以及未映射地址读零；不启动运算，STATUS/WB_DATA 读取未启用期望值比较。
- `mem_gen_smoke`：生成输入/golden、写配置并启动，scoreboard 逐个 s8 输出比对；另检查 `STATUS[2]` 写 1 清除和 IRQ 撤销。
- `ral_mem_gen_on_calc_start`：经 RAL 写配置，monitor 在 calc_start 触发数据生成，完成后走输出比对。

通过看 `MAT_CHK ... PASS`（运算用例）和 `TEST PASS`，且 `UVM_ERROR/UVM_FATAL` 计数均为 0。

## 3. SoC 裸机：CPU 真正配置并调用 NPU

在 `veri/sim`：

```bash
make run DUT_MODE=axi_soc SOC_APP=runtime case=ai_axi_soc_c_test \
  MMA_SIZE=4 MMA_IA_CACHE_BLOCKS=32 MMA_PS_FRAME_COUNT=16 \
  SOC_K=32 SOC_N=32 SOC_M=32 SOC_LHS_DTYPE=1 \
  SOC_QUANT_MODE=0 SOC_DATAFLOW_MODE=0 SOC_CPU_MEM_DP=65536 \
  SOC_TIMEOUT_CYCLES=50000000 DUMPOPTS=0
```

`runtime` 复用 firmware，数据从 `runtime_data.mem` 装入；换成 `SOC_APP=case` 则把数据编进 `cpu.mem`。两者都由 **C 程序比对输出**；`ai_axi_soc_c_test` 中虽有 RAM 比对函数，但当前 main_phase 没有调用它。

常用变化：`SOC_LHS_DTYPE=2` 为 int16 输入；`SOC_QUANT_MODE=1` 为 per-channel；`SOC_DATAFLOW_MODE=1` 为 IS；`SOC_UNALIGNED_LAYOUT=1` 覆盖非对齐布局。RAM 背压用：

```bash
# 把此参数追加到上面的 make run
SIM_ARGS='+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8'
```

CPU 寄存器专项（不计算矩阵）：

```bash
make run DUT_MODE=axi_soc SOC_APP=case case=ai_axi_soc_c_test \
  SOC_CASE=axi_soc_reg_directed SOC_C_SRC=../soc_csrc/soc_reg_directed_main.c \
  SOC_TIMEOUT_CYCLES=50000000 DUMPOPTS=0
```

额外 check：ID、ready、配置读回、ABI=2、四个预计算分组寄存器、DATAFLOW/CTRL 联动、字节写 strobe、未映射读零。

随机回归仍属于本层；以下对 WS/IS × int8/int16 × 两种量化 **每组合跑 5 次**（共 40 次）：

```bash
make soc_regress SOC_REGRESS_ITERS=5 SOC_REGRESS_START_SEED=10000 \
  SOC_SIZE_LIST='4' SOC_CACHE_BLOCKS_LIST='32' SOC_PS_FRAME_COUNT_LIST='16' \
  SOC_DATAFLOW_MODE_LIST='0 1' SOC_REGRESS_LHS_DTYPE_LIST='1 2' \
  SOC_REGRESS_QUANT_MODE_LIST='0 1' SOC_MIN_DIM=1 SOC_MAX_DIM=32 \
  SOC_REGRESS_DDR_RAND_LAT=1 SOC_REGRESS_UNALIGNED_LAYOUT=1 \
  SOC_REGRESS_SOC_TIMEOUT_CYCLES=120000000 DUMPOPTS=0
```

通过：`soc_status=0x00000001`、`cpu_trap=0`、未超时且 `TEST PASS`；回归看 `runs/axi_soc_c_regression/summary.txt`。注意 `SOC_REGRESS_DIM_MULTIPLE=0` 实际使用阵列 SIZE 作尺寸倍数；尾块可用单次 `SOC_K=17 SOC_N=31 SOC_M=19` 定向验证。

## 4. TFLM 整网：软件栈与模型贯通

在 `veri/sim`，先跑硬件路径，再跑软件基线（均在 PicoRV32 RTL 上执行）：

```bash
make tflm_mnist_mlp_run TFLM_SOC_MMA_ENABLE=1 TFLM_NMSIS_NN_ENABLE=1 DUMPOPTS=0
make tflm_mnist_mlp_run TFLM_SOC_MMA_ENABLE=0 TFLM_NMSIS_NN_ENABLE=0 DUMPOPTS=0
```

把 target 替换为下表入口即可；硬件开关表示启用 NPU 路径，具体算子仍可能走软件回退。

| target（`make <target> ...`） | firmware 检查内容 |
|---|---|
| `tflm_mnist_mlp_run` / `tflm_mnist_cnn_run` | 内置样本分类标签一致；记录 Invoke 周期，不逐值比对全部输出张量 |
| `tflm_mnist_mlp_int16x8_run` | FC hidden、logits、最终 softmax 与 golden 逐值一致（当前容差 0），并检查标签 |
| `tflm_sensor_calibration_int16x8_run` | 中间 FC 和最终 int16 输出与 golden 逐值一致 |
| `tflm_sensor_calibration_release_20261015_run` | base/adapter 推理所得 V4 与 PC TFLite 参考差值 ≤2500 µV；另记录校准误差 |
| `tflm_sensor_calibration_20261019_run` | int16 输出与 golden，容差 8 LSB；需覆盖 `TFLM_SENSOR_CALIBRATION_20261019_MODEL=/实际模型路径` |
| `tflm_sensor_calibrator_20261016_run` | 张量约定及预期量化输出（容差 16 LSB）；需覆盖 `TFLM_SENSOR_CALIBRATOR_20261016_MODEL=/实际模型路径`，默认 RAM 很大 |
| `tflm_my_model_run` / `tflm_micro_speech_run` | 分别检查 Z/W、yes/no 内置样本分类 |
| `tflm_hello_world_run` / `tflm_person_detection_run` | 分别检查正弦输出范围、有人/无人样本判别 |

通过：对应 `[tflm] ... PASS`，再满足第 3 层 SoC 判据。这里是内置样本回归；`make tflm_mnist_accuracy_run` 是 host 端精度测试，不能作为 SoC RTL 通过证据。

## 补充入口：周期观察、覆盖率和板级 RAM

**Python 周期接口**复用第 1 层 RTL，可单步、导出信号/周期；当前检出只有 backend manifest，没有二进制和 examples，先在 Linux 构建并生成 case。从仓库根目录：

```bash
python3 veri/python_model/build_backend.py --size 16 --cache 4 --ps 16 --jobs 4 --reference
python3 veri/top_regression/gen_mem.py --out_dir build/py_case \
  --size 16 --ia_cache_blocks 4 --ps_frame_count 16 --K 5 --N 19 --M 7 --lhs_dtype 1
python3 veri/python_model/run.py --case build/py_case --single-step \
  --trace build/py_case.csv --result build/py_result.json
```

通过：退出码 0、`passed=true`、`memory_mismatch_count=0`。单例一致性重验用 `python3 veri/python_model/validate_cycle_equivalence.py --only ws_int8_tail --output build/cycle_check`，比较 Python 与独立 Verilator testbench 的内存和逐周期信号，不涉及 CPU/TFLM。`--quick` 组合还需要用同样方式构建 cache=16 后端。

**覆盖率**：在 `veri/sim` 执行 `make coverage_module COVERAGE_GOAL=95 DUMPOPTS=0` 或 `make coverage_soc COVERAGE_GOAL=95 DUMPOPTS=0`。它们会先清理各自覆盖率目录；默认代码签核指标为 line，SoC 默认 scope 仅 NPU 外设子树，不等于整个 CPU/互连 SoC 覆盖率。看 `runs/coverage_{module,soc}/coverage_code_report_summary.md`。

**板级 RAM 专项**：从根目录按需执行；这些 Tcl 依赖外部 VU3P 工程、BRAM IP/初始化文件及硬编码 Linux 路径，须先适配，当前仓库不能独立直接跑：

```bash
vivado -mode batch -source veri/ram_axi_vip/run_vivado_ram_vip.tcl
vivado -mode batch -source veri/ram_axi_vip/run_uram_access_axi_vip.tcl
vivado -mode batch -source scripts/fpga/run_shared_ram_standalone.tcl
```

依次 check 模型初始化字/字节读取与写读（`[RAMVIP] PASS`）、各 URAM bank 首/中/尾及四个 byte lane（`[URAM_AXI_VIP] PASS`）、RAM 两拍读延迟和上下 lane（`SHARED_RAM_STANDALONE_RESULT=PASS`）。第二条依赖第一条生成的工程。`axi_key_write_tb.sv` 另有 AW先/W先、WSTRB 和清状态测试，但所需 Key 外设 RTL 不在本仓库，未接入统一 Makefile。

## 日志与定位

VCS 日志：`veri/sim/runs/<case>/seed_<seed>/{compile,sim}.log`；硬件参数变化复用不同 simv。修改 RTL 后需要强制编译时，用原参数执行 `make force_com ...` 再 `make run ...`。

推荐顺序：**NPU 本体 → AXI-Lite → SoC 单例/随机 → TFLM 硬件与软件基线**。性能扫描 `make soc_perf_sweep` 复用 SoC 层；Vivado 综合/实现属于硬件实现检查，不另算功能仿真层级。完整参数见 [README](README.md)、[NPU 回归](veri/top_regression/README.md)、[Python 接口](veri/python_model/README.md)。
