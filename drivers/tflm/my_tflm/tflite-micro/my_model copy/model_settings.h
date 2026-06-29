#ifndef MY_MODEL_SETTINGS_H_
#define MY_MODEL_SETTINGS_H_

// 保持这些常量表达式允许我们在栈上为工作内存分配固定大小的数组

// 所有这些值都来自模型训练期间使用的值
// 如果你改变你的模型，你需要更新这些常量
constexpr int kNumCols = 96;
constexpr int kNumRows = 96;
constexpr int kNumChannels = 1;

constexpr int kMaxImageSize = kNumCols * kNumRows * kNumChannels;

constexpr int kCategoryCount = 2;
constexpr int kPersonIndex = 1;
constexpr int kNotAPersonIndex = 0;

// 类别标签
extern const char* kCategoryLabels[kCategoryCount];

#endif  // MY_MODEL_SETTINGS_H_