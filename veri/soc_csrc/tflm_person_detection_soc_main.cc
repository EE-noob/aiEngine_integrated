#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "tensorflow/lite/core/c/common.h"
#include "tensorflow/lite/micro/examples/person_detection/model_settings.h"
#include "tensorflow/lite/micro/examples/person_detection/testdata/no_person_image_data.h"
#include "tensorflow/lite/micro/examples/person_detection/testdata/person_image_data.h"
#include "tensorflow/lite/micro/kernels/conv.h"
#include "tensorflow/lite/micro/kernels/depthwise_conv.h"
#include "tensorflow/lite/micro/kernels/pooling.h"
#include "tensorflow/lite/micro/kernels/softmax.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/models/person_detect_model_data.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"

extern "C" void picosoc_uart_init(void);

namespace {

constexpr uintptr_t kSocProgressAddr = 0x2000000cu;
constexpr int kTensorArenaSize = 136 * 1024;

alignas(16) uint8_t g_tensor_arena[kTensorArenaSize];

void WriteProgress(uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = value;
}

uint32_t EncodeMismatch(int test_case, int person_score, int no_person_score) {
  return 0x97000000u | ((test_case & 0xff) << 16) |
         (((person_score + 128) & 0xff) << 8) |
         ((no_person_score + 128) & 0xff);
}

uint32_t EncodeRunError(int test_case, int error) {
  return 0x97100000u | ((test_case & 0xff) << 8) | ((-error) & 0xff);
}

TfLiteStatus RegisterPersonDetectionOps(
    tflite::MicroMutableOpResolver<5>& op_resolver) {
  TF_LITE_ENSURE_STATUS(
      op_resolver.AddAveragePool2D(tflite::Register_AVERAGE_POOL_2D_INT8()));
  TF_LITE_ENSURE_STATUS(
      op_resolver.AddConv2D(tflite::Register_CONV_2D_INT8()));
  TF_LITE_ENSURE_STATUS(op_resolver.AddDepthwiseConv2D(
      tflite::Register_DEPTHWISE_CONV_2D_INT8()));
  TF_LITE_ENSURE_STATUS(op_resolver.AddReshape());
  TF_LITE_ENSURE_STATUS(
      op_resolver.AddSoftmax(tflite::Register_SOFTMAX_INT8()));
  return kTfLiteOk;
}

int RunInference(tflite::MicroInterpreter* interpreter,
                 const unsigned char* image_data, unsigned int image_size,
                 int* person_score, int* no_person_score) {
  TfLiteTensor* input = interpreter->input(0);
  TfLiteTensor* output = interpreter->output(0);
  if (input == nullptr || output == nullptr) {
    return -1;
  }
  if (input->dims == nullptr || input->dims->size != 4 ||
      input->dims->data[0] != 1 || input->dims->data[1] != kNumRows ||
      input->dims->data[2] != kNumCols ||
      input->dims->data[3] != kNumChannels) {
    return -2;
  }
  if (output->dims == nullptr || output->dims->size != 2 ||
      output->dims->data[0] != 1 ||
      output->dims->data[1] != kCategoryCount) {
    return -3;
  }
  if (input->type != kTfLiteInt8 || output->type != kTfLiteInt8) {
    return -4;
  }
  if (input->bytes != image_size || image_size != kMaxImageSize) {
    return -5;
  }

  memcpy(input->data.int8, image_data, input->bytes);
  if (interpreter->Invoke() != kTfLiteOk) {
    return -6;
  }

  *person_score = output->data.int8[kPersonIndex];
  *no_person_score = output->data.int8[kNotAPersonIndex];
  return (*person_score > *no_person_score) ? kPersonIndex : kNotAPersonIndex;
}

uint32_t RunPersonDetectionInferenceTest() {
  printf("[tflm] person_detection start\n");
  WriteProgress(0x5d100001u);
  tflite::InitializeTarget();

  const tflite::Model* model = tflite::GetModel(g_person_detect_model_data);
  if (model->version() != TFLITE_SCHEMA_VERSION) {
    WriteProgress(0x5d10e001u);
    printf("[tflm] schema mismatch model=%d expected=%d\n", model->version(),
           TFLITE_SCHEMA_VERSION);
    return 0x97000001u;
  }
  WriteProgress(0x5d100002u);
  printf("[tflm] model ok\n");

  static tflite::MicroMutableOpResolver<5> resolver;
  if (RegisterPersonDetectionOps(resolver) != kTfLiteOk) {
    WriteProgress(0x5d10e002u);
    printf("[tflm] op registration failed\n");
    return 0x97000002u;
  }
  WriteProgress(0x5d100003u);
  printf("[tflm] ops registered\n");

  static tflite::MicroInterpreter interpreter(model, resolver, g_tensor_arena,
                                              kTensorArenaSize);
  WriteProgress(0x5d100004u);
  printf("[tflm] allocating tensors\n");
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    WriteProgress(0x5d10e003u);
    printf("[tflm] AllocateTensors failed\n");
    return 0x97000003u;
  }
  WriteProgress(0x5d100005u);
  printf("[tflm] tensors allocated arena=%d\n", kTensorArenaSize);

  int person_score = 0;
  int no_person_score = 0;
  int person_result =
      RunInference(&interpreter, g_person_image_data, g_person_image_data_size,
                   &person_score, &no_person_score);
  WriteProgress(0x5d210000u | ((person_result & 0xff) << 8) |
                ((person_score + 128) & 0xff));
  printf("[tflm] person image result=%d person=%d no_person=%d\n",
         person_result, person_score, no_person_score);
  if (person_result < 0) {
    return EncodeRunError(1, person_result);
  }
  if (person_result != kPersonIndex) {
    return EncodeMismatch(1, person_score, no_person_score);
  }

  int no_person_result = RunInference(&interpreter, g_no_person_image_data,
                                      g_no_person_image_data_size,
                                      &person_score, &no_person_score);
  WriteProgress(0x5d220000u | ((no_person_result & 0xff) << 8) |
                ((no_person_score + 128) & 0xff));
  printf("[tflm] no_person image result=%d person=%d no_person=%d\n",
         no_person_result, person_score, no_person_score);
  if (no_person_result < 0) {
    return EncodeRunError(2, no_person_result);
  }
  if (no_person_result != kNotAPersonIndex) {
    return EncodeMismatch(2, person_score, no_person_score);
  }

  WriteProgress(0x5d100006u);
  printf("[tflm] person_detection PASS\n");
  return 1;
}

}  // namespace

extern "C" int main(void) {
  picosoc_uart_init();
  return static_cast<int>(RunPersonDetectionInferenceTest());
}
