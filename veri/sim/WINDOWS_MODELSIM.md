# Windows / ModelSim

`Makefile` 从 `oldMakefile` 派生，保留原任务，通过 `simtool=modelsim|vcs` 选择后端。Windows 默认 ModelSim，Linux 默认 VCS。工具可执行与测试通过是两件事；模型缺失或覆盖率门槛失败不能算通过。

```bash
cd /d/courseware/mst4/aiEngine_integrated/veri/sim
make help
make run simtool=modelsim DUT_MODE=axil case=ai_mem_gen_smoke_test DUMPOPTS=0
make npu_top_regress simtool=modelsim TOP_REGRESS_COUNT=2
make tflm_hello_world_run simtool=modelsim DUMPOPTS=0
```

## 工具配置

本机使用 ModelSim SE-64 10.4、自带的 `mtiUvm` UVM 1.1d、Windows RISC-V GCC 14.2.0 和 GNU make 4.4.1。外层 GNUWin make 3.81 仍可作为入口。原 VCS 分支保留 UVM 1.2 配置。

`windows.local.mk` 是不提交的本机配置，包含工具链、构建目录及本机已有的许可环境路径。没有修改许可内容。MSYS 会丢失一些 Windows 环境变量，因此这里显式传递它们。

可从 PowerShell 重新生成本机配置：

```powershell
python configure_windows.py --gcc-bin ../../build/riscv14/bin --make C:/msys64/usr/bin/make.exe --build-root ../../build/windows
```

`setup_windows_deps.py` 下载依赖并应用工程原有补丁；`install_riscv_toolchain.py <目录>` 下载 GCC；`prepare_tflm_data.py` 从已有模型、图片及音频生成 C 数组，需要 NumPy/Pillow。`MODELSIM_BIN`、`MSIM_UVM_HOME` 环境变量可覆盖工具与宏文件目录。

工具链和构建产物使用 `build/riscv14`、`build/windows` junction 引用任务目录，避免过长路径和 D 盘空间问题。PicoRV32 子模块固定在当前仿真所用的官方提交 `ef203c2b0a3fb793280f5114941416c425c5b461`。从仓库根目录执行 `git submodule update --init` 即可获取。打包的源码也可通过 `setup_windows_deps.py` 下载同一提交的归档。

ModelSim 默认 RAM 为 262144 个 32-bit words（1 MiB），容纳新版 GCC 生成的整网镜像，可显式覆盖 `SOC_CPU_MEM_DP`。VCS 原默认值不变。

`tflm_sensor_calibration_20261019_run` 的 ModelSim 默认预算单独为 524288 words（2 MiB），变量为 `TFLM_SENSOR_CALIBRATION_20261019_MEM_DP`；显式命令行 `SOC_CPU_MEM_DP` 仍可覆盖。该模型本身已有 1354592 字节，另需 262144 字节 arena 和程序空间，不能沿用普通 1 MiB 默认值。预算按源码静态分析设置，缺失原模型期间未验证实际占用。

## 任务与产物

| 任务 | ModelSim 分支 |
|---|---|
| `com/force_com` | 转换原 filelist、宏、参数，生成独立 ModelSim library 和 JSON 编译标记 |
| `run/sim`、各模型 `*_run` | 准备真实 firmware 后 `vsim -c` 运行；检查工具退出码、TEST PASS 和 UVM 错误 |
| `soc_regress/soc_perf_sweep` | 原脚本继承导出的 `simtool`，多次调用 ModelSim 后端 |
| `npu_top_regress` | ModelSim 执行原 NPU TB/DDR 模型及 Python golden；支持 AXI outstanding 参数和 `TOP_REGRESS_TRACE=1` WLF |
| 覆盖率 suite | 运行原计划，保存原生 UCDB；补充校准模型 INT16 输出、DMA 跨 4 KiB、4097 元素长行激励 |
| `cov_report/cov_code_report` | `definition` 模式按原 line 合约合并源码行证据；`instance` 模式使用原生 UCDB statement 报告，均检查门槛 |
| `vd` | 打开已有 WLF；先用 `DUMPOPTS=1` 记录波形 |
| firmware/data target | 保留软件构建流程，不要求 HDL 仿真器 |
| host 分析 target | 纯软件 TFLM host 库，Windows 工具静态链接，避免 MinGW DLL 冲突 |

ModelSim 实际产生 WLF/UCDB，不产生 FSDB/VCS VDB，也不依赖 Verdi/URG。默认 `coverage/coverage_module/coverage_soc` 保留旧流程的 `line`、`definition` 合约：分别用 `vcover report -details -byfile -code s` 导出每个 UCDB，以源码文件和行号做并集，某个配置命中即记该行命中，再应用已有 `coverage_line_exclude.json`。保留 `native_line_evidence.json`、源码 SHA-256、未命中行和原始报告。这样避免 ModelSim 10.4 直接合并不同参数布局时崩溃或丢数据；它不代表 VCS 的 functional/group coverage。

`coverage_soc` 使用 SoC 测试激励，默认统计范围仍是 NPU 加速器（与 `oldMakefile` 一致）。若需统计整个 SoC，可显式设置 `COV_ACCEL_SCOPE=0 COV_HIER_FILE=`，其覆盖率需单独评估。

ModelSim 的 `cov_plan/cov_report/cov_code_report` 也默认 `COV_VDB_MERGE_MODE=definition`。旧计划里的 `ai_coverage_test` 原来没有实现，现作为维护中的 `ai_mem_gen_smoke_test` 别名运行；该入口不构成功能 covergroup 达到 95% 的证明。ModelSim 的这几个报告入口检查上述 code line 合约；VCS 仍保留原 functional/group 报告流程。

默认日志：`runs/modelsim/<DUT_MODE>/<SOC_CASE>/<case>/seed_<seed>/`。计划显式指定 `OUT_DIR` 时保留原路径。不同模型不再因共享 UVM 类名而默认覆盖日志。

## 已修复的工程问题

- 递归 make 路径含空格、系统库 ini 定位、MSYS/原生环境传递。
- Windows 源码发现、对象路径、归档响应文件及构建依赖缓存。
- MSYS 子 make 不保证继承 `OS`，因此父 make 显式传递 `PYTHON`；TFLite core 源码列表为空时立即失败，防止生成缺符号的静态库。
- C 数组生成器的路径分隔符。
- case firmware stride 校验与数据生成器不一致。
- NMSIS 定制驱动遗漏 ABI 2 四个分组寄存器。
- int8 MLP 引用 int16 专属常量；person detection 引用当前库未提供的专用注册函数。
- CPU 明确 trap 时提前失败，并正确处理复位前 X。

## 当前验证边界

已通过：AXI-Lite 寄存器/smoke/RAL，SoC runtime/case，默认 10 次 SoC 随机回归与性能扫描，20 个 NPU 随机种子（AXI read outstanding=2，WLF 开启），hello_world、my_model（Z/W 两张图片）、micro_speech、person_detection（两张图片、默认 ICACHE=0 及 ICACHE=1）、MNIST MLP int8/int16x8、CNN、sensor_calibration_int16x8、sensor_calibration_release_20261015。host MNIST 完整 10000 样本评估完成（int8 93.10%、int16x8 93.21%），release 校准模型 6825 条 host 样本通过。WLF 记录与 `make vd WAVE_BATCH=1` 实际加载通过；`clean` 在独立临时目录验证通过。

原 module/SoC 计划的功能测试通过；按上述源码行 definition 并集，二者均为 2521/2587 = 97.4488%，超过原 95% 门限。statement/line 分母不同，不能混用其分数。完整入口复跑的日志为 `runs/msim_coverage_end_to_end.log`。

| 实际执行的入口 | 验证结果 / 证据 |
|---|---|
| `help`（外层 GNU make 3.81） | 无解析错误；`runs/msim_help_final.log` |
| `run/sim/com/force_com`、AXI-Lite 寄存器/smoke/RAL | 编译及 TEST PASS，UVM ERROR/FATAL=0；`runs/msim_*console.log` |
| `soc_case/soc_c/soc_runtime_c` | 生成真实数据/firmware，case 与 runtime 模式均完成 golden 比对 |
| `soc_regress` 默认参数 | 10/10；`runs/msim_regress_final.log` |
| `soc_perf_sweep` 默认参数 | WS/IS 与 reuse 共 8/8；`runs/axi_soc_perf_sweep/summary.txt` |
| `npu_top_regress TOP_REGRESS_COUNT=20 TOP_REGRESS_AXI_READ_OUTSTANDING=2 TOP_REGRESS_TRACE=1` | 20/20；`runs/modelsim_npu_top/summary.json`、每种子的 WLF |
| 已有模型 `*_soc_c` / `*_run`、`tflm_run` 别名 | 真实模型推理通过；各 `runs/msim_tflm_*.log`，别名复验见 `runs/msim_tflm_alias_final.log` |
| `tflm_mnist_accuracy/tflm_mnist_accuracy_run` | 10000 样本；`runs/msim_host_validation.log` |
| `tflm_sensor_calibration_release_20261015_host/host_run` | 6825 样本；`runs/msim_host_validation.log` |
| `coverage` / `coverage_module` | 完整 33 项计划及 95% 门限通过；`runs/coverage_module/coverage_plan_results.json` |
| `cov_plan` 默认参数 / `cov_report` | 完整 34 项计划及 95% 门限通过；`runs/coverage/coverage_plan_results.json` |
| `coverage_soc` | 完整 30 项计划及 95% 门限通过；`runs/coverage_soc/coverage_plan_results.json` |
| `cov_code_report` | 两类 suite 的报告入口已通过；`runs/*/coverage_code_report_summary.json` |
| `vd WAVE_BATCH=1` | 实际加载 WLF；`runs/msim_wave_view.log` |
| `cov_clean/clean` | 前者已在完整 suite 中执行；后者在 `build/clean_target_check` 隔离目录执行 |

三个完整覆盖入口均已通过。person detection 默认 ICACHE=0 在 370517763 周期内通过，原生仿真耗时 20 分 59 秒，日志为 `runs/msim_person_default_final.log`。

修复子 make 的 Python 传递后，已重建 RV32/host 静态库并重新通过 `tflm_run`、MNIST MLP int8/int16x8、CNN、sensor INT16 输出及 host 校准；日志为 `runs/msim_tflm_alias_final.log`、`runs/msim_post_archive_final.log`、`runs/msim_host_final.log`。最终机器可读清单为 `runs/modelsim_validation.json`。

person detection 保留两张图片的分类检查。旧 320000000 周期预算不足，现默认提高至 400000000。默认配置已完整通过：两张 invoke 分别为 169314708 / 169314839 周期；启用指令缓存时为 130210320 / 130210382 周期。两种配置的分类分别为 person=1 / no_person=0，UVM ERROR/FATAL 均为 0。日志见 `runs/msim_person_default_final.log`、`runs/msim_person_icache.log`。

```bash
make tflm_person_detection_run simtool=modelsim
make tflm_person_detection_run simtool=modelsim DUMPOPTS=0 SOC_CPU_ENABLE_ICACHE=1
```

20261016/20261019 两个入口依赖原开发机的专用模型，当前检出缺失，默认路径在 `/home/etc/...`。它们有固定张量/golden 合约，不能用仓库中的 20261015 模型替换。缺失时明确失败，不能宣称全部 target 已通过。原文件恢复后分别设置：

```bash
make tflm_sensor_calibrator_20261016_run simtool=modelsim TFLM_SENSOR_CALIBRATOR_20261016_MODEL=D:/actual/sensor_calibrator_int16.tflite
make tflm_sensor_calibration_20261019_run simtool=modelsim TFLM_SENSOR_CALIBRATION_20261019_MODEL=D:/actual/sensor_calibrator_complete_int16.tflite
```

它们对应的两个 `*_soc_c` firmware target 同样依赖这些模型。VCS 分支只做了命令生成检查，本机没有执行 VCS 仿真。当前 `simtool` 接受 `modelsim` 和 `vcs`；`vcs` 分支的 `npu_top_regress` 保留旧 Verilator 流程。Icarus 未实现本工程的 UVM 后端。

保留测试证据后再执行 `clean/cov_clean`。它们不删除本机配置或已下载工具链；`clean` 也不删除 TFLM 软件库。
