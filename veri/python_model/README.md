# Python 周期级 RTL 仿真接口

默认运行入口是 Python 3.9+，不需要安装 Verilator、VCS、NumPy 或其他 pip 包。随交接包提供的 `rtl_server` 是 Linux x86_64 静态可执行文件，Python 通过管道控制时钟推进并读取状态，因此接收方也不需要编译器或共享 C++ 运行库。其他操作系统或 CPU 架构需要重新构建后端。

这里的实现为“Python 接口 + 原 RTL 编译模型”，不手工近似状态机或用公式估计周期。后端完整保留：

- `rtl/axi_accelerator/npu/` 的原始 NPU RTL；
- `veri/top_regression/ddr_axi_mem_model.sv` 原 AXI DDR 行为模型；
- `veri/top_regression/tb_npu_top.sv` 原时钟、复位、启动和 golden 检查过程；
- `cycle_probe.sv` 只读观察器，不驱动 DUT。

默认模型覆盖 NPU 顶层，不执行 PicoRV32 CPU、AXI-Lite 配置软件或整个 TFLM 模型。SoC 和 TFLM 的原始代码、模型及运行入口也随交接包提供。Python 模型的周期与原 NPU 顶层 testbench 对照；SoC 周期包含 CPU、总线仲裁和软件时间，不能与它混用。

## 直接运行

在交接包根目录执行：

```bash
python3 veri/python_model/run.py --list
python3 veri/python_model/run.py \
  --case veri/python_model/examples/ws_int8_tail \
  --single-step \
  --trace results/ws_int8_tail.csv \
  --result results/ws_int8_tail.json
```

成功条件是进程退出码为 0，RTL 日志出现 `[TB] PASS`，JSON 中 `passed=true`、`memory_mismatch_count=0`。只有日志没有成功 JSON 不足以认定通过。CSV 和 JSON 的父目录会自动创建。

## 生成新的输入

输入生成器只使用 Python 标准库。例：

```bash
python3 veri/top_regression/gen_mem.py \
  --out_dir results/new_case --size 16 --ia_cache_blocks 16 \
  --ps_frame_count 16 --K 128 --N 64 --M 128 --lhs_dtype 1 \
  --ia_reuse_num 0 --w_reuse_num 0 --seed 88400
python3 veri/python_model/run.py \
  --case results/new_case --trace results/new_case.csv \
  --result results/new_case_result.json
```

也支持生成器已有的 WS/IS、s8/s16 输入、per-tensor/per-channel、非对齐 stride、尾块、无 bias 和 WS s16 输出。当前 s16 输出用例沿用原生成器的 WS/per-tensor 约束。`*_zp` 在本工程中是加到操作数上的 offset，不能自行改成减法。

参数 `SIZE/CACHE/PS` 必须匹配后端。预编译版本为 `SIZE=16`、`PS_FRAME_COUNT=16`、`IA_CACHE_BLOCKS=4/8/16/32`、AXI 32 bit、读 outstanding=4。输入生成器还会检查归约外输出维所需 PS frame 数；例如方阵 512³ 超过这组生成器配置的输出宽度限制，需要相应的 PS=32 后端，不能直接复用 PS=16 二进制。

可传递原 RAM 模型的 plusarg：

```bash
python3 veri/python_model/run.py --case results/new_case \
  --plusarg=+RAM_FIXED_LAT=8 --result results/fixed8.json
python3 veri/python_model/run.py --case results/new_case \
  --plusarg=+DDR_RAND_LAT=1 --plusarg=+DDR_CMD_MAX_LAT=3 \
  --plusarg=+DDR_W_MAX_LAT=2 --plusarg=+DDR_RSP_MAX_LAT=8 \
  --plusarg=+DDR_SEED=88400 --result results/random_latency.json
```

随机延迟直接由原 SV RAM 模型的 `$urandom` 产生；Python 不另造一套随机时间表。

## 周期与信号定义

原 testbench 使用 100 MHz 时钟，周期为 10,000 ps。观察器在每个上升沿后 1 ps 读取已稳定的状态，所以 `time_ps` 为 5,001、15,001……；这个只读观察延时不改变 DUT 的时钟、握手或计算周期。遇到原 `$finish` 后不再生成下一条样本。

每行 CSV 包含 98 个字段：周期序号、仿真时间、32 个控制/AXI 标量、16 个 IA、16 个权重、16 个累加输出和 16 个重量化输出。向量在 CSV 中以 32 bit 无符号数记录原始位型；Python `snapshot()` 返回它们的有符号解释。即使 valid=0，也保留这些位型，以便严格比较。

`axi_flags` 的 bit 0～11 依次为 ARVALID、ARREADY、RVALID、RREADY、RLAST、AWVALID、AWREADY、WVALID、WREADY、WLAST、BVALID、BREADY。在采样为高的 valid/ready 对应的传输于下一上升沿被消费；统计总线传输时必须使用同一采样约定。

JSON 的 `start_to_ready_cycles` 为采样到 `calc_start=1` 起，到经历 `sa_ready=0` 后恢复 `sa_ready=1` 的时钟周期差。复位、启动前等待和原 testbench 的结果检查尾部周期保留在 CSV 中，但不计入该差值。需统计当拍握手时，可对前一条稳定样本的 valid/ready 求与。

## Python API

```python
import sys
sys.path.insert(0, "veri/python_model")
from runtime import NpuModel

with NpuModel("veri/python_model/examples/ws_int8_tail") as model:
    while not model.finished:
        sample = model.step()
        if sample is not None and sample["acc_valid"]:
            print(sample["cycle"], sample["acc"])
    print(model.result())
```

`run()` 在同一个原 RTL 事件调度器内连续推进，适合性能扫描；`step()` 由 Python 每周期发一次指令。二者使用相同的后端状态。每个 Python 进程只允许一个活动实例；并行用例请使用独立子进程。

## 重做一致性检查

```bash
python3 veri/python_model/validate_cycle_equivalence.py --quick \
  --output results/cycle_quick
python3 veri/python_model/validate_cycle_equivalence.py \
  --output results/cycle_full
```

校验为每个用例独立运行两次：Python 驱动的模型，以及单独通过 Verilator `--binary` 构建的原 RTL testbench。检查完整比较区的内存、原 testbench 的 PASS，以及 CSV 的每一行、每一个信号位型。`ws_int8_tail` 额外通过 Python 单周期 `step()` API 推进。结果保存在 `summary.json` / `summary.csv`，原始完整轨迹保存在 `.csv.gz`。

随包保存的是这两种 Verilator 执行入口的对照记录，未将它表述为 VCS 四态仿真的跨工具证明。初始 X/Z 传播、门级延迟、FPGA 实物时序和 CPU/TFLM 执行不在本接口的验证范围中。

发送方还单独编译了未加入观察器的原 testbench，12 组用例的 golden 均通过，启动/完成时间戳与有观察器版本相同，记录见 `validation/observer_noninterference.json`。这项检查用于确认观察器没有改变原测试的任务周期。

## 源码与参数变更

每个后端的 `manifest.json` 保存原 RTL、原 testbench、RAM 模型、观察器、适配器和二进制 SHA-256。运行时默认核对这些值；修改 RTL 后会拒绝加载旧后端，避免把旧模型的周期误当成新代码的结果。

接收方有 g++、没有 Verilator 时，可以从随包的冻结 C++ 源码重建相同后端：

```bash
python3 veri/python_model/rebuild_frozen_backend.py \
  --backend s16_c4_p16 --jobs 4
```

这只重编已有 RTL 快照，不能反映后来修改的 SV。修改 SV 或增加硬件参数组合，需要在有 Verilator 5.040 或兼容版本的构建机上重新生成：

```bash
python3 veri/python_model/build_backend.py \
  --size 16 --cache 16 --ps 16 --jobs 4 --reference
```

当前总线模型与 testbench 端口固定为 32 bit，未提供 64 bit 周期后端。报告中 64 bit 的讨论是设计分析；需要完成 HDL 数据通路、RAM 模型和 testbench 的相应修改后，才能生成可用于实测的 64 bit 模型。
