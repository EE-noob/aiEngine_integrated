#include <math.h>
#include <stdint.h>
#include <string.h>

#include "sensor_calibration_release_data.h"
#include "sensor_calibration_release_inference.h"
#include "tensorflow/lite/micro/system_setup.h"

extern "C" void picosoc_uart_init(void);
extern "C" void picosoc_uart_put_i32(int32_t value);
extern "C" void picosoc_uart_put_u32(uint32_t value);
extern "C" void picosoc_uart_puts(const char* s);
extern "C" uint32_t soc_get_cycle(void);

namespace {

constexpr uintptr_t kSocProgressAddr = 0x2000000cu;
constexpr uintptr_t kSocStatusAddr = 0x20000000u;
constexpr uint32_t kMaxAllowedPackageDeltaUv = 2500;
constexpr int kBaseArenaBytes = 44 * 1024;
constexpr int kAdapterArenaBytes = 12 * 1024;
alignas(16) uint8_t g_base_arena[kBaseArenaBytes];
alignas(16) uint8_t g_adapter_arena[kAdapterArenaBytes];

void WriteProgress(uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = value;
}

[[noreturn]] void HaltWithStatus(uint32_t status) {
  *reinterpret_cast<volatile uint32_t*>(kSocStatusAddr) = status;
  while (1) __asm__ volatile("nop" ::: "memory");
}

uint32_t EncodeError(uint32_t major, uint32_t detail) {
  return 0x9a000000u | ((major & 0xffu) << 8) | (detail & 0xffu);
}

void LogU32(const char* key, uint32_t value) {
  picosoc_uart_puts(key);
  picosoc_uart_put_u32(value);
}

void LogI32(const char* key, int32_t value) {
  picosoc_uart_puts(key);
  picosoc_uart_put_i32(value);
}

uint32_t RunRegression() {
  picosoc_uart_puts("[tflm] sensor_calibration_release_20261015 start\n");
  WriteProgress(0x5e400001u);
  tflite::InitializeTarget();
  const tflite::Model* base_model =
      tflite::GetModel(g_sensor_calibration_release_base_model_data);
  const tflite::Model* adapter_model =
      tflite::GetModel(g_sensor_calibration_release_adapter_model_data);
  if (base_model->version() != TFLITE_SCHEMA_VERSION ||
      adapter_model->version() != TFLITE_SCHEMA_VERSION) {
    return EncodeError(1, 0);
  }

  tflite::MicroMutableOpResolver<6> resolver;
  if (sensor_calibration_release::AddRequiredOps(&resolver) != kTfLiteOk) {
    return EncodeError(2, 0);
  }
  tflite::MicroInterpreter base_interpreter(
      base_model, resolver, g_base_arena, sizeof(g_base_arena), nullptr, nullptr,
      true);
  tflite::MicroInterpreter adapter_interpreter(
      adapter_model, resolver, g_adapter_arena, sizeof(g_adapter_arena), nullptr,
      nullptr, true);
  const TfLiteStatus base_allocate_status = base_interpreter.AllocateTensors();
  if (base_allocate_status != kTfLiteOk) {
    picosoc_uart_puts("[tflm] base AllocateTensors failed");
    LogU32(" arena_used=", base_interpreter.arena_used_bytes());
    picosoc_uart_puts("\n");
    return EncodeError(3, 1);
  }
  const TfLiteStatus adapter_allocate_status =
      adapter_interpreter.AllocateTensors();
  if (adapter_allocate_status != kTfLiteOk) {
    picosoc_uart_puts("[tflm] adapter AllocateTensors failed");
    LogU32(" base_arena=", base_interpreter.arena_used_bytes());
    LogU32(" adapter_arena_used=", adapter_interpreter.arena_used_bytes());
    picosoc_uart_puts("\n");
    return EncodeError(3, 2);
  }
  picosoc_uart_puts("[tflm] sensor release tensors allocated");
  LogU32(" base_arena=", base_interpreter.arena_used_bytes());
  LogU32(" adapter_arena=", adapter_interpreter.arena_used_bytes());
  picosoc_uart_puts("\n");

  uint32_t total_cycles = 0;
  uint32_t maximum_package_delta_uv = 0;
  uint32_t maximum_calibration_error_uv = 0;
  for (int sample = 0; sample < SENSOR_CALIBRATION_RELEASE_SOC_SAMPLE_COUNT;
       ++sample) {
    const SensorCalibrationReleaseTestCase& test_case =
        g_sensor_calibration_release_soc_cases[sample];
    float outputs[9] = {};
    float baseline_v4 = 0.0f;
    int16_t base_v4_q = 0;
    int16_t adapter_q = 0;
    WriteProgress(0x5e410000u | static_cast<uint32_t>(sample));
    const uint32_t start = soc_get_cycle();
    if (sensor_calibration_release::Predict(
            &base_interpreter, &adapter_interpreter, test_case.sensor_inputs,
            test_case.pga_code, outputs, &base_v4_q, &baseline_v4,
            &adapter_q) != kTfLiteOk) {
      picosoc_uart_puts("[tflm] sensor release Invoke failed");
      LogI32(" sample=", sample);
      picosoc_uart_puts("\n");
      return EncodeError(4, sample);
    }
    const uint32_t cycles = soc_get_cycle() - start;
    total_cycles += cycles;

    const int32_t actual_mv = static_cast<int32_t>(nearbyintf(outputs[4] * 1000.0f));
    const int32_t package_mv = static_cast<int32_t>(nearbyintf(
        test_case.package_tflite_candidate_v4_v * 1000.0f));
    const int32_t reference_mv = static_cast<int32_t>(nearbyintf(
        test_case.reference_v4_v * 1000.0f));
    const uint32_t package_delta_uv = static_cast<uint32_t>(
        nearbyintf(fabsf(outputs[4] - test_case.package_tflite_candidate_v4_v) *
                   1000000.0f));
    const uint32_t calibration_error_uv = static_cast<uint32_t>(
        nearbyintf(fabsf(outputs[4] - test_case.reference_v4_v) * 1000000.0f));
    if (package_delta_uv > maximum_package_delta_uv) {
      maximum_package_delta_uv = package_delta_uv;
    }
    if (calibration_error_uv > maximum_calibration_error_uv) {
      maximum_calibration_error_uv = calibration_error_uv;
    }

    picosoc_uart_puts("[tflm_perf] sensor_cal_release");
    LogI32(" sample=", sample);
    LogI32(" file=", test_case.source_file_id);
    LogU32(" source_row=", test_case.source_row);
    LogI32(" pga=", test_case.pga_code);
    LogI32(" base_v4_q=", base_v4_q);
    LogI32(" adapter_q=", adapter_q);
    LogI32(" baseline_v4_uv=",
           static_cast<int32_t>(nearbyintf(baseline_v4 * 1000000.0f)));
    LogI32(" actual_v4_uv=",
           static_cast<int32_t>(nearbyintf(outputs[4] * 1000000.0f)));
    LogI32(" baseline_v4_mv=",
           static_cast<int32_t>(nearbyintf(baseline_v4 * 1000.0f)));
    LogI32(" actual_v4_mv=", actual_mv);
    LogI32(" package_v4_mv=", package_mv);
    LogI32(" ref_v4_mv=", reference_mv);
    LogU32(" package_delta_uv=", package_delta_uv);
    LogU32(" invoke_cycles=", cycles);
    picosoc_uart_puts("\n");
    if (package_delta_uv > kMaxAllowedPackageDeltaUv) {
      picosoc_uart_puts("[tflm] sensor release differs from PC TFLite reference\n");
      return EncodeError(5, sample);
    }
  }

  picosoc_uart_puts("[tflm_perf] sensor_cal_release");
  LogU32(" samples=", SENSOR_CALIBRATION_RELEASE_SOC_SAMPLE_COUNT);
  LogU32(" avg_invoke_cycles=",
         total_cycles / SENSOR_CALIBRATION_RELEASE_SOC_SAMPLE_COUNT);
  LogU32(" max_package_delta_uv=", maximum_package_delta_uv);
  LogU32(" max_allowed_package_delta_uv=", kMaxAllowedPackageDeltaUv);
  LogU32(" max_calibration_error_uv=", maximum_calibration_error_uv);
  picosoc_uart_puts("\n[tflm] sensor_calibration_release_20261015 PASS\n");
  WriteProgress(0x5e400003u);
  return 1;
}

}  // namespace

extern "C" int main(void) {
  picosoc_uart_init();
  HaltWithStatus(RunRegression());
}
