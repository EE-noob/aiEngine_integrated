# 图表数据摘要

## fig11_tops_param_curve
| 阵列边长 | IA cache 分块数 | 任务总周期 | NPU 执行周期 | 理论峰值 TOPS@200MHz |
| --- | --- | --- | --- | --- |
| 36 | 4 | 157168 | 3600 | 0.5184 |
| 40 | 4 | 157552 | 3984 | 0.64 |
| 44 | 4 | 157976 | 4408 | 0.7744 |
| 48 | 4 | 158440 | 4872 | 0.9216 |
| 50 | 4 | 158396 | 4828 | 1.0 |

## fig12_inference_time_compare
| 模型 | 硬件 Invoke 平均周期 | 软件 Invoke 平均周期 | 加速比 |
| --- | --- | --- | --- |
| MNIST MLP | 443903 | 44126602 | 99.4 |
| MNIST CNN | 4198745 | 60410324 | 14.39 |

## fig13_accuracy_compare
| 模型 | 浮点测试集准确率 | 样本级运行正确率 |
| --- | --- | --- |
| MNIST MLP | 96.93 | 100.0 |
| MNIST CNN | 97.74 | 100.0 |

## fig14_bus_util_curve
| 配置 | 读 beat/active | 写 beat/active |
| --- | --- | --- |
| 4x4
IA分块=256 | 6.8 | 0.75 |
| 8x8
IA分块=64 | 16.78 | 2.79 |
| 16x16
IA分块=16 | 44.85 | 7.44 |
| 32x32
IA分块=4 | 49.26 | 5.44 |

## fig15_npu_compute_util_bar
| 模型 | MMA active GOPS | 阵列利用率 |
| --- | --- | --- |
| MNIST MLP | 0.611 | 0.6 |
| MNIST CNN | 2.0281 | 1.98 |

## fig16_coverage_histogram
| 指标 | 百分比 |
| --- | --- |
| 功能覆盖率 | 100.0 |
| URG group | 0.0 |
| URG overall | 0.0 |
