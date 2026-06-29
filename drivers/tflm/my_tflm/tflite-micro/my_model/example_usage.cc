#include "my_model.h"
#include "model_settings.h"
#include "model_interface.h"
#include <stdio.h>

// 包含生成的测试数据
#include "gen/my_model/testdata/Z_test_image_data.h"
#include "gen/my_model/testdata/W_test_image_data.h"

// 定义一个储存64*64的uint8数组
uint8_t image_buffer[64 * 64];

// 示例主函数 - 模拟Arduino风格的setup/loop结构
int main(int argc, char** argv) {
    MicroPrintf("Start Gesture Detection Model Test...");
    
    // 1. 初始化模型
    if (ModelInit() != 0) {
        return -1;
    }
    
    // 2. 使用专用测试数据进行推理演示
    MicroPrintf("Running inference demo with real test data...");
    
    struct TestCase {
        const char* name;
        const uint8_t* image_data;
        char expect_char; // 期望的字符
    };
    
    // 使用生成的测试数据
    TestCase test_cases[] = {
        {"Z Image", g_Z_test_image_data, 'Z'},
        {"W Image", g_W_test_image_data, 'W'}
    };
    
    MicroPrintf("Testing with real image data...");
    
    // 遍历测试用例
    int num_test_cases = sizeof(test_cases) / sizeof(test_cases[0]);
    for (int i = 0; i < num_test_cases; ++i) {
        MicroPrintf("Test case #%d: %s", i + 1, test_cases[i].name);
        
        // 执行推理
        char result = ModelInferenceTest(test_cases[i].image_data);
        
        if (result != '\0') {
            MicroPrintf("  Detection: %c", result);
            
            // 验证结果是否符合预期
            if (result == test_cases[i].expect_char) {
                MicroPrintf("  Result matches expectation");
            } else {
                MicroPrintf("  Result does NOT match expectation (expected %c)", test_cases[i].expect_char);
            }
        } else {
            MicroPrintf("  Inference failed");
        }
        
        MicroPrintf("");
    }
    
    // 3. 清理资源
    my_model::Cleanup();
    MicroPrintf("Model test finished");
    
    return 0;
}

// 在嵌入式系统中的使用示例
// void embedded_usage_example() {
//     // 在嵌入式系统中，通常在系统初始化时调用一次ModelInit
//     static bool model_initialized = false;
    
//     if (!model_initialized) {
//         // 初始化模型（只需要初始化一次）
//         if (ModelInit() == 0) {
//             model_initialized = true;
//         }
//     }
    
//     // 在主循环中或者中断处理中调用
//     if (model_initialized) {
//         // 从摄像头或其他图像源获取数据
//         // 实际应用中，这里会调用相应的图像获取函数
//         // GetImage(kNumCols, kNumRows, kNumChannels, camera_image);
        
//         // 为演示目的，使用预生成的测试图像数据
//         // 在实际应用中，替换为从摄像头获取的实时图像数据
//         static int test_index = 0;
//         const uint8_t* camera_image;
        
//         // 轮流使用两种测试图像
//         if (test_index % 2 == 0) {
//             camera_image = g_Z_test_image_data;
//             MicroPrintf("Using Z test image...");
//         } else {
//             camera_image = g_W_test_image_data;
//             MicroPrintf("Using W test image...");
//         }
//         test_index++;
        
//         // 执行推理
//         char detected_char = ModelInferenceTest(camera_image);
        
//         if (detected_char != '\0') {
//             // 处理推理结果
//             // 以A为正例举例
//             if (detected_char == 'A') {
//                 MicroPrintf("%c detected! Executing response actions...", detected_char);
//                 // RespondToDetection(...);
//             } else {
//                 MicroPrintf("%c detected.", detected_char);
//             }
//         }
//     }
// }