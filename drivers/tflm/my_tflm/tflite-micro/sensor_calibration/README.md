# 传感器标定模型 INT16×INT8 回归

本目录保存 `veri/tools/prepare_sensor_calibration_regression.py` 自动选取的最新
`sensor_offset_calibrator_int16.tflite` 快照、RV32 C 数组和精度分析结果。默认按模型文件
修改时间选择 `/home/yusen/公共的/sensor_calibration_data` 下最新的
`calibration_model_*` 目录，也可用 `--model-dir` 固定版本。

当前快照来自
`calibration_model_20260907_1608_humidity_candidate/sensor_offset_calibrator_int16.tflite`，
SHA-256 为
`c2e1c8cf24ca7a2760c45d3a137946f5645227bf453cf176a22cebbd9a74eb5e`。

重新选取最新模型并生成回归数据：

```bash
conda run -n tf_2_18 env CUDA_VISIBLE_DEVICES=-1 TF_CPP_MIN_LOG_LEVEL=3 \
  python veri/tools/prepare_sensor_calibration_regression.py
```

运行 RTL/SoC/VCS 回归：

```bash
make -C veri/sim tflm_sensor_calibration_int16x8_run \
  SOC_CPU_MEM_DP=65536 DUMPOPTS=0 \
  SOC_TOOLCHAIN_DIR=/home/etc/FPGA/e203_simulator/deps/software-level/bin/gcc_open/bin
```

`regression_summary.json` 覆盖 1463 条固定留出样本，比较标准 TFLite INT16 输出与
NPU 的 INT32 累加、INT32 bias 限幅及 NMSIS reduced-Q15 重量化语义。当前结果无累加
溢出、无 bias 限幅；最终量化输出最大差异为 2 LSB，电压/电流/湿度 MAE 均未出现可测
的精度退化。VCS 使用 3 条确定性样本逐层检查 6 个 FC 和 3 个最终输出。
