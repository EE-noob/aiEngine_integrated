#pragma once
#include <stdint.h>
#include <stddef.h>

struct SensorCalibrationReleaseTestCase {
  float sensor_inputs[10];
  float reference_v4_v;
  float package_tflite_baseline_v4_v;
  float package_tflite_candidate_v4_v;
  uint8_t pga_code;
  uint8_t source_file_id;
  uint32_t source_row;
};

#define SENSOR_CALIBRATION_RELEASE_HOST_SAMPLE_COUNT 6825
#define SENSOR_CALIBRATION_RELEASE_SOC_SAMPLE_COUNT 3
#define SENSOR_CALIBRATION_RELEASE_CELL_COUNT 980

extern const unsigned char g_sensor_calibration_release_base_model_data[];
extern const unsigned int g_sensor_calibration_release_base_model_data_len;
extern const unsigned char g_sensor_calibration_release_adapter_model_data[];
extern const unsigned int g_sensor_calibration_release_adapter_model_data_len;
extern const SensorCalibrationReleaseTestCase g_sensor_calibration_release_host_cases[SENSOR_CALIBRATION_RELEASE_HOST_SAMPLE_COUNT];
extern const SensorCalibrationReleaseTestCase g_sensor_calibration_release_soc_cases[SENSOR_CALIBRATION_RELEASE_SOC_SAMPLE_COUNT];
extern const int16_t g_sensor_calibration_release_cell_keys[SENSOR_CALIBRATION_RELEASE_CELL_COUNT][5];
extern const float g_sensor_calibration_release_input_mean[10];
extern const float g_sensor_calibration_release_input_std[10];
extern const int g_sensor_calibration_release_output_map[9];
extern const char* const g_sensor_calibration_release_source_files[2];
