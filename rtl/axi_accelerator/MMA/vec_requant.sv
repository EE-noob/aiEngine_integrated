module vec_requant #(
    parameter int VLEN         = 16,
    parameter int REG_WIDTH    = 32,
    parameter int MAX_IA_REUSE = 2
) (
    input logic clk,
    input logic rst_n,

    // 配置
    input logic               init_cfg,
    input logic               cfg_per_channel,
    input logic               cfg_dataflow_mode,
    input logic signed [31:0] activation_min_in,
    input logic signed [31:0] activation_max_in,
    input logic signed [31:0] dst_offset_in,
    // per-tensor 常量；per-channel 下这两个做为“基地址”使用
    input logic signed [31:0] multiplier_in,
    input logic signed [31:0] shift_in,
    input logic        [31:0] k,                  // 行数
    input logic        [31:0] m,                  // 列数
    input logic        [31:0] ia_reuse_num_in,    // 输出 tile 行复用顺序

    // 量化参数装载握手（外部可用；TB里通常 grant=req）
    output logic load_quant_req,
    input  logic load_quant_granted,
    output logic quant_params_valid,

    // Native DMA read client for per-channel quant parameters.
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
    input  logic [REG_WIDTH-1:0]        dma_raw_data,
    input  logic                        dma_raw_valid,

    // 数据口
    input  logic               in_valid,
    input  logic               in_tile_done,
    input  logic signed [31:0] in_vec_s32[VLEN],
    output logic               out_valid,
    output logic               out_tile_done,
    output logic signed [ 7:0] out_vec_s8[VLEN]
);

  // ----------------------------
  // 常量与类型
  // ----------------------------
  localparam int BYTES_PER_WORD = REG_WIDTH / 8;  // 32位=4
  localparam int QBUF_DEPTH     = VLEN * MAX_IA_REUSE;
  localparam int QBUF_IDX_W     = (QBUF_DEPTH <= 1) ? 1 : $clog2(QBUF_DEPTH);
  localparam int VLEN_SHIFT     = $clog2(VLEN);
  localparam int VLEN_CNT_W     = (VLEN <= 1) ? 1 : $clog2(VLEN + 1);
  localparam int TILE_CNT_W     = (REG_WIDTH < 16) ? REG_WIDTH : 16;

  typedef logic [TILE_CNT_W-1:0] tile_idx_t;

  // ----------------------------
  // 状态机与游标
  // ----------------------------
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    COMPUTE
  } state_e;
  state_e state;

  // LOAD 内部用 phase 区分 mul/shift。
  typedef enum logic [0:0] {
    PH_MUL   = 1'b0,
    PH_SHIFT = 1'b1
  } phase_e;
  phase_e          load_phase;  // 当前子阶段（先 mul 后 shift）

  tile_idx_t       tile_col;  // 当前列 tile 号
  logic [VLEN_CNT_W-1:0] row_in_tile_cnt;  // 本 tile 已完成的行数
  logic     [31:0] lane_need_cur;  // 本 tile 需要的列数（尾块可能 < VLEN）
  logic     [31:0] quant_need_cur;  // 本 tile 需要加载的 per-channel 参数数
  logic     [31:0] quant_tile_idx_cur;
  tile_idx_t       tile_row;  // 当前行 tile 号
  logic     [31:0] rows_need_cur;  // 当前行 tile 需要的行数（最后一块为余数）
  logic     [31:0] lane_need_q;  // 锁存，用于计算/屏蔽无效 lane
  logic     [ 7:0] burst_len_cur;  // = lane_need_cur - 1
  tile_idx_t       reuse_group_base_row;
  tile_idx_t       row_offset_in_group;
  logic     [31:0] group_rows_need_cur;
  logic     [31:0] load_offset;
  logic     [31:0] chunk_need_cur;

  // per-channel：mul/shift 两次突发的采样计数
  logic [VLEN_CNT_W-1:0] rd_beats_cnt;
  logic [VLEN_CNT_W-1:0] beats_expect;
  logic            cmd_busy;
  logic            cmd_valid_r;
  logic [REG_WIDTH-1:0] cmd_base_addr_r;
  logic [7:0]     cmd_burst_len_m1_r;
  logic [VLEN_CNT_W-1:0] cmd_beats_expect_r;
  logic [REG_WIDTH-1:0] dma_base_addr_cur;
  logic            load_meta_valid;
  logic [31:0]     quant_need_load_r;
  logic [31:0]     quant_tile_idx_load_r;

  // track number of tiles & finished flag
  tile_idx_t       num_row_tiles_next;
  tile_idx_t       num_col_tiles_next;
  tile_idx_t       last_row_tile;
  tile_idx_t       last_col_tile;
  logic            all_tiles_done;
`ifndef SYNTHESIS
  bit              requant_trace_en;

  initial begin
    requant_trace_en = 1'b0;
    if ($test$plusargs("MMA_REQUANT_TRACE")) requant_trace_en = 1'b1;
  end
`else
  localparam bit requant_trace_en = 1'b0;
`endif

  // ----------------------------
  // 配置寄存
  // ----------------------------
  logic signed [31:0] pt_multiplier_r;  // per-tensor 常量
  logic [5:0]         pt_lshift_r, pt_rshift_r;
  logic [31:0] k_r, m_r;  // 锁存的尺寸
  logic [31:0] ia_reuse_num_r;
  logic        has_tiles_r;
  tile_idx_t   ia_reuse_mask_tile_r;
  logic [31:0] mul_base_r, sh_base_r;  // per-channel 基地址
  logic        is_mode_r;

  logic signed [31:0] pt_shift_abs_next;
  logic [5:0]         pt_lshift_next, pt_rshift_next;

  always_comb begin
    pt_shift_abs_next = -shift_in;
    pt_lshift_next = 6'd0;
    pt_rshift_next = 6'd0;
    if (shift_in > 32'sd0) begin
      pt_lshift_next = shift_in[5:0];
    end else if (shift_in < 32'sd0) begin
      pt_rshift_next = (pt_shift_abs_next > 32'sd63) ? 6'd63 : pt_shift_abs_next[5:0];
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pt_multiplier_r  <= '0;
      pt_lshift_r      <= 6'd0;
      pt_rshift_r      <= 6'd0;
      k_r              <= '0;
      m_r              <= '0;
      ia_reuse_num_r   <= 32'd1;
      has_tiles_r      <= 1'b0;
      ia_reuse_mask_tile_r <= '0;
      mul_base_r       <= '0;
      sh_base_r        <= '0;
      is_mode_r        <= 1'b0;
      last_row_tile    <= '0;
      last_col_tile    <= '0;
    end else if (init_cfg) begin
      pt_multiplier_r  <= multiplier_in;
      pt_lshift_r      <= pt_lshift_next;
      pt_rshift_r      <= pt_rshift_next;
      k_r              <= k;
      m_r              <= m;
      ia_reuse_num_r   <= (ia_reuse_num_in == 32'd0) ? 32'd1 : ia_reuse_num_in;
      has_tiles_r      <= (k != 32'd0) && (m != 32'd0);
      ia_reuse_mask_tile_r <= (ia_reuse_num_in <= 32'd1) ? '0 : tile_idx_t'(ia_reuse_num_in - 32'd1);
      // per-channel 基地址（接口复用 multiplier_in/shift_in）
      mul_base_r       <= multiplier_in;
      sh_base_r        <= shift_in;
      is_mode_r        <= cfg_dataflow_mode;
      last_row_tile    <= (num_row_tiles_next == '0) ? '0 : (num_row_tiles_next - tile_idx_t'(1));
      last_col_tile    <= (num_col_tiles_next == '0) ? '0 : (num_col_tiles_next - tile_idx_t'(1));
    end
  end

  // compute number of tiles once at configuration time
  assign num_row_tiles_next = (k == 0) ? '0 : tile_idx_t'((k + VLEN - 1) >> VLEN_SHIFT);
  assign num_col_tiles_next = (m == 0) ? '0 : tile_idx_t'((m + VLEN - 1) >> VLEN_SHIFT);

  // ----------------------------
  // tile 列需要多少 lane（尾块）
  // ----------------------------
  logic [31:0] lane_start_cur;
  logic [31:0] row_start_cur;
  logic [31:0] lane_remaining_cur;
  logic [31:0] rows_remaining_cur;
  logic [31:0] reuse_group_row_start;
  logic [31:0] reuse_group_capacity;
  logic [31:0] group_rows_remaining_cur;
  tile_idx_t   tile_row_inc;
  tile_idx_t   tile_col_inc;
  tile_idx_t   next_tile_row_cur;
  tile_idx_t   next_tile_col_cur;
  logic        final_tile_cur;
  logic        next_same_quant_group_cur;
  logic        cur_last_row_tile;
  logic        cur_last_col_tile;
  logic        cur_last_row_in_group;
  logic        step_row_in_group;
  logic        step_col_in_group;
  logic        step_next_group;

  // 每次进入 LOAD 前计算 lane_need\row_need
  always_comb begin
    lane_start_cur = REG_WIDTH'(tile_col) << VLEN_SHIFT;
    row_start_cur  = REG_WIDTH'(tile_row) << VLEN_SHIFT;
    lane_remaining_cur = (m_r > lane_start_cur) ? (m_r - lane_start_cur) : 32'd0;
    rows_remaining_cur = (k_r > row_start_cur) ? (k_r - row_start_cur) : 32'd0;
    lane_need_cur = (lane_remaining_cur >= REG_WIDTH'(VLEN))
                  ? REG_WIDTH'(VLEN)
                  : lane_remaining_cur;
    rows_need_cur = (rows_remaining_cur >= REG_WIDTH'(VLEN))
                  ? REG_WIDTH'(VLEN)
                  : rows_remaining_cur;

    reuse_group_base_row = tile_row & ~ia_reuse_mask_tile_r;
    row_offset_in_group  = tile_row & ia_reuse_mask_tile_r;
    reuse_group_row_start = REG_WIDTH'(reuse_group_base_row) << VLEN_SHIFT;
    reuse_group_capacity  = ia_reuse_num_r << VLEN_SHIFT;
    group_rows_remaining_cur = (k_r > reuse_group_row_start)
                             ? (k_r - reuse_group_row_start)
                             : 32'd0;
    group_rows_need_cur  = (group_rows_remaining_cur >= reuse_group_capacity)
                         ? reuse_group_capacity
                         : group_rows_remaining_cur;
    quant_need_cur       = is_mode_r ? group_rows_need_cur : lane_need_cur;
    quant_tile_idx_cur   = is_mode_r ? REG_WIDTH'(reuse_group_base_row) : REG_WIDTH'(tile_col);
    chunk_need_cur       = (quant_need_load_r > load_offset)
                         ? (((quant_need_load_r - load_offset) > VLEN)
                              ? VLEN
                              : (quant_need_load_r - load_offset))
                         : 32'd0;

    tile_row_inc = tile_row + tile_idx_t'(1);
    tile_col_inc = tile_col + tile_idx_t'(1);
    cur_last_row_tile = (tile_row == last_row_tile);
    cur_last_col_tile = (tile_col == last_col_tile);
    cur_last_row_in_group = cur_last_row_tile ||
                            (row_offset_in_group == ia_reuse_mask_tile_r);
    step_row_in_group = !cur_last_row_in_group;
    step_col_in_group = cur_last_row_in_group && !cur_last_col_tile;
    step_next_group   = cur_last_row_in_group && cur_last_col_tile && !cur_last_row_tile;

    if (step_row_in_group) begin
      next_tile_row_cur = tile_row_inc;
      next_tile_col_cur = tile_col;
    end else if (step_col_in_group) begin
      next_tile_row_cur = reuse_group_base_row;
      next_tile_col_cur = tile_col_inc;
    end else if (step_next_group) begin
      next_tile_row_cur = reuse_group_base_row + tile_idx_t'(ia_reuse_num_r);
      next_tile_col_cur = '0;
    end else begin
      next_tile_row_cur = '0;
      next_tile_col_cur = '0;
    end
    final_tile_cur = cur_last_col_tile && cur_last_row_tile;
    next_same_quant_group_cur = step_row_in_group ||
                                (step_col_in_group && is_mode_r);
  end

  // 参数就绪拍锁存（供计算屏蔽尾块）
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      lane_need_q <= '0;
    end else if (init_cfg) begin
      lane_need_q <= '0;
    end else begin
      // per-tensor 模式也要跟随当前列 tile，避免尾列把无效 lane 写出。
      if (!cfg_per_channel) begin
        lane_need_q <= lane_need_cur;
      end  // per-channel 模式下：在 quant_params_valid 时锁存当前需要的 lanes
      else if (quant_params_valid) begin
        lane_need_q <= lane_need_cur;
      end
    end
  end


  // DMA len = 需要拍数-1（0 表示 1 拍）
  always_comb begin
    burst_len_cur = 8'((chunk_need_cur > 0) ? (chunk_need_cur - 1) : 0);
  end

  // ----------------------------
  // Native DMA 命令/响应
  // ----------------------------
  wire dma_start_hskd = (state == LOAD) && !cmd_busy && cmd_valid_r && load_quant_granted;
  wire rsp_hskd = dma_raw_valid && cmd_busy;
  logic [QBUF_IDX_W-1:0] quant_rsp_idx;

  always_comb begin
    quant_rsp_idx = QBUF_IDX_W'(load_offset + REG_WIDTH'(rd_beats_cnt));
  end

  assign dma_start = dma_start_hskd;
  assign dma_is_write = 1'b0;
  assign dma_linear_read_mode = 1'b0;
  assign dma_base_addr_cur = (load_phase == PH_MUL)
                           ? (mul_base_r + (quant_tile_idx_load_r * VLEN + load_offset) * BYTES_PER_WORD)
                           : (sh_base_r  + (quant_tile_idx_load_r * VLEN + load_offset) * BYTES_PER_WORD);
  assign dma_base_addr = cmd_base_addr_r;
  assign dma_row_stride = REG_WIDTH'(REG_WIDTH / 8);
  assign dma_rows_to_read = REG_WIDTH'(1);
  assign dma_burst_len_m1 = cmd_burst_len_m1_r;
  assign dma_slot_id = 1'b0;
  assign dma_use_16bits = 1'b0;
  assign dma_lhs_zp = '0;


  // ----------------------------
  // per-channel 参数缓冲
  // ----------------------------
  logic signed [31:0] ch_multiplier_r[QBUF_DEPTH];
  logic [5:0]         ch_lshift_r    [QBUF_DEPTH];
  logic [5:0]         ch_rshift_r    [QBUF_DEPTH];
  logic signed [31:0] quant_rsp_shift_signed;
  logic signed [31:0] quant_rsp_shift_abs;
  logic [5:0]         quant_rsp_lshift;
  logic [5:0]         quant_rsp_rshift;

  always_comb begin
    quant_rsp_shift_signed = $signed(dma_raw_data);
    quant_rsp_shift_abs = -quant_rsp_shift_signed;
    quant_rsp_lshift = 6'd0;
    quant_rsp_rshift = 6'd0;
    if (quant_rsp_shift_signed > 32'sd0) begin
      quant_rsp_lshift = quant_rsp_shift_signed[5:0];
    end else if (quant_rsp_shift_signed < 32'sd0) begin
      quant_rsp_rshift = (quant_rsp_shift_abs > 32'sd63) ? 6'd63 : quant_rsp_shift_abs[5:0];
    end
  end

  always_ff @(posedge clk) begin
    if (rsp_hskd) begin
      if (load_phase == PH_MUL) begin
        ch_multiplier_r[quant_rsp_idx] <= dma_raw_data;
      end else begin
        ch_lshift_r[quant_rsp_idx] <= quant_rsp_lshift;
        ch_rshift_r[quant_rsp_idx] <= quant_rsp_rshift;
      end
    end
  end


  // ----------------------------
  // 主状态机（只保留 4 个状态名）
  // ----------------------------
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      // reset all sequential state
      state              <= IDLE;
      load_phase         <= PH_MUL;
	      quant_params_valid <= 1'b0;
	      row_in_tile_cnt    <= '0;
	      rd_beats_cnt       <= '0;
	      beats_expect       <= '0;
	      cmd_busy           <= 1'b0;
	      cmd_valid_r        <= 1'b0;
	      cmd_base_addr_r    <= '0;
	      cmd_burst_len_m1_r <= '0;
	      cmd_beats_expect_r <= '0;
	      load_meta_valid    <= 1'b0;
	      quant_need_load_r  <= 32'd0;
	      quant_tile_idx_load_r <= 32'd0;
	      load_quant_req     <= 1'b0;
      tile_col           <= '0;
      tile_row           <= '0;
      load_offset        <= 32'd0;
      all_tiles_done     <= 1'b0;
    end else begin
      // default per-cycle de-asserts (will be overridden in branches)
      //load_quant_req      <= 1'b0;  
      // note: do NOT clear quant_params_valid/lane_need_q here (they are cleared when tile completes)

      // handle init_cfg (single-cycle reset of per-tile counters)
      if (init_cfg) begin
        state              <= IDLE;
        quant_params_valid <= (cfg_per_channel ? 1'b0 : 1'b1);
	        row_in_tile_cnt    <= '0;
	        rd_beats_cnt       <= '0;
	        cmd_busy           <= 1'b0;
	        cmd_valid_r        <= 1'b0;
	        cmd_base_addr_r    <= '0;
	        cmd_burst_len_m1_r <= '0;
	        cmd_beats_expect_r <= '0;
	        load_meta_valid    <= 1'b0;
	        quant_need_load_r  <= 32'd0;
	        quant_tile_idx_load_r <= 32'd0;
	        tile_col           <= '0;
        tile_row           <= '0;
        load_offset        <= 32'd0;
        all_tiles_done     <= 1'b0;  // clear done on re-config
        if (requant_trace_en) begin
          $display("[%0t] REQ init per_ch=%0d is=%0d k=%0d m=%0d reuse=%0d mul=%08x sh=%08x",
                   $time, cfg_per_channel, cfg_dataflow_mode, k, m,
                   ia_reuse_num_in, multiplier_in, shift_in);
        end
      end else begin

        case (state)
          // ----------------------
	          IDLE: begin
	            rd_beats_cnt    <= '0;
	            cmd_busy        <= 1'b0;
	            cmd_valid_r     <= 1'b0;
	            row_in_tile_cnt <= '0;

            // 如果所有 tile 都做完了 -> stay IDLE 等待 init_cfg 清除
            if (all_tiles_done) begin
              load_quant_req <= 1'b0;
              // remain idle
            end else begin
              // 保持请求直到 grant（避免单拍丢失）
              if (cfg_per_channel && has_tiles_r && !quant_params_valid) begin
                load_quant_req <= 1'b1;
                if (load_quant_granted) begin
                  load_phase     <= PH_MUL;
                  load_offset    <= 32'd0;
                  load_meta_valid <= 1'b0;
                  state          <= LOAD;
                  if (requant_trace_en) begin
                    $display("[%0t] REQ idle->load tile=(%0d,%0d) lanes=%0d rows=%0d qneed=%0d",
                             $time, tile_row, tile_col, lane_need_cur,
                             rows_need_cur, quant_need_cur);
                  end
                  // do not clear load_quant_req here; default loop will clear next cycle if needed
                end
              end

              // per-tensor 或 已有参数: 直接响应输入
              if (!cfg_per_channel || quant_params_valid) begin
                if (in_valid) begin
                  if (in_tile_done) begin
                    row_in_tile_cnt <= '0;
                    all_tiles_done  <= final_tile_cur;

                    if (final_tile_cur) begin
                      tile_row <= '0;
                      tile_col <= '0;
                      load_quant_req <= 1'b0;
                      quant_params_valid <= cfg_per_channel ? 1'b0 : 1'b1;
                      state <= IDLE;
                    end else begin
                      tile_row <= next_tile_row_cur;
                      tile_col <= next_tile_col_cur;

                      if (!cfg_per_channel) begin
                        state <= COMPUTE;
                      end else if (next_same_quant_group_cur) begin
                        load_quant_req <= 1'b0;
                        quant_params_valid <= 1'b1;
                        state <= COMPUTE;
                      end else begin
                        load_quant_req <= 1'b0;
                        load_meta_valid <= 1'b0;
                        load_phase <= PH_MUL;
                        load_offset <= 32'd0;
                        quant_params_valid <= 1'b0;
                        state <= LOAD;
                      end
                    end
                  end else begin
                    // IDLE 中接住的第一拍 in_valid 已经被数据通路消费，
                    // 行计数也必须同步推进，避免下一拍把 tile_done 提前一行。
                    row_in_tile_cnt <= VLEN_CNT_W'(1);
                    state <= COMPUTE;
                  end
                end
              end
            end
          end

          // ----------------------
          LOAD: begin
            row_in_tile_cnt <= '0;
	            // 1) 先锁存本 LOAD 的量化参数范围，避免命令寄存器直接吃尺寸组合路径。
	            if (!load_meta_valid) begin
	              load_meta_valid      <= 1'b1;
	              quant_need_load_r    <= quant_need_cur;
	              quant_tile_idx_load_r <= quant_tile_idx_cur;
	              load_offset          <= 32'd0;
	              load_quant_req       <= 1'b1;
`ifndef SYNTHESIS
	              if (quant_need_cur == 32'd0) begin
	                $display("[%0t] ERROR: zero-length quant LOAD metadata", $time);
	                $fatal;
	              end
`endif
	            end else if (!cmd_busy) begin
	              // 2) 若当前没有在途命令，则按 phase 发一条 DMA 读命令。
	              if (!cmd_valid_r) begin
`ifndef SYNTHESIS
	                if (chunk_need_cur == 32'd0) begin
	                  $display("[%0t] ERROR: zero-length quant DMA command", $time);
	                  $fatal;
	                end
`endif
	                cmd_valid_r        <= 1'b1;
	                cmd_base_addr_r    <= dma_base_addr_cur;
	                cmd_burst_len_m1_r <= burst_len_cur;
	                cmd_beats_expect_r <= VLEN_CNT_W'(chunk_need_cur);
	                load_quant_req     <= 1'b1;
	              end else begin
	                load_quant_req <= 1'b1;
	              end

	              if (dma_start_hskd) begin
	                // 命令已被 DMA 接受，本次突发开始
	                cmd_busy       <= 1'b1;
	                cmd_valid_r    <= 1'b0;
	                load_quant_req <= 1'b0;
	                rd_beats_cnt   <= '0;
	                beats_expect   <= cmd_beats_expect_r;  // 需要收的拍数
	                if (requant_trace_en) begin
	                  $display("[%0t] REQ cmd phase=%0d addr=%08x len=%0d tile=(%0d,%0d) qidx=%0d off=%0d qneed=%0d",
	                           $time, load_phase,
	                           cmd_base_addr_r, cmd_burst_len_m1_r, tile_row, tile_col, quant_tile_idx_cur,
	                           load_offset, quant_need_load_r);
	                end
	              end
            end

            // 3) 接收响应拍：mul/shift 缓冲写入
            if (rsp_hskd && cmd_busy) begin
              // 防护断言（仿真）
`ifndef SYNTHESIS
              if (beats_expect > VLEN) begin
                $display("[%0t] ERROR: beats_expect (%0d) > VLEN", $time, beats_expect);
                $fatal;
              end
              if ((load_offset + rd_beats_cnt) >= QBUF_DEPTH) begin
                $display("[%0t] ERROR: quant buffer index (%0d) >= QBUF_DEPTH (%0d)",
                         $time, load_offset + rd_beats_cnt, QBUF_DEPTH);
                $fatal;
              end
`endif

              rd_beats_cnt <= rd_beats_cnt + VLEN_CNT_W'(1);

              // 3) 本次突发收满：决定是切 phase 还是完成 LOAD
              if ((rd_beats_cnt + VLEN_CNT_W'(1)) == beats_expect) begin
                cmd_busy <= 1'b0;  // 本突发结束
                if (requant_trace_en) begin
                  $display("[%0t] REQ rsp_done phase=%0d beats=%0d tile=(%0d,%0d) off=%0d",
                           $time, load_phase, beats_expect, tile_row, tile_col, load_offset);
                end
                if (load_phase == PH_MUL) begin
                  if ((load_offset + REG_WIDTH'(beats_expect)) < quant_need_load_r) begin
                    load_offset <= load_offset + REG_WIDTH'(beats_expect);
                  end else begin
                    // mul 收满 -> 切到 shift，下一拍会去发 shift 的命令
                    load_phase  <= PH_SHIFT;
                    load_offset <= 32'd0;
                  end
                end else begin
                  if ((load_offset + REG_WIDTH'(beats_expect)) < quant_need_load_r) begin
                    load_offset <= load_offset + REG_WIDTH'(beats_expect);
                  end else begin
                    // shift 也收满，参数就绪：同时锁存 lane_need，并根据当拍 in_valid 决定是否直接进 COMPUTE
                    quant_params_valid <= 1'b1;
                    load_offset        <= 32'd0;
                    load_meta_valid    <= 1'b0;
                    //lane_need_q        <= lane_need_cur;   // <-- 把 lane_need 在参数就绪时锁存
                    if (requant_trace_en) begin
                      $display("[%0t] REQ params_valid tile=(%0d,%0d) lanes=%0d rows=%0d qneed=%0d",
                               $time, tile_row, tile_col, lane_need_cur, rows_need_cur,
                               quant_need_load_r);
                    end

                    if (in_valid) begin
                      state <= COMPUTE; // 允许在同一时钟周期观察到 in_valid 并直接进入 COMPUTE
                    end else begin
                      state <= IDLE;
                    end
                  end
                end
              end
            end
          end

          // ----------------------
          COMPUTE: begin
            load_phase <= PH_MUL;

            if (in_valid) begin
              if (requant_trace_en) begin
                $write("[%0t] REQ in tile=(%0d,%0d) row_cnt=%0d/%0d done=%0d acc=",
                       $time, tile_row, tile_col, row_in_tile_cnt,
                       rows_need_cur, in_tile_done);
                for (int dbg_i = 0; dbg_i < VLEN; dbg_i++) begin
                  $write("%0d%s", in_vec_s32[dbg_i], (dbg_i == VLEN - 1) ? "" : ",");
                end
                $write("\n");
              end

              if (in_tile_done) begin
                row_in_tile_cnt <= '0;
                all_tiles_done  <= final_tile_cur;

                if (final_tile_cur) begin
                  tile_row <= '0;
                  tile_col <= '0;
                  load_quant_req <= 1'b0;
                  quant_params_valid <= cfg_per_channel ? 1'b0 : 1'b1;
                  state <= IDLE;
                end else begin
                  tile_row <= next_tile_row_cur;
                  tile_col <= next_tile_col_cur;

                  if (!cfg_per_channel) begin
                    state <= COMPUTE;
                  end else if (next_same_quant_group_cur) begin
                    load_quant_req <= 1'b0;
                    quant_params_valid <= 1'b1;
                    state <= COMPUTE;
                  end else begin
                    load_quant_req <= 1'b0;
                    load_meta_valid <= 1'b0;
                    load_phase <= PH_MUL;
                    load_offset <= 32'd0;
                    quant_params_valid <= 1'b0;
                    state <= LOAD;
                  end
                end
              end else begin
                row_in_tile_cnt <= row_in_tile_cnt + 1'b1;
                state <= COMPUTE;
              end
            end
          end

          default: begin
            // 保底：防止卡死
            state <= IDLE;
          end

        endcase
      end  // !init_cfg
    end  // !rst_n
  end


  // ----------------------------
  // 数据通路（全吞吐流水：in_valid -> out_valid）
  // ----------------------------
  logic accept_valid;
  logic stage0_valid;
  logic stage1_valid;
  logic stage2_valid;
  logic stage3_valid;
  logic stage4_valid;
  logic stage5_valid;
  logic stage6_valid;
  logic stage7_valid;
  logic stage8_valid;
  logic stage9_valid;
  logic stage10_valid;
  logic stage11_valid;
  logic stage0_tile_done;
  logic stage1_tile_done;
  logic stage2_tile_done;
  logic stage3_tile_done;
  logic stage4_tile_done;
  logic stage5_tile_done;
  logic stage6_tile_done;
  logic stage7_tile_done;
  logic stage8_tile_done;
  logic stage9_tile_done;
  logic stage10_tile_done;
  logic stage11_tile_done;

  assign accept_valid = in_valid && ((!cfg_per_channel) || quant_params_valid);
  assign out_valid = stage11_valid;
  assign out_tile_done = stage11_tile_done;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      stage0_valid     <= 1'b0;
      stage1_valid     <= 1'b0;
      stage2_valid     <= 1'b0;
      stage3_valid     <= 1'b0;
      stage4_valid     <= 1'b0;
      stage5_valid     <= 1'b0;
      stage6_valid     <= 1'b0;
      stage7_valid     <= 1'b0;
      stage8_valid     <= 1'b0;
      stage9_valid     <= 1'b0;
      stage10_valid    <= 1'b0;
      stage11_valid    <= 1'b0;
      stage0_tile_done <= 1'b0;
      stage1_tile_done <= 1'b0;
      stage2_tile_done <= 1'b0;
      stage3_tile_done <= 1'b0;
      stage4_tile_done <= 1'b0;
      stage5_tile_done <= 1'b0;
      stage6_tile_done <= 1'b0;
      stage7_tile_done <= 1'b0;
      stage8_tile_done <= 1'b0;
      stage9_tile_done <= 1'b0;
      stage10_tile_done <= 1'b0;
      stage11_tile_done <= 1'b0;
    end else if (init_cfg) begin
      stage0_valid     <= 1'b0;
      stage1_valid     <= 1'b0;
      stage2_valid     <= 1'b0;
      stage3_valid     <= 1'b0;
      stage4_valid     <= 1'b0;
      stage5_valid     <= 1'b0;
      stage6_valid     <= 1'b0;
      stage7_valid     <= 1'b0;
      stage8_valid     <= 1'b0;
      stage9_valid     <= 1'b0;
      stage10_valid    <= 1'b0;
      stage11_valid    <= 1'b0;
      stage0_tile_done <= 1'b0;
      stage1_tile_done <= 1'b0;
      stage2_tile_done <= 1'b0;
      stage3_tile_done <= 1'b0;
      stage4_tile_done <= 1'b0;
      stage5_tile_done <= 1'b0;
      stage6_tile_done <= 1'b0;
      stage7_tile_done <= 1'b0;
      stage8_tile_done <= 1'b0;
      stage9_tile_done <= 1'b0;
      stage10_tile_done <= 1'b0;
      stage11_tile_done <= 1'b0;
    end else begin
      stage0_valid     <= accept_valid;
      stage1_valid     <= stage0_valid;
      stage2_valid     <= stage1_valid;
      stage3_valid     <= stage2_valid;
      stage4_valid     <= stage3_valid;
      stage5_valid     <= stage4_valid;
      stage6_valid     <= stage5_valid;
      stage7_valid     <= stage6_valid;
      stage8_valid     <= stage7_valid;
      stage9_valid     <= stage8_valid;
      stage10_valid    <= stage9_valid;
      stage11_valid    <= stage10_valid;
      stage0_tile_done <= accept_valid && in_tile_done;
      stage1_tile_done <= stage0_tile_done;
      stage2_tile_done <= stage1_tile_done;
      stage3_tile_done <= stage2_tile_done;
      stage4_tile_done <= stage3_tile_done;
      stage5_tile_done <= stage4_tile_done;
      stage6_tile_done <= stage5_tile_done;
      stage7_tile_done <= stage6_tile_done;
      stage8_tile_done <= stage7_tile_done;
      stage9_tile_done <= stage8_tile_done;
      stage10_tile_done <= stage9_tile_done;
      stage11_tile_done <= stage10_tile_done;
    end
  end

  logic [VLEN_CNT_W-1:0] input_row_idx_cur;
  logic [QBUF_IDX_W-1:0] input_group_idx_cur;
  always_comb begin
    input_row_idx_cur = row_in_tile_cnt;
    input_group_idx_cur = QBUF_IDX_W'((REG_WIDTH'(row_offset_in_group) << VLEN_SHIFT) +
                                      REG_WIDTH'(input_row_idx_cur));
  end

  // 做一行（VLEN lane），尾块屏蔽。该流水每拍都能接收一行，只增加固定延迟。
  genvar j;
  for (j = 0; j < VLEN; j++) begin : LANE
    logic signed [31:0] mult_sel;
    logic [5:0]         lshift_sel;
    logic [5:0]         rshift_sel;
    logic signed [31:0] activation_min_lane_r;
    logic signed [31:0] activation_max_lane_r;
    logic signed [31:0] dst_offset_lane_r;

    logic signed [31:0] acc_s0;
    logic signed [31:0] mult_s0;
    logic [5:0]         lshift_s0;
    logic [5:0]         rshift_s0;
    logic               lane_en_s0;

    logic signed [31:0] acc_s1;
    logic signed [31:0] mult_s1;
    logic [5:0]         lshift_s1;
    logic [5:0]         rshift_s1;
    logic               lane_en_s1;

    (* use_dsp = "yes" *) logic signed [31:0] pp_hh_s2;
    (* use_dsp = "yes" *) logic signed [32:0] pp_hl_s2;
    (* use_dsp = "yes" *) logic signed [32:0] pp_lh_s2;
    (* use_dsp = "yes" *) logic [31:0] pp_ll_s2;
    logic [5:0]         lshift_s2;
    logic [5:0]         rshift_s2;
    logic               lane_en_s2;

    logic signed [31:0] pp_hh_s3;
    logic signed [33:0] pp_mid_s3;
    logic [31:0]        pp_ll_s3;
    logic [5:0]         lshift_s3;
    logic [5:0]         rshift_s3;
    logic               lane_en_s3;

    logic signed [63:0] prod_hi_mid_s4;
    logic [31:0]        pp_ll_s4;
    logic [5:0]         lshift_s4;
    logic [5:0]         rshift_s4;
    logic               lane_en_s4;

    logic signed [63:0] prod_s5;
    logic [5:0]         lshift_s5;
    logic [5:0]         rshift_s5;
    logic               lane_en_s5;

    logic signed [63:0] prod_shifted_s6;
    logic [5:0]         rshift_s6;
    logic               lane_en_s6;

    logic signed [31:0] high_s7;
    logic [5:0]         rshift_s7;
    logic               lane_en_s7;

    logic signed [31:0] shifted_next_s7;
    logic signed [31:0] remainder_next_s7;
    logic signed [31:0] threshold_next_s7;
    logic               has_rshift_next_s7;
    logic signed [31:0] shifted_s8;
    logic signed [31:0] remainder_s8;
    logic signed [31:0] threshold_s8;
    logic               has_rshift_s8;
    logic               lane_en_s8;

    logic signed [31:0] shifted_s9;
    logic               round_up_s9;
    logic               lane_en_s9;

    logic signed [31:0] rounded_s10;
    logic               lane_en_s10;

    always_comb begin
      if (cfg_per_channel) begin
        mult_sel   = is_mode_r ? ch_multiplier_r[input_group_idx_cur] : ch_multiplier_r[j];
        lshift_sel = is_mode_r ? ch_lshift_r[input_group_idx_cur] : ch_lshift_r[j];
        rshift_sel = is_mode_r ? ch_rshift_r[input_group_idx_cur] : ch_rshift_r[j];
      end else begin
        mult_sel   = pt_multiplier_r;
        lshift_sel = pt_lshift_r;
        rshift_sel = pt_rshift_r;
      end
    end

    always_comb begin
      logic [4:0]         rshift_amt;
      logic signed [31:0] mask;

      rshift_amt = 5'd0;
      mask       = 32'sd0;
      if (rshift_s7 == 6'd0) begin
        shifted_next_s7    = high_s7;
        remainder_next_s7  = 32'sd0;
        threshold_next_s7  = 32'sd0;
        has_rshift_next_s7 = 1'b0;
      end else begin
        rshift_amt = (rshift_s7 > 6'd31) ? 5'd31 : rshift_s7[4:0];
        mask       = (32'sd1 <<< rshift_amt) - 32'sd1;
        shifted_next_s7    = high_s7 >>> rshift_amt;
        remainder_next_s7  = high_s7 & mask;
        threshold_next_s7  = (mask >>> 1) + (high_s7[31] ? 32'sd1 : 32'sd0);
        has_rshift_next_s7 = 1'b1;
      end
    end

    always_ff @(posedge clk) begin
      if (!rst_n) begin
        lane_en_s0    <= 1'b0;
        lane_en_s1    <= 1'b0;
        lane_en_s2    <= 1'b0;
        lane_en_s3    <= 1'b0;
        lane_en_s4    <= 1'b0;
        lane_en_s5    <= 1'b0;
        lane_en_s6    <= 1'b0;
        lane_en_s7    <= 1'b0;
        lane_en_s8    <= 1'b0;
        lane_en_s9    <= 1'b0;
        lane_en_s10   <= 1'b0;
        out_vec_s8[j] <= '0;
        activation_min_lane_r <= '0;
        activation_max_lane_r <= '0;
        dst_offset_lane_r     <= '0;
      end else if (init_cfg) begin
        lane_en_s0    <= 1'b0;
        lane_en_s1    <= 1'b0;
        lane_en_s2    <= 1'b0;
        lane_en_s3    <= 1'b0;
        lane_en_s4    <= 1'b0;
        lane_en_s5    <= 1'b0;
        lane_en_s6    <= 1'b0;
        lane_en_s7    <= 1'b0;
        lane_en_s8    <= 1'b0;
        lane_en_s9    <= 1'b0;
        lane_en_s10   <= 1'b0;
        out_vec_s8[j] <= '0;
        activation_min_lane_r <= activation_min_in;
        activation_max_lane_r <= activation_max_in;
        dst_offset_lane_r     <= dst_offset_in;
      end else begin
        lane_en_s0  <= accept_valid && (j < (cfg_per_channel ? lane_need_q : lane_need_cur));
        lane_en_s1  <= lane_en_s0;
        lane_en_s2  <= lane_en_s1;
        lane_en_s3  <= lane_en_s2;
        lane_en_s4  <= lane_en_s3;
        lane_en_s5  <= lane_en_s4;
        lane_en_s6  <= lane_en_s5;
        lane_en_s7  <= lane_en_s6;
        lane_en_s8  <= lane_en_s7;
        lane_en_s9  <= lane_en_s8;
        lane_en_s10 <= lane_en_s9;

        if (!lane_en_s10) begin
          out_vec_s8[j] <= 8'sd0;
        end else if (rounded_s10 < activation_min_lane_r) begin
          out_vec_s8[j] <= activation_min_lane_r[7:0];
        end else if (rounded_s10 > activation_max_lane_r) begin
          out_vec_s8[j] <= activation_max_lane_r[7:0];
        end else if (rounded_s10 > 32'sd127) begin
          out_vec_s8[j] <= 8'sd127;
        end else if (rounded_s10 < -32'sd128) begin
          out_vec_s8[j] <= -8'sd128;
        end else begin
          out_vec_s8[j] <= rounded_s10[7:0];
        end
      end
    end

    always_ff @(posedge clk) begin
      if (!init_cfg) begin
        acc_s0     <= in_vec_s32[j];
        mult_s0    <= mult_sel;
        lshift_s0  <= lshift_sel;
        rshift_s0  <= rshift_sel;

        acc_s1     <= acc_s0;
        mult_s1    <= mult_s0;
        lshift_s1  <= lshift_s0;
        rshift_s1  <= rshift_s0;

        pp_hh_s2  <= $signed(acc_s1[31:16]) * $signed(mult_s1[31:16]);
        pp_hl_s2  <= $signed(acc_s1[31:16]) * $signed({1'b0, mult_s1[15:0]});
        pp_lh_s2  <= $signed(mult_s1[31:16]) * $signed({1'b0, acc_s1[15:0]});
        pp_ll_s2  <= acc_s1[15:0] * mult_s1[15:0];
        lshift_s2 <= lshift_s1;
        rshift_s2 <= rshift_s1;

        pp_hh_s3  <= pp_hh_s2;
        pp_mid_s3 <= $signed({pp_hl_s2[32], pp_hl_s2}) +
                     $signed({pp_lh_s2[32], pp_lh_s2});
        pp_ll_s3  <= pp_ll_s2;
        lshift_s3 <= lshift_s2;
        rshift_s3 <= rshift_s2;

        prod_hi_mid_s4 <= ($signed({{32{pp_hh_s3[31]}}, pp_hh_s3}) <<< 32) +
                          ($signed({{30{pp_mid_s3[33]}}, pp_mid_s3}) <<< 16);
        pp_ll_s4  <= pp_ll_s3;
        lshift_s4 <= lshift_s3;
        rshift_s4 <= rshift_s3;

        prod_s5   <= prod_hi_mid_s4 + $signed({32'd0, pp_ll_s4});
        lshift_s5 <= lshift_s4;
        rshift_s5 <= rshift_s4;

        prod_shifted_s6 <= prod_s5 <<< lshift_s5;
        rshift_s6 <= rshift_s5;

        high_s7   <= 32'((prod_shifted_s6 + (64'sd1 <<< 30)) >>> 31);
        rshift_s7 <= rshift_s6;

        shifted_s8    <= shifted_next_s7;
        remainder_s8  <= remainder_next_s7;
        threshold_s8  <= threshold_next_s7;
        has_rshift_s8 <= has_rshift_next_s7;

        shifted_s9 <= shifted_s8;
        round_up_s9 <= has_rshift_s8 && (remainder_s8 > threshold_s8);

        rounded_s10 <= shifted_s9 + dst_offset_lane_r + (round_up_s9 ? 32'sd1 : 32'sd0);
      end
    end
  end

endmodule
