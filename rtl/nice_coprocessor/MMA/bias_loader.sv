/*
 * bias_loader — 顶层汇聚
 * ============================================================
 * 复用现成 block_dma 做一维块读取，ctrl 负责顺序/切换，buffer 负责 bank 存储。
 * 每个 bias block 采用一次 burst 连续读取，避免单 beat 访问开销。
 */

module bias_loader #(
	    parameter int unsigned SIZE       = 8,
	    parameter int unsigned DATA_WIDTH = 32,
	    parameter int unsigned BUS_WIDTH  = 32,
	    parameter int unsigned REG_WIDTH  = 32,
	    parameter int unsigned GROUP_BLOCKS_MAX = 1,
	    parameter bit          EXTERNAL_DMA = 1'b0
	) (
    input logic clk,
    input logic rst_n,

    input logic                 init_cfg,
    input logic [REG_WIDTH-1:0] bias_base,
    input logic [REG_WIDTH-1:0] k,
    input logic [REG_WIDTH-1:0] m,
    input logic [REG_WIDTH-1:0] bias_step_blocks,
    input logic                 bias_switch,
    input logic                 bias_sleep,
    input logic                 bias_last_loop,

    output logic load_bias_req,
    input  logic load_bias_granted,

    output logic                         bias_valid,
    output logic                         next_bias_valid,
    output logic                         bias_group_valid,
    output logic                         load_bias_done,
    output logic signed [DATA_WIDTH-1:0] data_out  [SIZE],
    output logic signed [DATA_WIDTH-1:0] next_data_out [SIZE],
    output logic signed [DATA_WIDTH-1:0] group_data_out [GROUP_BLOCKS_MAX * SIZE],

    output logic                 icb_cmd_valid,
    input  logic                 icb_cmd_ready,
    output logic                 icb_cmd_read,
    output logic [REG_WIDTH-1:0] icb_cmd_addr,
    output logic [          3:0] icb_cmd_len,
	    input  logic                 icb_rsp_valid,
	    output logic                 icb_rsp_ready,
	    input  logic [BUS_WIDTH-1:0] icb_rsp_rdata,
	    input  logic                 icb_rsp_err,

	    // ---- 共享 block_dma 客户端接口（EXTERNAL_DMA=1 时使用）----
	    output logic                 ext_dma_start,
	    output logic                 ext_dma_is_write,
	    output logic                 ext_dma_linear_read_mode,
	    output logic [REG_WIDTH-1:0] ext_dma_base_addr,
	    output logic [REG_WIDTH-1:0] ext_dma_row_stride,
	    output logic [REG_WIDTH-1:0] ext_dma_rows_to_read,
	    output logic [3:0]           ext_dma_burst_len_m1,
	    output logic                 ext_dma_slot_id,
	    output logic                 ext_dma_use_16bits,
	    output logic signed [REG_WIDTH-1:0] ext_dma_lhs_zp,
	    input  logic                 ext_dma_busy,
	    input  logic                 ext_dma_done,
	    input  logic                 ext_dma_wr_slot,
	    input  logic [$clog2(SIZE * (DATA_WIDTH / 8))-1:0] ext_dma_wr_row,
	    input  logic [$clog2(SIZE * (DATA_WIDTH / 8))-1:0] ext_dma_wr_col_base,
	    input  logic signed [7:0]    ext_dma_wr_data [BUS_WIDTH/8],
	    input  logic                 ext_dma_wr_valid[BUS_WIDTH/8],
	    input  logic                 ext_dma_wr_use_16bits
	);

    localparam int DMA_SIZE = SIZE * (DATA_WIDTH / 8);

    logic                               ctrl_dma_start;
    logic        [       REG_WIDTH-1:0] ctrl_dma_base_addr;
    logic        [       REG_WIDTH-1:0] ctrl_dma_rows_to_read;
    logic        [                     3:0] ctrl_dma_burst_len_m1;
    logic                               ctrl_load_bank;
    logic        [       REG_WIDTH-1:0] ctrl_current_block_idx;
    logic        [       REG_WIDTH-1:0] ctrl_load_block_idx;
    logic        [       REG_WIDTH-1:0] ctrl_next_block_idx;
    logic        [       REG_WIDTH-1:0] ctrl_group_blocks_needed;
    logic                               ctrl_active_bank;
    logic                               ctrl_switch_pending;
    logic                               ctrl_load_block_valid;

    logic                               dma_busy;
    logic                               dma_done;
    assign load_bias_done = dma_done;
    logic        [       $clog2(2)-1:0] dma_wr_slot;
    logic        [$clog2(DMA_SIZE)-1:0] dma_wr_row;
    logic        [$clog2(DMA_SIZE)-1:0] dma_wr_col_base;
    logic signed [                7:0] dma_wr_data            [BUS_WIDTH/8];
    logic                               dma_wr_valid           [BUS_WIDTH/8];
    logic                               dma_wr_use_16bits;
    logic        [       BUS_WIDTH-1:0] dma_cmd_wdata_unused;
	    logic        [     BUS_WIDTH/8-1:0] dma_cmd_wmask_unused;
	    logic                               dma_src_wready_unused;

	    assign ext_dma_start            = ctrl_dma_start;
	    assign ext_dma_is_write         = 1'b0;
	    assign ext_dma_linear_read_mode = 1'b0;
	    assign ext_dma_base_addr        = ctrl_dma_base_addr;
	    assign ext_dma_row_stride       = REG_WIDTH'(SIZE * (DATA_WIDTH / 8));
	    assign ext_dma_rows_to_read     = ctrl_dma_rows_to_read;
	    assign ext_dma_burst_len_m1     = ctrl_dma_burst_len_m1;
	    assign ext_dma_slot_id          = ctrl_load_bank;
	    assign ext_dma_use_16bits       = 1'b0;
	    assign ext_dma_lhs_zp           = '0;

    bias_loader_ctrl #(
        .SIZE     (SIZE),
        .REG_WIDTH(REG_WIDTH)
    ) u_ctrl (
        .clk              (clk),
        .rst_n            (rst_n),
        .init_cfg         (init_cfg),
        .bias_base        (bias_base),
        .m                (m),
        .bias_step_blocks (bias_step_blocks),
        .bias_switch      (bias_switch),
        .bias_last_loop   (bias_last_loop),
        .load_bias_req    (load_bias_req),
        .load_bias_granted(load_bias_granted),
        .dma_busy         (dma_busy),
        .dma_done         (dma_done),
        .load_block_valid (ctrl_load_block_valid),
        .dma_start        (ctrl_dma_start),
        .dma_base_addr    (ctrl_dma_base_addr),
        .dma_rows_to_read (ctrl_dma_rows_to_read),
        .dma_burst_len_m1 (ctrl_dma_burst_len_m1),
        .load_bank        (ctrl_load_bank),
        .current_block_idx(ctrl_current_block_idx),
        .load_block_idx   (ctrl_load_block_idx),
        .next_block_idx   (ctrl_next_block_idx),
        .group_blocks_needed(ctrl_group_blocks_needed),
        .active_bank      (ctrl_active_bank),
        .switch_pending   (ctrl_switch_pending)
    );

	    generate
	        if (EXTERNAL_DMA) begin : gen_external_dma
	            assign icb_cmd_valid    = 1'b0;
	            assign icb_cmd_read     = 1'b1;
	            assign icb_cmd_addr     = '0;
	            assign icb_cmd_len      = '0;
	            assign icb_rsp_ready    = 1'b0;
	            assign dma_busy         = ext_dma_busy;
	            assign dma_done         = ext_dma_done;
	            assign dma_wr_slot      = ext_dma_wr_slot;
	            assign dma_wr_row       = ext_dma_wr_row;
	            assign dma_wr_col_base  = ext_dma_wr_col_base;
	            assign dma_wr_use_16bits = ext_dma_wr_use_16bits;
	            for (genvar dma_i = 0; dma_i < BUS_WIDTH/8; dma_i++) begin : gen_ext_wr
	                assign dma_wr_data[dma_i]  = ext_dma_wr_data[dma_i];
	                assign dma_wr_valid[dma_i] = ext_dma_wr_valid[dma_i];
	            end
	        end else begin : gen_internal_dma
	            block_dma #(
	                .DATA_WIDTH  (8),
	                .SIZE        (DMA_SIZE),
	                .BUS_WIDTH   (BUS_WIDTH),
	                .REG_WIDTH   (REG_WIDTH),
	                .CACHE_BLOCKS(2)
	            ) u_dma (
	                .clk             (clk),
	                .rst_n           (rst_n),
	                .start           (ctrl_dma_start),
	                .is_write        (1'b0),
	                .linear_read_mode(1'b0),
	                .tile_base_addr  (ctrl_dma_base_addr),
	                .row_stride      (REG_WIDTH'(SIZE * (DATA_WIDTH / 8))),
	                .rows_to_read    (ctrl_dma_rows_to_read),
	                .burst_len_m1    (ctrl_dma_burst_len_m1),
	                .slot_id         (ctrl_load_bank),
	                .use_16bits      (1'b0),
	                .lhs_zp          ('0),
	                .busy            (dma_busy),
	                .tile_done       (dma_done),
	                .src_wdata       ('0),
	                .src_wmask       ('0),
	                .src_wvalid      (1'b0),
	                .src_wready      (dma_src_wready_unused),
	                .icb_cmd_valid   (icb_cmd_valid),
	                .icb_cmd_ready   (icb_cmd_ready),
	                .icb_cmd_read    (icb_cmd_read),
	                .icb_cmd_addr    (icb_cmd_addr),
	                .icb_cmd_len     (icb_cmd_len),
	                .icb_cmd_wdata   (dma_cmd_wdata_unused),
	                .icb_cmd_wmask   (dma_cmd_wmask_unused),
	                .icb_w_valid     (),
	                .icb_w_ready     (1'b1),
	                .icb_rsp_valid   (icb_rsp_valid),
	                .icb_rsp_ready   (icb_rsp_ready),
	                .icb_rsp_rdata   (icb_rsp_rdata),
	                .icb_rsp_err     (icb_rsp_err),
	                .wr_slot         (dma_wr_slot),
	                .wr_row          (dma_wr_row),
	                .wr_col_base     (dma_wr_col_base),
	                .wr_data         (dma_wr_data),
	                .wr_valid        (dma_wr_valid),
	                .wr_use_16bits   (dma_wr_use_16bits),
	                .rd_raw_data     (),
	                .rd_raw_valid    (),
	                .rd_raw_row      (),
	                .rd_raw_col_base ()
	            );
	        end
	    endgenerate

    bias_loader_buffer #(
        .SIZE           (SIZE),
        .DATA_WIDTH     (DATA_WIDTH),
        .DMA_DATA_WIDTH (8),
        .REG_WIDTH      (REG_WIDTH),
        .GROUP_BLOCKS_MAX(GROUP_BLOCKS_MAX)
    ) u_buffer (
        .clk               (clk),
        .rst_n             (rst_n),
        .init_cfg          (init_cfg),
        .load_start        (ctrl_dma_start),
        .load_bank         (ctrl_load_bank),
        .load_block_idx    (ctrl_load_block_idx),
        .load_word_valid   (dma_wr_valid),
        .load_word_row     (REG_WIDTH'(dma_wr_row)),
        .load_word_col_base(dma_wr_col_base),
        .load_word_data    (dma_wr_data),
        .load_done         (dma_done),
        .active_bank       (ctrl_active_bank),
        .current_block_idx (ctrl_current_block_idx),
        .next_block_idx    (ctrl_next_block_idx),
        .bias_valid        (bias_valid),
        .load_block_valid  (ctrl_load_block_valid),
        .next_bias_valid   (next_bias_valid),
        .data_out          (data_out),
        .next_data_out     (next_data_out),
        .group_data_out    (group_data_out)
    );

    assign bias_group_valid = bias_valid && !ctrl_switch_pending;

endmodule
