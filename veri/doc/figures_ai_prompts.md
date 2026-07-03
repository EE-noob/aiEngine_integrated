# 绘图提示词

## 图1 PicoRV32 与优化 NPU 异构处理器总体架构

**绘图说明：** 白色背景、工程框图风格。左侧 PicoRV32，中央 AXI-Lite 控制与 AXI Interconnect，右侧 mma_axil_top、mma_top、AXI RAM、UART。蓝色箭头表示控制访问，橙色箭头表示 AXI4 数据搬运，绿色箭头表示 NPU 内部状态。禁止出现历史 CPU、历史接口和后端签核工具。

**输出文件名：** `fig_system_arch.png`

## 图2 NPU 内部数据通路与片上复用结构

**绘图说明：** 白色背景、细线框模块图。从左至右绘制 IA loader、kernel loader、bias/quant、ws_systolic_array、ps_buffer、vec_requant、vec_s8_to_fifo、oa_writer。突出 INT8/INT32 数据宽度变化和 AXI 写回方向。

**输出文件名：** `fig_npu_datapath.png`

## 图3 基于分块外积思想的矩阵乘法数据流

**绘图说明：** 绘制 A tile group 与 B tile group 形成 C tile partial sum 的过程。要求表现 partial sum 片上保留、最终 tile 写回、A/B 数据多次使用。禁止标注未经证明的 TOPS 数字。

**输出文件名：** `fig_outer_product_tile.png`

## 图4 AXI Burst、DMA 与双缓冲重叠关系

**绘图说明：** 绘制 read burst 预取下一 tile、buffer0/buffer1 交替、PE array 计算当前 tile、write burst 回写上一 tile 的时间重叠关系。

**输出文件名：** `fig_axi_dma_pingpong.png`

## 图5 RTL 仿真与 FPGA 实现材料关系

**绘图说明：** 绘制 RTL/filelist 到 Verilator random、VCS SoC、golden compare、报告结论的验证流程。覆盖率和低功耗标注为待补，不写通过。

**输出文件名：** `fig_verification_flow.png`

## 图6 FPGA 实现结果与待补材料

**绘图说明：** 绘制 Vivado、Artix-7、resource report、routed timing、bitstream 和板级照片/UART/ILA 待补。禁止出现 ASIC 后端签核术语。

**输出文件名：** `fig_fpga_flow.png`

## 时序图

AXI-Lite、AXI4 Burst、DMA 重叠和低功耗待补时序图使用 `wavedrom_json/*.json` 作为结构化输入，并同步导出同名 PNG。低功耗图仅表达待补信号位置，不作为当前 RTL 已实现证明。
