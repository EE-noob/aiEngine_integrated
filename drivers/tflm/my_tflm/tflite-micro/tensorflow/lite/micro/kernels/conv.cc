/* Copyright 2024 The TensorFlow Authors. All Rights Reserved.

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

#include "tensorflow/lite/micro/kernels/conv.h"

#include "tensorflow/lite/c/builtin_op_data.h"
#include "tensorflow/lite/c/common.h"
#include "tensorflow/lite/kernels/internal/common.h"
#include "tensorflow/lite/kernels/internal/portable_tensor_utils.h"
#include "tensorflow/lite/kernels/internal/reference/conv.h"
#include "tensorflow/lite/kernels/internal/reference/integer_ops/conv.h"
#include "tensorflow/lite/kernels/kernel_util.h"
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
constexpr int kMmaVectorCols = static_cast<int>(DSA_TILE_SIZE);
constexpr int kMmaMaxRows = 512;
constexpr int kMmaMaxInner = 512;
constexpr int kMmaTimeout = 2000000;
constexpr uint32_t kMmaIaCacheBlocks =
    static_cast<uint32_t>(DSA_IA_CACHE_BLOCKS);

alignas(16) int8_t g_mma_lhs[kMmaMaxRows * kMmaMaxInner];
alignas(16) int8_t g_mma_rhs[kMmaMaxInner * kMmaVectorCols];
alignas(16) int8_t g_mma_dst[kMmaMaxRows * kMmaVectorCols];
alignas(16) int32_t g_mma_bias[kMmaVectorCols];
alignas(16) int32_t g_mma_mult[kMmaVectorCols];
alignas(16) int32_t g_mma_shift[kMmaVectorCols];

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

[[maybe_unused]] int CeilDivInt(int value, int divisor) {
  return divisor == 0 ? 0 : (value + divisor - 1) / divisor;
}

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
      int32_t acc = g_mma_bias[col];
      for (int red = 0; red < inner; ++red) {
        const int32_t lhs =
            static_cast<int32_t>(g_mma_lhs[row * lhs_stride + red]) +
            lhs_offset;
        const int32_t rhs =
            static_cast<int32_t>(g_mma_rhs[red * rhs_stride + col]) +
            rhs_offset;
        acc += lhs * rhs;
      }
      const int8_t expected = EvalMmaReferenceElement(
          row, col, inner, lhs_stride, rhs_stride, lhs_offset, rhs_offset,
          dst_offset, act_min, act_max);
      const int8_t got = g_mma_dst[row * dst_stride + col];
      if (got != expected) {
        const int32_t scaled =
            MultiplyByQuantizedMultiplier(acc, g_mma_mult[col],
                                          g_mma_shift[col]);
        const int32_t with_offset = scaled + dst_offset;
        SocProgress(0x5c3e0000u | ((row & 0xff) << 8) | (col & 0xff));
        SocProgress(0x5c320000u |
                    ((static_cast<uint32_t>(static_cast<uint8_t>(act_min))
                      << 8) |
                     static_cast<uint32_t>(static_cast<uint8_t>(act_max))));
        SocProgress(0x5c330000u |
                    (static_cast<uint32_t>(dst_offset) & 0xffffu));
        SocProgress(0x5c340000u |
                    (static_cast<uint32_t>(scaled) & 0xffffu));
        SocProgress(0x5c350000u |
                    ((static_cast<uint32_t>(scaled) >> 16) & 0xffffu));
        SocProgress(0x5c360000u |
                    (static_cast<uint32_t>(with_offset) & 0xffffu));
        SocProgress(0x5c370000u |
                    ((static_cast<uint32_t>(with_offset) >> 16) & 0xffffu));
        SocProgress(0x5c380000u | (static_cast<uint32_t>(acc) & 0xffffu));
        SocProgress(0x5c390000u |
                    ((static_cast<uint32_t>(acc) >> 16) & 0xffffu));
        SocProgress(0x5c3a0000u |
                    (static_cast<uint32_t>(g_mma_shift[col]) & 0xffffu));
        SocProgress(0x5c3b0000u |
                    (static_cast<uint32_t>(g_mma_mult[col]) & 0xffffu));
        SocProgress(0x5c3c0000u |
                    ((static_cast<uint32_t>(g_mma_mult[col]) >> 16) & 0xffffu));
        SocProgress(0x5c3e8000u |
                    ((static_cast<uint32_t>(static_cast<uint8_t>(got)) << 8) |
                     static_cast<uint32_t>(static_cast<uint8_t>(expected))));
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
  const uint32_t lhs0 =
      static_cast<uint32_t>(static_cast<uint8_t>(g_mma_lhs[0])) |
      (static_cast<uint32_t>(static_cast<uint8_t>(g_mma_lhs[1])) << 8) |
      (static_cast<uint32_t>(static_cast<uint8_t>(g_mma_lhs[2])) << 16) |
      (static_cast<uint32_t>(static_cast<uint8_t>(g_mma_lhs[3])) << 24);
  SocProgress(0x5c400000u | (lhs0 & 0xffffu));
  SocProgress(0x5c410000u | ((lhs0 >> 16) & 0xffffu));
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
        SocProgress(0x5c3d0000u | (status & 0xffu));
        MicroPrintf("[mma self] conv status error status=%d", status);
        return false;
      }
      const uint32_t wb_data = DsaRead(kDsaRegWbData);
      const bool ok = wb_data == 0u;
      DmaMemoryBarrier();
      if (!ok) {
        SocProgress(0x5c3f0000u | (wb_data & 0xffffu));
        MicroPrintf("[mma self] conv wb_data=%d status=%d", wb_data, status);
        return false;
      }
#if defined(TFLM_SOC_MMA_SELF_CHECK)
      if (!CheckMmaOutput("conv", rows, inner, cols, lhs_stride, rhs_stride,
                          dst_stride, lhs_offset, rhs_offset, dst_offset,
                          act_min, act_max)) {
        return false;
      }
#endif
      return true;
    }
  }
  SocProgress(0x5c3dff00u);
  MicroPrintf("[mma self] conv timeout");
  return false;
#endif
}

bool TryMmaConvInt8(const TfLiteConvParams& params, const OpDataConv& data,
                    const TfLiteEvalTensor* input, const int8_t* input_data,
                    const TfLiteEvalTensor* filter,
                    const int8_t* filter_data,
                    const TfLiteEvalTensor* bias, const int32_t* bias_data,
                    const TfLiteEvalTensor* output, int8_t* output_data) {
  const RuntimeShape input_shape = tflite::micro::GetTensorShape(input);
  const RuntimeShape filter_shape = tflite::micro::GetTensorShape(filter);
  const RuntimeShape output_shape = tflite::micro::GetTensorShape(output);
  const ConvParams op_params = ConvParamsQuantized(params, data);

  if (input_shape.DimensionsCount() != 4 || filter_shape.DimensionsCount() != 4 ||
      output_shape.DimensionsCount() != 4 || input_data == nullptr ||
      filter_data == nullptr || output_data == nullptr) {
    return false;
  }

  const int batches = MatchingDim(input_shape, 0, output_shape, 0);
  const int input_height = input_shape.Dims(1);
  const int input_width = input_shape.Dims(2);
  const int input_depth = input_shape.Dims(3);
  const int output_depth = MatchingDim(filter_shape, 0, output_shape, 3);
  const int filter_height = filter_shape.Dims(1);
  const int filter_width = filter_shape.Dims(2);
  const int filter_input_depth = filter_shape.Dims(3);
  const int output_height = output_shape.Dims(1);
  const int output_width = output_shape.Dims(2);
  const int total_rows = batches * output_height * output_width;
  const int inner = filter_height * filter_width * input_depth;
  const int pad_value = -op_params.input_offset;

  if (filter_input_depth != input_depth || inner <= 0 ||
      inner > kMmaMaxInner || pad_value < -128 || pad_value > 127 ||
      output_depth <= 0 || total_rows <= 0 || data.filter_zero_point != 0) {
    return false;
  }

  SocProgress(0x5c311000u);
  const int input_batch_stride = input_height * input_width * input_depth;
  const int input_row_stride = input_width * input_depth;
  const int output_row_stride = output_width * output_depth;
  const int output_batch_stride = output_height * output_row_stride;
  const int8_t pad_value_s8 = static_cast<int8_t>(pad_value);

  for (int col_base = 0; col_base < output_depth;
       col_base += kMmaVectorCols) {
    const int col_count = MinInt(kMmaVectorCols, output_depth - col_base);
    const int lhs_stride = Align4(inner);
    const int rhs_stride = Align4(col_count);
    const int dst_stride = Align4(col_count);
    SocProgress(0x5c312000u | (col_base & 0xff));
    for (int red = 0; red < inner; ++red) {
      for (int col = 0; col < rhs_stride; ++col) {
        g_mma_rhs[red * rhs_stride + col] = 0;
      }
      const int kernel_idx = red / input_depth;
      const int in_channel = red - kernel_idx * input_depth;
      const int filter_y = kernel_idx / filter_width;
      const int filter_x = kernel_idx - filter_y * filter_width;
      for (int col = 0; col < col_count; ++col) {
        const int out_channel = col_base + col;
        const int filter_offset =
            (((out_channel * filter_height + filter_y) * filter_width +
              filter_x) *
             input_depth) +
            in_channel;
        g_mma_rhs[red * rhs_stride + col] = filter_data[filter_offset];
      }
    }

    for (int col = 0; col < col_count; ++col) {
      const int out_channel = col_base + col;
      g_mma_bias[col] =
          (bias != nullptr && bias_data != nullptr) ? bias_data[out_channel] : 0;
      g_mma_mult[col] = data.per_channel_output_multiplier[out_channel];
      g_mma_shift[col] = data.per_channel_output_shift[out_channel];
    }

    for (int row_base = 0; row_base < total_rows; row_base += kMmaMaxRows) {
      const int row_count = MinInt(kMmaMaxRows, total_rows - row_base);
      SocProgress(0x5c313000u | ((row_base / kMmaMaxRows) & 0xff));
      for (int local_row = 0; local_row < row_count; ++local_row) {
        const int out_linear = row_base + local_row;
        const int batch = out_linear / (output_height * output_width);
        const int out_hw = out_linear - batch * output_height * output_width;
        const int out_y = out_hw / output_width;
        const int out_x = out_hw - out_y * output_width;
        const int in_y_origin =
            out_y * params.stride_height - data.padding.height;
        const int in_x_origin =
            out_x * params.stride_width - data.padding.width;
        const int8_t* batch_input =
            input_data + batch * input_batch_stride;
        int8_t* dst = g_mma_lhs + local_row * lhs_stride;
        for (int idx = 0; idx < lhs_stride; ++idx) {
          dst[idx] = 0;
        }

        for (int filter_y = 0; filter_y < filter_height; ++filter_y) {
          const int in_y =
              in_y_origin + params.dilation_height_factor * filter_y;
          const bool y_inside = (in_y >= 0) && (in_y < input_height);
          for (int filter_x = 0; filter_x < filter_width; ++filter_x) {
            const int in_x =
                in_x_origin + params.dilation_width_factor * filter_x;
            const bool inside =
                y_inside && (in_x >= 0) && (in_x < input_width);
            const int8_t* input_pixel =
                inside ? batch_input + in_y * input_row_stride +
                             in_x * input_depth
                       : batch_input;
            for (int in_channel = 0; in_channel < input_depth; ++in_channel) {
              *dst++ = inside ? input_pixel[in_channel] : pad_value_s8;
            }
          }
        }
      }

      if (!RunMma(row_count, inner, col_count, lhs_stride, rhs_stride,
                  dst_stride, op_params.input_offset,
                  op_params.weights_offset, op_params.output_offset,
                  op_params.quantized_activation_min,
                  op_params.quantized_activation_max)) {
        SocProgress(0x5c31e001u);
        return false;
      }

      for (int local_row = 0; local_row < row_count; ++local_row) {
        const int out_linear = row_base + local_row;
        const int batch = out_linear / (output_height * output_width);
        const int out_hw = out_linear - batch * output_height * output_width;
        const int out_y = out_hw / output_width;
        const int out_x = out_hw - out_y * output_width;
        int8_t* out_pixel = output_data + batch * output_batch_stride +
                            out_y * output_row_stride +
                            out_x * output_depth + col_base;
        for (int col = 0; col < col_count; ++col) {
          out_pixel[col] = g_mma_dst[local_row * dst_stride + col];
        }
      }
    }
  }

  SocProgress(0x5c311001u);
  return true;
}
#endif  // defined(TFLM_SOC_MMA)

TfLiteStatus ConvEval(TfLiteContext* context, TfLiteNode* node) {
  SocProgress(0x5c310001u);
  const TfLiteEvalTensor* input =
      tflite::micro::GetEvalInput(context, node, kConvInputTensor);
  const TfLiteEvalTensor* filter =
      tflite::micro::GetEvalInput(context, node, kConvWeightsTensor);
  const TfLiteEvalTensor* bias =
      (NumInputs(node) == 3)
          ? tflite::micro::GetEvalInput(context, node, kConvBiasTensor)
          : nullptr;
  TfLiteEvalTensor* output =
      tflite::micro::GetEvalOutput(context, node, kConvOutputTensor);

  TFLITE_DCHECK(node->builtin_data != nullptr);
  const auto& params =
      *(reinterpret_cast<TfLiteConvParams*>(node->builtin_data));
  TFLITE_DCHECK(node->user_data != nullptr);
  const auto& data = *(static_cast<const OpDataConv*>(node->user_data));

#ifdef USE_TFLM_COMPRESSION

  MicroContext* micro_context = GetMicroContext(context);

  const CompressionTensorData* weights_comp_td =
      micro_context->GetTensorCompressionData(node, kConvWeightsTensor);
  const CompressionTensorData* bias_comp_td =
      micro_context->GetTensorCompressionData(node, kConvBiasTensor);

#endif  // USE_TFLM_COMPRESSION

  switch (input->type) {  // Already know in/out types are same.
    case kTfLiteFloat32: {
      tflite::reference_ops::Conv(
          ConvParamsFloat(params, data), tflite::micro::GetTensorShape(input),
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
          tflite::micro::GetTensorData<float>(output),
          tflite::micro::GetTensorShape(nullptr), nullptr);
      break;
    }
    case kTfLiteInt16: {
      if (bias == nullptr || bias->type == kTfLiteInt32) {
        reference_integer_ops::ConvPerChannel(
            ConvParamsQuantized(params, data),
            data.per_channel_output_multiplier, data.per_channel_output_shift,
            tflite::micro::GetTensorShape(input),
            tflite::micro::GetTensorData<int16_t>(input),
            tflite::micro::GetTensorShape(filter),
#ifdef USE_TFLM_COMPRESSION
            tflite::micro::GetTensorData<int8_t>(micro_context, filter,
                                                 weights_comp_td,
                                                 data.weights_scratch_index),
            tflite::micro::GetTensorShape(bias),
            tflite::micro::GetOptionalTensorData<int32_t>(
                micro_context, bias, bias_comp_td, data.bias_scratch_index),
#else   // USE_TFLM_COMPRESSION
            tflite::micro::GetTensorData<int8_t>(filter),
            tflite::micro::GetTensorShape(bias),
            tflite::micro::GetOptionalTensorData<std::int32_t>(bias),
#endif  // USE_TFLM_COMPRESSION
            tflite::micro::GetTensorShape(output),
            tflite::micro::GetTensorData<int16_t>(output));
      } else if (bias->type == kTfLiteInt64) {
        reference_integer_ops::ConvPerChannel(
            ConvParamsQuantized(params, data),
            data.per_channel_output_multiplier, data.per_channel_output_shift,
            tflite::micro::GetTensorShape(input),
            tflite::micro::GetTensorData<int16_t>(input),
            tflite::micro::GetTensorShape(filter),
#ifdef USE_TFLM_COMPRESSION
            tflite::micro::GetTensorData<int8_t>(micro_context, filter,
                                                 weights_comp_td,
                                                 data.weights_scratch_index),
            tflite::micro::GetTensorShape(bias),
            tflite::micro::GetTensorData<int64_t>(
                micro_context, bias, bias_comp_td, data.bias_scratch_index),
#else   // USE_TFLM_COMPRESSION
            tflite::micro::GetTensorData<int8_t>(filter),
            tflite::micro::GetTensorShape(bias),
            tflite::micro::GetTensorData<std::int64_t>(bias),
#endif  // USE_TFLM_COMPRESSION
            tflite::micro::GetTensorShape(output),
            tflite::micro::GetTensorData<int16_t>(output));
      } else {
        MicroPrintf("Bias type %s (%d) not supported.",
                    TfLiteTypeGetName(bias->type), bias->type);
        return kTfLiteError;
      }
      break;
    }
    case kTfLiteInt8: {
      switch (filter->type) {
        case kTfLiteInt4: {
          int8_t* unpacked_filter_data = static_cast<int8_t*>(
              context->GetScratchBuffer(context, data.filter_buffer_index));
          tflite::tensor_utils::UnpackDenseInt4IntoInt8(
              tflite::micro::GetTensorData<int8_t>(filter),
              tflite::micro::GetTensorShape(filter).FlatSize(),
              unpacked_filter_data);
          reference_integer_ops::ConvPerChannel(
              ConvParamsQuantized(params, data),
              data.per_channel_output_multiplier, data.per_channel_output_shift,
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
          SocProgress(0x5c310210u);
#ifdef USE_TFLM_COMPRESSION
          const int8_t* filter_data = tflite::micro::GetTensorData<int8_t>(
              micro_context, filter, weights_comp_td,
              data.weights_scratch_index);
          const int32_t* bias_data =
              tflite::micro::GetOptionalTensorData<int32_t>(
                  micro_context, bias, bias_comp_td, data.bias_scratch_index);
#else   // USE_TFLM_COMPRESSION
          const int8_t* filter_data = tflite::micro::GetTensorData<int8_t>(filter);
          const int32_t* bias_data =
              tflite::micro::GetOptionalTensorData<int32_t>(bias);
#endif  // USE_TFLM_COMPRESSION
#if defined(TFLM_SOC_MMA)
          if (TryMmaConvInt8(
                  params, data, input,
                  tflite::micro::GetTensorData<int8_t>(input), filter,
                  filter_data, bias, bias_data, output,
                  tflite::micro::GetTensorData<int8_t>(output))) {
            SocProgress(0x5c310212u);
            break;
          }
          SocProgress(0x5c310213u);
#endif  // defined(TFLM_SOC_MMA)
          reference_integer_ops::ConvPerChannel(
              ConvParamsQuantized(params, data),
              data.per_channel_output_multiplier, data.per_channel_output_shift,
              tflite::micro::GetTensorShape(input),
              tflite::micro::GetTensorData<int8_t>(input),
              tflite::micro::GetTensorShape(filter), filter_data,
              tflite::micro::GetTensorShape(bias), bias_data,
              tflite::micro::GetTensorShape(output),
              tflite::micro::GetTensorData<int8_t>(output));
          SocProgress(0x5c310211u);
          break;
        }
        default:
          MicroPrintf("Weight type %s (%d) not supported.",
                      TfLiteTypeGetName(filter->type), filter->type);
          return kTfLiteError;
      }
      break;
    }
    default:
      MicroPrintf("Type %s (%d) not supported.", TfLiteTypeGetName(input->type),
                  input->type);
      return kTfLiteError;
  }
  return kTfLiteOk;
}

}  // namespace

TFLMRegistration Register_CONV_2D() {
  return tflite::micro::RegisterOp(ConvInit, ConvPrepare, ConvEval);
}

}  // namespace tflite
