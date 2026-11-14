# NPU 顶层 Verilator 回归

本目录提供直接例化 `npu_top` 的轻量级顶层回归。该回归不经过 PicoRV32 SoC 和 AXI-Lite 寄存器封装，使用 Python 生成 `init.mem`、`config.mem` 和 `golden.mem`，由 testbench 驱动 NPU 配置端口，并在任务完成后直接比较 RAM 输出区域。

## 常用命令

从本目录直接运行：

```bash
make run_random \
  SIZE=4 IA_CACHE_BLOCKS=4 PS_FRAME_COUNT=8 \
  COUNT=20 SEED=1000 TRACE=0 \
  RANDOM_GEN_ARGS='--random --random_quant --lhs_dtype 0 --min_dim 1 --max_dim 32' \
  SIM_ARGS='+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8'
```

从统一仿真目录运行：

```bash
make -C ../sim npu_top_regress \
  TOP_REGRESS_SIZE=4 \
  TOP_REGRESS_IA_CACHE_BLOCKS=4 \
  TOP_REGRESS_PS_FRAME_COUNT=8 \
  TOP_REGRESS_COUNT=20 \
  TOP_REGRESS_SEED=1000
```

TFLM INT16×INT8、INT32 bias、INT16 输出定向回归：

```bash
make run SIZE=16 IA_CACHE_BLOCKS=4 PS_FRAME_COUNT=16 \
  GEN_ARGS='--K 3 --N 494 --M 7 --lhs_dtype 2 --int16_output \
  --tight_strides --ia_reuse_num 1 --w_reuse_num 1 --random_quant'
```

无 bias 的 FC 以 `bias_base=0` 编码，可用模型的 494 元素输入深度直接覆盖：

```bash
make run SIZE=16 IA_CACHE_BLOCKS=4 PS_FRAME_COUNT=16 \
  GEN_ARGS='--K 1 --N 494 --M 1 --lhs_dtype 2 --int16_output --no_bias \
  --tight_strides --ia_reuse_num 1 --w_reuse_num 1'
```

生成文件位于 `out/` 和 `obj_dir/`，均不进入版本库。

## 汇总输出

回归结束时会在终端打印 `[REGRESS_SUMMARY]` 和逐 case 表格，不需要手动查找单个 log。同步生成以下文件：

- `out/random_summary.md`
- `out/random_summary.csv`
- `out/random_summary.jsonl`

参数化随机回归对应输出为：

- `out/param_summary.md`
- `out/param_summary.csv`
- `out/param_summary.jsonl`
