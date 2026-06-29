#ifndef VERI_SOC_CSRC_TFLM_MICRO_SPEECH_FEATURES_H_
#define VERI_SOC_CSRC_TFLM_MICRO_SPEECH_FEATURES_H_

#include <stdint.h>

constexpr int kTflmMicroSpeechFeatureSize = 40;
constexpr int kTflmMicroSpeechFeatureFrames = 49;
constexpr int kTflmMicroSpeechFeatureCount =
    kTflmMicroSpeechFeatureSize * kTflmMicroSpeechFeatureFrames;
constexpr int kTflmMicroSpeechCategoryCount = 4;
constexpr int kTflmMicroSpeechYesIndex = 2;
constexpr int kTflmMicroSpeechNoIndex = 3;

extern const int8_t
    g_tflm_micro_speech_yes_features[kTflmMicroSpeechFeatureCount];
extern const int8_t
    g_tflm_micro_speech_no_features[kTflmMicroSpeechFeatureCount];

#endif  // VERI_SOC_CSRC_TFLM_MICRO_SPEECH_FEATURES_H_
