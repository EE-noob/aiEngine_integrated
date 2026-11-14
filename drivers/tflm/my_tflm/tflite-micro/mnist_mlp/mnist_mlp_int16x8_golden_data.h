#ifndef MNIST_MLP_INT16X8_GOLDEN_DATA_H_
#define MNIST_MLP_INT16X8_GOLDEN_DATA_H_

#include <cstdint>

#include "mnist_mlp/mnist_mlp_test_data.h"

constexpr int kMnistMlpHiddenSize = 64;

extern const int16_t
    g_mnist_mlp_int16x8_golden_outputs[kMnistMlpSampleCount]
                                           [kMnistMlpClassCount];
extern const int16_t
    g_mnist_mlp_int16x8_golden_hidden[kMnistMlpSampleCount]
                                          [kMnistMlpHiddenSize];
extern const int16_t
    g_mnist_mlp_int16x8_golden_logits[kMnistMlpSampleCount]
                                          [kMnistMlpClassCount];

#endif  // MNIST_MLP_INT16X8_GOLDEN_DATA_H_
