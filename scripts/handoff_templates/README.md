# aiEngine 仿真交接包

本包用于在没有 Verilator 的 Linux x86_64 环境中，通过 Python 驱动原 NPU RTL 做周期级仿真。默认入口只依赖 Python 3.9+ 标准库；已附静态 RTL 运行后端、当前工作树源码、AXI RAM 模型、输入与 golden、设计报告，以及逐周期一致性记录。

建议将本包与 `AGENT_TASK.md` 一起交给执行测试的 agent。源代码快照包含未提交的工作树修改，基准 Git 提交和文件校验值见 `SOURCE_SNAPSHOT.json` 与 `MANIFEST.sha256`。

## 立即运行

解压后进入本目录：

```bash
python3 verify_package.py
python3 veri/python_model/run.py \
  --case veri/python_model/examples/ws_int8_tail \
  --single-step --trace results/smoke.csv --result results/smoke.json
python3 veri/python_model/validate_cycle_equivalence.py \
  --quick --output results/cycle_quick
```

成功条件为退出码 0、RTL 日志出现 `[TB] PASS`，且结果 JSON 的 `passed=true`。一致性检查还要求 `all_cycle_signals_identical=true`。默认测试不调用 Verilator、VCS、g++ 或 pip。

预编译硬件组合：16×16 阵列、32 bit AXI、读 outstanding=4、PS frame=16，IA cache blocks 分别为 4、8、16、32。后端是原 RTL 编译后的静态程序，Python 每次 `step()` 推进一个时钟样本，`run()` 可连续推进。它不是手写近似时序模型。具体 API、周期定义、输入生成和重建方法见 [Python 模型说明](veri/python_model/README.md)。

## 项目与代码入口

NPU 包含 IA loader/cache、kernel loader、权重驻留脉动阵列、部分和缓存、量化、输出 FIFO、AXI DMA 与控制器。矩阵计算为 A[K,N] × B[N,M]；外部 RHS 按输出列展开存储，每列的 N 个元素连续存放。配置中的 `lhs_zp/rhs_zp` 是加到操作数上的 offset。

| 路径 | 用途 |
|---|---|
| `rtl/axi_accelerator/npu/` | 原始 NPU RTL，Python 后端的计算与控制来源 |
| `veri/top_regression/` | 原 NPU 顶层 testbench、DDR AXI RAM、纯 Python 输入/golden 生成器 |
| `veri/python_model/` | Python 周期接口、预编译后端、冻结 C++、对照记录 |
| `rtl/axi_accelerator/soc*`、`picorv32/` | PicoRV32 SoC 集成源码 |
| `veri/sim/`、`veri/env/` 等 | 原 VCS/UVM SoC 验证平台 |
| `veri/soc_csrc/`、`drivers/` | CPU firmware、MMIO 驱动、TFLM/NMSIS-NN 适配源码 |
| `drivers/tflm/my_tflm/tflite-micro/` | TFLM 源码、所需第三方源码、MNIST/传感器模型及测试数据 |
| `models/` | 原 SoC Makefile 引用的额外传感器 `.tflite` 文件，已复制入包 |

Python 默认仿真包含整个 NPU、原 RAM 模型和原 testbench，范围不含 PicoRV32 执行或整网 TFLM 推理。原 SoC/VCS 测试代码也在包内；其工具与操作说明见 `PROJECT_README.md`。设计报告中的 VU3P/MicroBlaze 部署平台，与仓库用于验证的 PicoRV32 SoC 是不同顶层，阅读结果时须保持区分。

## 设计报告与分析材料

- [详细设计报告 PDF](doc/详细设计报告/NPU与传感器校准SoC详细设计技术报告.pdf)、[DOCX](doc/详细设计报告/NPU与传感器校准SoC详细设计技术报告.docx)、[Markdown](doc/详细设计报告/NPU与传感器校准SoC详细设计技术报告.md)，含图源；
- [简明设计报告 PDF](doc/简明设计报告/简明NPU与SoC设计技术报告.pdf)、同目录 DOCX/Markdown；
- [MMA 架构说明](doc/mma_architecture_design_report_cn.md)、[模块设计文档](doc/DSA模块设计文档.md)；
- [吞吐量与 tile cache 分析 PDF](doc/throughput_analysis/脉动阵列吞吐量与TileCache瓶颈分析.pdf)，同目录 DOCX/Markdown、绘图脚本与 SVG/PNG；
- `doc/原版报告_技术报告.docx`、`doc/奶龙粉丝团-30017-芯片设计及评估报告.docx` 作为已有项目报告随包提供；
- 既有性能、总线、覆盖率报告和图表保存在 `doc/`。

报告中的理论值、旧仿真结果和本包新执行结果各有来源。需要重新检验的条件见 `MODEL_SCOPE.md`；不得直接把理论带宽倍率当成已测周期。

## 神经网络模型

完整文件表和 SHA-256 见 `models/INDEX.json`。MNIST MLP 的当前 int8 模型为 784→64→10，含两层 FULLY_CONNECTED 与 SOFTMAX；metadata 记录 50,816 MAC/sample、101,632 ops/sample。旧性能报告可能使用更大的另一版本模型，测试时以本包模型文件的 SHA-256 和 metadata 为准。

还附有 MNIST s16×s8、CNN，以及传感器校准模型、C/C++ 数组与 golden 数据。Python NPU 接口接受生成器的矩阵任务，并不解析 `.tflite` 运行整网。运行整网需原 TFLM/SoC 流程和相应工具。原 Makefile 中 20261016/20261019 模型默认值为发送方绝对路径；接收方应以命令行变量改为本包路径，例如：

```bash
make -C veri/sim tflm_sensor_calibration_20261019_run \
  TFLM_SENSOR_CALIBRATION_20261019_MODEL="$(pwd)/models/sensor_calibration_20261019/sensor_calibrator_complete_int16.tflite" \
  SIM_LAUNCHER=
```

此命令需要 VCS 和 RISC-V 交叉工具链，不属于默认 Python 测试。模型训练原始数据及重新训练环境未打包；已有推理输入与 golden 已提供。

## 已执行的验证

发送方对四种 cache 配置执行了 12 组 Python/独立原 RTL testbench 对照，累计比较 72,461 个周期样本、每样本 98 个字段，全部一致；完整比较区内存也全部匹配 golden。包括 WS/IS、s8/s16、s16 输出、per-channel、尾块、非对齐 stride、无 bias、固定和随机 RAM 延迟。结果见 `veri/python_model/validation/summary.json`，完整轨迹保存为 `.csv.gz`。

接收方可以直接重新运行全部对照：

```bash
python3 veri/python_model/validate_cycle_equivalence.py --output results/cycle_full
```

一致性记录验证了这份 RTL 快照的 Python 入口与 Verilator 原 testbench 入口，未将其扩展成 VCS 四态、门级或 FPGA 实物测试结论。

另有未加入观察器的原 testbench 对照：同样 12 组用例的 golden 均通过，所有启动/完成时间戳保持一致，见 `veri/python_model/validation/observer_noninterference.json`。封包前还在 `PATH` 为空的环境中，仅以系统 Python 重跑了全部对照；记录见 `PACKAGING_CHECKS.json`。
