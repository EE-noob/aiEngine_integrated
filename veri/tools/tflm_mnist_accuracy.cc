#include <algorithm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <limits>
#include <string>
#include <vector>

#include "tensorflow/lite/core/c/common.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/system_setup.h"
#include "tensorflow/lite/schema/schema_generated.h"

namespace {

constexpr int kInputSize = 784;
constexpr int kClassCount = 10;

std::vector<uint8_t> ReadFile(const std::string& path) {
  std::ifstream stream(path, std::ios::binary | std::ios::ate);
  if (!stream) return {};
  const std::streamsize size = stream.tellg();
  if (size <= 0) return {};
  stream.seekg(0);
  std::vector<uint8_t> data(static_cast<size_t>(size));
  if (!stream.read(reinterpret_cast<char*>(data.data()), size)) return {};
  return data;
}

template <typename T>
int ArgMax(const T* data) {
  int best = 0;
  for (int index = 1; index < kClassCount; ++index) {
    if (data[index] > data[best]) best = index;
  }
  return best;
}

template <typename T>
T QuantizePixel(uint8_t pixel, const TfLiteQuantizationParams& params) {
  const double real_value = static_cast<double>(pixel) / 255.0;
  const double quantized =
      std::round(real_value / static_cast<double>(params.scale)) +
      static_cast<double>(params.zero_point);
  const double clipped = std::max(
      static_cast<double>(std::numeric_limits<T>::min()),
      std::min(static_cast<double>(std::numeric_limits<T>::max()), quantized));
  return static_cast<T>(clipped);
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 4 || argc > 6) {
    std::cerr << "usage: " << argv[0]
              << " MODEL.tflite IMAGES_U8.bin LABELS_U8.bin [COUNT] [DUMP.csv]\n";
    return 2;
  }

  const std::vector<uint8_t> model_data = ReadFile(argv[1]);
  const std::vector<uint8_t> images = ReadFile(argv[2]);
  const std::vector<uint8_t> labels = ReadFile(argv[3]);
  if (model_data.empty() || images.empty() || labels.empty()) {
    std::cerr << "failed to read model or dataset\n";
    return 2;
  }
  const size_t available = std::min(labels.size(), images.size() / kInputSize);
  const size_t requested = argc >= 5 ? std::stoul(argv[4]) : available;
  const size_t sample_count = std::min(available, requested);
  if (sample_count == 0) {
    std::cerr << "dataset is empty\n";
    return 2;
  }

  tflite::InitializeTarget();
  const tflite::Model* model = tflite::GetModel(model_data.data());
  if (model->version() != TFLITE_SCHEMA_VERSION) {
    std::cerr << "schema mismatch\n";
    return 2;
  }
  tflite::MicroMutableOpResolver<2> resolver;
  if (resolver.AddFullyConnected() != kTfLiteOk ||
      resolver.AddSoftmax() != kTfLiteOk) {
    std::cerr << "operator registration failed\n";
    return 2;
  }
  std::vector<uint8_t> arena(64 * 1024);
  // Preserve intermediates so a hardware run can be compared at each FC
  // boundary instead of attributing a downstream Softmax delta to the NPU.
  tflite::MicroInterpreter interpreter(model, resolver, arena.data(), arena.size(),
                                       nullptr, nullptr, true);
  if (interpreter.AllocateTensors() != kTfLiteOk) {
    std::cerr << "AllocateTensors failed\n";
    return 2;
  }

  TfLiteTensor* input = interpreter.input(0);
  TfLiteTensor* output = interpreter.output(0);
  const bool int8_model =
      input->type == kTfLiteInt8 && output->type == kTfLiteInt8;
  const bool int16_model =
      input->type == kTfLiteInt16 && output->type == kTfLiteInt16;
  if (!int8_model && !int16_model) {
    std::cerr << "expected matching INT8 or INT16 input/output\n";
    return 2;
  }

  std::ofstream dump;
  if (argc >= 6) {
    dump.open(argv[5]);
    if (!dump) {
      std::cerr << "failed to open output dump\n";
      return 2;
    }
  }

  size_t correct = 0;
  for (size_t sample = 0; sample < sample_count; ++sample) {
    const uint8_t* image = images.data() + sample * kInputSize;
    if (int16_model) {
      int16_t* data = tflite::GetTensorData<int16_t>(input);
      for (int pixel = 0; pixel < kInputSize; ++pixel) {
        data[pixel] = QuantizePixel<int16_t>(image[pixel], input->params);
      }
    } else {
      int8_t* data = tflite::GetTensorData<int8_t>(input);
      for (int pixel = 0; pixel < kInputSize; ++pixel) {
        data[pixel] = QuantizePixel<int8_t>(image[pixel], input->params);
      }
    }
    if (interpreter.Invoke() != kTfLiteOk) {
      std::cerr << "Invoke failed at sample " << sample << "\n";
      return 2;
    }

    const int prediction =
        int16_model ? ArgMax(tflite::GetTensorData<int16_t>(output))
                    : ArgMax(tflite::GetTensorData<int8_t>(output));
    if (prediction == labels[sample]) ++correct;

    if (dump) {
      dump << sample << ',' << static_cast<int>(labels[sample]) << ','
           << prediction;
      for (int cls = 0; cls < kClassCount; ++cls) {
        const int value = int16_model
                              ? static_cast<int>(
                                    tflite::GetTensorData<int16_t>(output)[cls])
                              : static_cast<int>(
                                    tflite::GetTensorData<int8_t>(output)[cls]);
        dump << ',' << value;
      }
      // The MNIST MLP topology is fixed: tensor 5 is FC1 (64 elements), tensor
      // 6 is FC2/logits (10 elements).  Keep these after the final output so
      // existing prediction readers can continue to consume columns 0..12.
      for (int tensor_index : {5, 6}) {
        const TfLiteEvalTensor* intermediate =
            interpreter.GetTensor(tensor_index);
        if (intermediate == nullptr) {
          std::cerr << "failed to retrieve intermediate tensor "
                    << tensor_index << "\n";
          return 2;
        }
        const int element_count = tensor_index == 5 ? 64 : 10;
        for (int element = 0; element < element_count; ++element) {
          const int value = int16_model
                                ? static_cast<int>(intermediate->data.i16[element])
                                : static_cast<int>(intermediate->data.int8[element]);
          dump << ',' << value;
        }
      }
      dump << '\n';
    }
  }

  std::cout << "{\"model\":\"" << (int16_model ? "int16x8" : "int8")
            << "\",\"samples\":" << sample_count << ",\"correct\":" << correct
            << ",\"accuracy\":"
            << static_cast<double>(correct) / static_cast<double>(sample_count)
            << ",\"arena_used\":" << interpreter.arena_used_bytes() << "}\n";
  return 0;
}
