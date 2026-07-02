#ifndef MNIST_MLP_TEST_DATA_H_
#define MNIST_MLP_TEST_DATA_H_

#include <cstdint>

constexpr int kMnistMlpInputSize = 784;
constexpr int kMnistMlpClassCount = 10;
constexpr int kMnistMlpSampleCount = 3;

extern const int8_t g_mnist_mlp_test_images[kMnistMlpSampleCount][kMnistMlpInputSize];
extern const int8_t g_mnist_mlp_test_labels[kMnistMlpSampleCount];
extern const int32_t g_mnist_mlp_test_indices[kMnistMlpSampleCount];

#endif  // MNIST_MLP_TEST_DATA_H_
