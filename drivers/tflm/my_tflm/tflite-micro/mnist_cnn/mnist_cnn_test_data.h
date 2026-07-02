#ifndef MNIST_CNN_TEST_DATA_H_
#define MNIST_CNN_TEST_DATA_H_

#include <cstdint>

constexpr int kMnistCnnInputSize = 784;
constexpr int kMnistCnnClassCount = 10;
constexpr int kMnistCnnSampleCount = 3;

extern const int8_t g_mnist_cnn_test_images[kMnistCnnSampleCount][kMnistCnnInputSize];
extern const int8_t g_mnist_cnn_test_labels[kMnistCnnSampleCount];
extern const int32_t g_mnist_cnn_test_indices[kMnistCnnSampleCount];

#endif  // MNIST_CNN_TEST_DATA_H_
