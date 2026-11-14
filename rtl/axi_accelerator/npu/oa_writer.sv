module oa_writer #(
    parameter int unsigned VLEN       = 16,
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned REG_WIDTH  = 32,
    parameter int unsigned BUS_WIDTH  = 32,
    parameter int unsigned COUNT_WIDTH = REG_WIDTH,
    parameter int unsigned ENABLE_IS_MODE = 1
) (
    input logic clk,
    input logic rst_n,

    input  logic init_cfg,
    output logic write_oa_req,
    input  logic write_oa_granted,

    input logic [REG_WIDTH-1:0] dst_base,
    input logic [REG_WIDTH-1:0] dst_row_stride_b,
    input logic [REG_WIDTH-1:0] k,
    input logic [REG_WIDTH-1:0] m,
    input logic [REG_WIDTH-1:0] ia_reuse_num,
    input logic                 is_mode,
    input logic                 output_16bits,

    input  logic                    oa_fifo_req,
    output logic [$clog2(VLEN)-1:0] vec_valid_num_col,
    output logic [$clog2(VLEN)-1:0] vec_valid_num_row,

    input  logic                   output_valid,
    input  logic                   switch_row,
    output logic                   output_ready,
    input  logic [BUS_WIDTH/8-1:0] output_mask,
    input  logic [BUS_WIDTH-1:0]   output_data,

    output logic                        dma_start,
    output logic                        dma_is_write,
    output logic                        dma_linear_read_mode,
    output logic [REG_WIDTH-1:0]        dma_base_addr,
    output logic [REG_WIDTH-1:0]        dma_row_stride,
    output logic [REG_WIDTH-1:0]        dma_rows_to_read,
    output logic [7:0]                  dma_burst_len_m1,
    output logic                        dma_slot_id,
    output logic                        dma_use_16bits,
    output logic signed [REG_WIDTH-1:0] dma_lhs_zp,
    output logic [BUS_WIDTH-1:0]        dma_src_wdata,
    output logic [BUS_WIDTH/8-1:0]      dma_src_wmask,
    output logic                        dma_src_wvalid,
    input  logic                        dma_src_wready,
    input  logic                        dma_busy,
    input  logic                        dma_done,

    output logic write_done,
    output logic oa_calc_over
);

    localparam int unsigned BYTE_PER_BEAT = BUS_WIDTH / 8;
    localparam int unsigned VCOL_W = $clog2(VLEN);
    localparam int unsigned LOG2_BPB = $clog2(BYTE_PER_BEAT);
    localparam logic [VCOL_W:0] VLEN_COUNT = (VCOL_W + 1)'(VLEN);
    localparam int unsigned CNT_W = (COUNT_WIDTH < 1) ? 1 : COUNT_WIDTH;
    typedef logic [CNT_W-1:0] count_t;

    typedef enum logic [2:0] {
        S_IDLE,
        S_REQ,
        S_START,
        S_WRITE,
        S_DONE
    } state_t;

    (* fsm_encoding = "sequential" *) state_t state;

    logic [REG_WIDTH-1:0] cfg_dst_base;
    logic [REG_WIDTH-1:0] cfg_dst_row_stride_b;
    logic [REG_WIDTH-1:0] cfg_k;
    logic [REG_WIDTH-1:0] cfg_m;
    count_t               cfg_ia_reuse_num;
    logic                 cfg_has_tiles;
    logic                 cfg_is_mode;
    logic                 cfg_output_16bits;
    logic                 cfg_lat_tick;
    count_t               row_tiles_total;
    count_t               col_tiles_total;
    count_t               row_tiles_last_idx;
    count_t               col_tiles_last_idx;
    logic [VCOL_W:0]      k_last_valid;
    logic [VCOL_W:0]      m_last_valid;

    count_t               tiles_done;
    count_t               tile_row_idx;
    count_t               tile_col_idx;
    count_t               row_group_base_idx;
    count_t               row_group_next_base_idx;
    logic [VCOL_W-1:0]    vec_valid_num_col_r;
    logic [VCOL_W-1:0]    vec_valid_num_row_r;
    logic [VCOL_W:0]      rows_valid_cur_tile;
    logic [VCOL_W:0]      cols_valid_cur_tile;
    logic [VCOL_W:0]      beats_per_row_cur_tile;
    logic [REG_WIDTH-1:0] tile_base_addr_cur;
    logic [REG_WIDTH-1:0] row_addr_step_cur;
    logic [REG_WIDTH-1:0] col_addr_step_cur;
    logic [REG_WIDTH-1:0] group_row_addr_step_cur;
    logic [REG_WIDTH-1:0] row_group_base_addr_cur;
    logic [REG_WIDTH-1:0] col_offset_addr_cur;
    logic [REG_WIDTH-1:0] row_offset_addr_cur;
    logic                 tile_row_is_last;
    logic                 tile_col_is_last;
    logic                 dma_done_q;
    logic [VCOL_W-1:0]    row_in_tile;
    logic [VCOL_W:0]      beats_in_row;
    logic [VCOL_W:0]      beats_per_row;
    logic                 has_grant;
    logic                 cmd_pending;
    logic                 cmd_inflight;
    logic                 rsp_inflight;
    logic                 tile_done_pending;
    logic                 writer_ready_cond;
    logic                 cmd_fire;
    logic                 beat_fire;
    logic                 rsp_fire;
    logic                 oa_calc_over_r;
`ifndef SYNTHESIS
    bit                   oa_trace_en;

    initial begin
        oa_trace_en = 1'b0;
        if ($test$plusargs("NPU_OA_TRACE")) oa_trace_en = 1'b1;
    end
`else
    localparam bit oa_trace_en = 1'b0;
`endif

    wire is_mode_eff = (ENABLE_IS_MODE != 0) ? is_mode : 1'b0;

    assign vec_valid_num_col = vec_valid_num_col_r;
    assign vec_valid_num_row = vec_valid_num_row_r;

    wire [REG_WIDTH-1:0] k_tiles_pre_w = (k == '0) ? '0 : ((k + REG_WIDTH'(VLEN - 1)) >> VCOL_W);
    wire [REG_WIDTH-1:0] m_tiles_pre_w = (m == '0) ? '0 : ((m + REG_WIDTH'(VLEN - 1)) >> VCOL_W);
    wire count_t k_tiles_pre = count_t'(k_tiles_pre_w);
    wire count_t m_tiles_pre = count_t'(m_tiles_pre_w);
    wire [VCOL_W-1:0]    k_tail_pre  = k[VCOL_W-1:0];
    wire [VCOL_W-1:0]    m_tail_pre  = m[VCOL_W-1:0];
    wire [VCOL_W:0]      k_last_valid_pre =
        (k == '0) ? '0 : ((k_tail_pre == '0) ? VLEN_COUNT : {1'b0, k_tail_pre});
    wire [VCOL_W:0]      m_last_valid_pre =
        (m == '0) ? '0 : ((m_tail_pre == '0) ? VLEN_COUNT : {1'b0, m_tail_pre});
    wire count_t row_tiles_total_pre = is_mode_eff ? m_tiles_pre : k_tiles_pre;
    wire count_t col_tiles_total_pre = is_mode_eff ? k_tiles_pre : m_tiles_pre;

    count_t tile_row_inc;
    count_t tile_col_inc;
    count_t reuse_group_base_cur;
    count_t reuse_group_next_base_cur;
    count_t next_tile_row_cur;
    count_t next_tile_col_cur;
    logic                 next_tile_row_is_last_cur;
    logic                 next_tile_col_is_last_cur;
    logic                 next_tile_wrap_cur;
    logic                 next_tile_row_advance_cur;
    logic                 next_tile_col_advance_cur;
    logic                 next_tile_group_advance_cur;
    count_t next_tile_row_r;
    count_t next_tile_col_r;
    logic                 next_tile_row_is_last_r;
    logic                 next_tile_col_is_last_r;
    logic                 next_tile_wrap_r;
    logic                 next_tile_row_advance_r;
    logic                 next_tile_col_advance_r;
    logic                 next_tile_group_advance_r;
    logic [VCOL_W-1:0]    vec_valid_num_col_next_r;
    logic [VCOL_W-1:0]    vec_valid_num_row_next_r;
    logic [VCOL_W:0]      rows_valid_calc;
    logic [VCOL_W:0]      cols_valid_calc;
    logic [VCOL_W:0]      rows_valid_next_calc;
    logic [VCOL_W:0]      cols_valid_next_calc;
    logic [VCOL_W:0]      beats_per_row_calc;
    logic [VCOL_W:0]      vec_valid_num_col_next_w;
    logic [VCOL_W:0]      vec_valid_num_row_next_w;
    count_t               init_reuse_num_eff;
    logic [REG_WIDTH-1:0] init_tile_linear_step;
    logic [REG_WIDTH-1:0] init_tile_stride_step;
    logic [REG_WIDTH-1:0] init_row_addr_step;
    logic [REG_WIDTH-1:0] init_col_addr_step;
    logic [REG_WIDTH-1:0] init_group_row_addr_step;

    always_comb begin
        init_reuse_num_eff = (ia_reuse_num == '0) ? count_t'(1) : count_t'(ia_reuse_num);
        init_tile_linear_step = REG_WIDTH'(VLEN) << (output_16bits ? 1 : 0);
        init_tile_stride_step = dst_row_stride_b << VCOL_W;
        init_row_addr_step = is_mode_eff ? init_tile_linear_step : init_tile_stride_step;
        init_col_addr_step = is_mode_eff ? init_tile_stride_step : init_tile_linear_step;
        unique case (init_reuse_num_eff)
            count_t'(1):  init_group_row_addr_step = init_row_addr_step;
            count_t'(2):  init_group_row_addr_step = init_row_addr_step << 1;
            count_t'(4):  init_group_row_addr_step = init_row_addr_step << 2;
            count_t'(8):  init_group_row_addr_step = init_row_addr_step << 3;
            count_t'(16): init_group_row_addr_step = init_row_addr_step << 4;
            count_t'(25): init_group_row_addr_step = (init_row_addr_step << 4) + (init_row_addr_step << 3) + init_row_addr_step;
            count_t'(32): init_group_row_addr_step = init_row_addr_step << 5;
            count_t'(64): init_group_row_addr_step = init_row_addr_step << 6;
            default:        init_group_row_addr_step = init_row_addr_step;
        endcase

        tile_row_inc = tile_row_idx + count_t'(1);
        tile_col_inc = tile_col_idx + count_t'(1);
        reuse_group_base_cur = row_group_base_idx;
        reuse_group_next_base_cur = row_group_next_base_idx;
        next_tile_row_is_last_cur = (row_tiles_last_idx == '0);
        next_tile_col_is_last_cur = (col_tiles_last_idx == '0);
        next_tile_wrap_cur = 1'b0;
        next_tile_row_advance_cur = 1'b0;
        next_tile_col_advance_cur = 1'b0;
        next_tile_group_advance_cur = 1'b0;

        if ((tile_row_inc < row_tiles_total) && (tile_row_inc < reuse_group_next_base_cur)) begin
            next_tile_row_cur = tile_row_inc;
            next_tile_col_cur = tile_col_idx;
            next_tile_row_is_last_cur = (tile_row_inc == row_tiles_last_idx);
            next_tile_col_is_last_cur = tile_col_is_last;
            next_tile_row_advance_cur = 1'b1;
        end else if (tile_col_inc < col_tiles_total) begin
            next_tile_row_cur = reuse_group_base_cur;
            next_tile_col_cur = tile_col_inc;
            next_tile_row_is_last_cur = (reuse_group_base_cur == row_tiles_last_idx);
            next_tile_col_is_last_cur = (tile_col_inc == col_tiles_last_idx);
            next_tile_col_advance_cur = 1'b1;
        end else if (reuse_group_next_base_cur < row_tiles_total) begin
            next_tile_row_cur = reuse_group_next_base_cur;
            next_tile_col_cur = '0;
            next_tile_row_is_last_cur = (reuse_group_next_base_cur == row_tiles_last_idx);
            next_tile_col_is_last_cur = (col_tiles_last_idx == '0);
            next_tile_group_advance_cur = 1'b1;
        end else begin
            next_tile_row_cur = '0;
            next_tile_col_cur = '0;
            next_tile_wrap_cur = 1'b1;
        end

        rows_valid_calc = cfg_is_mode
                        ? (tile_col_is_last ? k_last_valid : VLEN_COUNT)
                        : (tile_row_is_last ? k_last_valid : VLEN_COUNT);
        cols_valid_calc = cfg_is_mode
                        ? (tile_row_is_last ? m_last_valid : VLEN_COUNT)
                        : (tile_col_is_last ? m_last_valid : VLEN_COUNT);
        rows_valid_next_calc = cfg_is_mode
                             ? (next_tile_col_is_last_cur ? k_last_valid : VLEN_COUNT)
                             : (next_tile_row_is_last_cur ? k_last_valid : VLEN_COUNT);
        cols_valid_next_calc = cfg_is_mode
                             ? (next_tile_row_is_last_cur ? m_last_valid : VLEN_COUNT)
                             : (next_tile_col_is_last_cur ? m_last_valid : VLEN_COUNT);
        if (cfg_output_16bits) begin
            beats_per_row_calc = (cols_valid_calc + (VCOL_W + 1)'(1)) >> 1;
        end else begin
            beats_per_row_calc = (cols_valid_calc + (VCOL_W + 1)'(BYTE_PER_BEAT - 1)) >> LOG2_BPB;
        end
        vec_valid_num_col_next_w = (cols_valid_next_calc == '0) ? '0 : (cols_valid_next_calc - 1'b1);
        vec_valid_num_row_next_w = (rows_valid_next_calc == '0) ? '0 : (rows_valid_next_calc - 1'b1);
    end

    assign write_oa_req = (state == S_REQ) || (state == S_START);
    assign writer_ready_cond = (state == S_WRITE) && dma_src_wready;
    assign output_ready = writer_ready_cond;
    assign dma_src_wvalid = (state == S_WRITE) && output_valid;
    assign dma_src_wdata = output_data;
    assign dma_src_wmask = output_mask;

    assign dma_start = (state == S_START) && write_oa_granted;
    assign dma_is_write = 1'b1;
    assign dma_linear_read_mode = 1'b0;
    assign dma_base_addr = tile_base_addr_cur;
    assign dma_row_stride = cfg_dst_row_stride_b;
    assign dma_rows_to_read = REG_WIDTH'(rows_valid_cur_tile);
    assign dma_burst_len_m1 = (beats_per_row_cur_tile == '0) ? 8'd0 : 8'(beats_per_row_cur_tile - 1'b1);
    assign dma_slot_id = 1'b0;
    assign dma_use_16bits = cfg_output_16bits;
    assign dma_lhs_zp = '0;

    assign write_done = (state == S_WRITE) && dma_done && !dma_done_q;
    assign oa_calc_over = oa_calc_over_r;
    assign beat_fire = output_valid && output_ready;
    assign cmd_fire = dma_start;
    assign rsp_fire = write_done;
    assign has_grant = write_oa_granted;
    assign cmd_pending = (state == S_REQ) || (state == S_START);
    assign cmd_inflight = dma_busy;
    assign rsp_inflight = (state == S_WRITE) && dma_busy;
    assign tile_done_pending = write_done;
    assign beats_per_row = beats_per_row_cur_tile;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cfg_dst_base <= '0;
            cfg_dst_row_stride_b <= '0;
            cfg_k <= '0;
            cfg_m <= '0;
            cfg_ia_reuse_num <= count_t'(1);
            cfg_has_tiles <= 1'b0;
            cfg_is_mode <= 1'b0;
            cfg_output_16bits <= 1'b0;
            cfg_lat_tick <= 1'b0;
            row_tiles_total <= '0;
            col_tiles_total <= '0;
            row_tiles_last_idx <= '0;
            col_tiles_last_idx <= '0;
            k_last_valid <= '0;
            m_last_valid <= '0;
        end else if (init_cfg) begin
            cfg_dst_base <= dst_base;
            cfg_dst_row_stride_b <= dst_row_stride_b;
            cfg_k <= k;
            cfg_m <= m;
            cfg_ia_reuse_num <= (ia_reuse_num == '0) ? count_t'(1) : count_t'(ia_reuse_num);
            cfg_has_tiles <= (k != '0) && (m != '0);
            cfg_is_mode <= is_mode_eff;
            cfg_output_16bits <= output_16bits;
            cfg_lat_tick <= 1'b1;
            row_tiles_total <= row_tiles_total_pre;
            col_tiles_total <= col_tiles_total_pre;
            row_tiles_last_idx <= '0;
            col_tiles_last_idx <= '0;
            k_last_valid <= k_last_valid_pre;
            m_last_valid <= m_last_valid_pre;
        end else if (cfg_lat_tick) begin
            cfg_lat_tick <= 1'b0;
            row_tiles_last_idx <= (row_tiles_total == '0) ? '0 : (row_tiles_total - count_t'(1));
            col_tiles_last_idx <= (col_tiles_total == '0) ? '0 : (col_tiles_total - count_t'(1));
        end else begin
            cfg_lat_tick <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            tiles_done <= '0;
            tile_row_idx <= '0;
            tile_col_idx <= '0;
            row_group_base_idx <= '0;
                row_group_next_base_idx <= count_t'(1);
            vec_valid_num_col_r <= '0;
            vec_valid_num_row_r <= '0;
            rows_valid_cur_tile <= '0;
            cols_valid_cur_tile <= '0;
            beats_per_row_cur_tile <= '0;
            tile_base_addr_cur <= '0;
            row_addr_step_cur <= '0;
            col_addr_step_cur <= '0;
            group_row_addr_step_cur <= '0;
            row_group_base_addr_cur <= '0;
            col_offset_addr_cur <= '0;
            row_offset_addr_cur <= '0;
            tile_row_is_last <= 1'b1;
            tile_col_is_last <= 1'b1;
            next_tile_row_r <= '0;
            next_tile_col_r <= '0;
            next_tile_row_is_last_r <= 1'b1;
            next_tile_col_is_last_r <= 1'b1;
            next_tile_wrap_r <= 1'b1;
            next_tile_row_advance_r <= 1'b0;
            next_tile_col_advance_r <= 1'b0;
            next_tile_group_advance_r <= 1'b0;
            vec_valid_num_col_next_r <= '0;
            vec_valid_num_row_next_r <= '0;
            dma_done_q <= 1'b0;
            row_in_tile <= '0;
            beats_in_row <= '0;
            oa_calc_over_r <= 1'b0;
        end else begin
            dma_done_q <= dma_done;
            oa_calc_over_r <= 1'b0;

            if (init_cfg) begin
                state <= S_IDLE;
                tiles_done <= '0;
                tile_row_idx <= '0;
                tile_col_idx <= '0;
                row_group_base_idx <= '0;
                row_group_next_base_idx <= init_reuse_num_eff;
                vec_valid_num_col_r <= '0;
                vec_valid_num_row_r <= '0;
                rows_valid_cur_tile <= '0;
                cols_valid_cur_tile <= '0;
                beats_per_row_cur_tile <= '0;
                tile_base_addr_cur <= dst_base;
                row_addr_step_cur <= init_row_addr_step;
                col_addr_step_cur <= init_col_addr_step;
                group_row_addr_step_cur <= init_group_row_addr_step;
                row_group_base_addr_cur <= dst_base;
                col_offset_addr_cur <= '0;
                row_offset_addr_cur <= '0;
                tile_row_is_last <= (row_tiles_total_pre <= count_t'(1));
                tile_col_is_last <= (col_tiles_total_pre <= count_t'(1));
                next_tile_row_r <= '0;
                next_tile_col_r <= '0;
                next_tile_row_is_last_r <= 1'b1;
                next_tile_col_is_last_r <= 1'b1;
                next_tile_wrap_r <= 1'b1;
                next_tile_row_advance_r <= 1'b0;
                next_tile_col_advance_r <= 1'b0;
                next_tile_group_advance_r <= 1'b0;
                vec_valid_num_col_next_r <= '0;
                vec_valid_num_row_next_r <= '0;
                row_in_tile <= '0;
                beats_in_row <= '0;
                oa_calc_over_r <= 1'b0;
            end else begin
                case (state)
                    S_IDLE: begin
                        if (cfg_lat_tick) begin
                            vec_valid_num_col_r <= (cols_valid_calc == '0) ? '0 : VCOL_W'(cols_valid_calc - 1'b1);
                            vec_valid_num_row_r <= (rows_valid_calc == '0) ? '0 : VCOL_W'(rows_valid_calc - 1'b1);
                        end
                        if (cfg_has_tiles && (oa_fifo_req || output_valid)) begin
                            state <= S_REQ;
                        end
                    end

                    S_REQ: begin
                        if (write_oa_granted) begin
                            rows_valid_cur_tile <= rows_valid_calc;
                            cols_valid_cur_tile <= cols_valid_calc;
                            beats_per_row_cur_tile <= beats_per_row_calc;
                            next_tile_row_r <= next_tile_row_cur;
                            next_tile_col_r <= next_tile_col_cur;
                            next_tile_row_is_last_r <= next_tile_row_is_last_cur;
                            next_tile_col_is_last_r <= next_tile_col_is_last_cur;
                            next_tile_wrap_r <= next_tile_wrap_cur;
                            next_tile_row_advance_r <= next_tile_row_advance_cur;
                            next_tile_col_advance_r <= next_tile_col_advance_cur;
                            next_tile_group_advance_r <= next_tile_group_advance_cur;
                            vec_valid_num_col_next_r <= vec_valid_num_col_next_w[VCOL_W-1:0];
                            vec_valid_num_row_next_r <= vec_valid_num_row_next_w[VCOL_W-1:0];
                            row_in_tile <= '0;
                            beats_in_row <= '0;
                            if (oa_trace_en) begin
                                $display("[OA_TRACE] time=%0t writer_req tile=(%0d,%0d) rows=%0d cols=%0d beats=%0d base=%08x",
                                         $time, tile_row_idx, tile_col_idx,
                                         rows_valid_calc,
                                         cols_valid_calc,
                                         beats_per_row_calc,
                                         tile_base_addr_cur);
                            end
                            state <= S_START;
                        end
                    end

                    S_START: begin
                        if (dma_start) begin
                            if (oa_trace_en) begin
                                $display("[OA_TRACE] time=%0t writer_start rows=%0d beats=%0d",
                                         $time, rows_valid_cur_tile, beats_per_row_cur_tile);
                            end
                            state <= S_WRITE;
                        end
                    end

                    S_WRITE: begin
                        if (beat_fire) begin
                            if (oa_trace_en) begin
                                $display("[OA_TRACE] time=%0t writer_beat row=%0d beat=%0d data=%08x mask=%b",
                                         $time, row_in_tile, beats_in_row,
                                         output_data, output_mask);
                            end
                            if ((beats_in_row + 1'b1) >= beats_per_row_cur_tile) begin
                                beats_in_row <= '0;
                                if (((VCOL_W + 1)'(row_in_tile) + (VCOL_W + 1)'(1)) < rows_valid_cur_tile) begin
                                    row_in_tile <= row_in_tile + 1'b1;
                                end
                            end else begin
                                beats_in_row <= beats_in_row + 1'b1;
                            end
                        end
                        if (write_done) begin
                            tiles_done <= tiles_done + 1'b1;

                            if (next_tile_wrap_r) begin
                                oa_calc_over_r <= 1'b1;
                                state <= S_DONE;
                                tile_row_idx <= '0;
                                tile_col_idx <= '0;
                                row_group_base_idx <= '0;
                                row_group_next_base_idx <= cfg_ia_reuse_num;
                                tile_base_addr_cur <= cfg_dst_base;
                                row_group_base_addr_cur <= cfg_dst_base;
                                col_offset_addr_cur <= '0;
                                row_offset_addr_cur <= '0;
                                tile_row_is_last <= (row_tiles_last_idx == '0);
                                tile_col_is_last <= (col_tiles_last_idx == '0);
                                if (oa_trace_en) begin
                                    $display("[OA_TRACE] time=%0t writer_done final tiles=%0d",
                                             $time, tiles_done + count_t'(1));
                                end
                            end else begin
                                tile_row_idx <= next_tile_row_r;
                                tile_col_idx <= next_tile_col_r;
                                tile_row_is_last <= next_tile_row_is_last_r;
                                tile_col_is_last <= next_tile_col_is_last_r;
                                vec_valid_num_col_r <= vec_valid_num_col_next_r;
                                vec_valid_num_row_r <= vec_valid_num_row_next_r;
                                if (next_tile_row_advance_r) begin
                                    row_offset_addr_cur <= row_offset_addr_cur + row_addr_step_cur;
                                    tile_base_addr_cur <= tile_base_addr_cur + row_addr_step_cur;
                                end else if (next_tile_col_advance_r) begin
                                    col_offset_addr_cur <= col_offset_addr_cur + col_addr_step_cur;
                                    row_offset_addr_cur <= '0;
                                    tile_base_addr_cur <= row_group_base_addr_cur +
                                                          col_offset_addr_cur +
                                                          col_addr_step_cur;
                                end else if (next_tile_group_advance_r) begin
                                    row_group_base_idx <= row_group_next_base_idx;
                                    row_group_next_base_idx <= row_group_next_base_idx +
                                                               cfg_ia_reuse_num;
                                    row_group_base_addr_cur <= row_group_base_addr_cur +
                                                               group_row_addr_step_cur;
                                    col_offset_addr_cur <= '0;
                                    row_offset_addr_cur <= '0;
                                    tile_base_addr_cur <= row_group_base_addr_cur +
                                                          group_row_addr_step_cur;
                                end
                                state <= S_IDLE;
                                if (oa_trace_en) begin
                                    $display("[OA_TRACE] time=%0t writer_done next=(%0d,%0d) tiles=%0d",
                                             $time, next_tile_row_r, next_tile_col_r, tiles_done + count_t'(1));
                                end
                            end
                        end
                    end

                    S_DONE: begin
                        state <= S_DONE;
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule
