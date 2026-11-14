#ifndef TFLM_SENSOR_CALIBRATION_20261019_GOLDEN_DATA_H_
#define TFLM_SENSOR_CALIBRATION_20261019_GOLDEN_DATA_H_

#include <stdint.h>

struct SensorCalibration20261019Case {
  float canonical_inputs[15];
  int16_t expected_outputs[3];  // humidity, voltage4, current2
};

extern const SensorCalibration20261019Case
    g_sensor_calibration_20261019_cases[];
extern const unsigned int g_sensor_calibration_20261019_case_count;

#endif  // TFLM_SENSOR_CALIBRATION_20261019_GOLDEN_DATA_H_
