#ifndef MODEL_INTERFACE_H_
#define MODEL_INTERFACE_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// 模型初始化函数
// 返回值: 0表示成功，非0表示失败
int ModelInit(void);

// 模型推理函数
// 输入: image_data - 图像数据指针
// 返回: 识别到的类别ID (0~N-1)，如果推理失败返回 -1
int ModelInference(const uint8_t* image_data);

// 测试用推理函数（带打印输出）
// 输入: image_data - 图像数据指针
// 返回: 识别到的字符 (A-Z), 如果推理失败返回 '\0'
char ModelInferenceTest(const uint8_t* image_data);

#ifdef __cplusplus
}
#endif

#endif  // MODEL_INTERFACE_H_
