#ifndef SENSOR_CALIBRATION_RELEASE_INFERENCE_H_
#define SENSOR_CALIBRATION_RELEASE_INFERENCE_H_

#include <math.h>
#include <stdint.h>
#include <string.h>

#include "sensor_calibration_release_data.h"
#include "tensorflow/lite/core/c/common.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/schema/schema_generated.h"

namespace sensor_calibration_release {

inline TfLiteStatus AddRequiredOps(tflite::MicroMutableOpResolver<6>* resolver) {
  if (resolver->AddFullyConnected() != kTfLiteOk ||
      resolver->AddAdd() != kTfLiteOk ||
      resolver->AddConcatenation() != kTfLiteOk ||
      resolver->AddMul() != kTfLiteOk ||
      resolver->AddLogistic() != kTfLiteOk ||
      resolver->AddQuantize() != kTfLiteOk) {
    return kTfLiteError;
  }
  return kTfLiteOk;
}

inline int16_t QuantizeInt16(float value, float scale, int zero_point) {
  const float quantized = nearbyintf(value / scale + zero_point);
  if (quantized < -32768.0f) return static_cast<int16_t>(-32768);
  if (quantized > 32767.0f) return static_cast<int16_t>(32767);
  return static_cast<int16_t>(quantized);
}

inline TfLiteStatus Predict(tflite::MicroInterpreter* base_interpreter,
                            tflite::MicroInterpreter* adapter_interpreter,
                            const float sensor_inputs[10], uint8_t pga_code,
                            float calibrated_outputs[9],
                            int16_t* base_v4_quantized,
                            float* base_v4_float,
                            int16_t* adapter_quantized) {
  if (base_interpreter == nullptr || adapter_interpreter == nullptr ||
      sensor_inputs == nullptr || calibrated_outputs == nullptr || pga_code > 7) {
    return kTfLiteError;
  }

  TfLiteTensor* base_input = base_interpreter->input(0);
  if (base_input == nullptr || base_input->type != kTfLiteInt16 ||
      base_input->bytes != 10 * sizeof(int16_t)) {
    return kTfLiteError;
  }
  int16_t* quantized_input = tflite::GetTensorData<int16_t>(base_input);
  for (int index = 0; index < 10; ++index) {
    const float standardized =
        (sensor_inputs[index] - g_sensor_calibration_release_input_mean[index]) /
        g_sensor_calibration_release_input_std[index];
    quantized_input[index] = QuantizeInt16(
        standardized, base_input->params.scale, base_input->params.zero_point);
  }
  if (base_interpreter->Invoke() != kTfLiteOk) return kTfLiteError;

  for (int logical_index = 0; logical_index < 9; ++logical_index) {
    const int raw_index = g_sensor_calibration_release_output_map[logical_index];
    TfLiteTensor* output = base_interpreter->output(raw_index);
    if (output == nullptr || output->type != kTfLiteInt16 ||
        output->bytes < sizeof(int16_t)) {
      return kTfLiteError;
    }
    const int16_t quantized = tflite::GetTensorData<int16_t>(output)[0];
    calibrated_outputs[logical_index] =
        (static_cast<int32_t>(quantized) - output->params.zero_point) *
        output->params.scale;
  }
  if (base_v4_quantized != nullptr) {
    TfLiteTensor* v4 = base_interpreter->output(
        g_sensor_calibration_release_output_map[4]);
    *base_v4_quantized = tflite::GetTensorData<int16_t>(v4)[0];
  }
  if (base_v4_float != nullptr) *base_v4_float = calibrated_outputs[4];

  TfLiteTensor* adapter_input = adapter_interpreter->input(0);
  if (adapter_input == nullptr || adapter_input->type != kTfLiteInt16 ||
      adapter_input->bytes !=
          SENSOR_CALIBRATION_RELEASE_CELL_COUNT * sizeof(int16_t)) {
    return kTfLiteError;
  }
  int16_t* onehot = tflite::GetTensorData<int16_t>(adapter_input);
  memset(onehot, 0, adapter_input->bytes);

  const int voltage_bin = static_cast<int>(floorf(sensor_inputs[5]));
  const int temperature_bin =
      static_cast<int>(floorf((sensor_inputs[0] + 40.0f) / 5.0f));
  const int humidity_bin = static_cast<int>(floorf(sensor_inputs[1] / 10.0f));
  const float current = sensor_inputs[7];
  const int current_bin = current >= 8.0f ? 4 : current >= 6.0f ? 3
                            : current >= 4.0f ? 2 : current >= 2.0f ? 1 : 0;
  int matching_cell = -1;
  for (int cell = 0; cell < SENSOR_CALIBRATION_RELEASE_CELL_COUNT; ++cell) {
    const int16_t* key = g_sensor_calibration_release_cell_keys[cell];
    if (key[0] == pga_code && key[1] == voltage_bin &&
        key[2] == temperature_bin && key[3] == humidity_bin &&
        key[4] == current_bin) {
      matching_cell = cell;
      break;
    }
  }
  if (matching_cell >= 0) {
    onehot[matching_cell] = QuantizeInt16(
        1.0f, adapter_input->params.scale, adapter_input->params.zero_point);
  }
  if (adapter_interpreter->Invoke() != kTfLiteOk) return kTfLiteError;

  TfLiteTensor* adapter_output = adapter_interpreter->output(0);
  if (adapter_output == nullptr || adapter_output->type != kTfLiteInt16 ||
      adapter_output->bytes < sizeof(int16_t)) {
    return kTfLiteError;
  }
  const int16_t correction_q =
      tflite::GetTensorData<int16_t>(adapter_output)[0];
  if (adapter_quantized != nullptr) *adapter_quantized = correction_q;
  float correction_mv =
      (static_cast<int32_t>(correction_q) - adapter_output->params.zero_point) *
      adapter_output->params.scale;
  if (correction_mv < -10.0f) correction_mv = -10.0f;
  if (correction_mv > 10.0f) correction_mv = 10.0f;
  calibrated_outputs[4] += correction_mv / 1000.0f;
  return kTfLiteOk;
}

}  // namespace sensor_calibration_release

#endif  // SENSOR_CALIBRATION_RELEASE_INFERENCE_H_
