#include "my_model.h"
#include "model_settings.h"
#include <stdio.h>

// 包含生成的测试数据
#include "gen/my_model/testdata/no_person_image_data.h"
#include "gen/my_model/testdata/person_image_data.h"

// 示例主函数 - 模拟Arduino风格的setup/loop结构
int main(int argc, char** argv) {
    MicroPrintf("Start Person Detection model test...\n");
    
    // 1. Setup阶段 - 对应Arduino的setup()
    MicroPrintf("Initializing model...\n");
    int setup_result = my_model::Setup();
    if (setup_result != 0) {
        MicroPrintf("Model initialization failed, error code: %d\n", setup_result);
        return -1;
    }
    MicroPrintf("Model initialized successfully\n");
    
    // 2. 使用专用测试数据进行推理演示
    MicroPrintf("Running inference demo with real test data...\n");
    
    struct TestCase {
        const char* name;
        const int8_t* image_data;
        bool expect_person;
    };
    
    // 使用生成的测试数据
    TestCase test_cases[] = {
        {"Person Image", reinterpret_cast<const int8_t*>(g_person_image_data), true},
        {"No Person Image", reinterpret_cast<const int8_t*>(g_no_person_image_data), false}
    };
    
    MicroPrintf("Testing with real image data...\n");
    
    // 遍历测试用例
    int num_test_cases = sizeof(test_cases) / sizeof(test_cases[0]);
    for (int i = 0; i < num_test_cases; ++i) {
        MicroPrintf("Test case #%d: %s\n", i + 1, test_cases[i].name);
        
        // 运行推理 - 直接获取输出数据指针
        uint8_t* scores = my_model::RunInference(test_cases[i].image_data);
        
        if (scores != nullptr) {
            int8_t no_person_score = scores[kNotAPersonIndex];
            int8_t person_score = scores[kPersonIndex];
            
            MicroPrintf("  Inference succeeded! Result: %s=%d, %s=%d\n", 
                   kCategoryLabels[kNotAPersonIndex], no_person_score,
                   kCategoryLabels[kPersonIndex], person_score);
            
            // 验证结果是否符合预期
            bool detected_person = (person_score > no_person_score);
            bool result_correct = (detected_person == test_cases[i].expect_person);
            
            if (detected_person) {
                MicroPrintf("  Detection: %s (confidence: %d)\n", 
                           kCategoryLabels[kPersonIndex], person_score);
            } else {
                MicroPrintf("  Detection: %s (confidence: %d)\n", 
                           kCategoryLabels[kNotAPersonIndex], no_person_score);
            }
            
            if (result_correct) {
                MicroPrintf("  ✓ Result matches expectation\n");
            } else {
                MicroPrintf("  ✗ Result does NOT match expectation (expected %s)\n", 
                           test_cases[i].expect_person ? kCategoryLabels[kPersonIndex] : kCategoryLabels[kNotAPersonIndex]);
            }
        } else {
            MicroPrintf("  Inference failed\n");
        }
        
        MicroPrintf("\n");
    }
    
    // 3. 清理资源
    my_model::Cleanup();
    MicroPrintf("Model test finished\n");
    
    return 0;
}

// 在嵌入式系统中的使用示例
void embedded_usage_example() {
    // 在嵌入式系统中，通常在系统初始化时调用一次Setup
    static bool model_initialized = false;
    
    if (!model_initialized) {
        // 初始化模型（只需要初始化一次）
        if (my_model::Setup() == 0) {
            model_initialized = true;
        }
    }
    
    // 在主循环中或者中断处理中调用
    if (model_initialized) {
        // 从摄像头或其他图像源获取数据
        // 实际应用中，这里会调用相应的图像获取函数
        // GetImage(kNumCols, kNumRows, kNumChannels, camera_image);
        
        // 为演示目的，使用预生成的测试图像数据
        // 在实际应用中，替换为从摄像头获取的实时图像数据
        static int test_index = 0;
        const int8_t* camera_image;
        
        // 轮流使用两种测试图像
        if (test_index % 2 == 0) {
            camera_image = reinterpret_cast<const int8_t*>(g_person_image_data);
            MicroPrintf("Using person test image...\n");
        } else {
            camera_image = reinterpret_cast<const int8_t*>(g_no_person_image_data);
            MicroPrintf("Using no-person test image...\n");
        }
        test_index++;
        
        // 执行推理
        uint8_t* scores = my_model::RunInference(camera_image);
        if (scores != nullptr) {
            int8_t no_person_score = scores[kNotAPersonIndex];
            int8_t person_score = scores[kPersonIndex];
            
            MicroPrintf("Inference result: %s=%d, %s=%d\n", 
                       kCategoryLabels[kPersonIndex], person_score,
                       kCategoryLabels[kNotAPersonIndex], no_person_score);
            
            // 处理推理结果
            if (person_score > no_person_score) {
                // 检测到人物 - 执行相应动作
                MicroPrintf("%s detected! Executing response actions...\n", kCategoryLabels[kPersonIndex]);
                // 例如：点亮LED、发送警报、记录日志等
                // RespondToDetection(person_score, no_person_score);
            } else {
                MicroPrintf("%s detected.\n", kCategoryLabels[kNotAPersonIndex]);
            }
        }
    }
}