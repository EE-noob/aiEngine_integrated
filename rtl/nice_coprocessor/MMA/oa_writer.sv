// Output-Activation Writer (oa_writer)
// - Writes 32-bit beats with 4-bit byte mask to ICB bus
// - Supports 16x16 tiles with boundary handling
// - Provides vec_valid_num_col to upstream FIFO (no req_ack)
/*
 * oa_writer 输出�?活写回控制器设计说明（自主访存版本）
 * ------------------------------------------------------------
 * 功能概述:
 *  本模块负责面向分块矩阵运算，将脉动阵列的输出�?活数据�?�过 ICB 总线主动写回到外部存储器��?
 *  模块采用自主驱动模式：init_cfg 后自动准备写回流程，每次完成后申请下�?次写回授权�?
 *  模块通过 ICB 总线作为主设备主动发起写请求，支持按行写回和地址 stride 控制��?
 *
 * 工作流程:
 *  1) 配置阶段（�?�过 init_cfg 触发��?
 *     - ��?init_cfg 有效时，模块锁存配置：dst_base、dst_row_stride_b、k、m、tile_count��?
 *     - dst_base: 输出矩阵在内存中的基地址（第�?个分块）
 *     - dst_row_stride_b: 每行之间的地�?间距（字节）
 *     - k: 输出矩阵列数（对��?RHS_COLS��?
 *     - m: 输出矩阵行数（对��?LHS_ROWS��?
 *     - tile_count: 总分块数��?
 *     - 配置完成后，模块准备接收数据写回��?
 *
 *  2) 写回阶段（由 oa_fifo_req 与握手驱动）
 *     - 上游 FIFO 在需要写回某��?OA Tile 的数据时提示 oa_fifo_req��?
 *     - 约定时序：当模块�?测到 oa_fifo_req 被断�?时，说明上游 FIFO 已取走当��?vec_valid_num_col 值并将开始传输数据；
 *       模块在�?�下�?周期”执行两件事��?
 *         a) 更新 vec_valid_num_col 为下�?��?Tile 的有效列数（供上��?FIFO 在准备下�?次传输时使用）；
 *         b) 驱动 write_oa_req=1 向外部控制器申请写回授权（write_oa_req 在下�?周期提出）�?
 *     - 在收��?write_oa_granted 之前，模块应保持 output_ready=0，表示尚不可接受脉动阵列的数据传输�?
 *     - 若在后续周期内收��?write_oa_granted 授权，则模块进入写回传输阶段，此时可��?output_ready ��? 并开始接��?output_valid/output_data
 *       （在每个周期��?output_valid=1 ��?output_ready=1 时，模块采样并�?�过 ICB 发起写请求）��?
 *     - 写回完成后，模块��?write_done=1，并按需驱动 write_oa_req 寻求下一次写回授权�?
 *
 *  3) 自动重触发阶��?
 *     - 每次完成�?个分块的写回后，模块可驱��?write_oa_req=1 申请下一次写回授权，外部控制器�?�过 write_oa_granted 授权��?
 *     - 模块内部维护分块地址指针，每次写回时自动计算下一个分块的基地�?；所有分块写回完成后停止申请��?
 *
 *  4) 地址计算
 *     - 当前写入地址 = dst_base + row_index * dst_row_stride_b + col_index * element_size��?
 *     - switch_row 信号用于控制行索引的递增��?
 *
 * ICB 握手��?
 *   - ICB 命令通道：模块作��?Master，驱��?icb_cmd_m，从端驱��?icb_cmd_s.ready��?
 *   - ICB 响应通道：从端驱��?icb_rsp_s，模块驱��?icb_rsp_m.rsp_ready��?
 */

/*  结构示意��?
            +-----------------------------+
            |        mma_controller       |
            |  - 提供 dst_base/stride/k/m |
            |  - 提供 tile_count          |
            |  - 发起 write_oa_trigger    |
            |  - 授权 write_oa_granted    |
            +----+------------------+-----+
                 |                  ^
                 |                  |
                 v                  |
        +-------------------------------+
        |           oa_writer           |
        |  - 锁存配置: dst_base/stride  |
        |  - FSM: IDLE/WRITE           |
        |  - ��?列地�?生成(16x16 tile)  |
        |  - ICB 主写: wdata/wmask     |
        |  - 行起��?pulse req_ack       |
        +--+-------------------------+--+
           |                         |   ICB 主接��?
           | 数据输入(来自FIFO)       |   icb_cmd_m -> ICB/LSU/内存
           |  output_valid/data/mask  +--> icb_cmd_s.ready
           |  output_ready <----------+   icb_rsp_s / icb_rsp_m.rsp_ready
           |  req_ack, vec_valid_num_col
           ^
 +----------------------+
 |    vec_s8_to_fifo    |
 |  - s8��?2位打��?      |
 |  - 输出:             |
 |    output_valid      |
 |    output_data[31:0] |
 |    output_mask[3:0]  |
 |  - 握手:             |
 |    output_ready<-----+（来��?oa_writer��?
 |    req_ack<----------+（来��?oa_writer��?
 |    vec_valid_num_col-+（来��?oa_writer��?
 +----------+-----------+
            ^
            | s8向量
 +----------------------+     +---------------------+     +------------------+
 |      vec_requant     |<----|     bias_adder      |<----| accumulator_arr. |
 +----------------------+     +---------------------+     +------------------+
                    ^                                           ^
                    |                                           |
              +-----------+                               +-------------+
              | data_setup|<------------------------------| ws_systolic |
              +-----------+                               +-------------+
                    ^                                           ^
                    |                                           |
              +-----------+                               +-------------+
              | ia_loader |                               | kernel_load |
              +-----------+                               +-------------+

*/

`include "C:/Users/92150/Desktop/tflm_dsa/rtl/rtl_new/define.svh"
`include "C:/Users/92150/Desktop/tflm_dsa/rtl/rtl_new/icb_types.svh"

module oa_writer #(
    parameter integer VLEN = 16,
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned REG_WIDTH  = 32
)(
    input  wire                        clk,
    input  wire                        rst_n,

    // Config
    input  wire                        init_cfg,
    input  wire                        write_oa_trigger,
    output reg                         write_oa_req,
    input  wire                        write_oa_granted,

    input  wire [REG_WIDTH-1:0]        dst_base,
    input  wire [REG_WIDTH-1:0]        dst_row_stride_b,
    input  wire [REG_WIDTH-1:0]        k,
    input  wire [REG_WIDTH-1:0]        m,
    input  wire [REG_WIDTH-1:0]        tile_count,

    // Handshake to FIFO
    input wire oa_fifo_req,
    output wire [$clog2(VLEN)-1:0]     vec_valid_num_col,

    // Data in
    input  wire                        output_valid,
    input  wire                        switch_row,
    output wire                        output_ready,
    input  wire [3:0]                  output_mask,
    input  wire [31:0]                 output_data,

    // ICB 主接口（模块作为 Master��?
    output icb_ext_cmd_m_t icb_ext_cmd_m,  // Master -> Slave: 命令有效载荷
    input  icb_ext_cmd_s_t icb_ext_cmd_s,  // Slave -> Master: 命令就绪
    output icb_ext_wr_m_t  icb_ext_wr_m,   // Master -> Slave: 写数据有效载��?
    input  icb_ext_wr_s_t  icb_ext_wr_s,   // Slave -> Master: 写数据就��?
    input  icb_ext_rsp_s_t icb_ext_rsp_s,  // Slave -> Master: 响应有效载荷
    output icb_ext_rsp_m_t icb_ext_rsp_m,  // Master -> Slave: 响应就绪

    // Status
    output reg                         write_done,
    output wire                        oa_calc_over
);

    //========================
    // Local params and cfg
    //========================
    localparam integer VCOL_W = $clog2(VLEN);






    assign icb_ext_rsp_m = '{ rsp_ready: 1'b1 };

    reg [REG_WIDTH-1:0] cfg_dst_base;
    reg [REG_WIDTH-1:0] cfg_dst_row_stride_b;
    reg [REG_WIDTH-1:0] cfg_k;
    reg [REG_WIDTH-1:0] cfg_m;
    reg [REG_WIDTH-1:0] cfg_tile_count;
    reg                  cfg_lat_tick; // one-cycle tick after init_cfg to use latched cfg_*

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_dst_base        <= '0;
            cfg_dst_row_stride_b<= '0;
            cfg_k               <= '0;
            cfg_m               <= '0;
            cfg_tile_count      <= '0;
            cfg_lat_tick        <= 1'b0;
        end else if (init_cfg) begin
            cfg_dst_base        <= dst_base;
            cfg_dst_row_stride_b<= dst_row_stride_b;
            cfg_k               <= k;
            cfg_m               <= m;
            cfg_tile_count      <= tile_count;
            cfg_lat_tick        <= 1'b1; // raise tick; will be consumed next cycle
        end else begin
            cfg_lat_tick        <= 1'b0;
        end
    end

    //========================
    //========================
    // Tile/row bookkeeping
    //========================
    reg [31:0]                tiles_done;
    reg [31:0]                tile_row_idx;
    reg [31:0]                tile_col_idx;
    reg [VCOL_W-1:0]          row_in_tile;
    reg [REG_WIDTH-1:0]       row_tile_base_addr; // start of current tile-row (col=0)
    reg [REG_WIDTH-1:0]       tile_base_addr;     // start of current tile (row/col)
    reg [REG_WIDTH-1:0]       cur_addr;           // current write address

    reg [VCOL_W:0]            rows_valid_cur_tile; // 0..16
    reg [VCOL_W:0]            cols_valid_cur_tile; // 0..16
    reg [VCOL_W:0]            beats_per_row;       // ceil(cols/4)
    reg [VCOL_W:0]            beats_in_row;        // progressed beats in current row

    // Handshake implementation with oa_fifo_req falling-edge update
    reg [VCOL_W-1:0] vec_valid_num_col_r;
    reg [VCOL_W-1:0] vec_next_m1;
    reg              vec_pending;
    reg              oa_fifo_req_q;
    wire             oa_fifo_req_fall = oa_fifo_req_q & ~oa_fifo_req;

    // Preview-next indices for vec_valid publication (col-first order)
    reg [31:0]       vpub_next_row_idx;
    reg [31:0]       vpub_next_col_idx;
    assign vec_valid_num_col = vec_valid_num_col_r;

    // sample for edge detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            oa_fifo_req_q <= 1'b0;
        end else begin
            oa_fifo_req_q <= oa_fifo_req;
        end
    end

    //========================
    // Helpers (Verilog-2001 style)
    //========================
    function [VCOL_W:0] min16;
        input [REG_WIDTH-1:0] val;
        begin
            if (val >= VLEN) min16 = VLEN; else min16 = val[VCOL_W:0];
        end
    endfunction

    function [REG_WIDTH-1:0] rem_after_tiles;
        input [REG_WIDTH-1:0] total;
        input [REG_WIDTH-1:0] tile_idx;
        reg   [REG_WIDTH-1:0] consumed;
        begin
            consumed = (tile_idx << VCOL_W);
            rem_after_tiles = (total > consumed) ? (total - consumed) : '0;
        end
    endfunction
    //========================

    //========================
    // FSM
    //========================
    // FSM: explicit wait-for-grant stage to ensure per-tile bus re-acquire
    localparam [1:0] S_IDLE  = 2'b00,
                     S_WAIT  = 2'b01,
                     S_WRITE = 2'b10;
    reg [1:0] state;
    reg        has_grant; // asserted after write_oa_granted until tile release
    wire slave_cmd_ready   = icb_ext_cmd_s.ready;
    wire slave_wr_ready    = icb_ext_wr_s.w_ready;
    wire first_beat_in_row = (beats_in_row == '0);
    wire bus_ready_for_beat = slave_wr_ready && (!first_beat_in_row || slave_cmd_ready);
    wire writer_ready_cond = (state == S_WRITE) && has_grant && (beats_in_row < beats_per_row) && bus_ready_for_beat;
    assign output_ready    = writer_ready_cond;
    wire beat_fire         = output_valid && writer_ready_cond;
    wire [2:0] cmd_len_cur   = (beats_per_row <= 1) ? 3'b000 : (beats_per_row[2:0] - 3'd1);

    assign icb_ext_cmd_m = '{
        valid: beat_fire && first_beat_in_row,
        addr:  cur_addr,
        read:  1'b0,
        len:   cmd_len_cur
    };

    assign icb_ext_wr_m = '{
        w_valid: beat_fire,
        wdata:   output_data,
        wmask:   output_mask
    };
    wire [VCOL_W:0] beats_in_row_plus1 = beats_in_row + 1'b1;
    wire [VCOL_W:0] beats_per_row_m1   = (beats_per_row == '0) ? '0 : (beats_per_row - 1'b1);
    wire [VCOL_W:0] row_in_tile_plus1  = row_in_tile + 1'b1;
    wire last_beat_in_row              = beat_fire && (beats_in_row_plus1 >= beats_per_row);
    wire last_row_in_tile              = (row_in_tile_plus1 >= rows_valid_cur_tile);
    wire tile_transfer_done            = last_beat_in_row && last_row_in_tile;
    wire oa_tiles_done     = (tiles_done == cfg_tile_count) && (cfg_tile_count != '0);
    assign oa_calc_over    = oa_tiles_done;


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= S_IDLE;
            write_done         <= 1'b0;
            write_oa_req        <= 1'b0;
            tiles_done          <= '0;
            tile_row_idx        <= '0;
            tile_col_idx        <= '0;
            row_in_tile         <= '0;
            row_tile_base_addr  <= '0;
            tile_base_addr      <= '0;
            cur_addr            <= '0;
            rows_valid_cur_tile <= '0;
            cols_valid_cur_tile <= '0;
            has_grant           <= 1'b0;
            // vec_valid handshake reset
            vec_valid_num_col_r <= '0;
            vec_next_m1         <= '0;
            vec_pending         <= 1'b0;
            vpub_next_row_idx   <= '0;
            vpub_next_col_idx   <= '0;
        end else begin
            // one-shots
            write_done        <= 1'b0;
            // one-shots
            case (state)
                S_IDLE: begin
                    if (init_cfg) begin
                        tile_row_idx       <= '0;
                        tile_col_idx       <= '0;
                        tiles_done         <= '0;
                    end

                    // 使用已锁存的 cfg_k 在下�?拍发布首?tile ?(cols-1)，并预取下一 tile ?(cols-1)
                    if (cfg_lat_tick) begin : init_vec_valid
                        reg [VCOL_W:0] curr_cols_tmp;
                        reg [VCOL_W:0] next_cols_tmp;
                        integer tile_cols_total_i;
                        reg [31:0] next_col_idx_tmp;
                        curr_cols_tmp = min16(rem_after_tiles(cfg_m, '0));
                        vec_valid_num_col_r <= (curr_cols_tmp == '0) ? {VCOL_W{1'b0}} : (curr_cols_tmp - 1'b1);
                        tile_cols_total_i   = (cfg_m + VLEN - 1) >> VCOL_W;
                        if (1 < tile_cols_total_i) begin
                            next_col_idx_tmp = 1;
                        end else begin
                            next_col_idx_tmp = 0;
                        end
                        next_cols_tmp       = min16(rem_after_tiles(cfg_m, next_col_idx_tmp[REG_WIDTH-1:0]));
                        vec_next_m1         <= (next_cols_tmp == '0) ? {VCOL_W{1'b0}} : (next_cols_tmp - 1'b1);
                        vec_pending         <= 1'b1;
                    end

                    // First-tile kick: only request the bus; move to WAIT
                    if (write_oa_trigger) begin
                        write_oa_req <= 1'b1;
                        has_grant    <= 1'b0;
                        state        <= S_WAIT;
                    end
                end

                // Wait for bus grant; once granted, compute current tile params,
                // publish vec_valid for this tile, then enter WRITE (ready will assert inside WRITE)
                S_WAIT: begin
                    if (oa_tiles_done) begin
                        state <= S_IDLE;
                    end else if (write_oa_granted && write_oa_req) begin
                        // Latch tile geometry for current indices
                        rows_valid_cur_tile <= min16(rem_after_tiles(cfg_k, tile_row_idx));
                        cols_valid_cur_tile <= min16(rem_after_tiles(cfg_m, tile_col_idx));
                        row_tile_base_addr  <= cfg_dst_base + ((tile_row_idx << VCOL_W) * cfg_dst_row_stride_b);
                        tile_base_addr      <= cfg_dst_base + ((tile_row_idx << VCOL_W) * cfg_dst_row_stride_b)
                                              + (tile_col_idx << VCOL_W);
                        cur_addr            <= cfg_dst_base + ((tile_row_idx << VCOL_W) * cfg_dst_row_stride_b)
                                              + (tile_col_idx << VCOL_W);
                        row_in_tile         <= '0;
                        beats_per_row       <= (min16(rem_after_tiles(cfg_m, tile_col_idx)) + 3) >> 2;
                        beats_in_row        <= '0;

                        // Publish current tile's (cols-1) immediately so FIFO knows how many bytes per row
                        begin : vec_valid_prep_wait
                            reg [VCOL_W:0] curr_cols_tmp;
                            reg [VCOL_W:0] next_cols_tmp;
                            integer tile_cols_total_i;
                            reg [31:0] next_col_idx_tmp;
                            curr_cols_tmp = min16(rem_after_tiles(cfg_m, tile_col_idx));
                            vec_valid_num_col_r <= (curr_cols_tmp == '0) ? {VCOL_W{1'b0}} : (curr_cols_tmp - 1'b1);
                            tile_cols_total_i   = (cfg_m + VLEN - 1) >> VCOL_W;
                            if ((tile_col_idx + 1) < tile_cols_total_i) begin
                                next_col_idx_tmp  = tile_col_idx + 1;
                                vpub_next_row_idx <= tile_row_idx;
                                vpub_next_col_idx <= tile_col_idx + 1'b1;
                            end else begin
                                next_col_idx_tmp  = 0; // wrap to next row
                                vpub_next_row_idx <= tile_row_idx + 1'b1;
                                vpub_next_col_idx <= '0;
                            end
                            next_cols_tmp       = min16(rem_after_tiles(cfg_m, next_col_idx_tmp[REG_WIDTH-1:0]));
                            vec_next_m1         <= (next_cols_tmp == '0) ? {VCOL_W{1'b0}} : (next_cols_tmp - 1'b1);
                            vec_pending         <= 1'b1;
                        end

                        state <= S_WRITE; // ready gating handled by writer_ready_cond
                    end
                end

                S_WRITE: begin
                    if (beat_fire) begin
                        if (last_beat_in_row) begin
                            beats_in_row <= '0;
                        end else if (beats_in_row < beats_per_row_m1) begin
                            beats_in_row <= beats_in_row + 1'b1;
                        end else begin
                            beats_in_row <= beats_per_row_m1;
                        end
                    end

                    // Tile complete once final row/beat accepted via FIFO tracking
                    if (tile_transfer_done) begin
                        state        <= S_WAIT;
                        tiles_done   <= tiles_done + 1'b1;
                        write_done   <= 1'b1;
                        if (tiles_done + 1'b1 < cfg_tile_count) begin
                            if (tile_col_idx + 1 < ((cfg_m + VLEN - 1) >> VCOL_W)) begin
                                tile_col_idx <= tile_col_idx + 1'b1;
                            end else begin
                                tile_col_idx       <= '0;
                                tile_row_idx       <= tile_row_idx + 1'b1;
                                row_tile_base_addr <= row_tile_base_addr + (cfg_dst_row_stride_b << VCOL_W);
                            end
                            write_oa_req <= 1'b1;
                            has_grant    <= 1'b0;
                        end else begin
                            write_oa_req <= 1'b0;
                            has_grant    <= 1'b0;
                        end
                    end
                    if (beat_fire && switch_row) begin
                        row_in_tile <= row_in_tile + 1'b1;
                        cur_addr    <= tile_base_addr + (row_in_tile_plus1 * cfg_dst_row_stride_b);
                    end

                end
            endcase
            // Publish new vec_valid when upstream deasserts oa_fifo_req (falling edge)
            if (oa_fifo_req_fall) begin
                integer tile_cols_total_i;
                reg [VCOL_W:0] next2_cols_tmp;
                vec_valid_num_col_r <= vec_next_m1;
                tile_cols_total_i = (cfg_m + VLEN - 1) >> VCOL_W;
                // advance vpub_next_* to following tile (col-first)
                if ((vpub_next_col_idx + 1) < tile_cols_total_i) begin
                    vpub_next_col_idx <= vpub_next_col_idx + 1'b1;
                    // same row
                end else begin
                    vpub_next_col_idx <= '0;
                    vpub_next_row_idx <= vpub_next_row_idx + 1'b1;
                end
                // recompute next mask for the new vpub_next_* index
                next2_cols_tmp      = min16(rem_after_tiles(cfg_m, vpub_next_col_idx));
                vec_next_m1         <= (next2_cols_tmp == '0) ? {VCOL_W{1'b0}} : (next2_cols_tmp - 1'b1);
            end

            // 授权采样：获得授权后清请求并标记拥有总线
            if (write_oa_granted) begin
                has_grant    <= 1'b1;
                write_oa_req <= 1'b0;
            end
        end
    end

endmodule
