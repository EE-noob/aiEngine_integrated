/*
 * ia_loader v2.0 — 输入激活加载控制器（模块化重构版）
 * ============================================================
 * 功能：
 *   从外部存储器自主读取 IA Tile，写入多槽缓存 RAM，
 *   按 L1/L2 两级分组复用策略循环发送，
 *   并在输出端内置对角化延迟（取代外部 data_setup）。
 *   另外输出 bias_sleep / bias_switch，供 bias_loader 协调切换。
 *
 * 子模块：
 *   ia_loader_ctrl      — 缓存调度、循环计数、发送控制
 *   block_dma            — ICB 分块DMA引擎（读写双向）
 *   ia_loader_cache_mgr — 缓存 RAM 管理、对角化输出、控制信号生成
 *
 * 相对 v1.1 的改进：
 *   - 支持 load-send overlap：不必等全部 R 个 tile 加载完才发送
 *   - 缓存块状态表：valid/busy 位跟踪，支持精确调度
 *   - 早期释放：tile 完成最后一次 reuse 后立即释放 slot
 *
 * 设计约束：
 *   - SIZE、ia_reuse_num、w_reuse_num 要求为 2 的幂次
 *   - CACHE_BLOCKS ≥ 2 × ia_reuse_num
 */

`include "e203_defines.v"
`include "icb_types.svh"

module ia_loader #(
    parameter int unsigned DATA_WIDTH   = 16,
    parameter int unsigned SIZE         = 16,
    parameter int unsigned BUS_WIDTH    = 32,
    parameter int unsigned REG_WIDTH    = 32,
    parameter int unsigned CACHE_BLOCKS = 4,
    parameter bit          EXTERNAL_DMA = 1'b0
) (
    input logic clk,
    input logic rst_n,

    // ---- 配置与控制 ----
    input  logic init_cfg,
    output logic load_ia_req,
    input  logic load_ia_granted,
    input  logic send_ia_trigger,

    // ---- 矩阵尺寸（init_cfg 高时须稳定）----
    input logic        [REG_WIDTH-1:0] k,
    input logic        [REG_WIDTH-1:0] n,
    input logic        [REG_WIDTH-1:0] m,
    input logic        [REG_WIDTH-1:0] lhs_base,
    input logic        [REG_WIDTH-1:0] lhs_row_stride_b,
    input logic signed [REG_WIDTH-1:0] lhs_zp,
    input logic                        use_16bits,
    input logic                        bias_by_row_mode,

    // ---- 复用控制（init_cfg 高时须稳定）----
    input logic [REG_WIDTH-1:0] ia_reuse_num,  // R
    input logic [REG_WIDTH-1:0] w_reuse_num,   // W

    // ---- ICB 主接口 ----
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
    output logic                                   ext_dma_start,
    output logic                                   ext_dma_is_write,
    output logic                                   ext_dma_linear_read_mode,
    output logic        [           REG_WIDTH-1:0] ext_dma_base_addr,
    output logic        [           REG_WIDTH-1:0] ext_dma_row_stride,
    output logic        [           REG_WIDTH-1:0] ext_dma_rows_to_read,
    output logic        [                     3:0] ext_dma_burst_len_m1,
    output logic        [$clog2(CACHE_BLOCKS)-1:0] ext_dma_slot_id,
    output logic                                   ext_dma_use_16bits,
    output logic signed [           REG_WIDTH-1:0] ext_dma_lhs_zp,
    input  logic                                   ext_dma_busy,
    input  logic                                   ext_dma_done,
    input  logic        [$clog2(CACHE_BLOCKS)-1:0] ext_dma_wr_slot,
    input  logic        [        $clog2(SIZE)-1:0] ext_dma_wr_row,
    input  logic        [        $clog2(SIZE)-1:0] ext_dma_wr_col_base,
    input  logic signed [          DATA_WIDTH-1:0] ext_dma_wr_data         [BUS_WIDTH/8],
    input  logic                                   ext_dma_wr_valid        [BUS_WIDTH/8],
    input  logic                                   ext_dma_wr_use_16bits,

    // ---- 输出到脉动阵列（SIZE 维数据 + 最后一列指示信号）----
    output logic signed [DATA_WIDTH-1:0] ia_out         [SIZE],
    output logic                         ia_row_valid,           // 最大延迟列有效标志
    output logic                         ia_is_init_data,        // 同上
    output logic                         ia_calc_done,           // 同上
    output logic                         ia_tile_start,          // 单 tile 首行到达输出端
    output logic                         ia_sending_done,
    output logic                         ia_data_valid,
    output logic                         ia_group_calc_done,
    output logic                         bias_sleep,
    output logic                         bias_switch,
    output logic                         bias_last_loop,
    output logic                         ia_l1_switch
);

    // =======================================================================
    // 局部参数
    // =======================================================================
    localparam int BYTE_PER_BEAT = BUS_WIDTH / 8;
    localparam int LOG2_SIZE = $clog2(SIZE);
    localparam int LOG2_BYTE_PER_BEAT = $clog2(BYTE_PER_BEAT);

    // =======================================================================
    // 状态机
    // =======================================================================
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        INIT = 2'b11,
        RUN  = 2'b01
    } state_t;

    state_t state, state_nxt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= state_nxt;
    end

    // ctrl 完成信号
    logic ctrl_all_done;
    logic cfg_valid;  // 参数已就绪

    always_comb begin
        state_nxt = state;
        case (state)
            IDLE: if (init_cfg) state_nxt = INIT;
            INIT: if (cfg_valid) state_nxt = RUN;
            RUN: if (ctrl_all_done) state_nxt = IDLE;
            default: state_nxt = IDLE;
        endcase
    end

    // =======================================================================
    // 配置寄存器（init_cfg 锁存）
    // =======================================================================
    logic [REG_WIDTH-1:0] cfg_k, cfg_n, cfg_m;
    logic signed [REG_WIDTH-1:0] cfg_lhs_zp;
    logic [REG_WIDTH-1:0] cfg_lhs_row_stride_b, cfg_lhs_base;
    logic                 cfg_use_16bits;
    logic                 cfg_bias_by_row_mode;
    logic [REG_WIDTH-1:0] cfg_ia_reuse_num;
    logic [REG_WIDTH-1:0] cfg_w_reuse_num;

    // =======================================================================
    // 派生参数
    // =======================================================================
    logic [REG_WIDTH-1:0] horizontal_tile_num;
    logic [REG_WIDTH-1:0] vertical_tile_num;
    logic [REG_WIDTH-1:0] l2_group_num;
    logic [REG_WIDTH-1:0] l1_per_l2;
    logic [REG_WIDTH-1:0] ia_reuse_num_act;
    logic [REG_WIDTH-1:0] rsp_beats_per_row_normal;
    logic [REG_WIDTH-1:0] rsp_beats_per_row_last;
    logic [REG_WIDTH-1:0] rsp_rows_last_tile;

    // =======================================================================
    // 派生参数计算通路（使用连续赋值）
    // =======================================================================
    logic [REG_WIDTH-1:0] vtn_tmp;
    logic [REG_WIDTH-1:0] r_mod;
    logic [REG_WIDTH-1:0] ia_reuse_num_act_comb;

    logic [REG_WIDTH-1:0] last_cols_comb;
    logic [REG_WIDTH-1:0] rsp_beats_per_row_last_comb;

    logic [REG_WIDTH-1:0] tmp_col_rem;
    logic [REG_WIDTH-1:0] rsp_rows_last_tile_comb;

    // 基于输入参数计算派生值
    assign vtn_tmp = (k + SIZE - 1) >> LOG2_SIZE;
    assign r_mod = vtn_tmp & (ia_reuse_num - 1);
    assign ia_reuse_num_act_comb = (r_mod == 0) ? ia_reuse_num : r_mod;

    assign last_cols_comb = SIZE - ((((n + SIZE - 1) >> LOG2_SIZE) << LOG2_SIZE) - n);
    assign rsp_beats_per_row_last_comb = ((last_cols_comb << (use_16bits ? 1 : 0)) + BYTE_PER_BEAT - 1) >> LOG2_BYTE_PER_BEAT;

    assign tmp_col_rem = (((k + SIZE - 1) >> LOG2_SIZE) << LOG2_SIZE) - k;
    assign rsp_rows_last_tile_comb = SIZE - tmp_col_rem;

    // =======================================================================
    // 配置参数锁存与派生参数计算（IDLE -> INIT）
    // =======================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_k                    <= '0;
            cfg_n                    <= '0;
            cfg_m                    <= '0;
            cfg_lhs_zp               <= '0;
            cfg_lhs_row_stride_b     <= '0;
            cfg_lhs_base             <= '0;
            cfg_use_16bits           <= '0;
            cfg_bias_by_row_mode     <= 1'b0;
            cfg_ia_reuse_num         <= '0;
            cfg_w_reuse_num          <= '0;

            horizontal_tile_num      <= '0;
            vertical_tile_num        <= '0;

            l2_group_num             <= '0;
            l1_per_l2                <= '0;
            ia_reuse_num_act         <= '0;

            rsp_beats_per_row_normal <= '0;
            rsp_beats_per_row_last   <= '0;
            rsp_rows_last_tile       <= '0;

            cfg_valid                <= 1'b0;
        end else if (state == IDLE && init_cfg) begin
            cfg_k <= k;
            cfg_n <= n;
            cfg_m <= m;
            cfg_lhs_zp <= lhs_zp;
            cfg_lhs_row_stride_b <= lhs_row_stride_b;
            cfg_lhs_base <= lhs_base;
            cfg_use_16bits <= use_16bits;
            cfg_bias_by_row_mode <= bias_by_row_mode;
            cfg_ia_reuse_num <= ia_reuse_num;
            cfg_w_reuse_num <= w_reuse_num;

            horizontal_tile_num <= (n + SIZE - 1) >> LOG2_SIZE;
            vertical_tile_num <= (k + SIZE - 1) >> LOG2_SIZE;

            l2_group_num <= (((k + SIZE - 1) >> LOG2_SIZE) + ia_reuse_num - 1) >> $clog2(
                ia_reuse_num
            );
            l1_per_l2 <= (n + SIZE - 1) >> LOG2_SIZE;
            ia_reuse_num_act <= ia_reuse_num_act_comb;
            rsp_beats_per_row_normal <= ((SIZE << (use_16bits ? 1 : 0)) + BYTE_PER_BEAT - 1) >> LOG2_BYTE_PER_BEAT;
            rsp_beats_per_row_last <= rsp_beats_per_row_last_comb;
            rsp_rows_last_tile <= rsp_rows_last_tile_comb;

            cfg_valid <= 1'b1;
        end else if (state == INIT) begin
            cfg_valid <= 1'b0;
        end
    end

    // =======================================================================
    // 子模块间连线
    // =======================================================================

    // ---- ctrl ↔ block_dma ----
    logic                                   tl_start;
    logic        [           REG_WIDTH-1:0] tl_base_addr;
    logic        [           REG_WIDTH-1:0] tl_row_stride;
    logic        [           REG_WIDTH-1:0] tl_rows_to_read;
    logic        [                     3:0] tl_burst_len_m1;
    logic        [$clog2(CACHE_BLOCKS)-1:0] tl_slot_id;
    logic                                   tl_use_16bits;
    logic signed [           REG_WIDTH-1:0] tl_lhs_zp;
    logic                                   tl_busy;
    logic                                   tl_tile_done;

    // ---- ctrl ↔ cache_mgr （L1组级接口）----
    logic                                   cache_l1_start;
    logic        [$clog2(CACHE_BLOCKS)-1:0] cache_l1_slot_start;
    logic        [$clog2(CACHE_BLOCKS)-1:0] cache_l1_slot_end;
    logic                                   cache_l1_is_init;
    logic                                   cache_l1_calc_done;
    logic        [        CACHE_BLOCKS-1:0] cache_blk_valid;
    logic        [           REG_WIDTH-1:0] cache_slot_rows     [ CACHE_BLOCKS];
    logic                                   cache_tile_done;
    logic                                   cache_l1_done;

    // ---- tile_loader ↔ cache_mgr（写端口）----
    logic        [$clog2(CACHE_BLOCKS)-1:0] tl_wr_slot;
    logic        [        $clog2(SIZE)-1:0] tl_wr_row;
    logic        [        $clog2(SIZE)-1:0] tl_wr_col_base;
    logic signed [          DATA_WIDTH-1:0] tl_wr_data          [BYTE_PER_BEAT];
    logic                                   tl_wr_valid         [BYTE_PER_BEAT];
    logic                                   tl_wr_use_16bits;

    // ctrl init_start 信号
    logic                                   ctrl_init_start;
    assign ctrl_init_start          = cfg_valid;

    assign ext_dma_start            = tl_start;
    assign ext_dma_is_write         = 1'b0;
    assign ext_dma_linear_read_mode = 1'b0;
    assign ext_dma_base_addr        = tl_base_addr;
    assign ext_dma_row_stride       = tl_row_stride;
    assign ext_dma_rows_to_read     = tl_rows_to_read;
    assign ext_dma_burst_len_m1     = tl_burst_len_m1;
    assign ext_dma_slot_id          = tl_slot_id;
    assign ext_dma_use_16bits       = tl_use_16bits;
    assign ext_dma_lhs_zp           = tl_lhs_zp;

    // =======================================================================
    // ia_loader_ctrl 例化
    // =======================================================================
    ia_loader_ctrl #(
        .DATA_WIDTH  (DATA_WIDTH),
        .SIZE        (SIZE),
        .BUS_WIDTH   (BUS_WIDTH),
        .REG_WIDTH   (REG_WIDTH),
        .CACHE_BLOCKS(CACHE_BLOCKS)
    ) u_ctrl (
        .clk  (clk),
        .rst_n(rst_n),

        .cfg_valid           (ctrl_init_start),
        .cfg_k               (cfg_k),
        .cfg_n               (cfg_n),
        .cfg_m               (cfg_m),
        .cfg_use_16bits      (cfg_use_16bits),
        .cfg_bias_by_row_mode(cfg_bias_by_row_mode),
        .cfg_lhs_base        (cfg_lhs_base),
        .cfg_lhs_row_stride_b(cfg_lhs_row_stride_b),
        .cfg_lhs_zp          (cfg_lhs_zp),
        .cfg_ia_reuse_num    (cfg_ia_reuse_num),
        .cfg_w_reuse_num     (cfg_w_reuse_num),

        .horizontal_tile_num     (horizontal_tile_num),
        .vertical_tile_num       (vertical_tile_num),
        .l2_group_num            (l2_group_num),
        .l1_per_l2               (l1_per_l2),
        .ia_reuse_num_act        (ia_reuse_num_act),
        .rsp_beats_per_row_normal(rsp_beats_per_row_normal),
        .rsp_beats_per_row_last  (rsp_beats_per_row_last),
        .rsp_rows_last_tile      (rsp_rows_last_tile),

        .init_start     (ctrl_init_start),
        .load_ia_req    (load_ia_req),
        .load_ia_granted(load_ia_granted),
        .send_ia_trigger(send_ia_trigger),
        .ia_data_valid  (ia_data_valid),
        .ia_sending_done(ia_sending_done),
        .ia_l1_switch   (ia_l1_switch),
        .bias_sleep     (bias_sleep),
        .bias_switch    (bias_switch),
        .bias_last_loop (bias_last_loop),
        .all_done       (ctrl_all_done),

        .tl_start       (tl_start),
        .tl_base_addr   (tl_base_addr),
        .tl_row_stride  (tl_row_stride),
        .tl_rows_to_read(tl_rows_to_read),
        .tl_burst_len_m1(tl_burst_len_m1),
        .tl_slot_id     (tl_slot_id),
        .tl_use_16bits  (tl_use_16bits),
        .tl_lhs_zp      (tl_lhs_zp),
        .tl_busy        (tl_busy),
        .tl_tile_done   (tl_tile_done),

        .cache_l1_start     (cache_l1_start),
        .cache_l1_slot_start(cache_l1_slot_start),
        .cache_l1_slot_end  (cache_l1_slot_end),
        .cache_l1_is_init   (cache_l1_is_init),
        .cache_l1_calc_done (cache_l1_calc_done),
        .cache_blk_valid    (cache_blk_valid),
        .cache_slot_rows    (cache_slot_rows),
        .cache_tile_done    (cache_tile_done),
        .cache_l1_done      (cache_l1_done)
    );

    logic ia_group_calc_done_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ia_group_calc_done_r <= 1'b0;
        end else if (state == IDLE || state == INIT) begin
            ia_group_calc_done_r <= 1'b0;
        end else if (cache_l1_start) begin
            ia_group_calc_done_r <= cache_l1_calc_done;
        end else if (cache_l1_done) begin
            ia_group_calc_done_r <= 1'b0;
        end
    end

    assign ia_group_calc_done = cache_l1_start ? cache_l1_calc_done : ia_group_calc_done_r;

    // =======================================================================
    // DMA 接入：单模块测试保留内建 DMA，顶层集成复用共享 block_dma
    // =======================================================================
    generate
        if (EXTERNAL_DMA) begin : gen_external_dma
            assign icb_cmd_valid    = 1'b0;
            assign icb_cmd_read     = 1'b1;
            assign icb_cmd_addr     = '0;
            assign icb_cmd_len      = '0;
            assign icb_rsp_ready    = 1'b0;
            assign tl_busy          = ext_dma_busy;
            assign tl_tile_done     = ext_dma_done;
            assign tl_wr_slot       = ext_dma_wr_slot;
            assign tl_wr_row        = ext_dma_wr_row;
            assign tl_wr_col_base   = ext_dma_wr_col_base;
            assign tl_wr_use_16bits = ext_dma_wr_use_16bits;
            for (genvar dma_i = 0; dma_i < BYTE_PER_BEAT; dma_i++) begin : gen_ext_wr
                assign tl_wr_data[dma_i]  = ext_dma_wr_data[dma_i];
                assign tl_wr_valid[dma_i] = ext_dma_wr_valid[dma_i];
            end
        end else begin : gen_internal_dma
            block_dma #(
                .DATA_WIDTH  (DATA_WIDTH),
                .SIZE        (SIZE),
                .BUS_WIDTH   (BUS_WIDTH),
                .REG_WIDTH   (REG_WIDTH),
                .CACHE_BLOCKS(CACHE_BLOCKS)
            ) u_block_dma (
                .clk  (clk),
                .rst_n(rst_n),

                .start           (tl_start),
                .is_write        (1'b0),
                .linear_read_mode(1'b0),
                .tile_base_addr  (tl_base_addr),
                .row_stride      (tl_row_stride),
                .rows_to_read    (tl_rows_to_read),
                .burst_len_m1    (tl_burst_len_m1),
                .slot_id         (tl_slot_id),
                .use_16bits      (tl_use_16bits),
                .lhs_zp          (tl_lhs_zp),
                .busy            (tl_busy),
                .tile_done       (tl_tile_done),

                .src_wdata ('0),
                .src_wmask ('0),
                .src_wvalid(1'b0),
                .src_wready(),

                .icb_cmd_valid(icb_cmd_valid),
                .icb_cmd_ready(icb_cmd_ready),
                .icb_cmd_read (icb_cmd_read),
                .icb_cmd_addr (icb_cmd_addr),
                .icb_cmd_len  (icb_cmd_len),
                .icb_cmd_wdata(),
                .icb_cmd_wmask(),
                .icb_w_valid  (),
                .icb_w_ready  (1'b1),
                .icb_rsp_valid(icb_rsp_valid),
                .icb_rsp_ready(icb_rsp_ready),
                .icb_rsp_rdata(icb_rsp_rdata),
                .icb_rsp_err  (icb_rsp_err),

                .wr_slot        (tl_wr_slot),
                .wr_row         (tl_wr_row),
                .wr_col_base    (tl_wr_col_base),
                .wr_data        (tl_wr_data),
                .wr_valid       (tl_wr_valid),
                .wr_use_16bits  (tl_wr_use_16bits),
                .rd_raw_data    (),
                .rd_raw_valid   (),
                .rd_raw_row     (),
                .rd_raw_col_base()
            );
        end
    endgenerate

    // =======================================================================
    // 缓存管理子模块例化
    // =======================================================================
    ia_loader_cache_mgr #(
        .DATA_WIDTH  (DATA_WIDTH),
        .SIZE        (SIZE),
        .BUS_WIDTH   (BUS_WIDTH),
        .REG_WIDTH   (REG_WIDTH),
        .CACHE_BLOCKS(CACHE_BLOCKS)
    ) u_cache_mgr (
        .clk  (clk),
        .rst_n(rst_n),

        // ---- 写入端（来自 tile_loader）----
        .wr_slot      (tl_wr_slot),
        .wr_row       (tl_wr_row),
        .wr_col_base  (tl_wr_col_base),
        .wr_data      (tl_wr_data),
        .wr_valid     (tl_wr_valid),
        .wr_use_16bits(tl_wr_use_16bits),

        // ---- L1组发送控制（来自 ctrl）----
        .l1_start     (cache_l1_start),
        .l1_slot_start(cache_l1_slot_start),
        .l1_slot_end  (cache_l1_slot_end),
        .l1_is_init   (cache_l1_is_init),
        .l1_calc_done (cache_l1_calc_done),
        .blk_valid_in (cache_blk_valid),
        .slot_rows    (cache_slot_rows),
        .tile_done    (cache_tile_done),
        .l1_done      (cache_l1_done),
        .ia_tile_start(ia_tile_start),

        // ---- 输出到脉动阵列 ----
        .ia_out         (ia_out),
        .ia_row_valid   (ia_row_valid),
        .ia_is_init_data(ia_is_init_data),
        .ia_calc_done   (ia_calc_done)
    );

endmodule
