#include <math.h>
#include <stdint.h>
#include <stdio.h>

#include "sensor_calibration_release_data.h"
#include "sensor_calibration_release_inference.h"
#include "tensorflow/lite/micro/system_setup.h"

namespace {

constexpr int kBaseArenaBytes = 96 * 1024;
constexpr int kAdapterArenaBytes = 16 * 1024;
alignas(16) uint8_t g_base_arena[kBaseArenaBytes];
alignas(16) uint8_t g_adapter_arena[kAdapterArenaBytes];

}  // namespace

int main() {
  tflite::InitializeTarget();
  const tflite::Model* base_model =
      tflite::GetModel(g_sensor_calibration_release_base_model_data);
  const tflite::Model* adapter_model =
      tflite::GetModel(g_sensor_calibration_release_adapter_model_data);
  if (base_model->version() != TFLITE_SCHEMA_VERSION ||
      adapter_model->version() != TFLITE_SCHEMA_VERSION) {
    fprintf(stderr, "TFLM schema version mismatch\n");
    return 2;
  }

  tflite::MicroMutableOpResolver<6> resolver;
  if (sensor_calibration_release::AddRequiredOps(&resolver) != kTfLiteOk) {
    fprintf(stderr, "TFLM sensor op registration failed\n");
    return 2;
  }
  tflite::MicroInterpreter base_interpreter(
      base_model, resolver, g_base_arena, sizeof(g_base_arena), nullptr, nullptr,
      true);
  tflite::MicroInterpreter adapter_interpreter(
      adapter_model, resolver, g_adapter_arena, sizeof(g_adapter_arena), nullptr,
      nullptr, true);
  if (base_interpreter.AllocateTensors() != kTfLiteOk ||
      adapter_interpreter.AllocateTensors() != kTfLiteOk) {
    fprintf(stderr, "TFLM sensor AllocateTensors failed\n");
    return 3;
  }

  double baseline_abs_sum_mv = 0.0;
  double candidate_abs_sum_mv = 0.0;
  double baseline_sq_sum_mv2 = 0.0;
  double candidate_sq_sum_mv2 = 0.0;
  double package_baseline_max_delta_mv = 0.0;
  double package_candidate_max_delta_mv = 0.0;
  double candidate_max_error_mv = 0.0;
  int candidate_within_5mv = 0;

  for (int sample = 0;
       sample < SENSOR_CALIBRATION_RELEASE_HOST_SAMPLE_COUNT; ++sample) {
    const SensorCalibrationReleaseTestCase& test_case =
        g_sensor_calibration_release_host_cases[sample];
    float outputs[9] = {};
    float baseline_v4 = 0.0f;
    if (sensor_calibration_release::Predict(
            &base_interpreter, &adapter_interpreter, test_case.sensor_inputs,
            test_case.pga_code, outputs, nullptr, &baseline_v4, nullptr) !=
        kTfLiteOk) {
      fprintf(stderr, "TFLM sensor Invoke failed at sample %d\n", sample);
      return 4;
    }

    const double baseline_error_mv =
        (static_cast<double>(baseline_v4) - test_case.reference_v4_v) * 1000.0;
    const double candidate_delta_mv =
        (static_cast<double>(outputs[4]) - test_case.reference_v4_v) * 1000.0;
    const double baseline_package_delta_mv =
        std::abs((static_cast<double>(baseline_v4) -
                  test_case.package_tflite_baseline_v4_v) *
                 1000.0);
    const double candidate_package_delta_mv =
        std::abs((static_cast<double>(outputs[4]) -
                  test_case.package_tflite_candidate_v4_v) *
                 1000.0);
    baseline_abs_sum_mv += std::abs(baseline_error_mv);
    baseline_sq_sum_mv2 += baseline_error_mv * baseline_error_mv;
    candidate_abs_sum_mv += std::abs(candidate_delta_mv);
    candidate_sq_sum_mv2 += candidate_delta_mv * candidate_delta_mv;
    if (std::abs(candidate_delta_mv) <= 5.0) ++candidate_within_5mv;
    if (std::abs(candidate_delta_mv) > candidate_max_error_mv) {
      candidate_max_error_mv = std::abs(candidate_delta_mv);
    }
    if (baseline_package_delta_mv > package_baseline_max_delta_mv) {
      package_baseline_max_delta_mv = baseline_package_delta_mv;
    }
    if (candidate_package_delta_mv > package_candidate_max_delta_mv) {
      package_candidate_max_delta_mv = candidate_package_delta_mv;
    }
    for (int selected = 0;
         selected < SENSOR_CALIBRATION_RELEASE_SOC_SAMPLE_COUNT; ++selected) {
      const SensorCalibrationReleaseTestCase& soc_case =
          g_sensor_calibration_release_soc_cases[selected];
      if (soc_case.source_file_id == test_case.source_file_id &&
          soc_case.source_row == test_case.source_row) {
        printf("[tflm_host_case] sample=%d file=%u source_row=%u "
               "reference_v4_uv=%d baseline_v4_uv=%d candidate_v4_uv=%d "
               "package_candidate_v4_uv=%d candidate_delta_uv=%d\n",
               selected, static_cast<unsigned>(test_case.source_file_id),
               test_case.source_row,
               static_cast<int>(nearbyint(test_case.reference_v4_v * 1000000.0)),
               static_cast<int>(nearbyint(baseline_v4 * 1000000.0)),
               static_cast<int>(nearbyint(outputs[4] * 1000000.0f)),
               static_cast<int>(nearbyint(
                   test_case.package_tflite_candidate_v4_v * 1000000.0)),
               static_cast<int>(nearbyint(candidate_package_delta_mv * 1000.0)));
      }
    }
  }

  const double sample_count = SENSOR_CALIBRATION_RELEASE_HOST_SAMPLE_COUNT;
  printf("[tflm_host] sensor_calibration_release samples=%d arena_base=%u arena_adapter=%u\n",
         SENSOR_CALIBRATION_RELEASE_HOST_SAMPLE_COUNT,
         static_cast<unsigned>(base_interpreter.arena_used_bytes()),
         static_cast<unsigned>(adapter_interpreter.arena_used_bytes()));
  printf("[tflm_host_accuracy] baseline_tflm_mae_mv=%.6f baseline_tflm_rmse_mv=%.6f "
         "candidate_tflm_mae_mv=%.6f "
         "candidate_tflm_rmse_mv=%.6f candidate_within_5mv_pct=%.4f "
         "candidate_max_abs_error_mv=%.6f package_baseline_max_delta_mv=%.6f "
         "package_candidate_max_delta_mv=%.6f\n",
         baseline_abs_sum_mv / sample_count,
         sqrt(baseline_sq_sum_mv2 / sample_count),
         candidate_abs_sum_mv / sample_count,
         sqrt(candidate_sq_sum_mv2 / sample_count),
         100.0 * candidate_within_5mv / sample_count,
         candidate_max_error_mv,
         package_baseline_max_delta_mv,
         package_candidate_max_delta_mv);
  printf("[tflm_host] sensor_calibration_release PASS\n");
  return 0;
}
