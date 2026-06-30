//`include "define.svh"
`include "e203_defines.v"
`include "icb_types.svh"

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

    // ICB
    output    icb_ext_cmd_m_t icb_cmd_m,
    //output    icb_ext_wr_m_t  icb_wr_m,
    input var icb_ext_cmd_s_t icb_cmd_s,
    input var icb_ext_wr_s_t  icb_wr_s,
    input var icb_ext_rsp_s_t icb_rsp_s,
    output    icb_ext_rsp_m_t icb_rsp_m,

    // 数据口
    input  logic               in_valid,
    input  logic signed [31:0] in_vec_s32[VLEN],
    output logic               out_valid,
    output logic signed [ 7:0] out_vec_s8[VLEN]
);

  // ----------------------------
  // 常量与类型
  // ----------------------------
  localparam int BYTES_PER_WORD = `E203_XLEN / 8;  // 32位=4
  localparam int QBUF_DEPTH     = VLEN * MAX_IA_REUSE;
  typedef logic [`ICB_LEN_W-1:0] icb_len_t;

  // ----------------------------
  // 状态机与游标
  // ----------------------------
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    COMPUTE,
    TILE_COMPLETE
  } state_e;
  state_e state, state_n;

  // 只保留 4 个状态名，LOAD 内部用 phase 区分 mul/shift
  typedef enum logic [0:0] {
    PH_MUL   = 1'b0,
    PH_SHIFT = 1'b1
  } phase_e;
  phase_e          load_phase;  // 当前子阶段（先 mul 后 shift）

  logic     [31:0] tile_col;  // 当前列 tile 号
  logic     [ 4:0] row_in_tile_cnt;  // 0..15：本 tile 已完成的行数
  logic     [31:0] lane_need_cur;  // 本 tile 需要的列数（尾块可能 < VLEN）
  logic     [31:0] quant_need_cur;  // 本 tile 需要加载的 per-channel 参数数
  logic     [31:0] quant_tile_idx_cur;
  logic     [31:0] tile_row;  // 当前行 tile 号
  logic     [31:0] rows_need_cur;  // 当前行 tile 需要的行数（最后一块为余数）
  logic     [31:0] lane_need_q;  // 锁存，用于计算/屏蔽无效 lane
  icb_len_t        burst_len_cur;  // = lane_need_cur - 1
  logic     [31:0] reuse_group_base_row;
  logic     [31:0] row_offset_in_group;
  logic     [31:0] group_rows_need_cur;
  logic     [31:0] load_offset;
  logic     [31:0] chunk_need_cur;

  // per-channel：mul/shift 两次突发的采样计数
  logic     [ 5:0] rd_beats_cnt;
  logic     [ 5:0] beats_expect;
  logic            cmd_busy;

  // track number of tiles & finished flag
  logic     [31:0] num_row_tiles;
  logic     [31:0] num_col_tiles;
  logic            all_tiles_done;
  bit              requant_trace_en;

  initial begin
    requant_trace_en = 1'b0;
    if ($test$plusargs("MMA_REQUANT_TRACE")) requant_trace_en = 1'b1;
  end

  // ----------------------------
  // 配置寄存
  // ----------------------------
  logic signed [31:0] activation_min_r, activation_max_r, dst_offset_r;
  logic signed [31:0] pt_multiplier_r, pt_shift_r;  // per-tensor 常量
  logic [31:0] k_r, m_r;  // 锁存的尺寸
  logic [31:0] ia_reuse_num_r;
  logic [31:0] mul_base_r, sh_base_r;  // per-channel 基地址
  logic        is_mode_r;


  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      activation_min_r <= '0;
      activation_max_r <= '0;
      dst_offset_r     <= '0;
      pt_multiplier_r  <= '0;
      pt_shift_r       <= '0;
      k_r              <= '0;
      m_r              <= '0;
      ia_reuse_num_r   <= 32'd1;
      mul_base_r       <= '0;
      sh_base_r        <= '0;
      is_mode_r        <= 1'b0;
    end else if (init_cfg) begin
      activation_min_r <= activation_min_in;
      activation_max_r <= activation_max_in;
      dst_offset_r     <= dst_offset_in;
      pt_multiplier_r  <= multiplier_in;
      pt_shift_r       <= shift_in;
      k_r              <= k;
      m_r              <= m;
      ia_reuse_num_r   <= (ia_reuse_num_in == 32'd0) ? 32'd1 : ia_reuse_num_in;
      // per-channel 基地址（接口复用 multiplier_in/shift_in）
      mul_base_r       <= multiplier_in;
      sh_base_r        <= shift_in;
      is_mode_r        <= cfg_dataflow_mode;
    end
  end

  // compute number of tiles (rows/cols)
  always_comb begin
    // safe ceil_div: (n + VLEN -1) / VLEN
    num_row_tiles = (k_r == 0) ? 0 : ((k_r + VLEN - 1) / VLEN);
    num_col_tiles = (m_r == 0) ? 0 : ((m_r + VLEN - 1) / VLEN);
  end

  // ----------------------------
  // tile 列需要多少 lane（尾块）
  // ----------------------------
  function automatic [31:0] f_lane_need(input [31:0] cols, input [31:0] vlen, input [31:0] tcol);
    reg [31:0] remain;
    begin
      remain = (cols > (tcol * vlen)) ? (cols - tcol * vlen) : 32'd0;
      f_lane_need = (remain >= vlen) ? vlen : remain;
    end
  endfunction

  function automatic [31:0] f_rows_need(input [31:0] rows, input [31:0] vlen, input [31:0] trow);
    reg [31:0] remain;
    begin
      remain = (rows > (trow * vlen)) ? (rows - trow * vlen) : 32'd0;
      f_rows_need = (remain >= vlen) ? vlen : remain;
    end
  endfunction

  function automatic [31:0] f_group_rows_need(input [31:0] rows,
                                              input [31:0] vlen,
                                              input [31:0] group_base_row,
                                              input [31:0] reuse_num_in);
    reg [31:0] row_start;
    reg [31:0] remain;
    reg [31:0] capacity;
    begin
      row_start = group_base_row * vlen;
      capacity  = ((reuse_num_in == 32'd0) ? 32'd1 : reuse_num_in) * vlen;
      remain    = (rows > row_start) ? (rows - row_start) : 32'd0;
      f_group_rows_need = (remain >= capacity) ? capacity : remain;
    end
  endfunction

  task automatic calc_next_tile(
      input  [31:0] cur_row,
      input  [31:0] cur_col,
      input  [31:0] row_tiles_total,
      input  [31:0] col_tiles_total,
      input  [31:0] reuse_num_in,
      output [31:0] next_row,
      output [31:0] next_col
  );
    reg [31:0] reuse_num;
    reg [31:0] group_base;
    reg [31:0] group_next_base;
    begin
      reuse_num = (reuse_num_in == 32'd0) ? 32'd1 : reuse_num_in;
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
        next_col = 32'd0;
      end else begin
        next_row = 32'd0;
        next_col = 32'd0;
      end
    end
  endtask

  // 每次进入 LOAD 前计算 lane_need\row_need
  always_comb begin
    lane_need_cur = f_lane_need(m_r, VLEN, tile_col);
  end

  always_comb begin
    rows_need_cur = f_rows_need(k_r, VLEN, tile_row);
  end

  always_comb begin
    reuse_group_base_row = (ia_reuse_num_r == 32'd0)
                         ? tile_row
                         : ((tile_row / ia_reuse_num_r) * ia_reuse_num_r);
    row_offset_in_group  = tile_row - reuse_group_base_row;
    group_rows_need_cur  = f_group_rows_need(k_r, VLEN, reuse_group_base_row, ia_reuse_num_r);
    quant_need_cur       = is_mode_r ? group_rows_need_cur : lane_need_cur;
    quant_tile_idx_cur   = is_mode_r ? reuse_group_base_row : tile_col;
    chunk_need_cur       = (quant_need_cur > load_offset)
                         ? (((quant_need_cur - load_offset) > VLEN)
                              ? VLEN
                              : (quant_need_cur - load_offset))
                         : 32'd0;
  end

  // 参数就绪拍锁存（供计算屏蔽尾块）
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
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


  // ICB len = 需要拍数-1（0 表示 1 拍）
  always_comb begin
    burst_len_cur = icb_len_t'((chunk_need_cur > 0) ? (chunk_need_cur - 1) : 0);
  end

  // ----------------------------
  // ICB 命令/响应
  // ----------------------------
  icb_ext_cmd_m_t icb_cmd_m_reg, icb_cmd_m_wire;
  icb_ext_rsp_m_t icb_rsp_m_wire;

  wire cmd_hskd = icb_cmd_m_reg.valid && icb_cmd_s.ready;
  wire rsp_hskd = icb_rsp_s.rsp_valid && icb_rsp_m.rsp_ready;

  // master 侧：响应 ready 常 1；不使用写通道
  //assign icb_wr_m  = '{default: '0};
  assign icb_rsp_m = '{rsp_ready: 1'b1};
  assign icb_cmd_m = icb_cmd_m_wire;
  always_comb icb_cmd_m_wire = icb_cmd_m_reg;


  // ----------------------------
  // per-channel 参数缓冲
  // ----------------------------
  logic signed [31:0] ch_multiplier_r[QBUF_DEPTH];
  logic signed [31:0] ch_shift_r     [QBUF_DEPTH];


  // ----------------------------
  // 主状态机（只保留 4 个状态名）
  // ----------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // reset all sequential state
      state              <= IDLE;
      load_phase         <= PH_MUL;
      quant_params_valid <= 1'b0;
      row_in_tile_cnt    <= 5'd0;
      rd_beats_cnt       <= 6'd0;
      beats_expect       <= 6'd0;
      cmd_busy           <= 1'b0;
      load_quant_req     <= 1'b0;
      tile_col           <= 32'd0;
      tile_row           <= 32'd0;
      load_offset        <= 32'd0;
      icb_cmd_m_reg      <= '{default: '0};
      all_tiles_done     <= 1'b0;
    end else begin
      // default per-cycle de-asserts (will be overridden in branches)
      icb_cmd_m_reg.valid <= 1'b0;
      icb_cmd_m_reg.read  <= 1'b0;
      //load_quant_req      <= 1'b0;  
      // note: do NOT clear quant_params_valid/lane_need_q here (they are cleared when tile completes)

      // handle init_cfg (single-cycle reset of per-tile counters)
      if (init_cfg) begin
        state              <= IDLE;
        quant_params_valid <= (cfg_per_channel ? 1'b0 : 1'b1);
        row_in_tile_cnt    <= 5'd0;
        rd_beats_cnt       <= 6'd0;
        cmd_busy           <= 1'b0;
        tile_col           <= 32'd0;
        tile_row           <= 32'd0;
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
            rd_beats_cnt    <= 6'd0;
            cmd_busy        <= 1'b0;
            row_in_tile_cnt <= 5'd0;

            // 如果所有 tile 都做完了 -> stay IDLE 等待 init_cfg 清除
            if (all_tiles_done) begin
              load_quant_req <= 1'b0;
              // remain idle
            end else begin
              // 保持请求直到 grant（避免单拍丢失）
              if (cfg_per_channel && !quant_params_valid && (lane_need_cur != 0)) begin
                load_quant_req <= 1'b1;
                if (load_quant_granted) begin
                  load_quant_req <= 1'b0;
                  load_phase     <= PH_MUL;
                  load_offset    <= 32'd0;
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
                  // start compute for this tile/row-stream
                  state <= COMPUTE;
                  // ensure counter starts at 0 when entering a fresh compute
                  // row_in_tile_cnt will be incremented on out_valid
                  // do not clear quant_params_valid here (should remain valid during compute)
                end
              end
            end
          end

          // ----------------------
          LOAD: begin
            if (load_quant_granted) load_quant_req <= 1'b0;
            row_in_tile_cnt <= 5'd0;
            // 1) 若当前没有在途命令，则按 phase 发一条读命令（valid/ready handshake）
            if (!cmd_busy) begin
              icb_cmd_m_reg.valid <= 1'b1;
              icb_cmd_m_reg.read <= 1'b1;
              icb_cmd_m_reg.addr  <= (load_phase==PH_MUL)
                                    ? (mul_base_r + (quant_tile_idx_cur*VLEN + load_offset)*BYTES_PER_WORD)
                                    : (sh_base_r  + (quant_tile_idx_cur*VLEN + load_offset)*BYTES_PER_WORD);
              icb_cmd_m_reg.len <= burst_len_cur;  // len = quant_need_cur - 1

              if (cmd_hskd) begin
                // 命令已被对端接受，本次突发开始
                cmd_busy            <= 1'b1;
                icb_cmd_m_reg.valid <= 1'b0;  // 下拍取消 valid
                rd_beats_cnt        <= 6'd0;
                beats_expect        <= chunk_need_cur[5:0];  // 需要收的拍数
                if (requant_trace_en) begin
                  $display("[%0t] REQ cmd phase=%0d addr=%08x len=%0d tile=(%0d,%0d) qidx=%0d off=%0d qneed=%0d",
                           $time, load_phase,
                           (load_phase==PH_MUL)
                             ? (mul_base_r + (quant_tile_idx_cur*VLEN + load_offset)*BYTES_PER_WORD)
                             : (sh_base_r  + (quant_tile_idx_cur*VLEN + load_offset)*BYTES_PER_WORD),
                           burst_len_cur, tile_row, tile_col, quant_tile_idx_cur,
                           load_offset, quant_need_cur);
                end
              end
            end

            // 2) 接收响应拍：mul/shift 缓冲写入
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

              if (load_phase == PH_MUL) ch_multiplier_r[load_offset + rd_beats_cnt] <= icb_rsp_s.rsp_rdata;
              else ch_shift_r[load_offset + rd_beats_cnt] <= icb_rsp_s.rsp_rdata;

              rd_beats_cnt <= rd_beats_cnt + 1;

              // 3) 本次突发收满：决定是切 phase 还是完成 LOAD
              if ((rd_beats_cnt + 1) == beats_expect) begin
                cmd_busy <= 1'b0;  // 本突发结束
                if (requant_trace_en) begin
                  $display("[%0t] REQ rsp_done phase=%0d beats=%0d tile=(%0d,%0d) off=%0d",
                           $time, load_phase, beats_expect, tile_row, tile_col, load_offset);
                end
                if (load_phase == PH_MUL) begin
                  if ((load_offset + beats_expect) < quant_need_cur) begin
                    load_offset <= load_offset + beats_expect;
                  end else begin
                    // mul 收满 -> 切到 shift，下一拍会去发 shift 的命令
                    load_phase  <= PH_SHIFT;
                    load_offset <= 32'd0;
                  end
                end else begin
                  if ((load_offset + beats_expect) < quant_need_cur) begin
                    load_offset <= load_offset + beats_expect;
                  end else begin
                    // shift 也收满，参数就绪：同时锁存 lane_need，并根据当拍 in_valid 决定是否直接进 COMPUTE
                    quant_params_valid <= 1'b1;
                    load_offset        <= 32'd0;
                    //lane_need_q        <= lane_need_cur;   // <-- 把 lane_need 在参数就绪时锁存
                    if (requant_trace_en) begin
                      $display("[%0t] REQ params_valid tile=(%0d,%0d) lanes=%0d rows=%0d qneed=%0d",
                               $time, tile_row, tile_col, lane_need_cur, rows_need_cur,
                               quant_need_cur);
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
            // 现在 COMPUTE 负责一整块 tile 的所有行：
            // 在 out_valid 的上升周期计数；当计数达到 rows_need_cur 时转到 TILE_COMPLETE
            load_phase <= PH_MUL;

            if (out_valid) begin
              if (requant_trace_en) begin
                $display("[%0t] REQ out tile=(%0d,%0d) row_cnt=%0d/%0d",
                         $time, tile_row, tile_col, row_in_tile_cnt, rows_need_cur);
              end
              if (row_in_tile_cnt == rows_need_cur[4:0] - 1) begin
                // 本 tile 行数已全部处理完毕 -> 执行收尾
                state <= TILE_COMPLETE;
                row_in_tile_cnt <= 5'd0;
              end else begin
                // 继续在 COMPUTE 等下一行的输入
                row_in_tile_cnt <= row_in_tile_cnt + 1;
                // 继续在 COMPUTE 等下一行的输入
                state <= COMPUTE;
              end
            end
            if ((tile_col + 1 == num_col_tiles) && (tile_row + 1 == num_row_tiles) && row_in_tile_cnt == rows_need_cur[4:0]-1)
              all_tiles_done <= 1'b1;
            // 否则保持在 COMPUTE，等待 out_valid（或者下一次 in_valid 进入流水线）
          end

          // ----------------------
          TILE_COMPLETE: begin
            logic [31:0] next_tile_row;
            logic [31:0] next_tile_col;
            logic        final_tile_cur;

            // 到这里意味着本 tile 的所有行已经计算完（由 COMPUTE 决定）
            // 做收尾工作：清参数就绪、推进 tile 坐标。
            calc_next_tile(tile_row, tile_col, num_row_tiles, num_col_tiles,
                           ia_reuse_num_r, next_tile_row, next_tile_col);
            final_tile_cur = (tile_col + 1 == num_col_tiles) &&
                             (tile_row + 1 == num_row_tiles);

            row_in_tile_cnt <= 5'd0;
            all_tiles_done  <= final_tile_cur;

            if (final_tile_cur) begin
              load_quant_req <= 1'b0;
              quant_params_valid <= 1'b0;
            end

            if (final_tile_cur) begin
              tile_row <= 32'd0;
              tile_col <= 32'd0;
              state <= IDLE;
              if (requant_trace_en) begin
                $display("[%0t] REQ tile_done final tile=(%0d,%0d)",
                         $time, tile_row, tile_col);
              end
            end else begin
              tile_row <= next_tile_row;
              tile_col <= next_tile_col;
              if (requant_trace_en) begin
                  $display("[%0t] REQ tile_done tile=(%0d,%0d) next=(%0d,%0d) reload=%0d",
                         $time, tile_row, tile_col, next_tile_row, next_tile_col,
                         cfg_per_channel &&
                         !((!is_mode_r && (next_tile_col == tile_col)) ||
                           ( is_mode_r &&
                             (((next_tile_row / ia_reuse_num_r) * ia_reuse_num_r) ==
                              ((tile_row      / ia_reuse_num_r) * ia_reuse_num_r)))));
              end
              if (!cfg_per_channel) begin
                state <= COMPUTE;
              end else if ((!is_mode_r && (next_tile_col == tile_col)) ||
                           ( is_mode_r &&
                             (((next_tile_row / ia_reuse_num_r) * ia_reuse_num_r) ==
                              ((tile_row      / ia_reuse_num_r) * ia_reuse_num_r)))) begin
                // Per-channel 参数只随输出列 tile 变化。IA reuse group 内会连续
                // 输出多个 row tile，必须沿用同一组量化参数，避免吞掉无反压数据。
                // IS 模式下 requant 前是转置流，量化参数随 stream row tile 变化。
                load_quant_req <= 1'b0;
                quant_params_valid <= 1'b1;
                state <= COMPUTE;
              end else begin
                load_quant_req <= 1'b1;
                load_offset <= 32'd0;
                quant_params_valid <= 1'b0;
                state <= LOAD;
              end
            end

            // 仿真断言：超出范围直接暴露
`ifndef SYNTHESIS
            if (row_in_tile_cnt > VLEN) begin
              $display("[%0t] ERROR: row_in_tile_cnt (%0d) > VLEN", $time, row_in_tile_cnt);
              $fatal;
            end
`endif
          end

          // ----------------------
          default: begin
            // 保底：防止卡死
            state <= IDLE;
          end

        endcase
      end  // !init_cfg
    end  // !rst_n
  end


  // ----------------------------
  // 数据通路（1 拍管线：in_valid -> out_valid）
  // ----------------------------
  logic out_valid_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_valid_q <= 1'b0;
    end else begin
      out_valid_q <= in_valid && ((!cfg_per_channel) || quant_params_valid);
    end
  end

  assign out_valid = (!cfg_per_channel) ? out_valid_q : (out_valid_q && quant_params_valid);

  function automatic signed [31:0] round_divide_by_power_of_two(input signed [31:0] x,
                                                                input integer rshift);
    reg signed [31:0] shifted;
    reg signed [31:0] mask;
    reg signed [31:0] remainder;
    reg signed [31:0] threshold;
    begin
      if (rshift == 0) begin
        round_divide_by_power_of_two = x;
      end else begin
        shifted   = x >>> rshift;
        mask      = (32'sd1 <<< rshift) - 1;
        remainder = x & mask;
        threshold = mask >>> 1;
        if (x < 0) threshold = threshold + 1;

        round_divide_by_power_of_two = shifted + (remainder > threshold);
      end
    end
  endfunction


  // CMSIS-NN 风格重量化函数
  function automatic signed [31:0] cmsis_nn_requantize(input signed [31:0] acc,
                                                       input signed [31:0] multiplier,  // Q31
                                                       input signed [31:0] shift_s       // can be + or -
);
    reg signed [63:0] acc_ext;
    reg signed [63:0] prod;
    reg signed [63:0] round64;
    reg signed [31:0] result;
    integer lshift;
    integer rshift;
    begin
      // -------- split shift --------
      lshift = (shift_s > 0) ? shift_s : 0;
      rshift = (shift_s < 0) ? -shift_s : 0;

      // -------- LEFT_SHIFT --------
      acc_ext = $signed(acc) <<< lshift;

      // -------- Q31 multiply + rounding (doubling high mult) --------
      prod    = acc_ext * $signed(multiplier);
      round64 = prod + (64'sd1 <<< 30);
      result  = round64 >>> 31;

      // -------- RIGHT_SHIFT with rounding --------
      if (rshift > 0) cmsis_nn_requantize = round_divide_by_power_of_two(result, rshift);
      else cmsis_nn_requantize = result;
    end
  endfunction

  logic [4:0] input_row_idx_cur;
  logic [31:0] input_group_idx_cur;
  always_comb begin
    input_row_idx_cur = row_in_tile_cnt;
    if ((state == COMPUTE) && out_valid &&
        ((row_in_tile_cnt + 5'd1) < rows_need_cur[4:0])) begin
      input_row_idx_cur = row_in_tile_cnt + 5'd1;
    end
    input_group_idx_cur = (row_offset_in_group * VLEN) + input_row_idx_cur;
  end

  // 做一行（16 lane），尾块屏蔽
  genvar j;
  for (j = 0; j < VLEN; j++) begin : LANE
    // 局部变量声明放最前
    logic lane_en;
    logic signed [31:0] cur_m, cur_s;
    logic signed [31:0] rq_tmp;

    always_ff @(posedge clk or negedge rst_n) begin

      rq_tmp = '0;
      cur_m  = '0;
      cur_s  = '0;

      if (!rst_n) begin
        out_vec_s8[j] <= '0;
      end else if (in_valid) begin
        // 选择 per-channel 缓冲或 per-tensor 常量
        if (cfg_per_channel) begin
          cur_m = is_mode_r ? ch_multiplier_r[input_group_idx_cur] : ch_multiplier_r[j];
          cur_s = is_mode_r ? ch_shift_r[input_group_idx_cur] : ch_shift_r[j];
        end else begin
          cur_m = pt_multiplier_r;
          cur_s = pt_shift_r;
        end

        rq_tmp = cmsis_nn_requantize(in_vec_s32[j], cur_m, cur_s);
        rq_tmp = rq_tmp + dst_offset_r;

        if (rq_tmp < activation_min_r) rq_tmp = activation_min_r;
        if (rq_tmp > activation_max_r) rq_tmp = activation_max_r;

        lane_en = (j < (cfg_per_channel ? lane_need_q : lane_need_cur));

        if (lane_en) begin
          if (rq_tmp > 32'sd127) out_vec_s8[j] <= 8'sd127;
          else if (rq_tmp < -32'sd128) out_vec_s8[j] <= -32'sd128;
          else out_vec_s8[j] <= rq_tmp[7:0];
        end else begin
          out_vec_s8[j] <= 8'sd0;
        end
      end
    end
  end

endmodule
