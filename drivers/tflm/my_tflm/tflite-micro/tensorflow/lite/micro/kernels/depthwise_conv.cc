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

#include "tensorflow/lite/micro/kernels/depthwise_conv.h"

#include "tensorflow/lite/c/builtin_op_data.h"
#include "tensorflow/lite/c/common.h"
#include "tensorflow/lite/kernels/internal/portable_tensor_utils.h"
#include "tensorflow/lite/kernels/internal/reference/depthwiseconv_float.h"
#include "tensorflow/lite/kernels/internal/reference/integer_ops/depthwise_conv.h"
#include "tensorflow/lite/kernels/kernel_util.h"
#include "tensorflow/lite/micro/kernels/kernel_util.h"
#include "tensorflow/lite/micro/micro_log.h"

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
constexpr int kMmaVectorCols = 16;
constexpr int kMmaMaxRows = 512;
constexpr int kMmaMaxInner = 128;
constexpr int kMmaTimeout = 2000000;

alignas(16) int8_t g_mma_lhs[kMmaMaxRows * kMmaMaxInner];
alignas(16) int8_t g_mma_rhs[kMmaMaxInner * kMmaVectorCols];
alignas(16) int8_t g_mma_dst[kMmaMaxRows * kMmaVectorCols];
alignas(16) int32_t g_mma_bias[kMmaVectorCols];
alignas(16) int32_t g_mma_mult[kMmaVectorCols];
alignas(16) int32_t g_mma_shift[kMmaVectorCols];

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

bool RunMma(int rows, int inner, int cols, int lhs_offset, int dst_offset,
            int act_min, int act_max) {
  DsaWrite(kCsrMultLhsPtr, PtrToDsa(g_mma_lhs));
  DsaWrite(kCsrMultRhsPtr, PtrToDsa(g_mma_rhs));
  DsaWrite(kCsrMultDstPtr, PtrToDsa(g_mma_dst));
  DsaWrite(kCsrMultBiasPtr, PtrToDsa(g_mma_bias));
  DsaWrite(kCsrMultLhsRows, static_cast<uint32_t>(rows));
  DsaWrite(kCsrMultRhsCols, static_cast<uint32_t>(inner));
  DsaWrite(kCsrMultRhsRows, static_cast<uint32_t>(cols));
  DsaWrite(kCsrMultLhsRowStride, static_cast<uint32_t>(inner));
  DsaWrite(kCsrMultRhsColStride, static_cast<uint32_t>(inner));
  DsaWrite(kCsrMultDstRowStride, static_cast<uint32_t>(cols));
  DsaWrite(kCsrMultLhsOffset, static_cast<uint32_t>(lhs_offset));
  DsaWrite(kCsrMultRhsOffset, 0u);
  DsaWrite(kCsrMultDstOffset, static_cast<uint32_t>(dst_offset));
  DsaWrite(kCsrMultDstMult, PtrToDsa(g_mma_mult));
  DsaWrite(kCsrMultDstShift, PtrToDsa(g_mma_shift));
  DsaWrite(kCsrMultActMin, static_cast<uint32_t>(act_min));
  DsaWrite(kCsrMultActMax, static_cast<uint32_t>(act_max));
  DsaWrite(kDsaRegCtrl, kDsaCtrlStart | kDsaCtrlPerChannel |
                            kDsaCtrlClearDone | kDsaCtrlClearWbValid);

  for (int timeout = kMmaTimeout; timeout > 0; --timeout) {
    const uint32_t status = DsaRead(kDsaRegStatus);
    if ((status & kDsaStatusDone) != 0u) {
      if ((status & kDsaStatusErrMask) != 0u) {
        return false;
      }
      return DsaRead(kDsaRegWbData) == 0u;
    }
  }
  return false;
}

bool TryMmaDepthwiseInt8(const TfLiteDepthwiseConvParams& params,
                         const OpDataConv& data,
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
  const DepthwiseParams op_params = DepthwiseConvParamsQuantized(params, data);

  if (input_shape.DimensionsCount() != 4 || filter_shape.DimensionsCount() != 4 ||
      output_shape.DimensionsCount() != 4 || filter_data == nullptr ||
      output_data == nullptr || data.filter_zero_point != 0) {
    return false;
  }

  const int batches = MatchingDim(input_shape, 0, output_shape, 0);
  const int input_height = input_shape.Dims(1);
  const int input_width = input_shape.Dims(2);
  const int input_depth = input_shape.Dims(3);
  const int filter_height = filter_shape.Dims(1);
  const int filter_width = filter_shape.Dims(2);
  const int output_height = output_shape.Dims(1);
  const int output_width = output_shape.Dims(2);
  const int output_depth = MatchingDim(filter_shape, 3, output_shape, 3);
  const int rows = batches * output_height * output_width;
  const int inner = filter_height * filter_width * input_depth;
  const int cols = kMmaVectorCols;
  const int pad_value = -op_params.input_offset;

  if (output_depth > kMmaVectorCols || rows > kMmaMaxRows ||
      inner > kMmaMaxInner || pad_value < -128 || pad_value > 127 ||
      output_depth != input_depth * params.depth_multiplier) {
    return false;
  }

  SocProgress(0x5b311000u);
  int row = 0;
  const int8_t pad_value_s8 = static_cast<int8_t>(pad_value);
  if (input_depth == 1 && params.dilation_width_factor == 1 &&
      params.dilation_height_factor == 1) {
    const int input_batch_stride = input_height * input_width;
    for (int batch = 0; batch < batches; ++batch) {
      const int8_t* batch_input = input_data + batch * input_batch_stride;
      for (int out_y = 0; out_y < output_height; ++out_y) {
        SocProgress(0x5b312000u | (out_y & 0xff));
        const int in_y_origin =
            out_y * params.stride_height - data.padding.height;
        for (int out_x = 0; out_x < output_width; ++out_x) {
          const int in_x_origin =
              out_x * params.stride_width - data.padding.width;
          int8_t* dst = g_mma_lhs + row * inner;
          ++row;
          for (int filter_y = 0; filter_y < filter_height; ++filter_y) {
            const int in_y = in_y_origin + filter_y;
            const bool y_inside = (in_y >= 0) && (in_y < input_height);
            const int8_t* input_row =
                y_inside ? batch_input + in_y * input_width : batch_input;
            for (int filter_x = 0; filter_x < filter_width; ++filter_x) {
              const int in_x = in_x_origin + filter_x;
              *dst++ =
                  (y_inside && in_x >= 0 && in_x < input_width)
                      ? input_row[in_x]
                      : pad_value_s8;
            }
          }
        }
      }
    }
  } else {
    const int input_batch_stride = input_height * input_width * input_depth;
    const int input_row_stride = input_width * input_depth;
    for (int batch = 0; batch < batches; ++batch) {
      const int8_t* batch_input = input_data + batch * input_batch_stride;
      for (int out_y = 0; out_y < output_height; ++out_y) {
        SocProgress(0x5b312000u | (out_y & 0xff));
        const int in_y_origin =
            out_y * params.stride_height - data.padding.height;
        for (int out_x = 0; out_x < output_width; ++out_x) {
          const int in_x_origin =
              out_x * params.stride_width - data.padding.width;
          int8_t* dst = g_mma_lhs + row * inner;
          ++row;
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
              for (int in_channel = 0; in_channel < input_depth;
                   ++in_channel) {
                *dst++ = inside ? input_pixel[in_channel] : pad_value_s8;
              }
            }
          }
        }
      }
    }
  }

  SocProgress(0x5b311001u);
  if (input_depth == 1) {
    for (int out_channel = 0; out_channel < cols; ++out_channel) {
      int8_t* rhs_col = g_mma_rhs + out_channel * inner;
      if (out_channel < output_depth) {
        for (int filter_y = 0; filter_y < filter_height; ++filter_y) {
          const int filter_row_offset =
              (filter_y * filter_width) * output_depth + out_channel;
          for (int filter_x = 0; filter_x < filter_width; ++filter_x) {
            *rhs_col++ =
                filter_data[filter_row_offset + filter_x * output_depth];
          }
        }
      } else {
        for (int col = 0; col < inner; ++col) {
          *rhs_col++ = 0;
        }
      }
    }
  } else {
    for (int out_channel = 0; out_channel < cols; ++out_channel) {
      int8_t* rhs_col = g_mma_rhs + out_channel * inner;
      if (out_channel < output_depth) {
        const int active_in_channel = out_channel / params.depth_multiplier;
        for (int filter_y = 0; filter_y < filter_height; ++filter_y) {
          for (int filter_x = 0; filter_x < filter_width; ++filter_x) {
            const int filter_offset =
                ((filter_y * filter_width + filter_x) * output_depth) +
                out_channel;
            for (int in_channel = 0; in_channel < input_depth; ++in_channel) {
              *rhs_col++ = (in_channel == active_in_channel)
                               ? filter_data[filter_offset]
                               : 0;
            }
          }
        }
      } else {
        for (int col = 0; col < inner; ++col) {
          *rhs_col++ = 0;
        }
      }
    }
  }

  for (int out_channel = 0; out_channel < cols; ++out_channel) {
    if (out_channel < output_depth) {
      g_mma_bias[out_channel] = (bias != nullptr && bias_data != nullptr)
                                    ? bias_data[out_channel]
                                    : 0;
      g_mma_mult[out_channel] = data.per_channel_output_multiplier[out_channel];
      g_mma_shift[out_channel] = data.per_channel_output_shift[out_channel];
    } else {
      g_mma_bias[out_channel] = 0;
      g_mma_mult[out_channel] = 1073741824;
      g_mma_shift[out_channel] = 0;
    }
  }

  SocProgress(0x5b311002u);
  if (!RunMma(rows, inner, cols, op_params.input_offset,
              op_params.output_offset, op_params.quantized_activation_min,
              op_params.quantized_activation_max)) {
    SocProgress(0x5b31e001u);
    return false;
  }

  SocProgress(0x5b311003u);
  for (int out_row = 0; out_row < rows; ++out_row) {
    for (int out_channel = 0; out_channel < output_depth; ++out_channel) {
      output_data[out_row * output_depth + out_channel] =
          g_mma_dst[out_row * cols + out_channel];
    }
  }

  return true;
}
#endif  // defined(TFLM_SOC_MMA)

void* DepthwiseConvInit(TfLiteContext* context, const char* buffer,
                        size_t length) {
  TFLITE_DCHECK(context->AllocatePersistentBuffer != nullptr);
  return context->AllocatePersistentBuffer(context, sizeof(OpDataConv));
}

TfLiteStatus DepthwiseConvEval(TfLiteContext* context, TfLiteNode* node) {
  SocProgress(0x5b310001u);
  TFLITE_DCHECK(node->user_data != nullptr);
  TFLITE_DCHECK(node->builtin_data != nullptr);

  auto& params =
      *(reinterpret_cast<TfLiteDepthwiseConvParams*>(node->builtin_data));
  const OpDataConv& data = *(static_cast<const OpDataConv*>(node->user_data));

  TfLiteEvalTensor* output =
      tflite::micro::GetEvalOutput(context, node, kDepthwiseConvOutputTensor);
  const TfLiteEvalTensor* input =
      tflite::micro::GetEvalInput(context, node, kDepthwiseConvInputTensor);
  const TfLiteEvalTensor* filter =
      tflite::micro::GetEvalInput(context, node, kDepthwiseConvWeightsTensor);
  const TfLiteEvalTensor* bias =
      (NumInputs(node) == 3)
          ? tflite::micro::GetEvalInput(context, node, kDepthwiseConvBiasTensor)
          : nullptr;

#ifdef USE_TFLM_COMPRESSION

  MicroContext* micro_context = GetMicroContext(context);

  const CompressionTensorData* filter_comp_td =
      micro_context->GetTensorCompressionData(node,
                                              kDepthwiseConvWeightsTensor);
  const CompressionTensorData* bias_comp_td =
      micro_context->GetTensorCompressionData(node, kDepthwiseConvBiasTensor);

#endif  // USE_TFLM_COMPRESSION

  switch (input->type) {  // Already know in/out types are same.
    case kTfLiteFloat32: {
      tflite::reference_ops::DepthwiseConv(
          DepthwiseConvParamsFloat(params, data),
          tflite::micro::GetTensorShape(input),
          tflite::micro::GetTensorData<float>(input),
          tflite::micro::GetTensorShape(filter),
#ifdef USE_TFLM_COMPRESSION
          tflite::micro::GetTensorData<float>(micro_context, filter,
                                              filter_comp_td,
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
      SocProgress(0x5b310200u | (filter->type & 0xff));
      switch (filter->type) {
        case kTfLiteInt4: {
          int8_t* unpacked_filter_data = static_cast<int8_t*>(
              context->GetScratchBuffer(context, data.filter_buffer_index));
          tflite::tensor_utils::UnpackDenseInt4IntoInt8(
              tflite::micro::GetTensorData<int8_t>(filter),
              tflite::micro::GetTensorShape(filter).FlatSize(),
              unpacked_filter_data);
          reference_integer_ops::DepthwiseConvPerChannel(
              DepthwiseConvParamsQuantized(params, data),
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
          SocProgress(0x5b310210u);
#ifdef USE_TFLM_COMPRESSION
          const int8_t* filter_data = tflite::micro::GetTensorData<int8_t>(
              micro_context, filter, filter_comp_td, data.weights_scratch_index);
          const int32_t* bias_data =
              tflite::micro::GetOptionalTensorData<int32_t>(
                  micro_context, bias, bias_comp_td, data.bias_scratch_index);
#else   // USE_TFLM_COMPRESSION
          const int8_t* filter_data = tflite::micro::GetTensorData<int8_t>(filter);
          const int32_t* bias_data =
              tflite::micro::GetOptionalTensorData<int32_t>(bias);
#endif  // USE_TFLM_COMPRESSION
#if defined(TFLM_SOC_MMA)
          if (TryMmaDepthwiseInt8(
                  params, data, input,
                  tflite::micro::GetTensorData<int8_t>(input), filter,
                  filter_data, bias, bias_data, output,
                  tflite::micro::GetTensorData<int8_t>(output))) {
            SocProgress(0x5b310212u);
            break;
          }
          SocProgress(0x5b310213u);
#endif  // defined(TFLM_SOC_MMA)
          reference_integer_ops::DepthwiseConvPerChannel(
              DepthwiseConvParamsQuantized(params, data),
              data.per_channel_output_multiplier, data.per_channel_output_shift,
              tflite::micro::GetTensorShape(input),
              tflite::micro::GetTensorData<int8_t>(input),
              tflite::micro::GetTensorShape(filter), filter_data,
              tflite::micro::GetTensorShape(bias), bias_data,
              tflite::micro::GetTensorShape(output),
              tflite::micro::GetTensorData<int8_t>(output));
          SocProgress(0x5b310211u);
          break;
        }
        default:
          MicroPrintf("Filter type %s (%d) for input type %s not supported.",
                      TfLiteTypeGetName(filter->type), filter->type,
                      TfLiteTypeGetName(input->type));
          return kTfLiteError;
      }
      break;
    }
    case kTfLiteInt16: {
      switch (filter->type) {
        case kTfLiteInt8: {
          reference_integer_ops::DepthwiseConvPerChannel(
              DepthwiseConvParamsQuantized(params, data),
              data.per_channel_output_multiplier, data.per_channel_output_shift,
              tflite::micro::GetTensorShape(input),
              tflite::micro::GetTensorData<int16_t>(input),
              tflite::micro::GetTensorShape(filter),
#ifdef USE_TFLM_COMPRESSION
              tflite::micro::GetTensorData<int8_t>(micro_context, filter,
                                                   filter_comp_td,
                                                   data.weights_scratch_index),
              tflite::micro::GetTensorShape(bias),
              tflite::micro::GetOptionalTensorData<int64_t>(
                  micro_context, bias, bias_comp_td, data.bias_scratch_index),
#else   // USE_TFLM_COMPRESSION
              tflite::micro::GetTensorData<int8_t>(filter),
              tflite::micro::GetTensorShape(bias),
              tflite::micro::GetOptionalTensorData<int64_t>(bias),
#endif  // USE_TFLM_COMPRESSION
              tflite::micro::GetTensorShape(output),
              tflite::micro::GetTensorData<int16_t>(output));
          break;
        }
        default:
          MicroPrintf("Filter type %s (%d) for input type %s not supported.",
                      TfLiteTypeGetName(filter->type), filter->type,
                      TfLiteTypeGetName(input->type));
          return kTfLiteError;
      }
      break;
    }
    default:
      MicroPrintf("Input type %s (%d) not supported.",
                  TfLiteTypeGetName(input->type), input->type);
      return kTfLiteError;
  }
  SocProgress(0x5b3100ffu);
  return kTfLiteOk;
}

}  // namespace

TFLMRegistration Register_DEPTHWISE_CONV_2D() {
  return tflite::micro::RegisterOp(DepthwiseConvInit, DepthwiseConvPrepare,
                                   DepthwiseConvEval);
}

}  // namespace tflite
