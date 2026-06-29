# Person Detection模型模板

这是一个基于TensorFlow Lite Micro的person_detection示例创建的模型调用和测试模板，使用person_detection模型进行人物检测。

## 文件结构

- `my_model.h` - 头文件，定义了对外接口
- `my_model.cc` - 实现文件，包含模型初始化、推理和测试逻辑
- `example_usage_new.cc` - 使用示例，展示如何调用模板函数
- `README.md` - 本说明文件

## 主要功能

### 1. Setup函数 - 对应person_detection的setup()
```cpp
int Setup();
```
- 初始化person_detection模型
- 只需要在程序开始时调用一次
- 返回0表示成功，其他值表示错误
- 自动加载g_person_detect_model_data模型数据

### 2. 推理函数 - 对应person_detection的loop()
```cpp
int RunInference(const int8_t* image_data, int8_t* person_score, int8_t* no_person_score);
```
- 使用96x96x1的int8图像数据进行人物检测推理
- `image_data`: 输入图像数据指针 (96x96x1, int8格式)
- `person_score`: 输出人的置信度分数
- `no_person_score`: 输出非人的置信度分数
- 返回0表示推理成功，其他值表示错误

### 3. 测试函数
```cpp
int RunTest();
```
- 使用person_detection的专用测试数据验证模型是否正常工作
- 包含两个测试用例：有人图像(g_person_data)和无人图像(g_no_person_data)
- 返回0表示测试通过，其他值表示测试失败
- 可以在模型初始化后调用来验证模型正确性
- 测试数据来自`person_image_data.h`和`no_person_image_data.h`

### 4. 辅助函数
```cpp
TfLiteTensor* GetInputTensor();   // 获取输入张量指针
TfLiteTensor* GetOutputTensor();  // 获取输出张量指针
void Cleanup();                   // 清理模型资源
```

## 使用步骤

### 1. 在你的代码中使用 - Arduino风格
```cpp
#include "my_model.h"

void setup() {
    // 初始化模型
    if (my_model::Setup() == 0) {
        printf("模型初始化成功\n");
        
        // 运行测试验证模型
        my_model::RunTest();
    }
}

void loop() {
    // 获取96x96x1的图像数据
    static int8_t image_data[kMaxImageSize];
    
    // 从摄像头或其他源获取图像数据
    // GetImage(kNumCols, kNumRows, kNumChannels, image_data);
    
    // 运行推理
    int8_t person_score, no_person_score;
    if (my_model::RunInference(image_data, &person_score, &no_person_score) == 0) {
        // 处理检测结果
        if (person_score > no_person_score) {
            printf("检测到人物，置信度: %d\n", person_score);
            // 执行检测到人物时的动作
        } else {
            printf("未检测到人物，置信度: %d\n", no_person_score);
            // 执行未检测到人物时的动作
        }
    }
}
```

### 2. 在STM32项目中集成

#### 2.1 包含必要的头文件
确保你的项目包含了TensorFlow Lite Micro的相关头文件和库，以及测试数据头文件：
```cpp
#include "tensorflow/lite/micro/examples/person_detection/person_image_data.h"
#include "tensorflow/lite/micro/examples/person_detection/no_person_image_data.h"
```

#### 2.2 链接模型数据和测试数据
模板使用person_detection的内置数据：
- 模型数据: `g_person_detect_model_data`
- 有人测试图像: `g_person_data` (96x96x1, int8格式)
- 无人测试图像: `g_no_person_data` (96x96x1, int8格式)

#### 2.3 配置内存
模板使用136KB的tensor arena，确保你的STM32有足够的RAM：
```cpp
constexpr int kTensorArenaSize = 136 * 1024;  // 136KB
```

#### 2.4 调用流程
```cpp
// 在系统初始化时调用一次
my_model::Setup();

// 在主循环或任务中调用
int8_t image[kMaxImageSize];  // 96x96x1图像
// ... 获取图像数据 ...
int8_t person_score, no_person_score;
my_model::RunInference(image, &person_score, &no_person_score);
```

## 技术规格

- **模型**: Person Detection (内置)
- **输入**: 96x96x1 图像，int8格式 (-128 到 127)
- **输出**: 2个分数值 (person_score, no_person_score)，uint8格式
- **内存需求**: 136KB tensor arena
- **支持的操作**: AveragePool2D, Conv2D, DepthwiseConv2D, Reshape, Softmax
- **测试数据**: 
  - `g_person_data`: 包含人物的96x96x1测试图像
  - `g_no_person_data`: 不包含人物的96x96x1测试图像
  - 两个测试数组都是int8格式，大小为9216字节(96x96x1)

## 错误代码说明

- `0`: 成功
- `-1`: 模型版本不兼容或模型未初始化
- `-2`: 张量分配失败或输入数据为空
- `-3`: 推理执行失败

## 注意事项

1. **内存要求**: 确保STM32有至少136KB的可用RAM
2. **输入格式**: 输入图像必须是96x96x1的int8格式
3. **数据转换**: 如果你的图像是uint8格式(0-255)，需要转换为int8格式(减去128)
4. **初始化**: 只需调用一次Setup()，然后可以多次调用RunInference()
5. **线程安全**: 当前实现不是线程安全的，如需多线程使用请添加适当的同步机制

## 性能优化建议

1. **量化模型**: 使用int8量化版本的person_detection模型以获得更好的性能
2. **内存对齐**: tensor_arena已经16字节对齐以获得最佳性能
3. **操作选择**: 只包含模型需要的操作，减少代码大小
4. **批处理**: 如果有多个图像需要处理，考虑批量处理

## 扩展方向

- 集成摄像头接口(image_provider)
- 添加结果响应处理(detection_responder)
- 支持其他视觉检测模型
- 添加性能监控和调试功能
- 支持模型热更新