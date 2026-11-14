# TOPS 参数复测记录（2026-07-03）

本记录保存阵列规模 50x50 与 52x52 参数设置的 SoC 仿真运行结果。正文设计报告只保留汇总指标，详细命令和日志路径保存在本文件。

## 运行命令

阵列规模 50x50：

```sh
make soc_perf_sweep SOC_PERF_LOG_ROOT=runs/tops_s50_recheck_20260703 SOC_PERF_SIZE_LIST=50 SOC_PERF_CACHE_BLOCKS_LIST=4 SOC_PERF_PS_FRAME_COUNT_LIST=16 SOC_PERF_DIMS=64x64x64 SOC_PERF_DATAFLOW_MODE_LIST=0 SOC_PERF_LHS_DTYPE_LIST=1 SOC_PERF_QUANT_MODE_LIST=0 SOC_PERF_INCLUDE_AUTO=1 SOC_PERF_SIM_ARGS='+MMA_CTRL_UTIL_SUMMARY +SOC_AXI_STATS +SOC_CPU_AXI_STATS' SOC_PERF_SOC_TIMEOUT_CYCLES=60000000 SOC_PERF_TIMEOUT=300
```

阵列规模 52x52：

```sh
make soc_perf_sweep SOC_PERF_LOG_ROOT=runs/tops_s52_check_20260703 SOC_PERF_SIZE_LIST=52 SOC_PERF_CACHE_BLOCKS_LIST=4 SOC_PERF_PS_FRAME_COUNT_LIST=16 SOC_PERF_DIMS=64x64x64 SOC_PERF_DATAFLOW_MODE_LIST=0 SOC_PERF_LHS_DTYPE_LIST=1 SOC_PERF_QUANT_MODE_LIST=0 SOC_PERF_INCLUDE_AUTO=1 SOC_PERF_SIM_ARGS='+MMA_CTRL_UTIL_SUMMARY +SOC_AXI_STATS +SOC_CPU_AXI_STATS' SOC_PERF_SOC_TIMEOUT_CYCLES=60000000 SOC_PERF_TIMEOUT=300
```

## 结果摘要

| 参数设置 | 任务规模 | 结果 | DSA 执行周期 | SoC 总周期 | DSA 吞吐@200MHz | SoC 吞吐@200MHz |
|---|---|---|---:|---:|---:|---:|
| 阵列规模 16x16、IA cache 总容量为 4 个输入矩阵分块大小、partial sum frame 数为 16 | 512x512x512 | PASS | 1457775 | 5221137 | 36.83GOPS | 10.28GOPS |
| 阵列规模 50x50、IA cache 总容量为 4 个输入矩阵分块大小、partial sum frame 数为 16 | 64x64x64 | PASS | 5074 | 175255 | 20.67GOPS | 0.598GOPS |
| 阵列规模 52x52、IA cache 总容量为 4 个输入矩阵分块大小、partial sum frame 数为 16 | 64x64x64 | PASS | 5590 | 175771 | 18.76GOPS | 0.597GOPS |

## 日志路径

阵列规模 16x16：

```text
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/bus_report_fifo_watermark_current/S16_C4_P16_DF0_D1_Q0_512x512x512_R0_W0.log
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/bus_report_fifo_watermark_current/perf.csv
```

阵列规模 50x50：

```text
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/tops_s50_recheck_20260703/S50_C4_P16_DF0_D1_Q0_64x64x64_R0_W0.log
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/tops_s50_recheck_20260703/perf.csv
```

阵列规模 52x52：

```text
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/tops_s52_check_20260703/S52_C4_P16_DF0_D1_Q0_64x64x64_R0_W0.log
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/tops_s52_check_20260703/perf.csv
```

## 结论

阵列规模 50x50 的 64x64x64 任务 DSA 执行吞吐为 20.67GOPS@200MHz，完整 SoC 吞吐为 0.598GOPS@200MHz。阵列规模 52x52 的同一任务 DSA 执行吞吐为 18.76GOPS@200MHz，完整 SoC 吞吐为 0.597GOPS@200MHz。因此，报告中仅使用实测任务吞吐，不把阵列规模外推结果写成性能结论。
