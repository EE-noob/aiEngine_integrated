#ifndef MY_MODEL_H_
#define MY_MODEL_H_

#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/schema/schema_generated.h"
#include "model_settings.h"

// 模型配置参数 - 参考justure_detection
#define TENSOR_ARENA_SIZE (136 * 1024)  // 与justure_detection保持一致

// 函数声明
namespace my_model {

/**
 * @brief 初始化模型 - 对应justure_detection的setup()函数
 * @return 0表示初始化成功，其他值表示错误
 */
int Setup();

/**
 * @brief 运行推理并返回模型输出数据指针
 * @param image_data 输入图像数据指针 (64x64x1, uint8格式)
 * @return 成功时返回输出数据指针，失败时返回nullptr
 *         返回的指针指向长度为kCategoryCount的数组 (data[0]=no_person, data[1]=person)
 */
uint8_t* RunInference(const uint8_t* image_data);

/**
 * @brief 释放模型资源
 */
void Cleanup();

/**
 * @brief 获取输入张量指针 - 用于直接操作输入数据
 * @return 输入张量指针
 */
TfLiteTensor* GetInputTensor();

/**
 * @brief 获取输出张量指针 - 用于直接读取输出数据
 * @return 输出张量指针
 */
TfLiteTensor* GetOutputTensor();

}  // namespace my_model

#endif  // MY_MODEL_H_