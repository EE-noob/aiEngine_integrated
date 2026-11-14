# 给执行仿真 agent 的任务

请对本包 aiEngine NPU 进行功能和周期测试，优先使用 Python 入口。先阅读根目录 README、`veri/python_model/README.md` 和 `MODEL_SCOPE.md`。所有结论必须以实际执行的日志、输入配置和模型校验值为依据。

1. 执行 `python3 verify_package.py`，确认包内文件及源码快照完整。
2. 执行 README 的 smoke 与 `validate_cycle_equivalence.py --quick`。确认原 RTL golden 比较通过、逐周期 CSV 一致。运行 Python 模型不需要安装 Verilator 或其他 pip 包。
3. 执行完整 12 组对照，并记录工具/平台、后端 manifest、每项 start-to-ready 周期与异常。不要仅依赖发送方的通过记录。
4. 使用 `veri/top_regression/gen_mem.py` 增加固定种子用例：WS/IS、s8/s16、per-channel、非对齐 stride、尾块、无 bias。s16 输出遵循生成器目前的 WS/per-tensor 限制。
5. 在相同 SIZE=16、PS=16、K/N/M、数据类型、RAM 延迟及种子下比较 C4/C8/C16/C32。推荐先扫 64³、128³、256³，再增加非方阵和向量矩阵工况。生成器目前限制输出方向最多 16×16=256 个元素；不要直接用现有后端运行 512³。
6. 保存实际周期和 AXI 握手统计。CSV 为上升沿后 1 ps 的稳定样本，valid/ready 的组合对应下一上升沿传输；统计时使用一致的边沿定义。原 testbench 时钟为 100 MHz，若按 200 MHz 换算 GOPS，须写明是等效频率。MAC=2 ops。
7. 核查吞吐报告关于权重驻留、cache 容量与复用的推导，特别是同时注入 IA/W 的假设与实际 `store_weight_req`、DMA 读取量是否相符。旧报告数据不应当作当前 RTL 的新测结果。
8. 当前只提供 AXI 32 bit 精确后端。64 bit 需要修改并重建 HDL testbench、RAM 与相关数据通路后再测，不能在 Python 中只改一个带宽参数便宣称完成 RTL 64 bit 仿真。

交付 Markdown 测试记录、逐 case CSV/JSON、失败时的首个差异周期与信号、输入/golden、实际命令和日志。新增结果放到 `results/`，保持随包基线记录可追溯。修改 RTL 后旧后端会因 SHA-256 不一致而拒绝运行；需要在构建机重新生成模型，或先将修改作为代码审查意见记录。
