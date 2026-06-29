#include <cstdint>
#include <cstdio>

#include "tensorflow/lite/micro/examples/micro_speech/models/micro_speech_quantized_model_data.h"
#include "tensorflow/lite/schema/schema_generated.h"

namespace {

const char* TensorTypeName(tflite::TensorType type) {
  switch (type) {
    case tflite::TensorType_FLOAT32:
      return "float32";
    case tflite::TensorType_INT32:
      return "int32";
    case tflite::TensorType_UINT8:
      return "uint8";
    case tflite::TensorType_INT64:
      return "int64";
    case tflite::TensorType_STRING:
      return "string";
    case tflite::TensorType_BOOL:
      return "bool";
    case tflite::TensorType_INT16:
      return "int16";
    case tflite::TensorType_COMPLEX64:
      return "complex64";
    case tflite::TensorType_INT8:
      return "int8";
    default:
      return "unknown";
  }
}

const char* BuiltinName(tflite::BuiltinOperator op) {
  switch (op) {
    case tflite::BuiltinOperator_RESHAPE:
      return "RESHAPE";
    case tflite::BuiltinOperator_DEPTHWISE_CONV_2D:
      return "DEPTHWISE_CONV_2D";
    case tflite::BuiltinOperator_FULLY_CONNECTED:
      return "FULLY_CONNECTED";
    case tflite::BuiltinOperator_SOFTMAX:
      return "SOFTMAX";
    default:
      return "OTHER";
  }
}

void PrintTensorBrief(const tflite::SubGraph* subgraph, int tensor_index) {
  const auto* tensor = subgraph->tensors()->Get(tensor_index);
  std::printf("    t%d %-12s shape=[", tensor_index,
              TensorTypeName(tensor->type()));
  const auto* shape = tensor->shape();
  if (shape != nullptr) {
    for (uint32_t i = 0; i < shape->size(); ++i) {
      if (i != 0) {
        std::printf(",");
      }
      std::printf("%d", shape->Get(i));
    }
  }
  std::printf("]");
  if (tensor->name() != nullptr) {
    std::printf(" name=%s", tensor->name()->c_str());
  }
  std::printf("\n");
}

void PrintTensorList(const tflite::SubGraph* subgraph, const char* label,
                     const flatbuffers::Vector<int32_t>* tensors) {
  std::printf("  %s:", label);
  for (uint32_t i = 0; i < tensors->size(); ++i) {
    std::printf(" t%d", tensors->Get(i));
  }
  std::printf("\n");
  for (uint32_t i = 0; i < tensors->size(); ++i) {
    PrintTensorBrief(subgraph, tensors->Get(i));
  }
}

}  // namespace

int main() {
  const tflite::Model* model =
      tflite::GetModel(g_micro_speech_quantized_model_data);
  std::printf("schema_version=%d\n", model->version());

  const tflite::SubGraph* subgraph = model->subgraphs()->Get(0);
  const auto* opcodes = model->operator_codes();
  const auto* operators = subgraph->operators();
  std::printf("operators=%u tensors=%u\n", operators->size(),
              subgraph->tensors()->size());

  for (uint32_t op_index = 0; op_index < operators->size(); ++op_index) {
    const tflite::Operator* op = operators->Get(op_index);
    const tflite::OperatorCode* opcode = opcodes->Get(op->opcode_index());
    const auto builtin = opcode->builtin_code();
    std::printf("op%u %s(%d)\n", op_index, BuiltinName(builtin), builtin);
    PrintTensorList(subgraph, "inputs", op->inputs());
    PrintTensorList(subgraph, "outputs", op->outputs());

    if (builtin == tflite::BuiltinOperator_DEPTHWISE_CONV_2D) {
      const auto* options = op->builtin_options_as_DepthwiseConv2DOptions();
      if (options != nullptr) {
        std::printf(
            "  depthwise: padding=%d stride=(%d,%d) dilation=(%d,%d) "
            "depth_multiplier=%d activation=%d\n",
            options->padding(), options->stride_h(), options->stride_w(),
            options->dilation_h_factor(), options->dilation_w_factor(),
            options->depth_multiplier(), options->fused_activation_function());
      }
    } else if (builtin == tflite::BuiltinOperator_FULLY_CONNECTED) {
      const auto* options = op->builtin_options_as_FullyConnectedOptions();
      if (options != nullptr) {
        std::printf("  fully_connected: activation=%d keep_num_dims=%d\n",
                    options->fused_activation_function(),
                    options->keep_num_dims());
      }
    }
  }

  return 0;
}
