#include <stdint.h>
#include <string.h>

#include "tensorflow/lite/core/c/common.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"

extern "C" void picosoc_uart_init(void);
extern "C" void picosoc_uart_put_i32(int32_t value);
extern "C" void picosoc_uart_put_u32(uint32_t value);
extern "C" void picosoc_uart_puts(const char* s);
extern "C" uint32_t soc_get_cycle(void);
extern "C" const unsigned char g_sensor_calibrator_20261016_model_data[];
extern "C" const unsigned char g_sensor_calibrator_20261016_model_data_end[];

namespace {

constexpr uintptr_t kSocStatusAddr = 0x20000000u;
constexpr uintptr_t kSocProgressAddr = 0x2000000cu;
constexpr int kTensorArenaBytes = (5 * 1024 * 1024) / 2;
constexpr int kOutputTolerance = 16;
constexpr int16_t kInput[15] = {
    19224, 28027, 0, 0, 0, 283, 0, 1019, 0, 0, 2294, 2294, 2294, 1638,
    19111};
constexpr int16_t kExpectedOutput[9] = {28799, 0, 0, 0, 74, 9, 1016, 0, 0};
alignas(16) uint8_t g_tensor_arena[kTensorArenaBytes];

void LogI32(const char* label, int32_t value) {
  picosoc_uart_puts(label);
  picosoc_uart_put_i32(value);
}

void LogU32(const char* label, uint32_t value) {
  picosoc_uart_puts(label);
  picosoc_uart_put_u32(value);
}

[[noreturn]] void HaltWithStatus(uint32_t status) {
  *reinterpret_cast<volatile uint32_t*>(kSocStatusAddr) = status;
  while (1) __asm__ volatile("nop" ::: "memory");
}

uint32_t Fail(uint32_t code, const char* message) {
  picosoc_uart_puts(message);
  picosoc_uart_puts("\n");
  return 0x9b000000u | code;
}

TfLiteStatus AddModelOps(tflite::MicroMutableOpResolver<16>* resolver) {
  if (resolver->AddAbs() != kTfLiteOk ||
      resolver->AddAdd() != kTfLiteOk ||
      resolver->AddConcatenation() != kTfLiteOk ||
      resolver->AddFill() != kTfLiteOk ||
      resolver->AddFullyConnected() != kTfLiteOk ||
      resolver->AddLogistic() != kTfLiteOk ||
      resolver->AddMaximum() != kTfLiteOk ||
      resolver->AddMinimum() != kTfLiteOk ||
      resolver->AddMul() != kTfLiteOk ||
      resolver->AddQuantize() != kTfLiteOk ||
      resolver->AddRelu() != kTfLiteOk ||
      resolver->AddReshape() != kTfLiteOk ||
      resolver->AddShape() != kTfLiteOk ||
      resolver->AddStridedSlice() != kTfLiteOk ||
      resolver->AddSub() != kTfLiteOk ||
      resolver->AddSum() != kTfLiteOk) {
    return kTfLiteError;
  }
  return kTfLiteOk;
}

uint32_t RunModel() {
  picosoc_uart_puts("[tflm] sensor_calibrator_20261016 start\n");
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = 0x5e610001u;
  tflite::InitializeTarget();

  const size_t model_bytes = static_cast<size_t>(
      g_sensor_calibrator_20261016_model_data_end -
      g_sensor_calibrator_20261016_model_data);
  const tflite::Model* model =
      tflite::GetModel(g_sensor_calibrator_20261016_model_data);
  if (model == nullptr || model->version() != TFLITE_SCHEMA_VERSION ||
      model_bytes < 8000000u) {
    return Fail(1, "[tflm] model/schema check failed");
  }
  picosoc_uart_puts("[tflm] model parsed bytes=");
  LogU32("", static_cast<uint32_t>(model_bytes));
  picosoc_uart_puts("\n");

  tflite::MicroMutableOpResolver<16> resolver;
  if (AddModelOps(&resolver) != kTfLiteOk) {
    return Fail(2, "[tflm] resolver setup failed");
  }
  tflite::MicroInterpreter interpreter(model, resolver, g_tensor_arena,
                                      sizeof(g_tensor_arena), nullptr, nullptr,
                                      true);
  picosoc_uart_puts("[tflm] AllocateTensors begin\n");
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    picosoc_uart_puts("[tflm] AllocateTensors failed arena_used=");
    LogU32("", static_cast<uint32_t>(interpreter.arena_used_bytes()));
    picosoc_uart_puts("\n");
    return 0x9b000300u;
  }
  picosoc_uart_puts("[tflm] AllocateTensors done arena_used=");
  LogU32("", static_cast<uint32_t>(interpreter.arena_used_bytes()));
  picosoc_uart_puts("\n");

  TfLiteTensor* input = interpreter.input(0);
  TfLiteTensor* output = interpreter.output(0);
  if (input == nullptr || output == nullptr || input->type != kTfLiteInt16 ||
      output->type != kTfLiteInt16 || input->bytes != sizeof(kInput) ||
      output->bytes != sizeof(kExpectedOutput)) {
    return Fail(4, "[tflm] input/output tensor contract mismatch");
  }
  memcpy(input->data.i16, kInput, sizeof(kInput));

  picosoc_uart_puts("[tflm] Invoke begin\n");
  const uint32_t start_cycle = soc_get_cycle();
  if (interpreter.Invoke() != kTfLiteOk) {
    return Fail(5, "[tflm] Invoke failed");
  }
  const uint32_t invoke_cycles = soc_get_cycle() - start_cycle;

  int max_abs_delta = 0;
  for (int i = 0; i < 9; ++i) {
    const int delta = static_cast<int>(output->data.i16[i]) -
                      static_cast<int>(kExpectedOutput[i]);
    const int abs_delta = delta < 0 ? -delta : delta;
    if (abs_delta > max_abs_delta) max_abs_delta = abs_delta;
  }
  picosoc_uart_puts("[tflm] output_q=");
  for (int i = 0; i < 9; ++i) {
    if (i != 0) picosoc_uart_puts(",");
    picosoc_uart_put_i32(output->data.i16[i]);
  }
  picosoc_uart_puts("\n");
  LogI32("[tflm] max_abs_delta=", max_abs_delta);
  LogU32(" invoke_cycles=", invoke_cycles);
  picosoc_uart_puts("\n");
  if (max_abs_delta > kOutputTolerance) {
    return Fail(6, "[tflm] output differs from expected quantized result");
  }
  picosoc_uart_puts("[tflm] sensor_calibrator_20261016 PASS\n");
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = 0x5e610003u;
  return 1;
}

}  // namespace

extern "C" int main(void) {
  picosoc_uart_init();
  HaltWithStatus(RunModel());
}
