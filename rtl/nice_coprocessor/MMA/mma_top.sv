//`include "define.svh"
`include "e203_defines.v"
`include "icb_types.svh"

// 矩阵乘累加(MMA)顶层模块
module mma_top #(
    parameter int unsigned WEIGHT_WIDTH = 16,  // 权重数据宽度；WS 下 s8 符号扩展，IS+s16 下使用 16bit LHS
    parameter int unsigned DATA_WIDTH = 16,  // IA数据宽度
    parameter int unsigned SIZE = 16,  // 阵列大小
    parameter int unsigned BUS_WIDTH = 32,  // 总线宽度
    parameter int unsigned REG_WIDTH = 32,  // 寄存器宽度
    parameter int unsigned ADDR_WIDTH = 19,  // 地址宽度
    parameter int unsigned ICB_LEN_W = 4,  // ICB 突发长度宽度
    parameter int unsigned IA_CACHE_BLOCKS = 4,  // IA loader cache slots；默认 IA reuse = IA_CACHE_BLOCKS/2
    parameter int unsigned PS_FRAME_COUNT = SIZE  // PS buffer 可保留的输出列 tile 数
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

    //==== 扁平化 ICB 接口 ====
    output logic                   sa_icb_cmd_valid,
    input  logic                   sa_icb_cmd_ready,
    output logic [ ADDR_WIDTH-1:0] sa_icb_cmd_addr,
    output logic                   sa_icb_cmd_read,
    output logic [  ICB_LEN_W-1:0] sa_icb_cmd_len,
    output logic [  BUS_WIDTH-1:0] sa_icb_cmd_wdata,
    output logic [BUS_WIDTH/8-1:0] sa_icb_cmd_wmask,
    output logic                   sa_icb_w_valid,
    input  logic                   sa_icb_w_ready,
    input  logic                   sa_icb_rsp_valid,
    output logic                   sa_icb_rsp_ready,
    input  logic [  BUS_WIDTH-1:0] sa_icb_rsp_rdata,
    input  logic                   sa_icb_rsp_err
);

	    //========================================
	    // 内部信号定义
	    //========================================
	    localparam int unsigned BIAS_DMA_SIZE = SIZE * 4;
	    localparam int unsigned SHARED_DMA_SIZE =
	        (BIAS_DMA_SIZE > SIZE) ? BIAS_DMA_SIZE : SIZE;

	    // Vec requant per-channel 参数仍使用原 ICB 风格端口，经 DMA read adapter 接入共享 DMA。
	    icb_ext_cmd_m_t vec_requant_cmd;
	    icb_ext_cmd_s_t vec_requant_cmd_ready;
	    icb_ext_wr_s_t  vec_requant_w_ready;
	    icb_ext_rsp_s_t vec_requant_rsp;
	    icb_ext_rsp_m_t vec_requant_rsp_ready;

	    // 保留调试层级名；总线仲裁删除后固定为 0。
	    wire [2:0] icb_sel = 3'd0;
	    wire [2:0] ctrl_icb_sel_unused;
	    wire ctrl_load_ia_granted_unused;
	    wire ctrl_load_weight_granted_unused;
	    wire ctrl_load_bias_granted_unused;
	    wire ctrl_load_quant_granted_unused;
	    wire ctrl_write_oa_granted_unused;

    // IA Loader 内部信号
    wire load_ia_req;
    wire load_ia_granted;
    wire send_ia_trigger;
    wire ia_sending_done;
    wire ia_row_valid;
    wire ia_tile_start;
    wire ia_is_init_data;
    wire ia_calc_done;
    wire ia_group_calc_done;
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
    wire signed [7:0] requant_out[SIZE];
    logic requant_tile_done;

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
	    logic ia_dma_start, ia_dma_is_write, ia_dma_linear_read_mode;
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

	    logic kernel_dma_start, kernel_dma_is_write, kernel_dma_linear_read_mode;
	    logic [REG_WIDTH-1:0] kernel_dma_base_addr, kernel_dma_row_stride, kernel_dma_rows_to_read;
	    logic [3:0] kernel_dma_burst_len_m1;
	    logic kernel_dma_slot_id, kernel_dma_use_16bits;
	    logic signed [REG_WIDTH-1:0] kernel_dma_lhs_zp;
	    logic kernel_dma_busy, kernel_dma_done;
	    logic [$clog2(SIZE)-1:0] kernel_dma_wr_row, kernel_dma_wr_col_base;
	    logic signed [WEIGHT_WIDTH-1:0] kernel_dma_wr_data[BUS_WIDTH/8];
	    logic kernel_dma_wr_valid[BUS_WIDTH/8];

	    logic bias_dma_start, bias_dma_is_write, bias_dma_linear_read_mode;
	    logic [REG_WIDTH-1:0] bias_dma_base_addr, bias_dma_row_stride, bias_dma_rows_to_read;
	    logic [3:0] bias_dma_burst_len_m1;
	    logic bias_dma_slot_id, bias_dma_use_16bits;
	    logic signed [REG_WIDTH-1:0] bias_dma_lhs_zp;
	    logic bias_dma_busy, bias_dma_done, bias_dma_wr_slot, bias_dma_wr_use_16bits;
	    logic [$clog2(BIAS_DMA_SIZE)-1:0] bias_dma_wr_row, bias_dma_wr_col_base;
	    logic signed [7:0] bias_dma_wr_data[BUS_WIDTH/8];
	    logic bias_dma_wr_valid[BUS_WIDTH/8];

	    logic quant_dma_start, quant_dma_is_write, quant_dma_linear_read_mode;
	    logic [REG_WIDTH-1:0] quant_dma_base_addr, quant_dma_row_stride, quant_dma_rows_to_read;
	    logic [3:0] quant_dma_burst_len_m1;
	    logic quant_dma_slot_id, quant_dma_use_16bits;
	    logic signed [REG_WIDTH-1:0] quant_dma_lhs_zp;
	    logic quant_dma_busy, quant_dma_done, quant_dma_req;
	    logic [BUS_WIDTH-1:0] quant_dma_raw_data;
	    logic quant_dma_raw_valid;

	    logic oa_dma_start, oa_dma_is_write, oa_dma_linear_read_mode;
	    logic [REG_WIDTH-1:0] oa_dma_base_addr, oa_dma_row_stride, oa_dma_rows_to_read;
	    logic [3:0] oa_dma_burst_len_m1;
	    logic oa_dma_slot_id, oa_dma_use_16bits;
	    logic signed [REG_WIDTH-1:0] oa_dma_lhs_zp;
	    logic [BUS_WIDTH-1:0] oa_dma_src_wdata;
	    logic [BUS_WIDTH/8-1:0] oa_dma_src_wmask;
	    logic oa_dma_src_wvalid, oa_dma_src_wready, oa_dma_busy, oa_dma_done;

	    logic shared_icb_cmd_valid, shared_icb_cmd_read, shared_icb_w_valid, shared_icb_rsp_ready;
	    logic [REG_WIDTH-1:0] shared_icb_cmd_addr;
	    logic [3:0] shared_icb_cmd_len;
	    logic [BUS_WIDTH-1:0] shared_icb_cmd_wdata;
	    logic [BUS_WIDTH/8-1:0] shared_icb_cmd_wmask;

    // 添加缺少的内部信号
    // per-submodule init_cfg signals (由mma_controller产生的单拍脉冲)
    wire init_cfg_ia;
    wire init_cfg_weight;
    wire init_cfg_bias;
    wire init_cfg_requant;
    wire init_cfg_oa;
    wire use_16bits;  // 16位数据指示信号
    wire [REG_WIDTH-1:0] tile_count;  // 分块计数信号
    wire is_mode = cfg_dataflow_mode;
    wire [REG_WIDTH-1:0] stream_k = is_mode ? m : k;
    wire [REG_WIDTH-1:0] stream_m = is_mode ? k : m;
    wire [REG_WIDTH-1:0] ia_base_eff = is_mode ? rhs_base : lhs_base;
    wire [REG_WIDTH-1:0] ia_stride_eff = is_mode ? rhs_col_stride_b : lhs_row_stride_b;
    wire signed [REG_WIDTH-1:0] ia_zp_eff = is_mode ? rhs_zp : lhs_zp;
    wire ia_use_16bits_eff = is_mode ? 1'b0 : use_16bits;
    wire [REG_WIDTH-1:0] weight_base_eff = is_mode ? lhs_base : rhs_base;
    wire [REG_WIDTH-1:0] weight_stride_eff = is_mode ? lhs_row_stride_b : rhs_col_stride_b;
    wire signed [REG_WIDTH-1:0] weight_zp_eff = is_mode ? lhs_zp : rhs_zp;
    wire weight_use_16bits_eff = is_mode ? use_16bits : 1'b0;
    wire compute_bias_sleep = bias_sleep;
	    localparam int unsigned IA_REUSE_NUM_MAX =
	        (IA_CACHE_BLOCKS < 2) ? 1 : (IA_CACHE_BLOCKS / 2);
		    localparam int unsigned IA_REUSE_NUM_DEFAULT = IA_REUSE_NUM_MAX;
	    localparam int unsigned OA_FIFO_BANKS = PS_FRAME_COUNT * IA_REUSE_NUM_MAX;
		    localparam int unsigned IS_BIAS_ROWS = IA_REUSE_NUM_MAX * SIZE;
		    localparam int unsigned IS_BIAS_ROW_W = (IS_BIAS_ROWS <= 1) ? 1 : $clog2(IS_BIAS_ROWS);
		    wire signed [31:0] bias_group_data_out[IS_BIAS_ROWS];

	    wire [REG_WIDTH-1:0] output_col_tile_num = (stream_m + REG_WIDTH'(SIZE - 1)) >> $clog2(SIZE);
    wire        [   REG_WIDTH-1:0] ia_reuse_num_raw =
      (cfg_ia_reuse_num == '0) ? REG_WIDTH'(IA_REUSE_NUM_DEFAULT) : cfg_ia_reuse_num;
    wire        [   REG_WIDTH-1:0] w_reuse_num_raw =
      (cfg_w_reuse_num == '0) ? output_col_tile_num : cfg_w_reuse_num;
    wire        [   REG_WIDTH-1:0] ia_reuse_num_eff_ws =
      (ia_reuse_num_raw == '0) ? REG_WIDTH'(1) :
      (ia_reuse_num_raw > REG_WIDTH'(IA_REUSE_NUM_MAX))
          ? REG_WIDTH'(IA_REUSE_NUM_MAX)
          : ia_reuse_num_raw;
    wire [REG_WIDTH-1:0] ia_reuse_num_eff = ia_reuse_num_eff_ws;
	    wire [REG_WIDTH-1:0] w_reuse_num_clamped_max =
	      (w_reuse_num_raw == '0) ? REG_WIDTH'(1) :
	      ((output_col_tile_num != '0) && (w_reuse_num_raw > output_col_tile_num))
	          ? output_col_tile_num
	          : w_reuse_num_raw;
	    wire [REG_WIDTH-1:0] w_reuse_num_eff =
	      (is_mode && (w_reuse_num_clamped_max < ia_reuse_num_eff) &&
	       (output_col_tile_num >= ia_reuse_num_eff))
	          ? ia_reuse_num_eff
	          : w_reuse_num_clamped_max;

	    assign sa_icb_cmd_valid = shared_icb_cmd_valid;
	    assign sa_icb_cmd_addr  = shared_icb_cmd_addr[ADDR_WIDTH-1:0];
	    assign sa_icb_cmd_read  = shared_icb_cmd_read;
	    assign sa_icb_cmd_len   = shared_icb_cmd_len[ICB_LEN_W-1:0];
	    assign sa_icb_cmd_wdata = shared_icb_cmd_wdata;
	    assign sa_icb_cmd_wmask = shared_icb_cmd_wmask;
	    assign sa_icb_w_valid   = shared_icb_w_valid;
	    assign sa_icb_rsp_ready = shared_icb_rsp_ready;

	    block_dma_arbiter #(
	        .DATA_WIDTH  (DATA_WIDTH),
	        .KERNEL_WIDTH(WEIGHT_WIDTH),
	        .SIZE        (SIZE),
	        .DMA_SIZE    (SHARED_DMA_SIZE),
	        .BUS_WIDTH   (BUS_WIDTH),
	        .REG_WIDTH   (REG_WIDTH),
	        .CACHE_BLOCKS(IA_CACHE_BLOCKS)
	    ) u_block_dma_arbiter (
	        .clk                     (clk),
	        .rst_n                   (rst_n),
	        .ia_req                  (load_ia_req),
	        .ia_granted              (load_ia_granted),
	        .ia_start                (ia_dma_start),
	        .ia_is_write             (ia_dma_is_write),
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
	        .kernel_is_write         (kernel_dma_is_write),
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
	        .bias_is_write           (bias_dma_is_write),
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
	        .quant_req               (load_quant_req || quant_dma_req),
	        .quant_granted           (load_quant_granted),
	        .quant_start             (quant_dma_start),
	        .quant_is_write          (quant_dma_is_write),
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
	        .oa_is_write             (oa_dma_is_write),
	        .oa_linear_read_mode     (oa_dma_linear_read_mode),
	        .oa_base_addr            (oa_dma_base_addr),
	        .oa_row_stride           (oa_dma_row_stride),
	        .oa_rows_to_read         (oa_dma_rows_to_read),
	        .oa_burst_len_m1         (oa_dma_burst_len_m1),
	        .oa_slot_id              (oa_dma_slot_id),
	        .oa_use_16bits           (oa_dma_use_16bits),
	        .oa_lhs_zp               (oa_dma_lhs_zp),
	        .oa_src_wdata            (oa_dma_src_wdata),
	        .oa_src_wmask            (oa_dma_src_wmask),
	        .oa_src_wvalid           (oa_dma_src_wvalid),
	        .oa_src_wready           (oa_dma_src_wready),
	        .oa_busy                 (oa_dma_busy),
	        .oa_done                 (oa_dma_done),
	        .icb_cmd_valid           (shared_icb_cmd_valid),
	        .icb_cmd_ready           (sa_icb_cmd_ready),
	        .icb_cmd_read            (shared_icb_cmd_read),
	        .icb_cmd_addr            (shared_icb_cmd_addr),
	        .icb_cmd_len             (shared_icb_cmd_len),
	        .icb_cmd_wdata           (shared_icb_cmd_wdata),
	        .icb_cmd_wmask           (shared_icb_cmd_wmask),
	        .icb_w_valid             (shared_icb_w_valid),
	        .icb_w_ready             (sa_icb_w_ready),
	        .icb_rsp_valid           (sa_icb_rsp_valid),
	        .icb_rsp_ready           (shared_icb_rsp_ready),
	        .icb_rsp_rdata           (sa_icb_rsp_rdata),
	        .icb_rsp_err             (sa_icb_rsp_err)
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
        .calc_start       (calc_start),
        .cfg_16bits_ia    (cfg_16bits_ia),
        .cfg_dataflow_mode(cfg_dataflow_mode),
        .sa_ready         (sa_ready),

        .partial_sum_calc_over(partial_sum_calc_over),
        .tile_calc_over       (tile_calc_over),
	        .icb_sel              (ctrl_icb_sel_unused),
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
        .load_ia_req          (load_ia_req),
	        .load_ia_granted      (ctrl_load_ia_granted_unused),
        .send_ia_trigger      (send_ia_trigger),
        .ia_sending_done      (ia_sending_done),
        .ia_data_valid        (ia_data_valid),
        .ia_group_calc_done   (ia_group_calc_done),
        // Weight Loader Interface
        .load_weight_req      (load_weight_req),
	        .load_weight_granted  (ctrl_load_weight_granted_unused),
        .load_weight_done     (load_weight_done),
        .send_weight_trigger  (send_weight_trigger),
        .weight_sending_done  (weight_sending_done),
        .weight_data_valid    (weight_data_valid),
        // Bias Loader Interface
        .load_bias_req        (load_bias_req),
	        .load_bias_granted    (ctrl_load_bias_granted_unused),
        .bias_valid           (bias_group_valid),
        .bias_sleep           (bias_sleep),
        .load_bias_done       (load_bias_done),
        // Requantization Interface
        .load_quant_req       (load_quant_req),
	        .load_quant_granted   (ctrl_load_quant_granted_unused),
        .quant_params_valid   (quant_params_valid),
        // FIFO Interface
        .fifo_full_flag       (fifo_full_flag),
        // OA Writer Interface
        .write_oa_req         (write_oa_req),
	        .write_oa_granted     (ctrl_write_oa_granted_unused),
        .write_done           (write_done),
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
	        .EXTERNAL_DMA(1'b1)
	    ) u_ia_loader (
        .clk             (clk),
        .rst_n           (rst_n),
        .init_cfg        (init_cfg_ia),
        .load_ia_req     (load_ia_req),
        .load_ia_granted (load_ia_granted),
        .send_ia_trigger (send_ia_trigger),
        .k               (stream_k),
        .n               (n),
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
	        .ext_dma_is_write(ia_dma_is_write),
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
        .ia_group_calc_done(ia_group_calc_done),
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
        .n                  (n),
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
	        .ext_dma_is_write(kernel_dma_is_write),
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
        .k                (k),
        .m                (m),
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
	        .ext_dma_is_write (bias_dma_is_write),
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
      if (bias_valid) begin
        for (int bi = 0; bi < SIZE; bi = bi + 1) begin
          bias_data_hold[bi] <= bias_data_out[bi];
        end
      end

      if (capture_compute_bias) begin
        for (int bi = 0; bi < SIZE; bi = bi + 1) begin
          compute_bias_latched[bi] <= bias_valid ? bias_data_out[bi] : bias_data_hold[bi];
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
    wire [REG_WIDTH-1:0] is_bias_group_rows_target = ia_reuse_num_eff * REG_WIDTH'(SIZE);
    wire [REG_WIDTH-1:0] is_bias_rows_remaining =
      (m > is_bias_group_base) ? (m - is_bias_group_base) : REG_WIDTH'(0);
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
        end else if (init_cfg_ia) begin
            is_bias_row_idx <= '0;
            is_bias_group_base <= '0;
            is_bias_rows_valid <= REG_WIDTH'(1);
            for (int bi = 0; bi < IS_BIAS_ROWS; bi = bi + 1) begin
                is_bias_tile_data[bi] <= '0;
            end
        end else if (is_mode && acc_data_valid) begin
            if (is_bias_rows_valid <= REG_WIDTH'(1)) begin
                is_bias_row_idx <= '0;
            end else if ((REG_WIDTH'(is_bias_row_idx) + REG_WIDTH'(1)) >= is_bias_rows_valid) begin
                is_bias_row_idx <= '0;
            end else begin
                is_bias_row_idx <= is_bias_row_idx + 1'b1;
            end
        end

        if (rst_n && is_mode && bias_switch) begin
            if ((is_bias_group_base + is_bias_rows_valid) >= m) begin
                is_bias_group_base <= '0;
            end else begin
                is_bias_group_base <= is_bias_group_base + is_bias_rows_valid;
            end
        end

	        if (rst_n && is_mode && send_ia_trigger && !bias_sleep) begin
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

    genvar rq_i;
    generate
        for (rq_i = 0; rq_i < SIZE; rq_i = rq_i + 1) begin : gen_requant_in_vec
            assign requant_in_vec[rq_i] =
          is_mode ? (acc_data_out[rq_i] + is_bias_scalar) : acc_data_out[rq_i];
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            requant_tile_done <= 1'b0;
        end else begin
            requant_tile_done <= tile_calc_over;
        end
    end

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
        .icb_cmd_m         (vec_requant_cmd),
        //.icb_wr_m          (vec_requant_wr),
        .icb_cmd_s         (vec_requant_cmd_ready),
        .icb_wr_s          (vec_requant_w_ready),
        .icb_rsp_s         (vec_requant_rsp),
        .icb_rsp_m         (vec_requant_rsp_ready),
        .in_valid          (acc_data_valid),
        .in_vec_s32        (requant_in_vec),
        .out_valid         (requant_out_valid),
	        .out_vec_s8        (requant_out)
	    );
	    assign vec_requant_w_ready.w_ready = 1'b0;

	    icb_read_dma_adapter #(
	        .BUS_WIDTH(BUS_WIDTH),
	        .REG_WIDTH(REG_WIDTH)
	    ) u_quant_dma_adapter (
	        .clk                 (clk),
	        .rst_n               (rst_n),
	        .icb_cmd_m           (vec_requant_cmd),
	        .icb_cmd_s           (vec_requant_cmd_ready),
	        .icb_rsp_s           (vec_requant_rsp),
	        .icb_rsp_m           (vec_requant_rsp_ready),
	        .dma_granted         (load_quant_granted),
	        .dma_req             (quant_dma_req),
	        .dma_start           (quant_dma_start),
	        .dma_is_write        (quant_dma_is_write),
	        .dma_linear_read_mode(quant_dma_linear_read_mode),
	        .dma_base_addr       (quant_dma_base_addr),
	        .dma_row_stride      (quant_dma_row_stride),
	        .dma_rows_to_read    (quant_dma_rows_to_read),
	        .dma_burst_len_m1    (quant_dma_burst_len_m1),
	        .dma_slot_id         (quant_dma_slot_id),
	        .dma_use_16bits      (quant_dma_use_16bits),
	        .dma_lhs_zp          (quant_dma_lhs_zp),
	        .dma_raw_data        (quant_dma_raw_data),
	        .dma_raw_valid       (quant_dma_raw_valid),
	        .dma_done            (quant_dma_done)
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
        .in_tile_done     (requant_tile_done),
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
        .k                (k),
        .m                (m),
        .ia_reuse_num     (ia_reuse_num_eff),
        .is_mode          (is_mode),
        .output_valid     (fifo_output_valid),
        .switch_row       (fifo_output_switch_row),
	        .output_ready     (fifo_output_ready),
	        .output_mask      (fifo_output_mask),
	        .output_data      (fifo_output_data),
	        .dma_start        (oa_dma_start),
	        .dma_is_write     (oa_dma_is_write),
	        .dma_linear_read_mode(oa_dma_linear_read_mode),
	        .dma_base_addr    (oa_dma_base_addr),
	        .dma_row_stride   (oa_dma_row_stride),
	        .dma_rows_to_read (oa_dma_rows_to_read),
	        .dma_burst_len_m1 (oa_dma_burst_len_m1),
	        .dma_slot_id      (oa_dma_slot_id),
	        .dma_use_16bits   (oa_dma_use_16bits),
	        .dma_lhs_zp       (oa_dma_lhs_zp),
	        .dma_src_wdata    (oa_dma_src_wdata),
	        .dma_src_wmask    (oa_dma_src_wmask),
	        .dma_src_wvalid   (oa_dma_src_wvalid),
	        .dma_src_wready   (oa_dma_src_wready),
	        .dma_busy         (oa_dma_busy),
	        .dma_done         (oa_dma_done),
	        .write_done       (write_done),
	        .oa_calc_over     (oa_calc_over)
	    );

    //assign calc_done = oa_calc_over;
endmodule
