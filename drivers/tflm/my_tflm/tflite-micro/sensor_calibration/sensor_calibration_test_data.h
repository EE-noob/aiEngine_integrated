#ifndef SENSOR_CALIBRATION_TEST_DATA_H_
#define SENSOR_CALIBRATION_TEST_DATA_H_

#include <cstdint>

constexpr int kSensorCalibrationSampleCount = 3;
constexpr int kSensorCalibrationInputSize = 494;
constexpr int kSensorCalibrationOutputCount = 3;

constexpr int kSensorCalibrationFcCount = 6;

extern const int16_t g_sensor_calibration_test_inputs
    [kSensorCalibrationSampleCount][kSensorCalibrationInputSize];
extern const int16_t g_sensor_calibration_golden_outputs
    [kSensorCalibrationSampleCount][kSensorCalibrationOutputCount];
extern const uint32_t
    g_sensor_calibration_source_rows[kSensorCalibrationSampleCount];

extern const int32_t
    g_sensor_calibration_fc_tensor_indices[kSensorCalibrationFcCount];
extern const int16_t g_sensor_calibration_fc_golden_outputs
    [kSensorCalibrationSampleCount][kSensorCalibrationFcCount];

#endif  // SENSOR_CALIBRATION_TEST_DATA_H_
