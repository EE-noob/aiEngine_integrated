#include <stdint.h>
#include <string.h>

#include "sensor_calibration/sensor_calibration_model_data.h"
#include "sensor_calibration/sensor_calibration_test_data.h"
#include "tensorflow/lite/core/c/common.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"

extern "C" void picosoc_uart_init(void);
extern "C" void picosoc_uart_put_i32(int32_t value);
extern "C" void picosoc_uart_put_u32(uint32_t value);
extern "C" void picosoc_uart_puts(const char* s);
extern "C" uint32_t soc_get_cycle(void);

namespace {

constexpr uintptr_t kSocProgressAddr = 0x2000000cu;
constexpr uintptr_t kSocStatusAddr = 0x20000000u;

#ifndef TFLM_SENSOR_CALIBRATION_ARENA_SIZE
#define TFLM_SENSOR_CALIBRATION_ARENA_SIZE (16 * 1024)
#endif

alignas(16) uint8_t g_tensor_arena[TFLM_SENSOR_CALIBRATION_ARENA_SIZE];

void WriteProgress(uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = value;
}

[[noreturn]] void HaltWithStatus(uint32_t status) {
  *reinterpret_cast<volatile uint32_t*>(kSocStatusAddr) = status;
  while (1) {
    __asm__ volatile("nop" ::: "memory");
  }
}

uint32_t EncodeError(uint32_t major, uint32_t detail) {
  return 0x99000000u | ((major & 0xffu) << 8) | (detail & 0xffu);
}

void LogU32(const char* key, uint32_t value) {
  picosoc_uart_puts(key);
  picosoc_uart_put_u32(value);
}

void LogI32(const char* key, int32_t value) {
  picosoc_uart_puts(key);
  picosoc_uart_put_i32(value);
}

uint32_t RunSensorCalibrationTest() {
  picosoc_uart_puts("[tflm] sensor_calibration_int16x8 start\n");
  WriteProgress(0x5e300001u);
  tflite::InitializeTarget();

  const tflite::Model* model =
      tflite::GetModel(g_sensor_calibration_model_data);
  if (model->version() != TFLITE_SCHEMA_VERSION) {
    picosoc_uart_puts("[tflm] sensor calibration schema mismatch\n");
    return EncodeError(1, static_cast<uint32_t>(model->version()));
  }

  static tflite::MicroMutableOpResolver<2> resolver;
  if (resolver.AddFullyConnected() != kTfLiteOk ||
      resolver.AddAdd() != kTfLiteOk) {
    picosoc_uart_puts("[tflm] sensor calibration op registration failed\n");
    return EncodeError(2, 0);
  }

  static tflite::MicroInterpreter interpreter(
      model, resolver, g_tensor_arena, TFLM_SENSOR_CALIBRATION_ARENA_SIZE,
      nullptr, nullptr, true);
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    picosoc_uart_puts("[tflm] sensor calibration AllocateTensors failed\n");
    return EncodeError(3, 0);
  }
  WriteProgress(0x5e300002u);
  picosoc_uart_puts("[tflm] sensor calibration tensors allocated");
  LogU32(" arena=", TFLM_SENSOR_CALIBRATION_ARENA_SIZE);
  LogU32(" used=", static_cast<uint32_t>(interpreter.arena_used_bytes()));
  picosoc_uart_puts("\n");

  TfLiteTensor* input = interpreter.input(0);
  if (input == nullptr || input->type != kTfLiteInt16 ||
      input->bytes != kSensorCalibrationInputSize * sizeof(int16_t) ||
      interpreter.outputs_size() != kSensorCalibrationOutputCount) {
    picosoc_uart_puts("[tflm] sensor calibration tensor contract mismatch\n");
    return EncodeError(4, 0);
  }
  for (int output_index = 0; output_index < kSensorCalibrationOutputCount;
       ++output_index) {
    TfLiteTensor* output = interpreter.output(output_index);
    if (output == nullptr || output->type != kTfLiteInt16 ||
        output->bytes != sizeof(int16_t)) {
      return EncodeError(4, static_cast<uint32_t>(output_index + 1));
    }
  }

  uint32_t total_cycles = 0;
  uint32_t minimum_cycles = 0xffffffffu;
  uint32_t maximum_cycles = 0;
  for (int sample = 0; sample < kSensorCalibrationSampleCount; ++sample) {
    memcpy(tflite::GetTensorData<int16_t>(input),
           g_sensor_calibration_test_inputs[sample], input->bytes);
    WriteProgress(0x5e310000u | static_cast<uint32_t>(sample));
    const uint32_t start = soc_get_cycle();
    if (interpreter.Invoke() != kTfLiteOk) {
      picosoc_uart_puts("[tflm] sensor calibration Invoke failed");
      LogI32(" sample=", sample);
      picosoc_uart_puts("\n");
      return EncodeError(5, static_cast<uint32_t>(sample));
    }
    const uint32_t cycles = soc_get_cycle() - start;
    total_cycles += cycles;
    if (cycles < minimum_cycles) minimum_cycles = cycles;
    if (cycles > maximum_cycles) maximum_cycles = cycles;

    for (int fc = 0; fc < kSensorCalibrationFcCount; ++fc) {
      const TfLiteEvalTensor* tensor =
          interpreter.GetTensor(g_sensor_calibration_fc_tensor_indices[fc]);
      if (tensor == nullptr || tensor->type != kTfLiteInt16) {
        return EncodeError(6, static_cast<uint32_t>(fc));
      }
      const int16_t actual = tensor->data.i16[0];
      const int16_t expected =
          g_sensor_calibration_fc_golden_outputs[sample][fc];
      if (actual != expected) {
        picosoc_uart_puts("[tflm] sensor calibration FC mismatch");
        LogI32(" sample=", sample);
        LogI32(" fc=", fc);
        LogI32(" tensor=", g_sensor_calibration_fc_tensor_indices[fc]);
        LogI32(" got=", actual);
        LogI32(" expected=", expected);
        picosoc_uart_puts("\n");
        return EncodeError(6, (static_cast<uint32_t>(sample) << 4) |
                                  static_cast<uint32_t>(fc));
      }
    }

    picosoc_uart_puts("[tflm_perf] sensor_calibration");
    LogI32(" sample=", sample);
    LogU32(" source_row=", g_sensor_calibration_source_rows[sample]);
    for (int output_index = 0; output_index < kSensorCalibrationOutputCount;
         ++output_index) {
      const int16_t actual =
          tflite::GetTensorData<int16_t>(interpreter.output(output_index))[0];
      const int16_t expected =
          g_sensor_calibration_golden_outputs[sample][output_index];
      LogI32(" output=", actual);
      if (actual != expected) {
        picosoc_uart_puts("\n[tflm] sensor calibration output mismatch");
        LogI32(" sample=", sample);
        LogI32(" output_index=", output_index);
        LogI32(" got=", actual);
        LogI32(" expected=", expected);
        picosoc_uart_puts("\n");
        return EncodeError(7, (static_cast<uint32_t>(sample) << 4) |
                                  static_cast<uint32_t>(output_index));
      }
    }
    LogU32(" invoke_cycles=", cycles);
    picosoc_uart_puts("\n");
  }

  picosoc_uart_puts("[tflm_perf] sensor_calibration");
  LogU32(" total_invoke_cycles=", total_cycles);
  LogU32(" avg=", total_cycles / kSensorCalibrationSampleCount);
  LogU32(" min=", minimum_cycles);
  LogU32(" max=", maximum_cycles);
  picosoc_uart_puts("\n");
  picosoc_uart_puts("[tflm] sensor_calibration_int16x8 PASS\n");
  WriteProgress(0x5e300003u);
  return 1;
}

}  // namespace

extern "C" int main(void) {
  picosoc_uart_init();
  HaltWithStatus(RunSensorCalibrationTest());
}
