#include <stdint.h>

#include "tensorflow/lite/core/c/common.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/micro/examples/micro_speech/models/micro_speech_quantized_model_data.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"
#include "tflm_micro_speech_features.h"

namespace {

constexpr uintptr_t kSocProgressAddr = 0x2000000cu;
constexpr int kTensorArenaSize = 28584;

alignas(16) uint8_t g_tensor_arena[kTensorArenaSize];

void WriteProgress(uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = value;
}

uint32_t EncodeMismatch(int test_case, int expected, int observed) {
  return 0x93000000u | ((test_case & 0xff) << 16) |
         ((expected & 0xff) << 8) | (observed & 0xff);
}

TfLiteStatus RegisterMicroSpeechOps(
    tflite::MicroMutableOpResolver<4>& op_resolver) {
  TF_LITE_ENSURE_STATUS(op_resolver.AddReshape());
  TF_LITE_ENSURE_STATUS(op_resolver.AddFullyConnected());
  TF_LITE_ENSURE_STATUS(op_resolver.AddDepthwiseConv2D());
  TF_LITE_ENSURE_STATUS(op_resolver.AddSoftmax());
  return kTfLiteOk;
}

int RunInference(tflite::MicroInterpreter* interpreter,
                 const int8_t* features) {
  TfLiteTensor* input = interpreter->input(0);
  TfLiteTensor* output = interpreter->output(0);
  if (input == nullptr || output == nullptr) {
    return -1;
  }
  if (input->type != kTfLiteInt8 || output->type != kTfLiteInt8) {
    return -2;
  }
  if (input->dims->data[input->dims->size - 1] !=
          kTflmMicroSpeechFeatureCount ||
      output->dims->data[output->dims->size - 1] !=
          kTflmMicroSpeechCategoryCount) {
    return -3;
  }

  int8_t* input_data = tflite::GetTensorData<int8_t>(input);
  for (int i = 0; i < kTflmMicroSpeechFeatureCount; ++i) {
    input_data[i] = features[i];
  }

  WriteProgress(0x5b200001u);
  if (interpreter->Invoke() != kTfLiteOk) {
    return -4;
  }
  WriteProgress(0x5b200002u);

  const int8_t* scores = tflite::GetTensorData<int8_t>(output);
  int best = 0;
  for (int i = 1; i < kTflmMicroSpeechCategoryCount; ++i) {
    if (scores[i] > scores[best]) {
      best = i;
    }
  }
  return best;
}

}  // namespace

extern "C" int main(void) {
  WriteProgress(0x5b100001u);
  tflite::InitializeTarget();

  const tflite::Model* model =
      tflite::GetModel(g_micro_speech_quantized_model_data);
  if (model->version() != TFLITE_SCHEMA_VERSION) {
    WriteProgress(0x5b10e001u);
    return 0x94000001u;
  }
  WriteProgress(0x5b100002u);

  static tflite::MicroMutableOpResolver<4> resolver;
  if (RegisterMicroSpeechOps(resolver) != kTfLiteOk) {
    WriteProgress(0x5b10e002u);
    return 0x94000002u;
  }
  WriteProgress(0x5b100003u);

  static tflite::MicroInterpreter interpreter(model, resolver, g_tensor_arena,
                                              kTensorArenaSize);
  WriteProgress(0x5b100004u);
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    WriteProgress(0x5b10e003u);
    return 0x94000003u;
  }
  WriteProgress(0x5b100005u);

  int yes_result =
      RunInference(&interpreter, g_tflm_micro_speech_yes_features);
  WriteProgress(0x5b210000u | (yes_result & 0xff));
  if (yes_result != kTflmMicroSpeechYesIndex) {
    return EncodeMismatch(1, kTflmMicroSpeechYesIndex, yes_result);
  }

#if defined(TFLM_MICRO_SPEECH_FULL) && TFLM_MICRO_SPEECH_FULL
  int no_result = RunInference(&interpreter, g_tflm_micro_speech_no_features);
  WriteProgress(0x5b220000u | (no_result & 0xff));
  if (no_result != kTflmMicroSpeechNoIndex) {
    return EncodeMismatch(2, kTflmMicroSpeechNoIndex, no_result);
  }
#endif

  WriteProgress(0x5b100006u);
  return 1;
}
