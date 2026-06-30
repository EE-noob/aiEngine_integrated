# DUT_MODE=axi_soc 使用说明

`DUT_MODE=axi_soc` 是一个 SoC 级验证模式，用 PicoRV32 作为软件主控，通过 C 程序访问 AXI-Lite 寄存器来驱动现有 MMA 协处理器。这个模式保留 UVM testbench 的启动、日志、FSDB、检查和报错机制，但激励来源从 UVM sequence 直接写寄存器变成了 CPU 执行交叉编译后的 C 程序。

## RTL 结构

SoC 顶层在 `rtl/nice_coprocessor/soc_top.sv`。

主要模块关系如下。`soc_top` 现在只保留模块实例化和连线，地址译码、AXI 仲裁、UART/ctrl 寄存器和 RAM 行为都下沉到 `rtl/nice_coprocessor/soc/` 子模块中：

```text
PicoRV32 native memory bus
        |
        v
pico_native_to_axi
        |
        v
soc_axi_interconnect <---------------- MMA AXI master
        |                 \
        |                  \-- 0x1000_0000 MMA AXI-Lite CSR
        |                  \-- 0x0200_0000 UART AXI-Lite
        |                  \-- 0x2000_0000 SoC ctrl/status
        v
soc_axi_ram
  - cpu.mem: C 程序、栈和 BSS
  - runtime_data.mem: lhs/rhs/bias/quant/output
```

`soc_top` 内部把 PicoRV32 的 `mem_valid/mem_ready/mem_addr/mem_wdata/mem_wstrb/mem_rdata` 总线译码到几个地址窗：

| 地址范围 | 用途 |
| --- | --- |
| `0x0000_0000` | PicoRV32 程序 RAM，默认深度 `CPU_MEM_DP=524288` words |
| `0x0200_0000` | UART AXI-Lite 窗口，`0x4` 为 divider，`0x8` 为 data |
| `0x1000_0000` | MMA AXI-Lite CSR 访问窗口，低位地址传给 `mma_axil_top` |
| `0x2000_0000` | SoC 控制寄存器，C 程序写这里通知 UVM 测试结束 |

SoC 控制寄存器目前定义为：

| Offset | 读写 | 含义 |
| --- | --- | --- |
| `0x0` | RW | `soc_status`。C 程序写入后 `soc_finish` 置 1 |
| `0x4` | R | `{31'b0, soc_finish}` |
| `0x8` | R | `{31'b0, cpu_trap}` |
| `0xc` | RW | `soc_progress`，软件写入阶段码，UVM timeout 时打印 |

UART 使用 PicoSoC 原生 `simpleuart`，软件侧地址和 PicoSoC BSP 保持一致：

| 地址 | 读写 | 含义 |
| --- | --- | --- |
| `0x0200_0004` | RW | UART clock divider，仿真默认由 `SOC_UART_CLKDIV=8` 设置 |
| `0x0200_0008` | RW | UART data，写入 8-bit 字符会通过 `ser_tx` 发出 |

`veri/tb/top_tb.sv` 在 `DUT_MODE=axi_soc` 下打开 UART TX monitor，按 `soc_top.u_soc_uart.u_simpleuart.ser_tx` 和 `soc_top.u_soc_uart.cfg_divider` 解码串口输出，并把 PicoRV32 侧 `printf`/`print` 输出直接写到 VCS 终端和 `sim.log`。

PicoRV32 程序镜像通过 `+SOC_CPU_MEM=<path>` 指定，MMA runtime 数据通过 `+SOC_DATA_MEM=<path>` 或兼容别名 `+SOC_MMA_MEM=<path>` overlay 到统一 RAM。没有 plusarg 时使用 RTL 参数默认路径。

## AXI outstanding 和 DDR 模型

当前 SoC 数据通路已经切换为统一 AXI：

- `pico_native_to_axi` 复用 PicoRV32 官方 `picorv32_axi_adapter` 的握手语义，`mem_ready` 由 AXI `RVALID/BVALID` 组合产生，避免把上一笔响应延后一拍误应答到下一笔 Pico 原生访问。
- `soc_axi_interconnect` 支持 Pico 和 MMA 两个 AXI master。RAM 读、写通道分别锁定当前 owner；同一 owner 可继续发多笔 outstanding，另一 owner 等待当前 owner outstanding 归零后再切换。
- `soc_axi_interconnect` 的 CPU 侧 active 状态必须显式处理“新请求与上一笔响应同周期握手”。否则 `AR/R` 或 `AW/B` 同周期时会把新事务的 active 位清掉，后续响应无法路由。
- `soc_axi_interconnect`、`soc_axi_ram`、`mma_top` 和 AXI DMA 共用 `AXI_READ_OUTSTANDING/AXI_WRITE_OUTSTANDING` 参数。读写深度相互独立，默认写深度跟随读深度。
- `soc_axi_ram` 支持 AXI burst、读写 outstanding、B/R 随机延迟。`+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8` 可模拟 DDR 命令、写数据和响应延迟。
- `soc_axi_ram` 当前保留单 beat 读快路径和 `AW/W` 同周期接收；写响应仍通过 B 队列返回。实验性的直接 B 快路径会让 `micro_speech` 卡在 `progress=0x5b313000`，不要在没有覆盖 TFLM 回归前重新打开。
- `axi_dual_block_dma` 写侧也支持 outstanding：`AW` 可按行提前排队，`W` 连续发送已接收地址的行数据，`B` 独立回收，不再要求每行写回等待上一行 B 响应。
- `axi_block_dma_arbiter` 的读侧优先级为 `kernel > quant > IA > bias`。quant 提到 IA 前是有意的：TFLM per-channel 算子里量化参数是短读，提前完成可以避免 IA 数据到达后再等待 `quant_params_valid`。per-tensor 不发 `quant_req`，因此不受该优先级影响。

## UVM Testbench 集成

`veri/tb/top_tb.sv` 在 `DUT_AXI_SOC` 宏打开时例化 `soc_top`，并把 UVM 环境配置成 `AI_DUT_AXI_SOC`。这个模式下 UVM 不再创建主动 AXI-Lite 或 NICE driver 去发业务寄存器访问，寄存器访问由 PicoRV32 C 程序完成。

主要 UVM test 是 `ai_axi_soc_c_test`：

1. 读取 `+SOC_CASE_DIR=<dir>`，默认 `../tb/axi_soc_case`。
2. 从 `<dir>/config.txt` 解析输出地址和期望输出大小。
3. 等待 RTL 中的 `soc_finish`。
4. 检查 `cpu_trap` 必须为 0。
5. 检查 `soc_status` 必须为 `0x1`。
6. 对比 `axi_sim_ram` 中输出区域和 `<dir>/expected.mem`。

测试通过时会打印 `TEST PASS`，失败时通过 UVM error/fatal 报出。

## 软件和数据流

`make run DUT_MODE=axi_soc` 会自动执行以下步骤：

1. `soc_case`
   - 调用 `veri/tb/generate_axi_soc_case.py`。
   - 该脚本复用 `generate_test_case_complex_mem.py` 生成矩阵数据、量化参数、期望结果和 `config.txt`。
   - 额外生成 `soc_case.h`，供 C 程序编译时包含。
   - 生成的 `data.mem` 会作为 MMA 数据 RAM 初值。

2. `soc_c`
   - 使用 `riscv64-unknown-elf-gcc` 编译 `veri/soc_csrc/start.S`、`picosoc_bsp.c`、`dsa_accel_mmio.c` 和 `SOC_C_SRC`。
   - 默认 `SOC_C_SRC=../soc_csrc/soc_main.c`。
   - 使用 `veri/soc_csrc/link.ld` 链接到 `0x0000_0000`。
   - 通过 `elf_to_mem.py` 把 binary 转成 `cpu.mem`。

3. `com`
   - 使用 `veri/flist/tb_axi_soc.f` 编译 UVM testbench、PicoRV32、`soc_top` 和 MMA RTL。
   - 自动加 `+define+DUT_AXI_SOC`。

4. `sim`
   - 运行 `simv`。
   - 自动传入 `+SOC_CPU_MEM=$(SOC_CASE_DIR)/cpu.mem`。
   - 自动传入 `+SOC_MMA_MEM=$(SOC_CASE_DIR)/data.mem`。
   - 自动传入 `+SOC_CASE_DIR=$(SOC_CASE_DIR)` 供 UVM check 使用。

## 常用命令

从 `veri/sim` 目录运行：

```bash
make run DUT_MODE=axi_soc case=ai_axi_soc_c_test \
  SOC_K=24 SOC_N=32 SOC_M=16 \
  SOC_LHS_DTYPE=1 SOC_QUANT_MODE=0 \
  SOC_LHS_OFFSET=0 SOC_RHS_OFFSET=0 SOC_DST_OFFSET=0 \
  seed=1 SOC_SEED=1
```

只生成 case 和 C 程序：

```bash
make soc_c DUT_MODE=axi_soc case=ai_axi_soc_c_test
```

只编译仿真：

```bash
make com DUT_MODE=axi_soc case=ai_axi_soc_c_test
```

只跑已有 `simv`：

```bash
make sim DUT_MODE=axi_soc case=ai_axi_soc_c_test
```

per-channel 量化示例：

```bash
make run DUT_MODE=axi_soc case=ai_axi_soc_c_test \
  SOC_K=16 SOC_N=16 SOC_M=16 \
  SOC_LHS_DTYPE=1 SOC_QUANT_MODE=1 \
  SOC_FIX_MODE=1 SOC_SEED=9 seed=9
```

TFLM 推理示例：

```bash
make tflm_hello_world_run
make tflm_micro_speech_run
make tflm_my_model_run
make tflm_person_detection_run
```

`tflm_person_detection_run` 默认关闭 `DUMPOPTS`，只保留终端/UART 日志，避免 96x96 person_detection 模型的长仿真同时写全量 FSDB。

## 可配置参数

| Make 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `SOC_CASE` | `axi_soc_case` | case 子目录名 |
| `SOC_CASE_DIR` | `../tb/$(SOC_CASE)` | 生成文件目录 |
| `SOC_K` | `24` | 输出矩阵行数/左矩阵行数 |
| `SOC_N` | `32` | inner dimension |
| `SOC_M` | `16` | 输出矩阵列数/右矩阵列数 |
| `SOC_LHS_DTYPE` | `1` | `1=S8`, `2=S16` |
| `SOC_QUANT_MODE` | `0` | `0=per-tensor`, `1=per-channel` |
| `SOC_FIX_MODE` | `1` | 使用固定矩阵数据，便于 debug |
| `SOC_SEED` | `1` | Python 生成数据的随机种子 |
| `SOC_LHS_OFFSET` | `0` | lhs zero-point/offset |
| `SOC_RHS_OFFSET` | `0` | rhs zero-point/offset |
| `SOC_DST_OFFSET` | `0` | dst zero-point/offset |
| `SOC_ACT_MIN` | `-128` | activation clamp 下限 |
| `SOC_ACT_MAX` | `127` | activation clamp 上限 |
| `SOC_DST_MULT` | 空 | 指定时覆盖自动生成的 quant multiplier |
| `SOC_DST_SHIFT` | 空 | 指定时覆盖自动生成的 quant shift |
| `SOC_UART_CLKDIV` | `8` | PicoSoC UART divider。数值越大越接近真实低速 UART，数值越小仿真打印越快 |
| `SOC_C_SRC` | `../soc_csrc/soc_main.c` | C 激励源文件 |
| `SOC_CPU_MEM_DP` | `524288` | `cpu.mem` 输出深度，单位 word |
| `SOC_AXI_READ_OUTSTANDING` | `4` | SoC RAM/interconnect/MMA DMA 读 outstanding 深度 |
| `SOC_AXI_WRITE_OUTSTANDING` | `SOC_AXI_READ_OUTSTANDING` | SoC RAM/interconnect/MMA DMA 写 outstanding 深度 |

`SOC_DST_MULT` 和 `SOC_DST_SHIFT` 要一起使用。为空时，Python 根据参考结果自动生成量化参数。

## 生成文件

默认输出在 `veri/tb/axi_soc_case`：

| 文件 | 用途 |
| --- | --- |
| `data.mem` | MMA 数据 RAM 初值，包含 lhs/rhs/bias/quant params |
| `expected.mem` | UVM 对比用的期望输出 |
| `expected_dst.txt` | 人可读的期望输出矩阵 |
| `config.txt` | case 配置和内存地址记录 |
| `soc_case.h` | C 程序使用的宏定义 |
| `cpu.elf` | 交叉编译后的 ELF |
| `cpu.bin` | ELF objcopy 后的 binary |
| `cpu.mem` | PicoRV32 程序 RAM 初值 |

仿真输出在 `veri/sim/runs/<case>/seed_<seed>`：

| 文件 | 用途 |
| --- | --- |
| `compile.log` | VCS 编译日志 |
| `sim.log` | 仿真日志 |
| `tb_top.fsdb` | 波形 |

## C 程序接口

默认 C 程序在 `veri/soc_csrc/soc_main.c`。它从 `soc_case.h` 读取矩阵地址、尺寸和量化参数，调用 `dsa_matmul_execute()`。

MMIO 基地址在 `veri/soc_csrc/dsa_accel_mmio.h`：

```c
#define DSA_MMIO_BASE 0x10000000u
#define SOC_CTRL_BASE 0x20000000u
```

`dsa_matmul_execute()` 会按协处理器 CSR 定义写入 `0x7C0` 到 `0x7D0` 的矩阵配置寄存器，再写 `DSA_REG_CTRL` 触发计算，轮询 `DSA_REG_STATUS` 的 done 位。成功后调用：

```c
soc_finish(SOC_STATUS_PASS);
```

`soc_finish()` 写 `SOC_CTRL_BASE`，RTL 置位 `soc_finish`，UVM test 随后开始检查输出。

普通 C case 会链接 `veri/soc_csrc/picosoc_bsp.c`，其中 `printf()`、`puts()`、`print()`、`print_hex()` 和 `print_dec()` 都写 PicoSoC UART。TFLM 程序继续使用 newlib `printf()`，`veri/soc_csrc/tflm_soc_runtime.cc` 的 `_write()` 会把 stdout/stderr 字符发送到同一个 PicoSoC UART。

## Debug 提示

常见检查点：

- C 程序没有结束：看 `sim.log` 里的 `Timeout waiting for soc_finish`，再看 `cpu_trap` 是否为 1。
- MMA 没有启动或没有 done：看 C 程序是否正确写 `DSA_MMIO_BASE + (CSR << 2)`，以及 `DSA_REG_STATUS`。
- 输出不匹配：先看 `<SOC_CASE_DIR>/config.txt` 中 `output_base_addr` 和 `expected_dst_size`，再看 `data.mem`、`expected.mem`。
- RAM 没加载对：确认仿真命令里有 `+SOC_CPU_MEM=.../cpu.mem` 和 `+SOC_MMA_MEM=.../data.mem`。
- 修改 C 源后需要重新跑 `make run` 或至少 `make soc_c` 后再 `make sim`。
- Pico 启动早期 trap：加 `SIM_ARGS='+SOC_CPU_AXI_TRACE +SOC_PROGRESS_TRACE'`，先看 `_start` 的 progress 是否走过 `0x5a000001/2/3`。

当前模式已验证过小尺寸 per-tensor 和 per-channel case，均可由 PicoRV32 C 程序触发 MMA 并由 UVM 完成输出比对。

## 2026-07-01 验证记录

| 测试 | 配置 | 结果 |
| --- | --- | --- |
| 编译 | `DUT_MODE=axi_soc,SIZE=4,CACHE=2,PS_FRAME=8,RO=4,WO=4` | PASS |
| 启动 trace smoke | `unaligned_layout,DDR_RAND_LAT=0,+SOC_CPU_AXI_TRACE,+SOC_PROGRESS_TRACE` | PASS，`soc_finish` after 24409 cycles |
| 正常 smoke | `unaligned_layout,DDR_RAND_LAT=0,RO=4,WO=4` | PASS，`cpu_trap=0,status=1` |
| 随机 DDR 延迟 | `unaligned_layout,RO=4,WO=4,cmd/w/rsp max=3/2/8` | PASS，after 38360 cycles |
| outstanding 边界 | `RO=1,WO=1,随机 DDR 延迟` | PASS，覆盖最小 outstanding 深度 |
| S8 随机回归 | `SIZE=8,CACHE={2,4,8},DF={WS,IS},lhs={s8,s16},Q={per-tensor,per-channel},unaligned_layout,DDR_RAND_LAT=1` | PASS 24/24 |
| S16 随机回归 | `SIZE=16,CACHE={2,4,8},DF={WS,IS},lhs={s8,s16},Q={per-tensor,per-channel},unaligned_layout,DDR_RAND_LAT=1` | PASS 24/24 |
| TFLM | `hello_world/micro_speech/my_model/person_detection,SIZE=16,CACHE=4,PS_FRAME=16,O3` | PASS |
| 量化优先级边界回归 | `SIZE={8,16},CACHE=4,DF={WS,IS},lhs={s8,s16},Q={per-tensor,per-channel},MIN_DIM=1,MAX_DIM=65,unaligned_layout,DDR_RAND_LAT=1` | PASS 16/16 |
| 量化优先级 TFLM | `micro_speech/my_model/person_detection,SIZE=16,CACHE=4,PS_FRAME=16,O3` | PASS；`quant_stall` 在已采样 per-channel TFLM op 中清零 |
