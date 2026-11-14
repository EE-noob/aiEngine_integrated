# 2026-10-15 sensor calibration validation

## Result

The packaged two-stage int16x8 model ran under host TFLM and the RV32 SoC
TFLM/NPU regression. The host TFLM candidate V4 MAE is **4.783 mV** over all
**6,825** valid rows in the release's random-row test split. The release's
TensorFlow Lite result is **4.781 mV**; the baseline results are **7.431 mV**
and **7.432 mV**, respectively.

The VCS SoC test completed with `TEST PASS`, no UVM errors, and an exact 0 µV
final-output difference from the packaged PC reference at all three selected
checkpoints. The measured mean invocation cost for base plus adapter was
2,388,912 CPU cycles. The largest calibration error among those three points
was 4.295 mV.

| Source row | PGA | Reference V4 | PC TFLM / SoC V4 | PC-to-SoC delta | Calibration error |
| --- | ---: | ---: | ---: | ---: | ---: |
| `calibration_20161013_h60(1).csv:3` | 5 | 2,207 µV | 3,662 µV | 0 µV | 1,455 µV |
| `calibration_20161013_h70.csv:59` | 5 | 587,446 µV | 587,842 µV | 0 µV | 396 µV |
| `calibration_20161013_h70.csv:22922` | 0 | 26,662,201 µV | 26,666,496 µV | 0 µV | 4,295 µV |

The SoC regression now fails if any selected final V4 output differs from the
packaged PC result by more than **2,500 µV**. Both TFLM tensor arenas fit in the
RV32 image: base 35,364 bytes and adapter 6,548 bytes used.

## Deployment note

The base graph has 24 fully connected nodes. Int16 activation/int8 weight FC
now passes either scalar or per-output-channel multiplier/shift parameters to
the NMSIS DSA entry point. Per-channel parameters are fetched by the NPU's
quantization DMA and selected lane-wise in the int16 requantization pipeline;
the int16 FC evaluator has no reference-kernel fallback. The SoC run completed
all three checkpoints with 0 µV difference from the packaged PC TFLite output,
which exercises the NPU path. All int64 FC biases in this release fit in signed
int32, so bias saturation did not change these outputs.

The source release uses a random row split, so this validates consistency with
PC inference and within-release accuracy, not transfer to an unseen acquisition
batch. The reported full-set maximum error remains 299.582 mV.
