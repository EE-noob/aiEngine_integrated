/*
 * ia_loader_ctrl — 缓存调度与发送控制
 * ============================================================
 * 功能：
 *   1. 管理 CACHE_BLOCKS 个 cache block 的状态表（valid/busy）
 *   2. 维护 L2/L1/W/IA 循环计数器
 *   3. 计算 tile 基地址，下发加载命令给 tile_loader
 *   4. 生成 ia_data_valid，协调 send_ia_trigger → cache_send_start
 *   5. 支持 load-send overlap：加载下一组 tile 的同时可发送已就绪的 tile
 *   6. 早期释放：tile 完成最后一次 reuse 后立即释放 slot
 *
 * 核心思想：
 *   - 原始 v1.1 是 LOAD-all-then-SEND-all（串行）
 *   - 新版本：一个 tile 加载完成就可以开始发送（不等待整组 R 个 tile 全部加完）
 *   - 每次发送完成后检查：下一个要发送的 tile 是否已在缓存中（valid）
 *     如果是 → 立即 ia_data_valid
 *     如果否 → 等待 tile_loader 完成后再 ia_data_valid
 *   - 每次发送完成后检查：该 slot 是否还需要 reuse
 *     如果不需要 → 立即释放该 slot（标记 free）
 */

module ia_loader_ctrl #(
    parameter int unsigned DATA_WIDTH   = 16,
    parameter int unsigned SIZE         = 16,
    parameter int unsigned BUS_WIDTH    = 32,
    parameter int unsigned REG_WIDTH    = 32,
    parameter int unsigned CACHE_BLOCKS = 4,
    parameter int unsigned PS_FRAME_COUNT = SIZE
) (
    input  logic clk,
    input  logic rst_n,

    // ---- 来自 top：配置参数（已锁存）----
    input  logic                        cfg_valid,       // 参数有效（INIT 状态）
    input  logic [REG_WIDTH-1:0]        cfg_k,
    input  logic [REG_WIDTH-1:0]        cfg_n,
    input  logic                        cfg_use_16bits,
    input  logic                        cfg_bias_by_row_mode,
    input  logic [REG_WIDTH-1:0]        cfg_lhs_base,
    input  logic [REG_WIDTH-1:0]        cfg_lhs_row_stride_b,
    input  logic signed [REG_WIDTH-1:0] cfg_lhs_zp,
    input  logic [REG_WIDTH-1:0]        cfg_ia_reuse_num,  // R
    input  logic [REG_WIDTH-1:0]        cfg_w_reuse_num,   // W

    // ---- 派生参数（from top）----
    input  logic [REG_WIDTH-1:0]        horizontal_tile_num,
    input  logic [REG_WIDTH-1:0]        vertical_tile_num,
    input  logic [REG_WIDTH-1:0]        l2_group_num,
    input  logic [REG_WIDTH-1:0]        l1_per_l2,
    input  logic [REG_WIDTH-1:0]        ia_reuse_num_act,
    input  logic [REG_WIDTH-1:0]        output_col_tile_num,
    input  logic [REG_WIDTH-1:0]        w_groups_total,
    input  logic [REG_WIDTH-1:0]        w_group_last_width,
    input  logic [REG_WIDTH-1:0]        rsp_beats_per_row_normal,
    input  logic [REG_WIDTH-1:0]        rsp_beats_per_row_last,
    input  logic [REG_WIDTH-1:0]        rsp_rows_last_tile,

    // ---- 顶层握手 ----
    input  logic                        init_start,     // 从 IDLE→INIT 的触发
    output logic                        load_ia_req,
    input  logic                        load_ia_granted,
    input  logic                        send_ia_trigger,
    output logic                        ia_data_valid,
    output logic                        ia_sending_done,
    output logic                        ia_l1_switch,
    output logic                        bias_sleep,
    output logic                        bias_switch,
    output logic                        bias_last_loop,
    output logic                        all_done,       // 全部完成，回 IDLE

    // ---- tile_loader 接口 ----
    output logic                        tl_start,
    output logic [REG_WIDTH-1:0]        tl_base_addr,
    output logic [REG_WIDTH-1:0]        tl_row_stride,
    output logic [REG_WIDTH-1:0]        tl_rows_to_read,
    output logic [REG_WIDTH-1:0]        tl_valid_cols,
    output logic [3:0]                  tl_burst_len_m1,
    output logic [$clog2(CACHE_BLOCKS)-1:0] tl_slot_id,
    output logic                        tl_use_16bits,
    output logic signed [REG_WIDTH-1:0] tl_lhs_zp,
    input  logic                        tl_busy,
    input  logic                        tl_tile_done,

    // ---- cache_mgr 发送接口（L1组级别）----
    output logic                              cache_l1_start,       // L1组发送启动脉冲
    output logic [$clog2(CACHE_BLOCKS)-1:0]   cache_l1_slot_start,  // 起始 slot
    output logic [$clog2(CACHE_BLOCKS)-1:0]   cache_l1_slot_end,    // 终止 slot（含，支持回绕）
    output logic                              cache_l1_is_init,     // L1 组 is_init 标记
    output logic                              cache_l1_calc_done,   // L1 组 calc_done 标记
    output logic [CACHE_BLOCKS-1:0]           cache_blk_valid,      // slot 有效状态总线
    output logic [REG_WIDTH-1:0]              cache_slot_rows [CACHE_BLOCKS], // 每 slot 有效行数
    input  logic                              cache_tile_done,      // 单 tile 输出完成
    input  logic                              cache_l1_done         // L1 组全部输出完成
);

  // =====================================================================
  // 局部参数
  // =====================================================================
  localparam int LOG2_SIZE     = $clog2(SIZE);
  localparam int BYTE_PER_BEAT = BUS_WIDTH / 8;
  localparam int LOG2_BPB      = $clog2(BYTE_PER_BEAT);
  localparam int SLOT_W        = $clog2(CACHE_BLOCKS);
  localparam int LOAD_CNT_W    = $clog2(CACHE_BLOCKS + 1);
  localparam int W_CNT_W       = (PS_FRAME_COUNT <= 1) ? 1 : ($clog2(PS_FRAME_COUNT) + 1);

  // =====================================================================
  // 状态机
  // =====================================================================
  typedef enum logic [2:0] {
    S_IDLE    = 3'b000,
    S_INIT    = 3'b001,
    S_LOAD    = 3'b010,  // 正在加载（可能同时发送）
    S_SEND    = 3'b011,  // 纯发送（当前无需再加载）
    S_DONE    = 3'b100
  } state_t;

  state_t state, state_nxt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else        state <= state_nxt;
  end

  // =====================================================================
  // IA tile 行步进。配置要求 reuse 为 2 的幂，用移位代替动态乘法。
  // =====================================================================
  logic [REG_WIDTH-1:0] tile_row_step_b;
  logic [REG_WIDTH-1:0] l2_group_row_step_b;
  logic [REG_WIDTH-1:0] tile_row_step_b_comb;
  logic [REG_WIDTH-1:0] l2_group_row_step_b_comb;

  assign tile_row_step_b_comb = cfg_lhs_row_stride_b << LOG2_SIZE;

  always_comb begin
    unique case (cfg_ia_reuse_num)
      REG_WIDTH'(1):  l2_group_row_step_b_comb = tile_row_step_b_comb;
      REG_WIDTH'(2):  l2_group_row_step_b_comb = tile_row_step_b_comb << 1;
      REG_WIDTH'(4):  l2_group_row_step_b_comb = tile_row_step_b_comb << 2;
      REG_WIDTH'(8):  l2_group_row_step_b_comb = tile_row_step_b_comb << 3;
      REG_WIDTH'(16): l2_group_row_step_b_comb = tile_row_step_b_comb << 4;
      REG_WIDTH'(32): l2_group_row_step_b_comb = tile_row_step_b_comb << 5;
      REG_WIDTH'(64): l2_group_row_step_b_comb = tile_row_step_b_comb << 6;
      default:        l2_group_row_step_b_comb = tile_row_step_b_comb;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tile_row_step_b     <= '0;
      l2_group_row_step_b <= '0;
    end else if (state == S_IDLE && init_start) begin
      tile_row_step_b     <= tile_row_step_b_comb;
      l2_group_row_step_b <= l2_group_row_step_b_comb;
    end
  end

  // =====================================================================
  // Cache Block 状态表
  // =====================================================================
  // valid: 数据已加载完毕，可供读取
  // busy:  正在被发送使用中（不可覆写）
  logic blk_valid [CACHE_BLOCKS];
  logic blk_busy  [CACHE_BLOCKS];

  // =====================================================================
  // 循环计数器
  // =====================================================================
  logic [REG_WIDTH-1:0] l2_idx;
  logic [REG_WIDTH-1:0] l1_idx;
  logic [REG_WIDTH-1:0] w_group_idx;
  logic [REG_WIDTH-1:0] w_cnt;
  logic [REG_WIDTH-1:0] ia_idx;

  // =====================================================================
  // 加载跟踪
  // =====================================================================
  logic [REG_WIDTH-1:0] load_ia_cursor;    // 当前 L1 组中正在加载第几个 tile（0..r_cur-1）
  logic [REG_WIDTH-1:0] load_tiles_done;   // 当前 L1 组中已加载完成的 tile 数

  // slot 分配
  logic [SLOT_W-1:0] wr_slot_ptr;          // 下一个写入slot
  logic [SLOT_W-1:0] rd_slot_base;         // 当前 L1 组的读基地址

  // =====================================================================
  // Prefetch: 在最后一次 reuse 期间，提前加载下一 L1 组
  // =====================================================================
  logic is_final_l1_group;                  // 没有后续 L1 组可预取
  logic is_last_l2_group;
  logic is_last_w_group;
  logic is_last_l1_group;
  logic [REG_WIDTH-1:0] l2_group_last_idx;
  logic [REG_WIDTH-1:0] w_group_last_idx;
  logic [REG_WIDTH-1:0] l1_last_idx;
  logic [REG_WIDTH-1:0] last_col_tile_idx;
  logic [REG_WIDTH-1:0] last_col_valid_cols;
  logic [REG_WIDTH-1:0] next_l1_idx;        // 下一 L1 组的列索引
  logic [REG_WIDTH-1:0] next_w_group_idx;   // 下一输出列组索引
  logic                 next_group_advances_l2; // 下一 L1 组是否跨到新的 L2 行组
  logic                 next_group_is_last_l2;  // 下一 L1 组是否属于最后一个 L2 行组
  logic [REG_WIDTH-1:0] next_r_cur;         // 下一组的 R 上界
  logic [REG_WIDTH-1:0] next_l2_row_base;   // 下一组的 L2 行基地址
  logic [REG_WIDTH-1:0] pf_tile_col_byte_offset; // 下一组列字节偏移
  logic can_prefetch;                       // 预取条件成立（组合）
  logic prefetch_active;                    // 预取模式已激活（寄存器）
  logic prefetch_entering;                  // 预取进入脉冲
  logic can_overlap_prefetch;                // 当前配置下 cache 可同时容纳当前组和下一组
  logic [SLOT_W-1:0] pf_rd_slot_base;       // 下一组的读基地址
  logic [REG_WIDTH-1:0] pf_r_target;         // 预取组的 R 上界，进入预取时锁存
  logic retirement_l1;                      // L1 组退休条件
  logic [REG_WIDTH-1:0] load_r_target;      // 当前加载的 R 目标
  logic [REG_WIDTH-1:0] w_cur_r;
  logic [REG_WIDTH-1:0] first_w_group_width;
  logic [REG_WIDTH-1:0] next_w_group_width;
  logic                 load_l2_is_last;     // 当前加载批次是否为最后一个 L2 行组

  // =====================================================================
  // L1 连续输出控制
  // =====================================================================
  logic in_l1_output;              // L1 组输出进行中（l1_start 后 → cache_l1_done 前）
  logic [SLOT_W-1:0] next_rd_slot; // 下一个要发送的 slot（用于 blk_busy 管理）

  // =====================================================================
  // 派生计算
  // =====================================================================
  // 当前 L2 组的 R 上界
  logic [REG_WIDTH-1:0] r_cur;
  assign r_cur = is_last_l2_group ? ia_reuse_num_act : cfg_ia_reuse_num;

  logic [LOG2_SIZE-1:0] cfg_n_tail_cols;
  assign cfg_n_tail_cols = cfg_n[LOG2_SIZE-1:0];

  // W 上界（最后一个输出列组可能不足 cfg_w_reuse_num）
  logic [REG_WIDTH-1:0] w_cur;
  assign w_cur = w_cur_r;

  logic ia_iter_last;
  logic w_iter_last;
  logic ia_iter_last_narrow;
  logic w_iter_last_narrow;
  logic retirement_l1_guard;
  logic [LOAD_CNT_W-1:0] ia_idx_cnt;
  logic [LOAD_CNT_W-1:0] r_cur_cnt;
  logic [W_CNT_W-1:0] w_cnt_narrow;
  logic [W_CNT_W-1:0] w_cur_narrow;
  assign ia_iter_last = (ia_idx == r_cur - 1);
  assign w_iter_last  = (w_cnt == w_cur - 1);
  assign ia_idx_cnt = ia_idx[LOAD_CNT_W-1:0];
  assign r_cur_cnt = r_cur[LOAD_CNT_W-1:0];
  assign w_cnt_narrow = w_cnt[W_CNT_W-1:0];
  assign w_cur_narrow = w_cur[W_CNT_W-1:0];
  assign ia_iter_last_narrow = ((ia_idx_cnt + LOAD_CNT_W'(1)) == r_cur_cnt);
  assign w_iter_last_narrow = ((w_cnt_narrow + W_CNT_W'(1)) == w_cur_narrow);

  always_comb begin
    first_w_group_width = (w_groups_total <= REG_WIDTH'(1))
                        ? w_group_last_width
                        : cfg_w_reuse_num;
    if (first_w_group_width == '0)
      first_w_group_width = REG_WIDTH'(1);

    if (is_last_w_group) begin
      next_w_group_width = (w_group_last_idx == '0)
                         ? w_group_last_width
                         : cfg_w_reuse_num;
    end else if ((w_group_idx + REG_WIDTH'(1)) == w_group_last_idx) begin
      next_w_group_width = w_group_last_width;
    end else begin
      next_w_group_width = cfg_w_reuse_num;
    end
    if (next_w_group_width == '0)
      next_w_group_width = REG_WIDTH'(1);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_cur_r <= REG_WIDTH'(1);
    end else if (state == S_IDLE && init_start) begin
      w_cur_r <= first_w_group_width;
    end else if ((state == S_SEND || state == S_LOAD) && cache_tile_done &&
                 ia_iter_last && w_iter_last && is_last_l1_group) begin
      w_cur_r <= next_w_group_width;
    end
  end

  // =====================================================================
  // Loop-boundary flags
  // =====================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      l2_group_last_idx <= '0;
      w_group_last_idx  <= '0;
      l1_last_idx       <= '0;
      last_col_tile_idx <= '0;
      last_col_valid_cols <= REG_WIDTH'(SIZE);
      is_last_l2_group  <= 1'b1;
      is_last_w_group   <= 1'b1;
      is_last_l1_group  <= 1'b1;
    end else if (state == S_IDLE && init_start) begin
      l2_group_last_idx <= (l2_group_num <= REG_WIDTH'(1)) ? '0 : (l2_group_num - REG_WIDTH'(1));
      w_group_last_idx  <= (w_groups_total <= REG_WIDTH'(1)) ? '0 : (w_groups_total - REG_WIDTH'(1));
      l1_last_idx       <= (l1_per_l2 <= REG_WIDTH'(1)) ? '0 : (l1_per_l2 - REG_WIDTH'(1));
      last_col_tile_idx <= (horizontal_tile_num <= REG_WIDTH'(1)) ? '0 : (horizontal_tile_num - REG_WIDTH'(1));
      last_col_valid_cols <= (cfg_n_tail_cols == '0) ? REG_WIDTH'(SIZE) : REG_WIDTH'(cfg_n_tail_cols);
      is_last_l2_group  <= (l2_group_num <= REG_WIDTH'(1));
      is_last_w_group   <= (w_groups_total <= REG_WIDTH'(1));
      is_last_l1_group  <= (l1_per_l2 <= REG_WIDTH'(1));
    end else if (state == S_INIT) begin
      is_last_l2_group <= (l2_group_last_idx == '0);
      is_last_w_group  <= (w_group_last_idx == '0);
      is_last_l1_group <= (l1_last_idx == '0);
    end else if ((state == S_SEND || state == S_LOAD) && cache_tile_done &&
                 ia_iter_last && w_iter_last) begin
      if (!is_last_l1_group) begin
        is_last_l1_group <= ((l1_idx + REG_WIDTH'(1)) == l1_last_idx);
      end else begin
        is_last_l1_group <= (l1_last_idx == '0);
        if (!is_last_w_group) begin
          is_last_w_group <= ((w_group_idx + REG_WIDTH'(1)) == w_group_last_idx);
        end else begin
          is_last_w_group <= (w_group_last_idx == '0);
          if (!is_last_l2_group) begin
            is_last_l2_group <= ((l2_idx + REG_WIDTH'(1)) == l2_group_last_idx);
          end
        end
      end
    end
  end

  // tile 行列坐标
  logic [REG_WIDTH-1:0] tile_row_idx;
  logic [REG_WIDTH-1:0] tile_col_idx;
  logic [REG_WIDTH-1:0] l2_tile_row_base;
  always_comb begin
    tile_row_idx = l2_tile_row_base + ia_idx;
    tile_col_idx = l1_idx;
  end

  logic is_last_col_tile, is_last_row_tile, is_first_tile;
  assign is_last_col_tile = (tile_col_idx == last_col_tile_idx);
  assign is_last_row_tile = (tile_row_idx == vertical_tile_num - 1);
  assign is_first_tile    = (l1_idx == 0);

  logic load_is_last_row_tile;
  logic [LOAD_CNT_W-1:0] load_ia_cursor_cnt;
  logic [LOAD_CNT_W-1:0] load_tiles_done_cnt;
  logic [LOAD_CNT_W-1:0] load_r_target_cnt;
  assign load_ia_cursor_cnt = load_ia_cursor[LOAD_CNT_W-1:0];
  assign load_tiles_done_cnt = load_tiles_done[LOAD_CNT_W-1:0];
  assign load_r_target_cnt = load_r_target[LOAD_CNT_W-1:0];
  assign load_is_last_row_tile = load_l2_is_last &&
                                 ((load_ia_cursor_cnt + LOAD_CNT_W'(1)) == load_r_target_cnt);
  logic load_is_last_col_tile;
  assign load_is_last_col_tile = prefetch_active ?
    (next_l1_idx == last_col_tile_idx) :
    (tile_col_idx == last_col_tile_idx);

  // 有效行数
  logic [REG_WIDTH-1:0] send_valid_rows;
  assign send_valid_rows = is_last_row_tile ? rsp_rows_last_tile : REG_WIDTH'(SIZE);

  logic [REG_WIDTH-1:0] load_rows_cur;
  assign load_rows_cur = load_is_last_row_tile ? rsp_rows_last_tile : REG_WIDTH'(SIZE);

  logic [REG_WIDTH-1:0] load_cols_cur;
  assign load_cols_cur = load_is_last_col_tile ? last_col_valid_cols : REG_WIDTH'(SIZE);

  // burst 长度
  logic [3:0] load_burst_len_m1;
  assign load_burst_len_m1 = load_is_last_col_tile ? 
                             rsp_beats_per_row_last[3:0] - 4'd1 : 
                             rsp_beats_per_row_normal[3:0] - 4'd1;

  // 当前读 slot = rd_slot_base + ia_idx
  logic [SLOT_W-1:0] current_rd_slot;
  assign current_rd_slot = rd_slot_base + ia_idx[SLOT_W-1:0];

  // 下一个要发送的 slot（用于 blk_busy 管理）
  assign next_rd_slot = rd_slot_base + SLOT_W'(ia_idx + 1);

  // slot_rows_reg: 存储每个 slot 的有效行数，在 tl_tile_done 时写入
  logic [REG_WIDTH-1:0] slot_rows_reg [CACHE_BLOCKS];

  // =====================================================================
  // L2 行基地址
  // =====================================================================
  logic [REG_WIDTH-1:0] l2_row_base;
  logic                 l2_group_retire;

  assign l2_group_retire = (state == S_SEND || state == S_LOAD) && cache_tile_done &&
                           ia_iter_last &&
                           w_iter_last &&
                           is_last_l1_group &&
                           is_last_w_group;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      l2_row_base <= '0;
      l2_tile_row_base <= '0;
    end else if (state == S_IDLE && init_start) begin
      l2_row_base <= cfg_lhs_base;
      l2_tile_row_base <= '0;
    end else if (l2_group_retire) begin
      l2_row_base <= l2_row_base + l2_group_row_step_b;
      l2_tile_row_base <= l2_tile_row_base + cfg_ia_reuse_num;
    end
  end

  // tile 基地址
  logic [REG_WIDTH-1:0] tile_col_byte_offset;
  assign tile_col_byte_offset = tile_col_idx << (LOG2_SIZE + (cfg_use_16bits ? 1 : 0));

  // prefetch 地址参数
  assign pf_tile_col_byte_offset = next_l1_idx << (LOG2_SIZE + (cfg_use_16bits ? 1 : 0));
  always_comb begin
    if (next_group_advances_l2)
      next_l2_row_base = l2_row_base + l2_group_row_step_b;
    else
      next_l2_row_base = l2_row_base;
  end

  logic [REG_WIDTH-1:0] computed_tile_base;
  logic [REG_WIDTH-1:0] load_cursor_row_base;
  assign computed_tile_base = load_cursor_row_base +
                              (prefetch_active ? pf_tile_col_byte_offset : tile_col_byte_offset);

  // =====================================================================
  // 加载触发逻辑
  // =====================================================================
  // load_r_target: 当前加载目标 R（prefetch 时为下一组的 R）
  assign load_r_target = prefetch_active ? pf_r_target : r_cur;

  // 当前加载批次的所有 tile 都已加载完
  logic l1_load_complete;
  assign l1_load_complete = (load_tiles_done_cnt == load_r_target_cnt);

  // 可以开始加载下一个 tile 的条件：
  //   1. tile_loader 空闲
  //   2. load_ia_cursor < load_r_target（还有 tile 需要加载）
  //   3. 目标 slot 空闲（!blk_busy 且 !blk_valid）
  //   4. 在 S_LOAD 状态，或在 S_SEND 且 prefetch 已激活
  //   5. 还没加载完所有 tile

  logic can_start_load;
  assign can_start_load = ((state == S_LOAD) || (state == S_SEND && prefetch_active))
                        && !tl_busy
                        && (load_ia_cursor_cnt < load_r_target_cnt)
                        && !blk_busy[wr_slot_ptr]
                        && !blk_valid[wr_slot_ptr]
                        && !l1_load_complete;

  // 当前是否存在待加载工作（用于维持 req 握手）
  logic load_need_active;
  assign load_need_active = (state == S_INIT)
                         || (((state == S_LOAD) || (state == S_SEND && prefetch_active))
                             && !l1_load_complete);

  // =====================================================================
  // 发送就绪逻辑
  // =====================================================================
  // 当前 ia_idx 要发送的 slot 是否 valid
  logic send_slot_ready;
  assign send_slot_ready = blk_valid[current_rd_slot];

  logic send_group_ready;
  always_comb begin
    send_group_ready = 1'b1;
    for (int gi = 0; gi < CACHE_BLOCKS; gi++) begin
      if (REG_WIDTH'(gi) < r_cur) begin
        send_group_ready &= blk_valid[rd_slot_base + SLOT_W'(gi)];
      end
    end
  end

  // =====================================================================
  // Prefetch 控制逻辑
  // =====================================================================
  // 是否为最后一个 L1 组（无后续组可预取）
  assign is_final_l1_group = is_last_l2_group &&
                             is_last_w_group &&
                             is_last_l1_group;

  // 下一 L1 组的列/L2 索引
  always_comb begin
    if (!is_last_l1_group) begin
      next_l1_idx = l1_idx + 1;
      next_w_group_idx = w_group_idx;
    end else if (!is_last_w_group) begin
      next_l1_idx = '0;
      next_w_group_idx = w_group_idx + 1;
    end else begin
      next_l1_idx = '0;
      next_w_group_idx = '0;
    end
  end

  assign next_group_advances_l2 = is_last_l1_group && is_last_w_group;
  assign next_group_is_last_l2 = is_last_l2_group ? 1'b1 :
                                 (next_group_advances_l2 ?
                                  ((l2_idx + REG_WIDTH'(1)) == l2_group_last_idx) :
                                  1'b0);
  assign next_r_cur = next_group_is_last_l2 ? ia_reuse_num_act : cfg_ia_reuse_num;

  // L1 组退休条件
  assign retirement_l1 = (state == S_SEND || state == S_LOAD) && cache_tile_done &&
                         ia_iter_last && w_iter_last;
  assign retirement_l1_guard = cache_tile_done &&
                               ia_iter_last_narrow &&
                               w_iter_last_narrow;

  // 缓冲区空余容量足以同时容纳当前组和下一组时，可从第一轮 W 复用起预取。
  // 合法配置要求 cfg_ia_reuse_num <= CACHE_BLOCKS/2；该条件只需在 init 锁存一次。
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      can_overlap_prefetch <= 1'b0;
    else if (state == S_IDLE && init_start)
      can_overlap_prefetch <= (cfg_ia_reuse_num <= REG_WIDTH'(CACHE_BLOCKS / 2));
  end

  // 可以进入预取的条件：
  //   - can_overlap_prefetch 成立 → 立即预取（第一轮 W 复用起）
  //   - 否则回退到最后一轮 W 复用时再预取
  assign can_prefetch = (state == S_SEND) && !is_final_l1_group &&
                        (can_overlap_prefetch || w_iter_last);

  // 预取进入脉冲。只避开 L1 退休拍，保留同组 tile 完成拍的重叠预取机会。
  assign prefetch_entering = can_prefetch && !prefetch_active && !retirement_l1_guard;

  // prefetch_active 寄存器
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      prefetch_active <= 1'b0;
    else if (state == S_IDLE || state == S_INIT)
      prefetch_active <= 1'b0;
    else if (prefetch_entering)
      prefetch_active <= 1'b1;
    else if (retirement_l1)
      prefetch_active <= 1'b0;
  end

  // 预取进入时保存 wr_slot_ptr 作为下一组的读基地址
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pf_rd_slot_base <= '0;
    else if (prefetch_entering)
      pf_rd_slot_base <= wr_slot_ptr;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pf_r_target <= REG_WIDTH'(1);
    else if (state == S_IDLE || state == S_INIT)
      pf_r_target <= REG_WIDTH'(1);
    else if (prefetch_entering)
      pf_r_target <= next_r_cur;
  end

  // =====================================================================
  // 主 FSM 次态逻辑
  // =====================================================================
  logic last_send;  // 最后一个 tile 发送完成
  assign last_send = is_final_l1_group &&
                     w_iter_last &&
                     ia_iter_last;

  always_comb begin
    state_nxt = state;
    case (state)
      S_IDLE: if (init_start) state_nxt = S_INIT;
      S_INIT: if (load_ia_granted) state_nxt = S_LOAD;

      S_LOAD: begin
        // 所有 tile 加载完且所有 tile 发送完 → 检查是否全部完成
        // （但在 overlap 模式下，发送和加载并行，所以需要在 S_SEND 中处理完成）
        // 当 L1 组加载完成且没有更多的发送：转到 S_SEND（纯发送模式）
        if (l1_load_complete)
          state_nxt = S_SEND;
      end

      S_SEND: begin
        if (cache_tile_done) begin
          if (last_send)
            state_nxt = S_DONE;
          // L1 组退休
          else if (ia_iter_last && w_iter_last) begin
            // 预取已完成全部下一组 tile → 跳过 S_LOAD 直接发送
            if (prefetch_active && l1_load_complete)
              state_nxt = S_SEND;
            else
              state_nxt = S_LOAD;
          end
          // 否则继续发送（同 L1 组内，cache_mgr 自主处理）
        end
      end

      S_DONE: state_nxt = S_IDLE;

      default: state_nxt = S_IDLE;
    endcase
  end

  assign all_done = (state == S_DONE);
  logic bias_switch_by_col;
  logic bias_switch_by_row;
  logic bias_switch_comb;
  logic bias_last_loop_comb;
  logic bias_switch_within_w_group;
  logic bias_switch_next_w_group;
  assign bias_switch_within_w_group = (l1_idx == '0) && !w_iter_last;
  assign bias_switch_next_w_group   = cache_l1_calc_done && w_iter_last;
  assign bias_switch_by_col = cache_l1_done &&
                              ia_iter_last &&
                              (output_col_tile_num > REG_WIDTH'(1)) &&
                              (bias_switch_within_w_group || bias_switch_next_w_group) &&
                              !last_send;
  assign bias_switch_by_row = cache_l1_done && cache_l1_calc_done &&
                              w_iter_last &&
                              is_last_w_group &&
                              ia_iter_last &&
                              !is_last_l2_group;

  assign bias_sleep  = (state == S_IDLE) ? 1'b1 : ~cache_l1_is_init;
  assign bias_switch_comb = cfg_bias_by_row_mode ? bias_switch_by_row : bias_switch_by_col;
  assign bias_last_loop_comb = (state != S_IDLE) && is_last_l2_group;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bias_switch    <= 1'b0;
      bias_last_loop <= 1'b0;
    end else begin
      bias_switch    <= bias_switch_comb;
      bias_last_loop <= bias_last_loop_comb;
    end
  end

  // =====================================================================
  // tile_loader 启动命令
  // =====================================================================
  // 仅在 req/granted 握手成功时，允许启动 tile_loader
  logic tl_start_r;
  logic can_issue_load;
  logic [REG_WIDTH-1:0] tl_base_addr_r;
  logic [REG_WIDTH-1:0] tl_row_stride_r;
  logic [REG_WIDTH-1:0] tl_rows_to_read_r;
  logic [REG_WIDTH-1:0] tl_valid_cols_r;
  logic [3:0]           tl_burst_len_m1_r;
  logic [SLOT_W-1:0]    tl_slot_id_r;
  logic                 tl_use_16bits_r;
  logic signed [REG_WIDTH-1:0] tl_lhs_zp_r;
  assign can_issue_load = can_start_load && load_ia_req && load_ia_granted;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tl_start_r        <= 1'b0;
      tl_base_addr_r    <= '0;
      tl_row_stride_r   <= '0;
      tl_rows_to_read_r <= '0;
      tl_valid_cols_r   <= '0;
      tl_burst_len_m1_r <= '0;
      tl_slot_id_r      <= '0;
      tl_use_16bits_r   <= 1'b0;
      tl_lhs_zp_r       <= '0;
    end else begin
      tl_start_r <= can_issue_load && !tl_start_r;
      if (can_issue_load && !tl_start_r) begin
        tl_base_addr_r    <= computed_tile_base;
        tl_row_stride_r   <= cfg_lhs_row_stride_b;
        tl_rows_to_read_r <= load_rows_cur;
        tl_valid_cols_r   <= load_cols_cur;
        tl_burst_len_m1_r <= load_burst_len_m1;
        tl_slot_id_r      <= wr_slot_ptr;
        tl_use_16bits_r   <= cfg_use_16bits;
        tl_lhs_zp_r       <= cfg_lhs_zp;
      end
    end
  end

  assign tl_start       = tl_start_r;
  assign tl_base_addr    = tl_base_addr_r;
  assign tl_row_stride   = tl_row_stride_r;
  assign tl_rows_to_read = tl_rows_to_read_r;
  assign tl_valid_cols   = tl_valid_cols_r;
  assign tl_burst_len_m1 = tl_burst_len_m1_r;
  assign tl_slot_id      = tl_slot_id_r;
  assign tl_use_16bits   = tl_use_16bits_r;
  assign tl_lhs_zp       = tl_lhs_zp_r;

  // =====================================================================
  // load_ia_cursor 与 load_tiles_done 管理
  // =====================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_ia_cursor      <= '0;
      load_tiles_done     <= '0;
      load_cursor_row_base <= '0;
      load_l2_is_last     <= 1'b1;
    end else begin
      // L1 组切换时重置（仅在非预取模式下；预取模式下计数器已切换到下一组）
      if (retirement_l1 && !prefetch_active) begin
        load_ia_cursor      <= '0;
        load_tiles_done     <= '0;
        load_cursor_row_base <= next_l2_row_base;
        load_l2_is_last     <= next_group_is_last_l2;
      end else if (state == S_INIT) begin
        load_ia_cursor      <= '0;
        load_tiles_done     <= '0;
        load_cursor_row_base <= cfg_lhs_base;
        load_l2_is_last     <= is_last_l2_group;
      end else if (prefetch_entering) begin
        // 进入预取模式：重置计数器，开始为下一组加载
        load_ia_cursor      <= '0;
        load_tiles_done     <= '0;
        load_cursor_row_base <= next_l2_row_base;
        load_l2_is_last     <= next_group_is_last_l2;
      end else if ((state == S_LOAD || state == S_SEND) && tl_tile_done) begin
        load_tiles_done     <= load_tiles_done + 1;
        load_ia_cursor      <= load_ia_cursor + 1;
        load_cursor_row_base <= load_cursor_row_base + tile_row_step_b;
      end
    end
  end

  // =====================================================================
  // slot 指针管理
  // =====================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_slot_ptr  <= '0;
      rd_slot_base <= '0;
    end else if (state == S_INIT) begin
      wr_slot_ptr  <= '0;
      rd_slot_base <= '0;
    end else begin
      // 写指针：每完成一个 tile 加载递增
      if (tl_tile_done)
        wr_slot_ptr <= wr_slot_ptr + 1;

      // 读基地址：L1 组退休时更新
      if (retirement_l1)
        rd_slot_base <= prefetch_active ? pf_rd_slot_base : wr_slot_ptr;
    end
  end

  // slot_rows_reg: 每个 slot 的有效行数，在 tile 加载完成时写入
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < CACHE_BLOCKS; i++)
        slot_rows_reg[i] <= REG_WIDTH'(SIZE);
    end else if (tl_tile_done) begin
      slot_rows_reg[wr_slot_ptr] <= tl_rows_to_read_r;
    end
  end

  // =====================================================================
  // Cache Block 状态表管理
  // =====================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < CACHE_BLOCKS; i++) begin
        blk_valid[i] <= 1'b0;
        blk_busy[i]  <= 1'b0;
      end
    end else if (state == S_INIT) begin
      for (int i = 0; i < CACHE_BLOCKS; i++) begin
        blk_valid[i] <= 1'b0;
        blk_busy[i]  <= 1'b0;
      end
    end else begin
      // tile_loader 完成加载 → 标记 valid
      if (tl_tile_done) begin
        blk_valid[tl_slot_id] <= 1'b1;
      end

      // L1组发送启动 → 标记第一个 tile 的 slot 为 busy
      if (cache_l1_start) begin
        blk_busy[cache_l1_slot_start] <= 1'b1;
      end

      // 单 tile 输出完成 → 取消当前 slot busy
      if (cache_tile_done) begin
        blk_busy[current_rd_slot] <= 1'b0;

        // 早期释放：如果这是该 slot 的最后一次 reuse，标记 invalid
        if (w_iter_last) begin
          blk_valid[current_rd_slot] <= 1'b0;
        end

        // 标记下一 tile 的 slot 为 busy（cache_mgr 将继续处理它）
        if (!ia_iter_last) begin
          blk_busy[next_rd_slot] <= 1'b1;
        end
      end
    end
  end

  // =====================================================================
  // 循环计数器管理
  // =====================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      l2_idx <= '0;
      l1_idx <= '0;
      w_group_idx <= '0;
      w_cnt  <= '0;
      ia_idx <= '0;
    end else if (state == S_INIT) begin
      l2_idx <= '0;
      l1_idx <= '0;
      w_group_idx <= '0;
      w_cnt  <= '0;
      ia_idx <= '0;
    end else if ((state == S_SEND || state == S_LOAD) && cache_tile_done) begin
      // 最内层 ia_idx 递增
      if (!ia_iter_last) begin
        ia_idx <= ia_idx + 1;
      end else begin
        ia_idx <= '0;
        if (!w_iter_last) begin
          w_cnt <= w_cnt + 1;
        end else begin
          w_cnt <= '0;
          if (!is_last_l1_group) begin
            l1_idx <= l1_idx + 1;
          end else begin
            l1_idx <= '0;
            if (!is_last_w_group) begin
              w_group_idx <= w_group_idx + 1;
            end else begin
              w_group_idx <= '0;
              if (!is_last_l2_group)
                l2_idx <= l2_idx + 1;
            end
          end
        end
      end
    end
  end

  // =====================================================================
  // cache_l1 信号生成
  // =====================================================================
  assign cache_l1_slot_start = rd_slot_base;
  assign cache_l1_slot_end   = rd_slot_base + SLOT_W'(r_cur - 1);  // 自然回绕
  assign cache_l1_is_init    = is_first_tile;
  assign cache_l1_calc_done  = is_last_l1_group;

  // 将内部状态暴露给 cache_mgr
  generate
    for (genvar gi = 0; gi < CACHE_BLOCKS; gi++) begin : g_cache_out
      assign cache_blk_valid[gi] = blk_valid[gi];
      assign cache_slot_rows[gi] = slot_rows_reg[gi];
    end
  endgenerate

  // =====================================================================
  // ia_data_valid — 组合逻辑
  // =====================================================================
  // 规则：L1 组的所有 R 个 slot 都已就绪 且 当前不在 L1 连续输出中。
  // 这样每个 reduction 阶段的同一组 IA 分块形态一致：要么整组连续输出，
  // 不会第一轮因只缓存到首块而 split、后一轮又变成 tall stream。
  assign ia_data_valid = (state == S_SEND || state == S_LOAD)
                       && send_group_ready
                       && !in_l1_output;

  // in_l1_output: send_ia_trigger 接受后置位，cache_l1_done 后清零
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      in_l1_output <= 1'b0;
    else if (state == S_IDLE || state == S_INIT)
      in_l1_output <= 1'b0;
    else if (send_ia_trigger && ia_data_valid)
      in_l1_output <= 1'b1;
    else if (cache_l1_done)
      in_l1_output <= 1'b0;
  end

  // cache_l1_start: 仅在外部 trigger 触发时发出（L1 组整体启动脉冲）
  // cache_mgr 收到后自主完成整组 r_cur 个 tile 的连续对角化输出
  assign cache_l1_start = (state == S_SEND || state == S_LOAD)
                        && send_ia_trigger && ia_data_valid;

  // =====================================================================
  // ia_sending_done — 每个 L1 组全部输出完成时拉高一拍
  // =====================================================================
  assign ia_sending_done = cache_l1_done;

  // ia_l1_switch：当前 L1 组最后一次输出后的切换边界脉冲
  // 仅在后续还会输出新的 L1 组时拉高，避免把最终收尾组误当成切换点。
  logic has_next_l1_group;
  assign has_next_l1_group = !last_send;
  assign ia_l1_switch      = cache_l1_done && has_next_l1_group;

  // =====================================================================
  // load_ia_req 生成 — 懒加载策略
  // =====================================================================
  // 规则：load_ia_req 是电平握手，存在待加载工作时持续拉高。
  // 只有 req 与 granted 同时有效时，才允许触发 tile_loader。
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_ia_req <= 1'b0;
    end else begin
      if (state == S_IDLE)
        load_ia_req <= 1'b0;
      else if (load_need_active)
        load_ia_req <= 1'b1;
      else
        load_ia_req <= 1'b0;
    end
  end

endmodule
