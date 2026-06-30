/* Copyright 2025 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

#include "tensorflow/lite/micro/kernels/fully_connected.h"

#include "tensorflow/lite/c/builtin_op_data.h"
#include "tensorflow/lite/c/common.h"
#include "tensorflow/lite/kernels/internal/common.h"
#include "tensorflow/lite/kernels/internal/portable_tensor_utils.h"
#include "tensorflow/lite/kernels/internal/reference/fully_connected.h"
#include "tensorflow/lite/kernels/internal/reference/integer_ops/fully_connected.h"
#include "tensorflow/lite/micro/kernels/kernel_util.h"
#include "tensorflow/lite/micro/micro_log.h"

#include <stdint.h>

namespace tflite {
namespace {

#if defined(TFLM_SOC_PROGRESS)
void SocProgress(uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(0x2000000cu) = value;
}
#else
void SocProgress(uint32_t value) { (void)value; }
#endif

#if defined(TFLM_SOC_MMA)
constexpr uintptr_t kDsaMmioBase = 0x10000000u;
constexpr uint32_t kDsaRegCtrl = 0x000u;
constexpr uint32_t kDsaRegStatus = 0x001u;
constexpr uint32_t kDsaRegWbData = 0x002u;
constexpr uint32_t kDsaRegIaReuse = 0x004u;
constexpr uint32_t kDsaRegWReuse = 0x005u;
constexpr uint32_t kDsaCtrlStart = 1u << 0;
constexpr uint32_t kDsaCtrlPerChannel = 1u << 2;
constexpr uint32_t kDsaCtrlClearDone = 1u << 8;
constexpr uint32_t kDsaCtrlClearWbValid = 1u << 9;
constexpr uint32_t kDsaStatusDone = 1u << 2;
constexpr uint32_t kDsaStatusErrMask = 3u << 4;
constexpr uint32_t kCsrMultLhsPtr = 0x7c0u;
constexpr uint32_t kCsrMultRhsPtr = 0x7c1u;
constexpr uint32_t kCsrMultDstPtr = 0x7c2u;
constexpr uint32_t kCsrMultBiasPtr = 0x7c3u;
constexpr uint32_t kCsrMultLhsRows = 0x7c4u;
constexpr uint32_t kCsrMultRhsCols = 0x7c5u;
constexpr uint32_t kCsrMultRhsRows = 0x7c6u;
constexpr uint32_t kCsrMultDstRowStride = 0x7c7u;
constexpr uint32_t kCsrMultLhsRowStride = 0x7c8u;
constexpr uint32_t kCsrMultRhsColStride = 0x7c9u;
constexpr uint32_t kCsrMultLhsOffset = 0x7cau;
constexpr uint32_t kCsrMultRhsOffset = 0x7cbu;
constexpr uint32_t kCsrMultDstOffset = 0x7ccu;
constexpr uint32_t kCsrMultDstMult = 0x7cdu;
constexpr uint32_t kCsrMultDstShift = 0x7ceu;
constexpr uint32_t kCsrMultActMin = 0x7cfu;
constexpr uint32_t kCsrMultActMax = 0x7d0u;
#ifndef DSA_TILE_SIZE
#define DSA_TILE_SIZE 16
#endif
#ifndef DSA_IA_CACHE_BLOCKS
#define DSA_IA_CACHE_BLOCKS 4
#endif
#ifndef TFLM_SOC_MMA_MIN_MACS
#define TFLM_SOC_MMA_MIN_MACS 0
#endif
constexpr int kMmaVectorCols = static_cast<int>(DSA_TILE_SIZE);
constexpr int kMmaMaxRows = 16;
constexpr int kMmaMaxInner = 4096;
constexpr int kMmaTimeout = 2000000;
constexpr uint32_t kMmaIaCacheBlocks =
    static_cast<uint32_t>(DSA_IA_CACHE_BLOCKS);
constexpr uint32_t kMmaMinMacs =
    static_cast<uint32_t>(TFLM_SOC_MMA_MIN_MACS);

alignas(16) int8_t g_mma_lhs[kMmaMaxRows * kMmaMaxInner]
    __attribute__((section(".noinit.mma")));
alignas(16) int8_t g_mma_rhs[kMmaMaxInner * kMmaVectorCols]
    __attribute__((section(".noinit.mma")));
alignas(16) int8_t g_mma_dst[kMmaMaxRows * kMmaVectorCols]
    __attribute__((section(".noinit.mma")));
alignas(16) int32_t g_mma_bias[kMmaVectorCols]
    __attribute__((section(".noinit.mma")));
alignas(16) int32_t g_mma_mult[kMmaVectorCols]
    __attribute__((section(".noinit.mma")));
alignas(16) int32_t g_mma_shift[kMmaVectorCols]
    __attribute__((section(".noinit.mma")));

#if !defined(TFLM_SOC_MMA_SOFT)
void DsaWrite(uint32_t word_addr, uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(kDsaMmioBase + (word_addr << 2)) =
      value;
}

uint32_t DsaRead(uint32_t word_addr) {
  return *reinterpret_cast<volatile uint32_t*>(kDsaMmioBase +
                                               (word_addr << 2));
}

uint32_t PtrToDsa(const void* ptr) {
  return static_cast<uint32_t>(reinterpret_cast<uintptr_t>(ptr));
}

void DmaMemoryBarrier() {
#if defined(__riscv)
  asm volatile("fence rw, rw" ::: "memory");
#else
  asm volatile("" ::: "memory");
#endif
}
#endif

int MinInt(int a, int b) { return a < b ? a : b; }

int Align4(int value) { return (value + 3) & ~3; }

#if !defined(TFLM_SOC_MMA_SOFT)
uint32_t CeilDivU32(uint32_t value, uint32_t divisor) {
  return divisor == 0 ? 0 : ((value + divisor - 1) / divisor);
}

uint32_t MinU32(uint32_t a, uint32_t b) { return a < b ? a : b; }

uint32_t MaxU32(uint32_t a, uint32_t b) { return a > b ? a : b; }

uint32_t FloorPow2(uint32_t value) {
  uint32_t out = 1;
  while ((out << 1) != 0 && (out << 1) <= value) {
    out <<= 1;
  }
  return out;
}

uint32_t SatMulU32(uint32_t a, uint32_t b) {
  if (a != 0 && b > (0xffffffffu / a)) {
    return 0xffffffffu;
  }
  return a * b;
}

bool ShouldUseMmaShape(int rows, int inner, int cols) {
  if (kMmaMinMacs == 0) {
    return true;
  }
  if (rows <= 0 || inner <= 0 || cols <= 0) {
    return false;
  }
  const uint32_t macs =
      SatMulU32(SatMulU32(static_cast<uint32_t>(rows),
                          static_cast<uint32_t>(inner)),
                static_cast<uint32_t>(cols));
  return macs >= kMmaMinMacs;
}

uint32_t EvalReuseTime(uint32_t x_tiles, uint32_t y_tiles, uint32_t z_tiles,
                       uint32_t ia_reuse, uint32_t w_reuse) {
  if (x_tiles == 0 || y_tiles == 0 || z_tiles == 0 || ia_reuse == 0 ||
      w_reuse == 0) {
    return 0xffffffffu;
  }

  const uint32_t xyz = SatMulU32(SatMulU32(x_tiles, y_tiles), z_tiles);
  const uint32_t total_blocks = SatMulU32(2u, xyz);
  const uint32_t comp_t0 = SatMulU32(47u, xyz);
  const uint32_t x_groups = CeilDivU32(x_tiles, ia_reuse);
  const uint32_t y_groups = CeilDivU32(y_tiles, w_reuse);
  const uint32_t schedule_terms = SatMulU32(SatMulU32(x_groups, y_groups),
                                           z_tiles);

  const uint32_t reuse_factor =
      SatMulU32(2u, SatMulU32(ia_reuse, w_reuse)) -
      (ia_reuse + w_reuse);
  uint32_t reused_blocks = SatMulU32(schedule_terms, reuse_factor);
  if (reused_blocks > total_blocks) {
    reused_blocks = total_blocks;
  }
  const uint32_t mem_t1 = SatMulU32(64u, total_blocks - reused_blocks);

  const uint32_t comp_factor =
      SatMulU32(ia_reuse - 1u, SatMulU32(31u, w_reuse) - 15u);
  uint32_t comp_save = SatMulU32(schedule_terms, comp_factor);
  comp_save += SatMulU32(SatMulU32(15u, ia_reuse - 1u),
                         (y_groups > 0) ? (y_groups - 1u) : 0u);
  const uint32_t comp_t1 = (comp_t0 > comp_save) ? (comp_t0 - comp_save) : 0u;

  return MaxU32(mem_t1, comp_t1);
}

void SelectMmaReuse(int rows, int inner, int cols, uint32_t* ia_reuse,
                    uint32_t* w_reuse) {
  const uint32_t row_count = rows > 0 ? static_cast<uint32_t>(rows) : 0u;
  const uint32_t inner_count = inner > 0 ? static_cast<uint32_t>(inner) : 0u;
  const uint32_t col_count = cols > 0 ? static_cast<uint32_t>(cols) : 0u;

  if (row_count == 0 || inner_count == 0 || col_count == 0) {
    *ia_reuse = 1;
    *w_reuse = 1;
    return;
  }

  const uint32_t x_tiles = CeilDivU32(col_count, DSA_TILE_SIZE);
  const uint32_t y_tiles = CeilDivU32(inner_count, DSA_TILE_SIZE);
  const uint32_t z_tiles = CeilDivU32(row_count, DSA_TILE_SIZE);
  const uint32_t ia_limit = MaxU32(1u, kMmaIaCacheBlocks < 2u
                                           ? 1u
                                           : (kMmaIaCacheBlocks / 2u));
  const uint32_t smax = MaxU32(1u, kMmaIaCacheBlocks);
  uint32_t best_ia = 1;
  uint32_t best_w = 1;
  uint32_t best_time = 0xffffffffu;

  for (uint32_t w = 1; w <= MinU32(y_tiles, smax); ++w) {
    const uint32_t ia = MinU32(x_tiles, smax / w);
    if (ia == 0) {
      continue;
    }
    const uint32_t time = EvalReuseTime(x_tiles, y_tiles, z_tiles, ia, w);
    if (time < best_time || (time == best_time && ia > best_ia)) {
      best_time = time;
      best_ia = ia;
      best_w = w;
    }
  }

  *ia_reuse = FloorPow2(MaxU32(1u, MinU32(best_ia, ia_limit)));
  *w_reuse = FloorPow2(MaxU32(1u, MinU32(best_w, x_tiles)));
}
#endif

#if defined(TFLM_SOC_MMA_SOFT) || defined(TFLM_SOC_MMA_SELF_CHECK)
int8_t EvalMmaReferenceElement(int row, int col, int inner, int lhs_stride,
                               int rhs_stride, int lhs_offset, int rhs_offset,
                               int dst_offset, int act_min, int act_max) {
  int32_t acc = g_mma_bias[col];
  for (int red = 0; red < inner; ++red) {
    const int32_t lhs =
        static_cast<int32_t>(g_mma_lhs[row * lhs_stride + red]) + lhs_offset;
    const int32_t rhs =
        static_cast<int32_t>(g_mma_rhs[red * rhs_stride + col]) + rhs_offset;
    acc += lhs * rhs;
  }
  acc = MultiplyByQuantizedMultiplier(acc, g_mma_mult[col], g_mma_shift[col]);
  acc += dst_offset;
  if (acc < act_min) acc = act_min;
  if (acc > act_max) acc = act_max;
  return static_cast<int8_t>(acc);
}
#endif

#if defined(TFLM_SOC_MMA_SELF_CHECK)
bool CheckMmaOutput(const char* tag, int rows, int inner, int cols,
                    int lhs_stride, int rhs_stride, int dst_stride,
                    int lhs_offset, int rhs_offset, int dst_offset,
                    int act_min, int act_max) {
  for (int row = 0; row < rows; ++row) {
    for (int col = 0; col < cols; ++col) {
      const int8_t expected = EvalMmaReferenceElement(
          row, col, inner, lhs_stride, rhs_stride, lhs_offset, rhs_offset,
          dst_offset, act_min, act_max);
      const int8_t got = g_mma_dst[row * dst_stride + col];
      if (got != expected) {
        SocProgress(0x5b42e000u | ((row & 0xff) << 8) | (col & 0xff));
        MicroPrintf(
            "[mma self] %s mismatch row=%d col=%d got=%d exp=%d rows=%d inner=%d cols=%d lhs_stride=%d rhs_stride=%d dst_stride=%d lhs_off=%d rhs_off=%d dst_off=%d mult=%d shift=%d",
            tag, row, col, got, expected, rows, inner, cols, lhs_stride,
            rhs_stride, dst_stride, lhs_offset, rhs_offset, dst_offset,
            g_mma_mult[col], g_mma_shift[col]);
        return false;
      }
    }
  }
  return true;
}
#endif

bool RunMma(int rows, int inner, int cols, int lhs_stride, int rhs_stride,
            int dst_stride, int lhs_offset, int rhs_offset, int dst_offset,
            int act_min, int act_max) {
#if defined(TFLM_SOC_MMA_SOFT)
  for (int row = 0; row < rows; ++row) {
    for (int col = 0; col < cols; ++col) {
      g_mma_dst[row * dst_stride + col] = EvalMmaReferenceElement(
          row, col, inner, lhs_stride, rhs_stride, lhs_offset, rhs_offset,
          dst_offset, act_min, act_max);
    }
  }
  return true;
#else
  uint32_t ia_reuse = 1;
  uint32_t w_reuse = 1;
  SelectMmaReuse(rows, inner, cols, &ia_reuse, &w_reuse);

#if defined(TFLM_SOC_MMA_SELF_CHECK)
  for (int row = 0; row < rows; ++row) {
    for (int col = 0; col < cols; ++col) {
      g_mma_dst[row * dst_stride + col] = static_cast<int8_t>(0x5a);
    }
  }
#endif

  DsaWrite(kDsaRegIaReuse, ia_reuse);
  DsaWrite(kDsaRegWReuse, w_reuse);
  DsaWrite(kCsrMultLhsPtr, PtrToDsa(g_mma_lhs));
  DsaWrite(kCsrMultRhsPtr, PtrToDsa(g_mma_rhs));
  DsaWrite(kCsrMultDstPtr, PtrToDsa(g_mma_dst));
  DsaWrite(kCsrMultBiasPtr, PtrToDsa(g_mma_bias));
  DsaWrite(kCsrMultLhsRows, static_cast<uint32_t>(rows));
  DsaWrite(kCsrMultRhsCols, static_cast<uint32_t>(inner));
  DsaWrite(kCsrMultRhsRows, static_cast<uint32_t>(cols));
  DsaWrite(kCsrMultLhsRowStride, static_cast<uint32_t>(lhs_stride));
  DsaWrite(kCsrMultRhsColStride, static_cast<uint32_t>(rhs_stride));
  DsaWrite(kCsrMultDstRowStride, static_cast<uint32_t>(dst_stride));
  DsaWrite(kCsrMultLhsOffset, static_cast<uint32_t>(lhs_offset));
  DsaWrite(kCsrMultRhsOffset, static_cast<uint32_t>(rhs_offset));
  DsaWrite(kCsrMultDstOffset, static_cast<uint32_t>(dst_offset));
  DsaWrite(kCsrMultDstMult, PtrToDsa(g_mma_mult));
  DsaWrite(kCsrMultDstShift, PtrToDsa(g_mma_shift));
  DsaWrite(kCsrMultActMin, static_cast<uint32_t>(act_min));
  DsaWrite(kCsrMultActMax, static_cast<uint32_t>(act_max));
  DmaMemoryBarrier();
  DsaWrite(kDsaRegCtrl, kDsaCtrlStart | kDsaCtrlPerChannel |
                            kDsaCtrlClearDone | kDsaCtrlClearWbValid);

  for (int timeout = kMmaTimeout; timeout > 0; --timeout) {
    const uint32_t status = DsaRead(kDsaRegStatus);
    if ((status & kDsaStatusDone) != 0u) {
      if ((status & kDsaStatusErrMask) != 0u) {
        SocProgress(0x5b42d000u | (status & 0xffu));
        MicroPrintf("[mma self] fully-connected status error status=%d",
                    status);
        return false;
      }
      const uint32_t wb_data = DsaRead(kDsaRegWbData);
      const bool ok = wb_data == 0u;
      DmaMemoryBarrier();
      if (!ok) {
        SocProgress(0x5b42f000u | (wb_data & 0xffffu));
        MicroPrintf("[mma self] fully-connected wb_data=%d status=%d",
                    wb_data, status);
        return false;
      }
#if defined(TFLM_SOC_MMA_SELF_CHECK)
      if (!CheckMmaOutput("fully-connected", rows, inner, cols, lhs_stride,
                          rhs_stride, dst_stride, lhs_offset, rhs_offset,
                          dst_offset, act_min, act_max)) {
        return false;
      }
#endif
      return true;
    }
  }
  SocProgress(0x5b42dff0u);
  MicroPrintf("[mma self] fully-connected timeout");
  return false;
#endif
}

bool TryMmaFullyConnectedInt8(const OpDataFullyConnected& data,
                              const TfLiteEvalTensor* input,
                              const int8_t* input_data,
                              const TfLiteEvalTensor* filter,
                              const int8_t* filter_data,
                              const TfLiteEvalTensor* bias,
                              const int32_t* bias_data,
                              const TfLiteEvalTensor* output,
                              int8_t* output_data) {
  const RuntimeShape input_shape = tflite::micro::GetTensorShape(input);
  const RuntimeShape filter_shape = tflite::micro::GetTensorShape(filter);
  const RuntimeShape output_shape = tflite::micro::GetTensorShape(output);
  const FullyConnectedParams op_params = FullyConnectedParamsQuantized(data);

  if (input_data == nullptr || filter_data == nullptr ||
      output_data == nullptr || filter_shape.DimensionsCount() < 2 ||
      output_shape.DimensionsCount() < 1 || data.filter_zero_point != 0) {
    return false;
  }

  const int filter_dim_count = filter_shape.DimensionsCount();
  const int output_dim_count = output_shape.DimensionsCount();
  const int rows = FlatSizeSkipDim(output_shape, output_dim_count - 1);
  const int output_depth = output_shape.Dims(output_dim_count - 1);
  const int filter_output_depth = filter_shape.Dims(filter_dim_count - 2);
  const int inner = filter_shape.Dims(filter_dim_count - 1);
  const int input_flat_size = input_shape.FlatSize();
  const int output_flat_size = output_shape.FlatSize();

  if (output_depth <= 0 || inner <= 0 || inner > kMmaMaxInner ||
      rows <= 0 || output_depth != filter_output_depth ||
      input_flat_size != rows * inner ||
      output_flat_size != rows * output_depth) {
    return false;
  }
#if !defined(TFLM_SOC_MMA_SOFT)
  if (!ShouldUseMmaShape(rows, inner, output_depth)) {
    return false;
  }
#endif

  SocProgress(0x5b321000u);
  const int lhs_stride = Align4(inner);

  for (int col_base = 0; col_base < output_depth;
       col_base += kMmaVectorCols) {
    const int col_count = MinInt(kMmaVectorCols, output_depth - col_base);
    const int rhs_stride = Align4(col_count);
    const int dst_stride = Align4(col_count);
    SocProgress(0x5b322000u | (col_base & 0xff));

    const int8_t* rhs_src_cols[kMmaVectorCols];
    for (int col = 0; col < col_count; ++col) {
      rhs_src_cols[col] = filter_data + (col_base + col) * inner;
    }
    for (int red = 0; red < inner; ++red) {
      int8_t* rhs_row = g_mma_rhs + red * rhs_stride;
      int col = 0;
      for (; col < col_count; ++col) {
        rhs_row[col] = rhs_src_cols[col][red];
      }
      for (; col < rhs_stride; ++col) {
        rhs_row[col] = 0;
      }
    }

    for (int col = 0; col < col_count; ++col) {
      const int out_channel = col_base + col;
      g_mma_bias[col] =
          (bias != nullptr && bias_data != nullptr) ? bias_data[out_channel] : 0;
      g_mma_mult[col] = data.is_per_channel
                            ? data.per_channel_output_multiplier[out_channel]
                            : data.output_multiplier;
      g_mma_shift[col] = data.is_per_channel
                             ? data.per_channel_output_shift[out_channel]
                             : data.output_shift;
    }

    for (int row_base = 0; row_base < rows; row_base += kMmaMaxRows) {
      const int row_count = MinInt(kMmaMaxRows, rows - row_base);
      SocProgress(0x5b323000u | ((row_base / kMmaMaxRows) & 0xff));

      for (int local_row = 0; local_row < row_count; ++local_row) {
        const int8_t* src = input_data + (row_base + local_row) * inner;
        int8_t* dst = g_mma_lhs + local_row * lhs_stride;
        for (int idx = 0; idx < inner; ++idx) {
          dst[idx] = src[idx];
        }
        for (int idx = inner; idx < lhs_stride; ++idx) {
          dst[idx] = 0;
        }
      }

      if (!RunMma(row_count, inner, col_count, lhs_stride, rhs_stride,
                  dst_stride, op_params.input_offset,
                  op_params.weights_offset, op_params.output_offset,
                  op_params.quantized_activation_min,
                  op_params.quantized_activation_max)) {
        SocProgress(0x5b32e001u);
        return false;
      }

      for (int local_row = 0; local_row < row_count; ++local_row) {
        int8_t* out_row =
            output_data + (row_base + local_row) * output_depth + col_base;
        for (int col = 0; col < col_count; ++col) {
          out_row[col] = g_mma_dst[local_row * dst_stride + col];
        }
      }
    }
  }

  SocProgress(0x5b321001u);
  return true;
}
#endif  // defined(TFLM_SOC_MMA)

void* FullyConnectedInit(TfLiteContext* context, const char* buffer,
                         size_t length) {
  TFLITE_DCHECK(context->AllocatePersistentBuffer != nullptr);
  return context->AllocatePersistentBuffer(context,
                                           sizeof(OpDataFullyConnected));
}

TfLiteStatus FullyConnectedPrepare(TfLiteContext* context, TfLiteNode* node) {
  MicroContext* micro_context = GetMicroContext(context);

  TFLITE_DCHECK(node->user_data != nullptr);
  TFLITE_DCHECK(node->builtin_data != nullptr);

  auto* data = static_cast<OpDataFullyConnected*>(node->user_data);
  const auto params =
      static_cast<const TfLiteFullyConnectedParams*>(node->builtin_data);

  TfLiteTensor* input =
      micro_context->AllocateTempInputTensor(node, kFullyConnectedInputTensor);
  TF_LITE_ENSURE(context, input != nullptr);
  TfLiteTensor* filter = micro_context->AllocateTempInputTensor(
      node, kFullyConnectedWeightsTensor);
  TF_LITE_ENSURE(context, filter != nullptr);
  TfLiteTensor* bias =
      micro_context->AllocateTempInputTensor(node, kFullyConnectedBiasTensor);
  TfLiteTensor* output = micro_context->AllocateTempOutputTensor(
      node, kFullyConnectedOutputTensor);
  TF_LITE_ENSURE(context, output != nullptr);
  TF_LITE_ENSURE_TYPES_EQ(context, input->type, output->type);

  if ((input->type == kTfLiteFloat32 && filter->type != kTfLiteFloat32) ||
      (input->type == kTfLiteInt8 &&
       (filter->type != kTfLiteInt8 && filter->type != kTfLiteInt4)) ||
      (input->type == kTfLiteInt16 && filter->type != kTfLiteInt8)) {
    MicroPrintf("Input type: %s with filter type: %s not supported.",
                TfLiteTypeGetName(input->type),
                TfLiteTypeGetName(filter->type));
    return kTfLiteError;
  }

  if (filter->type == kTfLiteInt4) {
    int filter_size =
        RuntimeShape(filter->dims->size,
                     reinterpret_cast<const int32_t*>(filter->dims->data))
            .FlatSize();
    context->RequestScratchBufferInArena(context, filter_size,
                                         &data->filter_buffer_index);
  }

  TF_LITE_ENSURE_OK(context, CalculateOpDataFullyConnected(
                                 context, params->activation, input->type,
                                 input, filter, bias, output, data));

#ifdef USE_TFLM_COMPRESSION

  // Compression scratch buffers.
  // These will only be allocated if the tensor is compressed.
  if (micro_context->IsTensorCompressed(node, kFullyConnectedWeightsTensor) &&
      filter->type == kTfLiteInt4) {
    MicroPrintf("Compression not supported with INT4 tensors");
    return kTfLiteError;
  }
  data->weights_scratch_index =
      micro_context->AllocateDecompressionScratchBuffer(
          node, kFullyConnectedWeightsTensor);
  data->bias_scratch_index = micro_context->AllocateDecompressionScratchBuffer(
      node, kFullyConnectedBiasTensor);

#endif  // USE_TFLM_COMPRESSION

  micro_context->DeallocateTempTfLiteTensor(input);
  micro_context->DeallocateTempTfLiteTensor(filter);
  if (bias != nullptr) {
    micro_context->DeallocateTempTfLiteTensor(bias);
  }
  micro_context->DeallocateTempTfLiteTensor(output);
  return kTfLiteOk;
}

TfLiteStatus FullyConnectedEval(TfLiteContext* context, TfLiteNode* node) {
  SocProgress(0x5b320001u);
  TFLITE_DCHECK(node->builtin_data != nullptr);
  const auto* params =
      static_cast<const TfLiteFullyConnectedParams*>(node->builtin_data);

  const TfLiteEvalTensor* input =
      tflite::micro::GetEvalInput(context, node, kFullyConnectedInputTensor);
  const TfLiteEvalTensor* filter =
      tflite::micro::GetEvalInput(context, node, kFullyConnectedWeightsTensor);
  const TfLiteEvalTensor* bias =
      tflite::micro::GetEvalInput(context, node, kFullyConnectedBiasTensor);
  TfLiteEvalTensor* output =
      tflite::micro::GetEvalOutput(context, node, kFullyConnectedOutputTensor);

#ifdef USE_TFLM_COMPRESSION

  MicroContext* micro_context = GetMicroContext(context);

  const CompressionTensorData* weights_comp_td =
      micro_context->GetTensorCompressionData(node,
                                              kFullyConnectedWeightsTensor);
  const CompressionTensorData* bias_comp_td =
      micro_context->GetTensorCompressionData(node, kFullyConnectedBiasTensor);

#endif  // USE_TFLM_COMPRESSION

  TFLITE_DCHECK(node->user_data != nullptr);
  const auto& data =
      *(static_cast<const OpDataFullyConnected*>(node->user_data));

  // Checks in Prepare ensure input, output and filter types are all the same.
  switch (input->type) {
    case kTfLiteFloat32: {
      tflite::reference_ops::FullyConnected(
          FullyConnectedParamsFloat(params->activation),
          tflite::micro::GetTensorShape(input),
          tflite::micro::GetTensorData<float>(input),
          tflite::micro::GetTensorShape(filter),
#ifdef USE_TFLM_COMPRESSION
          tflite::micro::GetTensorData<float>(micro_context, filter,
                                              weights_comp_td,
                                              data.weights_scratch_index),
          tflite::micro::GetTensorShape(bias),
          tflite::micro::GetOptionalTensorData<float>(
              micro_context, bias, bias_comp_td, data.bias_scratch_index),
#else   // USE_TFLM_COMPRESSION
          tflite::micro::GetTensorData<float>(filter),
          tflite::micro::GetTensorShape(bias),
          tflite::micro::GetOptionalTensorData<float>(bias),
#endif  // USE_TFLM_COMPRESSION
          tflite::micro::GetTensorShape(output),
          tflite::micro::GetTensorData<float>(output));
      break;
    }

    case kTfLiteInt8: {
      SocProgress(0x5b320200u | (filter->type & 0xff));
      switch (filter->type) {
        case kTfLiteInt4: {
          int8_t* unpacked_filter_data = static_cast<int8_t*>(
              context->GetScratchBuffer(context, data.filter_buffer_index));
          tflite::tensor_utils::UnpackDenseInt4IntoInt8(
              tflite::micro::GetTensorData<int8_t>(filter),
              tflite::micro::GetTensorShape(filter).FlatSize(),
              unpacked_filter_data);
          tflite::reference_integer_ops::FullyConnected(
              FullyConnectedParamsQuantized(data),
              tflite::micro::GetTensorShape(input),
              tflite::micro::GetTensorData<int8_t>(input),
              tflite::micro::GetTensorShape(filter), unpacked_filter_data,
              tflite::micro::GetTensorShape(bias),
              tflite::micro::GetOptionalTensorData<int32_t>(bias),
              tflite::micro::GetTensorShape(output),
              tflite::micro::GetTensorData<int8_t>(output));
          break;
        }
        case kTfLiteInt8: {
          SocProgress(0x5b320210u);
          const RuntimeShape input_shape =
              tflite::micro::GetTensorShape(input);
          const RuntimeShape filter_shape =
              tflite::micro::GetTensorShape(filter);
          const RuntimeShape bias_shape = tflite::micro::GetTensorShape(bias);
          const RuntimeShape output_shape =
              tflite::micro::GetTensorShape(output);
          const int8_t* input_data =
              tflite::micro::GetTensorData<int8_t>(input);
          const int8_t* filter_data =
#ifdef USE_TFLM_COMPRESSION
              tflite::micro::GetTensorData<int8_t>(
                  micro_context, filter, weights_comp_td,
                  data.weights_scratch_index)
#else   // USE_TFLM_COMPRESSION
              tflite::micro::GetTensorData<int8_t>(filter)
#endif  // USE_TFLM_COMPRESSION
              ;
          const int32_t* bias_data =
#ifdef USE_TFLM_COMPRESSION
              tflite::micro::GetOptionalTensorData<int32_t>(
                  micro_context, bias, bias_comp_td, data.bias_scratch_index)
#else   // USE_TFLM_COMPRESSION
              tflite::micro::GetOptionalTensorData<int32_t>(bias)
#endif  // USE_TFLM_COMPRESSION
              ;
          int8_t* output_data = tflite::micro::GetTensorData<int8_t>(output);
#if defined(TFLM_SOC_MMA)
          if (TryMmaFullyConnectedInt8(data, input, input_data, filter,
                                       filter_data, bias, bias_data, output,
                                       output_data)) {
            SocProgress(0x5b320212u);
            break;
          }
          SocProgress(0x5b320213u);
#endif  // defined(TFLM_SOC_MMA)
          data.is_per_channel
              ? tflite::reference_integer_ops::FullyConnectedPerChannel(
                    FullyConnectedParamsQuantized(data),
                    data.per_channel_output_multiplier,
                    reinterpret_cast<const int*>(data.per_channel_output_shift),
                    input_shape, input_data, filter_shape, filter_data,
                    bias_shape, bias_data, output_shape, output_data)
              : tflite::reference_integer_ops::FullyConnected(
                    FullyConnectedParamsQuantized(data),
                    input_shape, input_data, filter_shape, filter_data,
                    bias_shape, bias_data, output_shape, output_data);
          SocProgress(0x5b320211u);
          break;
        }
        default: {
          MicroPrintf("Filter type %s (%d) not supported.",
                      TfLiteTypeGetName(filter->type), input->type);
          return kTfLiteError;
        }
      }
      break;
    }

    case kTfLiteInt16: {
      switch (filter->type) {
        case kTfLiteInt8: {
          if (bias == nullptr || bias->type == kTfLiteInt32) {
            data.is_per_channel
                ? tflite::reference_integer_ops::FullyConnectedPerChannel(
                      FullyConnectedParamsQuantized(data),
                      data.per_channel_output_multiplier,
                      reinterpret_cast<const int*>(
                          data.per_channel_output_shift),
                      tflite::micro::GetTensorShape(input),
                      tflite::micro::GetTensorData<int16_t>(input),
                      tflite::micro::GetTensorShape(filter),
#ifdef USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorData<int8_t>(
                          micro_context, filter, weights_comp_td,
                          data.weights_scratch_index),
                      tflite::micro::GetTensorShape(bias),
                      tflite::micro::GetOptionalTensorData<int32_t>(
                          micro_context, bias, bias_comp_td,
                          data.bias_scratch_index),
#else   // USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorData<int8_t>(filter),
                      tflite::micro::GetTensorShape(bias),
                      tflite::micro::GetOptionalTensorData<int32_t>(bias),
#endif  // USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorShape(output),
                      tflite::micro::GetTensorData<int16_t>(output))
                : tflite::reference_integer_ops::FullyConnected(
                      FullyConnectedParamsQuantized(data),
                      tflite::micro::GetTensorShape(input),
                      tflite::micro::GetTensorData<int16_t>(input),
                      tflite::micro::GetTensorShape(filter),
#ifdef USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorData<int8_t>(
                          micro_context, filter, weights_comp_td,
                          data.weights_scratch_index),
                      tflite::micro::GetTensorShape(bias),
                      tflite::micro::GetOptionalTensorData<int32_t>(
                          micro_context, bias, bias_comp_td,
                          data.bias_scratch_index),
#else   // USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorData<int8_t>(filter),
                      tflite::micro::GetTensorShape(bias),
                      tflite::micro::GetOptionalTensorData<int32_t>(bias),
#endif  // USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorShape(output),
                      tflite::micro::GetTensorData<int16_t>(output));
          } else if (bias->type == kTfLiteInt64) {
            data.is_per_channel
                ? tflite::reference_integer_ops::FullyConnectedPerChannel(
                      FullyConnectedParamsQuantized(data),
                      data.per_channel_output_multiplier,
                      reinterpret_cast<const int*>(
                          data.per_channel_output_shift),
                      tflite::micro::GetTensorShape(input),
                      tflite::micro::GetTensorData<int16_t>(input),
                      tflite::micro::GetTensorShape(filter),
#ifdef USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorData<int8_t>(
                          micro_context, filter, weights_comp_td,
                          data.weights_scratch_index),
                      tflite::micro::GetTensorShape(bias),
                      tflite::micro::GetOptionalTensorData<int64_t>(
                          micro_context, bias, bias_comp_td,
                          data.bias_scratch_index),
#else   // USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorData<int8_t>(filter),
                      tflite::micro::GetTensorShape(bias),
                      tflite::micro::GetOptionalTensorData<int64_t>(bias),
#endif  // USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorShape(output),
                      tflite::micro::GetTensorData<int16_t>(output))
                : tflite::reference_integer_ops::FullyConnected(
                      FullyConnectedParamsQuantized(data),
                      tflite::micro::GetTensorShape(input),
                      tflite::micro::GetTensorData<int16_t>(input),
                      tflite::micro::GetTensorShape(filter),
#ifdef USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorData<int8_t>(
                          micro_context, filter, weights_comp_td,
                          data.weights_scratch_index),
                      tflite::micro::GetTensorShape(bias),
                      tflite::micro::GetOptionalTensorData<int64_t>(
                          micro_context, bias, bias_comp_td,
                          data.bias_scratch_index),
#else   // USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorData<int8_t>(filter),
                      tflite::micro::GetTensorShape(bias),
                      tflite::micro::GetOptionalTensorData<int64_t>(bias),
#endif  // USE_TFLM_COMPRESSION
                      tflite::micro::GetTensorShape(output),
                      tflite::micro::GetTensorData<int16_t>(output));
          }
          break;
        }
        default: {
          MicroPrintf("Filter type %s (%d) not supported.",
                      TfLiteTypeGetName(filter->type), input->type);
          return kTfLiteError;
        }
      }
      break;
    }

    default: {
      MicroPrintf("Input type %s (%d) not supported.",
                  TfLiteTypeGetName(input->type), input->type);
      return kTfLiteError;
    }
  }
  SocProgress(0x5b3200ffu);
  return kTfLiteOk;
}

}  // namespace

TFLMRegistration Register_FULLY_CONNECTED() {
  return tflite::micro::RegisterOp(FullyConnectedInit, FullyConnectedPrepare,
                                   FullyConnectedEval);
}

TFLMInferenceRegistration RegisterInference_FULLY_CONNECTED() {
  return tflite::micro::RegisterOp(FullyConnectedEval);
}

}  // namespace tflite
