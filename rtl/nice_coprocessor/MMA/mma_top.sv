// 矩阵乘累加(MMA)顶层模块
module mma_top #(
    parameter int unsigned WEIGHT_WIDTH = 16,  // 权重数据宽度；WS 下 s8 符号扩展，IS+s16 下使用 16bit LHS
    parameter int unsigned DATA_WIDTH = 16,  // IA数据宽度
    parameter int unsigned SIZE = 16,  // 阵列大小
    parameter int unsigned BUS_WIDTH = 32,  // 总线宽度
    parameter int unsigned REG_WIDTH = 32,  // 寄存器宽度
    parameter int unsigned ADDR_WIDTH = 19,  // 地址宽度
    parameter int unsigned ICB_LEN_W = 4,  // Legacy wrapper parameter; native AXI datapath does not use it
    parameter int unsigned IA_CACHE_BLOCKS = 4,  // IA loader cache slots；默认 IA reuse = IA_CACHE_BLOCKS/2
	    parameter int unsigned PS_FRAME_COUNT = SIZE,  // PS buffer 可保留的输出列 tile 数
	    parameter int unsigned AXI_READ_OUTSTANDING = 4,  // AXI 读通道最多提前排队的 burst 数
	    parameter int unsigned AXI_WRITE_OUTSTANDING = AXI_READ_OUTSTANDING  // AXI 写通道最多提前排队的 burst 数
) (
    //==== 时钟与复位 ====
    input wire clk,   // 系统时钟
    input wire rst_n, // 异步复位，低有效

    //==== 外部控制接口 ====
    input wire calc_start,  // 计算开始信号
    input wire cfg_16bits_ia,  // 使用16位IA数据
    input wire cfg_dataflow_mode,  // 0: WS, 1: IS
    input  logic [REG_WIDTH-1:0] cfg_ia_reuse_num,  // IA L1 组复用深度，0 表示使用参数默认值
    input  logic [REG_WIDTH-1:0] cfg_w_reuse_num,   // W 侧复用窗口，0 表示使用参数默认值
    output wire sa_ready,  // 系统就绪信号

    //==== 写回握手接口 ====
    output wire       wb_valid,  // 写回有效信号
    input  wire       wb_ready,  // 写回就绪信号
    output wire [1:0] err_code,  // 写回状态码

    // --- base pointers
    input logic [REG_WIDTH-1:0] lhs_base,  // A base         (MULT_LHS_PTR)
    input logic [REG_WIDTH-1:0] rhs_base,  // B base (s8)    (MULT_RHS_PTR, N x K row-major)
    input logic [REG_WIDTH-1:0] dst_base,  // C base (s8)    (MULT_DST_PTR)
    input logic [REG_WIDTH-1:0] bias_base, // bias s32 (0=none)   (MULT_BIAS_PTR)

    // --- quantization & zero-points ---
    input logic signed [REG_WIDTH-1:0] lhs_zp,          // A zero-point (s32)  (MULT_LHS_OFFSET)
    input logic signed [REG_WIDTH-1:0] rhs_zp,          // B zero-point (s32)  (MULT_RHS_OFFSET)
    input logic signed [REG_WIDTH-1:0] dst_zp,          // C zero-point (s32)  (MULT_DST_OFFSET)
    input logic signed [REG_WIDTH-1:0] q_mult_pt,       // per-tensor mult     (MULT_DST_MULT)
    input logic signed [REG_WIDTH-1:0] q_shift_pt,      // per-tensor rshift
    // (MULT_DST_SHIFT, +N => >>N)
    input logic                        use_per_channel, // 1: per-channel; 0: per-tensor

    // --- dimensions ---
    input logic [REG_WIDTH-1:0] k,  // IA矩阵行数
    input logic [REG_WIDTH-1:0] n,  // IA矩阵列数 = W矩阵行数
    input logic [REG_WIDTH-1:0] m,  // W矩阵列数

    // --- row strides (all in BYTES) ---
    input logic [REG_WIDTH-1:0] lhs_row_stride_b,  // A row stride       (MULT_LHS_COLS_OFFSET)
    input logic [REG_WIDTH-1:0] dst_row_stride_b,  // C row stride       (MULT_ROW_ADDR_OFFSET)
    input logic [REG_WIDTH-1:0] rhs_col_stride_b,  // B row stride       (MULT_RHS_ROW_STRIDE) （转置后的右矩阵是列展平的，所以这个步长本质上是列步长）

    // --- activation clamp ---
    input logic signed [REG_WIDTH-1:0] act_min,  // (MULT_ACT_MIN)
    input logic signed [REG_WIDTH-1:0] act_max,  // (MULT_ACT_MAX)

    //==== AXI4 master 接口 ====
    output logic                   m_axi_arvalid,
    input  logic                   m_axi_arready,
    output logic [  REG_WIDTH-1:0] m_axi_araddr,
    output logic [            7:0] m_axi_arlen,
    output logic [            2:0] m_axi_arsize,
    output logic [            1:0] m_axi_arburst,
    input  logic                   m_axi_rvalid,
    output logic                   m_axi_rready,
    input  logic [  BUS_WIDTH-1:0] m_axi_rdata,
    input  logic [            1:0] m_axi_rresp,
    input  logic                   m_axi_rlast,

    output logic                   m_axi_awvalid,
    input  logic                   m_axi_awready,
    output logic [  REG_WIDTH-1:0] m_axi_awaddr,
    output logic [            7:0] m_axi_awlen,
    output logic [            2:0] m_axi_awsize,
    output logic [            1:0] m_axi_awburst,
    output logic                   m_axi_wvalid,
    input  logic                   m_axi_wready,
    output logic [  BUS_WIDTH-1:0] m_axi_wdata,
    output logic [BUS_WIDTH/8-1:0] m_axi_wstrb,
    output logic                   m_axi_wlast,
    input  logic                   m_axi_bvalid,
    output logic                   m_axi_bready,
    input  logic [            1:0] m_axi_bresp
);

	    //========================================
	    // 内部信号定义
	    //========================================
	    localparam int unsigned BIAS_DMA_SIZE = SIZE * 4;
	    localparam int unsigned SHARED_DMA_SIZE =
	        (BIAS_DMA_SIZE > SIZE) ? BIAS_DMA_SIZE : SIZE;

    // IA Loader 内部信号
    wire load_ia_req;
    wire load_ia_granted;
    wire send_ia_trigger;
    wire ia_sending_done;
    wire ia_row_valid;
    wire ia_tile_start;
    wire ia_is_init_data;
    wire ia_calc_done;
    wire partial_sum_calc_over;
    wire signed [DATA_WIDTH-1:0] ia_out[SIZE];
    wire ia_data_valid;
    wire ia_l1_switch;
    wire bias_sleep;
    wire bias_switch;
    wire bias_last_loop;

    // Kernel Loader 内部信号
    wire load_weight_req;
    wire load_weight_granted;
    wire send_weight_trigger;
    wire weight_sending_done;
    wire load_weight_done;
    wire store_weight_req;
    wire signed [WEIGHT_WIDTH-1:0] weight_out[SIZE];
    wire weight_data_valid;

    // Bias Loader 内部信号
    wire load_bias_req;
    wire load_bias_granted;
    wire bias_valid;
    wire next_bias_valid;
    wire bias_group_valid;
    wire load_bias_done;
    wire signed [31:0] bias_data_out[SIZE];
    wire signed [31:0] next_bias_data_out[SIZE];

    // Accumulator Array 输出（来自封装模块）
    wire acc_data_valid;
    wire tile_calc_over;
    wire signed [31:0] acc_data_out[SIZE];

    // Requantization 内部信号
    wire load_quant_req;
    wire load_quant_granted;
    wire quant_params_valid;
    wire requant_out_valid;
    wire requant_out_tile_done;
    wire signed [7:0] requant_out[SIZE];

    // FIFO 内部信号
    wire fifo_output_req;
    wire [$clog2(SIZE)-1:0] fifo_vec_valid_num_col;
    wire [$clog2(SIZE)-1:0] fifo_vec_valid_num_row;
    wire fifo_output_valid;
    wire fifo_output_switch_row;
    wire fifo_output_ready;
    wire [3:0] fifo_output_mask;
    wire [31:0] fifo_output_data;
    wire fifo_full_flag;

	    // OA Writer 内部信号
	    wire write_oa_req;
	    wire write_oa_granted;
	    wire write_done;
	    wire oa_calc_over;

	    // Shared block_dma client signals
	    logic ia_dma_start, ia_dma_linear_read_mode;
	    logic [REG_WIDTH-1:0] ia_dma_base_addr, ia_dma_row_stride, ia_dma_rows_to_read;
	    logic [3:0] ia_dma_burst_len_m1;
	    logic [$clog2(IA_CACHE_BLOCKS)-1:0] ia_dma_slot_id;
	    logic ia_dma_use_16bits;
	    logic signed [REG_WIDTH-1:0] ia_dma_lhs_zp;
	    logic ia_dma_busy, ia_dma_done;
	    logic [$clog2(IA_CACHE_BLOCKS)-1:0] ia_dma_wr_slot;
	    logic [$clog2(SIZE)-1:0] ia_dma_wr_row, ia_dma_wr_col_base;
	    logic signed [DATA_WIDTH-1:0] ia_dma_wr_data[BUS_WIDTH/8];
	    logic ia_dma_wr_valid[BUS_WIDTH/8];
	    logic ia_dma_wr_use_16bits;

	    logic kernel_dma_start, kernel_dma_linear_read_mode;
	    logic [REG_WIDTH-1:0] kernel_dma_base_addr, kernel_dma_row_stride, kernel_dma_rows_to_read;
	    logic [3:0] kernel_dma_burst_len_m1;
	    logic kernel_dma_slot_id, kernel_dma_use_16bits;
	    logic signed [REG_WIDTH-1:0] kernel_dma_lhs_zp;
	    logic kernel_dma_busy, kernel_dma_done;
	    logic [$clog2(SIZE)-1:0] kernel_dma_wr_row, kernel_dma_wr_col_base;
	    logic signed [WEIGHT_WIDTH-1:0] kernel_dma_wr_data[BUS_WIDTH/8];
	    logic kernel_dma_wr_valid[BUS_WIDTH/8];

	    logic bias_dma_start, bias_dma_linear_read_mode;
	    logic [REG_WIDTH-1:0] bias_dma_base_addr, bias_dma_row_stride, bias_dma_rows_to_read;
	    logic [3:0] bias_dma_burst_len_m1;
	    logic bias_dma_slot_id, bias_dma_use_16bits;
	    logic signed [REG_WIDTH-1:0] bias_dma_lhs_zp;
	    logic bias_dma_busy, bias_dma_done, bias_dma_wr_slot, bias_dma_wr_use_16bits;
	    logic [$clog2(BIAS_DMA_SIZE)-1:0] bias_dma_wr_row, bias_dma_wr_col_base;
	    logic signed [7:0] bias_dma_wr_data[BUS_WIDTH/8];
	    logic bias_dma_wr_valid[BUS_WIDTH/8];

	    logic quant_dma_start, quant_dma_linear_read_mode;
	    logic [REG_WIDTH-1:0] quant_dma_base_addr, quant_dma_row_stride, quant_dma_rows_to_read;
	    logic [3:0] quant_dma_burst_len_m1;
	    logic quant_dma_slot_id, quant_dma_use_16bits;
	    logic signed [REG_WIDTH-1:0] quant_dma_lhs_zp;
	    logic quant_dma_busy, quant_dma_done;
	    logic [BUS_WIDTH-1:0] quant_dma_raw_data;
	    logic quant_dma_raw_valid;

	    logic oa_dma_start;
	    logic [REG_WIDTH-1:0] oa_dma_base_addr, oa_dma_row_stride, oa_dma_rows_to_read;
	    logic [3:0] oa_dma_burst_len_m1;
	    logic [BUS_WIDTH-1:0] oa_dma_src_wdata;
	    logic [BUS_WIDTH/8-1:0] oa_dma_src_wmask;
	    logic oa_dma_src_wvalid, oa_dma_src_wready, oa_dma_busy, oa_dma_done;

    // 添加缺少的内部信号
    // per-submodule init_cfg signals (由mma_controller产生的单拍脉冲)
    wire init_cfg_ia;
    wire init_cfg_weight;
    wire init_cfg_bias;
    wire init_cfg_requant;
    wire init_cfg_oa;
    wire use_16bits;  // 16位数据指示信号
    wire [REG_WIDTH-1:0] tile_count;  // 分块计数信号
	    localparam int unsigned IA_REUSE_NUM_MAX =
	        (IA_CACHE_BLOCKS < 2) ? 1 : (IA_CACHE_BLOCKS / 2);
	    localparam int unsigned SIZE_SHIFT = $clog2(SIZE);
	    localparam int unsigned W_REUSE_NUM_MAX =
	        (PS_FRAME_COUNT < 1) ? 1 : PS_FRAME_COUNT;
	    localparam int unsigned IA_REUSE_W =
	        (IA_REUSE_NUM_MAX <= 1) ? 1 : ($clog2(IA_REUSE_NUM_MAX) + 1);
	    localparam int unsigned W_REUSE_W =
	        (W_REUSE_NUM_MAX <= 1) ? 1 : ($clog2(W_REUSE_NUM_MAX) + 1);
	    localparam int unsigned OA_FIFO_BANKS = PS_FRAME_COUNT * IA_REUSE_NUM_MAX;
				    localparam int unsigned IS_BIAS_ROWS = IA_REUSE_NUM_MAX * SIZE;
				    localparam int unsigned IS_BIAS_ROW_W = (IS_BIAS_ROWS <= 1) ? 1 : $clog2(IS_BIAS_ROWS);
				    wire signed [31:0] bias_group_data_out[IS_BIAS_ROWS];

	    function automatic logic [REG_WIDTH-1:0] floor_pow2_ia(input logic [IA_REUSE_W-1:0] value);
	        logic [REG_WIDTH-1:0] out;
	        begin
	            out = REG_WIDTH'(1);
	            for (int bit_i = 1; bit_i < IA_REUSE_W; bit_i++) begin
	                if (value >= (IA_REUSE_W'(1) << bit_i)) begin
	                    out = (REG_WIDTH'(1) << bit_i);
	                end
	            end
	            floor_pow2_ia = out;
	        end
	    endfunction

	    function automatic logic [REG_WIDTH-1:0] floor_pow2_w(input logic [W_REUSE_W-1:0] value);
	        logic [REG_WIDTH-1:0] out;
	        begin
	            out = REG_WIDTH'(1);
	            for (int bit_i = 1; bit_i < W_REUSE_W; bit_i++) begin
	                if (value >= (W_REUSE_W'(1) << bit_i)) begin
	                    out = (REG_WIDTH'(1) << bit_i);
	                end
	            end
	            floor_pow2_w = out;
	        end
	    endfunction

	    wire ctrl_sa_ready;
	    logic cfg_stage0_valid;
	    logic cfg_stage1_valid;
	    logic cfg_stage2_valid;
	    logic cfg_mode_s0;
	    logic cfg_use16_s0;
	    logic [REG_WIDTH-1:0] cfg_k_s0;
	    logic [REG_WIDTH-1:0] cfg_m_s0;
	    logic [REG_WIDTH-1:0] cfg_n_s0;
	    logic [REG_WIDTH-1:0] cfg_stream_k_s0;
	    logic [REG_WIDTH-1:0] cfg_stream_m_s0;
	    logic [REG_WIDTH-1:0] cfg_ia_req_s0;
	    logic [REG_WIDTH-1:0] cfg_w_req_s0;
	    logic cfg_mode_s1;
	    logic cfg_use16_s1;
	    logic [REG_WIDTH-1:0] cfg_k_s1;
	    logic [REG_WIDTH-1:0] cfg_m_s1;
	    logic [REG_WIDTH-1:0] cfg_n_s1;
	    logic [REG_WIDTH-1:0] cfg_stream_k_s1;
	    logic [REG_WIDTH-1:0] cfg_stream_m_s1;
	    logic [REG_WIDTH-1:0] cfg_ia_req_s1;
	    logic [REG_WIDTH-1:0] cfg_w_req_s1;
	    logic [REG_WIDTH-1:0] cfg_ia_cap_raw_s1;
	    logic [REG_WIDTH-1:0] cfg_w_cap_raw_s1;
	    logic cfg_mode_s2;
	    logic cfg_use16_s2;
	    logic [REG_WIDTH-1:0] cfg_k_s2;
	    logic [REG_WIDTH-1:0] cfg_m_s2;
	    logic [REG_WIDTH-1:0] cfg_n_s2;
	    logic [REG_WIDTH-1:0] cfg_stream_k_s2;
	    logic [REG_WIDTH-1:0] cfg_stream_m_s2;
	    logic [REG_WIDTH-1:0] cfg_ia_reuse_eff_s2;
	    logic [REG_WIDTH-1:0] cfg_w_reuse_eff_s2;
	    logic [REG_WIDTH-1:0] cfg_bias_rows_target_s2;

	    wire cfg_start_event = calc_start && sa_ready;
	    wire cfg_stage2_fire = cfg_stage2_valid && ctrl_sa_ready;
	    wire ctrl_calc_start = cfg_stage2_fire;
	    assign sa_ready = ctrl_sa_ready && !cfg_stage0_valid && !cfg_stage1_valid && !cfg_stage2_valid;

	    wire cfg_is_mode_pre = cfg_mode_s0;
	    wire [REG_WIDTH-1:0] cfg_stream_k_pre = cfg_stream_k_s0;
	    wire [REG_WIDTH-1:0] cfg_stream_m_pre = cfg_stream_m_s0;
	    wire [REG_WIDTH-1:0] output_row_tile_num_pre =
	        (cfg_stream_k_pre + REG_WIDTH'(SIZE - 1)) >> SIZE_SHIFT;
	    wire [REG_WIDTH-1:0] output_col_tile_num_pre =
	        (cfg_stream_m_pre + REG_WIDTH'(SIZE - 1)) >> SIZE_SHIFT;
	    wire [REG_WIDTH-1:0] ia_reuse_capacity_limit_raw_pre =
	        ((output_row_tile_num_pre != '0) &&
	         (output_row_tile_num_pre < REG_WIDTH'(IA_REUSE_NUM_MAX)))
	            ? output_row_tile_num_pre
	            : REG_WIDTH'(IA_REUSE_NUM_MAX);
	    wire [REG_WIDTH-1:0] w_reuse_capacity_limit_raw_pre =
	        ((output_col_tile_num_pre != '0) &&
	         (output_col_tile_num_pre < REG_WIDTH'(W_REUSE_NUM_MAX)))
	            ? output_col_tile_num_pre
	            : REG_WIDTH'(W_REUSE_NUM_MAX);
	    wire [REG_WIDTH-1:0] ia_reuse_capacity_limit_s1 =
	        floor_pow2_ia(cfg_ia_cap_raw_s1[IA_REUSE_W-1:0]);
	    wire [REG_WIDTH-1:0] w_reuse_capacity_limit_s1 =
	        floor_pow2_w(cfg_w_cap_raw_s1[W_REUSE_W-1:0]);
	    wire [IA_REUSE_W-1:0] ia_reuse_cfg_small_s1 =
	        (cfg_ia_req_s1 == '0) ? ia_reuse_capacity_limit_s1[IA_REUSE_W-1:0] :
	        (cfg_ia_req_s1 >= ia_reuse_capacity_limit_s1)
	            ? ia_reuse_capacity_limit_s1[IA_REUSE_W-1:0]
	            : cfg_ia_req_s1[IA_REUSE_W-1:0];
	    wire [W_REUSE_W-1:0] w_reuse_cfg_small_s1 =
	        (cfg_w_req_s1 == '0) ? w_reuse_capacity_limit_s1[W_REUSE_W-1:0] :
	        (cfg_w_req_s1 >= w_reuse_capacity_limit_s1)
	            ? w_reuse_capacity_limit_s1[W_REUSE_W-1:0]
	            : cfg_w_req_s1[W_REUSE_W-1:0];
	    wire [REG_WIDTH-1:0] ia_reuse_num_eff_ws_s1 = floor_pow2_ia(ia_reuse_cfg_small_s1);
	    wire [REG_WIDTH-1:0] w_reuse_num_clamped_max_s1 = floor_pow2_w(w_reuse_cfg_small_s1);
	    wire [REG_WIDTH-1:0] ia_reuse_num_eff_s1 =
	        (cfg_mode_s1 && (ia_reuse_num_eff_ws_s1 > w_reuse_capacity_limit_s1))
	            ? w_reuse_capacity_limit_s1
	            : ia_reuse_num_eff_ws_s1;
	    wire [REG_WIDTH-1:0] w_reuse_num_eff_s1 =
	        (cfg_mode_s1 && (w_reuse_num_clamped_max_s1 < ia_reuse_num_eff_s1) &&
	         (cfg_w_cap_raw_s1 >= ia_reuse_num_eff_s1))
	            ? ia_reuse_num_eff_s1
	            : w_reuse_num_clamped_max_s1;

	    always_ff @(posedge clk or negedge rst_n) begin
	        if (!rst_n) begin
		            cfg_stage0_valid <= 1'b0;
		            cfg_stage1_valid <= 1'b0;
		            cfg_stage2_valid <= 1'b0;
		            cfg_mode_s0 <= 1'b0;
		            cfg_use16_s0 <= 1'b0;
		            cfg_k_s0 <= '0;
		            cfg_m_s0 <= '0;
		            cfg_n_s0 <= '0;
		            cfg_stream_k_s0 <= '0;
		            cfg_stream_m_s0 <= '0;
		            cfg_ia_req_s0 <= '0;
		            cfg_w_req_s0 <= '0;
		            cfg_mode_s1 <= 1'b0;
		            cfg_use16_s1 <= 1'b0;
		            cfg_k_s1 <= '0;
		            cfg_m_s1 <= '0;
		            cfg_n_s1 <= '0;
		            cfg_stream_k_s1 <= '0;
		            cfg_stream_m_s1 <= '0;
		            cfg_ia_req_s1 <= '0;
		            cfg_w_req_s1 <= '0;
		            cfg_ia_cap_raw_s1 <= REG_WIDTH'(1);
		            cfg_w_cap_raw_s1 <= REG_WIDTH'(1);
		            cfg_mode_s2 <= 1'b0;
		            cfg_use16_s2 <= 1'b0;
		            cfg_k_s2 <= '0;
		            cfg_m_s2 <= '0;
		            cfg_n_s2 <= '0;
		            cfg_stream_k_s2 <= '0;
		            cfg_stream_m_s2 <= '0;
		            cfg_ia_reuse_eff_s2 <= REG_WIDTH'(1);
		            cfg_w_reuse_eff_s2 <= REG_WIDTH'(1);
		            cfg_bias_rows_target_s2 <= REG_WIDTH'(SIZE);
		        end else begin
		            if (cfg_stage2_fire) begin
		                cfg_stage2_valid <= 1'b0;
		            end

		            if (cfg_stage1_valid && !cfg_stage2_valid) begin
		                cfg_stage2_valid <= 1'b1;
		                cfg_stage1_valid <= 1'b0;
		                cfg_mode_s2 <= cfg_mode_s1;
		                cfg_use16_s2 <= cfg_use16_s1;
		                cfg_k_s2 <= cfg_k_s1;
		                cfg_m_s2 <= cfg_m_s1;
		                cfg_n_s2 <= cfg_n_s1;
		                cfg_stream_k_s2 <= cfg_stream_k_s1;
		                cfg_stream_m_s2 <= cfg_stream_m_s1;
		                cfg_ia_reuse_eff_s2 <= ia_reuse_num_eff_s1;
		                cfg_w_reuse_eff_s2 <= w_reuse_num_eff_s1;
		                cfg_bias_rows_target_s2 <= ia_reuse_num_eff_s1 << SIZE_SHIFT;
		            end

		            if (cfg_stage0_valid && !cfg_stage1_valid) begin
		                cfg_stage1_valid <= 1'b1;
		                cfg_stage0_valid <= 1'b0;
	                cfg_mode_s1 <= cfg_mode_s0;
	                cfg_use16_s1 <= cfg_use16_s0;
	                cfg_k_s1 <= cfg_k_s0;
	                cfg_m_s1 <= cfg_m_s0;
		                cfg_n_s1 <= cfg_n_s0;
		                cfg_stream_k_s1 <= cfg_stream_k_s0;
		                cfg_stream_m_s1 <= cfg_stream_m_s0;
		                cfg_ia_req_s1 <= cfg_ia_req_s0;
		                cfg_w_req_s1 <= cfg_w_req_s0;
		                cfg_ia_cap_raw_s1 <= ia_reuse_capacity_limit_raw_pre;
		                cfg_w_cap_raw_s1 <= w_reuse_capacity_limit_raw_pre;
		            end

		            if (cfg_start_event) begin
		                cfg_stage0_valid <= 1'b1;
	                cfg_mode_s0 <= cfg_dataflow_mode;
	                cfg_use16_s0 <= cfg_16bits_ia;
	                cfg_k_s0 <= k;
	                cfg_m_s0 <= m;
		                cfg_n_s0 <= n;
		                cfg_stream_k_s0 <= cfg_dataflow_mode ? m : k;
		                cfg_stream_m_s0 <= cfg_dataflow_mode ? k : m;
		                cfg_ia_req_s0 <= cfg_ia_reuse_num;
		                cfg_w_req_s0 <= cfg_w_reuse_num;
		            end
		        end
		    end

	    logic run_is_mode;
	    logic run_use_16bits;
	    logic [REG_WIDTH-1:0] run_k;
	    logic [REG_WIDTH-1:0] run_m;
	    logic [REG_WIDTH-1:0] run_n;
	    logic [REG_WIDTH-1:0] stream_k;
	    logic [REG_WIDTH-1:0] stream_m;
	    logic [REG_WIDTH-1:0] ia_reuse_num_eff;
	    logic [REG_WIDTH-1:0] w_reuse_num_eff;
	    logic [REG_WIDTH-1:0] is_bias_group_rows_target;

	    always_ff @(posedge clk or negedge rst_n) begin
	        if (!rst_n) begin
	            run_is_mode <= 1'b0;
	            run_use_16bits <= 1'b0;
	            run_k <= '0;
	            run_m <= '0;
	            run_n <= '0;
	            stream_k <= '0;
	            stream_m <= '0;
	            ia_reuse_num_eff <= REG_WIDTH'(1);
	            w_reuse_num_eff <= REG_WIDTH'(1);
	            is_bias_group_rows_target <= REG_WIDTH'(SIZE);
	        end else if (cfg_stage2_fire) begin
	            run_is_mode <= cfg_mode_s2;
	            run_use_16bits <= cfg_use16_s2;
	            run_k <= cfg_k_s2;
	            run_m <= cfg_m_s2;
	            run_n <= cfg_n_s2;
	            stream_k <= cfg_stream_k_s2;
	            stream_m <= cfg_stream_m_s2;
	            ia_reuse_num_eff <= cfg_ia_reuse_eff_s2;
	            w_reuse_num_eff <= cfg_w_reuse_eff_s2;
	            is_bias_group_rows_target <= cfg_bias_rows_target_s2;
	        end
	    end

	    wire is_mode = run_is_mode;
	    wire [REG_WIDTH-1:0] ia_base_eff = is_mode ? rhs_base : lhs_base;
	    wire [REG_WIDTH-1:0] ia_stride_eff = is_mode ? rhs_col_stride_b : lhs_row_stride_b;
	    wire signed [REG_WIDTH-1:0] ia_zp_eff = is_mode ? rhs_zp : lhs_zp;
	    wire ia_use_16bits_eff = is_mode ? 1'b0 : run_use_16bits;
	    wire [REG_WIDTH-1:0] weight_base_eff = is_mode ? lhs_base : rhs_base;
	    wire [REG_WIDTH-1:0] weight_stride_eff = is_mode ? lhs_row_stride_b : rhs_col_stride_b;
	    wire signed [REG_WIDTH-1:0] weight_zp_eff = is_mode ? lhs_zp : rhs_zp;
	    wire weight_use_16bits_eff = is_mode ? run_use_16bits : 1'b0;
	    wire compute_bias_sleep = bias_sleep;

	    axi_block_dma_arbiter #(
	        .DATA_WIDTH  (DATA_WIDTH),
	        .KERNEL_WIDTH(WEIGHT_WIDTH),
	        .SIZE        (SIZE),
	        .DMA_SIZE    (SHARED_DMA_SIZE),
	        .BUS_WIDTH   (BUS_WIDTH),
	        .REG_WIDTH   (REG_WIDTH),
	        .CACHE_BLOCKS(IA_CACHE_BLOCKS),
	        .READ_OUTSTANDING(AXI_READ_OUTSTANDING),
	        .WRITE_OUTSTANDING(AXI_WRITE_OUTSTANDING)
	    ) u_block_dma_arbiter (
	        .clk                     (clk),
	        .rst_n                   (rst_n),
		        .ia_req                  (load_ia_req),
		        .ia_granted              (load_ia_granted),
		        .ia_start                (ia_dma_start),
		        .ia_linear_read_mode     (ia_dma_linear_read_mode),
	        .ia_base_addr            (ia_dma_base_addr),
	        .ia_row_stride           (ia_dma_row_stride),
	        .ia_rows_to_read         (ia_dma_rows_to_read),
	        .ia_burst_len_m1         (ia_dma_burst_len_m1),
	        .ia_slot_id              (ia_dma_slot_id),
	        .ia_use_16bits           (ia_dma_use_16bits),
	        .ia_lhs_zp               (ia_dma_lhs_zp),
	        .ia_busy                 (ia_dma_busy),
	        .ia_done                 (ia_dma_done),
	        .ia_wr_slot              (ia_dma_wr_slot),
	        .ia_wr_row               (ia_dma_wr_row),
	        .ia_wr_col_base          (ia_dma_wr_col_base),
	        .ia_wr_data              (ia_dma_wr_data),
	        .ia_wr_valid             (ia_dma_wr_valid),
	        .ia_wr_use_16bits        (ia_dma_wr_use_16bits),
		        .kernel_req              (load_weight_req),
		        .kernel_granted          (load_weight_granted),
		        .kernel_start            (kernel_dma_start),
		        .kernel_linear_read_mode (kernel_dma_linear_read_mode),
	        .kernel_base_addr        (kernel_dma_base_addr),
	        .kernel_row_stride       (kernel_dma_row_stride),
	        .kernel_rows_to_read     (kernel_dma_rows_to_read),
	        .kernel_burst_len_m1     (kernel_dma_burst_len_m1),
	        .kernel_slot_id          (kernel_dma_slot_id),
	        .kernel_use_16bits       (kernel_dma_use_16bits),
	        .kernel_lhs_zp           (kernel_dma_lhs_zp),
	        .kernel_busy             (kernel_dma_busy),
	        .kernel_done             (kernel_dma_done),
	        .kernel_wr_row           (kernel_dma_wr_row),
	        .kernel_wr_col_base      (kernel_dma_wr_col_base),
	        .kernel_wr_data          (kernel_dma_wr_data),
	        .kernel_wr_valid         (kernel_dma_wr_valid),
		        .bias_req                (load_bias_req),
		        .bias_granted            (load_bias_granted),
		        .bias_start              (bias_dma_start),
		        .bias_linear_read_mode   (bias_dma_linear_read_mode),
	        .bias_base_addr          (bias_dma_base_addr),
	        .bias_row_stride         (bias_dma_row_stride),
	        .bias_rows_to_read       (bias_dma_rows_to_read),
	        .bias_burst_len_m1       (bias_dma_burst_len_m1),
	        .bias_slot_id            (bias_dma_slot_id),
	        .bias_use_16bits         (bias_dma_use_16bits),
	        .bias_lhs_zp             (bias_dma_lhs_zp),
	        .bias_busy               (bias_dma_busy),
	        .bias_done               (bias_dma_done),
	        .bias_wr_slot            (bias_dma_wr_slot),
	        .bias_wr_row             (bias_dma_wr_row),
	        .bias_wr_col_base        (bias_dma_wr_col_base),
	        .bias_wr_data            (bias_dma_wr_data),
	        .bias_wr_valid           (bias_dma_wr_valid),
	        .bias_wr_use_16bits      (bias_dma_wr_use_16bits),
		        .quant_req               (load_quant_req),
		        .quant_granted           (load_quant_granted),
		        .quant_start             (quant_dma_start),
		        .quant_linear_read_mode  (quant_dma_linear_read_mode),
	        .quant_base_addr         (quant_dma_base_addr),
	        .quant_row_stride        (quant_dma_row_stride),
	        .quant_rows_to_read      (quant_dma_rows_to_read),
	        .quant_burst_len_m1      (quant_dma_burst_len_m1),
	        .quant_slot_id           (quant_dma_slot_id),
	        .quant_use_16bits        (quant_dma_use_16bits),
	        .quant_lhs_zp            (quant_dma_lhs_zp),
	        .quant_busy              (quant_dma_busy),
	        .quant_done              (quant_dma_done),
	        .quant_raw_data          (quant_dma_raw_data),
	        .quant_raw_valid         (quant_dma_raw_valid),
		        .oa_req                  (write_oa_req),
		        .oa_granted              (write_oa_granted),
		        .oa_start                (oa_dma_start),
		        .oa_base_addr            (oa_dma_base_addr),
		        .oa_row_stride           (oa_dma_row_stride),
		        .oa_rows_to_read         (oa_dma_rows_to_read),
		        .oa_burst_len_m1         (oa_dma_burst_len_m1),
		        .oa_src_wdata            (oa_dma_src_wdata),
	        .oa_src_wmask            (oa_dma_src_wmask),
	        .oa_src_wvalid           (oa_dma_src_wvalid),
	        .oa_src_wready           (oa_dma_src_wready),
	        .oa_busy                 (oa_dma_busy),
	        .oa_done                 (oa_dma_done),
	        .m_axi_arvalid           (m_axi_arvalid),
	        .m_axi_arready           (m_axi_arready),
	        .m_axi_araddr            (m_axi_araddr),
	        .m_axi_arlen             (m_axi_arlen),
	        .m_axi_arsize            (m_axi_arsize),
	        .m_axi_arburst           (m_axi_arburst),
	        .m_axi_rvalid            (m_axi_rvalid),
	        .m_axi_rready            (m_axi_rready),
	        .m_axi_rdata             (m_axi_rdata),
	        .m_axi_rresp             (m_axi_rresp),
	        .m_axi_rlast             (m_axi_rlast),
	        .m_axi_awvalid           (m_axi_awvalid),
	        .m_axi_awready           (m_axi_awready),
	        .m_axi_awaddr            (m_axi_awaddr),
	        .m_axi_awlen             (m_axi_awlen),
	        .m_axi_awsize            (m_axi_awsize),
	        .m_axi_awburst           (m_axi_awburst),
	        .m_axi_wvalid            (m_axi_wvalid),
	        .m_axi_wready            (m_axi_wready),
	        .m_axi_wdata             (m_axi_wdata),
	        .m_axi_wstrb             (m_axi_wstrb),
	        .m_axi_wlast             (m_axi_wlast),
	        .m_axi_bvalid            (m_axi_bvalid),
	        .m_axi_bready            (m_axi_bready),
	        .m_axi_bresp             (m_axi_bresp)
	    );

	    //========================================
    // 模块实例化
    //========================================

	    // MMA 控制器
    mma_controller #(
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .SIZE        (SIZE),
        .BUS_WIDTH   (BUS_WIDTH),
        .REG_WIDTH   (REG_WIDTH)
    ) u_mma_controller (
        .clk              (clk),
        .rst_n            (rst_n),
        .calc_start       (ctrl_calc_start),
        .cfg_16bits_ia    (cfg_16bits_ia),
        .cfg_dataflow_mode(cfg_dataflow_mode),
        .sa_ready         (ctrl_sa_ready),

        .partial_sum_calc_over(partial_sum_calc_over),
        .tile_calc_over       (tile_calc_over),
	        .init_cfg_ia          (init_cfg_ia),
        .init_cfg_weight      (init_cfg_weight),
        .init_cfg_bias        (init_cfg_bias),
        .init_cfg_requant     (init_cfg_requant),
        .init_cfg_oa          (init_cfg_oa),
        .use_16bits           (use_16bits),
        // 新增配置参数连接
        .lhs_base             (lhs_base),
        .rhs_base             (rhs_base),
        .dst_base             (dst_base),
        .bias_base            (bias_base),
        .q_mult_pt            (q_mult_pt),
        .q_shift_pt           (q_shift_pt),
        .use_per_channel      (use_per_channel),
        .k                    (k),
        .n                    (n),
        .m                    (m),
        .lhs_row_stride_b     (lhs_row_stride_b),
        .dst_row_stride_b     (dst_row_stride_b),
        .rhs_col_stride_b     (rhs_col_stride_b),
	        // IA Loader Interface
	        .send_ia_trigger      (send_ia_trigger),
	        .ia_sending_done      (ia_sending_done),
	        .ia_data_valid        (ia_data_valid),
		        // Weight Loader Interface
	        .send_weight_trigger  (send_weight_trigger),
        .weight_sending_done  (weight_sending_done),
        .weight_data_valid    (weight_data_valid),
	        // Bias Loader Interface
	        .bias_valid           (bias_group_valid),
	        .bias_sleep           (bias_sleep),
	        // Requantization Interface
	        .quant_params_valid   (quant_params_valid),
        // FIFO Interface
        .fifo_full_flag       (fifo_full_flag),
	        // OA Writer Interface
	        .oa_calc_over         (oa_calc_over),
        // Writeback Handshake Interface
        .wb_valid             (wb_valid),
        .wb_ready             (wb_ready),
        .err_code             (err_code)
    );
	    // IA Loader
	    ia_loader #(
	        .DATA_WIDTH  (DATA_WIDTH),
	        .SIZE        (SIZE),
	        .BUS_WIDTH   (BUS_WIDTH),
	        .REG_WIDTH   (REG_WIDTH),
	        .CACHE_BLOCKS(IA_CACHE_BLOCKS),
	        .PS_FRAME_COUNT(PS_FRAME_COUNT),
	        .EXTERNAL_DMA(1'b1)
	    ) u_ia_loader (
        .clk             (clk),
        .rst_n           (rst_n),
        .init_cfg        (init_cfg_ia),
        .load_ia_req     (load_ia_req),
        .load_ia_granted (load_ia_granted),
	        .send_ia_trigger (send_ia_trigger),
	        .k               (stream_k),
	        .n               (run_n),
	        .m               (stream_m),
        .lhs_zp          (ia_zp_eff),
        .lhs_row_stride_b(ia_stride_eff),
        .lhs_base        (ia_base_eff),
        .use_16bits      (ia_use_16bits_eff),
        .bias_by_row_mode(is_mode),
        .ia_reuse_num    (ia_reuse_num_eff),
        .w_reuse_num     (w_reuse_num_eff),


        // .icb_cmd_m       (ia_loader_cmd),
        // .icb_cmd_s       (ia_loader_cmd_ready),
        // .icb_rsp_s       (ia_loader_rsp),
        // .icb_rsp_m       (ia_loader_rsp_ready),
	        .icb_cmd_valid(),
	        .icb_cmd_ready(1'b0),
	        .icb_cmd_read (),
	        .icb_cmd_addr (),
	        .icb_cmd_len  (),
	        .icb_rsp_valid(1'b0),
	        .icb_rsp_ready(),
	        .icb_rsp_rdata('0),
	        .icb_rsp_err  (1'b0),
	        .ext_dma_start(ia_dma_start),
	        .ext_dma_is_write(),
	        .ext_dma_linear_read_mode(ia_dma_linear_read_mode),
	        .ext_dma_base_addr(ia_dma_base_addr),
	        .ext_dma_row_stride(ia_dma_row_stride),
	        .ext_dma_rows_to_read(ia_dma_rows_to_read),
	        .ext_dma_burst_len_m1(ia_dma_burst_len_m1),
	        .ext_dma_slot_id(ia_dma_slot_id),
	        .ext_dma_use_16bits(ia_dma_use_16bits),
	        .ext_dma_lhs_zp(ia_dma_lhs_zp),
	        .ext_dma_busy(ia_dma_busy),
	        .ext_dma_done(ia_dma_done),
	        .ext_dma_wr_slot(ia_dma_wr_slot),
	        .ext_dma_wr_row(ia_dma_wr_row),
	        .ext_dma_wr_col_base(ia_dma_wr_col_base),
	        .ext_dma_wr_data(ia_dma_wr_data),
	        .ext_dma_wr_valid(ia_dma_wr_valid),
	        .ext_dma_wr_use_16bits(ia_dma_wr_use_16bits),


        .ia_sending_done(ia_sending_done),
        .ia_row_valid   (ia_row_valid),
        .ia_tile_start  (ia_tile_start),
        .ia_is_init_data(ia_is_init_data),
	        .ia_calc_done   (ia_calc_done),
	        .ia_out         (ia_out),
	        .ia_data_valid  (ia_data_valid),
	        .bias_sleep     (bias_sleep),
        .bias_switch    (bias_switch),
        .bias_last_loop (bias_last_loop),
        .ia_l1_switch   (ia_l1_switch)
    );
	    // Kernel Loader
	    kernel_loader #(
	        .DATA_WIDTH(WEIGHT_WIDTH),
	        .SIZE      (SIZE),
	        .BUS_WIDTH (BUS_WIDTH),
	        .REG_WIDTH (REG_WIDTH),
	        .EXTERNAL_DMA(1'b1)
	    ) u_kernel_loader (
        .clk                (clk),
        .rst_n              (rst_n),
        .init_cfg           (init_cfg_weight),
        .load_weight_req    (load_weight_req),
        .load_weight_granted(load_weight_granted),
	        .send_weight_trigger(send_weight_trigger),
	        .k                  (stream_k),
	        .n                  (run_n),
	        .m                  (stream_m),
        .rhs_zp             (weight_zp_eff),
        .rhs_base           (weight_base_eff),
        .rhs_row_stride_b   (weight_stride_eff),
        .ia_reuse_num       (ia_reuse_num_eff),
        .w_reuse_num        (w_reuse_num_eff),
        .use_16bits         (weight_use_16bits_eff),

        // .icb_cmd_m       (ia_loader_cmd),
        // .icb_cmd_s       (ia_loader_cmd_ready),
        // .icb_rsp_s       (ia_loader_rsp),
        // .icb_rsp_m       (ia_loader_rsp_ready),
	        .icb_cmd_valid(),
	        .icb_cmd_ready(1'b0),
	        .icb_cmd_read (),
	        .icb_cmd_addr (),
	        .icb_cmd_len  (),
	        .icb_rsp_valid(1'b0),
	        .icb_rsp_ready(),
	        .icb_rsp_rdata('0),
	        .icb_rsp_err  (1'b0),
	        .ext_dma_start(kernel_dma_start),
	        .ext_dma_is_write(),
	        .ext_dma_linear_read_mode(kernel_dma_linear_read_mode),
	        .ext_dma_base_addr(kernel_dma_base_addr),
	        .ext_dma_row_stride(kernel_dma_row_stride),
	        .ext_dma_rows_to_read(kernel_dma_rows_to_read),
	        .ext_dma_burst_len_m1(kernel_dma_burst_len_m1),
	        .ext_dma_slot_id(kernel_dma_slot_id),
	        .ext_dma_use_16bits(kernel_dma_use_16bits),
	        .ext_dma_lhs_zp(kernel_dma_lhs_zp),
	        .ext_dma_busy(kernel_dma_busy),
	        .ext_dma_done(kernel_dma_done),
	        .ext_dma_wr_row(kernel_dma_wr_row),
	        .ext_dma_wr_col_base(kernel_dma_wr_col_base),
	        .ext_dma_wr_data(kernel_dma_wr_data),
	        .ext_dma_wr_valid(kernel_dma_wr_valid),


        .weight_sending_done(weight_sending_done),
        .load_weight_done   (load_weight_done),
        .store_weight_req   (store_weight_req),
        .weight_out         (weight_out),
        .weight_data_valid  (weight_data_valid)
    );

	    // Bias Loader
	    bias_loader #(
	        .SIZE      (SIZE),
	        .DATA_WIDTH(32),
	        .BUS_WIDTH (BUS_WIDTH),
	        .REG_WIDTH (REG_WIDTH),
	        .GROUP_BLOCKS_MAX(IA_REUSE_NUM_MAX),
	        .EXTERNAL_DMA(1'b1)
	    ) u_bias_loader (
        .clk              (clk),
        .rst_n            (rst_n),
        .init_cfg         (init_cfg_bias),
        .load_bias_req    (load_bias_req),
	        .load_bias_granted(load_bias_granted),
	        .bias_base        (bias_base),
	        .k                (run_k),
	        .m                (run_m),
	        .bias_step_blocks (is_mode ? ia_reuse_num_eff : REG_WIDTH'(1)),
        .bias_switch      (bias_switch),
        .bias_sleep       (bias_sleep),
        .bias_last_loop   (bias_last_loop),
        .bias_valid       (bias_valid),
        .next_bias_valid  (next_bias_valid),
        .bias_group_valid (bias_group_valid),
        .load_bias_done   (load_bias_done),
        .data_out         (bias_data_out),
        .next_data_out    (next_bias_data_out),
        .group_data_out   (bias_group_data_out),
	        .icb_cmd_valid    (),
	        .icb_cmd_ready    (1'b0),
	        .icb_cmd_read     (),
	        .icb_cmd_addr     (),
	        .icb_cmd_len      (),
	        .icb_rsp_valid    (1'b0),
	        .icb_rsp_ready    (),
	        .icb_rsp_rdata    ('0),
	        .icb_rsp_err      (1'b0),
		        .ext_dma_start    (bias_dma_start),
		        .ext_dma_is_write (),
	        .ext_dma_linear_read_mode(bias_dma_linear_read_mode),
	        .ext_dma_base_addr(bias_dma_base_addr),
	        .ext_dma_row_stride(bias_dma_row_stride),
	        .ext_dma_rows_to_read(bias_dma_rows_to_read),
	        .ext_dma_burst_len_m1(bias_dma_burst_len_m1),
	        .ext_dma_slot_id  (bias_dma_slot_id),
	        .ext_dma_use_16bits(bias_dma_use_16bits),
	        .ext_dma_lhs_zp   (bias_dma_lhs_zp),
	        .ext_dma_busy     (bias_dma_busy),
	        .ext_dma_done     (bias_dma_done),
	        .ext_dma_wr_slot  (bias_dma_wr_slot),
	        .ext_dma_wr_row   (bias_dma_wr_row),
	        .ext_dma_wr_col_base(bias_dma_wr_col_base),
	        .ext_dma_wr_data  (bias_dma_wr_data),
	        .ext_dma_wr_valid (bias_dma_wr_valid),
	        .ext_dma_wr_use_16bits(bias_dma_wr_use_16bits)
	    );

  // 脉动阵列计算核心
  wire signed [31:0] compute_bias_in[SIZE];
  logic signed [31:0] bias_data_hold[SIZE];
  logic signed [31:0] compute_bias_latched[SIZE];
  wire capture_compute_bias = !is_mode && ia_tile_start && !bias_sleep;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int bi = 0; bi < SIZE; bi = bi + 1) begin
        bias_data_hold[bi] <= '0;
        compute_bias_latched[bi] <= '0;
      end
    end else if (init_cfg_bias) begin
      for (int bi = 0; bi < SIZE; bi = bi + 1) begin
        bias_data_hold[bi] <= '0;
        compute_bias_latched[bi] <= '0;
      end
    end else begin
      if (bias_group_valid) begin
        for (int bi = 0; bi < SIZE; bi = bi + 1) begin
          bias_data_hold[bi] <= bias_data_out[bi];
        end
      end

      if (capture_compute_bias) begin
        for (int bi = 0; bi < SIZE; bi = bi + 1) begin
          compute_bias_latched[bi] <= bias_group_valid ? bias_data_out[bi] : bias_data_hold[bi];
        end
      end
    end
  end

  genvar cb_i;
  generate
    for (cb_i = 0; cb_i < SIZE; cb_i = cb_i + 1) begin : gen_compute_bias_in
      assign compute_bias_in[cb_i] = is_mode ? 32'sd0 : compute_bias_latched[cb_i];
    end
  endgenerate

    compute_core #(
        .SIZE          (SIZE),
        .DATA_WIDTH    (DATA_WIDTH),
        .WEIGHT_WIDTH  (WEIGHT_WIDTH),
        .PS_FRAME_COUNT(PS_FRAME_COUNT),
        .MAX_IA_REUSE  (IA_REUSE_NUM_MAX)
    ) u_compute_core (
        .clk             (clk),
        .rst_n           (rst_n),
        .store_weight_req(store_weight_req),
        .weight_in       (weight_out),
        .ia_vec_in       (ia_out),
        .ia_row_valid    (ia_row_valid),
        .ia_tile_start   (ia_tile_start),
        .ia_calc_done    (ia_calc_done),
        .ia_is_init_data (ia_is_init_data),
        .ia_l1_switch    (ia_l1_switch),
        .ia_sending_done (ia_sending_done),
        .send_ia_trigger (send_ia_trigger),
        .bias_sleep      (compute_bias_sleep),
        .bias_in         (compute_bias_in),
        .acc_data_out    (acc_data_out),
        .acc_data_valid  (acc_data_valid),
        .partial_sum_calc_over(partial_sum_calc_over),
        .tile_calc_over  (tile_calc_over)
    );

    // Vec Requant
	    logic [IS_BIAS_ROW_W-1:0] is_bias_row_idx;
	    logic [REG_WIDTH-1:0] is_bias_group_base;
	    logic [REG_WIDTH-1:0] is_bias_rows_valid;
	    logic signed [31:0] is_bias_tile_data[IS_BIAS_ROWS];
	    wire [REG_WIDTH-1:0] is_bias_rows_remaining =
	      (run_m > is_bias_group_base) ? (run_m - is_bias_group_base) : REG_WIDTH'(0);
    wire [REG_WIDTH-1:0] is_bias_rows_valid_next =
      (is_bias_rows_remaining == '0) ? REG_WIDTH'(1) :
      (is_bias_rows_remaining > is_bias_group_rows_target)
          ? is_bias_group_rows_target
          : is_bias_rows_remaining;
    wire signed [31:0] is_bias_scalar =
      (is_mode && (bias_base != '0)) ? is_bias_tile_data[is_bias_row_idx] : 32'sd0;
    wire signed [31:0] requant_in_vec[SIZE];

	    always_ff @(posedge clk or negedge rst_n) begin
	        if (!rst_n) begin
	            is_bias_row_idx <= '0;
	            is_bias_group_base <= '0;
	            is_bias_rows_valid <= REG_WIDTH'(1);
	            for (int bi = 0; bi < IS_BIAS_ROWS; bi = bi + 1) begin
	                is_bias_tile_data[bi] <= '0;
	            end
	        end else begin
	            if (init_cfg_ia) begin
	                is_bias_row_idx <= '0;
	                is_bias_group_base <= '0;
	                is_bias_rows_valid <= REG_WIDTH'(1);
	                for (int bi = 0; bi < IS_BIAS_ROWS; bi = bi + 1) begin
	                    is_bias_tile_data[bi] <= '0;
	                end
	            end else begin
	                if (is_mode && acc_data_valid) begin
	                    if (is_bias_rows_valid <= REG_WIDTH'(1)) begin
	                        is_bias_row_idx <= '0;
	                    end else if ((REG_WIDTH'(is_bias_row_idx) + REG_WIDTH'(1)) >= is_bias_rows_valid) begin
	                        is_bias_row_idx <= '0;
	                    end else begin
	                        is_bias_row_idx <= is_bias_row_idx + 1'b1;
	                    end
	                end

	                if (is_mode && bias_switch) begin
		                    if ((is_bias_group_base + is_bias_rows_valid) >= run_m) begin
	                        is_bias_group_base <= '0;
	                    end else begin
	                        is_bias_group_base <= is_bias_group_base + is_bias_rows_valid;
	                    end
	                end

	                if (is_mode && send_ia_trigger && !bias_sleep) begin
	                    is_bias_row_idx <= '0;
	                    is_bias_rows_valid <= is_bias_rows_valid_next;
	                    for (int bi = 0; bi < IS_BIAS_ROWS; bi = bi + 1) begin
	                        if (REG_WIDTH'(bi) < is_bias_rows_valid_next) begin
	                            is_bias_tile_data[bi] <= bias_group_valid ? bias_group_data_out[bi] : 32'sd0;
	                        end else begin
	                            is_bias_tile_data[bi] <= 32'sd0;
	                        end
	                    end
	                end
	            end
	        end
	    end

    genvar rq_i;
    generate
        for (rq_i = 0; rq_i < SIZE; rq_i = rq_i + 1) begin : gen_requant_in_vec
            assign requant_in_vec[rq_i] =
          is_mode ? (acc_data_out[rq_i] + is_bias_scalar) : acc_data_out[rq_i];
        end
    endgenerate

	    vec_requant #(
	        .VLEN        (SIZE),
	        .REG_WIDTH   (REG_WIDTH),
	        .MAX_IA_REUSE(IA_REUSE_NUM_MAX)
    ) u_vec_requant (
        .clk               (clk),
        .rst_n             (rst_n),
        .init_cfg          (init_cfg_requant),
        .cfg_per_channel   (use_per_channel),
        .cfg_dataflow_mode (cfg_dataflow_mode),
        .activation_min_in (act_min),
        .activation_max_in (act_max),
        .dst_offset_in     (dst_zp),
        .multiplier_in     (q_mult_pt),
        .shift_in          (q_shift_pt),
        .load_quant_req    (load_quant_req),
        .load_quant_granted(load_quant_granted),
        .quant_params_valid(quant_params_valid),
	        .k                 (stream_k),
	        .m                 (stream_m),
	        .ia_reuse_num_in   (ia_reuse_num_eff),
	        .dma_start         (quant_dma_start),
	        .dma_is_write      (),
	        .dma_linear_read_mode(quant_dma_linear_read_mode),
	        .dma_base_addr     (quant_dma_base_addr),
	        .dma_row_stride    (quant_dma_row_stride),
	        .dma_rows_to_read  (quant_dma_rows_to_read),
	        .dma_burst_len_m1  (quant_dma_burst_len_m1),
	        .dma_slot_id       (quant_dma_slot_id),
	        .dma_use_16bits    (quant_dma_use_16bits),
	        .dma_lhs_zp        (quant_dma_lhs_zp),
	        .dma_raw_data      (quant_dma_raw_data),
	        .dma_raw_valid     (quant_dma_raw_valid),
	        .in_valid          (acc_data_valid),
	        .in_tile_done      (tile_calc_over),
	        .in_vec_s32        (requant_in_vec),
        .out_valid         (requant_out_valid),
        .out_tile_done     (requant_out_tile_done),
	        .out_vec_s8        (requant_out)
	    );
    //wire signed [             7:0] requant_out                            [SIZE];
    //TODO: check big or little endian
    //
    wire [SIZE*8-1:0] in_vec_s8;
    genvar i;
    generate
        for (i = 0; i < SIZE; i = i + 1) begin : gen_unpack_in_vec
            assign in_vec_s8[i*8+:8] = requant_out[i];
        end
    endgenerate

    // FIFO
    vec_s8_to_fifo #(
        .VLEN (SIZE),
        .BANKS(OA_FIFO_BANKS)
    ) u_vec_s8_to_fifo (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_valid         (requant_out_valid),
        .in_tile_done     (requant_out_tile_done),
        //.in_vec_s8        (requant_out),
        .in_vec_s8        (in_vec_s8),
        //.output_req       (fifo_output_req),
        .oa_fifo_req      (fifo_output_req),
        .transpose_mode   (is_mode),
        .vec_valid_num_col(fifo_vec_valid_num_col),
        .vec_valid_num_row(fifo_vec_valid_num_row),
        .output_valid     (fifo_output_valid),
        //.output_switch_row(fifo_output_switch_row),
        .output_row_switch(fifo_output_switch_row),
        .output_ready     (fifo_output_ready),
        .output_mask      (fifo_output_mask),
        .output_data      (fifo_output_data),
        .fifo_full_flag   (fifo_full_flag)
    );

    // OA Writer
	    oa_writer #(
	        .VLEN      (SIZE),
	        .DATA_WIDTH(8),
	        .REG_WIDTH (REG_WIDTH),
	        .BUS_WIDTH (BUS_WIDTH)
	    ) u_oa_writer (
        .clk              (clk),
        .rst_n            (rst_n),
        .init_cfg         (init_cfg_oa),
        .oa_fifo_req      (fifo_output_req),
        .vec_valid_num_col(fifo_vec_valid_num_col),
        .vec_valid_num_row(fifo_vec_valid_num_row),
        //.write_oa_trigger(),
        .write_oa_req     (write_oa_req),
        .write_oa_granted (write_oa_granted),
	        .dst_base         (dst_base),
	        .dst_row_stride_b (dst_row_stride_b),
	        .k                (run_k),
	        .m                (run_m),
        .ia_reuse_num     (ia_reuse_num_eff),
        .is_mode          (is_mode),
        .output_valid     (fifo_output_valid),
        .switch_row       (fifo_output_switch_row),
	        .output_ready     (fifo_output_ready),
	        .output_mask      (fifo_output_mask),
	        .output_data      (fifo_output_data),
	        .dma_start        (oa_dma_start),
	        .dma_is_write     (),
	        .dma_linear_read_mode(),
	        .dma_base_addr    (oa_dma_base_addr),
	        .dma_row_stride   (oa_dma_row_stride),
	        .dma_rows_to_read (oa_dma_rows_to_read),
	        .dma_burst_len_m1 (oa_dma_burst_len_m1),
	        .dma_slot_id      (),
	        .dma_use_16bits   (),
	        .dma_lhs_zp       (),
	        .dma_src_wdata    (oa_dma_src_wdata),
	        .dma_src_wmask    (oa_dma_src_wmask),
	        .dma_src_wvalid   (oa_dma_src_wvalid),
	        .dma_src_wready   (oa_dma_src_wready),
	        .dma_busy         (oa_dma_busy),
	        .dma_done         (oa_dma_done),
	        .write_done       (write_done),
	        .oa_calc_over     (oa_calc_over)
	    );

`ifndef SYNTHESIS
    function automatic longint unsigned util_bp(
        input longint unsigned numerator,
        input longint unsigned denominator
    );
        begin
            util_bp = (denominator == 0) ? 0 : ((numerator * 10000) / denominator);
        end
    endfunction

    bit top_util_trace_en;
    logic top_util_active;
    longint unsigned top_util_op_id;
    longint unsigned top_util_active_cycles;
    longint unsigned top_util_ia_row_cycles;
    longint unsigned top_util_acc_valid_cycles;
    longint unsigned top_util_requant_valid_cycles;
    longint unsigned top_util_fifo_valid_cycles;
    longint unsigned top_util_fifo_full_cycles;
    longint unsigned top_util_store_weight_cycles;
    longint unsigned top_util_send_weight_count;
    longint unsigned top_util_send_ia_count;
    longint unsigned top_util_tile_start_count;
    longint unsigned top_util_tile_over_count;
    longint unsigned top_util_partial_over_count;
    longint unsigned top_util_ia_l1_switch_count;
    longint unsigned top_util_ia_dma_busy_cycles;
    longint unsigned top_util_kernel_dma_busy_cycles;
    longint unsigned top_util_bias_dma_busy_cycles;
    longint unsigned top_util_quant_dma_busy_cycles;
    longint unsigned top_util_oa_dma_busy_cycles;
    longint unsigned top_util_axi_ar_cycles;
    longint unsigned top_util_axi_r_cycles;
    longint unsigned top_util_axi_aw_cycles;
    longint unsigned top_util_axi_w_cycles;
    longint unsigned top_util_axi_b_cycles;

    initial begin
        top_util_trace_en = 1'b0;
        if ($test$plusargs("MMA_UTIL_TRACE")) top_util_trace_en = 1'b1;
    end

    wire top_util_start_event = calc_start && sa_ready;
    wire top_util_finish_event = top_util_active && wb_valid && wb_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            top_util_active                 <= 1'b0;
            top_util_op_id                  <= '0;
            top_util_active_cycles          <= '0;
            top_util_ia_row_cycles          <= '0;
            top_util_acc_valid_cycles       <= '0;
            top_util_requant_valid_cycles   <= '0;
            top_util_fifo_valid_cycles      <= '0;
            top_util_fifo_full_cycles       <= '0;
            top_util_store_weight_cycles    <= '0;
            top_util_send_weight_count      <= '0;
            top_util_send_ia_count          <= '0;
            top_util_tile_start_count       <= '0;
            top_util_tile_over_count        <= '0;
            top_util_partial_over_count     <= '0;
            top_util_ia_l1_switch_count     <= '0;
            top_util_ia_dma_busy_cycles     <= '0;
            top_util_kernel_dma_busy_cycles <= '0;
            top_util_bias_dma_busy_cycles   <= '0;
            top_util_quant_dma_busy_cycles  <= '0;
            top_util_oa_dma_busy_cycles     <= '0;
            top_util_axi_ar_cycles          <= '0;
            top_util_axi_r_cycles           <= '0;
            top_util_axi_aw_cycles          <= '0;
            top_util_axi_w_cycles           <= '0;
            top_util_axi_b_cycles           <= '0;
        end else begin
            if (top_util_start_event) begin
                top_util_active                 <= 1'b1;
                top_util_op_id                  <= top_util_op_id + 1'b1;
                top_util_active_cycles          <= '0;
                top_util_ia_row_cycles          <= '0;
                top_util_acc_valid_cycles       <= '0;
                top_util_requant_valid_cycles   <= '0;
                top_util_fifo_valid_cycles      <= '0;
                top_util_fifo_full_cycles       <= '0;
                top_util_store_weight_cycles    <= '0;
                top_util_send_weight_count      <= '0;
                top_util_send_ia_count          <= '0;
                top_util_tile_start_count       <= '0;
                top_util_tile_over_count        <= '0;
                top_util_partial_over_count     <= '0;
                top_util_ia_l1_switch_count     <= '0;
                top_util_ia_dma_busy_cycles     <= '0;
                top_util_kernel_dma_busy_cycles <= '0;
                top_util_bias_dma_busy_cycles   <= '0;
                top_util_quant_dma_busy_cycles  <= '0;
                top_util_oa_dma_busy_cycles     <= '0;
                top_util_axi_ar_cycles          <= '0;
                top_util_axi_r_cycles           <= '0;
                top_util_axi_aw_cycles          <= '0;
                top_util_axi_w_cycles           <= '0;
                top_util_axi_b_cycles           <= '0;
            end else if (top_util_active) begin
                top_util_active_cycles <= top_util_active_cycles + 1'b1;

                if (ia_row_valid) begin
                    top_util_ia_row_cycles <= top_util_ia_row_cycles + 1'b1;
                end
                if (acc_data_valid) begin
                    top_util_acc_valid_cycles <= top_util_acc_valid_cycles + 1'b1;
                end
                if (requant_out_valid) begin
                    top_util_requant_valid_cycles <= top_util_requant_valid_cycles + 1'b1;
                end
                if (fifo_output_valid) begin
                    top_util_fifo_valid_cycles <= top_util_fifo_valid_cycles + 1'b1;
                end
                if (fifo_full_flag) begin
                    top_util_fifo_full_cycles <= top_util_fifo_full_cycles + 1'b1;
                end
                if (store_weight_req) begin
                    top_util_store_weight_cycles <= top_util_store_weight_cycles + 1'b1;
                end
                if (send_weight_trigger) begin
                    top_util_send_weight_count <= top_util_send_weight_count + 1'b1;
                end
                if (send_ia_trigger) begin
                    top_util_send_ia_count <= top_util_send_ia_count + 1'b1;
                end
                if (ia_tile_start) begin
                    top_util_tile_start_count <= top_util_tile_start_count + 1'b1;
                end
                if (tile_calc_over) begin
                    top_util_tile_over_count <= top_util_tile_over_count + 1'b1;
                end
                if (partial_sum_calc_over) begin
                    top_util_partial_over_count <= top_util_partial_over_count + 1'b1;
                end
                if (ia_l1_switch) begin
                    top_util_ia_l1_switch_count <= top_util_ia_l1_switch_count + 1'b1;
                end
                if (ia_dma_busy) begin
                    top_util_ia_dma_busy_cycles <= top_util_ia_dma_busy_cycles + 1'b1;
                end
                if (kernel_dma_busy) begin
                    top_util_kernel_dma_busy_cycles <= top_util_kernel_dma_busy_cycles + 1'b1;
                end
                if (bias_dma_busy) begin
                    top_util_bias_dma_busy_cycles <= top_util_bias_dma_busy_cycles + 1'b1;
                end
                if (quant_dma_busy) begin
                    top_util_quant_dma_busy_cycles <= top_util_quant_dma_busy_cycles + 1'b1;
                end
                if (oa_dma_busy) begin
                    top_util_oa_dma_busy_cycles <= top_util_oa_dma_busy_cycles + 1'b1;
                end
                if (m_axi_arvalid && m_axi_arready) begin
                    top_util_axi_ar_cycles <= top_util_axi_ar_cycles + 1'b1;
                end
                if (m_axi_rvalid && m_axi_rready) begin
                    top_util_axi_r_cycles <= top_util_axi_r_cycles + 1'b1;
                end
                if (m_axi_awvalid && m_axi_awready) begin
                    top_util_axi_aw_cycles <= top_util_axi_aw_cycles + 1'b1;
                end
                if (m_axi_wvalid && m_axi_wready) begin
                    top_util_axi_w_cycles <= top_util_axi_w_cycles + 1'b1;
                end
                if (m_axi_bvalid && m_axi_bready) begin
                    top_util_axi_b_cycles <= top_util_axi_b_cycles + 1'b1;
                end
            end

            if (top_util_finish_event) begin
                if (top_util_trace_en) begin
                    $display("[MMA_UTIL] op=%0d active=%0d ia_row=%0d ia_row_util_bp=%0d acc_valid=%0d acc_util_bp=%0d requant_valid=%0d fifo_valid=%0d fifo_full=%0d store_weight=%0d send_weight=%0d send_ia=%0d tile_start=%0d tile_over=%0d partial_over=%0d l1_switch=%0d dma_busy_ia=%0d dma_busy_kernel=%0d dma_busy_bias=%0d dma_busy_quant=%0d dma_busy_oa=%0d axi_ar=%0d axi_r=%0d axi_aw=%0d axi_w=%0d axi_b=%0d",
                             top_util_op_id,
                             top_util_active_cycles,
                             top_util_ia_row_cycles,
                             util_bp(top_util_ia_row_cycles, top_util_active_cycles),
                             top_util_acc_valid_cycles,
                             util_bp(top_util_acc_valid_cycles, top_util_active_cycles),
                             top_util_requant_valid_cycles,
                             top_util_fifo_valid_cycles,
                             top_util_fifo_full_cycles,
                             top_util_store_weight_cycles,
                             top_util_send_weight_count,
                             top_util_send_ia_count,
                             top_util_tile_start_count,
                             top_util_tile_over_count,
                             top_util_partial_over_count,
                             top_util_ia_l1_switch_count,
                             top_util_ia_dma_busy_cycles,
                             top_util_kernel_dma_busy_cycles,
                             top_util_bias_dma_busy_cycles,
                             top_util_quant_dma_busy_cycles,
                             top_util_oa_dma_busy_cycles,
                             top_util_axi_ar_cycles,
                             top_util_axi_r_cycles,
                             top_util_axi_aw_cycles,
                             top_util_axi_w_cycles,
                             top_util_axi_b_cycles);
                end
                top_util_active <= 1'b0;
            end
        end
    end
`endif

    //assign calc_done = oa_calc_over;
endmodule
