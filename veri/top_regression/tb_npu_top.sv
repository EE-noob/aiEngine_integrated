`timescale 1ns / 1ps

module tb_npu_top;
    // 时钟复位
    logic clk = 0;
    always #5 clk = ~clk;  // 100MHz
    logic rst_n = 0;
    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
    end

`ifndef TB_SIZE
`define TB_SIZE 4
`endif
`ifndef TB_WEIGHT_WIDTH
`define TB_WEIGHT_WIDTH 16
`endif
`ifndef TB_DATA_WIDTH
`define TB_DATA_WIDTH 16
`endif
`ifndef TB_IA_CACHE_BLOCKS
`define TB_IA_CACHE_BLOCKS 4
`endif
`ifndef TB_PS_FRAME_COUNT
`define TB_PS_FRAME_COUNT 8
`endif
`ifndef TB_AXI_READ_OUTSTANDING
`define TB_AXI_READ_OUTSTANDING 4
`endif

    localparam int unsigned SIZE = `TB_SIZE;
    localparam int unsigned WEIGHT_WIDTH = `TB_WEIGHT_WIDTH;
    localparam int unsigned DATA_WIDTH = `TB_DATA_WIDTH;
    localparam int unsigned IA_CACHE_BLOCKS = `TB_IA_CACHE_BLOCKS;
    localparam int unsigned PS_FRAME_COUNT = `TB_PS_FRAME_COUNT;
    localparam int unsigned AXI_READ_OUTSTANDING = `TB_AXI_READ_OUTSTANDING;
    localparam int unsigned REGW = 32;

    localparam int unsigned CFG_WORDS = 32;
    localparam logic [31:0] CFG_MAGIC = 32'h4e505531; // "NPU1"
    localparam int CFG_MAGIC_IDX             = 0;
    localparam int CFG_SIZE_IDX              = 1;
    localparam int CFG_IA_CACHE_BLOCKS_IDX   = 2;
    localparam int CFG_K_IDX                 = 3;
    localparam int CFG_N_IDX                 = 4;
    localparam int CFG_M_IDX                 = 5;
    localparam int CFG_IA_REUSE_NUM_IDX      = 6;
    localparam int CFG_W_REUSE_NUM_IDX       = 7;
    localparam int CFG_DATAFLOW_MODE_IDX     = 8;
    localparam int CFG_PS_FRAME_COUNT_IDX    = 9;
    localparam int CFG_COMPARE_WORDS_IDX     = 10;
    localparam int CFG_MEM_WORDS_IDX         = 11;
    localparam int CFG_16BITS_IA_IDX         = 12;
    localparam int CFG_USE_PER_CHANNEL_IDX   = 13;
    localparam int CFG_LHS_BASE_IDX          = 14;
    localparam int CFG_RHS_BASE_IDX          = 15;
    localparam int CFG_BIAS_BASE_IDX         = 16;
    localparam int CFG_DST_BASE_IDX          = 17;
    localparam int CFG_LHS_ROW_STRIDE_B_IDX  = 18;
    localparam int CFG_RHS_ROW_STRIDE_B_IDX  = 19;
    localparam int CFG_DST_ROW_STRIDE_B_IDX  = 20;
    localparam int CFG_LHS_ZP_IDX            = 21;
    localparam int CFG_RHS_ZP_IDX            = 22;
    localparam int CFG_DST_ZP_IDX            = 23;
    localparam int CFG_QMUL_IDX              = 24;
    localparam int CFG_QSHIFT_IDX            = 25;
    localparam int CFG_ACT_MIN_IDX           = 26;
    localparam int CFG_ACT_MAX_IDX           = 27;
    localparam int CFG_16X8_IDX              = 28;

    logic [31:0] case_cfg_mem[0:CFG_WORDS-1];
    logic [REGW-1:0] compare_words;
    logic [REGW-1:0] case_mem_words;

    function automatic logic signed [31:0] cfg_s32(input int idx);
        cfg_s32 = $signed(case_cfg_mem[idx]);
    endfunction

    logic                       calc_start;
    logic                       cfg_16bits_ia;
    logic                       cfg_16x8;
    logic                       cfg_dataflow_mode;
    logic [REGW-1:0]            cfg_ia_reuse_num;
    logic [REGW-1:0]            cfg_w_reuse_num;
    logic                       sa_ready;
    logic [REGW-1:0]            lhs_base;
    logic [REGW-1:0]            rhs_base;
    logic [REGW-1:0]            dst_base;
    logic [REGW-1:0]            bias_base;
    logic signed [REGW-1:0]     lhs_zp;
    logic signed [REGW-1:0]     rhs_zp;
    logic signed [REGW-1:0]     dst_zp;
    logic signed [REGW-1:0]     q_mult_pt;
    logic signed [REGW-1:0]     q_shift_pt;
    logic                       use_per_channel;
    logic [REGW-1:0]            k;
    logic [REGW-1:0]            n;
    logic [REGW-1:0]            m;
    logic [REGW-1:0]            lhs_row_stride_b;
    logic [REGW-1:0]            dst_row_stride_b;
    logic [REGW-1:0]            rhs_row_stride_b;
    logic signed [REGW-1:0]     act_min;
    logic signed [REGW-1:0]     act_max;
    wire        done_valid;
    wire        done_ready = 1'b1;
    wire [ 1:0] err_code;

    wire        m_axi_arvalid;
    wire        m_axi_arready;
    wire [31:0] m_axi_araddr;
    wire [ 7:0] m_axi_arlen;
    wire [ 2:0] m_axi_arsize;
    wire [ 1:0] m_axi_arburst;
    wire        m_axi_rvalid;
    wire        m_axi_rready;
    wire [31:0] m_axi_rdata;
    wire [ 1:0] m_axi_rresp;
    wire        m_axi_rlast;
    wire        m_axi_awvalid;
    wire        m_axi_awready;
    wire [31:0] m_axi_awaddr;
    wire [ 7:0] m_axi_awlen;
    wire [ 2:0] m_axi_awsize;
    wire [ 1:0] m_axi_awburst;
    wire        m_axi_wvalid;
    wire        m_axi_wready;
    wire [31:0] m_axi_wdata;
    wire [ 3:0] m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_bvalid;
    wire        m_axi_bready;
    wire [ 1:0] m_axi_bresp;

    // DUT 实例
    npu_top #(
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .IA_CACHE_BLOCKS(IA_CACHE_BLOCKS),
        .PS_FRAME_COUNT(PS_FRAME_COUNT),
        .AXI_READ_OUTSTANDING(AXI_READ_OUTSTANDING)
    ) u_dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .calc_start   (calc_start),
        .cfg_16bits_ia(cfg_16bits_ia),
        .cfg_16x8(cfg_16x8),
        .cfg_dataflow_mode(cfg_dataflow_mode),
        .cfg_ia_reuse_num(cfg_ia_reuse_num),
        .cfg_w_reuse_num (cfg_w_reuse_num),
        // Four mandatory CPU/compiler-computed fields, packed in descriptor words 30/31.
        .cfg_row_groups({16'b0,case_cfg_mem[30][15:0]}),
        .cfg_col_groups({16'b0,case_cfg_mem[30][31:16]}),
        .cfg_row_tail_tiles({16'b0,case_cfg_mem[31][15:0]}),
        .cfg_col_tail_tiles({16'b0,case_cfg_mem[31][31:16]}),
        .sa_ready     (sa_ready),
        .done_valid   (done_valid),
        .done_ready   (done_ready),
        .err_code     (err_code),

        .lhs_base (lhs_base),
        .rhs_base (rhs_base),
        .dst_base (dst_base),
        .bias_base(bias_base),

        .lhs_zp         (lhs_zp),
        .rhs_zp         (rhs_zp),
        .dst_zp         (dst_zp),
        .q_mult_pt      (q_mult_pt),
        .q_shift_pt     (q_shift_pt),
        .use_per_channel(use_per_channel),

        .k(k),
        .n(n),
        .m(m),

        .lhs_row_stride_b(lhs_row_stride_b),
        .dst_row_stride_b(dst_row_stride_b),
        .rhs_col_stride_b(rhs_row_stride_b),

        .act_min(act_min),
        .act_max(act_max),

        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_araddr (m_axi_araddr),
        .m_axi_arlen  (m_axi_arlen),
        .m_axi_arsize (m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_rvalid (m_axi_rvalid),
        .m_axi_rready (m_axi_rready),
        .m_axi_rdata  (m_axi_rdata),
        .m_axi_rresp  (m_axi_rresp),
        .m_axi_rlast  (m_axi_rlast),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awaddr (m_axi_awaddr),
        .m_axi_awlen  (m_axi_awlen),
        .m_axi_awsize (m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_wvalid (m_axi_wvalid),
        .m_axi_wready (m_axi_wready),
        .m_axi_wdata  (m_axi_wdata),
        .m_axi_wstrb  (m_axi_wstrb),
        .m_axi_wlast  (m_axi_wlast),
        .m_axi_bvalid (m_axi_bvalid),
        .m_axi_bready (m_axi_bready),
        .m_axi_bresp  (m_axi_bresp)
    );

    // 直接 AXI DDR 行为模型：读写通道独立，支持随机 cmd/write/response 延迟。
    ddr_axi_mem_model #(
        .WIDTH (32),
        .ADDR_W(32),
        .MW    (4),
        .DP    (131072)
    ) u_mem (
        .clk          (clk),
        .rst_n        (rst_n),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_araddr (m_axi_araddr),
        .m_axi_arlen  (m_axi_arlen),
        .m_axi_arsize (m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_rvalid (m_axi_rvalid),
        .m_axi_rready (m_axi_rready),
        .m_axi_rdata  (m_axi_rdata),
        .m_axi_rresp  (m_axi_rresp),
        .m_axi_rlast  (m_axi_rlast),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awaddr (m_axi_awaddr),
        .m_axi_awlen  (m_axi_awlen),
        .m_axi_awsize (m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_wvalid (m_axi_wvalid),
        .m_axi_wready (m_axi_wready),
        .m_axi_wdata  (m_axi_wdata),
        .m_axi_wstrb  (m_axi_wstrb),
        .m_axi_wlast  (m_axi_wlast),
        .m_axi_bvalid (m_axi_bvalid),
        .m_axi_bready (m_axi_bready),
        .m_axi_bresp  (m_axi_bresp)
    );

    // 使用 clocking block 初始化配置
    initial begin
        calc_start        <= 1'b0;
        cfg_16bits_ia    <= 1'b0;
        cfg_16x8         <= 1'b0;
        cfg_dataflow_mode <= 1'b0;
        cfg_ia_reuse_num <= '0;
        cfg_w_reuse_num  <= '0;
        lhs_base         <= '0;
        rhs_base         <= '0;
        dst_base         <= '0;
        bias_base        <= '0;
        lhs_zp           <= '0;
        rhs_zp           <= '0;
        dst_zp           <= '0;
        q_mult_pt        <= '0;
        q_shift_pt       <= '0;
        use_per_channel  <= 1'b0;
        k                <= '0;
        n                <= '0;
        m                <= '0;
        lhs_row_stride_b <= '0;
        dst_row_stride_b <= '0;
        rhs_row_stride_b <= '0;
        act_min          <= '0;
        act_max          <= '0;

        @(posedge rst_n);
        @(posedge clk);
        cfg_16bits_ia    <= case_cfg_mem[CFG_16BITS_IA_IDX][0];
        cfg_16x8         <= case_cfg_mem[CFG_16X8_IDX][0];
        cfg_dataflow_mode <= case_cfg_mem[CFG_DATAFLOW_MODE_IDX][0];
        cfg_ia_reuse_num <= case_cfg_mem[CFG_IA_REUSE_NUM_IDX];
        cfg_w_reuse_num  <= case_cfg_mem[CFG_W_REUSE_NUM_IDX];
        lhs_base         <= case_cfg_mem[CFG_LHS_BASE_IDX];
        rhs_base         <= case_cfg_mem[CFG_RHS_BASE_IDX];
        dst_base         <= case_cfg_mem[CFG_DST_BASE_IDX];
        bias_base        <= case_cfg_mem[CFG_BIAS_BASE_IDX];
        lhs_zp           <= cfg_s32(CFG_LHS_ZP_IDX);
        rhs_zp           <= cfg_s32(CFG_RHS_ZP_IDX);
        dst_zp           <= cfg_s32(CFG_DST_ZP_IDX);
        q_mult_pt        <= cfg_s32(CFG_QMUL_IDX);
        q_shift_pt       <= cfg_s32(CFG_QSHIFT_IDX);
        use_per_channel  <= case_cfg_mem[CFG_USE_PER_CHANNEL_IDX][0];
        k                <= case_cfg_mem[CFG_K_IDX];
        n                <= case_cfg_mem[CFG_N_IDX];
        m                <= case_cfg_mem[CFG_M_IDX];
        lhs_row_stride_b <= case_cfg_mem[CFG_LHS_ROW_STRIDE_B_IDX];
        dst_row_stride_b <= case_cfg_mem[CFG_DST_ROW_STRIDE_B_IDX];
        rhs_row_stride_b <= case_cfg_mem[CFG_RHS_ROW_STRIDE_B_IDX];
        act_min          <= cfg_s32(CFG_ACT_MIN_IDX);
        act_max          <= cfg_s32(CFG_ACT_MAX_IDX);
    end

    // 层级引用加载内存
    string init_mem_path, golden_mem_path, case_mem_path;
    localparam int MEMW = 32;
    localparam int MEMDP = 131072;
    reg [MEMW-1:0] golden_mem[0:MEMDP-1];
    integer err;
    integer acc_valid_count;
    integer requant_valid_count;
    integer fifo_req_count;
    integer write_done_count;
    integer tile_calc_over_count;
    integer ia_row_valid_rise_count;
    integer ia_calc_done_count;
    logic   ia_row_valid_q;
    bit     debug_stream;
    bit     full_mem_check;

    initial begin
        debug_stream = $test$plusargs("DEBUG_STREAM");
        full_mem_check = $test$plusargs("FULL_MEM_CHECK");
    end

    function automatic logic [7:0] pick_byte(input logic [31:0] word, input int unsigned byte_sel);
        case (byte_sel[1:0])
            2'd0: pick_byte = word[7:0];
            2'd1: pick_byte = word[15:8];
            2'd2: pick_byte = word[23:16];
            default: pick_byte = word[31:24];
        endcase
    endfunction

    function automatic logic [7:0] actual_mem_byte(input int unsigned byte_addr);
        actual_mem_byte = pick_byte(u_mem.mem_r[byte_addr >> 2], byte_addr);
    endfunction

    function automatic logic [7:0] golden_mem_byte(input int unsigned byte_addr);
        golden_mem_byte = pick_byte(golden_mem[byte_addr >> 2], byte_addr);
    endfunction

    function automatic logic [15:0] actual_mem_s16(input int unsigned byte_addr);
        actual_mem_s16 = {actual_mem_byte(byte_addr + 1), actual_mem_byte(byte_addr)};
    endfunction

    function automatic logic [15:0] golden_mem_s16(input int unsigned byte_addr);
        golden_mem_s16 = {golden_mem_byte(byte_addr + 1), golden_mem_byte(byte_addr)};
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_valid_count       <= 0;
            requant_valid_count   <= 0;
            fifo_req_count        <= 0;
            write_done_count      <= 0;
            tile_calc_over_count  <= 0;
            ia_row_valid_rise_count <= 0;
            ia_calc_done_count     <= 0;
            ia_row_valid_q         <= 1'b0;
        end else begin
            ia_row_valid_q <= u_dut.ia_row_valid;
            if (u_dut.acc_data_valid) acc_valid_count <= acc_valid_count + 1;
            if (u_dut.requant_out_valid) requant_valid_count <= requant_valid_count + 1;
            if (u_dut.fifo_output_req) fifo_req_count <= fifo_req_count + 1;
            if (u_dut.write_done) write_done_count <= write_done_count + 1;
            if (u_dut.tile_calc_over) tile_calc_over_count <= tile_calc_over_count + 1;
            if (u_dut.ia_row_valid && !ia_row_valid_q) ia_row_valid_rise_count <= ia_row_valid_rise_count + 1;
            if (u_dut.ia_row_valid && u_dut.ia_calc_done) ia_calc_done_count <= ia_calc_done_count + 1;
            if (debug_stream && u_dut.store_weight_req) begin
                $display("[DBG][WGT] t=%0t store=%0b w=%0d,%0d,%0d,%0d",
                         $time, u_dut.store_weight_req,
                         u_dut.weight_out[0], u_dut.weight_out[1],
                         u_dut.weight_out[2], u_dut.weight_out[3]);
            end
            if (debug_stream && (u_dut.ia_dma_wr_valid[0] || u_dut.ia_dma_done)) begin
                $display("[DBG][IADMA] t=%0t done=%0b slot=%0d row=%0d col=%0d v=%b data=%0d,%0d,%0d,%0d",
                         $time, u_dut.ia_dma_done, u_dut.ia_dma_wr_slot,
                         u_dut.ia_dma_wr_row, u_dut.ia_dma_wr_col_base,
                         {u_dut.ia_dma_wr_valid[3], u_dut.ia_dma_wr_valid[2],
                          u_dut.ia_dma_wr_valid[1], u_dut.ia_dma_wr_valid[0]},
                         u_dut.ia_dma_wr_data[0], u_dut.ia_dma_wr_data[1],
                         u_dut.ia_dma_wr_data[2], u_dut.ia_dma_wr_data[3]);
            end
            if (debug_stream && u_dut.u_ia_loader.u_ctrl.cache_l1_start) begin
                $display("[DBG][IASTART] t=%0t slot_start=%0d slot_end=%0d l2=%0d l1=%0d wg=%0d w=%0d ia=%0d valid=%b bias_valid=%0b group_valid=%0b bias=%0d,%0d latched=%0d,%0d",
                         $time,
                         u_dut.u_ia_loader.u_ctrl.cache_l1_slot_start,
                         u_dut.u_ia_loader.u_ctrl.cache_l1_slot_end,
                         u_dut.u_ia_loader.u_ctrl.l2_idx,
                         u_dut.u_ia_loader.u_ctrl.l1_idx,
                         u_dut.u_ia_loader.u_ctrl.w_group_idx,
                         u_dut.u_ia_loader.u_ctrl.w_cnt,
                         u_dut.u_ia_loader.u_ctrl.ia_idx,
                         u_dut.u_ia_loader.u_ctrl.cache_blk_valid,
                         u_dut.bias_valid,
                         u_dut.bias_group_valid,
                         u_dut.bias_data_out[0],
                         u_dut.bias_data_out[1],
                         u_dut.compute_bias_latched[0],
                         u_dut.compute_bias_latched[1]);
            end
            if (debug_stream && (u_dut.bias_switch || u_dut.load_bias_granted ||
                                 u_dut.load_bias_done || u_dut.u_bias_loader.u_ctrl.switch_pending)) begin
                $display("[DBG][BIAS] t=%0t state=%0d sw=%0b sleep=%0b last=%0b req=%0b grant=%0b done=%0b pending=%0b cur=%0d load=%0d act_bank=%0b load_bank=%0b valid=%0b group=%0b data=%0d,%0d",
                         $time,
                         u_dut.u_bias_loader.u_ctrl.state,
                         u_dut.bias_switch,
                         u_dut.bias_sleep,
                         u_dut.bias_last_loop,
                         u_dut.load_bias_req,
                         u_dut.load_bias_granted,
                         u_dut.load_bias_done,
                         u_dut.u_bias_loader.u_ctrl.switch_pending,
                         u_dut.u_bias_loader.u_ctrl.current_block_idx,
                         u_dut.u_bias_loader.u_ctrl.load_block_idx,
                         u_dut.u_bias_loader.u_ctrl.active_bank,
                         u_dut.u_bias_loader.u_ctrl.load_bank,
                         u_dut.bias_valid,
                         u_dut.bias_group_valid,
                         u_dut.bias_data_out[0],
                         u_dut.bias_data_out[1]);
            end
            if (debug_stream && u_dut.ia_row_valid) begin
                $display("[DBG][IA]  t=%0t done=%0b init=%0b tile_start=%0b bias_valid=%0b bias=%0d,%0d ia=%0d,%0d,%0d,%0d",
                         $time, u_dut.ia_calc_done, u_dut.ia_is_init_data, u_dut.ia_tile_start,
                         u_dut.bias_valid, u_dut.bias_data_out[0], u_dut.bias_data_out[1],
                         u_dut.ia_out[0], u_dut.ia_out[1],
                         u_dut.ia_out[2], u_dut.ia_out[3]);
            end
            if (debug_stream && (u_dut.u_compute_core.u_ps_buffer.u_ps_buffer_fifo.replay_data_valid ||
                                 u_dut.u_compute_core.u_ps_buffer.u_ps_buffer_fifo.ram_write_en ||
                                 u_dut.u_compute_core.u_ps_buffer.u_ps_buffer_fifo.send_ia_trigger_i)) begin
                $write("[DBG][PS]  t=%0t trig=%0b replay=%0b rcnt=%0d wren=%0b len=%0d ps=",
                         $time,
                         u_dut.u_compute_core.u_ps_buffer.u_ps_buffer_fifo.send_ia_trigger_i,
                         u_dut.u_compute_core.u_ps_buffer.u_ps_buffer_fifo.replay_data_valid,
                         u_dut.u_compute_core.u_ps_buffer.u_ps_buffer_fifo.replay_count,
                         u_dut.u_compute_core.u_ps_buffer.u_ps_buffer_fifo.ram_write_en,
                         u_dut.u_compute_core.u_ps_buffer.u_ps_buffer_fifo.frame_len);
                for (int dbg_i = 0; dbg_i < SIZE; dbg_i++) begin
                    $write("%0d%s", u_dut.u_compute_core.ps_data_out[dbg_i],
                           (dbg_i == SIZE - 1) ? "" : ",");
                end
                $write(" sum=");
                for (int dbg_i = 0; dbg_i < SIZE; dbg_i++) begin
                    $write("%0d%s", u_dut.u_compute_core.systolic_sum[dbg_i],
                           (dbg_i == SIZE - 1) ? "" : ",");
                end
                $write("\n");
            end
            if (debug_stream && u_dut.acc_data_valid) begin
                $write("[DBG][ACC] t=%0t done=%0b row_idx=%0d bias=%0d acc=",
                       $time, u_dut.tile_calc_over, u_dut.is_bias_row_idx,
                       u_dut.is_bias_scalar);
                for (int dbg_i = 0; dbg_i < SIZE; dbg_i++) begin
                    $write("%0d%s", u_dut.acc_data_out[dbg_i],
                           (dbg_i == SIZE - 1) ? "" : ",");
                end
                $write(" sys=");
                for (int dbg_i = 0; dbg_i < SIZE; dbg_i++) begin
                    $write("%0d%s", u_dut.u_compute_core.systolic_sum[dbg_i],
                           (dbg_i == SIZE - 1) ? "" : ",");
                end
                $write("\n");
            end
            if (debug_stream && u_dut.requant_out_valid) begin
                $write("[DBG][RQ]  t=%0t done=%0b out=",
                       $time, u_dut.requant_out_tile_done);
                for (int dbg_i = 0; dbg_i < SIZE; dbg_i++) begin
                    $write("%0d%s", u_dut.requant_out[dbg_i],
                           (dbg_i == SIZE - 1) ? "" : ",");
                end
                $write("\n");
            end
            if (debug_stream && u_dut.fifo_output_valid && u_dut.fifo_output_ready) begin
                $display("[DBG][WR]  t=%0t tile=(%0d,%0d) row=%0d data=%h mask=%b sw=%0b",
                         $time, u_dut.u_oa_writer.tile_row_idx, u_dut.u_oa_writer.tile_col_idx,
                         u_dut.u_oa_writer.row_in_tile,
                         u_dut.fifo_output_data, u_dut.fifo_output_mask,
                         u_dut.fifo_output_switch_row);
            end
        end
    end

    initial begin
        if (!$value$plusargs("INIT_MEM=%s", init_mem_path)) init_mem_path = "out/init.mem";
        if (!$value$plusargs("GOLDEN_MEM=%s", golden_mem_path)) golden_mem_path = "out/golden.mem";
        if (!$value$plusargs("CASE_MEM=%s", case_mem_path)) case_mem_path = "out/config.mem";
        $display("[TB] INIT_MEM=%s", init_mem_path);
        $display("[TB] GOLDEN_MEM=%s", golden_mem_path);
        $display("[TB] CASE_MEM=%s", case_mem_path);

        for (int cfg_i = 0; cfg_i < CFG_WORDS; cfg_i++) begin
            case_cfg_mem[cfg_i] = '0;
        end
        $readmemh(case_mem_path, case_cfg_mem);

        if (case_cfg_mem[CFG_MAGIC_IDX] != CFG_MAGIC) begin
            $display("[TB] FATAL: bad config magic %08x in %s", case_cfg_mem[CFG_MAGIC_IDX], case_mem_path);
            $finish;
        end
        if (case_cfg_mem[CFG_SIZE_IDX] != SIZE) begin
            $display("[TB] FATAL: case SIZE=%0d but compiled TB_SIZE=%0d",
                     case_cfg_mem[CFG_SIZE_IDX], SIZE);
            $finish;
        end
        if (case_cfg_mem[CFG_IA_CACHE_BLOCKS_IDX] != IA_CACHE_BLOCKS) begin
            $display("[TB] FATAL: case IA_CACHE_BLOCKS=%0d but compiled TB_IA_CACHE_BLOCKS=%0d",
                     case_cfg_mem[CFG_IA_CACHE_BLOCKS_IDX], IA_CACHE_BLOCKS);
            $finish;
        end
        if (case_cfg_mem[CFG_PS_FRAME_COUNT_IDX] > PS_FRAME_COUNT) begin
            $display("[TB] FATAL: case PS_FRAME_COUNT=%0d exceeds compiled TB_PS_FRAME_COUNT=%0d",
                     case_cfg_mem[CFG_PS_FRAME_COUNT_IDX], PS_FRAME_COUNT);
            $finish;
        end
        compare_words = case_cfg_mem[CFG_COMPARE_WORDS_IDX];
        case_mem_words = case_cfg_mem[CFG_MEM_WORDS_IDX];

        $display("[TB] CASE SIZE=%0d CACHE=%0d K=%0d N=%0d M=%0d cfg_16bits_ia=%0b cfg_16x8=%0b mode=%s R=%0d W=%0d compare_words=%0d check=%s",
                 SIZE, IA_CACHE_BLOCKS,
                 case_cfg_mem[CFG_K_IDX], case_cfg_mem[CFG_N_IDX], case_cfg_mem[CFG_M_IDX],
                 case_cfg_mem[CFG_16BITS_IA_IDX][0],
                 case_cfg_mem[CFG_16X8_IDX][0],
                 case_cfg_mem[CFG_DATAFLOW_MODE_IDX][0] ? "IS" : "WS",
                 case_cfg_mem[CFG_IA_REUSE_NUM_IDX], case_cfg_mem[CFG_W_REUSE_NUM_IDX],
                 compare_words, full_mem_check ? "full" : "dst");

        if ($test$plusargs("WAVE")) begin
            $dumpfile("wave.vcd");
            $dumpvars(0, tb_npu_top);
        end

        $readmemh(init_mem_path, u_mem.mem_r);
        $readmemh(golden_mem_path, golden_mem);
    end

    // 使用 clocking block 触发计算
    initial begin
        wait (rst_n);
        repeat (5) @(posedge clk);
        calc_start <= 1'b1;
        @(posedge clk);
        calc_start <= 1'b0;
    end

    // 校验
    initial begin
        @(posedge rst_n);

        // 等待 calc_start 被触发
        @(posedge calc_start);
        $display("[TB] calc_start triggered at time %0t", $time);

        // 等待 sa_ready 变为 0（计算开始）
        wait (sa_ready == 1'b0);
        $display("[TB] Computation started (sa_ready=0) at time %0t", $time);

        // 等待 sa_ready 恢复为 1（计算完成）
        wait (sa_ready == 1'b1);
        $display("[TB] Computation done (sa_ready=1) at time %0t", $time);
        if ($test$plusargs("EXPECT_CFG_ERROR")) begin
            if (err_code == 2'b01) $display("[TB] EXPECTED_CFG_ERROR_PASS");
            else $display("[TB] EXPECTED_CFG_ERROR_FAIL code=%0d",err_code);
            $finish;
        end
        if (err_code != 2'b00) begin
            $display("[TB] FAIL, err_code=%0b", err_code);
            $finish;
        end

        // 额外等待几个周期确保结果写入完成
        repeat (10) @(posedge clk);

        err = 0;
        if (full_mem_check) begin
            for (int i = 0; i < int'(compare_words); i++) begin
                if (u_mem.mem_r[i] !== golden_mem[i]) begin
                    if (err < 32) begin
                        $display("[TB][MISMATCH] word %0d: got=%08x exp=%08x", i,
                                 u_mem.mem_r[i], golden_mem[i]);
                    end
                    err++;
                end
            end
        end else begin
            for (int row = 0; row < int'(case_cfg_mem[CFG_K_IDX]); row++) begin
                for (int col = 0; col < int'(case_cfg_mem[CFG_M_IDX]); col++) begin
                    int unsigned byte_addr;
                    logic [7:0] got_byte;
                    logic [7:0] exp_byte;
                    byte_addr = case_cfg_mem[CFG_DST_BASE_IDX] +
                                row * case_cfg_mem[CFG_DST_ROW_STRIDE_B_IDX] +
                                (case_cfg_mem[CFG_16X8_IDX][0] ? (col << 1) : col);
                    if (case_cfg_mem[CFG_16X8_IDX][0]) begin
                        logic [15:0] got_s16;
                        logic [15:0] exp_s16;
                        got_s16 = actual_mem_s16(byte_addr);
                        exp_s16 = golden_mem_s16(byte_addr);
                        if (got_s16 !== exp_s16) begin
                            if (err < 32) begin
                                $display("[TB][MISMATCH] dst[%0d,%0d] addr=%08x got=%04x exp=%04x",
                                         row, col, byte_addr, got_s16, exp_s16);
                            end
                            err++;
                        end
                    end else begin
                        got_byte = actual_mem_byte(byte_addr);
                        exp_byte = golden_mem_byte(byte_addr);
                        if (got_byte !== exp_byte) begin
                            if (err < 32) begin
                                $display("[TB][MISMATCH] dst[%0d,%0d] addr=%08x got=%02x exp=%02x",
                                         row, col, byte_addr, got_byte, exp_byte);
                            end
                            err++;
                        end
                    end
                end
            end
        end
        if (err == 0) $display("[TB] PASS");
        else $display("[TB] FAIL, err=%0d", err);
        $finish;
    end

    initial begin
        longint unsigned timeout_cycles;
        timeout_cycles = 2_000_000;
        void'($value$plusargs("TB_TIMEOUT_CYCLES=%d", timeout_cycles));
        repeat (timeout_cycles) @(posedge clk);
        $display("[TB] FATAL: timeout, sa_ready=%0b done_valid=%0b err_code=%0b",
                 sa_ready, done_valid, err_code);
        $display("[TB][DBG] ctrl_state=%0d ia_valid=%0b ia_done=%0b w_valid=%0b w_done=%0b bias_valid=%0b bias_sleep=%0b quant_valid=%0b tile_calc_over=%0b oa_calc_over=%0b",
                 u_dut.u_npu_controller.current_state,
                 u_dut.ia_data_valid,
                 u_dut.ia_sending_done,
                 u_dut.weight_data_valid,
                 u_dut.weight_sending_done,
                 u_dut.bias_valid,
                 u_dut.bias_sleep,
                 u_dut.quant_params_valid,
                 u_dut.tile_calc_over,
                 u_dut.oa_calc_over);
        $display("[TB][DBG] ia_ctrl_state=%0d ia_l2=%0d ia_l1=%0d ia_w=%0d ia_idx=%0d ia_all_done=%0b",
                 u_dut.u_ia_loader.u_ctrl.state,
                 u_dut.u_ia_loader.u_ctrl.l2_idx,
                 u_dut.u_ia_loader.u_ctrl.l1_idx,
                 u_dut.u_ia_loader.u_ctrl.w_cnt,
                 u_dut.u_ia_loader.u_ctrl.ia_idx,
                 u_dut.u_ia_loader.ctrl_all_done);
        $display("[TB][DBG] w_ctrl_state=%0d w_tile_row=%0d w_tile_col=%0d w_rep=%0d w_all_done=%0b",
                 u_dut.u_kernel_loader.u_ctrl.state,
                 u_dut.u_kernel_loader.u_ctrl.tile_row_dbg,
                 u_dut.u_kernel_loader.u_ctrl.tile_col_dbg,
                 u_dut.u_kernel_loader.u_ctrl.repeat_dbg,
                 u_dut.u_kernel_loader.ctrl_all_done);
        $display("[TB][DBG] oa_state=%0d tiles_done=%0d tile_row=%0d tile_col=%0d write_req=%0b write_done=%0b",
                 u_dut.u_oa_writer.state,
                 u_dut.u_oa_writer.tiles_done,
                 u_dut.u_oa_writer.tile_row_idx,
                 u_dut.u_oa_writer.tile_col_idx,
                 u_dut.write_oa_req,
                 u_dut.write_done);
        $display("[TB][DBG] oa has_grant=%0b cmd_pending=%0b cmd_inflight=%0b rsp_inflight=%0b tile_done_pending=%0b beats_in_row=%0d beats_per_row=%0d row_in_tile=%0d out_ready_cond=%0b cmd_fire=%0b beat_fire=%0b rsp_fire=%0b",
                 u_dut.u_oa_writer.has_grant,
                 u_dut.u_oa_writer.cmd_pending,
                 u_dut.u_oa_writer.cmd_inflight,
                 u_dut.u_oa_writer.rsp_inflight,
                 u_dut.u_oa_writer.tile_done_pending,
                 u_dut.u_oa_writer.beats_in_row,
                 u_dut.u_oa_writer.beats_per_row,
                 u_dut.u_oa_writer.row_in_tile,
                 u_dut.u_oa_writer.writer_ready_cond,
                 u_dut.u_oa_writer.cmd_fire,
                 u_dut.u_oa_writer.beat_fire,
                 u_dut.u_oa_writer.rsp_fire);
        $display("[TB][DBG] fifo req=%0b full=%0b stream=%0b ready0=%0b ready1=%0b read_sel=%0b write_sel=%0b out_v=%0b out_r=%0b bank_count0=%0d bank_count1=%0d",
                 u_dut.fifo_output_req,
                 u_dut.fifo_full_flag,
                 u_dut.u_vec_s8_to_fifo.stream_active,
                 u_dut.u_vec_s8_to_fifo.bank_ready0,
                 u_dut.u_vec_s8_to_fifo.bank_ready1,
                 u_dut.u_vec_s8_to_fifo.read_sel,
                 u_dut.u_vec_s8_to_fifo.write_sel,
                 u_dut.fifo_output_valid,
                 u_dut.fifo_output_ready,
                 u_dut.u_vec_s8_to_fifo.bank_count0,
                 u_dut.u_vec_s8_to_fifo.bank_count1);
        $display("[TB][DBG] dma_arb rd_active=%0b rd_client=%0d rd_started=%0b rd_busy=%0b rd_done=%0b wr_active=%0b wr_started=%0b wr_busy=%0b wr_done=%0b",
                 u_dut.u_block_dma_arbiter.rd_active,
                 u_dut.u_block_dma_arbiter.rd_client,
                 u_dut.u_block_dma_arbiter.rd_started,
                 u_dut.u_block_dma_arbiter.rd_dma_busy,
                 u_dut.u_block_dma_arbiter.rd_dma_done,
                 u_dut.u_block_dma_arbiter.wr_active,
                 u_dut.u_block_dma_arbiter.wr_started,
                 u_dut.u_block_dma_arbiter.wr_dma_busy,
                 u_dut.u_block_dma_arbiter.wr_dma_done);
        $display("[TB][DBG] dma rd_cmd_row=%0d rd_rsp_row=%0d rd_rsp_beat=%0d rd_inflight=%0b rd_active=%0b rd_done=%0b wr_beat=%0d",
                 u_dut.u_block_dma_arbiter.u_dma.rd_cmd_row_cnt,
                 u_dut.u_block_dma_arbiter.u_dma.rd_rsp_row_cnt,
                 u_dut.u_block_dma_arbiter.u_dma.rd_rsp_beat_cnt,
                 u_dut.u_block_dma_arbiter.u_dma.rd_cmd_inflight,
                 u_dut.u_block_dma_arbiter.u_dma.rd_active,
                 u_dut.u_block_dma_arbiter.u_dma.rd_done,
                 u_dut.u_block_dma_arbiter.u_dma.wr_beat_cnt);
        $display("[TB][DBG] axi ar_v=%0b ar_r=%0b r_v=%0b r_r=%0b aw_v=%0b aw_r=%0b w_v=%0b w_r=%0b b_v=%0b b_r=%0b",
                 m_axi_arvalid,
                 m_axi_arready,
                 m_axi_rvalid,
                 m_axi_rready,
                 m_axi_awvalid,
                 m_axi_awready,
                 m_axi_wvalid,
                 m_axi_wready,
                 m_axi_bvalid,
                 m_axi_bready);
        $display("[TB][DBG] ddr_axi r_state=%0d w_state=%0d r_wait=%0d w_wait=%0d r_left=%0d w_left=%0d r_addr=%h w_addr=%h",
                 u_mem.r_state,
                 u_mem.w_state,
                 u_mem.r_wait_cnt,
                 u_mem.w_wait_cnt,
                 u_mem.r_left,
                 u_mem.w_left,
                 u_mem.r_addr,
                 u_mem.w_addr);
        $display("[TB][DBG] counts acc=%0d requant=%0d fifo_req=%0d write_done=%0d tile_calc_over=%0d ia_rise=%0d ia_calc_done_cycles=%0d",
                 acc_valid_count,
                 requant_valid_count,
                 fifo_req_count,
                 write_done_count,
                 tile_calc_over_count,
                 ia_row_valid_rise_count,
                 ia_calc_done_count);
        $finish;
    end

endmodule
