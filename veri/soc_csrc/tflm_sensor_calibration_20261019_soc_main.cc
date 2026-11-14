#include <math.h>
#include <stdint.h>
#include <string.h>

#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"
#include "tflm_sensor_calibration_20261019_golden_data.h"

extern "C" void picosoc_uart_init(void);
extern "C" void picosoc_uart_put_i32(int32_t value);
extern "C" void picosoc_uart_put_u32(uint32_t value);
extern "C" void picosoc_uart_puts(const char* s);

extern const unsigned char g_sensor_calibration_20261019_model_data[];
extern const unsigned char g_sensor_calibration_20261019_model_data_end[];

namespace {

constexpr uintptr_t kSocStatusAddr = 0x20000000u;
constexpr uintptr_t kSocProgressAddr = 0x2000000cu;
constexpr int kTensorArenaBytes = TFLM_SENSOR_CALIBRATION_20261019_ARENA_SIZE;
constexpr int kMaxOutputDelta = 8;
alignas(16) uint8_t g_tensor_arena[kTensorArenaBytes];
uint32_t g_run_failure_stage = 0;

void LogU32(const char* label, uint32_t value) {
  picosoc_uart_puts(label);
  picosoc_uart_put_u32(value);
}

void LogI32(const char* label, int32_t value) {
  picosoc_uart_puts(label);
  picosoc_uart_put_i32(value);
}

uint32_t Fail(uint32_t status, const char* message) {
  picosoc_uart_puts(message);
  picosoc_uart_puts("\n");
  return status;
}

int16_t Quantize(float value, const TfLiteTensor* tensor) {
  const float q = nearbyintf(value / tensor->params.scale +
                             tensor->params.zero_point);
  if (q < -32768.0f) return -32768;
  if (q > 32767.0f) return 32767;
  return static_cast<int16_t>(q);
}

TfLiteStatus RegisterOps(tflite::MicroMutableOpResolver<16>* resolver) {
  return resolver->AddAbs() == kTfLiteOk &&
                 resolver->AddAdd() == kTfLiteOk &&
                 resolver->AddConcatenation() == kTfLiteOk &&
                 resolver->AddFill() == kTfLiteOk &&
                 resolver->AddFullyConnected() == kTfLiteOk &&
                 resolver->AddLogistic() == kTfLiteOk &&
                 resolver->AddMaximum() == kTfLiteOk &&
                 resolver->AddMinimum() == kTfLiteOk &&
                 resolver->AddMul() == kTfLiteOk &&
                 resolver->AddQuantize() == kTfLiteOk &&
                 resolver->AddRelu() == kTfLiteOk &&
                 resolver->AddShape() == kTfLiteOk &&
                 resolver->AddStridedSlice() == kTfLiteOk &&
                 resolver->AddSub() == kTfLiteOk &&
                 resolver->AddSum() == kTfLiteOk
             ? kTfLiteOk
             : kTfLiteError;
}

TfLiteTensor* FindInputByWidth(tflite::MicroInterpreter* interpreter,
                               int width) {
  for (int i = 0; i < interpreter->inputs_size(); ++i) {
    TfLiteTensor* tensor = interpreter->input(i);
    if (tensor != nullptr && tensor->dims != nullptr &&
        tensor->dims->size == 2 && tensor->dims->data[1] == width) {
      return tensor;
    }
  }
  return nullptr;
}

TfLiteStatus RunOne(tflite::MicroInterpreter* interpreter,
                    const SensorCalibration20261019Case& test_case,
                    int16_t actual[3]) {
  g_run_failure_stage = 1;
  const float* raw = test_case.canonical_inputs;
  const float voltage4[5] = {
      (raw[0] - 40.0f) / 40.0f,
      (raw[1] - 60.0f) / 50.0f,
      raw[5] / 40.0f,
      raw[13] / 7.0f,
      (raw[14] - 40.0f) / 40.0f,
  };
  const float current2[3] = {raw[0], raw[1], raw[7]};
  const float humidity[2] = {raw[0], raw[1]};
  TfLiteTensor* input_v = FindInputByWidth(interpreter, 5);
  TfLiteTensor* input_i = FindInputByWidth(interpreter, 3);
  TfLiteTensor* input_h = FindInputByWidth(interpreter, 2);
  if (input_v == nullptr || input_i == nullptr || input_h == nullptr ||
      input_v->type != kTfLiteInt16 || input_i->type != kTfLiteInt16 ||
      input_h->type != kTfLiteInt16 || input_v->bytes != 5 * sizeof(int16_t) ||
      input_i->bytes != 3 * sizeof(int16_t) ||
      input_h->bytes != 2 * sizeof(int16_t)) {
    return kTfLiteError;
  }
  int16_t* qv = tflite::GetTensorData<int16_t>(input_v);
  int16_t* qi = tflite::GetTensorData<int16_t>(input_i);
  int16_t* qh = tflite::GetTensorData<int16_t>(input_h);
  for (int i = 0; i < 5; ++i) qv[i] = Quantize(voltage4[i], input_v);
  for (int i = 0; i < 3; ++i) qi[i] = Quantize(current2[i], input_i);
  for (int i = 0; i < 2; ++i) qh[i] = Quantize(humidity[i], input_h);
  g_run_failure_stage = 2;
  if (interpreter->Invoke() != kTfLiteOk) return kTfLiteError;

  // The pinned release's signature output order is voltage4, humidity,
  // current2 (tensor names end in :1, :0, :2 respectively).
  TfLiteTensor* out_v = interpreter->output(0);
  TfLiteTensor* out_h = interpreter->output(1);
  TfLiteTensor* out_i = interpreter->output(2);
  g_run_failure_stage = 3;
  if (out_h == nullptr || out_v == nullptr || out_i == nullptr ||
      out_h->type != kTfLiteInt16 || out_v->type != kTfLiteInt16 ||
      out_i->type != kTfLiteInt16) {
    return kTfLiteError;
  }
  actual[0] = tflite::GetTensorData<int16_t>(out_h)[0];
  actual[1] = tflite::GetTensorData<int16_t>(out_v)[0];
  actual[2] = tflite::GetTensorData<int16_t>(out_i)[0];
  return kTfLiteOk;
}

uint32_t RunRegression() {
  picosoc_uart_puts("[tflm] sensor_calibration_20261019 start\n");
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = 0x5e190001u;
  tflite::InitializeTarget();
  const size_t model_bytes = static_cast<size_t>(
      g_sensor_calibration_20261019_model_data_end -
      g_sensor_calibration_20261019_model_data);
  const tflite::Model* model =
      tflite::GetModel(g_sensor_calibration_20261019_model_data);
  if (model == nullptr || model->version() != TFLITE_SCHEMA_VERSION ||
      model_bytes != 1354592u) {
    return Fail(0x9b001001u, "[tflm] model/schema/size check failed");
  }
  tflite::MicroMutableOpResolver<16> resolver;
  if (RegisterOps(&resolver) != kTfLiteOk) {
    return Fail(0x9b001002u, "[tflm] resolver setup failed");
  }
  tflite::MicroInterpreter interpreter(model, resolver, g_tensor_arena,
                                       sizeof(g_tensor_arena), nullptr, nullptr,
                                       true);
  picosoc_uart_puts("[tflm] AllocateTensors begin\n");
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    picosoc_uart_puts("[tflm] AllocateTensors failed arena_used=");
    picosoc_uart_put_u32(interpreter.arena_used_bytes());
    picosoc_uart_puts("\n");
    return 0x9b001003u;
  }
  picosoc_uart_puts("[tflm] AllocateTensors done arena_used=");
  picosoc_uart_put_u32(interpreter.arena_used_bytes());
  picosoc_uart_puts("\n");

  int max_delta[3] = {0, 0, 0};
  for (unsigned int sample = 0;
       sample < g_sensor_calibration_20261019_case_count; ++sample) {
    int16_t actual[3] = {};
    if (RunOne(&interpreter, g_sensor_calibration_20261019_cases[sample],
               actual) != kTfLiteOk) {
      picosoc_uart_puts("[tflm] Invoke/input/output failure sample=");
      picosoc_uart_put_u32(sample);
      LogU32(" stage=", g_run_failure_stage);
      picosoc_uart_puts("\n");
      return 0x9b001004u | (sample & 0xffu);
    }
    const int16_t* expected =
        g_sensor_calibration_20261019_cases[sample].expected_outputs;
    int delta[3];
    for (int output = 0; output < 3; ++output) {
      delta[output] = actual[output] - expected[output];
      if (delta[output] < 0) delta[output] = -delta[output];
      if (delta[output] > max_delta[output]) max_delta[output] = delta[output];
    }
    picosoc_uart_puts("[tflm_golden] sample=");
    picosoc_uart_put_u32(sample);
    LogI32(" humidity_q=", actual[0]);
    LogI32(" voltage4_q=", actual[1]);
    LogI32(" current2_q=", actual[2]);
    LogI32(" max_delta_hvi=", delta[0] > delta[1]
                                   ? (delta[0] > delta[2] ? delta[0] : delta[2])
                                   : (delta[1] > delta[2] ? delta[1] : delta[2]));
    picosoc_uart_puts("\n");
    if (delta[0] > kMaxOutputDelta || delta[1] > kMaxOutputDelta ||
        delta[2] > kMaxOutputDelta) {
      return 0x9b001100u | (sample & 0xffu);
    }
  }
  picosoc_uart_puts("[tflm_golden] max_delta_hvi=");
  picosoc_uart_put_u32(max_delta[0]);
  picosoc_uart_puts(",");
  picosoc_uart_put_u32(max_delta[1]);
  picosoc_uart_puts(",");
  picosoc_uart_put_u32(max_delta[2]);
  picosoc_uart_puts(" tolerance=8 LSB\n");
  picosoc_uart_puts("[tflm] sensor_calibration_20261019 PASS\n");
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = 0x5e190003u;
  return 1;
}

}  // namespace

extern "C" int main(void) {
  picosoc_uart_init();
  const uint32_t status = RunRegression();
  *reinterpret_cast<volatile uint32_t*>(kSocStatusAddr) = status;
  while (1) __asm__ volatile("nop" ::: "memory");
}
