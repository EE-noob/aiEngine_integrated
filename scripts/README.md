# 目录与工具说明

## 项目目录

| 目录 | 内容 |
|---|---|
| `rtl/` | NPU、AXI 接口与 SoC 硬件源码 |
| `include/` | RTL 公共头文件 |
| `drivers/` | MMIO 驱动、配置接口及 TFLM/NMSIS-NN 集成 |
| `picorv32/` | PicoRV32 处理器与外设源码 |
| `veri/` | 验证环境、测试程序、仿真接口及运行脚本 |
| `veri/legacy/` | 历史验证源码 |
| `doc/` | 设计报告、验证说明、性能分析与插图 |
| `scripts/` | 按用途分类的工程工具 |
| `build/` | 编译和 FPGA 实现产生的文件 |
| `deliverables/` | 通过脚本生成的发布包 |
| `paper/` | 单独管理的论文与实验资料 |

## 工具分类

以下命令均从仓库根目录执行。

| 目录 | 用途 | 示例 |
|---|---|---|
| `scripts/fpga/` | Artix-7 前仿、综合、实现与后仿，以及各平台的导出和部署 | `python scripts/fpga/run_a7_flow.py --help` |
| `scripts/models/` | 模型检查与 RAM 初始化文件生成 | `inspect_tflite_metadata.cc`、`prepare_vu3p_uram_init.py` |
| `scripts/packaging/` | 仿真代码导出与使用说明模板 | `python3 scripts/packaging/package_simulation_handoff.py --help` |
| `scripts/maintenance/` | 工具临时文件清理 | `python3 scripts/maintenance/clean_tool_outputs.py --apply` |
| `scripts/utils/` | 文件格式和后缀批量转换 | `dos2unix.csh`、`flist_v2sv.csh` |

Artix-7 原型入口为 `run_a7_flow.py`，默认使用 `xc7a200tfbg484-3`、100 MHz 和 512 KiB 共享 RAM。它调用 `a7_flow.tcl` 运行综合与实现，使用 `a7_smoke.c` 和 `a7_smoke_tb.sv` 检查各级仿真。完整命令见 [FPGA 项目说明与运行指南](../doc/artix7_fpga_flow_cn.md)。VU3P 相关脚本使用各自的板级工程路径。

保留的 `vivado_synth_soc.tcl` 单独运行原 150 MHz 综合配置。可将其 Vivado 日志和 journal 写入构建目录：

```bash
mkdir -p build/logs
vivado -mode batch -source scripts/fpga/vivado_synth_soc.tcl \
  -log build/logs/vivado_soc_synth.log -journal build/logs/vivado_soc_synth.jou
```

共享 RAM 的测试源码位于 `veri/ram_axi_vip/`，AXI 寄存器写入测试源码位于 `veri/tb/axi_key_write_tb.sv`。Python 仿真接口的使用方法见 [仿真说明](../veri/python_model/README.md)。

## 构建产物

| 目录 | 内容 |
|---|---|
| `build/fpga_a7_<容量>k/` | Artix-7 原型默认输出目录，含固件、XSim 日志、综合或实现报告和 DCP |
| `build/vivado_soc_synth_150mhz/` | 原 150 MHz SoC 单次综合报告和检查点 |
| `build/board_artifacts/` | 按日期保存的板级构建产物 |
| `build/artifacts/` | FPGA 实现分析与历史输出 |
| `build/vivado_generated/` | 本地 Vivado IP 生成文件 |
| `build/ram_axi_vip/` | 共享 RAM 的 Vivado 仿真工程 |
| `build/xsim/` | XSim 生成文件 |

VCS 和 Verilator 的输出目录继续由各自 Makefile 管理。构建产物和发布包通过 `.gitignore` 排除。

## 临时文件清理

```bash
python3 scripts/maintenance/clean_tool_outputs.py
python3 scripts/maintenance/clean_tool_outputs.py --apply
```

默认列出匹配文件，`--apply` 执行删除。匹配范围包括 Vivado 和 updatemem 日志、对应 journal、工具备份日志、JVM 崩溃日志及根目录中的综合崩溃转储。脚本保留 Git 已跟踪的文件，并跳过文档、发布包、第三方源码及论文目录。仿真结果日志、波形、时序报告、检查点和比特流继续保存在对应输出目录。
