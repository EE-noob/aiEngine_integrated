#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "mnist_cnn/mnist_cnn_model_data.h"
#include "mnist_cnn/mnist_cnn_test_data.h"
#include "tensorflow/lite/core/c/common.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"

extern "C" void picosoc_uart_init(void);
extern "C" uint32_t soc_get_cycle(void);

namespace {

constexpr uintptr_t kSocProgressAddr = 0x2000000cu;

#ifndef TFLM_MNIST_CNN_ARENA_SIZE
#define TFLM_MNIST_CNN_ARENA_SIZE (256 * 1024)
#endif

#ifndef TFLM_MNIST_CNN_SAMPLE_LIMIT
#define TFLM_MNIST_CNN_SAMPLE_LIMIT kMnistCnnSampleCount
#endif

alignas(16) uint8_t g_tensor_arena[TFLM_MNIST_CNN_ARENA_SIZE];

void WriteProgress(uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = value;
}

uint32_t EncodeError(uint32_t major, uint32_t detail) {
  return 0x99000000u | ((major & 0xffu) << 8) | (detail & 0xffu);
}

TfLiteStatus RegisterMnistCnnOps(tflite::MicroMutableOpResolver<5>& resolver) {
  TF_LITE_ENSURE_STATUS(resolver.AddConv2D());
  TF_LITE_ENSURE_STATUS(resolver.AddMaxPool2D());
  TF_LITE_ENSURE_STATUS(resolver.AddReshape());
  TF_LITE_ENSURE_STATUS(resolver.AddFullyConnected());
  TF_LITE_ENSURE_STATUS(resolver.AddSoftmax());
  return kTfLiteOk;
}

int ArgMax(const int8_t* data, int size) {
  int best_idx = 0;
  int8_t best_val = data[0];
  for (int i = 1; i < size; ++i) {
    if (data[i] > best_val) {
      best_val = data[i];
      best_idx = i;
    }
  }
  return best_idx;
}

uint32_t RunMnistCnnTest() {
  printf("[tflm] mnist_cnn start\n");
  WriteProgress(0x6e100001u);
  tflite::InitializeTarget();

  const tflite::Model* model = tflite::GetModel(g_mnist_cnn_model_data);
  if (model->version() != TFLITE_SCHEMA_VERSION) {
    printf("[tflm] schema mismatch model=%d expected=%d\n", model->version(),
           TFLITE_SCHEMA_VERSION);
    return EncodeError(1, static_cast<uint32_t>(model->version()));
  }
  WriteProgress(0x6e100002u);

  static tflite::MicroMutableOpResolver<5> resolver;
  if (RegisterMnistCnnOps(resolver) != kTfLiteOk) {
    printf("[tflm] mnist_cnn op registration failed\n");
    return EncodeError(2, 0);
  }
  WriteProgress(0x6e100003u);

  static tflite::MicroInterpreter interpreter(
      model, resolver, g_tensor_arena, TFLM_MNIST_CNN_ARENA_SIZE);
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    printf("[tflm] mnist_cnn AllocateTensors failed\n");
    return EncodeError(3, 0);
  }
  WriteProgress(0x6e100004u);
  printf("[tflm] mnist_cnn tensors allocated arena=%d used=%u\n",
         TFLM_MNIST_CNN_ARENA_SIZE,
         static_cast<unsigned>(interpreter.arena_used_bytes()));

  TfLiteTensor* input = interpreter.input(0);
  TfLiteTensor* output = interpreter.output(0);
  if (input == nullptr || output == nullptr) {
    return EncodeError(4, 0);
  }
  if (input->type != kTfLiteInt8 || output->type != kTfLiteInt8) {
    printf("[tflm] mnist_cnn tensor type mismatch input=%d output=%d\n",
           input->type, output->type);
    return EncodeError(5, (static_cast<uint32_t>(input->type) << 4) |
                              static_cast<uint32_t>(output->type));
  }
  if (input->bytes != kMnistCnnInputSize ||
      output->bytes != kMnistCnnClassCount) {
    printf("[tflm] mnist_cnn tensor size mismatch input=%u output=%u\n",
           static_cast<unsigned>(input->bytes),
           static_cast<unsigned>(output->bytes));
    return EncodeError(6, 0);
  }

  constexpr int kRunSampleCount =
      (TFLM_MNIST_CNN_SAMPLE_LIMIT < kMnistCnnSampleCount)
          ? TFLM_MNIST_CNN_SAMPLE_LIMIT
          : kMnistCnnSampleCount;
  if (kRunSampleCount <= 0) {
    return EncodeError(8, 0);
  }

  uint32_t total_cycles = 0;
  uint32_t min_cycles = 0xffffffffu;
  uint32_t max_cycles = 0;

  for (int sample = 0; sample < kRunSampleCount; ++sample) {
    memcpy(tflite::GetTensorData<int8_t>(input),
           g_mnist_cnn_test_images[sample], kMnistCnnInputSize);
    WriteProgress(0x6e200000u | static_cast<uint32_t>(sample));
    const uint32_t invoke_start = soc_get_cycle();
    if (interpreter.Invoke() != kTfLiteOk) {
      printf("[tflm] mnist_cnn Invoke failed sample=%d\n", sample);
      return EncodeError(7, static_cast<uint32_t>(sample));
    }
    const uint32_t cycles = soc_get_cycle() - invoke_start;
    total_cycles += cycles;
    if (cycles < min_cycles) min_cycles = cycles;
    if (cycles > max_cycles) max_cycles = cycles;

    const int pred =
        ArgMax(tflite::GetTensorData<int8_t>(output), kMnistCnnClassCount);
    const int label = static_cast<int>(g_mnist_cnn_test_labels[sample]);
    printf("[tflm_perf] mnist_cnn sample=%d index=%d label=%d pred=%d invoke_cycles=%u\n",
           sample, static_cast<int>(g_mnist_cnn_test_indices[sample]), label,
           pred, cycles);
    if (pred != label) {
      printf("[tflm] mnist_cnn mismatch sample=%d label=%d pred=%d\n", sample,
             label, pred);
      return 0x99100000u | ((sample & 0xffu) << 8) |
             static_cast<uint32_t>(pred & 0xff);
    }
  }

  const uint32_t avg_cycles = total_cycles / kRunSampleCount;
  printf("[tflm_perf] mnist_cnn total_invoke_cycles=%u avg=%u min=%u max=%u samples=%d\n",
         total_cycles, avg_cycles, min_cycles, max_cycles, kRunSampleCount);
  printf("[tflm] mnist_cnn PASS\n");
  WriteProgress(0x6e100005u);
  return 1;
}

}  // namespace

extern "C" int main(void) {
  picosoc_uart_init();
  return static_cast<int>(RunMnistCnnTest());
}
