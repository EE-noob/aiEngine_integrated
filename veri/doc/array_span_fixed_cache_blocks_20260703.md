# 阵列规模与固定 IA cache 块数性能记录（2026-07-03）

本记录保存阵列规模 4x4、8x8、16x16、32x32 和 64x64 在固定 IA cache 块数下的 SoC 仿真结果。设计报告正文只保留汇总数据和分析，详细命令和日志路径保存在本文件。

## 运行命令

```sh
python ./run_axi_soc_perf_sweep.py --log-root runs/array_span_fixed_cache_blocks_20260703 --size-cache-pairs '4:4 8:4 16:4 32:4 64:4' --ps-frame-counts 16 --dims 64x64x64 --dataflow-modes 0 --lhs-dtypes 1 --quant-modes 0 --ia-reuse-list 0 --w-reuse-list 0 --sim-args '+MMA_CTRL_UTIL_SUMMARY +SOC_AXI_STATS +SOC_CPU_AXI_STATS' --soc-timeout-cycles 120000000 --timeout 900
```

## 结果摘要

64x64x64 任务操作数为 524288，TOPS/GOPS 按 200MHz 换算。

| 阵列规模 | IA cache 块数 | partial sum frame 数 | 结果 | DSA 执行周期 | SoC 总周期 | 理想上限@200MHz | DSA 吞吐@200MHz | SoC 吞吐@200MHz |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| 4x4 | 4 | 16 | PASS | 58485 | 212321 | 0.006400TOPS | 0.001793TOPS | 0.000494TOPS |
| 8x8 | 4 | 16 | PASS | 14884 | 168720 | 0.025600TOPS | 0.007045TOPS | 0.000621TOPS |
| 16x16 | 4 | 16 | PASS | 6257 | 159825 | 0.102400TOPS | 0.016758TOPS | 0.000656TOPS |
| 32x32 | 4 | 16 | PASS | 5285 | 158853 | 0.409600TOPS | 0.019841TOPS | 0.000660TOPS |
| 64x64 | 4 | 16 | PASS | 5121 | 158689 | 1.638400TOPS | 0.020476TOPS | 0.000661TOPS |

## 日志路径

```text
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/array_span_fixed_cache_blocks_20260703/perf.csv
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/array_span_fixed_cache_blocks_20260703/summary.txt
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/array_span_fixed_cache_blocks_20260703/S4_C4_P16_DF0_D1_Q0_64x64x64_R0_W0.log
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/array_span_fixed_cache_blocks_20260703/S8_C4_P16_DF0_D1_Q0_64x64x64_R0_W0.log
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/array_span_fixed_cache_blocks_20260703/S16_C4_P16_DF0_D1_Q0_64x64x64_R0_W0.log
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/array_span_fixed_cache_blocks_20260703/S32_C4_P16_DF0_D1_Q0_64x64x64_R0_W0.log
/media/proj_tmp/aiEngine_integrated/veri/sim/runs/array_span_fixed_cache_blocks_20260703/S64_C4_P16_DF0_D1_Q0_64x64x64_R0_W0.log
```

## 备注

另行尝试按固定总存储量映射阵列规模 64x64 到 IA cache 块数 1 时，RTL elaboration 在 `ia_loader_ctrl.sv` 中出现零宽 `SLOT_W` 类型转换错误。固定 IA cache 块数为 4 的版本可以覆盖阵列规模 64x64 并完成仿真。
