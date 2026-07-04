# AI 绘图提示词

本文件保存报告插图的生成提示词。图形应采用白色背景、二维工程框图风格，重点表达模块组成、连接关系、数据搬移方向、控制信号方向和存储复用关系。曲线图和柱状图应优先由脚本按实测数据生成，AI 绘图仅用于结构示意、流程示意和时序说明图。

## 统一绘图规范

所有图片使用 16:9 横向画布，推荐 3840×2160 或 2560×1440 分辨率。背景为纯白色或极浅灰色 `#FAFAFA`，不使用渐变背景、三维透视、阴影堆叠、发光效果、装饰性纹理和宣传海报式构图。图中模块使用圆角很小的矩形，线宽 2 px 左右，字体使用清晰的无衬线字体，中文标签为主，必要的 RTL 模块名可以放在括号中使用小字号。整体效果应接近论文和数字 IC 设计文档中的结构图，而不是产品宣传图。

图中文字必须优先保证阅读清晰。3840×2160 画布中，主标题推荐 64 px 至 72 px，一级模块标题推荐 42 px 至 48 px，模块内部文字推荐 34 px 至 40 px，箭头标注和说明文字不小于 30 px；2560×1440 画布中按相同比例缩放，但最小文字不低于 24 px。模块框可以采用更紧凑的网格排列，减少大面积留白，但同一模块内部文字不应超过四行；连接关系较多时优先增加连接线标注密度和局部说明框，不通过缩小字号容纳内容。正式报告插图优先使用 SVG 或高分辨率 PNG，避免在页面中缩放到文字难以识别的尺寸。

颜色推荐保持一致：CPU 与软件控制使用浅蓝填充 `#E3F2FD`、深蓝描边 `#1565C0`；总线和互连使用浅紫填充 `#EDE7F6`、深紫描边 `#5E35B1`；共享存储和片上缓存使用浅绿填充 `#E8F5E9`、深绿描边 `#2E7D32`；寄存器和配置外设使用浅黄填充 `#FFF8E1`、琥珀色描边 `#F9A825`；NPU 计算阵列和计算核心使用浅红填充 `#FFEBEE`、深红描边 `#C62828`；DMA 与数据搬移单元使用浅青填充 `#E0F7FA`、深青描边 `#00838F`；重量化和输出处理使用浅粉填充 `#FCE4EC`、深粉描边 `#AD1457`；状态和完成信号使用浅灰填充 `#ECEFF1`、深灰描边 `#455A64`。

箭头颜色推荐区分含义：配置和控制访问使用蓝色箭头，矩阵数据搬移使用橙色或青色箭头，片上缓存到计算阵列的数据流使用绿色箭头，状态返回使用紫色或灰色箭头，写回路径使用红色箭头。箭头应标注协议、数据宽度或关键握手关系，例如 `AXI-Lite 32 bit`、`AXI4 32 bit`、`valid/ready`、`start`、`busy/done/error`、`wstrb`、`int8`、`int32`。箭头方向必须与硬件实际方向一致。

图中不要加入未实现的性能数字、未确认的频率、未确认的资源占用、未实现的电源管理模块、未使用的 CPU、未使用的接口、ASIC 后端签核流程、抽象云端服务、人物、服务器机柜或商业化图标。若需要表达未在图中展开的内部细节，应使用小字号说明框，不应使用夸张标语。

## 基于 RTL 连接关系生成的高精度图

以下图形已经按 RTL 代码重新梳理并用 Graphviz/DOT 生成。图形采用较大的节点和箭头字号、较小的节点间距和高分辨率输出，框图元素排列较紧凑，优先保证文字在报告页面中仍可阅读。`npu_top` 的完整图保留全局连接，正式排版时可优先采用拆分后的控制与 DMA 图、加载计算与输出图，避免单张图片信息量过大导致字号被压缩。它们比通用 AI 插图更适合表达真实模块连接，报告排版优先采用这些 PNG 或 SVG 文件。

| 图形 | DOT 源文件 | PNG 输出 | SVG 输出 | 依据代码 |
|---|---|---|---|---|
| `soc_top` 连接关系 | `report_figures/dot/fig_rtl_soc_top_connect.dot` | `report_figures/rendered/dot/fig_rtl_soc_top_connect.png` | `report_figures/rendered/dot/fig_rtl_soc_top_connect.svg` | `rtl/axi_accelerator/soc_top.sv`、`soc_axi_interconnect.sv`、`pico_native_to_axi.sv` |
| NPU AXI-Lite 寄存器组连接关系 | `report_figures/dot/fig_rtl_npu_axil_reg_connect.dot` | `report_figures/rendered/dot/fig_rtl_npu_axil_reg_connect.png` | `report_figures/rendered/dot/fig_rtl_npu_axil_reg_connect.svg` | `npu_axil_top.sv`、`npu_axil_reg_if.sv`、`npu_top.sv` |
| `npu_top` 连接关系 | `report_figures/dot/fig_rtl_npu_top_connect.dot` | `report_figures/rendered/dot/fig_rtl_npu_top_connect.png` | `report_figures/rendered/dot/fig_rtl_npu_top_connect.svg` | `rtl/axi_accelerator/npu/npu_top.sv` 及各 NPU 子模块 |
| `npu_top` 配置控制与 DMA 访问 | `report_figures/dot/fig_rtl_npu_control_dma_connect.dot` | `report_figures/rendered/dot/fig_rtl_npu_control_dma_connect.png` | `report_figures/rendered/dot/fig_rtl_npu_control_dma_connect.svg` | `npu_top.sv`、`npu_controller.sv`、`axi_block_dma_arbiter.sv`、`axi_dual_block_dma.sv` |
| `npu_top` 加载计算与输出写回 | `report_figures/dot/fig_rtl_npu_compute_output_connect.dot` | `report_figures/rendered/dot/fig_rtl_npu_compute_output_connect.png` | `report_figures/rendered/dot/fig_rtl_npu_compute_output_connect.svg` | `npu_top.sv`、`ia_loader.sv`、`kernel_loader.sv`、`bias_loader.sv`、`compute_core.sv`、`vec_requant.sv`、`vec_s8_to_fifo.sv`、`oa_writer.sv` |
| `npu_controller` 状态机 | `report_figures/dot/fig_rtl_npu_controller_fsm.dot` | `report_figures/rendered/dot/fig_rtl_npu_controller_fsm.png` | `report_figures/rendered/dot/fig_rtl_npu_controller_fsm.svg` | `npu_controller.sv` |
| `ia_loader_ctrl` 状态机 | `report_figures/dot/fig_rtl_ia_loader_ctrl_fsm.dot` | `report_figures/rendered/dot/fig_rtl_ia_loader_ctrl_fsm.png` | `report_figures/rendered/dot/fig_rtl_ia_loader_ctrl_fsm.svg` | `ia_loader_ctrl.sv` |
| `kernel_loader_ctrl` 状态机 | `report_figures/dot/fig_rtl_kernel_loader_ctrl_fsm.dot` | `report_figures/rendered/dot/fig_rtl_kernel_loader_ctrl_fsm.png` | `report_figures/rendered/dot/fig_rtl_kernel_loader_ctrl_fsm.svg` | `kernel_loader_ctrl.sv` |
| `bias_loader_ctrl` 状态机 | `report_figures/dot/fig_rtl_bias_loader_ctrl_fsm.dot` | `report_figures/rendered/dot/fig_rtl_bias_loader_ctrl_fsm.png` | `report_figures/rendered/dot/fig_rtl_bias_loader_ctrl_fsm.svg` | `bias_loader_ctrl.sv` |
| `vec_requant` 状态机 | `report_figures/dot/fig_rtl_vec_requant_fsm.dot` | `report_figures/rendered/dot/fig_rtl_vec_requant_fsm.png` | `report_figures/rendered/dot/fig_rtl_vec_requant_fsm.svg` | `vec_requant.sv` |
| `oa_writer` 状态机 | `report_figures/dot/fig_rtl_oa_writer_fsm.dot` | `report_figures/rendered/dot/fig_rtl_oa_writer_fsm.png` | `report_figures/rendered/dot/fig_rtl_oa_writer_fsm.svg` | `oa_writer.sv` |
| DMA 仲裁与块访问 | `report_figures/dot/fig_rtl_dma_arbiter_detail.dot` | `report_figures/rendered/dot/fig_rtl_dma_arbiter_detail.png` | `report_figures/rendered/dot/fig_rtl_dma_arbiter_detail.svg` | `axi_block_dma_arbiter.sv`、`axi_dual_block_dma.sv`、`oa_writer.sv` |

`soc_top` 图必须体现两条主设备路径。CPU 路径为 `u_picorv32` 到 `u_pico_axi_bridge`，再分别经过 `u_cpu_axi_read_pingpong` 和 `u_cpu_axi_write_pingpong` 接入 `u_axi_interconnect` 的 `s0` 端口。NPU 路径为 CPU 通过互连访问 `u_npu_axil_pingpong`，再进入 `u_npu_axil_top` 的 AXI-Lite 从接口；NPU 内部 DMA 产生的 AXI4 主设备信号从 `u_npu_axil_top` 输出，经 `u_npu_axi_pingpong` 接入互连 `s1` 端口。互连对外连接 RAM、UART 和 SOC 控制寄存器，其中 RAM 默认读通道直连，写通道可经过 `u_ram_axi_write_pingpong`，UART 前级包含 `u_uart_axil_pingpong`。

`npu_top` 图必须体现配置、加载、计算、重量化、打包和写回之间的真实信号关系。配置入口由 `calc_start && sa_ready` 形成 `cfg_start_event`，经过 `cfg_stage0/1/2` 锁存模式、矩阵维度、数据宽度和复用参数，裁剪后形成 `run_k/run_n/run_m/run_is_mode` 等配置，再由 `ctrl_calc_start` 触发 `u_npu_controller`。控制器向 `u_ia_loader`、`u_kernel_loader`、`u_bias_loader`、`u_vec_requant` 和 `u_oa_writer` 发出 `init_cfg_*`，并通过 `send_ia_trigger`、`send_weight_trigger` 推动加载和计算；同时接收 `ia_sending_done`、`weight_sending_done`、`bias_group_valid`、`quant_params_valid`、`fifo_full_flag`、`tile_calc_over`、`partial_sum_calc_over` 和 `oa_calc_over`。

加载路径必须按代码中的外部 DMA 客户端画出。`u_ia_loader` 由 `ia_loader_ctrl` 和 `ia_loader_cache_mgr` 组成，通过 `load_ia_req/ia_start` 向 `u_block_dma_arbiter` 申请读请求，并接收 `ia_wr_slot`、`ia_wr_row`、`ia_wr_col_base`、`ia_wr_data[BUS_WIDTH/8]` 和 `ia_wr_valid` 写入IA cache；输出 `ia_out[SIZE]`、`ia_row_valid`、`ia_tile_start`、`ia_is_init_data`、`ia_calc_done`、`ia_l1_switch` 和 `ia_sending_done` 到 `u_compute_core`。`u_kernel_loader` 通过 `load_weight_req/kernel_start` 读取权重，内部使用 `kernel_loader_ctrl` 与 `kernel_loader_buffer`，输出 `weight_out[SIZE]`、`store_weight_req` 和 `weight_data_valid` 到计算核心。`u_bias_loader` 通过 `load_bias_req/bias_start` 读取偏置，内部使用 `bias_loader_ctrl` 与 `bias_loader_buffer`，输出 `bias_data_out[SIZE]`、`bias_group_valid` 和 `group_data_out[IA_REUSE*SIZE]`。

计算与输出路径必须体现 `u_compute_core` 内部由 `bias_mux`、`ws_systolic_array` 和 `ps_buffer` 组成。`bias_mux` 在 WS 模式下选择锁存偏置或部分和回灌值，`ws_systolic_array` 接收 `store_weight_req`、`weight_in`、`ia_vec_in` 和 `sum_in`，`ps_buffer` 接收阵列输出并根据 `ia_is_init_data`、`ia_calc_done`、`ia_l1_switch` 保存或输出部分和。`u_vec_requant` 接收 `acc_data_out[SIZE]` 和 `acc_data_valid`，在per-channel量化时通过 `load_quant_req/quant_start` 读取参数，并输出 `requant_out[SIZE]`、`requant_out_valid` 和 `requant_out_tile_done`。`u_vec_s8_to_fifo` 将 int8 向量写入 bank，按 4 字节生成 `output_data[31:0]` 和 `output_mask[3:0]`。`u_oa_writer` 使用 `vec_valid_num_col/row`、`dst_base` 和 `dst_row_stride_b` 生成写回地址，通过 `write_oa_req/oa_start` 和 `dma_src_wdata/dma_src_wmask/dma_src_wvalid` 接入 DMA 写客户端。

DMA 细节图必须体现读写分离。读侧在 `axi_block_dma_arbiter` 中先执行组合选择，优先级为 `kernel_req`、`quant_req`、`ia_req`、`bias_req`，随后由 `rd_client/rd_active/rd_started` 寄存选中客户端，发出 `*_granted`，并把所选客户端的 base、stride、rows、burst 长度、slot、use16 和 zero point 多路选择到 `axi_dual_block_dma`。读引擎发出 `m_axi_arvalid`，接收 `m_axi_rvalid`，对非对齐读数据进行拼接，并把数据按选中客户端返回到 IA、权重、偏置或重量化参数路径。写侧由 `oa_req` 独占，`wr_active/wr_started` 管理写事务，写数据从 `oa_writer` 的 `src_wdata/src_wmask/src_wvalid` 进入 DMA，AW/W 通道完成后必须等待 B 响应返回才产生 `oa_done`。

## 图 1 PicoRV32 与 NPU 异构 SoC 总体架构

**输出文件名：** `fig_system_arch.png`

**用途：** 用于展示 SoC 顶层组成，说明 PicoRV32、AXI 互连、共享 SRAM、UART、SOC 控制寄存器、NPU AXI-Lite 外设、NPU 顶层和分块 DMA 的连接关系。

**详细提示词：** 绘制一张白色背景的数字 IC 系统架构图，横向 16:9，工程框图风格。画面从左到右分为四个区域。最左侧是浅蓝色 CPU 区域，包含一个大矩形“PicoRV32 控制 CPU”，下方小字标注“C 软件、算子调度、寄存器配置、状态轮询”。CPU 右侧连接浅蓝色矩形“CPU 原生接口到 AXI 桥”，箭头标签为 `mem_valid / mem_addr / mem_wdata / mem_wstrb`。

中间区域为浅紫色“共享 AXI 互连”，放置在画面中心，作为所有主设备和从设备的连接枢纽。CPU 桥到互连使用蓝色箭头，标注“CPU AXI 主设备”。右下侧放置浅青色“分块 DMA”，从 NPU 指向 DMA，再由 DMA 回到 AXI 互连，箭头标注“AXI4 32 bit 读写请求”。互连向下连接浅绿色“共享 AXI RAM”，RAM 内部用小块标出“输入矩阵 LHS”“权重 RHS”“输出 DST”“bias 与量化参数”“im2col 缓冲区”。互连向上连接浅黄色“UART”和“SOC 控制寄存器”，箭头标注“AXI-Lite 外设访问”。

右侧为 NPU 区域，使用浅红色外框表示“矩阵乘 NPU”。外框内部从左到右放置浅黄色“NPU AXI-Lite 外设”、浅黄色“任务配置寄存器”、浅红色“NPU 控制器”、浅红色“计算数据通路”。NPU AXI-Lite 外设通过蓝色箭头连接互连，标注“AXI-Lite 32 bit 寄存器访问”。任务配置寄存器向控制器发出 `start / irq_enable / cfg`，控制器向寄存器返回 `ready / busy / done / error`。NPU 控制器和计算数据通路向分块 DMA 发出橙色箭头，标注“二维分块读写、地址、长度、写掩码”。

在图右上角设置图例，列出颜色含义：蓝色为 CPU 与软件控制，紫色为总线互连，绿色为存储，黄色为配置寄存器，红色为 NPU 计算，青色为 DMA 数据搬移，灰色为状态返回。图中所有文本使用中文，协议名 AXI-Lite、AXI4 可以保留英文缩写。不要出现未实现的外设、外部 DDR 控制器、GPU、操作系统调度器或任何未在设计中使用的模块。

## 图 2 NPU 内部数据通路与片上复用结构

**输出文件名：** `fig_npu_datapath.png`

**用途：** 用于展示 NPU 内部从寄存器组到加载、缓存、阵列计算、部分和保存、重量化、输出打包和写回的结构。

**详细提示词：** 绘制一张 NPU 内部功能结构图，白色背景，横向 16:9，采用严格的数字电路框图。画面顶部放置一条浅黄色配置控制带，从左到右依次为“NPU AXI-Lite 外设”“任务配置寄存器”“NPU 控制器”。配置控制带向下发出蓝色控制箭头，分别连接输入加载、权重加载、bias 与量化参数加载、计算核心、输出写回单元。控制箭头标注 `cfg_valid`、`start`、`clear`、`busy/done/error`、`reuse 参数`。

画面中部为数据通路，从左到右排列。左侧放置三个外部数据源，使用浅绿色存储符号：“LHS 输入矩阵”“RHS 权重矩阵”“bias 与量化参数”。它们通过浅青色“分块 DMA”进入三个加载路径。第一条路径为“输入激活加载单元”，内部包含“地址生成”“s8/s16 抽取与符号扩展”“IA cache”“对角化输出时序”；输出到计算核心的箭头为绿色，标注 `int16 输入向量 valid/ready`。第二条路径为“权重加载单元”，内部包含“权重地址生成”“权重缓存”“store_weight 装载控制”；输出到阵列的箭头标注 `int8 权重向量`。第三条路径为“bias 与量化参数加载”，内部包含“int32 偏置”“乘法系数”“移位参数”“输出偏移与激活范围”。

画面中心偏右放置浅红色“计算核心与 16x16 权重固定脉动阵列”，内部画成 16 个小 PE 方块的 4×4 缩略网格，并用文字说明“图中为缩略表示，实际参数为 16x16 阵列”。阵列下方放置浅绿色“部分和缓冲区”，箭头从计算核心写入部分和，再从部分和缓冲区回到计算核心，标注“int32 中间和保存与回灌”。从计算核心到右侧浅粉色“重量化流水”使用红色箭头，标注“最终 int32 向量”。重量化流水内部标注“乘法缩放、舍入、移位、输出偏移、激活钳位、int8 饱和”。

画面最右侧为输出写回路径。重量化流水连接“输出打包 FIFO”，标注“int8 输出打包为 32 bit 数据拍”。FIFO 连接“输出写回单元”，标注“DST 地址生成、行步长、尾列处理、4 bit 字节写掩码”。输出写回单元连接分块 DMA，再写回浅绿色“DST 输出矩阵”。写回箭头用红色，标注 `AW/W/B` 和 `wstrb`。图中使用灰色虚线箭头表示状态返回，例如加载完成、FIFO 水位、写响应完成。不要把 CPU 逐元素访问画入 NPU 内部，不要把部分和画成外存写回。

## 图 3 分块矩阵外积式数据流调度

**输出文件名：** `fig_outer_product_tile.png`

**用途：** 用于说明输入矩阵分块、权重分块、输出分块和部分和帧之间的复用关系，强调片上缓存减少重复外部读取。

**详细提示词：** 绘制一张矩阵分块数据流示意图，白色背景，横向 16:9。左侧放置一个大矩阵 A，标题为“LHS 输入矩阵 A[K,N]”，用浅绿色网格表示，并高亮一组连续的输入行分块，颜色为浅蓝。上方放置一个大矩阵 B，标题为“RHS 权重矩阵 B[N,M]”，用浅绿色网格表示，并高亮多个输出列分块，颜色为浅黄。右侧放置输出矩阵 C，标题为“输出矩阵 C[K,M]”，用浅红色网格表示，显示多个输出分块正在被同一输入分块和不同权重分块更新。

在画面中央绘制“调度窗口”，用虚线矩形框住一组输入激活分块和一组权重分块。框内放置三个模块：“IA cache：保存多个输入矩阵分块”“权重驻留：权重分块装入 PE 后复用”“部分和帧：保存 int32 中间和”。从 A 的高亮分块到IA cache画绿色箭头，标注“一次读取，多次服务输出列组”；从 B 的高亮分块到权重驻留模块画橙色箭头，标注“一次装载，多次服务输出行组”；从计算结果到部分和帧画红色箭头，标注“归约未完成时保存 int32 中间和”；从部分和帧回到计算阵列画红色回灌箭头，标注“下一归约分块继续累加”。

中间计算模块画成浅红色“16x16 脉动阵列”，阵列旁标注“以 SIZE×SIZE 为基本分块，图中展示一个调度窗口”。底部放置一条时间轴，顺序标出“读取输入分块组”“装载权重列组”“执行乘加”“保存或回灌部分和”“最终重量化并写回”。时间轴上的箭头不要表现为软件循环，而要表现为硬件调度阶段。右下角放置小图例说明：蓝色高亮为输入行分块，黄色高亮为权重列分块，红色高亮为输出分块，绿色箭头为读入，红色箭头为部分和与写回。

图中不要出现未确认的 TOPS 数字。不要使用英文短语描述部分和或分块，使用“部分和”“输入矩阵分块”“权重分块”“输出分块”“归约分块”等中文标签。

## 图 4 AXI4 突发传输、DMA 与乒乓缓冲重叠关系

**输出文件名：** `fig_axi_dma_pingpong.png`

**用途：** 用于展示预取、计算和写回在时间上的重叠关系，说明 DMA、缓存、计算阵列和输出 FIFO 的速率匹配。

**详细提示词：** 绘制一张横向时序加结构混合图，白色背景，16:9。上半部分为结构图，下半部分为时间轴。结构图从左到右为“共享 AXI RAM”“分块 DMA”“乒乓缓冲区 0 / 乒乓缓冲区 1”“16x16 脉动阵列”“输出 FIFO”“输出写回单元”“共享 AXI RAM 的 DST 区域”。共享 RAM 使用浅绿色，DMA 使用浅青色，两个缓冲区使用浅黄，阵列使用浅红，FIFO 使用浅绿，写回单元使用浅青。

从 RAM 到 DMA 画橙色读箭头，标注“AXI4 突发读，32 bit 数据拍”；从 DMA 到缓冲区 0 和缓冲区 1 画分叉箭头，标注“预取下一输入或权重分块”。缓冲区到阵列画绿色箭头，标注 `valid/ready`；阵列到输出 FIFO 画红色箭头，标注“int32 到 int8 输出”；输出 FIFO 到写回单元画红色箭头，标注“32 bit 写数据 + 4 bit 字节写掩码”；写回单元到 RAM 的 DST 区域画红色箭头，标注“AXI4 写回，等待 B 响应”。

下半部分时间轴分为四行：DMA 读、缓冲区 0、缓冲区 1、阵列计算、DMA 写回。时间从左向右推进。画出第一个阶段“DMA 读分块 A 到缓冲区 0”，随后“阵列计算缓冲区 0 数据”与“DMA 读分块 B 到缓冲区 1”重叠；再画出“阵列计算缓冲区 1 数据”与“写回上一输出分块”重叠。使用半透明色块表示每个阶段，读为橙色，计算为红色，写回为紫色，等待为灰色。时间轴上标注 `rd_start`、`buf0_load`、`buf0_compute`、`buf1_load`、`buf1_compute`、`oa_dma_start`、`B response`。

图中需要体现反压关系：当输出 FIFO 接近满时，用一条灰色虚线从 FIFO 指向阵列前级，标注“局部反压，只暂停直接上游”；当 DMA 未完成事务达到上限时，用灰色虚线从 DMA 指向加载单元，标注“暂停新请求，已接受传输保持”。不要把反压画成跨越整个系统的组合信号。

## 图 5 AXI-Lite 配置、启动与完成时序

**输出文件名：** `fig_axi_lite_start_done.png`

**用途：** 用于说明 CPU 通过 AXI-Lite 写控制寄存器、写 start、NPU 置 busy、任务完成后置 done sticky 的时序关系。

**详细提示词：** 绘制一张数字时序图，白色背景，横向 16:9，风格接近 WaveDrom。左侧为信号名，右侧为时钟波形。信号从上到下依次为 `aclk`、`aresetn`、`AWVALID`、`AWREADY`、`AWADDR`、`WVALID`、`WREADY`、`WDATA`、`WSTRB`、`BVALID`、`BREADY`、`calc_start`、`npu_busy`、`done_sticky`、`clear_done`。时钟使用黑色方波，复位释放后开始事务。

第一组事务表现为 CPU 写控制寄存器。`AWVALID` 与 `AWREADY` 在同一周期为高，`AWADDR` 标注“CONTROL 地址”；`WVALID` 与 `WREADY` 同周期为高，`WDATA` 标注“start=1”，`WSTRB` 标注“4'b1111”。在写地址和写数据均完成后，`BVALID` 拉高一个周期，`BRESP` 若出现则标注“OKAY”。`calc_start` 在写事务接受后形成一个周期脉冲，随后 `npu_busy` 置 1。

中间阶段用灰色省略区表示 NPU 内部加载、计算、重量化和写回，不展开内部信号。右侧表现任务完成：当所有输出写响应返回后，`npu_busy` 由 1 变 0，`done_sticky` 置 1 并保持。最后画一组 CPU 写清除位事务，`clear_done` 一个周期有效，随后 `done_sticky` 清 0。关键周期用竖向虚线对齐，分别标注“写握手完成”“start 被采样”“busy 有效”“写回完成”“done 保持”“软件清除”。不要画成软件流程图，应保持硬件时序图形式。

## 图 6 AXI4 递增突发读写地址与响应时序

**输出文件名：** `fig_axi_burst_incr_addr.png`

**用途：** 用于说明 DMA 将二维分块访问拆成 AXI4 递增突发读写事务，以及 `last` 和写响应的完成条件。

**详细提示词：** 绘制一张 AXI4 读写事务时序图，白色背景，横向 16:9。上半部分为读通道，下半部分为写通道，中间用细灰线分隔。读通道信号包括 `ARVALID`、`ARREADY`、`ARADDR`、`ARLEN`、`ARSIZE`、`ARBURST=INCR`、`RVALID`、`RREADY`、`RDATA`、`RLAST`、`RRESP`。写通道信号包括 `AWVALID`、`AWREADY`、`AWADDR`、`AWLEN`、`WVALID`、`WREADY`、`WDATA`、`WSTRB`、`WLAST`、`BVALID`、`BREADY`、`BRESP`。

读事务中，`ARVALID` 和 `ARREADY` 握手时 `ARADDR` 标为 `row_base + col_offset`，`ARLEN` 标为“本行数据拍数减 1”，`ARBURST` 标为 `INCR`。随后 `RVALID` 连续或间隔返回多个数据拍，`RDATA` 标注 `D0, D1, D2, ...`，最后一拍 `RLAST` 拉高。使用橙色竖线标注“地址握手”，使用绿色区块标出“读数据返回窗口”。

写事务中，`AWVALID` 和 `AWREADY` 握手时 `AWADDR` 标为 `dst_base + row * stride + col`；`WVALID` 与 `WREADY` 表示写数据拍传输；`WSTRB` 需要标出首拍、完整中间拍和尾拍的不同字节写掩码，例如 `0011`、`1111`、`0001`；最后一个写数据拍 `WLAST` 拉高。`BVALID` 在写地址和全部写数据拍被接受后返回，图中用红色标注“写响应返回后才计入完成”。不要把 AW/W 握手画成完成点，完成点必须对应 B 响应。

右侧放置一个小型地址示意框，显示二维矩阵行访问：第 0 行起始地址、行步长、每行有效字节数、下一行起始地址。箭头说明 DMA 按行生成多个递增突发传输。不要加入 AXI 未使用通道，也不要展示与本设计无关的缓存一致性事务。

## 图 7 DMA 预取、计算与写回多周期时序

**输出文件名：** `fig_dma_pingpong_compute.png`

**用途：** 用于展示加载、计算、写回的多周期重叠，适合放在软硬件接口或性能优化相关章节作为时序说明。

**详细提示词：** 绘制一张多周期时序图，白色背景，横向 16:9，使用五到七条水平泳道。泳道依次为“DMA 读请求”“缓冲区 0 装载”“缓冲区 0 供给计算”“缓冲区 1 装载”“缓冲区 1 供给计算”“输出写回请求”“AXI 写响应”。每个泳道使用矩形色块表示有效周期，空白表示等待。读请求用橙色，缓冲区装载用浅黄，计算用浅红，写回用紫色，响应用灰色。

时间轴从左到右分为若干拍，顶部画时钟刻度。第一段为 `rd_start` 拉高并装载缓冲区 0；第二段为缓冲区 0 进入计算，同时 DMA 对缓冲区 1 发起下一组读请求；第三段为缓冲区 1 进入计算，同时输出写回单元发起上一输出分块写请求；最后画 B 响应返回，并标注“全部写响应返回后写回完成”。在每个色块内使用中文短标签，例如“读入分块 0”“计算分块 0”“预取分块 1”“写回输出分块 0”。

在图下方放置三条规则说明，使用小字号：第一，valid 与 ready 同周期为高时传输完成；第二，下游反压时数据、地址和写掩码保持；第三，写回完成以 B 响应返回为准。说明文字要简洁，不使用宣传性表达。

## 图 8 输出打包、字节写掩码与非对齐写回

**输出文件名：** `fig_output_pack_wstrb.png`

**用途：** 用于补充说明 `vec_s8_to_fifo` 和 `oa_writer` 如何把 int8 输出转换为 32 bit AXI 写数据，并处理尾列和非 4 字节对齐地址。

**详细提示词：** 绘制一张输出写回结构图，白色背景，横向 16:9。左侧放置浅粉色“重量化输出向量”，内部画 16 个小格表示 16 个 int8 输出通道，其中尾列无效通道用浅灰色填充。中间放置浅绿色“输出打包 FIFO”，画成多行 32 bit 数据拍，每行包含 4 个字节格。每个字节格标注 `O0`、`O1`、`O2`、`O3` 等输出元素，尾拍中无效字节画成灰色并标注“不写”。

右侧放置浅青色“输出写回单元”，内部标注“DST 基址”“行步长”“输出行/列坐标”“地址低位”“4 bit 字节写掩码”。从 FIFO 到写回单元画红色箭头，标注“写数据 + 写掩码 + 坐标”。从写回单元到共享 RAM 的 DST 区域画红色 AXI 写箭头，标注 `AWADDR`、`WDATA[31:0]`、`WSTRB[3:0]`、`WLAST`、`BVALID`。

在底部画三个例子：地址 4 字节对齐且 4 个输出字节有效时 `WSTRB=1111`；首地址低位为 1 且写 3 个字节时 `WSTRB=1110`；尾列只剩 1 个有效输出时 `WSTRB=0001` 或按地址低位显示对应位。所有示例应明确“只修改掩码为 1 的字节”。不要使用模糊英文描述，不要把无效尾列画成写入 0。

## 图 9 WS/IS 双数据流与输出坐标映射

**输出文件名：** `fig_ws_is_dataflow.png`

**用途：** 用于展示权重固定模式和输入固定模式的差异，以及两种模式下软件可见输出矩阵仍保持同一行主序布局。

**详细提示词：** 绘制一张左右对比图，白色背景，横向 16:9。左半部分标题为“WS 权重固定模式”，右半部分标题为“IS 输入固定模式”。两侧都包含输入矩阵、权重矩阵、脉动阵列、部分和缓冲区、重量化、输出写回和 DST 输出矩阵。使用相同颜色：输入矩阵浅蓝，权重浅黄，阵列浅红，部分和浅绿，重量化浅粉，输出矩阵浅绿色。

左侧 WS 模式中，权重分块从上方进入阵列并驻留在 PE 内，输入激活分块从左侧按对角化时序进入阵列，部分和沿阵列输出方向进入缓冲区或重量化。箭头标注“权重装载后保持”“输入激活连续流入”“输出列组复用”。右侧 IS 模式中，输入相关数据驻留或优先保持，另一矩阵数据流入阵列，输出产生顺序经过 FIFO 和写回坐标转换后写入同一 DST 行主序矩阵。箭头标注“模式位在 start 时锁存”“内部流向变化”“DST 行主序不变”。

两侧底部各画一小块输出矩阵 C[K,M]，使用相同的行列坐标标注 `row` 和 `col`，并用灰色说明“软件可见 GEMM 公式保持 C=A×B”。不要把两种模式画成两套完全不同的外设接口；AXI-Lite 寄存器、分块 DMA、重量化和状态寄存器应显示为共享或相同结构。

## 图 10 FPGA 实现结果汇总结构图

**输出文件名：** `fig_fpga_flow.png`

**用途：** 用于实现结果总结相关页面，展示 RTL 参数化配置、综合实现、时序结果、资源结果和 bitstream 产物之间的关系。

**详细提示词：** 绘制一张 FPGA 实现结果汇总图，白色背景，横向 16:9，采用流程加表格结合的工程风格。左侧为输入配置区域，包含“RTL 源码”“顶层参数：阵列规模、IA cache块数、部分和帧数、AXI 数据宽度”“约束文件：时钟、复位、引脚”。中间为 Vivado 流程区域，依次放置“综合”“实现”“时序分析”“资源统计”“bitstream 生成”。右侧为结果区域，使用四个浅绿色或浅灰色卡片显示“时序结果”“LUT/FF/BRAM/DSP 资源”“最高工作频率需结合实现结果确认”“上板文件与启动镜像”。

箭头从左到右连接各阶段，流程箭头使用蓝色，结果箭头使用绿色。图中可以出现 Vivado、FPGA、bitstream、WNS、LUT、FF、BRAM、DSP 等术语，但不要加入未确认数值；若需要示意数值位置，用“填入综合报告数值”这类占位，不要写具体数字。不要出现 ASIC 后端流程、工艺节点、电源相关指标或未实现功能。

## 图 11 RTL 仿真与结果检查流程

**输出文件名：** `fig_verification_flow.png`

**用途：** 该图供验证报告使用，不插入设计报告正文。用于展示 RTL、testbench、随机用例、SoC 程序、golden 对比和日志汇总之间的关系。

**详细提示词：** 绘制一张 RTL 仿真流程图，白色背景，横向 16:9。左侧为输入区域，包含“RTL 源码”“testbench”“C 程序镜像”“随机矩阵与 golden 输出”。中间为执行区域，分成三条并行路径：“NPU 独立随机回归”“SoC 级 VCS 仿真”“TFLM/NMSIS-NN 软件入口”。右侧为结果区域，包含“输出矩阵比较”“状态位与错误码检查”“周期计数器”“总线读写数据拍统计”“日志汇总”。

每条路径使用不同颜色：独立 NPU 回归为浅红，SoC 级仿真为浅紫，软件入口为浅蓝，结果检查为浅绿。箭头从输入指向执行，再指向结果。结果区域最后汇总到“验证报告表格与图形源文件”。图中只表达验证组织方式，不给出覆盖率或通过率数值，除非图外已经提供明确数据。不要把该图放入设计报告正文。

## 设计报告待生成插图提示词

以下提示词按报告正文中的图号整理，输出文件建议保存到 `report_figures/ai/`。绘图时保持正文图号和图题一致，图内文字不要过小；若模块数量较多，可以提高方框密度，但所有箭头标签、寄存器名和信号名必须清晰可读。

## 图2-4 AXI 地址译码、RAM 访问归属与外设转发关系

**输出文件名：** `report_figures/ai/fig02_04_axi_decode_ram_owner.png`

**用途：** 用于补充说明 `soc_axi_interconnect` 中 CPU 与 NPU 两个主设备访问共享 RAM 和外设的地址译码、读写归属选择、NPU 活跃期间 CPU 新请求限制和错误响应路径。

**详细提示词：** 绘制一张白色背景的数字 IC 总线互连结构图，横向 16:9，标题为“AXI 地址译码、RAM 访问归属与外设转发关系”。左侧放置两个主设备输入区：上方浅蓝色“CPU AXI 主设备 s0”，列出 `s0_axi_ar*`、`s0_axi_aw*`、`s0_axi_w*`、`s0_axi_r*`、`s0_axi_b*`；下方浅红色“NPU AXI 主设备 s1”，列出 `s1_axi_ar*`、`s1_axi_aw*`、`s1_axi_w*`、`s1_axi_r*`、`s1_axi_b*`。CPU 输入旁放一个浅灰小框“读地址两项缓冲”，内部标注 `cpu_arq_count`、`cpu_arq_dest`、`cpu_arq_addr`，表示 CPU 读地址先进入队列再发往目标。

画面中央放置浅紫色大框“soc_axi_interconnect”。该框内部从左到右分为三层。第一层为“CPU 地址译码”，列出四个地址窗口：`CPU_RAM_BASE` 进入 RAM，`NPU_AXIL_BASE` 进入 NPU AXI-Lite 外设，`UART_BASE` 进入 UART，`SOC_CTRL_BASE` 进入 SOC 控制寄存器，其他地址进入 `D_ERR`。第二层为“RAM 读归属选择”和“RAM 写归属选择”两个并列仲裁框，内部标注 `OWNER_CPU`、`OWNER_NPU`、`ram_rd_active`、`ram_wr_active`、`READ_OUTSTANDING`、`WRITE_OUTSTANDING`。第三层为“外设转发与错误响应”，包含“NPU 外设转发”“UART 转发”“SOC 控制寄存器转发”“D_ERR 固定响应”四个小框。

右侧放置目标设备。中上方为浅绿色“共享 AXI RAM”，箭头从 RAM 读归属选择连接到 RAM AR/R 通道，箭头标签写“读地址与读数据返回”；箭头从 RAM 写归属选择连接到 RAM AW/W/B 通道，标签写“写地址、写数据、写响应”。右上方放浅黄色“NPU AXI-Lite 外设”，右中放浅黄色“UART”，右下放浅黄色“SOC 控制寄存器”。CPU 外设访问只连接这些外设；NPU 主设备只连接共享 RAM，不要把 NPU 主设备画到外设转发路径。

在中央互连框上方绘制一条灰色控制箭头 `npu_bus_lock`，从 NPU 活跃状态指向 CPU 请求入口，标注“NPU 活跃时限制 CPU 新 AR/AW 请求；已在途事务按 AXI 响应完成”。在 RAM 归属选择框中用不同颜色箭头表示 CPU 与 NPU 竞争同一 RAM 端口；当 NPU 有 RAM 请求且 CPU 占用可让出时，用虚线标注“归属切换到 NPU”。所有协议箭头使用方向明确的单向箭头，读地址、读数据、写地址、写数据和写响应用不同线型区分。不要加入外部 DDR、缓存一致性控制器或未使用外设。

## 图3-6 compute_core 内部阵列、偏置选择与部分和缓冲关系

**输出文件名：** `report_figures/ai/fig03_06_compute_core_ps_requant.png`

**用途：** 用于展示 `compute_core` 内部 `bias_mux`、`ws_systolic_array` 和 `ps_buffer` 的连接关系，以及 IA 对角化输入、权重装载、部分和保存与最终累加输出之间的硬件行为。

**详细提示词：** 绘制一张 NPU 计算核心内部结构图，白色背景，横向 16:9，标题为“compute_core 内部阵列、偏置选择与部分和缓冲关系”。左侧放置浅绿色“IA cache 对角化输出”，内部用 16 条细线表示 `ia_vec_in[SIZE]`，旁边标注 `ia_row_valid`、`ia_tile_start`、`ia_is_init_data`、`ia_calc_done`、`ia_l1_switch`、`ia_sending_done`。上方放置浅黄色“权重加载输出”，标注 `weight_in[SIZE]` 和 `store_weight_req`，箭头从上进入阵列每一列。

中央放置浅红色大框“ws_systolic_array：16x16 权重固定脉动阵列”。阵列内部画成 8×8 缩略 PE 网格，并在右下角用说明框写“缩略显示，实际按 SIZE×SIZE 参数生成”。左侧 IA 输入从每一行进入，权重从上方进入并在 PE 内保持；阵列底部输出 `sum_out[SIZE]`。阵列输入侧放置浅黄色“bias_mux”，它有两个输入：一条来自“bias 输入 bias_in[SIZE] 或 0”，另一条来自下方“部分和回灌 ps_data_out[SIZE]”。`bias_sleep` 用蓝色控制箭头进入 `bias_mux`，箭头说明“首次归约使用 bias 或 0，中间归约使用部分和回灌”。

阵列下方放置浅绿色大框“ps_buffer：部分和帧缓冲”。该框内部左侧为“宽向量 FIFO”，右侧为“反对角化输出单元”，中间标注 `FRAME_COUNT`、`MAX_IA_REUSE`、`frame_len`、`read_ptr/write_ptr`。从阵列 `sum_out[SIZE]` 向 ps_buffer 画红色箭头；从 ps_buffer 回到 `bias_mux` 画绿色回灌箭头，标注 `ps_data_out[SIZE]`；从 ps_buffer 向右画红色箭头，标注 `acc_data_out[SIZE]` 和 `acc_data_valid`，连接到图右侧浅粉色“vec_requant 输入”。ps_buffer 还向控制器返回 `tile_calc_over`、`stream_calc_over` 和 `partial_sum_calc_over`，用灰色状态箭头画到上方“控制器状态采样”小框。

图中需要体现时序延迟：在 IA 输入到阵列之间画一条细灰色“SIZE 周期对齐寄存”说明，表示 `ia_tile_start` 经对齐后生成 `ps_burst_start`；在输出侧画 `ps_tail_cnt` 小框，说明阵列尾部排空期间继续产生有效部分和。所有数据宽度标签使用 `int16 输入`、`int16 权重`、`int32 累加`、`int32 部分和`。不要把部分和画成外部 RAM 访问，也不要把重量化逻辑放入 PE 内。

## 图3-8 oa_writer 输出坐标、字节写掩码与写响应完成关系

**输出文件名：** `report_figures/ai/fig03_08_oa_writer_coord_wmask_rsp.png`

**用途：** 用于说明 `oa_writer` 根据输出 FIFO 数据、有效行列数、WS/IS 模式和 DST 步长生成写回命令，并以 AXI 写响应作为输出完成条件。

**详细提示词：** 绘制一张输出写回控制结构图，白色背景，横向 16:9，标题为“oa_writer 输出坐标、字节写掩码与写响应完成关系”。左侧放置浅绿色“vec_s8_to_fifo 输出”，内部列出 `output_valid`、`output_ready`、`output_data[31:0]`、`output_mask[3:0]`、`oa_fifo_req`、`output_row_switch`。从 FIFO 到中央 `oa_writer` 画红色箭头，标注“32 bit 输出数据拍、4 bit 字节写掩码、行切换标志”。

中央放置浅青色大框“oa_writer”。框内分成四个子单元：第一是“任务几何锁存”，标注 `k`、`m`、`dst_base`、`dst_row_stride_b`、`cfg_is_mode`；第二是“有效范围计算”，标注 `rows_valid_cur_tile`、`cols_valid_cur_tile`、`vec_valid_num_row`、`vec_valid_num_col`；第三是“地址生成”，标注 `tile_base_addr_cur`、`row_group_base_addr_cur`、`row_offset_addr_cur`、`col_offset_addr_cur`；第四是“DMA 写命令保持”，标注 `write_oa_req`、`write_oa_granted`、`dma_start`、`dma_rows_to_read`、`dma_burst_len_m1`。

右侧放置浅紫色“axi_block_dma_arbiter 写客户端”和浅绿色“共享 RAM 的 DST 区域”。从 `oa_writer` 到仲裁器画蓝色请求箭头，标注 `write_oa_req / write_oa_granted`；从 `oa_writer` 到 DMA 写数据口画红色箭头，标注 `dma_src_wdata`、`dma_src_wmask`、`dma_src_wvalid / dma_src_wready`；从 DMA 到 RAM 画 AXI 写通道箭头，依次标出 `AWADDR`、`WDATA`、`WSTRB`、`BVALID`。在 B 响应返回处用粗红色竖线标注“写响应返回后，该输出范围才计入完成”。

在图底部画一个小型状态机带：`S_IDLE` 等待 `init_cfg` 和 FIFO 请求，`S_REQ` 保持写请求，`S_START` 等待 grant 后发出 `dma_start`，`S_WRITE` 传输输出数据并等待 `dma_done`，`S_DONE` 产生 `oa_calc_over` 后回到空闲。每个状态使用小矩形和箭头，箭头上写进入条件。图右下角增加 WS/IS 坐标说明：WS 模式下行步进对应输出行，列步进对应输出列；IS 模式下内部产生顺序可变化，但 DST 行主序写回保持。不要使用“自动处理”这类模糊表述。

## 图4-1 FPGA 资源映射与主要 RTL 模块对应关系

**输出文件名：** `report_figures/ai/fig04_01_fpga_resource_mapping.png`

**用途：** 用于表达主要 RTL 模块与 FPGA 资源类型之间的对应关系，不写入未确认的具体资源数量。

**详细提示词：** 绘制一张 FPGA 资源映射结构图，白色背景，横向 16:9，标题为“FPGA 资源映射与主要 RTL 模块对应关系”。画面左侧为浅红色“NPU 计算模块”，包含 `compute_core`、`ws_systolic_array`、`ws_systolic_cell`、`vec_requant`，箭头指向右侧资源框“乘法器、加法树、流水寄存器、DSP 或查找表乘法资源”。图中只写资源类型，不写 LUT、FF、BRAM、DSP 的具体数值。

画面中部为浅绿色“片上存储模块”，包含 `ia_loader_cache_mgr`、`kernel_loader_buffer`、`bias_loader_buffer`、`ps_buffer`、`vec_s8_to_fifo`，箭头指向“BRAM、分布式 RAM、同步读 RAM、读写指针寄存器”。在该区内部用小图标表示 IA cache 槽位、权重缓存、偏置 bank、部分和帧和输出 FIFO bank。每个小图标旁写一句短标签，例如“valid 标志保护有效数据”“帧信息绑定输出分块坐标”“bank_ready 控制输出流”。

画面右侧为浅紫色“总线与控制模块”，包含 `soc_axi_interconnect`、`pico_native_to_axi`、`npu_axil_top`、`npu_axil_reg_if`、`axi_block_dma_arbiter`、`axi_dual_block_dma`、`axi_pingpong_buffer`，箭头指向“状态机、地址译码、仲裁选择、未完成事务计数、valid 标志寄存器”。在最右边放浅黄色“软件可见寄存器组”，标注“32 bit AXI-Lite、控制、状态、矩阵参数、量化参数基址”。

底部放一条参数化说明带，列出综合期参数“阵列规模 SIZE”“IA cache 分块数”“部分和帧数”“AXI 数据宽度”“未完成事务深度”。用虚线从这些参数连接到计算模块、存储模块和 DMA 模块，说明参数影响生成硬件规模。图中不要写性能承诺、频率数字、资源百分比或未实现功能；如需要数值位置，只用“由综合报告填写”表示。

## 图4-2 长组合路径隔离、乒乓缓冲与局部寄存器切分关系

**输出文件名：** `report_figures/ai/fig04_02_timing_buffer_pipeline.png`

**用途：** 用于展示 SoC 互连、AXI RAM、DMA、加载单元、计算核心和写回单元之间通过乒乓缓冲与局部寄存器切分 ready/valid 长路径的结构。

**详细提示词：** 绘制一张时序结构图，白色背景，横向 16:9，标题为“长组合路径隔离、乒乓缓冲与局部寄存器切分关系”。从左到右排列模块：“PicoRV32 原生接口”“pico_native_to_axi”“CPU AXI 读写乒乓缓冲”“soc_axi_interconnect”“RAM 写侧乒乓缓冲”“共享 AXI RAM”“NPU AXI 主设备乒乓缓冲”“axi_block_dma_arbiter”“axi_dual_block_dma”“加载单元局部寄存”“compute_core”“vec_s8_to_fifo”“oa_writer”。各模块使用不同颜色区分 CPU、总线、存储、DMA 和 NPU 计算。

在每两个相邻模块之间画 `valid/ready + payload` 箭头，payload 标签包括“地址、长度、数据、写掩码、last、客户端编号、坐标”。在乒乓缓冲模块内部画两个交替工作的寄存槽，标注“槽 0”和“槽 1”，并用小箭头表示上游写入和下游读出可以在相邻周期交替。不要把缓冲画成大容量 FIFO；它是用于切分时序路径和保持负载稳定的时序缓冲。

在图上方用三条红色短线标出原本容易变长的组合路径：互连仲裁到 RAM ready、DMA 返回到加载单元 ready、输出 FIFO 满到计算输入 ready。每条红线被旁边的寄存器或乒乓缓冲切开，旁边写“边沿采样后保持”“下游反压只停止直接上游”“已接受事务等待响应计数”。用灰色虚线从下游反压返回到上游最近一级缓冲，不要画成直接跨越整个系统的组合返回。

底部增加一个小型时序带，展示连续三个时钟周期：周期 T 接受上游数据，周期 T+1 缓冲有效并向下游发送，周期 T+2 下游反压时 valid 和 payload 保持。该时序带不需要精确波形，只需要清晰标注“采样”“保持”“释放”。不要加入时钟频率数字或 FPGA 具体器件信息。

## 图5-2 IA cache 槽位状态、标签匹配与预取时序关系

**输出文件名：** `report_figures/ai/fig05_02_ia_cache_prefetch_slots.png`

**用途：** 用于说明 IA cache 的槽位 valid/busy 状态、读写槽位指针、L1 输入组连续输出和预取触发条件。

**详细提示词：** 绘制一张 IA cache 管理结构图，白色背景，横向 16:9，标题为“IA cache 槽位状态、标签匹配与预取时序关系”。画面左侧放浅青色“分块DMA 读返回”，箭头进入浅绿色“IA cache 写入端”，标签写 `wr_slot`、`wr_row`、`wr_col_base`、`wr_data[BUS_WIDTH/8]`、`wr_valid`、`wr_use_16bits`。写入端后方画一个由 8 到 16 个槽位组成的环形或横向槽位表，每个槽位用小矩形表示，内部字段包括“valid”“busy”“slot_rows”“行分块编号”“归约分块编号”。槽位表中一组连续槽位高亮，标注“当前 L1 输入组”；另一组空闲槽位用虚线高亮，标注“下一组预取写入目标”。

槽位表上方放浅黄色“ia_loader_ctrl”，内部列出 `wr_slot_ptr`、`rd_slot_base`、`pf_rd_slot_base`、`prefetch_active`、`can_overlap_prefetch`、`blk_valid`、`blk_busy`、`load_ia_cursor`。从控制器到槽位表画蓝色控制箭头，标注“写槽位选择”“读起始槽位”“释放 valid”“标记 busy”。控制器左侧连接“DMA 请求生成”小框，列出 `load_ia_req`、`load_ia_granted`、`tl_base_addr`、`tl_row_stride`、`tl_rows_to_read`、`tl_valid_cols`、`tl_burst_len_m1`。

槽位表右侧放浅绿色“ia_loader_cache_mgr 对角化读出”，内部画 `diag_step`、`issue_slot`、`issue_row_idx`、`l1_slot_start`、`l1_slot_end`。从槽位表到该单元画绿色箭头，标注“按 slot 和 row 读出”；从该单元到右侧浅红色“compute_core”画多路箭头，标注 `ia_out[SIZE]`、`ia_row_valid`、`ia_tile_start`、`ia_is_init_data`、`ia_calc_done`、`ia_l1_switch`。

底部画一条时序泳道，横向分成“加载当前组”“发送当前组”“预取下一组”“释放已完成槽位”“切换到下一组”。在“发送当前组”和“预取下一组”之间使用重叠色块，说明预取可以与当前组输出并行。用箭头标出预取条件：目标槽位 `valid=0` 且 `busy=0`，当前组不是最后一组，DMA 仲裁器接受请求。不要把预取画成越过当前发送数据；预取写入只进入空闲槽位。

## 图5-3 权重驻留、部分和保存与重量化输入关系

**输出文件名：** `report_figures/ai/fig05_03_weight_ps_requant.png`

**用途：** 用于展示权重固定阵列中权重装载、IA 输入、偏置或部分和初值选择、部分和保存和最终重量化输入之间的连接。

**详细提示词：** 绘制一张权重驻留和部分和数据通路图，白色背景，横向 16:9，标题为“权重驻留、部分和保存与重量化输入关系”。左上方放浅黄色“kernel_loader_buffer”，内部画两个权重槽位，标注 `weight_data_valid`、`store_weight_req`、`weight_out[SIZE]`。从该模块向中央阵列上方画橙色箭头，标注“权重列向量装入 PE 并保持”。左下方放浅绿色“IA cache 输出”，向阵列左侧画绿色箭头，标注“对角化输入激活向量”。

中央放浅红色“16x16 权重固定脉动阵列”，内部用网格 PE 表示。每一列顶部画一个小寄存器符号，标注“权重寄存”；每一行左侧画 IA 输入箭头。阵列下方输出 `sum_out[SIZE]`，进入浅绿色“ps_buffer 部分和帧”。ps_buffer 内部画两类路径：一条红色箭头写入“中间归约结果 int32”；一条绿色箭头读出“上一归约分块部分和”，回到左侧浅黄色“bias_mux”。bias_mux 的另一输入来自“bias_loader 输出 bias_in[SIZE]”，并由 `bias_sleep` 控制选择。旁边写明“首次归约使用 bias 或 0；后续归约使用部分和回灌”。

右侧放浅粉色“vec_requant 重量化流水”。从 ps_buffer 向 vec_requant 画红色箭头，标注 `acc_data_out[SIZE] / acc_data_valid`。vec_requant 旁边放“量化参数”小框，包含“按张量乘法系数与移位”“per-channel 乘法系数与移位”“输出偏移”“激活上下限”。从 vec_requant 到右侧“输出打包 FIFO”画箭头，标注 `int8 输出向量`。

图底部画一个归约分块序列：`N 分块 0` 使用 bias 初值并写部分和，`N 分块 1..倒数第二个` 读部分和并写回更新后的部分和，`N 最后分块` 读部分和并输出到重量化。每个阶段用色块表示，不写性能数字。不要把 int32 部分和画到外部 RAM；不要把 bias 在每个归约分块重复相加。

## 图5-4 分块DMA 读写客户端调度与 AXI 通道分配关系

**输出文件名：** `report_figures/ai/fig05_04_block_dma_arbiter_channels.png`

**用途：** 用于展示 `axi_block_dma_arbiter` 如何在 IA、权重、bias、量化参数读客户端和 OA 写客户端之间进行选择，并连接到 `axi_dual_block_dma` 的 AXI4 通道。

**详细提示词：** 绘制一张分块DMA 仲裁结构图，白色背景，横向 16:9，标题为“分块DMA 读写客户端调度与 AXI 通道分配关系”。左侧竖向排列四个浅蓝色读客户端：“IA 读客户端”“权重读客户端”“bias 读客户端”“量化参数读客户端”。每个客户端旁列出请求字段：`req`、`start`、`base_addr`、`row_stride`、`rows_to_read`、`burst_len_m1`、`slot_id`、`use_16bits`、`zero_point`。四个客户端箭头进入中央浅青色“读客户端选择器”。

中央上方放浅青色“axi_block_dma_arbiter 读侧”。内部画优先选择顺序：`kernel_req` 优先，其次 `quant_req`，其次 `ia_req`，最后 `bias_req`；再画寄存器 `rd_client`、`rd_active`、`rd_started`。从读侧选择器到右侧“axi_dual_block_dma 读引擎”画蓝色箭头，标注“多路选择后的读命令”。读引擎向最右侧“AXI4 主设备读通道”输出 `ARVALID/ARREADY/ARADDR/ARLEN`，再接收 `RVALID/RREADY/RDATA/RLAST`。读返回后从读引擎分别回到 IA、权重、bias、量化参数路径，箭头标注 `wr_slot`、`wr_row`、`wr_col_base`、`raw_data`、`raw_valid`。

左下方放浅粉色“OA 写客户端”，字段包括 `oa_req`、`oa_start`、`oa_base_addr`、`oa_row_stride`、`oa_rows_to_read`、`oa_burst_len_m1`、`oa_src_wdata`、`oa_src_wmask`、`oa_src_wvalid`。该客户端进入中央下方“写侧控制”，内部标注 `wr_active`、`wr_started`、`oa_granted`。写侧控制连接到“axi_dual_block_dma 写引擎”，写引擎输出 `AWVALID/AWREADY/AWADDR/AWLEN` 和 `WVALID/WREADY/WDATA/WSTRB/WLAST`，接收 `BVALID/BREADY/BRESP`。

在 DMA 读写引擎之间放一个小说明框：“读引擎和写引擎分别跟踪未完成事务，共用同一个 AXI4 主设备端口信号组”。在图中用不同颜色区分读地址、读数据、写地址、写数据、写响应。写响应箭头必须从 AXI B 通道回到写引擎，再回到 OA 写客户端，并标注“B 响应返回后产生写完成”。不要把四个读客户端画成各自独立 AXI 主设备。

## 图5-8 int8 输出打包、尾列字节写掩码与非对齐写回关系

**输出文件名：** `report_figures/ai/fig05_08_output_pack_wstrb_unaligned.png`

**用途：** 用于展示 `vec_s8_to_fifo` 和 `oa_writer` 如何把 int8 输出向量打包为 32 bit AXI 写数据，并在尾列或非 4 字节对齐地址下生成正确字节写掩码。

**详细提示词：** 绘制一张输出打包与写掩码结构图，白色背景，横向 16:9，标题为“int8 输出打包、尾列字节写掩码与非对齐写回关系”。左侧放浅粉色“vec_requant 输出”，画 16 个 int8 通道格，标注 `out_vec_s8[0]` 到 `out_vec_s8[15]`，其中尾列无效通道用灰色填充并写“不写”。从该向量进入浅绿色“vec_s8_to_fifo”，FIFO 内部画多个 bank，字段包括 `write_bank`、`read_bank`、`bank_ready`、`bank_count`、`fifo_full_flag`、`vec_valid_num_col`、`vec_valid_num_row`。

FIFO 右侧画“32 bit 输出数据拍生成”区域，每一行是一个 32 bit 字，内部由 4 个 8 bit 字节格组成，分别标注输出元素 `O0`、`O1`、`O2`、`O3`。完整数据拍的 `output_mask=1111`；尾列只剩 1、2、3 个有效字节时分别显示 `0001`、`0011`、`0111`。若首地址低位不为 0，在右侧 `oa_writer` 中画地址低位对写掩码左移或合并的示意，例如地址低位为 1 且写 3 字节时，最终 `WSTRB=1110`。所有示例必须标注“掩码为 1 的字节被写入，掩码为 0 的字节保持原值”。

右侧放浅青色“oa_writer 与 DMA 写引擎”，内部列出 `output_valid/output_ready`、`dma_src_wdata`、`dma_src_wmask`、`dma_base_addr`、`dma_row_stride`。再向最右侧浅绿色“DST 内存 32 bit 字”画红色 AXI 写箭头，标签为 `AWADDR`、`WDATA[31:0]`、`WSTRB[3:0]`、`BVALID`。在内存字中用不同颜色显示被修改字节和保持字节。不要把无效尾列画成写 0；不要使用英文模糊短语描述字节有效性。

## 图5-9 WS 与 IS 模式下阵列输入角色、输出坐标和写回次序关系

**输出文件名：** `report_figures/ai/fig05_09_ws_is_dataflow_coord.png`

**用途：** 用于展示 WS 权重固定模式与 IS 输入固定模式下阵列输入角色、输出产生顺序和最终 DST 行主序写回之间的关系。

**详细提示词：** 绘制一张左右对比图，白色背景，横向 16:9，标题为“WS 与 IS 模式下阵列输入角色、输出坐标和写回次序关系”。左半部分为“WS 权重固定模式”，右半部分为“IS 输入固定模式”。两侧都从共享 RAM 开始，包含 LHS 输入矩阵、RHS 权重矩阵、NPU 加载单元、脉动阵列、部分和缓冲区、vec_requant、vec_s8_to_fifo、oa_writer 和 DST 输出矩阵。两侧使用相同颜色体系，模块位置尽量对称，便于比较。

左侧 WS 模式中，RHS 权重分块从上方进入阵列并驻留在 PE 内，箭头标注“权重装载后保持”；LHS 输入激活从左侧以对角化时序进入，箭头标注“输入激活连续流入”；输出列组由权重分块决定，部分和按输出分块坐标保存。画一个小矩阵 C[K,M]，高亮当前输出列组和当前输出行组，箭头指向 DST 行主序位置。

右侧 IS 模式中，用不同箭头说明内部输入角色发生变化：输入相关数据优先保持，另一矩阵数据流入阵列，输出产生顺序需要通过 FIFO 坐标和 `oa_writer` 地址生成恢复到 DST 行主序。画 `cfg_dataflow_mode` 控制箭头从寄存器组进入加载单元、重量化和写回单元，标注“start 时锁存”。在右侧 C[K,M] 中使用与左侧相同的最终行列坐标，旁边写“软件可见 GEMM 结果布局相同”。

图底部放一条公共接口说明带，列出两种模式共用的外部接口：AXI-Lite 寄存器组、分块DMA、bias 与量化参数加载、状态寄存器、输出写回。不要把 WS 和 IS 画成两套不同外设；不要改变软件可见矩阵公式。

## 图6-4 软件驱动、TFLM/NMSIS-NN 接入层与 NPU MMIO 接口关系

**输出文件名：** `report_figures/ai/fig06_04_sw_tflm_mmio_interface.png`

**用途：** 用于展示软件推理入口、TFLM/NMSIS-NN 算子适配层、NPU 驱动、AXI-Lite MMIO 寄存器和共享 RAM 数据区之间的关系。

**详细提示词：** 绘制一张软硬件接口分层图，白色背景，横向 16:9，标题为“软件驱动、TFLM/NMSIS-NN 接入层与 NPU MMIO 接口关系”。画面从上到下分为三层。最上层为浅蓝色“应用推理与模型调度”，包含“模型输入”“TFLite Micro 推理入口”“算子调度”。中间层为浅蓝色“算子适配与驱动层”，从左到右放置“TFLM 全连接与卷积 im2col 后端”“NMSIS-NN 软件函数路径”“NPU 矩阵乘提交路径”“dsa_matmul_execute 驱动函数”。驱动函数旁列出任务结构字段：LHS/RHS/DST 基址、bias 基址、K/N/M、步长、零点、乘法系数、移位、激活上下限、WS/IS 模式、s8 或 s16 输入。

最下层为硬件接口。左下放浅黄色“NPU AXI-Lite MMIO 寄存器组”，内部按类别画小表格：“CONTROL”“STATUS”“LHS/RHS/DST/BIAS BASE”“K/N/M”“STRIDE”“ZERO POINT”“QUANT”“ACT RANGE”“REUSE 与 DATAFLOW”。中下放浅紫色“AXI 互连”，右下放浅红色“NPU 计算数据通路”，最右放浅绿色“共享 RAM 数据区”，内部包含“输入张量”“权重”“bias”“per-channel 参数”“im2col 缓冲区”“输出张量”。

从驱动层到 MMIO 寄存器组画蓝色箭头，标注“32 bit AXI-Lite 写配置、写 start、读 status”；从 NPU 到共享 RAM 画橙色箭头，标注“AXI4 分块DMA 读输入、读参数、写输出”；从共享 RAM 回到软件层画灰色箭头，标注“done 后软件读取输出”。在中间层增加一个选择器：当矩阵规模、数据类型和布局满足硬件条件时进入 NPU 提交路径；否则进入 NMSIS-NN 或普通软件函数路径。不要画自定义处理器指令，不要画 CPU 逐元素控制 PE。

## 图6-5 按张量与按通道量化参数组织及重量化流水对应关系

**输出文件名：** `report_figures/ai/fig06_05_quant_params_requant_pipeline.png`

**用途：** 用于说明 `vec_requant` 在按张量与 per-channel 量化模式下的参数来源、DMA 装载、参数缓冲和 11 级重量化流水关系。

**详细提示词：** 绘制一张量化参数组织与重量化流水图，白色背景，横向 16:9，标题为“按张量与按通道量化参数组织及重量化流水对应关系”。左侧分为上下两块参数来源。上块为浅黄色“按张量量化参数”，包含单个 `multiplier`、单个 `shift`、`dst_offset`、`activation_min`、`activation_max`，箭头直接进入 `vec_requant` 配置寄存。下块为浅绿色“per-channel 量化参数数组”，画两个数组“乘法系数数组”和“移位数组”，每个数组按输出通道索引排列；从数组到浅青色“量化参数 DMA 读客户端”画箭头，标注 `load_quant_req/load_quant_granted`、`dma_base_addr`、`dma_burst_len_m1`、`dma_raw_data/dma_raw_valid`。

中央放浅粉色大框“vec_requant”。框内上部为“参数控制状态机”，画三个状态 `IDLE`、`LOAD`、`COMPUTE`，并在 LOAD 内画两个子阶段 `PH_MUL` 和 `PH_SHIFT`。箭头条件写清楚：per-channel 且参数无效时由 IDLE 进入 LOAD；乘法系数装载完成后进入移位装载；两个数组片段均装载完成后 `quant_params_valid=1`；输入有效且参数有效时进入 COMPUTE。状态机旁放“参数缓冲 QBUF”，标注 `QBUF_DEPTH = VLEN × MAX_IA_REUSE`、`ch_multiplier`、`ch_lshift`、`ch_rshift`。

中央下部画“11 级重量化流水”，从左到右列出 stage0 到 stage11。每一级使用紧凑矩形，文字不要过多。阶段内容依次表达：采样 int32 累加值和参数、拆分乘法局部积、局部积求和、左移、取高位、右移舍入、加输出偏移、激活上下限钳位、int8 饱和、输出 valid。用一条并行细线表示 `tile_done` 标志从 stage0 同步延迟到 stage11。输入箭头为 `in_vec_s32[VLEN] / in_valid / in_tile_done`，输出箭头为 `out_vec_s8[VLEN] / out_valid / out_tile_done`。

右侧画一个输出通道索引示例。按张量模式下所有通道共享同一参数；per-channel 模式下 WS 模式按输出列选择参数，IS 模式按复用行组选择参数，并由 `cfg_dataflow_mode` 控制索引。尾列无效通道用灰色表示，标注“无效通道输出 0 且不写入有效输出字节”。不要写任何准确率或性能数值，图中只表达参数组织和硬件流水。

## 设计报告正文使用的脚本图

以下图形由 Mermaid、WaveDrom 或 Python 绘图脚本生成，不推荐用 AI 重绘。如需统一外观，应修改对应源文件或绘图脚本。

| 图形 | 源文件或图片 | 说明 |
|---|---|---|
| SoC 总体结构 | `report_figures/mermaid/fig01_system_arch.mmd` | Mermaid 源图，展示 PicoRV32、AXI 互连、RAM、外设和 NPU |
| NPU 内部结构 | `report_figures/mermaid/fig02_npu_module_arch.mmd` | Mermaid 源图，展示 NPU 子模块和 DMA 请求关系 |
| 分块数据流 | `report_figures/mermaid/fig03_blocked_dataflow.mmd` | Mermaid 源图，展示分块读取、片上复用、阵列计算和写回 |
| AXI-Lite 时序 | `report_figures/wavedrom/fig08_axil_write_read.json` | WaveDrom 源图，展示寄存器写读时序 |
| AXI4 读写时序 | `report_figures/wavedrom/fig09_axi_burst_read_write.json` | WaveDrom 源图，展示递增突发读写和写响应 |
| valid/ready 时序 | `report_figures/wavedrom/fig10_valid_ready_handshake.json` | WaveDrom 源图，展示反压下的数据保持规则 |
| 阵列规模与吞吐 | `report_figures/charts/fig11_tops_param_curve.png` | Python 脚本图，展示理想上限与实测吞吐 |
| 总线周期变化 | `perf_plots/bus_opt_evolution_cycles.png` | Python 脚本图，展示总线结构优化阶段 |
| 读写数据拍组成 | `perf_plots/bus_opt_read_write_512.png` | Python 脚本图，展示 512×512×512 任务读写组成 |
| 等待组成 | `perf_plots/bus_opt_stall_breakdown_512.png` | Python 脚本图，展示主要等待来源 |
| 不同矩阵尺寸周期 | `perf_plots/bus_opt_current_cycles_by_dim.png` | Python 脚本图，展示不同矩阵尺寸下 SoC 周期 |
| 总线数据拍压力 | `perf_plots/bus_opt_current_util_by_dim.png` | Python 脚本图，展示不同矩阵尺寸下读写数据拍比例 |
