# Sensor calibration release 2026-10-15

This directory contains the frozen release's int16x8 TFLite base model and V4
residual adapter, generated C model data, metadata, and regression vectors. It
is kept separate from the earlier `sensor_calibration/` regression assets.

The base model takes 10 standardized sensor inputs and produces 9 calibrated
outputs. The adapter takes a 980-element one-hot cell vector and adjusts only
calibrated V4. The embedded inference helper performs standardization,
quantization, cell selection, and the ±10 mV correction clamp.

Input order is temperature, humidity, voltage 1–4, then current 1–4. Output
order is calibrated humidity, voltage 1–4, then current 1–4. In this release,
only voltage 4 and current 2 were active training inputs; inactive channels
follow the packaged training convention and are zero-filled. The adapter also
requires the AD7124 PGA code (0–7).

## Regenerate and test

From the repository root, in the `tf_2_18` conda environment:

```bash
TF_CPP_MIN_LOG_LEVEL=3 conda run -n tf_2_18 \
  python veri/tools/prepare_sensor_calibration_release_20261015.py \
  --soc-samples 3 --force

make -C veri/sim tflm_sensor_calibration_release_20261015_host_run

make -C veri/sim tflm_sensor_calibration_release_20261015_run \
  SOC_TOOLCHAIN_DIR=/media/proj_tmp/alioth_simulator/deps/software-level/bin/gcc_open/bin \
  SOC_CPU_MEM_DP=131072 \
  SOC_CASE_DIR=../tb/axi_soc_tflm_sensor_calibration_release_20261015_hw
```

The host target runs the full 6,825-row valid V4 test split with TFLM. The SoC
target checks three evenly spaced rows from the two source files; its final V4
output must be within 2,500 µV of the packaged PC TFLite result. Int16 FC
per-channel multiplier/shift arrays are passed through NMSIS to the DSA, loaded
by the NPU quantization DMA, and applied lane-wise in the int16 requantization
pipeline. The int16 FC path has no reference-kernel fallback; a DSA failure
fails inference.

The current release test split reports host TFLM baseline/candidate V4 MAE of
7.431/4.783 mV. The packaged TFLite reports 7.432/4.781 mV. The three SoC/NPU
checkpoints matched the packaged result exactly (0 µV output difference); the
largest V4 calibration error among those checkpoints was 4.295 mV. These are
random-row holdout results, not an unseen-acquisition-batch guarantee.

See [validation_report.md](validation_report.md) for checkpoint-by-checkpoint
results and the per-channel DSA validation details.
