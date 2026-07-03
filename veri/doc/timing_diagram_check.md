# 时序图 JSON 与模块设计一致性检查

| JSON | 对应模块 | 设计含义 | 检查结论 |
| --- | --- | --- | --- |
| fig_axi_lite_start_done | `mma_axil_top.sv` | CTRL 写入产生 `calc_start`，busy 保持到写回，done 置位 | 一致 |
| fig_axi_burst_incr_addr | `axi_dual_block_dma.sv` | AR/AW burst 为 INCR，R/W 以 last 结束 | 一致 |
| fig_dma_pingpong_compute | `mma_top.sv`、DMA、FIFO | 读预取、计算和写回可分阶段重叠 | 一致 |
| fig_npu_clock_gate | 低功耗材料 | 图中门控和 DFS 均标注待补 | 不作为已实现证明 |

本文件用于说明时序图与当前 RTL 的关系。AXI-Lite、AXI4 Burst 和 DMA 重叠三类时序图使用当前模块中存在的信号名称。低功耗图只展示未来应补充的观察信号，不参与当前完成项判定。
