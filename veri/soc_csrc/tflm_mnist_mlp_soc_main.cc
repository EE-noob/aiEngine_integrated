#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "mnist_mlp/mnist_mlp_model_data.h"
#include "mnist_mlp/mnist_mlp_test_data.h"
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

#ifndef TFLM_MNIST_MLP_ARENA_SIZE
#define TFLM_MNIST_MLP_ARENA_SIZE (128 * 1024)
#endif

#ifndef TFLM_MNIST_MLP_SAMPLE_LIMIT
#define TFLM_MNIST_MLP_SAMPLE_LIMIT kMnistMlpSampleCount
#endif

alignas(16) uint8_t g_tensor_arena[TFLM_MNIST_MLP_ARENA_SIZE];

void WriteProgress(uint32_t value) {
  *reinterpret_cast<volatile uint32_t*>(kSocProgressAddr) = value;
}

uint32_t EncodeError(uint32_t major, uint32_t detail) {
  return 0x98000000u | ((major & 0xffu) << 8) | (detail & 0xffu);
}

TfLiteStatus RegisterMnistMlpOps(tflite::MicroMutableOpResolver<2>& resolver) {
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

uint32_t RunMnistMlpTest() {
  printf("[tflm] mnist_mlp start\n");
  WriteProgress(0x5e100001u);
  tflite::InitializeTarget();

  const tflite::Model* model = tflite::GetModel(g_mnist_mlp_model_data);
  if (model->version() != TFLITE_SCHEMA_VERSION) {
    printf("[tflm] schema mismatch model=%d expected=%d\n", model->version(),
           TFLITE_SCHEMA_VERSION);
    return EncodeError(1, static_cast<uint32_t>(model->version()));
  }
  WriteProgress(0x5e100002u);

  static tflite::MicroMutableOpResolver<2> resolver;
  if (RegisterMnistMlpOps(resolver) != kTfLiteOk) {
    printf("[tflm] mnist_mlp op registration failed\n");
    return EncodeError(2, 0);
  }
  WriteProgress(0x5e100003u);

  static tflite::MicroInterpreter interpreter(
      model, resolver, g_tensor_arena, TFLM_MNIST_MLP_ARENA_SIZE);
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    printf("[tflm] mnist_mlp AllocateTensors failed\n");
    return EncodeError(3, 0);
  }
  WriteProgress(0x5e100004u);
  printf("[tflm] mnist_mlp tensors allocated arena=%d used=%u\n",
         TFLM_MNIST_MLP_ARENA_SIZE,
         static_cast<unsigned>(interpreter.arena_used_bytes()));

  TfLiteTensor* input = interpreter.input(0);
  TfLiteTensor* output = interpreter.output(0);
  if (input == nullptr || output == nullptr) {
    return EncodeError(4, 0);
  }
  if (input->type != kTfLiteInt8 || output->type != kTfLiteInt8) {
    printf("[tflm] mnist_mlp tensor type mismatch input=%d output=%d\n",
           input->type, output->type);
    return EncodeError(5, (static_cast<uint32_t>(input->type) << 4) |
                              static_cast<uint32_t>(output->type));
  }
  if (input->bytes != kMnistMlpInputSize ||
      output->bytes != kMnistMlpClassCount) {
    printf("[tflm] mnist_mlp tensor size mismatch input=%u output=%u\n",
           static_cast<unsigned>(input->bytes),
           static_cast<unsigned>(output->bytes));
    return EncodeError(6, 0);
  }

  uint32_t total_cycles = 0;
  uint32_t min_cycles = 0xffffffffu;
  uint32_t max_cycles = 0;

  constexpr int kRunSampleCount =
      (TFLM_MNIST_MLP_SAMPLE_LIMIT < kMnistMlpSampleCount)
          ? TFLM_MNIST_MLP_SAMPLE_LIMIT
          : kMnistMlpSampleCount;
  if (kRunSampleCount <= 0) {
    return EncodeError(8, 0);
  }

  for (int sample = 0; sample < kRunSampleCount; ++sample) {
    memcpy(tflite::GetTensorData<int8_t>(input),
           g_mnist_mlp_test_images[sample], kMnistMlpInputSize);
    WriteProgress(0x5e200000u | static_cast<uint32_t>(sample));
    const uint32_t invoke_start = soc_get_cycle();
    if (interpreter.Invoke() != kTfLiteOk) {
      printf("[tflm] mnist_mlp Invoke failed sample=%d\n", sample);
      return EncodeError(7, static_cast<uint32_t>(sample));
    }
    const uint32_t cycles = soc_get_cycle() - invoke_start;
    total_cycles += cycles;
    if (cycles < min_cycles) min_cycles = cycles;
    if (cycles > max_cycles) max_cycles = cycles;

    const int pred =
        ArgMax(tflite::GetTensorData<int8_t>(output), kMnistMlpClassCount);
    const int label = static_cast<int>(g_mnist_mlp_test_labels[sample]);
    printf("[tflm_perf] mnist_mlp sample=%d index=%d label=%d pred=%d invoke_cycles=%u\n",
           sample, static_cast<int>(g_mnist_mlp_test_indices[sample]), label,
           pred, cycles);
    if (pred != label) {
      printf("[tflm] mnist_mlp mismatch sample=%d label=%d pred=%d\n", sample,
             label, pred);
      return 0x98100000u | ((sample & 0xffu) << 8) |
             static_cast<uint32_t>(pred & 0xff);
    }
  }

  const uint32_t avg_cycles = total_cycles / kRunSampleCount;
  printf("[tflm_perf] mnist_mlp total_invoke_cycles=%u avg=%u min=%u max=%u samples=%d\n",
         total_cycles, avg_cycles, min_cycles, max_cycles,
         kRunSampleCount);
  printf("[tflm] mnist_mlp PASS\n");
  WriteProgress(0x5e100005u);
  return 1;
}

}  // namespace

extern "C" int main(void) {
  picosoc_uart_init();
  return static_cast<int>(RunMnistMlpTest());
}
