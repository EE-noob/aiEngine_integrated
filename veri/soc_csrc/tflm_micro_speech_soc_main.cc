#include <stdint.h>
#include <stdio.h>

#include "tensorflow/lite/core/c/common.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/micro/examples/micro_speech/models/micro_speech_quantized_model_data.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"
#include "tflm_micro_speech_features.h"

extern "C" void picosoc_uart_init(void);
extern "C" uint32_t soc_get_cycle(void);

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
  const uint32_t invoke_start = soc_get_cycle();
  TfLiteStatus invoke_status = interpreter->Invoke();
  const uint32_t invoke_cycles = soc_get_cycle() - invoke_start;
  if (invoke_status != kTfLiteOk) {
    return -4;
  }
  WriteProgress(0x5b200002u);
  printf("[tflm_perf] micro_speech invoke_cycles=%u\n", invoke_cycles);

  const int8_t* scores = tflite::GetTensorData<int8_t>(output);
  int best = 0;
  for (int i = 1; i < kTflmMicroSpeechCategoryCount; ++i) {
    if (scores[i] > scores[best]) {
      best = i;
    }
  }
  return best;
}

uint32_t RunMicroSpeechInferenceTest() {
  printf("[tflm] micro_speech start\n");
  WriteProgress(0x5b100001u);
  tflite::InitializeTarget();

  const tflite::Model* model =
      tflite::GetModel(g_micro_speech_quantized_model_data);
  if (model->version() != TFLITE_SCHEMA_VERSION) {
    WriteProgress(0x5b10e001u);
    printf("[tflm] schema mismatch model=%d expected=%d\n", model->version(),
           TFLITE_SCHEMA_VERSION);
    return 0x94000001u;
  }
  WriteProgress(0x5b100002u);
  printf("[tflm] model ok\n");

  static tflite::MicroMutableOpResolver<4> resolver;
  if (RegisterMicroSpeechOps(resolver) != kTfLiteOk) {
    WriteProgress(0x5b10e002u);
    printf("[tflm] op registration failed\n");
    return 0x94000002u;
  }
  WriteProgress(0x5b100003u);

  static tflite::MicroInterpreter interpreter(model, resolver, g_tensor_arena,
                                              kTensorArenaSize);
  WriteProgress(0x5b100004u);
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    WriteProgress(0x5b10e003u);
    printf("[tflm] AllocateTensors failed\n");
    return 0x94000003u;
  }
  WriteProgress(0x5b100005u);
  printf("[tflm] tensors allocated arena=%d used=%u\n", kTensorArenaSize,
         static_cast<unsigned>(interpreter.arena_used_bytes()));

  int yes_result =
      RunInference(&interpreter, g_tflm_micro_speech_yes_features);
  WriteProgress(0x5b210000u | (yes_result & 0xff));
  printf("[tflm] yes result=%d expected=%d\n", yes_result,
         kTflmMicroSpeechYesIndex);
  if (yes_result != kTflmMicroSpeechYesIndex) {
    return EncodeMismatch(1, kTflmMicroSpeechYesIndex, yes_result);
  }

#if defined(TFLM_MICRO_SPEECH_FULL) && TFLM_MICRO_SPEECH_FULL
  int no_result = RunInference(&interpreter, g_tflm_micro_speech_no_features);
  WriteProgress(0x5b220000u | (no_result & 0xff));
  printf("[tflm] no result=%d expected=%d\n", no_result,
         kTflmMicroSpeechNoIndex);
  if (no_result != kTflmMicroSpeechNoIndex) {
    return EncodeMismatch(2, kTflmMicroSpeechNoIndex, no_result);
  }
#endif

  WriteProgress(0x5b100006u);
  printf("[tflm] micro_speech PASS\n");
  return 1;
}

}  // namespace

extern "C" int main(void) {
  picosoc_uart_init();
  return static_cast<int>(RunMicroSpeechInferenceTest());
}
