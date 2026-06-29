#include "my_model.h"
#include "model_settings.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_log.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"

// 包含生成的模型数据
#include "tensorflow/lite/micro/models/person_detect_model_data.h"

// 包含生成的测试数据
#include "tensorflow/lite/micro/examples/person_detection/testdata/no_person_image_data.h"
#include "tensorflow/lite/micro/examples/person_detection/testdata/person_image_data.h"

namespace my_model {

// 全局变量 - 与person_detection保持一致的命名和结构
namespace {
const tflite::Model* model = nullptr;
tflite::MicroInterpreter* interpreter = nullptr;
TfLiteTensor* input = nullptr;

// Tensor arena - 与person_detection保持一致的大小和对齐
constexpr int kTensorArenaSize = TENSOR_ARENA_SIZE;
alignas(16) static uint8_t tensor_arena[kTensorArenaSize];
}  // namespace

// Setup函数 - 完全参考person_detection的setup()实现
int Setup() {
  tflite::InitializeTarget();

  // 映射模型到可用数据结构 - 使用person_detection模型
  model = tflite::GetModel(g_person_detect_model_data);
  if (model->version() != TFLITE_SCHEMA_VERSION) {
    MicroPrintf(
        "Model provided is schema version %d not equal "
        "to supported version %d.",
        model->version(), TFLITE_SCHEMA_VERSION);
    return -1;
  }

  // 只包含需要的操作实现 - 与person_detection完全一致
  static tflite::MicroMutableOpResolver<5> micro_op_resolver;
  micro_op_resolver.AddAveragePool2D(tflite::Register_AVERAGE_POOL_2D_INT8());
  micro_op_resolver.AddConv2D(tflite::Register_CONV_2D_INT8());
  micro_op_resolver.AddDepthwiseConv2D(
      tflite::Register_DEPTHWISE_CONV_2D_INT8());
  micro_op_resolver.AddReshape();
  micro_op_resolver.AddSoftmax(tflite::Register_SOFTMAX_INT8());

  // 构建解释器
  static tflite::MicroInterpreter static_interpreter(
      model, micro_op_resolver, tensor_arena, kTensorArenaSize);
  interpreter = &static_interpreter;

  // 从tensor_arena为模型的张量分配内存
  TfLiteStatus allocate_status = interpreter->AllocateTensors();
  if (allocate_status != kTfLiteOk) {
    MicroPrintf("AllocateTensors() failed");
    return -2;
  }

  // 获取模型输入的内存区域信息
  input = interpreter->input(0);
  
  return 0;
}

// RunInference函数重载 - 直接返回模型输出数据指针
uint8_t* RunInference(const int8_t* image_data) {
  if (!interpreter || !input) {
    MicroPrintf("Model not initialized");
    return nullptr;
  }

  // 检查输入数据
  if (!image_data) {
    MicroPrintf("Image data is null");
    return nullptr;
  }

  // 将图像数据复制到输入张量
  for (int i = 0; i < kMaxImageSize; ++i) {
    input->data.int8[i] = image_data[i];
  }

  // 运行模型推理
  if (kTfLiteOk != interpreter->Invoke()) {
    MicroPrintf("Invoke failed.");
    return nullptr;
  }

  TfLiteTensor* output = interpreter->output(0);

  // 直接返回模型输出数据指针
  return output->data.uint8;
}

// 辅助函数
TfLiteTensor* GetInputTensor() {
  return input;
}

TfLiteTensor* GetOutputTensor() {
  if (!interpreter) {
    return nullptr;
  }
  return interpreter->output(0);
}

void Cleanup() {
  // 在嵌入式系统中，通常不需要显式清理
  // 但可以在这里重置全局变量
  interpreter = nullptr;
  input = nullptr;
  model = nullptr;
}

}  // namespace my_model