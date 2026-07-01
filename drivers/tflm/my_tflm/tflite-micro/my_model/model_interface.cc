#include "model_interface.h"
#include "my_model.h"
#include "model_settings.h"
#include "tensorflow/lite/micro/micro_time.h"

namespace {

#if defined(TFLM_SOC_PROGRESS)
void SocProgress(uint32_t value) {
    *reinterpret_cast<volatile uint32_t*>(0x2000000cu) = value;
}
#else
void SocProgress(uint32_t value) { (void)value; }
#endif

}  // namespace

#ifdef __cplusplus
extern "C" {
#endif

// 模型初始化函数
// 返回值: 0表示成功，非0表示失败
int ModelInit(void) {
#if !defined(TFLM_SOC_QUIET)
    MicroPrintf("Initializing model...");
#endif
    SocProgress(0x5a101001u);
    int setup_result = my_model::Setup();
    SocProgress(0x5a101100u | (setup_result & 0xff));
    if (setup_result != 0) {
#if !defined(TFLM_SOC_QUIET)
        MicroPrintf("Model initialization failed, error code: %d", setup_result);
#endif
        return setup_result;
    }
#if !defined(TFLM_SOC_QUIET)
    MicroPrintf("Model initialized successfully");
#endif
    return 0;
}

// 模型推理函数（无打印输出）
int ModelInference(const uint8_t* image_data) {
    if (image_data == nullptr) {
        return -1;
    }
    SocProgress(0x5a201001u);
    uint8_t* scores = my_model::RunInference(image_data);
    SocProgress(0x5a201100u | (scores == nullptr ? 0xffu : 0u));
    if (scores == nullptr) {
        return -1;
    }
    int max_index = 0;
    uint8_t max_score = scores[0];
    for (int j = 1; j < kCategoryCount; ++j) {
        if (scores[j] > max_score) {
            max_score = scores[j];
            max_index = j;
        }
    }
    return max_index;
}

uint32_t ModelLastInvokeCycles(void) {
    return my_model::LastInvokeCycles();
}

// 测试用推理函数（带打印输出）
char ModelInferenceTest(const uint8_t* image_data) {
    if (image_data == nullptr) {
        MicroPrintf("Error: image_data is null");
        return '\0';
    }
    
    // 记录推理开始时间
    uint32_t start_ticks = tflite::GetCurrentTimeTicks();
    
    // 运行推理
    uint8_t* scores = my_model::RunInference(image_data);
    
    // 记录推理结束时间
    uint32_t end_ticks = tflite::GetCurrentTimeTicks();
    uint32_t elapsed_ticks = end_ticks - start_ticks;
    float elapsed_seconds = (float)elapsed_ticks / tflite::ticks_per_second();
    
    if (scores == nullptr) {
        MicroPrintf("Inference failed");
        return '\0';
    }
    
    // 找到最大分数及其类别
    int max_index = 0;
    uint8_t max_score = scores[0];
    for (int j = 1; j < kCategoryCount; ++j) {
        if (scores[j] > max_score) {
            max_score = scores[j];
            max_index = j;
        }
    }
    
    // 打印推理耗时
    MicroPrintf("Inference time: %u ticks", elapsed_ticks);
    
    // 打印推理结果
    MicroPrintf("Inference result: %s (confidence: %d)", kCategoryLabels[max_index], max_score);
    
    // 打印所有类别分数
    MicroPrintf("All scores:");
    for (int j = 0; j < kCategoryCount; ++j) {
        MicroPrintf("  %s: %d", kCategoryLabels[j], scores[j]);
    }
    
    // 返回识别到的字符
    return kCategoryLabels[max_index][0];
}

#ifdef __cplusplus
}
#endif
