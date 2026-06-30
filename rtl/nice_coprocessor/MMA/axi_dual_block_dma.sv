/*
 * axi_dual_block_dma -- native AXI4 read/write block DMA
 * ======================================================
 *
 * This module is the AXI-native replacement building block for the shared ICB
 * block_dma.  Read and write commands are split into independent engines:
 *
 *   - read  engine: AXI AR/R, used by IA/kernel/bias/quant loaders
 *   - write engine: AXI AW/W/B, used by OA writer
 *
 * The two engines can be active at the same time, allowing AXI full-duplex
 * memory traffic without an ICB-to-AXI bridge.
 */

module axi_dual_block_dma #(
    parameter int unsigned DATA_WIDTH   = 16,
    parameter int unsigned SIZE         = 16,
    parameter int unsigned BUS_WIDTH    = 32,
    parameter int unsigned REG_WIDTH    = 32,
    parameter int unsigned CACHE_BLOCKS = 4,
    parameter int unsigned READ_OUTSTANDING = 4,
    parameter int unsigned WRITE_OUTSTANDING = READ_OUTSTANDING
) (
    input logic clk,
    input logic rst_n,

    // ---- Read block command ----
    input  logic                                   rd_start,
    input  logic                                   rd_linear_read_mode,
    input  logic        [           REG_WIDTH-1:0] rd_base_addr,
    input  logic        [           REG_WIDTH-1:0] rd_row_stride,
    input  logic        [           REG_WIDTH-1:0] rd_rows_to_read,
    input  logic        [           REG_WIDTH-1:0] rd_valid_cols,
    input  logic        [                     3:0] rd_burst_len_m1,
    input  logic        [$clog2(CACHE_BLOCKS)-1:0] rd_slot_id,
    input  logic                                   rd_use_16bits,
    input  logic signed [           REG_WIDTH-1:0] rd_lhs_zp,
    output logic                                   rd_busy,
    output logic                                   rd_done,

    // ---- Write block command ----
    input  logic                            wr_start,
    input  logic [           REG_WIDTH-1:0] wr_base_addr,
    input  logic [           REG_WIDTH-1:0] wr_row_stride,
    input  logic [           REG_WIDTH-1:0] wr_rows_to_write,
    input  logic [                     3:0] wr_burst_len_m1,
    output logic                            wr_busy,
    output logic                            wr_done,

    // ---- Write data stream ----
    input  logic [  BUS_WIDTH-1:0] src_wdata,
    input  logic [BUS_WIDTH/8-1:0] src_wmask,
    input  logic                   src_wvalid,
    output logic                   src_wready,

    // ---- AXI4 master read address channel ----
    output logic                   m_axi_arvalid,
    input  logic                   m_axi_arready,
    output logic [  REG_WIDTH-1:0] m_axi_araddr,
    output logic [            7:0] m_axi_arlen,
    output logic [            2:0] m_axi_arsize,
    output logic [            1:0] m_axi_arburst,

    // ---- AXI4 master read data channel ----
    input  logic                   m_axi_rvalid,
    output logic                   m_axi_rready,
    input  logic [  BUS_WIDTH-1:0] m_axi_rdata,
    input  logic [            1:0] m_axi_rresp,
    input  logic                   m_axi_rlast,

    // ---- AXI4 master write address channel ----
    output logic                   m_axi_awvalid,
    input  logic                   m_axi_awready,
    output logic [  REG_WIDTH-1:0] m_axi_awaddr,
    output logic [            7:0] m_axi_awlen,
    output logic [            2:0] m_axi_awsize,
    output logic [            1:0] m_axi_awburst,

    // ---- AXI4 master write data channel ----
    output logic                   m_axi_wvalid,
    input  logic                   m_axi_wready,
    output logic [  BUS_WIDTH-1:0] m_axi_wdata,
    output logic [BUS_WIDTH/8-1:0] m_axi_wstrb,
    output logic                   m_axi_wlast,

    // ---- AXI4 master write response channel ----
    input  logic                   m_axi_bvalid,
    output logic                   m_axi_bready,
    input  logic [            1:0] m_axi_bresp,

    // ---- Read unpack output ----
    output logic        [$clog2(CACHE_BLOCKS)-1:0] wr_slot,
    output logic        [        $clog2(SIZE)-1:0] wr_row,
    output logic        [        $clog2(SIZE)-1:0] wr_col_base,
    output logic signed [          DATA_WIDTH-1:0] wr_data      [BUS_WIDTH/8],
    output logic                                   wr_valid     [BUS_WIDTH/8],
    output logic                                   wr_use_16bits,

    // ---- Raw read stream for quant/bias-like users ----
    output logic [   BUS_WIDTH-1:0] rd_raw_data,
    output logic                    rd_raw_valid,
    output logic [$clog2(SIZE)-1:0] rd_raw_row,
    output logic [$clog2(SIZE)-1:0] rd_raw_col_base,

    output logic rd_error,
    output logic wr_error
);

    localparam int unsigned BYTE_PER_BEAT = BUS_WIDTH / 8;
    localparam int unsigned ELEM_PER_BEAT_S8 = BYTE_PER_BEAT;
    localparam int unsigned ELEM_PER_BEAT_S16 = BYTE_PER_BEAT >> 1;
    localparam int unsigned ADDR_LSB = $clog2(BYTE_PER_BEAT);
    localparam int unsigned AXI_SIZE_VALUE = $clog2(BYTE_PER_BEAT);
    localparam int unsigned RD_OUTS_MAX =
        (READ_OUTSTANDING < 1) ? 1 : READ_OUTSTANDING;
    localparam int unsigned RD_OUTS_W =
        (RD_OUTS_MAX < 2) ? 1 : $clog2(RD_OUTS_MAX + 1);
    localparam int unsigned WR_OUTS_MAX =
        (WRITE_OUTSTANDING < 1) ? 1 : WRITE_OUTSTANDING;
    localparam int unsigned WR_OUTS_W =
        (WR_OUTS_MAX < 2) ? 1 : $clog2(WR_OUTS_MAX + 1);

    wire rd_ar_hs = m_axi_arvalid && m_axi_arready;
    wire rd_r_hs  = m_axi_rvalid && m_axi_rready;
    wire wr_aw_hs = m_axi_awvalid && m_axi_awready;
    wire wr_w_hs  = m_axi_wvalid && m_axi_wready;
    wire wr_b_hs  = m_axi_bvalid && m_axi_bready;

    logic dma_trace_en;
    initial begin
        dma_trace_en = 1'b0;
        if ($test$plusargs("MMA_DMA_TRACE")) dma_trace_en = 1'b1;
    end

    function automatic [REG_WIDTH-1:0] align_down(input [REG_WIDTH-1:0] addr);
        align_down = {addr[REG_WIDTH-1:ADDR_LSB], {ADDR_LSB{1'b0}}};
    endfunction

    // ---------------------------------------------------------------------
    // Read engine configuration/state
    // ---------------------------------------------------------------------
    logic [REG_WIDTH-1:0] rd_cfg_base_addr;
    logic [REG_WIDTH-1:0] rd_cfg_row_stride;
    logic [REG_WIDTH-1:0] rd_cfg_rows;
    logic [REG_WIDTH-1:0] rd_cfg_valid_cols;
    logic [3:0] rd_cfg_burst_len_m1;
    logic [$clog2(CACHE_BLOCKS)-1:0] rd_cfg_slot;
    logic rd_cfg_linear_read;
    logic rd_cfg_use_16bits;
    logic signed [REG_WIDTH-1:0] rd_cfg_zp;

    logic [REG_WIDTH-1:0] rd_cmd_row_cnt;
    logic [REG_WIDTH-1:0] rd_rsp_row_cnt;
    logic [REG_WIDTH-1:0] rd_rsp_beat_cnt;
    logic [BUS_WIDTH-1:0] rd_rsp_prev_data;
    logic [BUS_WIDTH-1:0] rd_rsp_data_r;
    logic [REG_WIDTH-1:0] rd_rsp_row_r;
    logic [$clog2(SIZE)-1:0] rd_rsp_col_base_r;
    logic rd_rsp_valid_r;
    logic [RD_OUTS_W-1:0] rd_outstanding_cnt;
    logic rd_cmd_inflight;
    logic rd_active;
    logic rd_done_r;
    logic rd_error_r;
    logic rd_pending_cmd_cross;
    longint unsigned rd_trace_ar_count;
    longint unsigned rd_trace_unaligned_ar_count;
    longint unsigned rd_trace_cross_ar_count;
    longint unsigned rd_trace_r_count;
    logic [RD_OUTS_W-1:0] rd_trace_max_outs;

    assign rd_busy = rd_active;
    assign rd_done = rd_done_r;
    assign rd_error = rd_error_r;
    assign wr_use_16bits = rd_cfg_use_16bits;
    assign wr_slot = rd_cfg_slot;

    assign m_axi_arsize  = 3'(AXI_SIZE_VALUE);
    assign m_axi_arburst = 2'b01; // INCR
    assign m_axi_rready  = rd_active;
    assign rd_cmd_inflight = (rd_outstanding_cnt != '0);

    wire [REG_WIDTH-1:0] rd_cfg_burst_len_ext = REG_WIDTH'(rd_cfg_burst_len_m1);
    wire [REG_WIDTH-1:0] rd_logical_burst_len_ext =
        rd_cfg_linear_read ? REG_WIDTH'(0) : rd_cfg_burst_len_ext;
    wire rd_unaligned_mode = (rd_cfg_base_addr[ADDR_LSB-1:0] != '0)
                          || (rd_cfg_row_stride[ADDR_LSB-1:0] != '0);

    wire [REG_WIDTH-1:0] rd_rsp_row_addr =
        rd_cfg_base_addr + rd_rsp_row_cnt * rd_cfg_row_stride;
    wire [ADDR_LSB-1:0] rd_rsp_offset = rd_rsp_row_addr[ADDR_LSB-1:0];
    wire rd_rsp_cross = rd_unaligned_mode && (rd_rsp_offset != '0);
    wire [REG_WIDTH-1:0] rd_rsp_aligned_last_beat =
        rd_logical_burst_len_ext + (rd_rsp_cross ? REG_WIDTH'(1) : REG_WIDTH'(0));
    wire rd_rsp_emit = !rd_rsp_cross || (rd_rsp_beat_cnt != '0);

    wire rd_rsp_done = rd_r_hs
                    && ((rd_rsp_beat_cnt == rd_rsp_aligned_last_beat) || m_axi_rlast);

    wire last_rd_rsp = rd_rsp_done && (rd_rsp_row_cnt == rd_cfg_rows - 1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_done_r <= 1'b0;
        end else begin
            rd_done_r <= rd_active && last_rd_rsp;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_active           <= 1'b0;
            rd_cfg_base_addr    <= '0;
            rd_cfg_row_stride   <= '0;
            rd_cfg_rows         <= '0;
            rd_cfg_valid_cols   <= REG_WIDTH'(SIZE);
            rd_cfg_burst_len_m1 <= '0;
            rd_cfg_slot         <= '0;
            rd_cfg_linear_read  <= 1'b0;
            rd_cfg_use_16bits   <= 1'b0;
            rd_cfg_zp           <= '0;
            rd_error_r          <= 1'b0;
        end else if (rd_start && !rd_active) begin
            rd_active           <= 1'b1;
            rd_cfg_base_addr    <= rd_base_addr;
            rd_cfg_row_stride   <= rd_row_stride;
            rd_cfg_rows         <= rd_rows_to_read;
            rd_cfg_valid_cols   <= (rd_valid_cols == '0) ? REG_WIDTH'(SIZE) : rd_valid_cols;
            rd_cfg_burst_len_m1 <= rd_burst_len_m1;
            rd_cfg_slot         <= rd_slot_id;
            rd_cfg_linear_read  <= rd_linear_read_mode;
            rd_cfg_use_16bits   <= rd_use_16bits;
            rd_cfg_zp           <= rd_lhs_zp;
            rd_error_r          <= 1'b0;
        end else begin
            if (rd_r_hs && m_axi_rresp[1]) rd_error_r <= 1'b1;
            if (rd_done_r) rd_active <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_arvalid   <= 1'b0;
            m_axi_araddr    <= '0;
            m_axi_arlen     <= '0;
            rd_cmd_row_cnt  <= '0;
            rd_outstanding_cnt <= '0;
            rd_pending_cmd_cross <= 1'b0;
        end else if (rd_start && !rd_active) begin
            m_axi_arvalid   <= 1'b0;
            m_axi_araddr    <= rd_base_addr;
            m_axi_arlen     <= '0;
            rd_cmd_row_cnt  <= '0;
            rd_outstanding_cnt <= '0;
            rd_pending_cmd_cross <= 1'b0;
        end else if (rd_active) begin
            if (rd_done_r) begin
                m_axi_arvalid   <= 1'b0;
                rd_outstanding_cnt <= '0;
                rd_pending_cmd_cross <= 1'b0;
            end else begin
                if (rd_ar_hs) begin
                    m_axi_arvalid <= 1'b0;
                    rd_pending_cmd_cross <= 1'b0;
                end else if (!m_axi_arvalid &&
                             (rd_unaligned_mode
                                ? (rd_outstanding_cnt == '0)
                                : (rd_outstanding_cnt < RD_OUTS_W'(RD_OUTS_MAX))) &&
                             (rd_cmd_row_cnt < rd_cfg_rows)) begin
                    logic [REG_WIDTH-1:0] cmd_addr_cur;
                    logic [ADDR_LSB-1:0] cmd_offset_cur;

                    cmd_addr_cur = rd_cfg_base_addr + rd_cmd_row_cnt * rd_cfg_row_stride;
                    cmd_offset_cur = cmd_addr_cur[ADDR_LSB-1:0];
                    m_axi_arvalid <= 1'b1;
                    m_axi_araddr  <= rd_unaligned_mode ? align_down(cmd_addr_cur) : cmd_addr_cur;
                    m_axi_arlen   <= 8'(rd_cfg_linear_read ? 4'd0 : rd_cfg_burst_len_m1)
                                   + ((rd_unaligned_mode && (cmd_offset_cur != '0)) ? 8'd1 : 8'd0);
                    rd_cmd_row_cnt <= rd_cmd_row_cnt + 1'b1;
                    rd_pending_cmd_cross <= rd_unaligned_mode && (cmd_offset_cur != '0);
                end

                unique case ({rd_ar_hs, rd_rsp_done})
                    2'b10: rd_outstanding_cnt <= rd_outstanding_cnt + 1'b1;
                    2'b01: rd_outstanding_cnt <= rd_outstanding_cnt - 1'b1;
                    default: rd_outstanding_cnt <= rd_outstanding_cnt;
                endcase
            end
        end else begin
            m_axi_arvalid   <= 1'b0;
            rd_cmd_row_cnt  <= '0;
            rd_outstanding_cnt <= '0;
            rd_pending_cmd_cross <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_trace_ar_count          <= '0;
            rd_trace_unaligned_ar_count <= '0;
            rd_trace_cross_ar_count    <= '0;
            rd_trace_r_count           <= '0;
            rd_trace_max_outs          <= '0;
        end else if (rd_start && !rd_active) begin
            rd_trace_ar_count          <= '0;
            rd_trace_unaligned_ar_count <= '0;
            rd_trace_cross_ar_count    <= '0;
            rd_trace_r_count           <= '0;
            rd_trace_max_outs          <= '0;
        end else if (rd_active) begin
            if (rd_ar_hs) begin
                rd_trace_ar_count <= rd_trace_ar_count + 1'b1;
                if (rd_unaligned_mode) rd_trace_unaligned_ar_count <= rd_trace_unaligned_ar_count + 1'b1;
                if (rd_pending_cmd_cross) rd_trace_cross_ar_count <= rd_trace_cross_ar_count + 1'b1;
                if (!rd_rsp_done && ((rd_outstanding_cnt + 1'b1) > rd_trace_max_outs)) begin
                    rd_trace_max_outs <= rd_outstanding_cnt + 1'b1;
                end else if (rd_rsp_done && (rd_outstanding_cnt > rd_trace_max_outs)) begin
                    rd_trace_max_outs <= rd_outstanding_cnt;
                end
            end
            if (rd_r_hs) begin
                rd_trace_r_count <= rd_trace_r_count + 1'b1;
            end
            if (rd_done_r && dma_trace_en) begin
                $display("[AXI_DMA_TRACE] rd_done base=%08x stride=%0d rows=%0d len_m1=%0d linear=%0b use16=%0b unaligned=%0b ar=%0d ar_unaligned=%0d ar_cross=%0d r=%0d max_out=%0d",
                         rd_cfg_base_addr, rd_cfg_row_stride, rd_cfg_rows,
                         rd_cfg_burst_len_m1, rd_cfg_linear_read,
                         rd_cfg_use_16bits, rd_unaligned_mode,
                         rd_trace_ar_count, rd_trace_unaligned_ar_count,
                         rd_trace_cross_ar_count, rd_trace_r_count,
                         rd_trace_max_outs);
            end
        end
    end

    logic [REG_WIDTH-1:0] rd_rsp_logical_beat_comb;
    logic [$clog2(SIZE)-1:0] rd_rsp_col_base_comb;
    logic [BUS_WIDTH-1:0] rd_rsp_aligned_data_comb;
    always_comb begin
        rd_rsp_logical_beat_comb = rd_rsp_beat_cnt;
        rd_rsp_aligned_data_comb = m_axi_rdata;

        if (rd_cfg_linear_read) begin
            rd_rsp_logical_beat_comb = rd_rsp_row_cnt;
        end

        if (rd_rsp_cross) begin
            if (!rd_cfg_linear_read) begin
                rd_rsp_logical_beat_comb = (rd_rsp_beat_cnt == '0) ? '0 : (rd_rsp_beat_cnt - 1'b1);
            end
            rd_rsp_aligned_data_comb =
                (m_axi_rdata << ((BYTE_PER_BEAT - int'(rd_rsp_offset)) * 8)) |
                (rd_rsp_prev_data >> (int'(rd_rsp_offset) * 8));
        end
    end

    assign rd_rsp_col_base_comb = rd_cfg_use_16bits
                                ? rd_rsp_logical_beat_comb[$clog2(SIZE)-1:0] << $clog2(ELEM_PER_BEAT_S16)
                                : rd_rsp_logical_beat_comb[$clog2(SIZE)-1:0] << $clog2(ELEM_PER_BEAT_S8);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_rsp_row_cnt    <= '0;
            rd_rsp_beat_cnt   <= '0;
            rd_rsp_prev_data   <= '0;
            rd_rsp_valid_r    <= 1'b0;
            rd_rsp_data_r     <= '0;
            rd_rsp_row_r      <= '0;
            rd_rsp_col_base_r <= '0;
        end else if (rd_start && !rd_active) begin
            rd_rsp_row_cnt  <= '0;
            rd_rsp_beat_cnt <= '0;
            rd_rsp_prev_data <= '0;
            rd_rsp_valid_r  <= 1'b0;
        end else if (rd_active) begin
            if (rd_r_hs) begin
                rd_rsp_prev_data  <= m_axi_rdata;
                rd_rsp_data_r     <= rd_rsp_aligned_data_comb;
                rd_rsp_row_r      <= rd_cfg_linear_read ? '0 : rd_rsp_row_cnt;
                rd_rsp_col_base_r <= rd_rsp_col_base_comb;
                rd_rsp_valid_r    <= rd_rsp_emit;

                if (rd_rsp_done) begin
                    rd_rsp_beat_cnt <= '0;
                    if (rd_rsp_row_cnt == rd_cfg_rows - 1) rd_rsp_row_cnt <= '0;
                    else rd_rsp_row_cnt <= rd_rsp_row_cnt + 1'b1;
                end else begin
                    rd_rsp_beat_cnt <= rd_rsp_beat_cnt + 1'b1;
                end
            end else begin
                rd_rsp_valid_r <= 1'b0;
            end
        end else begin
            rd_rsp_row_cnt  <= '0;
            rd_rsp_beat_cnt <= '0;
            rd_rsp_prev_data <= '0;
            rd_rsp_valid_r  <= 1'b0;
        end
    end

    assign wr_row          = rd_rsp_row_r[$clog2(SIZE)-1:0];
    assign wr_col_base     = rd_rsp_col_base_r;
    assign rd_raw_data     = rd_rsp_data_r;
    assign rd_raw_valid    = rd_rsp_valid_r;
    assign rd_raw_row      = rd_rsp_row_r[$clog2(SIZE)-1:0];
    assign rd_raw_col_base = rd_rsp_col_base_r;

    always_comb begin
        for (int i = 0; i < BYTE_PER_BEAT; i++) begin
            wr_data[i]  = '0;
            wr_valid[i] = 1'b0;
        end

        if (rd_rsp_valid_r) begin
            if (rd_cfg_use_16bits) begin
                for (int i = 0; i < ELEM_PER_BEAT_S16; i++) begin
                    if (rd_rsp_col_base_r + i < SIZE) begin
                        if (REG_WIDTH'(rd_rsp_col_base_r + i) < rd_cfg_valid_cols) begin
                            wr_data[i] = DATA_WIDTH'($signed(rd_rsp_data_r[i*16+:16]) + rd_cfg_zp[15:0]);
                        end
                        wr_valid[i] = 1'b1;
                    end
                end
            end else begin
                for (int i = 0; i < ELEM_PER_BEAT_S8; i++) begin
                    if (rd_rsp_col_base_r + i < SIZE) begin
                        if (REG_WIDTH'(rd_rsp_col_base_r + i) < rd_cfg_valid_cols) begin
                            wr_data[i] = DATA_WIDTH'($signed({{8{rd_rsp_data_r[i*8+7]}}, rd_rsp_data_r[i*8+:8]}) + rd_cfg_zp[15:0]);
                        end
                        wr_valid[i] = 1'b1;
                    end
                end
            end
        end
    end

    // ---------------------------------------------------------------------
    // Write engine configuration/state
    // ---------------------------------------------------------------------
    logic [REG_WIDTH-1:0] wr_cfg_base_addr;
    logic [REG_WIDTH-1:0] wr_cfg_row_stride;
    logic [REG_WIDTH-1:0] wr_cfg_rows;
    logic [3:0] wr_cfg_burst_len_m1;
    logic [REG_WIDTH-1:0] wr_cmd_row_cnt;
    logic [REG_WIDTH-1:0] wr_data_row_cnt;
    logic [REG_WIDTH-1:0] wr_resp_row_cnt;
    logic [REG_WIDTH-1:0] wr_beat_cnt;
    logic [BUS_WIDTH-1:0] wr_tail_data;
    logic [BUS_WIDTH/8-1:0] wr_tail_mask;
    logic wr_active;
    logic wr_data_active;
    logic [WR_OUTS_W-1:0] wr_outstanding_cnt;
    logic wr_done_r;
    logic wr_error_r;
    logic wr_pending_cmd_cross;
    longint unsigned wr_trace_aw_count;
    longint unsigned wr_trace_cross_aw_count;
    longint unsigned wr_trace_w_count;
    logic [WR_OUTS_W-1:0] wr_trace_max_outs;

    assign wr_busy  = wr_active;
    assign wr_done  = wr_done_r;
    assign wr_error = wr_error_r;

    wire [REG_WIDTH-1:0] wr_cfg_burst_len_ext = REG_WIDTH'(wr_cfg_burst_len_m1);
    wire [REG_WIDTH-1:0] wr_cmd_row_addr_cur =
        wr_cfg_base_addr + wr_cmd_row_cnt * wr_cfg_row_stride;
    wire [ADDR_LSB-1:0] wr_cmd_row_offset = wr_cmd_row_addr_cur[ADDR_LSB-1:0];
    wire [REG_WIDTH-1:0] wr_data_row_addr_cur =
        wr_cfg_base_addr + wr_data_row_cnt * wr_cfg_row_stride;
    wire [ADDR_LSB-1:0] wr_row_offset = wr_data_row_addr_cur[ADDR_LSB-1:0];
    wire wr_row_cross = (wr_row_offset != '0);
    wire [REG_WIDTH-1:0] wr_aligned_last_beat =
        wr_cfg_burst_len_ext + (wr_row_cross ? REG_WIDTH'(1) : REG_WIDTH'(0));
    wire wr_tail_beat = wr_row_cross && (wr_beat_cnt == wr_aligned_last_beat);
    wire wr_need_src_beat = !wr_tail_beat;
    wire wr_can_issue_aw = wr_active &&
                            (wr_cmd_row_cnt < wr_cfg_rows) &&
                            (wr_outstanding_cnt < WR_OUTS_W'(WR_OUTS_MAX));
    wire wr_can_start_data = wr_active && !wr_data_active &&
                              (wr_data_row_cnt < wr_cmd_row_cnt);

    logic [BUS_WIDTH-1:0] wr_aligned_wdata;
    logic [BUS_WIDTH/8-1:0] wr_aligned_wstrb;
    always_comb begin
        wr_aligned_wdata = src_wdata;
        wr_aligned_wstrb = src_wmask;

        if (wr_row_cross) begin
            if (wr_tail_beat) begin
                wr_aligned_wdata = wr_tail_data;
                wr_aligned_wstrb = wr_tail_mask;
            end else begin
                wr_aligned_wdata =
                    (src_wdata << (int'(wr_row_offset) * 8)) | wr_tail_data;
                wr_aligned_wstrb =
                    (src_wmask << int'(wr_row_offset)) | wr_tail_mask;
            end
        end
    end

    assign m_axi_awsize  = 3'(AXI_SIZE_VALUE);
    assign m_axi_awburst = 2'b01; // INCR
    assign m_axi_wdata   = wr_aligned_wdata;
    assign m_axi_wstrb   = wr_aligned_wstrb;
    assign m_axi_wvalid  = wr_active && wr_data_active &&
                           (wr_need_src_beat ? src_wvalid : 1'b1);
    assign m_axi_wlast   = (wr_beat_cnt == wr_aligned_last_beat);
    assign m_axi_bready  = wr_active;
    assign src_wready    = wr_active && wr_data_active &&
                           wr_need_src_beat && m_axi_wready;

    wire last_wr_b = wr_b_hs && (wr_resp_row_cnt == wr_cfg_rows - 1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_done_r <= 1'b0;
        end else begin
            wr_done_r <= wr_active && last_wr_b;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_active           <= 1'b0;
            wr_cfg_base_addr    <= '0;
            wr_cfg_row_stride   <= '0;
            wr_cfg_rows         <= '0;
            wr_cfg_burst_len_m1 <= '0;
            wr_error_r          <= 1'b0;
        end else if (wr_start && !wr_active) begin
            wr_active           <= 1'b1;
            wr_cfg_base_addr    <= wr_base_addr;
            wr_cfg_row_stride   <= wr_row_stride;
            wr_cfg_rows         <= wr_rows_to_write;
            wr_cfg_burst_len_m1 <= wr_burst_len_m1;
            wr_error_r          <= 1'b0;
        end else begin
            if (wr_b_hs && m_axi_bresp[1]) wr_error_r <= 1'b1;
            if (wr_done_r) wr_active <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_awvalid <= 1'b0;
            m_axi_awaddr  <= '0;
            m_axi_awlen   <= '0;
            wr_cmd_row_cnt <= '0;
            wr_data_row_cnt <= '0;
            wr_resp_row_cnt <= '0;
            wr_beat_cnt   <= '0;
            wr_tail_data   <= '0;
            wr_tail_mask   <= '0;
            wr_data_active <= 1'b0;
            wr_outstanding_cnt <= '0;
            wr_pending_cmd_cross <= 1'b0;
        end else if (wr_start && !wr_active) begin
            m_axi_awvalid <= 1'b0;
            m_axi_awaddr  <= wr_base_addr;
            m_axi_awlen   <= 8'(wr_burst_len_m1);
            wr_cmd_row_cnt <= '0;
            wr_data_row_cnt <= '0;
            wr_resp_row_cnt <= '0;
            wr_beat_cnt   <= '0;
            wr_tail_data   <= '0;
            wr_tail_mask   <= '0;
            wr_data_active <= 1'b0;
            wr_outstanding_cnt <= '0;
            wr_pending_cmd_cross <= 1'b0;
        end else if (wr_active) begin
            if (wr_done_r) begin
                m_axi_awvalid <= 1'b0;
                wr_data_active <= 1'b0;
                wr_outstanding_cnt <= '0;
                wr_pending_cmd_cross <= 1'b0;
            end else begin
                if (wr_aw_hs) begin
                    m_axi_awvalid <= 1'b0;
                    wr_cmd_row_cnt <= wr_cmd_row_cnt + 1'b1;
                    wr_pending_cmd_cross <= 1'b0;
                end else if (!m_axi_awvalid && wr_can_issue_aw) begin
                    m_axi_awvalid <= 1'b1;
                    m_axi_awaddr  <= align_down(wr_cmd_row_addr_cur);
                    m_axi_awlen   <= 8'(wr_cfg_burst_len_m1)
                                   + ((wr_cmd_row_offset != '0) ? 8'd1 : 8'd0);
                    wr_pending_cmd_cross <= (wr_cmd_row_offset != '0);
                end

                unique case ({wr_aw_hs, wr_b_hs})
                    2'b10: wr_outstanding_cnt <= wr_outstanding_cnt + 1'b1;
                    2'b01: wr_outstanding_cnt <= wr_outstanding_cnt - 1'b1;
                    default: wr_outstanding_cnt <= wr_outstanding_cnt;
                endcase

                if (wr_can_start_data) begin
                    wr_data_active <= 1'b1;
                    wr_beat_cnt   <= '0;
                    wr_tail_data   <= '0;
                    wr_tail_mask   <= '0;
                end

                if (wr_w_hs) begin
                    if (wr_need_src_beat && wr_row_cross) begin
                        wr_tail_data <= src_wdata >> ((BYTE_PER_BEAT - int'(wr_row_offset)) * 8);
                        wr_tail_mask <= src_wmask >> (BYTE_PER_BEAT - int'(wr_row_offset));
                    end
                    if (wr_beat_cnt == wr_aligned_last_beat) begin
                        wr_beat_cnt   <= '0;
                        wr_data_active <= 1'b0;
                        wr_data_row_cnt <= wr_data_row_cnt + 1'b1;
                        wr_tail_data   <= '0;
                        wr_tail_mask   <= '0;
                    end else begin
                        wr_beat_cnt <= wr_beat_cnt + 1'b1;
                    end
                end

                if (wr_b_hs) begin
                    if (wr_resp_row_cnt < wr_cfg_rows) wr_resp_row_cnt <= wr_resp_row_cnt + 1'b1;
                end
            end
        end else begin
            m_axi_awvalid <= 1'b0;
            wr_cmd_row_cnt <= '0;
            wr_data_row_cnt <= '0;
            wr_resp_row_cnt <= '0;
            wr_beat_cnt   <= '0;
            wr_tail_data   <= '0;
            wr_tail_mask   <= '0;
            wr_data_active <= 1'b0;
            wr_outstanding_cnt <= '0;
            wr_pending_cmd_cross <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_trace_aw_count       <= '0;
            wr_trace_cross_aw_count <= '0;
            wr_trace_w_count        <= '0;
            wr_trace_max_outs       <= '0;
        end else if (wr_start && !wr_active) begin
            wr_trace_aw_count       <= '0;
            wr_trace_cross_aw_count <= '0;
            wr_trace_w_count        <= '0;
            wr_trace_max_outs       <= '0;
        end else if (wr_active) begin
            if (wr_aw_hs) begin
                wr_trace_aw_count <= wr_trace_aw_count + 1'b1;
                if (wr_pending_cmd_cross) wr_trace_cross_aw_count <= wr_trace_cross_aw_count + 1'b1;
                if (!wr_b_hs && ((wr_outstanding_cnt + 1'b1) > wr_trace_max_outs)) begin
                    wr_trace_max_outs <= wr_outstanding_cnt + 1'b1;
                end else if (wr_b_hs && (wr_outstanding_cnt > wr_trace_max_outs)) begin
                    wr_trace_max_outs <= wr_outstanding_cnt;
                end
            end
            if (wr_w_hs) begin
                wr_trace_w_count <= wr_trace_w_count + 1'b1;
            end
            if (wr_done_r && dma_trace_en) begin
                $display("[AXI_DMA_TRACE] wr_done base=%08x stride=%0d rows=%0d len_m1=%0d aw=%0d aw_cross=%0d w=%0d max_out=%0d",
                         wr_cfg_base_addr, wr_cfg_row_stride, wr_cfg_rows,
                         wr_cfg_burst_len_m1, wr_trace_aw_count,
                         wr_trace_cross_aw_count, wr_trace_w_count,
                         wr_trace_max_outs);
            end
        end
    end

endmodule
