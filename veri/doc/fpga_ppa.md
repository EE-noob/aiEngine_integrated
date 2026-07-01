# 通用 FPGA 时序优化 Skill 与 AI 提示词

## 1. Skill 目标

本 skill 用于指导 AI agent 或 EDA 助手对 FPGA RTL 设计进行系统性的时序优化。目标不是简单修复某一条 worst path，而是在保证功能正确的前提下，从真实硬件结构出发，同时优化 timing、area 和 performance。

FPGA 时序优化必须避免“只看代码、不看硬件结构”的错误。AI 需要理解 RTL 会被综合成什么电路，例如优先级链、宽 mux、加法器链、比较器链、高扇出控制信号、RAM 地址路径、valid/ready 反压路径、flush/stall 控制路径等。优化建议必须围绕这些真实硬件结构展开。

核心目标可以概括为：

* 固定验收口径；
* 清理 RTL 语义问题；
* 对 timing path 进行脚本化去重；
* 按硬件结构聚类路径；
* 找出真正的结构性瓶颈；
* 切断 late data 和 late control 长组合链；
* 局部化高扇出控制；
* 减少不必要 reset、payload 打拍和重复 sideband；
* 用性能指标保护优化收益；
* 最终以 full implementation 或 post-route 结果验收。

---

## 2. 基本原则

### 2.1 固定验收口径

所有 PPA 结论必须来自同一套约束、同一目标频率、同一目标 hierarchy、同一 implementation flow。OOC 综合、局部综合或 early placement 只能作为趋势参考，不能作为最终达标依据。

最终验收应以 full implementation、route 或 post-route physopt 后的结果为准。任何优化结论都需要同时记录 timing、area、performance 和功能验证情况。

---

### 2.2 先修 RTL 语义，再谈 QoR

如果设计中存在综合 warning、隐式 latch、多驱动、位宽截断、未初始化状态、前后仿 mismatch、RAM/FIFO 推断异常等问题，应优先修复这些 RTL 语义问题。

功能语义不稳定时，不应继续讨论时序优化收益。否则 AI 可能会把错误的电路结构当作优化对象，导致后续结论没有意义。

---

### 2.3 从硬件结构理解 RTL

AI 分析 RTL 时不能只看代码形式，而要判断代码会综合成什么硬件。例如：

* 多级 if/else 可能形成 priority chain；
* 大 case 语句可能形成宽 mux tree；
* late data 进入比较器或加法器后可能形成长组合路径；
* flush、stall、CE、reset 可能成为高扇出控制信号；
* valid 和 ready 组合反馈可能形成跨模块反压长链；
* 宽 payload reset 可能引入大量 reset mux；
* 变量移位可能形成 barrel shifter；
* 大量 sideband 字段可能增加 mux、寄存器和布线压力。

优化时应优先描述硬件结构，而不是只描述代码行。

---

### 2.4 使用 Python 脚本对 timing path 去重

在正式分析 timing report 前，应要求 AI 使用 Python 脚本对导出的时序路径进行去重和归并。不要直接拿原始 timing report 的前几十条路径下结论。

FPGA timing report 中经常会出现大量重复路径，例如：

* 同一条 bus 的不同 bit；
* 同一类 lane 的多个副本；
* 同一逻辑在多个实例中的重复展开；
* 同一个高扇出控制信号驱动多个相邻寄存器；
* 同一个宽 mux 的多个等价终点；
* 同一类 RAM address 或 CE 路径被展开成大量近似路径。

如果不去重，AI 很容易误判为存在大量独立问题，实际却只是同一个结构瓶颈被重复展开。

去重时应对路径生成结构化 fingerprint，考虑时钟域、起点、终点、主要层级、主要 cell chain、路径类型、setup/hold 类型、data/control 属性等信息。对于 bus bit、lane 编号、数组下标、复制寄存器造成的重复路径，应合并为同一类，只保留 slack 最差的一条代表路径，同时记录该类路径出现次数。

最终用于分析的应是去重后的代表路径集合，而不是原始 timing report。

---

### 2.5 按路径形态聚类，而不是只看 worst path

时序分析不能只看最差一条路径。应对去重后的路径进行结构聚类，常见类别包括：

* 算术路径：adder、compare、multiplier、divider；
* 宽 mux 路径：operand select、writeback select、case decode；
* late data 路径：迟到数据进入 mux、compare、branch、flush；
* late control 路径：迟到控制信号驱动 datapath 或 CE；
* 高扇出路径：flush、stall、valid、ready、reset、CE；
* memory/address 路径：RAM index、FIFO pointer、AXI address；
* branch/redirect 路径：compare、target、redirect、PC enable；
* ready/valid 反压路径：跨模块 backpressure；
* physical 路径：跨层级、跨区域、布线过长；
* reset/control set 路径：全局 reset 或局部 reset 过宽。

聚类的目的，是找出真正的结构性瓶颈，而不是逐条路径做表面修补。

---

## 3. 标准优化流程

### 3.1 建立基线

优化前必须记录完整基线，包括：

* 目标频率；
* 目标 FPGA 器件；
* 目标 hierarchy；
* timing summary；
* setup 和 hold 情况；
* utilization hierarchy；
* LUT、FF、BRAM、DSP 数量；
* synthesis 和 implementation warnings；
* benchmark 性能；
* cycles、IPC、stall metrics 或项目等价性能指标；
* smoke test、单元测试、系统测试和仿真回归情况。

没有基线，不允许宣称优化有效。

---

### 3.2 导出并去重时序路径

应导出足够数量的 setup 和 hold timing path，然后通过 Python 脚本去重。去重后的结果应包含：

* 每类路径的代表路径；
* 每类路径的最差 slack；
* 每类路径出现次数；
* 主要起点和终点；
* 主要层级模块；
* 主要 cell chain；
* 可能的问题类型；
* 是否属于 data、control、CE、reset、address 或 physical 问题。

AI 后续分析必须基于去重后的代表路径集合。

---

### 3.3 分析路径根因

AI 需要把 timing path 翻译成硬件结构语言。例如不要只写“某寄存器到某寄存器路径超时”，而要说明：

* 是否是 late data 进入宽 mux；
* 是否是 compare 后驱动 branch flush；
* 是否是 load data 当拍参与 forwarding；
* 是否是 WBU 仲裁结果反向影响 dispatch；
* 是否是 ready/valid 形成组合反压；
* 是否是 FIFO count compare 过长；
* 是否是 reset 或 CE fanout 太高；
* 是否是 RAM address 计算链过长；
* 是否是跨层级跨区域布线问题。

只有根因清楚，优化建议才有意义。

---

### 3.4 制定结构性优化方案

优先考虑结构性改法，而不是局部语法改写。常见策略包括：

#### 切断 late data 长组合链

如果数据到达很晚，就不要让它在同一拍继续经过宽 mux、加法器、比较器、branch redirect 或 flush 逻辑。可以考虑增加寄存、拆分阶段、延后一拍消费、使用 bypass bank 或局部 hold register。

#### 局部化高扇出控制

flush、stall、valid、ready、CE、reset、branch redirect 等信号应尽量局部生成、局部寄存、局部解码。不要让一个晚到的全局控制信号直接驱动大量远端寄存器。

#### 分离 data path 和 control path

payload 数据、valid 位、sideband 控制字段应分清用途。通常只需要 reset valid、FSM、pointer、count 和架构必需状态，不应无脑 reset 所有 payload。

#### 压缩 sideband 和控制字段

跨流水级传递的字段越多，mux、寄存器和布线压力越大。能在本地重新生成的字段，不应重复打拍传递。低收益的 debug 字段、兼容字段、冗余字段应删除或用宏开关裁掉。

#### 优化 forwarding、bypass 和 writeback

Forwarding、bypass、writeback 不能混成一条跨级组合链。Forwarding 面向发射前 operand 修正，bypass 面向执行单元内部下一拍消费，writeback 面向架构状态提交。三者应有清晰边界。

#### 正确处理 RAM 和变延时数据

不能伪造同步 RAM 的读延迟，也不能假设 AXI 或 cache data 当拍一定返回。变延时 load 的 valid 必须与真实 data 有一致关系。性能应通过 queue、wake-up、prefetch、bypass bank 或 outstanding 机制优化，而不是破坏硬件语义。

#### 减少 reset 和 control set 压力

过宽 reset 会引入大量 reset mux 和 control set，增加布线压力。对于 FIFO data、pipeline payload、bypass bank data，如果 valid 无效时不会被使用，通常不需要 reset。

#### 用 generate 隔离可选功能

可选功能应在 elaboration 阶段通过 generate 直接裁掉相关寄存器、mux 和控制逻辑，而不是只把输出置零。否则无用结构仍可能存在于综合结果中。

---

### 3.5 验证优化收益

每次修改后都必须验证：

* 功能测试是否通过；
* benchmark 是否退化；
* stall metrics 是否恶化；
* setup timing 是否改善；
* hold timing 是否引入新问题；
* LUT、FF、BRAM、DSP 是否变化；
* 原来的路径是否真正消失；
* 新 worst path 是否只是问题迁移；
* 是否对其他 clock domain 或 hierarchy 造成副作用。

不能只看 WNS 变好，也不能只看面积减少。FPGA 优化必须同时看 timing、area、performance 和功能正确性。

---

## 4. 常见反模式

需要避免以下错误：

* 只看一条 worst path 就下结论；
* 不对 timing path 去重，直接分析原始 report；
* 用 OOC 结果宣称最终达标；
* 为了性能恢复 late data 到 branch/flush 的组合快路径；
* 用约束掩盖 RTL 结构问题；
* 无脑添加 pipeline，导致功能和性能退化；
* reset 所有 payload、FIFO data 和 bypass data；
* 把变延时 RAM 当成固定延时组合读取；
* 把 ready/valid 反压做成跨模块组合长链；
* 只删除代码，不看 utilization hierarchy；
* 只看 benchmark 总分，不看 stall 细节；
* 只优化 setup，不检查 hold；
* 只看综合结果，不跑 implementation；
* 不记录 checkpoint，导致无法回退。

---

## 5. AI Agent 通用提示词

你是一名 FPGA RTL/PPA 优化专家，任务是帮助我对一个 FPGA 设计进行系统性时序优化。你必须从真实硬件结构理解 RTL，而不是只按软件代码或单条 worst path 判断。

优化时请严格遵守以下原则：

1. 先固定验收口径。所有 timing、area、performance 结论必须来自同一目标配置、同一频率约束、同一 hierarchy 和同一 implementation flow。OOC 或综合结果只能作为趋势参考，最终以 full implementation 或 post-route 结果为准。

2. 先检查 RTL 语义问题。若存在综合 warning、隐式 latch、多驱动、位宽异常、前后仿 mismatch、RAM/FIFO 推断异常，应优先修复这些问题，再讨论 QoR。

3. 在分析 timing report 前，必须使用 Python 脚本对 timing path 进行去重和归并。不要直接拿原始 timing report 前几十条路径下结论。去重时要合并 bus bit、lane、副本模块、数组下标、复制寄存器造成的重复路径，只保留每类路径中 slack 最差的代表路径，并记录该类路径出现次数。

4. 对去重后的路径进行结构聚类。请按硬件形态分类，例如算术路径、宽 mux 路径、late data 路径、late control 路径、高扇出 CE/reset/flush 路径、memory/address 路径、ready/valid 反压路径和 physical 布线路径。

5. 分析路径时，必须把路径翻译成硬件结构语言。不要只说某个寄存器到某个寄存器超时，而要指出路径中是否包含 late data、宽 mux、compare、adder、branch redirect、flush、stall、CE、reset、RAM address、FIFO pointer 或跨层级布线。

6. 优化建议必须是结构性改法。优先考虑切断跨级组合长链、局部化高扇出控制、拆分 data/control、压缩 sideband、减少不必要 reset、优化 bypass/forwarding/writeback 边界、修正 RAM 延迟语义、消除冗余 mux 和重复寄存。

7. 不允许为了短期性能分数伪造 RAM 延迟、恢复危险组合快路径、扩大 late data 到 branch/flush 的路径，或引入不可验证的跨模块组合控制。

8. 每次修改必须说明目标、影响范围、预期收益、潜在风险和验证方法。修改后需要同时比较 timing、area、performance、功能测试和 stall metrics。

9. 如果某个优化只是把原来的 worst path 转移到另一个更严重的路径，不能认为优化成功。必须判断结构瓶颈是否真正被消除。

10. 所有建议都要给出 checkpoint 和回退条件。若优化导致功能失败、性能显著退化、面积超标、hold 恶化或新路径不可接受，应回退。

请按以下格式输出你的分析：

* 当前基线；
* timing path 去重结论；
* 主要路径聚类；
* 根因分析；
* 结构性优化方案；
* 可能副作用；
* 验证计划；
* checkpoint 与回退条件；
* 下一步优先级。

核心目标是：固定口径、脚本去重、结构聚类、先修语义、切断 late data/late control 长链、局部化高扇出控制、减少无效 reset 和冗余 sideband、用 stall metrics 保护性能，并最终以 full implementation 结果验收。

---

## 6. 简短版提示词

你是一名 FPGA RTL/PPA 优化专家。请从真实硬件结构出发分析设计，而不是只看代码或单条 worst path。优化前先固定频率、约束、hierarchy 和 implementation flow，并检查综合 warning、仿真一致性、RAM/FIFO 推断和 RTL 语义问题。

分析 timing report 前，必须使用 Python 脚本对 timing path 去重，合并 bus bit、lane、副本模块、数组下标和复制寄存器造成的重复路径，只保留每类 slack 最差的代表路径，并记录出现次数。随后按硬件形态聚类，包括算术路径、宽 mux、late data、late control、高扇出 CE/reset/flush、memory/address、ready/valid 反压和 physical 布线路径。

请把每类路径翻译成硬件结构根因，指出是否存在 late data 经过 mux、compare、branch、flush，或者高扇出控制驱动远端寄存器等问题。优化建议应优先采用结构性改法，包括切断跨级组合长链、局部化控制、拆分 data/control、压缩 sideband、减少 payload reset、优化 forwarding/bypass/writeback 边界，以及修正 RAM 延迟语义。

每次修改后必须比较 timing、area、performance、stall metrics 和功能测试结果。最终只接受 full implementation 或 post-route 结果。若优化只是迁移 worst path、破坏功能、显著降低性能或引入新的 hold/setup 问题，应回退。

---

## 7. 核心记忆

固定口径，先修语义；
Python 去重 timing path，再做结构聚类；
不要被重复 bus bit 和副本路径误导；
从硬件结构解释 RTL，而不是从代码表面解释；
优先切断 late data 和 late control 长组合链；
局部化 flush、stall、valid、ready、CE、reset 等高扇出控制；
reset valid，不 reset 无效 payload；
压缩 sideband，删除冗余 mux 和低收益 bypass；
RAM 延迟必须真实，不能为了性能伪造组合返回；
性能优化必须看 stall metrics；
最终以 full implementation 或 post-route 结果验收。
