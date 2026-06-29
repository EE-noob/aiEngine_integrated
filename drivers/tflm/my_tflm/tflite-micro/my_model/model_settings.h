#ifndef MY_MODEL_SETTINGS_H_
#define MY_MODEL_SETTINGS_H_

// 保持这些常量表达式允许我们在栈上为工作内存分配固定大小的数组

// 所有这些值都来自模型训练期间使用的值
// 如果你改变你的模型，你需要更新这些常量
constexpr int kNumCols = 64;
constexpr int kNumRows = 64;
constexpr int kNumChannels = 1;

constexpr int kMaxImageSize = kNumCols * kNumRows * kNumChannels;

constexpr int kCategoryCount = 29;
constexpr int kAIndex = 0;
constexpr int kBIndex = 1;
constexpr int kCIndex = 2;
constexpr int kDIndex = 3;
constexpr int kEIndex = 4;
constexpr int kFIndex = 5;
constexpr int kGIndex = 6;
constexpr int kHIndex = 7;
constexpr int kIIndex = 8;
constexpr int kJIndex = 9;
constexpr int kKIndex = 10;
constexpr int kLIndex = 11;
constexpr int kMIndex = 12;
constexpr int kNIndex = 13;
constexpr int kOIndex = 14;
constexpr int kPIndex = 15;
constexpr int kQIndex = 16;
constexpr int kRIndex = 17;
constexpr int kSIndex = 18;
constexpr int kTIndex = 19;
constexpr int kUIndex = 20;
constexpr int kVIndex = 21;
constexpr int kWIndex = 22;
constexpr int kXIndex = 23;
constexpr int kYIndex = 24;
constexpr int kZIndex = 25;
constexpr int kDelIndex = 26;
constexpr int kNothingIndex = 27;
constexpr int kSpaceIndex = 28;

// 类别标签，顺序为：A-Z, del, nothing, space
extern const char* kCategoryLabels[kCategoryCount];

#endif  // MY_MODEL_SETTINGS_H_