#include <stdint.h>
#include <stdio.h>

#include "tensorflow/lite/core/c/common.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/micro/examples/hello_world/models/hello_world_int8_model_data.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"

extern "C" void picosoc_uart_init(void);
extern "C" uint32_t soc_get_cycle(void);

namespace {

constexpr uintptr_t kSocProgressAddr = 0x2000000cu;
constexpr int kTensorArenaSize = 3000;

alignas(16) uint8_t g_tensor_arena[kTensorArenaSize];

void WriteProgress(uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = value;
}

int AbsInt(int value) {
  return value < 0 ? -value : value;
}

uint32_t EncodeUnexpectedScore(int test_case, int score, int zero_point) {
  return 0x95000000u | ((test_case & 0xff) << 16) |
         (((score + 128) & 0xff) << 8) | ((zero_point + 128) & 0xff);
}

TfLiteStatus RegisterHelloWorldOps(
    tflite::MicroMutableOpResolver<1>& op_resolver) {
  TF_LITE_ENSURE_STATUS(op_resolver.AddFullyConnected());
  return kTfLiteOk;
}

int RunOne(tflite::MicroInterpreter* interpreter, int8_t input_value) {
  TfLiteTensor* input = interpreter->input(0);
  TfLiteTensor* output = interpreter->output(0);
  if (input == nullptr || output == nullptr) {
    return -129;
  }
  if (input->type != kTfLiteInt8 || output->type != kTfLiteInt8) {
    return -130;
  }

  tflite::GetTensorData<int8_t>(input)[0] = input_value;
  const uint32_t invoke_start = soc_get_cycle();
  TfLiteStatus invoke_status = interpreter->Invoke();
  const uint32_t invoke_cycles = soc_get_cycle() - invoke_start;
  if (invoke_status != kTfLiteOk) {
    return -131;
  }
  printf("[tflm_perf] hello_world invoke_cycles=%u\n", invoke_cycles);
  return tflite::GetTensorData<int8_t>(output)[0];
}

uint32_t RunHelloWorldInferenceTest() {
  printf("[tflm] hello_world start\n");
  WriteProgress(0x5c100001u);
  tflite::InitializeTarget();

  const tflite::Model* model = tflite::GetModel(g_hello_world_int8_model_data);
  if (model->version() != TFLITE_SCHEMA_VERSION) {
    WriteProgress(0x5c10e001u);
    printf("[tflm] schema mismatch model=%d expected=%d\n", model->version(),
           TFLITE_SCHEMA_VERSION);
    return 0x96000001u;
  }

  static tflite::MicroMutableOpResolver<1> resolver;
  if (RegisterHelloWorldOps(resolver) != kTfLiteOk) {
    WriteProgress(0x5c10e002u);
    printf("[tflm] op registration failed\n");
    return 0x96000002u;
  }

  static tflite::MicroInterpreter interpreter(model, resolver, g_tensor_arena,
                                              kTensorArenaSize);
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    WriteProgress(0x5c10e003u);
    printf("[tflm] AllocateTensors failed\n");
    return 0x96000003u;
  }
  WriteProgress(0x5c100002u);
  printf("[tflm] tensors allocated arena=%d\n", kTensorArenaSize);

  TfLiteTensor* output = interpreter.output(0);
  int zero_point = output->params.zero_point;

  int score_077 = RunOne(&interpreter, -96);
  WriteProgress(0x5c200000u | ((score_077 + 128) & 0xff));
  printf("[tflm] x=0.77 score=%d zero=%d\n", score_077, zero_point);
  if (score_077 < -128 || score_077 <= zero_point + 10) {
    return EncodeUnexpectedScore(1, score_077, zero_point);
  }

  int score_157 = RunOne(&interpreter, -63);
  WriteProgress(0x5c210000u | ((score_157 + 128) & 0xff));
  printf("[tflm] x=1.57 score=%d zero=%d\n", score_157, zero_point);
  if (score_157 < -128 || score_157 <= score_077) {
    return EncodeUnexpectedScore(2, score_157, zero_point);
  }

  int score_230 = RunOne(&interpreter, -34);
  WriteProgress(0x5c220000u | ((score_230 + 128) & 0xff));
  printf("[tflm] x=2.30 score=%d zero=%d\n", score_230, zero_point);
  if (score_230 < -128 || score_230 <= zero_point + 10 ||
      score_230 >= score_157) {
    return EncodeUnexpectedScore(3, score_230, zero_point);
  }

  int score_314 = RunOne(&interpreter, 0);
  WriteProgress(0x5c230000u | ((score_314 + 128) & 0xff));
  printf("[tflm] x=3.14 score=%d zero=%d\n", score_314, zero_point);
  if (score_314 < -128 || AbsInt(score_314 - zero_point) > 24) {
    return EncodeUnexpectedScore(4, score_314, zero_point);
  }

  WriteProgress(0x5c100003u);
  printf("[tflm] hello_world PASS\n");
  return 1;
}

}  // namespace

extern "C" int main(void) {
  picosoc_uart_init();
  return static_cast<int>(RunHelloWorldInferenceTest());
}
