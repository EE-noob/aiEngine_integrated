#include "my_model.h"

#include "model_settings.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_log.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"

#include <stdint.h>

// 包含生成的模型数据
#include "gen/my_model/models/justure_detect_model_data.h"

namespace my_model {

// 全局变量 - 与justure_detection保持一致的命名和结构
namespace {
const tflite::Model* model = nullptr;
tflite::MicroInterpreter* interpreter = nullptr;
TfLiteTensor* input = nullptr;
uint32_t last_invoke_cycles = 0;

// Tensor arena - 与justure_detection保持一致的大小和对齐
constexpr int kTensorArenaSize = TENSOR_ARENA_SIZE;
alignas(16) static uint8_t tensor_arena[kTensorArenaSize];

#if defined(TFLM_SOC_PROGRESS)
extern "C" uint32_t soc_get_cycle(void);

void SocProgress(uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(0x2000000cu) = value;
}

uint32_t ReadCycle() { return soc_get_cycle(); }
#else
void SocProgress(uint32_t value) { (void)value; }
uint32_t ReadCycle() { return 0; }
#endif
}  // namespace

// Setup函数 - 完全参考justure_detection的setup()实现
int Setup() {
  SocProgress(0x5a110001u);
  tflite::InitializeTarget();

  // 映射模型到可用数据结构 - 使用justure_detection模型
  SocProgress(0x5a110002u);
  model = tflite::GetModel(g_justure_detect_model_data);
  SocProgress(0x5a110003u);
  if (model->version() != TFLITE_SCHEMA_VERSION) {
#if !defined(TFLM_SOC_QUIET)
    MicroPrintf(
        "Model provided is schema version %d not equal "
        "to supported version %d.",
        model->version(), TFLITE_SCHEMA_VERSION);
#endif
    return -1;
  }

  // 2 注册算子（见第3步）
  SocProgress(0x5a110004u);
  static tflite::MicroMutableOpResolver<11> resolver;
  resolver.AddConv2D();
  resolver.AddDepthwiseConv2D();
  resolver.AddMean();
  resolver.AddAveragePool2D();
  resolver.AddFullyConnected(
      );  // 如果你实现了 INT8 FC
  resolver.AddSoftmax();
  resolver.AddReshape();
  resolver.AddQuantize();
  resolver.AddDequantize();
  resolver.AddAdd();

  // 3 创建解释器并分配 tensor
  SocProgress(0x5a110005u);
  static tflite::MicroInterpreter static_interpreter(
      model, resolver, tensor_arena, kTensorArenaSize);
  SocProgress(0x5a110006u);
  interpreter = &static_interpreter;
  SocProgress(0x5a110007u);
  TfLiteStatus allocate_status = interpreter->AllocateTensors();
  SocProgress(0x5a110100u | (allocate_status & 0xff));
  if (allocate_status != kTfLiteOk) {
#if !defined(TFLM_SOC_QUIET)
    MicroPrintf("AllocateTensors() failed");
#endif
    return -2;
  }

  // 获取模型输入的内存区域信息
  SocProgress(0x5a110008u);
  input = interpreter->input(0);

  // 检查输入张量的数据类型
  if (input->type != kTfLiteUInt8) {
#if !defined(TFLM_SOC_QUIET)
    MicroPrintf("Input tensor type is not uint8, got %d", input->type);
#endif
    return -3;
  }

  // 获取模型输出张量
  SocProgress(0x5a110009u);
  TfLiteTensor* output = interpreter->output(0);

  // 检查输出张量的数据类型
  if (output->type != kTfLiteUInt8) {
#if !defined(TFLM_SOC_QUIET)
    MicroPrintf("Output tensor type is not uint8, got %d", output->type);
#endif
    return -4;
  }

  return 0;
}

// RunInference函数重载 - 直接返回模型输出数据指针
uint8_t* RunInference(const uint8_t* image_data) {
  if (!interpreter || !input) {
#if !defined(TFLM_SOC_QUIET)
    MicroPrintf("Model not initialized");
#endif
    return nullptr;
  }

  // 检查输入数据
  if (!image_data) {
#if !defined(TFLM_SOC_QUIET)
    MicroPrintf("Image data is null");
#endif
    return nullptr;
  }

  // 将图像数据复制到输入张量
  SocProgress(0x5a210001u);
  memcpy(input->data.uint8, image_data, kMaxImageSize);

  // 运行模型推理
  SocProgress(0x5a210002u);
  const uint32_t invoke_start = ReadCycle();
  if (kTfLiteOk != interpreter->Invoke()) {
    last_invoke_cycles = ReadCycle() - invoke_start;
#if !defined(TFLM_SOC_QUIET)
    MicroPrintf("Invoke failed.");
#endif
    return nullptr;
  }
  last_invoke_cycles = ReadCycle() - invoke_start;

  SocProgress(0x5a210003u);
  TfLiteTensor* output = interpreter->output(0);

  // 直接返回模型输出数据指针
  return output->data.uint8;
}

// 辅助函数
TfLiteTensor* GetInputTensor() { return input; }

uint32_t LastInvokeCycles() { return last_invoke_cycles; }

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
