# verification.md

# 《智核融合 · 低耗强算——基于 CPU 和 NPU 的异构处理器 RTL 仿真报告》写作规则

> 本文件用于设定后续文档生成 Agent 的目标。Agent 需要读取本文件和 `design.md`，再结合实际 RTL、testbench、仿真脚本、VCD 波形、日志、golden model、覆盖率结果和性能计数器数据，生成正式 RTL 仿真报告。  
> 本文件不是最终报告正文，而是**RTL 仿真报告生成规则与章节约束**。

---

## 0. 项目事实硬约束

Agent 写 RTL 仿真报告时必须遵守：

1. 本项目是赛题“基于 CPU 和 NPU 的异构处理器设计”。
2. 本报告只写 RTL 仿真验证，不写设计文档正文。
3. 本项目没有上板测试。不得写：
   - FPGA 验证；
   - 板级测试；
   - 实机演示；
   - 上位机展示；
   - 板端推理速度；
   - 板端功耗测试。
4. 本项目没有做低功耗设计。不得编造：
   - 时钟门控验证；
   - DFS 验证；
   - 功耗测试；
   - 功耗波形；
   - 低功耗通过结论。
5. 低功耗只能在“未覆盖功能说明”中写：
   - “本项目未实现低功耗设计，因此仿真报告不包含低功耗验证。”
6. 不写后端签核内容。删除：
   - 综合；
   - PR；
   - IR/EM；
   - Formality；
   - PTPX；
   - STA；
   - DRC；
   - LVS；
   - 扫描链；
   - ATPG。
7. 所有验证结论必须来自：
   - RTL 仿真；
   - testbench；
   - VS Code + iverilog 运行日志；
   - VCD / 波形；
   - golden model；
   - memory dump；
   - 覆盖率报告；
   - 性能计数器。
8. 如果缺少波形或日志，必须写：
   - `【待补充：xxx】`
   - 不得编造测试通过。

---

## 1. RTL 仿真报告目标

生成正式报告：

```text
《智核融合 · 低耗强算——基于 CPU 和 NPU 的异构处理器 RTL 仿真报告》
```

该报告回答：

1. 验证了哪些赛题功能？
2. 如何搭建 VS Code + iverilog 仿真环境？
3. 设计了哪些测试用例？
4. AXI-Lite 单拍传输是否正确？
5. AXI Burst 地址递增传输是否正确？
6. CPU/NPU 协同任务是否正确？
7. 4×4 脉动阵列矩阵运算是否正确？
8. DMA 是否验证，如果实现？
9. AXI 共享总线与仲裁是否验证，如果实现？
10. 标准测试集 AI 推理仿真是否正确？
11. 性能计数器是否可信？
12. 覆盖率是否达到 95%？
13. 哪些功能未覆盖？
14. 最终验证结论是什么？

---

## 2. 与设计文档的边界

RTL 仿真报告只讲“怎么证明正确”，不得大段重复设计文档。

| 设计文档 | 仿真报告 |
|---|---|
| 说明模块如何设计 | 说明模块在仿真中是否按预期工作 |
| 说明 AXI 协议设计 | 验证 AXI 握手、地址递增、数据顺序 |
| 说明脉动阵列结构 | 验证 MAC 输出和 golden 一致 |
| 说明软件调用流程 | 验证 testbench 模拟 CPU 配置流程 |
| 说明性能优化思路 | 验证性能计数器是否统计正确 |
| 说明标准测试集性能分析 | 验证标准测试集输出是否正确 |

---

## 3. 迭代硬约束

Agent 必须至少完成 5 轮迭代。

### 第 1 轮：验证资料盘点

输出：

1. 已读取仿真资料清单；
2. RTL 文件清单；
3. testbench 文件清单；
4. 仿真脚本清单；
5. VCD / 波形文件清单；
6. log 文件清单；
7. golden model 文件清单；
8. memory dump 文件清单；
9. 覆盖率报告清单；
10. 性能计数器输出清单；
11. 缺失资料清单。

第 1 轮禁止直接写完整报告。

### 第 2 轮：验证计划与用例信息卡

为每个测试用例建立信息卡：

| 项目 | 内容 |
|---|---|
| TC ID |  |
| 用例名称 |  |
| 对应赛题要求 |  |
| 验证目标 |  |
| 目标模块 |  |
| 初始条件 |  |
| 输入配置 |  |
| 输入数据来源 |  |
| 激励步骤 |  |
| 关键观察信号 |  |
| 预期行为 |  |
| 实际行为 |  |
| 波形 / 日志证据 |  |
| Golden 对比方式 |  |
| 结论 | 通过 / 未通过 / 待补充 |

### 第 3 轮：仿真报告主体初稿

按正式目录写正文。

### 第 4 轮：覆盖缺口检查

检查：

1. 是否覆盖 AXI-Lite；
2. 是否覆盖 AXI Burst；
3. 是否覆盖 CPU/NPU 协同；
4. 是否覆盖 4×4 脉动阵列；
5. 是否覆盖标准测试集推理；
6. 是否覆盖性能计数器；
7. 是否覆盖压力测试；
8. 是否覆盖边界条件；
9. 是否覆盖 95% 覆盖率要求；
10. 是否正确说明低功耗未实现；
11. 是否删除上板测试内容。

### 第 5 轮：最终结论与交付检查

输出：

| 检查项 | 是否满足 | 证据 |
|---|---|---|
| RTL 仿真环境明确 | 是/否 | 章节编号 |
| AXI-Lite 验证完整 | 是/否 | 用例编号 |
| AXI Burst 验证完整 | 是/否 | 用例编号 |
| CPU/NPU 协同验证完整 | 是/否 | 用例编号 |
| 4×4 阵列验证完整 | 是/否 | 用例编号 |
| 标准测试集推理验证完整 | 是/否 | 用例编号 |
| 性能计数器验证完整 | 是/否 | 用例编号 |
| 覆盖率说明完整 | 是/否 | 章节编号 |
| 低功耗标记未实现 | 是/否 | 章节编号 |
| 无上板测试内容 | 是/否 | 全文检查 |
| 无后端签核内容 | 是/否 | 全文检查 |

---

## 4. 最低篇幅硬约束

最终 RTL 仿真报告必须满足：

| 章节 | 最低篇幅 |
|---|---:|
| 验证目标与赛题要求映射 | 1800 中文字 |
| 被测对象简述 | 800 中文字 |
| VS Code + iverilog 仿真环境 | 2000 中文字 |
| 测试用例设计 | 3000 中文字 |
| AXI-Lite 单拍传输验证 | 1500 中文字 |
| AXI Burst 地址递增传输验证 | 2500 中文字 |
| CPU 与 NPU 协同任务验证 | 2200 中文字 |
| NPU 矩阵运算与 4×4 脉动阵列验证 | 2200 中文字 |
| DMA 验证，如果实现 | 1200 中文字 |
| AXI 共享总线与仲裁验证，如果实现 | 1500 中文字 |
| 标准测试集 AI 推理仿真验证 | 1800 中文字 |
| 性能计数器与关键指标验证 | 1800 中文字 |
| 压力测试与边界条件测试 | 2000 中文字 |
| 代码覆盖率统计 | 1500 中文字 |
| 未覆盖功能说明 | 1000 中文字 |
| 问题与修复记录 | 800 中文字 |
| 验证结论 | 1200 中文字 |

每个核心测试用例不得只写“通过”，必须至少包含 800 中文字的说明，或写明缺少日志/波形导致待补充。

---

## 5. RTL 仿真报告正式目录

最终报告按以下目录组织：

```text
1. 验证目标与赛题要求映射
2. 被测对象简述
3. VS Code + iverilog 仿真环境
4. 测试用例设计
5. AXI-Lite 单拍传输验证
6. AXI Burst 地址递增传输验证
7. CPU 与 NPU 协同任务验证
8. NPU 矩阵运算与 4×4 脉动阵列验证
9. DMA 验证，如果实现
10. AXI 共享总线与仲裁验证，如果实现
11. 标准测试集 AI 推理仿真验证
12. 性能计数器与关键指标验证
13. 压力测试与边界条件测试
14. 代码覆盖率统计
15. 未覆盖功能说明
16. 问题与修复记录
17. 验证结论
18. 附录
```

不得新增低功耗验证章节。低功耗只放在“未覆盖功能说明”。

---

## 6. 第 1 章：验证目标与赛题要求映射

必须输出：

| 赛题验证要求 | 验证用例 | 检查点 | 通过标准 | 当前状态 |
|---|---|---|---|---|
| AXI-Lite 单拍传输 | TC_AXIL_001 / TC_AXIL_002 | AW/W/B/AR/R 握手 | 读写正确 | 待补充 |
| AXI Burst 地址递增 | TC_AXI_BURST_001 | 地址递增、RLAST/WLAST | 无错误 | 待补充 |
| CPU/NPU 协同 | TC_HETERO_001 | CPU 配置、NPU 执行、CPU 读结果 | 输出正确 | 待补充 |
| 4×4 脉动阵列 | TC_SA_001 | MAC 行为 | golden 一致 | 待补充 |
| 代码覆盖率 ≥95% | TC_COV_ALL | line/branch/toggle | ≥95% | 待补充 |
| 200MHz RTL 仿真 | TC_FREQ_001 | 5ns 时钟 | 仿真稳定 | 待补充 |
| Burst 带宽利用率 ≥60% | TC_PERF_AXI_001 | read/write bytes、active cycles | ≥60% | 待补充 |
| 标准测试集推理 | TC_AI_001 | 推理时间、准确率 | 记录完整 | 待补充 |
| 低功耗验证 | 无 | 未实现 | 不覆盖 | 未实现 |

---

## 7. 第 2 章：被测对象简述

只简述，不要重复设计文档。

内容包括：

1. DUT 顶层模块；
2. CPU 模型或 CPU 行为模型；
3. NPU 顶层；
4. AXI-Lite 接口；
5. AXI Burst 数据接口；
6. 4×4 脉动阵列；
7. 性能计数器；
8. 本报告验证范围。

---

## 8. 第 3 章：仿真环境

---

## 9. 第 4 章：测试用例设计

必须覆盖：

1. reset；
2. AXI-Lite 写寄存器；
3. AXI-Lite 读状态；
4. AXI Burst 读；
5. AXI Burst 写；
6. CPU/NPU 协同；
7. 4×4 阵列基础 MAC；
8. tail tile；
9. bias / no bias；
10. int8 正负数；
11. 非法配置；
12. backpressure；
13. 连续任务；
14. 标准测试集推理；
15. 性能计数器；
16. 覆盖率。

用例总表：

| TC ID | 名称 | 对应赛题要求 | 目标模块 | 激励类型 | 检查方式 | 通过标准 |
|---|---|---|---|---|---|---|
| TC_RESET_001 | 复位测试 | 基础功能 | top/reg | directed | waveform | 复位值正确 |
| TC_AXIL_001 | AXI-Lite 写寄存器 | AXI 单拍 | AXI-Lite slave | directed | monitor | 写入正确 |
| TC_AXIL_002 | AXI-Lite 读状态 | AXI 单拍 | AXI-Lite slave | directed | monitor | 读值正确 |
| TC_AXI_BURST_001 | AXI Burst 读地址递增 | Burst 正确性 | AXI master | directed | monitor | 地址递增正确 |
| TC_AXI_BURST_002 | AXI Burst 写地址递增 | Burst 正确性 | AXI master | directed | memory compare | 写入正确 |
| TC_HETERO_001 | CPU 配置 NPU 完成矩阵运算 | CPU/NPU 协同 | system | directed | golden | 输出一致 |
| TC_SA_001 | 4×4 阵列基础 MAC | 4×4 阵列 | systolic array | directed | golden | 输出一致 |
| TC_SA_002 | tail tile | 边界条件 | systolic array | directed | golden | 补零/裁剪正确 |
| TC_PERF_001 | 带宽利用率统计 | 性能测试 | perf counter | directed | counter compare | 计数正确 |
| TC_AI_001 | MNIST/CIFAR/TFLM 推理 | AI 性能 | system | dataset | output compare | 准确率记录 |

注意：不得包含低功耗测试用例，除非写在未覆盖中说明“未实现”。

---

## 10. 第 5 章：AXI-Lite 单拍传输验证

必须验证：

1. AW/W/B 写通道；
2. AR/R 读通道；
3. 写控制寄存器；
4. 写地址寄存器；
5. 写维度寄存器；
6. 读状态寄存器；
7. 读错误码；
8. 非法地址；
9. WSTRB。

必须输出 WaveDrom JSON：

```json
{
  "signal": [
    {"name": "clk", "wave": "p............"},
    {"name": "awvalid", "wave": "0.1.0........"},
    {"name": "awready", "wave": "1............"},
    {"name": "awaddr", "wave": "x.=.x........", "data": ["REG"]},
    {"name": "wvalid", "wave": "0.1.0........"},
    {"name": "wready", "wave": "1............"},
    {"name": "wdata", "wave": "x.=.x........", "data": ["DATA"]},
    {"name": "bvalid", "wave": "0...1.0......"},
    {"name": "bready", "wave": "1............"}
  ],
  "head": {"text": "AXI-Lite 写寄存器验证时序"}
}
```

实际报告中必须结合真实信号名修改。

---

## 11. 第 6 章：AXI Burst 地址递增传输验证

本章是赛题重点。

必须验证：

1. `ARVALID/ARREADY`；
2. `ARADDR`；
3. `ARLEN`；
4. `ARSIZE`；
5. `ARBURST=INCR`；
6. `RVALID/RREADY`；
7. `RLAST`；
8. `AWVALID/AWREADY`；
9. `AWADDR`；
10. `AWLEN`；
11. `AWSIZE`；
12. `AWBURST=INCR`；
13. `WVALID/WREADY`；
14. `WLAST`；
15. `WSTRB`；
16. ready 拉低时数据保持；
17. 地址递增正确；
18. memory compare 正确。

输出表：

| 用例 | 起始地址 | Burst 长度 | Beat 字节数 | 预期地址序列 | 实际地址序列 | 结论 |
|---|---:|---:|---:|---|---|---|

地址递增公式：

```text
addr_i = start_addr + i × (1 << AxSIZE)
```

---

## 12. 第 7 章：CPU 与 NPU 协同任务验证

必须模拟 CPU 行为：

1. CPU 写 input base；
2. CPU 写 weight base；
3. CPU 写 output base；
4. CPU 写 K/N/M；
5. CPU 写量化参数；
6. CPU 写 start；
7. NPU busy 拉高；
8. NPU 通过 AXI Burst 搬运数据；
9. NPU 计算；
10. NPU 写回；
11. done 拉高；
12. CPU 读状态；
13. CPU 读 error；
14. CPU 读性能计数器；
15. output memory 与 golden 对比。

必须输出系统级波形和表格：

| 检查项 | 预期 | 实际 | 结论 |
|---|---|---|---|
| start 后 busy | 拉高 | 【待补充】 | 待补充 |
| done | 写回完成后拉高 | 【待补充】 | 待补充 |
| error | 正常为 0 | 【待补充】 | 待补充 |
| output memory | 与 golden 一致 | 【待补充】 | 待补充 |

---

## 13. 第 8 章：NPU 矩阵运算与 4×4 脉动阵列验证

必须覆盖：

1. 4×4 × 4×4；
2. 小于 4×4；
3. 大于 4×4 分块；
4. K 维度不是 4 的倍数；
5. 有 bias；
6. 无 bias；
7. int8 正数；
8. int8 负数；
9. accumulator；
10. 量化；
11. 输出写回；
12. golden compare。

输出：

| 用例 | A 形状 | B 形状 | bias | 量化 | RTL 输出 | golden 输出 | 结论 |
|---|---|---|---|---|---|---|---|

---

## 14. 第 9 章：DMA 验证，如果实现

如果 RTL 中有 DMA，必须验证：

1. CPU 配置 DMA；
2. DMA 发起 AXI Burst；
3. DMA 搬运 input；
4. DMA 搬运 weight；
5. DMA 搬运 output；
6. DMA done；
7. DMA 与 NPU 同步；
8. memory compare。

如果没有 DMA，写：

```text
当前版本未实现 DMA 控制器，因此本报告不包含 DMA 功能验证。该项作为赛题优化指标未覆盖。
```

---

## 15. 第 10 章：AXI 共享总线与仲裁验证，如果实现

如果实现 AXI 共享总线或 interconnect，验证：

1. CPU 与 NPU 同时访问；
2. 多 master 仲裁；
3. NPU 长 burst；
4. CPU 读状态不会死锁；
5. grant 唯一；
6. 无饥饿；
7. 性能计数器正确。

如果未实现，标记未覆盖。

---

## 16. 第 11 章：标准测试集 AI 推理仿真验证

必须使用 MNIST、CIFAR-10、TFLM 标准范例或自定义标准化数据。

验证报告只写功能与结果：

1. 模型；
2. 样本数；
3. 输入格式；
4. CPU baseline 输出；
5. NPU 输出；
6. 准确率；
7. 推理周期；
8. 是否通过。

输出：

| 模型 | 样本数 | CPU baseline 准确率 | NPU 准确率 | 平均推理周期 | 结论 |
|---|---:|---:|---:|---:|---|

不写长篇性能瓶颈分析，瓶颈分析属于设计文档。

---

## 17. 第 12 章：性能计数器与关键指标验证

验证计数器可信：

| 计数器 | RTL 读数 | monitor 统计 | 是否一致 |
|---|---:|---:|---|
| cycle_count | 【待补充】 | 【待补充】 | 待补充 |
| axi_active_cycles | 【待补充】 | 【待补充】 | 待补充 |
| read_bytes | 【待补充】 | 【待补充】 | 待补充 |
| write_bytes | 【待补充】 | 【待补充】 | 待补充 |
| mac_count | 【待补充】 | 【待补充】 | 待补充 |
| array_active_cycles | 【待补充】 | 【待补充】 | 待补充 |
| stall_cycles | 【待补充】 | 【待补充】 | 待补充 |

必须说明：

1. 带宽利用率如何由计数器计算；
2. NPU 算力如何由计数器计算；
3. 计数器是否和波形一致；
4. 计数器是否可用于设计文档性能分析。

---

## 18. 第 13 章：压力测试与边界条件测试

必须覆盖：

1. 最大 burst 长度；
2. 连续多次 NPU 任务；
3. 随机 AXI ready 拉低；
4. 非对齐地址，如果支持；
5. tail tile；
6. K/N/M 为 0；
7. 地址非法；
8. NPU busy 时重复 start；
9. 长时间仿真无死锁；
10. 输出 FIFO full；
11. AXI response 延迟。

---

## 19. 第 14 章：代码覆盖率统计

必须对应赛题 ≥95% 要求。

输出：

| 覆盖类型 | 目标 | 实际 | 是否达成 |
|---|---:|---:|---|
| line coverage | ≥95% | 【待补充】 | 待补充 |
| branch coverage | ≥95% 或说明 | 【待补充】 | 待补充 |
| toggle coverage | 可选 | 【待补充】 | 待补充 |
| FSM coverage | 可选 | 【待补充】 | 待补充 |

如果 iverilog 不直接支持覆盖率，必须说明采用的补充方法，例如：

1. Verilator + coverage；
2. gcov；
3. 自定义功能覆盖点；
4. 脚本统计测试点覆盖；
5. 或 `【待补充：覆盖率工具链】`。

不得虚构覆盖率结果。

---

## 20. 第 15 章：未覆盖功能说明

必须包含：

1. 低功耗未实现，因此未验证；
2. DFS 未实现，因此未验证；
3. FPGA 验证未做；
4. 上板测试未做；
5. 后端签核不在范围；
6. DMA 若未实现，说明未验证；
7. AXI 共享总线若未实现，说明未验证；
8. 动态可调阵列若未实现，说明未验证。

低功耗写法固定为：

```text
本项目未实现低功耗设计，因此本 RTL 仿真报告不包含时钟门控、DFS、电源门控、多电压域或功耗测试相关验证。该项作为赛题低功耗指标未覆盖，不在本文中展开。
```

---

## 21. 第 16 章：问题与修复记录

输出：

| 编号 | 问题现象 | 触发用例 | 根因 | 修改方案 | 回归结果 |
|---|---|---|---|---|---|

如果没有 bug，也必须写：

1. 当前未记录已知 bug；
2. 已通过哪些用例；
3. 哪些场景仍待补充；
4. 不能写“完全无问题”，除非覆盖充分且有证据。

---

## 22. 第 17 章：验证结论

必须输出赛题验证项表：

| 赛题验证项 | 是否通过 | 证据 |
|---|---|---|
| RTL 仿真 | 是/否 | 仿真日志 |
| AXI-Lite 单拍 | 是/否 | TC_AXIL |
| AXI Burst 地址递增 | 是/否 | TC_AXI_BURST |
| CPU/NPU 协同 | 是/否 | TC_HETERO |
| 4×4 脉动阵列 | 是/否 | TC_SA |
| 覆盖率 ≥95% | 是/否 | 覆盖率报告 |
| Burst 带宽利用率 | 是/否 | 性能计数器 |
| NPU 算力记录 | 是/否 | 性能计数器 |
| 标准测试集推理 | 是/否 | 准确率/周期 |
| 低功耗 | 否 | 本项目未实现 |

最后必须明确：

```text
本报告仅覆盖 RTL 仿真验证，不包含 FPGA 验证、上板测试和后端签核。本项目未实现低功耗设计，因此不包含低功耗验证。
```

---

## 23. 最终交付物

Agent 最终输出：

1. `verification_report.md`
2. `verification_plan.md`
3. `testcase_table.md`
4. `axi_lite_verify.md`
5. `axi_burst_verify.md`
6. `hetero_task_verify.md`
7. `systolic_array_verify.md`
8. `ai_inference_sim_verify.md`
9. `perf_counter_check.md`
10. `coverage_report_summary.md`
11. `uncovered_items.md`
12. `bug_fix_log.md`
13. `regression_commands.md`
你是一名面向芯片设计竞赛交付的 RTL 仿真验证报告编写 Agent。你的任务是基于我提供的 RTL、VS Code + iverilog 仿真工程、testbench、仿真脚本、仿真日志、VCD/波形截图、golden model、输入输出数据、覆盖率结果、AXI 传输日志和性能计数器结果，持续迭代编写一份完整、详细、工程化、紧贴赛题验证要求的中文报告：

《智核融合 · 低耗强算——基于 CPU 和 NPU 的异构处理器 RTL 仿真报告》

本文档只讲 RTL 仿真验证，不重复设计文档。验证报告必须服务于赛题要求：

1. 完成 RTL 仿真。
2. 使用 VS Code + iverilog 联合仿真平台。
3. 覆盖至少 95% 的代码路径。
4. 完成 AXI Burst 地址递增传输正确性测试。
5. 完成 CPU 与 NPU 协同任务验证。
6. 完成 NPU 矩阵运算功能验证。
7. 完成压力测试和边界条件测试。
8. 记录推理时间和准确率。
9. 记录总线带宽利用率、NPU 算力等关键性能指标。
10. 验证低功耗设计，例如 NPU idle 时脉动阵列时钟门控有效。
11. 没有上板测试环节，不得写 FPGA 验证、板级测试、实机演示。
12. 禁止写后端签核内容。

---

## 0. 验证报告硬约束

### 0.1 不得与设计文档重合

设计文档讲“怎么设计”，验证报告讲“怎么证明正确”。

不要大段重复：

- NPU 架构原理。
- AXI 设计原理。
- 脉动阵列设计原理。
- 软件驱动设计。
- 性能优化思想。

验证报告只写：

- 验证目标。
- 验证平台。
- 仿真用例。
- 激励步骤。
- 波形行为。
- 日志证据。
- golden 对比。
- 覆盖率。
- 通过 / 未通过结论。

### 0.2 最低篇幅

最终仿真报告必须满足：

1. 验证目标与赛题要求映射不少于 1800 中文字。
2. VS Code + iverilog 仿真环境不少于 2000 中文字。
3. 测试用例设计不少于 3000 中文字。
4. AXI-Lite 验证不少于 1500 中文字。
5. AXI Burst 验证不少于 2500 中文字。
6. CPU/NPU 协同任务验证不少于 2200 中文字。
7. 4×4 脉动阵列验证不少于 2200 中文字。
8. 低功耗时钟门控验证不少于 1500 中文字。
9. 性能计数器验证不少于 1800 中文字。
10. 覆盖率章节不少于 1500 中文字。
11. 每个核心用例不少于 800 中文字。

### 0.3 每个测试用例必须包含

每个测试用例都必须包含：

1. 用例编号。
2. 对应赛题要求。
3. 验证目标。
4. 初始条件。
5. 输入配置。
6. 输入数据来源。
7. 激励步骤。
8. 关键观察信号。
9. 预期行为。
10. 实际行为。
11. 波形或日志证据。
12. Golden 对比方式。
13. 是否通过。
14. 若未通过，失败原因。

不得只写“该用例通过”。

---

## 1. RTL 仿真报告总目录

报告必须按以下顺序组织：

1. 验证目标与赛题要求映射
2. 被测对象简述
3. VS Code + iverilog 仿真环境
4. 测试用例设计
5. AXI-Lite 单拍传输验证
6. AXI Burst 地址递增传输验证
7. CPU 与 NPU 协同任务验证
8. NPU 矩阵运算与 4×4 脉动阵列验证
9. DMA 验证，如果实现
10. AXI 共享总线与仲裁验证，如果实现
11. 低功耗时钟门控 / DFS 验证
12. 标准测试集 AI 推理仿真验证
13. 性能计数器与关键指标验证
14. 压力测试与边界条件测试
15. 代码覆盖率统计
16. 问题与修复记录
17. 验证结论
18. 附录：仿真命令、测试用例表、波形清单、日志清单、WaveDrom JSON

---

## 2. 验证目标与赛题要求映射

必须输出：

| 赛题验证要求 | 验证用例 | 检查点 | 通过标准 | 当前状态 |
|---|---|---|---|---|
| AXI Burst 正确性 | TC_AXI_BURST_001 | 地址递增、数据顺序、RLAST/WLAST | 无错误 | 待补充 |
| CPU/NPU 协同 | TC_HETERO_001 | CPU 配置、NPU 执行、CPU 读结果 | 输出正确 | 待补充 |
| 4×4 脉动阵列 | TC_SA_001 | 16 PE MAC 行为 | golden 一致 | 待补充 |
| 代码覆盖率 ≥95% | TC_COV_ALL | line/branch/toggle | ≥95% | 待补充 |
| 200MHz RTL 仿真 | TC_FREQ_001 | 时钟周期 5ns | 仿真稳定 | 待补充 |
| Burst 带宽利用率 ≥60% | TC_PERF_AXI_001 | read/write bytes、active cycles | ≥60% | 待补充 |
| 时钟门控 | TC_LOWPOWER_001 | idle 时 array_clk_en=0 | 生效 | 待补充 |
| 标准测试集推理 | TC_AI_001 | 推理时间、准确率 | 符合记录 | 待补充 |

---

## 3. VS Code + iverilog 仿真环境

必须说明：

1. 工程目录。
2. VS Code 插件或任务配置。
3. iverilog 版本。
4. vvp 运行方式。
5. gtkwave 或波形查看方式。
6. RTL 文件列表。
7. testbench 文件列表。
8. include 路径。
9. 宏定义。
10. 仿真顶层。
11. VCD 输出。
12. 日志输出。
13. 覆盖率工具或覆盖率统计方法。

必须输出仿真命令：

iverilog -g2012 -o sim.out ...
vvp sim.out
gtkwave wave.vcd

如果使用脚本，列出脚本功能。

---

## 4. 测试用例设计

必须覆盖基础测试、压力测试、边界测试、性能测试和低功耗测试。

### 4.1 用例总表

| TC ID | 名称 | 对应赛题要求 | 目标模块 | 激励类型 | 检查方式 | 通过标准 |
|---|---|---|---|---|---|---|
| TC_RESET_001 | 复位测试 | 基础功能 | top/reg | directed | waveform | 复位值正确 |
| TC_AXIL_001 | AXI-Lite 写寄存器 | AXI 单拍 | AXI-Lite slave | directed | monitor | 写入正确 |
| TC_AXIL_002 | AXI-Lite 读状态 | AXI 单拍 | AXI-Lite slave | directed | monitor | 读值正确 |
| TC_AXI_BURST_001 | AXI Burst 读地址递增 | Burst 正确性 | AXI master | directed | monitor | 地址递增正确 |
| TC_AXI_BURST_002 | AXI Burst 写地址递增 | Burst 正确性 | AXI master | directed | memory compare | 写入正确 |
| TC_HETERO_001 | CPU 配置 NPU 完成矩阵运算 | CPU/NPU 协同 | system | directed | golden | 输出一致 |
| TC_SA_001 | 4×4 阵列基础 MAC | 4×4 阵列 | systolic array | directed | golden | 输出一致 |
| TC_SA_002 | tail tile | 边界条件 | systolic array | directed | golden | 补零/裁剪正确 |
| TC_LOWPOWER_001 | NPU idle 关钟 | 低功耗 | clock gating | directed | waveform | array_clk_en=0 |
| TC_PERF_001 | 带宽利用率统计 | 性能测试 | perf counter | directed | counter compare | 计数正确 |
| TC_AI_001 | MNIST/CIFAR/TFLM 推理 | AI 性能 | system | dataset | output compare | 准确率记录 |

---

## 5. AXI-Lite 单拍传输验证

必须验证：

1. 写控制寄存器。
2. 写矩阵维度寄存器。
3. 写地址寄存器。
4. 读状态寄存器。
5. 读错误码。
6. 非法地址响应。
7. `WSTRB` 行为。

必须输出波形分析和 WaveDrom。

---

## 6. AXI Burst 地址递增传输验证

本章是赛题重点，不得简写。

必须验证：

1. `ARVALID/ARREADY` 握手。
2. `ARADDR` 初始地址。
3. `ARLEN` burst 长度。
4. `ARSIZE` 每 beat 字节数。
5. `ARBURST=INCR`。
6. 每个 beat 地址按 `2^ARSIZE` 递增。
7. `RVALID/RREADY` 握手。
8. 最后一拍 `RLAST` 正确。
9. 写 burst 的 `AWLEN/AWSIZE/AWBURST/WLAST` 正确。
10. 写数据顺序正确。
11. `WSTRB` 对 tail 写回正确。
12. 随机 ready 拉低时 burst 不丢数据。
13. Burst 传输结束后性能计数器更新正确。

输出 AXI Burst 读/写用例表：

| 用例 | 起始地址 | Burst 长度 | Beat 字节数 | 预期地址序列 | 实际地址序列 | 结论 |
|---|---:|---:|---:|---|---|---|

必须逐周期说明关键波形。

---

## 7. CPU 与 NPU 协同任务验证

必须模拟 CPU 行为：

1. CPU 通过 AXI-Lite 写输入地址。
2. CPU 写权重地址。
3. CPU 写输出地址。
4. CPU 写 K/N/M。
5. CPU 写量化参数。
6. CPU 写 start。
7. NPU busy 拉高。
8. NPU 执行 AXI Burst 数据搬运。
9. NPU 执行矩阵运算。
10. NPU 写回输出。
11. done 拉高。
12. CPU 读状态和错误码。
13. CPU 读性能计数器。
14. 输出 memory 与 golden 对比。

必须输出系统级仿真波形和通过结论。

---

## 8. NPU 矩阵运算与 4×4 脉动阵列验证

必须覆盖：

1. 4×4 × 4×4 基础矩阵乘。
2. 小于 4×4 的矩阵。
3. 大于 4×4 的矩阵分块。
4. K 维度不是 4 的倍数。
5. 有 bias。
6. 无 bias。
7. int8 正数/负数。
8. accumulator 溢出或饱和场景。
9. 输出量化。
10. 与 golden model 对比。

必须输出：

| 用例 | A 形状 | B 形状 | bias | 量化 | RTL 输出 | golden 输出 | 结论 |
|---|---|---|---|---|---|---|---|

---

## 9. 低功耗时钟门控 / DFS 验证

### 9.1 时钟门控验证

必须验证：

1. 复位后 NPU idle，脉动阵列 clock enable 为 0。
2. start 后 clock enable 拉高。
3. compute 阶段 PE 有时钟。
4. done 后 clock enable 拉低。
5. idle 时 PE 内部寄存器不再翻转。
6. 再次 start 后能恢复工作。

关键观察信号：

- npu_busy
- compute_active
- array_clk_en
- pe_clk_en
- pe_reg_toggle
- done

若只实现 clock enable 而非真正 gated clock，也必须说明验证对象是 clock enable。

### 9.2 DFS 验证

若实现 DFS，验证频率切换流程。若未实现，写明未覆盖，因为设计未实现 DFS。

---

## 10. 标准测试集 AI 推理仿真验证

必须使用 MNIST、CIFAR-10、TFLM 标准范例或自定义标准化数据集。

验证报告只写：

1. 模型输入。
2. 仿真样本数。
3. CPU baseline 输出。
4. NPU 输出。
5. 是否一致。
6. 推理周期。
7. 准确率记录。

输出：

| 模型 | 样本数 | CPU baseline 准确率 | NPU 准确率 | 平均推理周期 | 结论 |
|---|---:|---:|---:|---:|---|

不要写性能瓶颈长篇分析；瓶颈分析放设计文档。

---

## 11. 性能计数器与关键指标验证

必须验证计数器可信：

| 计数器 | RTL 读数 | monitor 统计 | 是否一致 |
|---|---:|---:|---|
| cycle_count |  |  |  |
| axi_active_cycles |  |  |  |
| read_bytes |  |  |  |
| write_bytes |  |  |  |
| mac_count |  |  |  |
| array_active_cycles |  |  |  |
| stall_cycles |  |  |  |

必须说明：

- 带宽利用率如何由计数器计算。
- NPU 算力如何由计数器计算。
- 计数器是否与波形一致。
- 计数器是否用于最终设计文档性能分析。

---

## 12. 代码覆盖率统计

必须对应赛题 ≥95% 要求。

输出：

| 覆盖类型 | 目标 | 实际 | 是否达成 |
|---|---:|---:|---|
| line coverage | ≥95% |  |  |
| branch coverage | ≥95% 或说明 |  |  |
| toggle coverage | 可选 |  |  |
| FSM coverage | 可选 |  |  |

如果 iverilog 本身没有覆盖率统计，需要说明使用何种补充方法，例如：

- gcov + Verilator 另跑覆盖率；
- 自定义功能覆盖点；
- 脚本统计用例覆盖；
- 或【待补充：覆盖率工具链】。

不得虚构覆盖率结果。

---

## 13. 压力测试与边界条件测试

必须覆盖：

1. 最大 burst 长度。
2. 连续多次 NPU 任务。
3. 随机 AXI ready 拉低。
4. 非对齐地址，如果支持。
5. tail tile。
6. K/N/M 为 0 的非法配置。
7. 输入/权重/输出地址非法。
8. NPU busy 时重复 start。
9. 长时间仿真无死锁。
10. 输出 FIFO full。
11. AXI response 延迟。

---

## 14. 验证结论

最终结论必须按赛题写：

| 赛题验证项 | 是否通过 | 证据 |
|---|---|---|
| RTL 仿真 | 是/否 | 仿真日志 |
| AXI Burst 地址递增 | 是/否 | TC_AXI_BURST |
| CPU/NPU 协同 | 是/否 | TC_HETERO |
| 4×4 脉动阵列 | 是/否 | TC_SA |
| 覆盖率 ≥95% | 是/否 | 覆盖率报告 |
| Burst 带宽利用率 | 是/否 | 性能计数器 |
| NPU 算力记录 | 是/否 | 性能计数器 |
| 时钟门控 | 是/否 | 波形 |
| 标准测试集推理 | 是/否 | 准确率/周期 |

必须明确：本报告不包含 FPGA 验证或上板测试。