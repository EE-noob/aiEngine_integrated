module oa_writer #(
    parameter int unsigned VLEN       = 16,
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned REG_WIDTH  = 32,
    parameter int unsigned BUS_WIDTH  = 32
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
    output logic [3:0]                  dma_burst_len_m1,
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

    typedef enum logic [2:0] {
        S_IDLE,
        S_REQ,
        S_START,
        S_WRITE,
        S_DONE
    } state_t;

    state_t state;

    logic [REG_WIDTH-1:0] cfg_dst_base;
    logic [REG_WIDTH-1:0] cfg_dst_row_stride_b;
    logic [REG_WIDTH-1:0] cfg_k;
    logic [REG_WIDTH-1:0] cfg_m;
    logic [REG_WIDTH-1:0] cfg_ia_reuse_num;
    logic [REG_WIDTH-1:0] cfg_tile_count;
    logic                 cfg_is_mode;
    logic                 cfg_lat_tick;

    logic [REG_WIDTH-1:0] tiles_done;
    logic [REG_WIDTH-1:0] tile_row_idx;
    logic [REG_WIDTH-1:0] tile_col_idx;
    logic [VCOL_W-1:0]    vec_valid_num_col_r;
    logic [VCOL_W-1:0]    vec_valid_num_row_r;
    logic [VCOL_W:0]      rows_valid_cur_tile;
    logic [VCOL_W:0]      cols_valid_cur_tile;
    logic [VCOL_W:0]      beats_per_row_cur_tile;
    logic [REG_WIDTH-1:0] tile_base_addr_cur;
    logic                 dma_done_q;
    logic [VCOL_W-1:0]    row_in_tile;
    logic [VCOL_W:0]      beats_in_row;
    logic [VCOL_W:0]      beats_per_row;
    logic [REG_WIDTH-1:0] cur_addr;
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

    assign vec_valid_num_col = vec_valid_num_col_r;
    assign vec_valid_num_row = vec_valid_num_row_r;

    function automatic [REG_WIDTH-1:0] ceil_div_vlen(input [REG_WIDTH-1:0] val);
        ceil_div_vlen = (val == '0) ? '0 : ((val + REG_WIDTH'(VLEN - 1)) >> VCOL_W);
    endfunction

    function automatic [VCOL_W:0] min_vlen(input [REG_WIDTH-1:0] val);
        if (val >= REG_WIDTH'(VLEN)) min_vlen = (VCOL_W + 1)'(VLEN);
        else                         min_vlen = val[VCOL_W:0];
    endfunction

    function automatic [REG_WIDTH-1:0] rem_after_tiles(
        input [REG_WIDTH-1:0] total,
        input [REG_WIDTH-1:0] tile_idx
    );
        logic [REG_WIDTH-1:0] consumed;
        begin
            consumed = tile_idx << VCOL_W;
            rem_after_tiles = (total > consumed) ? (total - consumed) : '0;
        end
    endfunction

    function automatic [REG_WIDTH-1:0] stream_k_total();
        stream_k_total = cfg_is_mode ? cfg_m : cfg_k;
    endfunction

    function automatic [REG_WIDTH-1:0] stream_m_total();
        stream_m_total = cfg_is_mode ? cfg_k : cfg_m;
    endfunction

    function automatic [VCOL_W:0] rows_valid_for_tile(
        input [REG_WIDTH-1:0] row_idx,
        input [REG_WIDTH-1:0] col_idx
    );
        if (cfg_is_mode) rows_valid_for_tile = min_vlen(rem_after_tiles(cfg_k, col_idx));
        else             rows_valid_for_tile = min_vlen(rem_after_tiles(cfg_k, row_idx));
    endfunction

    function automatic [VCOL_W:0] cols_valid_for_tile(
        input [REG_WIDTH-1:0] row_idx,
        input [REG_WIDTH-1:0] col_idx
    );
        if (cfg_is_mode) cols_valid_for_tile = min_vlen(rem_after_tiles(cfg_m, row_idx));
        else             cols_valid_for_tile = min_vlen(rem_after_tiles(cfg_m, col_idx));
    endfunction

    function automatic [REG_WIDTH-1:0] tile_addr_for_idx(
        input [REG_WIDTH-1:0] row_idx,
        input [REG_WIDTH-1:0] col_idx
    );
        if (cfg_is_mode) begin
            tile_addr_for_idx = cfg_dst_base
                              + ((col_idx << VCOL_W) * cfg_dst_row_stride_b)
                              +  (row_idx << VCOL_W);
        end else begin
            tile_addr_for_idx = cfg_dst_base
                              + ((row_idx << VCOL_W) * cfg_dst_row_stride_b)
                              +  (col_idx << VCOL_W);
        end
    endfunction

    function automatic [VCOL_W:0] beats_for_cols(input [VCOL_W:0] cols);
        beats_for_cols = (cols + BYTE_PER_BEAT - 1) / BYTE_PER_BEAT;
    endfunction

    function automatic [VCOL_W-1:0] valid_m1(input [VCOL_W:0] valid_cnt);
        valid_m1 = (valid_cnt == '0) ? '0 : (valid_cnt - 1'b1);
    endfunction

    task automatic calc_next_tile(
        input  [REG_WIDTH-1:0] cur_row,
        input  [REG_WIDTH-1:0] cur_col,
        input  [REG_WIDTH-1:0] row_tiles_total,
        input  [REG_WIDTH-1:0] col_tiles_total,
        output [REG_WIDTH-1:0] next_row,
        output [REG_WIDTH-1:0] next_col
    );
        logic [REG_WIDTH-1:0] reuse_num;
        logic [REG_WIDTH-1:0] group_base;
        logic [REG_WIDTH-1:0] group_next_base;
        begin
            reuse_num = (cfg_ia_reuse_num == '0) ? REG_WIDTH'(1) : cfg_ia_reuse_num;
            group_base = (cur_row / reuse_num) * reuse_num;
            group_next_base = group_base + reuse_num;

            if (((cur_row + 1) < row_tiles_total) && ((cur_row + 1) < group_next_base)) begin
                next_row = cur_row + 1;
                next_col = cur_col;
            end else if ((cur_col + 1) < col_tiles_total) begin
                next_row = group_base;
                next_col = cur_col + 1;
            end else if (group_next_base < row_tiles_total) begin
                next_row = group_next_base;
                next_col = '0;
            end else begin
                next_row = '0;
                next_col = '0;
            end
        end
    endtask

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
    assign dma_burst_len_m1 = (beats_per_row_cur_tile == '0) ? 4'd0 : 4'(beats_per_row_cur_tile - 1'b1);
    assign dma_slot_id = 1'b0;
    assign dma_use_16bits = 1'b0;
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
    assign cur_addr = tile_base_addr_cur
                    + (REG_WIDTH'(row_in_tile) * cfg_dst_row_stride_b)
                    + (REG_WIDTH'(beats_in_row) * REG_WIDTH'(BYTE_PER_BEAT));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_dst_base <= '0;
            cfg_dst_row_stride_b <= '0;
            cfg_k <= '0;
            cfg_m <= '0;
            cfg_ia_reuse_num <= REG_WIDTH'(1);
            cfg_tile_count <= '0;
            cfg_is_mode <= 1'b0;
            cfg_lat_tick <= 1'b0;
        end else if (init_cfg) begin
            cfg_dst_base <= dst_base;
            cfg_dst_row_stride_b <= dst_row_stride_b;
            cfg_k <= k;
            cfg_m <= m;
            cfg_ia_reuse_num <= (ia_reuse_num == '0) ? REG_WIDTH'(1) : ia_reuse_num;
            cfg_tile_count <= ceil_div_vlen(is_mode ? m : k) * ceil_div_vlen(is_mode ? k : m);
            cfg_is_mode <= is_mode;
            cfg_lat_tick <= 1'b1;
        end else begin
            cfg_lat_tick <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            tiles_done <= '0;
            tile_row_idx <= '0;
            tile_col_idx <= '0;
            vec_valid_num_col_r <= '0;
            vec_valid_num_row_r <= '0;
            rows_valid_cur_tile <= '0;
            cols_valid_cur_tile <= '0;
            beats_per_row_cur_tile <= '0;
            tile_base_addr_cur <= '0;
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
                vec_valid_num_col_r <= '0;
                vec_valid_num_row_r <= '0;
                rows_valid_cur_tile <= '0;
                cols_valid_cur_tile <= '0;
                beats_per_row_cur_tile <= '0;
                tile_base_addr_cur <= '0;
                row_in_tile <= '0;
                beats_in_row <= '0;
                oa_calc_over_r <= 1'b0;
            end else begin
                case (state)
                    S_IDLE: begin
                        if (cfg_lat_tick) begin
                            vec_valid_num_col_r <= valid_m1(cols_valid_for_tile('0, '0));
                            vec_valid_num_row_r <= valid_m1(rows_valid_for_tile('0, '0));
                        end
                        if ((cfg_tile_count != '0) && (oa_fifo_req || output_valid)) begin
                            state <= S_REQ;
                        end
                    end

                    S_REQ: begin
                        if (write_oa_granted) begin
                            rows_valid_cur_tile <= rows_valid_for_tile(tile_row_idx, tile_col_idx);
                            cols_valid_cur_tile <= cols_valid_for_tile(tile_row_idx, tile_col_idx);
                            beats_per_row_cur_tile <= beats_for_cols(cols_valid_for_tile(tile_row_idx, tile_col_idx));
                            tile_base_addr_cur <= tile_addr_for_idx(tile_row_idx, tile_col_idx);
                            row_in_tile <= '0;
                            beats_in_row <= '0;
                            state <= S_START;
                        end
                    end

                    S_START: begin
                        if (dma_start) begin
                            state <= S_WRITE;
                        end
                    end

                    S_WRITE: begin
                        if (beat_fire) begin
                            if ((beats_in_row + 1'b1) >= beats_per_row_cur_tile) begin
                                beats_in_row <= '0;
                                if ((REG_WIDTH'(row_in_tile) + REG_WIDTH'(1)) < REG_WIDTH'(rows_valid_cur_tile)) begin
                                    row_in_tile <= row_in_tile + 1'b1;
                                end
                            end else begin
                                beats_in_row <= beats_in_row + 1'b1;
                            end
                        end
                        if (write_done) begin
                            logic [REG_WIDTH-1:0] next_row;
                            logic [REG_WIDTH-1:0] next_col;
                            logic [REG_WIDTH-1:0] row_tiles_total;
                            logic [REG_WIDTH-1:0] col_tiles_total;

                            tiles_done <= tiles_done + 1'b1;
                            row_tiles_total = ceil_div_vlen(stream_k_total());
                            col_tiles_total = ceil_div_vlen(stream_m_total());
                            calc_next_tile(tile_row_idx, tile_col_idx,
                                           row_tiles_total, col_tiles_total,
                                           next_row, next_col);

                            if ((tiles_done + 1'b1) >= cfg_tile_count) begin
                                oa_calc_over_r <= 1'b1;
                                state <= S_DONE;
                                tile_row_idx <= '0;
                                tile_col_idx <= '0;
                            end else begin
                                tile_row_idx <= next_row;
                                tile_col_idx <= next_col;
                                vec_valid_num_col_r <= valid_m1(cols_valid_for_tile(next_row, next_col));
                                vec_valid_num_row_r <= valid_m1(rows_valid_for_tile(next_row, next_col));
                                state <= S_IDLE;
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
