/*
 * block_dma — 分块 DMA 引擎（读/写双向）
 * ============================================================
 * 功能：
 *   1. 读模式：支持按行 burst 的块读，以及单拍顺序的线性 1D 读
 *   2. 写模式：按行/beat 写回外存，支持分块写入
 *
 * 说明：
 *   - 保持与 tile_loader 读通路兼容，便于 ia_loader 平滑迁移
 *   - 写模式通过 src_wdata/src_wmask/src_wvalid 流式提供待写数据
 */

module block_dma #(
    parameter int unsigned DATA_WIDTH   = 16,
    parameter int unsigned SIZE         = 16,
    parameter int unsigned BUS_WIDTH    = 32,
    parameter int unsigned REG_WIDTH    = 32,
    parameter int unsigned CACHE_BLOCKS = 4
) (
    input logic clk,
    input logic rst_n,

    // ---- 分块命令 ----
    input  logic                                   start,             // 单拍脉冲
    input  logic                                   is_write,          // 0:读块 1:写块
    input  logic                                   linear_read_mode,  // 0:块读 1:线性 1D 读
    input  logic        [           REG_WIDTH-1:0] tile_base_addr,
    input  logic        [           REG_WIDTH-1:0] row_stride,
    input  logic        [           REG_WIDTH-1:0] rows_to_read,
    input  logic        [                     3:0] burst_len_m1,
    input  logic        [$clog2(CACHE_BLOCKS)-1:0] slot_id,
    input  logic                                   use_16bits,
    input  logic signed [           REG_WIDTH-1:0] lhs_zp,
    output logic                                   busy,
    output logic                                   tile_done,

    // ---- 写模式数据源 ----
    input  logic [  BUS_WIDTH-1:0] src_wdata,
    input  logic [BUS_WIDTH/8-1:0] src_wmask,
    input  logic                   src_wvalid,
    output logic                   src_wready,

    // ---- ICB 主接口 ----
    output logic                   icb_cmd_valid,
    input  logic                   icb_cmd_ready,
    output logic                   icb_cmd_read,
    output logic [  REG_WIDTH-1:0] icb_cmd_addr,
    output logic [            3:0] icb_cmd_len,
    output logic [  BUS_WIDTH-1:0] icb_cmd_wdata,
    output logic [BUS_WIDTH/8-1:0] icb_cmd_wmask,
    output logic                   icb_w_valid,
    input  logic                   icb_w_ready,
    input  logic                   icb_rsp_valid,
    output logic                   icb_rsp_ready,
    input  logic [  BUS_WIDTH-1:0] icb_rsp_rdata,
    input  logic                   icb_rsp_err,

    // ---- 读模式写回端口 ----
    output logic        [$clog2(CACHE_BLOCKS)-1:0] wr_slot,
    output logic        [        $clog2(SIZE)-1:0] wr_row,
    output logic        [        $clog2(SIZE)-1:0] wr_col_base,
    output logic signed [          DATA_WIDTH-1:0] wr_data      [BUS_WIDTH/8],
    output logic                                   wr_valid     [BUS_WIDTH/8],
    output logic                                   wr_use_16bits,

    // ---- 原始读响应旁路：供量化参数等 32-bit word 流复用同一 DMA ----
    output logic [   BUS_WIDTH-1:0] rd_raw_data,
    output logic                    rd_raw_valid,
    output logic [$clog2(SIZE)-1:0] rd_raw_row,
    output logic [$clog2(SIZE)-1:0] rd_raw_col_base
);

    localparam int BYTE_PER_BEAT = BUS_WIDTH / 8;
    localparam int ELEM_PER_BEAT_S8 = BYTE_PER_BEAT;
    localparam int ELEM_PER_BEAT_S16 = BYTE_PER_BEAT >> 1;

    wire                                    cmd_hs = icb_cmd_valid && icb_cmd_ready;
    wire                                    w_hs = icb_w_valid && icb_w_ready;
    wire                                    rsp_hs = icb_rsp_valid && icb_rsp_ready;

    logic        [           REG_WIDTH-1:0] cfg_base_addr;
    logic        [           REG_WIDTH-1:0] cfg_row_stride;
    logic        [           REG_WIDTH-1:0] cfg_rows;
    logic        [                     3:0] cfg_burst_len_m1;
    logic        [$clog2(CACHE_BLOCKS)-1:0] cfg_slot;
    logic                                   cfg_linear_read;
    logic                                   cfg_use_16bits;
    logic signed [           REG_WIDTH-1:0] cfg_zp;
    logic                                   cfg_is_write;

    // 读模式状态
    logic        [           REG_WIDTH-1:0] current_row_addr;
    logic        [           REG_WIDTH-1:0] cmd_row_cnt;
    logic        [           REG_WIDTH-1:0] rsp_row_cnt;
    logic        [           REG_WIDTH-1:0] rsp_beat_cnt;
    logic        [           BUS_WIDTH-1:0] rsp_data_r;
    logic        [           REG_WIDTH-1:0] rsp_row_r;
    logic        [        $clog2(SIZE)-1:0] rsp_col_base_r;
    logic                                   rsp_valid_r;
    logic                                   rd_cmd_inflight;

    // 写模式状态
    logic        [           REG_WIDTH-1:0] wr_row_cnt;
    logic        [           REG_WIDTH-1:0] wr_beat_cnt;
    logic                                   wr_cmd_inflight;
    logic                                   wr_w_pending;
    logic        [           BUS_WIDTH-1:0] wr_data_buf;
    logic        [         BUS_WIDTH/8-1:0] wr_mask_buf;
    logic                                   wr_data_buf_valid;

    logic                                   active;
    logic                                   tile_done_r;

    assign busy          = active;
    assign wr_use_16bits = cfg_use_16bits;
    assign wr_slot       = cfg_slot;
    assign icb_w_valid   = active && cfg_is_write && wr_w_pending && wr_data_buf_valid;

    // ICB 固定信号
    assign icb_rsp_ready = active;

    wire read_rsp_done = rsp_hs
                    && !cfg_is_write
                    && (cfg_linear_read
                        ? 1'b1
                        : (rsp_beat_cnt == {28'd0, cfg_burst_len_m1}));

    wire last_rsp_read = rsp_hs
                    && !cfg_is_write
                    && (cfg_linear_read
                        ? (rsp_beat_cnt == cfg_rows - 1)
                        : ((rsp_beat_cnt == {28'd0, cfg_burst_len_m1})
                           && (rsp_row_cnt  == cfg_rows - 1)));

    wire last_rsp_write = rsp_hs
                     && cfg_is_write
                     && (wr_beat_cnt == {28'd0, cfg_burst_len_m1})
                     && (wr_row_cnt  == cfg_rows - 1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) tile_done_r <= 1'b0;
        else tile_done_r <= active && (last_rsp_read || last_rsp_write);
    end

    assign tile_done = tile_done_r;

    // 参数锁存
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active           <= 1'b0;
            cfg_base_addr    <= '0;
            cfg_row_stride   <= '0;
            cfg_rows         <= '0;
            cfg_burst_len_m1 <= '0;
            cfg_slot         <= '0;
            cfg_linear_read  <= 1'b0;
            cfg_use_16bits   <= 1'b0;
            cfg_zp           <= '0;
            cfg_is_write     <= 1'b0;
        end else if (start && !active) begin
            active           <= 1'b1;
            cfg_base_addr    <= tile_base_addr;
            cfg_row_stride   <= row_stride;
            cfg_rows         <= rows_to_read;
            cfg_burst_len_m1 <= burst_len_m1;
            cfg_slot         <= slot_id;
            cfg_linear_read  <= linear_read_mode;
            cfg_use_16bits   <= use_16bits;
            cfg_zp           <= lhs_zp;
            cfg_is_write     <= is_write;
        end else if (tile_done_r) begin
            active <= 1'b0;
        end
    end

    // 默认命令字段
    always_comb begin
        icb_cmd_read  = !cfg_is_write;
        icb_cmd_len   = cfg_is_write ? 4'd0 : (cfg_linear_read ? 4'd0 : cfg_burst_len_m1);
        icb_cmd_wdata = wr_data_buf;
        icb_cmd_wmask = wr_mask_buf;
    end

    // 源写数据就绪：仅写模式且缓存空、当前无 outstanding
    assign src_wready = active && cfg_is_write
	                   && !wr_data_buf_valid
	                   && !icb_cmd_valid
	                   && !wr_w_pending
	                   && !wr_cmd_inflight
	                   && (wr_row_cnt < cfg_rows);

    // 命令发送
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            icb_cmd_valid     <= 1'b0;
            icb_cmd_addr      <= '0;
            current_row_addr  <= '0;
            cmd_row_cnt       <= '0;
            wr_row_cnt        <= '0;
            wr_beat_cnt       <= '0;
            rd_cmd_inflight   <= 1'b0;
            wr_cmd_inflight   <= 1'b0;
            wr_w_pending      <= 1'b0;
            wr_data_buf       <= '0;
            wr_mask_buf       <= '0;
            wr_data_buf_valid <= 1'b0;
        end else if (start && !active) begin
            icb_cmd_valid     <= 1'b0;
            icb_cmd_addr      <= tile_base_addr;
            current_row_addr  <= tile_base_addr + row_stride;
            cmd_row_cnt       <= '0;
            wr_row_cnt        <= '0;
            wr_beat_cnt       <= '0;
            rd_cmd_inflight   <= 1'b0;
            wr_cmd_inflight   <= 1'b0;
            wr_w_pending      <= 1'b0;
            wr_data_buf       <= '0;
            wr_mask_buf       <= '0;
            wr_data_buf_valid <= 1'b0;
        end else if (active) begin
            // 写模式下先缓存上游待写数据，再发命令
            if (cfg_is_write && src_wvalid && src_wready) begin
                wr_data_buf       <= src_wdata;
                wr_mask_buf       <= src_wmask;
                wr_data_buf_valid <= 1'b1;
            end

            if (tile_done_r) begin
                icb_cmd_valid     <= 1'b0;
                rd_cmd_inflight   <= 1'b0;
                wr_cmd_inflight   <= 1'b0;
                wr_w_pending      <= 1'b0;
                wr_data_buf_valid <= 1'b0;
            end else if (!cfg_is_write) begin
                // 读模式：块读（逐行 burst）或线性 1D 读（单拍顺序）
                if (cmd_row_cnt < cfg_rows && !rd_cmd_inflight) begin
                    if (!icb_cmd_valid || cmd_hs) begin
                        icb_cmd_valid <= 1'b1;
                        if (cmd_row_cnt == 0) begin
                            icb_cmd_addr     <= cfg_base_addr;
                            current_row_addr <= cfg_base_addr + cfg_row_stride;
                        end else begin
                            icb_cmd_addr     <= current_row_addr;
                            current_row_addr <= current_row_addr + cfg_row_stride;
                        end
                        cmd_row_cnt <= cmd_row_cnt + 1;
                    end
                end else if (cmd_hs || !icb_cmd_valid) begin
                    icb_cmd_valid <= 1'b0;
                end

                if (cmd_hs) rd_cmd_inflight <= 1'b1;
                if (read_rsp_done) rd_cmd_inflight <= 1'b0;
            end else begin
                // 写模式：按 row/beat 发单拍写命令（len=0）
                if (!icb_cmd_valid && !wr_w_pending && !wr_cmd_inflight) begin
                    if (wr_data_buf_valid && (wr_row_cnt < cfg_rows)) begin
                        icb_cmd_valid <= 1'b1;
                        icb_cmd_addr  <= cfg_base_addr + wr_row_cnt * cfg_row_stride + wr_beat_cnt * BYTE_PER_BEAT;
                    end
                end else if (cmd_hs) begin
                    icb_cmd_valid <= 1'b0;
                    wr_w_pending  <= 1'b1;
                end

                if (w_hs) begin
                    wr_w_pending      <= 1'b0;
                    wr_cmd_inflight   <= 1'b1;
                    wr_data_buf_valid <= 1'b0;
                end
                if (rsp_hs) wr_cmd_inflight <= 1'b0;
            end

            // 写模式计数器按 rsp 推进
            if (rsp_hs && cfg_is_write) begin
                if (wr_beat_cnt == {28'd0, cfg_burst_len_m1}) begin
                    wr_beat_cnt <= '0;
                    if (wr_row_cnt < cfg_rows) wr_row_cnt <= wr_row_cnt + 1;
                end else begin
                    wr_beat_cnt <= wr_beat_cnt + 1;
                end
            end
        end else begin
            icb_cmd_valid     <= 1'b0;
            cmd_row_cnt       <= '0;
            wr_row_cnt        <= '0;
            wr_beat_cnt       <= '0;
            rd_cmd_inflight   <= 1'b0;
            wr_cmd_inflight   <= 1'b0;
            wr_w_pending      <= 1'b0;
            wr_data_buf       <= '0;
            wr_mask_buf       <= '0;
            wr_data_buf_valid <= 1'b0;
        end
    end

    // 读模式响应锁存
    logic [$clog2(SIZE)-1:0] rsp_col_base_comb;
    assign rsp_col_base_comb = cfg_use_16bits ? rsp_beat_cnt[$clog2(
        SIZE
    )-1:0] << $clog2(
        ELEM_PER_BEAT_S16
    ) : rsp_beat_cnt[$clog2(
        SIZE
    )-1:0] << $clog2(
        ELEM_PER_BEAT_S8
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_row_cnt    <= '0;
            rsp_beat_cnt   <= '0;
            rsp_valid_r    <= 1'b0;
            rsp_data_r     <= '0;
            rsp_row_r      <= '0;
            rsp_col_base_r <= '0;
        end else if (start && !active) begin
            rsp_row_cnt  <= '0;
            rsp_beat_cnt <= '0;
            rsp_valid_r  <= 1'b0;
        end else if (active && !cfg_is_write) begin
            if (rsp_hs) begin
                rsp_data_r     <= icb_rsp_rdata;
                rsp_row_r      <= cfg_linear_read ? '0 : rsp_row_cnt[$clog2(SIZE)-1:0];
                rsp_col_base_r <= rsp_col_base_comb;
                rsp_valid_r    <= 1'b1;

                if (cfg_linear_read) begin
                    if (rsp_beat_cnt == cfg_rows - 1) rsp_beat_cnt <= '0;
                    else rsp_beat_cnt <= rsp_beat_cnt + 1;
                end else if (rsp_beat_cnt == {28'd0, cfg_burst_len_m1}) begin
                    rsp_beat_cnt <= '0;
                    if (rsp_row_cnt == cfg_rows - 1) rsp_row_cnt <= '0;
                    else rsp_row_cnt <= rsp_row_cnt + 1;
                end else begin
                    rsp_beat_cnt <= rsp_beat_cnt + 1;
                end
            end else begin
                rsp_valid_r <= 1'b0;
            end
        end else begin
            rsp_row_cnt  <= '0;
            rsp_beat_cnt <= '0;
            rsp_valid_r  <= 1'b0;
        end
    end

    // 读模式数据解包
    assign wr_row          = rsp_row_r;
    assign wr_col_base     = rsp_col_base_r;
    assign rd_raw_data     = rsp_data_r;
    assign rd_raw_valid    = rsp_valid_r && !cfg_is_write;
    assign rd_raw_row      = rsp_row_r;
    assign rd_raw_col_base = rsp_col_base_r;

    always_comb begin
        for (int i = 0; i < BYTE_PER_BEAT; i++) begin
            wr_data[i]  = '0;
            wr_valid[i] = 1'b0;
        end

        if (rsp_valid_r && !cfg_is_write) begin
            if (cfg_use_16bits) begin
                for (int i = 0; i < ELEM_PER_BEAT_S16; i++) begin
                    if (rsp_col_base_r + i < SIZE) begin
                        wr_data[i]  = DATA_WIDTH'($signed(rsp_data_r[i*16+:16]) + cfg_zp[15:0]);
                        wr_valid[i] = 1'b1;
                    end
                end
            end else begin
                for (int i = 0; i < ELEM_PER_BEAT_S8; i++) begin
                    if (rsp_col_base_r + i < SIZE) begin
                        wr_data[i] = DATA_WIDTH
                            '($signed({{8{rsp_data_r[i*8+7]}}, rsp_data_r[i*8+:8]}) + cfg_zp[15:0]);
                        wr_valid[i] = 1'b1;
                    end
                end
            end
        end
    end

endmodule
