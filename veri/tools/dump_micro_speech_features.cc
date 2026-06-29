#include <algorithm>
#include <cstdint>
#include <cstdio>

#include "tensorflow/lite/core/c/common.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/micro/examples/micro_speech/micro_model_settings.h"
#include "tensorflow/lite/micro/examples/micro_speech/models/audio_preprocessor_int8_model_data.h"
#include "tensorflow/lite/micro/examples/micro_speech/models/micro_speech_quantized_model_data.h"
#include "tensorflow/lite/micro/examples/micro_speech/testdata/no_1000ms_audio_data.h"
#include "tensorflow/lite/micro/examples/micro_speech/testdata/yes_1000ms_audio_data.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/schema/schema_generated.h"

namespace {

constexpr size_t kArenaSize = 28584;
constexpr int kAudioSampleDurationCount =
    kFeatureDurationMs * kAudioSampleFrequency / 1000;
constexpr int kAudioSampleStrideCount =
    kFeatureStrideMs * kAudioSampleFrequency / 1000;

using Features = int8_t[kFeatureCount][kFeatureSize];
using MicroSpeechOpResolver = tflite::MicroMutableOpResolver<4>;
using AudioPreprocessorOpResolver = tflite::MicroMutableOpResolver<18>;

alignas(16) uint8_t g_arena[kArenaSize];

bool Check(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "error: %s\n", message);
  }
  return condition;
}

bool CheckOk(TfLiteStatus status, const char* message) {
  return Check(status == kTfLiteOk, message);
}

TfLiteStatus RegisterMicroSpeechOps(MicroSpeechOpResolver& op_resolver) {
  TF_LITE_ENSURE_STATUS(op_resolver.AddReshape());
  TF_LITE_ENSURE_STATUS(op_resolver.AddFullyConnected());
  TF_LITE_ENSURE_STATUS(op_resolver.AddDepthwiseConv2D());
  TF_LITE_ENSURE_STATUS(op_resolver.AddSoftmax());
  return kTfLiteOk;
}

TfLiteStatus RegisterAudioPreprocessorOps(
    AudioPreprocessorOpResolver& op_resolver) {
  TF_LITE_ENSURE_STATUS(op_resolver.AddReshape());
  TF_LITE_ENSURE_STATUS(op_resolver.AddCast());
  TF_LITE_ENSURE_STATUS(op_resolver.AddStridedSlice());
  TF_LITE_ENSURE_STATUS(op_resolver.AddConcatenation());
  TF_LITE_ENSURE_STATUS(op_resolver.AddMul());
  TF_LITE_ENSURE_STATUS(op_resolver.AddAdd());
  TF_LITE_ENSURE_STATUS(op_resolver.AddDiv());
  TF_LITE_ENSURE_STATUS(op_resolver.AddMinimum());
  TF_LITE_ENSURE_STATUS(op_resolver.AddMaximum());
  TF_LITE_ENSURE_STATUS(op_resolver.AddWindow());
  TF_LITE_ENSURE_STATUS(op_resolver.AddFftAutoScale());
  TF_LITE_ENSURE_STATUS(op_resolver.AddRfft());
  TF_LITE_ENSURE_STATUS(op_resolver.AddEnergy());
  TF_LITE_ENSURE_STATUS(op_resolver.AddFilterBank());
  TF_LITE_ENSURE_STATUS(op_resolver.AddFilterBankSquareRoot());
  TF_LITE_ENSURE_STATUS(op_resolver.AddFilterBankSpectralSubtraction());
  TF_LITE_ENSURE_STATUS(op_resolver.AddPCAN());
  TF_LITE_ENSURE_STATUS(op_resolver.AddFilterBankLog());
  return kTfLiteOk;
}

bool GenerateSingleFeature(const int16_t* audio_data, int audio_data_size,
                           int8_t* feature_output,
                           tflite::MicroInterpreter* interpreter) {
  TfLiteTensor* input = interpreter->input(0);
  TfLiteTensor* output = interpreter->output(0);
  if (!Check(input != nullptr, "audio preprocessor input missing") ||
      !Check(output != nullptr, "audio preprocessor output missing") ||
      !Check(audio_data_size == kAudioSampleDurationCount,
             "audio sample window size mismatch") ||
      !Check(input->dims->data[input->dims->size - 1] ==
                 kAudioSampleDurationCount,
             "audio preprocessor input shape mismatch") ||
      !Check(output->dims->data[output->dims->size - 1] == kFeatureSize,
             "audio preprocessor output shape mismatch")) {
    return false;
  }

  int16_t* input_data = tflite::GetTensorData<int16_t>(input);
  for (int i = 0; i < audio_data_size; ++i) {
    input_data[i] = audio_data[i];
  }
  if (!CheckOk(interpreter->Invoke(), "audio preprocessor Invoke failed")) {
    return false;
  }

  const int8_t* output_data = tflite::GetTensorData<int8_t>(output);
  for (int i = 0; i < kFeatureSize; ++i) {
    feature_output[i] = output_data[i];
  }
  return true;
}

bool GenerateFeatures(const int16_t* audio_data, size_t audio_data_size,
                      Features* features_output) {
  const tflite::Model* model =
      tflite::GetModel(g_audio_preprocessor_int8_model_data);
  if (!Check(model->version() == TFLITE_SCHEMA_VERSION,
             "audio preprocessor schema version mismatch")) {
    return false;
  }

  AudioPreprocessorOpResolver op_resolver;
  if (!CheckOk(RegisterAudioPreprocessorOps(op_resolver),
               "audio preprocessor op registration failed")) {
    return false;
  }

  tflite::MicroInterpreter interpreter(model, op_resolver, g_arena,
                                       kArenaSize);
  if (!CheckOk(interpreter.AllocateTensors(),
               "audio preprocessor AllocateTensors failed")) {
    return false;
  }

  size_t remaining_samples = audio_data_size;
  size_t feature_index = 0;
  while (remaining_samples >= kAudioSampleDurationCount &&
         feature_index < kFeatureCount) {
    if (!GenerateSingleFeature(audio_data, kAudioSampleDurationCount,
                               (*features_output)[feature_index],
                               &interpreter)) {
      return false;
    }
    ++feature_index;
    audio_data += kAudioSampleStrideCount;
    remaining_samples -= kAudioSampleStrideCount;
  }

  return Check(feature_index == kFeatureCount,
               "audio did not produce the full feature window");
}

bool ClassifyFeatures(const Features& features, int* prediction_index,
                      int8_t* scores) {
  const tflite::Model* model =
      tflite::GetModel(g_micro_speech_quantized_model_data);
  if (!Check(model->version() == TFLITE_SCHEMA_VERSION,
             "micro_speech schema version mismatch")) {
    return false;
  }

  MicroSpeechOpResolver op_resolver;
  if (!CheckOk(RegisterMicroSpeechOps(op_resolver),
               "micro_speech op registration failed")) {
    return false;
  }

  tflite::MicroInterpreter interpreter(model, op_resolver, g_arena,
                                       kArenaSize);
  if (!CheckOk(interpreter.AllocateTensors(),
               "micro_speech AllocateTensors failed")) {
    return false;
  }

  TfLiteTensor* input = interpreter.input(0);
  TfLiteTensor* output = interpreter.output(0);
  if (!Check(input != nullptr, "micro_speech input missing") ||
      !Check(output != nullptr, "micro_speech output missing") ||
      !Check(input->dims->data[input->dims->size - 1] == kFeatureElementCount,
             "micro_speech input shape mismatch") ||
      !Check(output->dims->data[output->dims->size - 1] == kCategoryCount,
             "micro_speech output shape mismatch")) {
    return false;
  }

  int8_t* input_data = tflite::GetTensorData<int8_t>(input);
  const int8_t* source = &features[0][0];
  for (int i = 0; i < kFeatureElementCount; ++i) {
    input_data[i] = source[i];
  }

  if (!CheckOk(interpreter.Invoke(), "micro_speech Invoke failed")) {
    return false;
  }

  const int8_t* output_data = tflite::GetTensorData<int8_t>(output);
  int best = 0;
  scores[0] = output_data[0];
  for (int i = 1; i < kCategoryCount; ++i) {
    scores[i] = output_data[i];
    if (output_data[i] > output_data[best]) {
      best = i;
    }
  }
  *prediction_index = best;
  return true;
}

void PrintArray(const char* symbol, const Features& features) {
  std::printf("alignas(16) const int8_t %s[kTflmMicroSpeechFeatureCount] = {",
              symbol);
  const int8_t* values = &features[0][0];
  for (int i = 0; i < kFeatureElementCount; ++i) {
    if ((i % 16) == 0) {
      std::printf("\n    ");
    }
    std::printf("%d", static_cast<int>(values[i]));
    if (i + 1 != kFeatureElementCount) {
      std::printf(", ");
    }
  }
  std::printf("\n};\n\n");
}

void PrintGeneratedFile(const Features& yes_features,
                        const Features& no_features) {
  std::printf("#include \"tflm_micro_speech_features.h\"\n\n");
  PrintArray("g_tflm_micro_speech_yes_features", yes_features);
  PrintArray("g_tflm_micro_speech_no_features", no_features);
}

bool GenerateAndVerify(const char* label, int expected_index,
                       const int16_t* audio_data, size_t audio_data_size,
                       Features* features) {
  int prediction = -1;
  int8_t scores[kCategoryCount] = {};
  if (!GenerateFeatures(audio_data, audio_data_size, features) ||
      !ClassifyFeatures(*features, &prediction, scores)) {
    return false;
  }

  std::fprintf(stderr, "%s prediction=%s scores=[%d,%d,%d,%d]\n", label,
               kCategoryLabels[prediction], static_cast<int>(scores[0]),
               static_cast<int>(scores[1]), static_cast<int>(scores[2]),
               static_cast<int>(scores[3]));
  return Check(prediction == expected_index, "unexpected host prediction");
}

}  // namespace

int main() {
  Features yes_features = {};
  Features no_features = {};

  if (!GenerateAndVerify("yes", 2, g_yes_1000ms_audio_data,
                         g_yes_1000ms_audio_data_size, &yes_features) ||
      !GenerateAndVerify("no", 3, g_no_1000ms_audio_data,
                         g_no_1000ms_audio_data_size, &no_features)) {
    return 1;
  }

  PrintGeneratedFile(yes_features, no_features);
  return 0;
}
