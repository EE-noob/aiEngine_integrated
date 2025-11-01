`timescale 1ns/1ps
`include "define.svh"
`include "icb_types.svh"

// =====================================================
// Testbench for vec_requant: FSM transitions & ICB handshake
// =====================================================
module requant_tb;

  // ---------- Parameters ----------
  localparam int VLEN           = 16;
  localparam int BYTES_PER_WORD = `E203_XLEN/8;  // 4
  localparam int REG_WIDTH      = 32;

  // per-channel: bases used by DUT as "multiplier_in/shift_in"
  localparam logic [31:0] MUL_BASE = 32'h4000_0000;
  localparam logic [31:0] SH_BASE  = 32'h5000_0000;

  // per-channel case size（有尾块：16+10）
  localparam int K_ROWS_PC         = 55;
  localparam int M_COLS_PC         = 26;
  localparam int TILES_PER_ROW_PC  = (M_COLS_PC + VLEN - 1) / VLEN;

  // per-tensor case size（仅 1 tile）
  localparam int K_ROWS_PT         = 29;
  localparam int M_COLS_PT         = 10;

  localparam int LAT               = 2;         // ICB 响应延迟拍数

  // ---------- Clock / Reset ----------
  logic clk = 0, rstn = 0;
  always #5 clk = ~clk;

  initial begin
    repeat (5) @(posedge clk);
    rstn = 1;
  end

  // ---------- DUT ports ----------
  // 配置
  logic                       init_cfg, cfg_per_channel;
  logic signed [31:0]         activation_min_in, activation_max_in, dst_offset_in;
  logic signed [31:0]         multiplier_in, shift_in;
  logic [31:0]                k, m;

  // 量化参数装载
  logic load_quant_req, load_quant_granted, quant_params_valid;

  // ICB
  icb_ext_cmd_m_t icb_cmd_m;
  icb_ext_wr_m_t  icb_wr_m;
  icb_ext_cmd_s_t icb_cmd_s;
  icb_ext_wr_s_t  icb_wr_s;
  icb_ext_rsp_s_t icb_rsp_s;
  icb_ext_rsp_m_t icb_rsp_m;

  // 数据
  logic                       in_valid;
  logic signed [31:0]         in_vec_s32 [VLEN];
  logic                       out_valid;
  logic signed [7:0]          out_vec_s8 [VLEN];

  // ---------- DUT ----------
  vec_requant #(.VLEN(VLEN), .REG_WIDTH(REG_WIDTH)) dut (
    .clk, .rstn,
    .init_cfg, .cfg_per_channel,
    .activation_min_in, .activation_max_in, .dst_offset_in,
    .multiplier_in, .shift_in,
    .k, .m,
    .load_quant_req, .load_quant_granted, .quant_params_valid,
    .icb_cmd_m, .icb_wr_m, .icb_cmd_s, .icb_wr_s, .icb_rsp_s, .icb_rsp_m,
    .in_valid, .in_vec_s32, .out_valid, .out_vec_s8
  );

  // ---------- ICB "slave" model ----------
  // from-side ready 固定拉高；无写通道
  assign icb_cmd_s.ready   = 1'b1;
  assign icb_wr_s.w_ready  = 1'b1;

  // 地址分类：mul/shift
  function automatic bit f_is_mul(input logic [31:0] a);
    return (a[31:28] == MUL_BASE[31:28]); // 简单比较高 nibble
  endfunction

  // 根据地址求 tile_col： (addr - base) / (VLEN*4)
  function automatic int f_tile_col(input logic [31:0] a, input bit is_mul);
    logic [31:0] base;
    begin
      base = is_mul ? MUL_BASE : SH_BASE;
      return integer'((a - base) / (VLEN*BYTES_PER_WORD));
    end
  endfunction

  // 生成“假” mul/shift 数据（确定性）
  function automatic logic signed [31:0] gen_mul(input int tile, input int lane);
    return 32'sh4000_0000 + tile*16 + lane;
  endfunction
  function automatic logic signed [31:0] gen_shf(input int tile, input int lane);
    int s;
    begin
      s = (lane % 5) - 2;   // -2..+2
      return s;
    end
  endfunction

  typedef struct packed {
    bit          is_mul;
    int          tile_col;
    int          beats_total; // len+1
  } tr_t;

  tr_t q[$];       // 命令队列
  tr_t cur;        // 正在服务的突发
  int  lat_cnt;
  int  beat_idx;

  // 捕获命令，排队等待返回
  int total_cmds;
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      q.delete();
      total_cmds <= 0;
    end else begin
      if (icb_cmd_m.valid && icb_cmd_s.ready && icb_cmd_m.read) begin
        tr_t t;
        t.is_mul      = f_is_mul(icb_cmd_m.addr);
        t.tile_col    = f_tile_col(icb_cmd_m.addr, t.is_mul);
        t.beats_total = icb_cmd_m.len + 1;
        q.push_back(t);
        total_cmds   <= total_cmds + 1;
        $display("[%0t] ICB CMD  %s  addr=0x%08x  len=%0d  tile_col=%0d",
                 $time, t.is_mul?"MUL ":"SHFT", icb_cmd_m.addr, icb_cmd_m.len, t.tile_col);
      end
    end
  end

  // 发送响应：固定延迟 LAT 后，连续 beats_total 个拍
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      icb_rsp_s.rsp_valid <= 1'b0;
      icb_rsp_s.rsp_rdata <= '0;
      lat_cnt  <= 0;
      beat_idx <= 0;
      cur      <= '{default:'0};
    end else begin
      icb_rsp_s.rsp_valid <= 1'b0;

      // 拉取新事务
      if ((cur.beats_total == 0) && (q.size() > 0)) begin
        cur      <= q.pop_front();
        lat_cnt  <= LAT;
        beat_idx <= 0;
      end

      // 倒计时到 0 开始吐 rsp
      if (cur.beats_total != 0) begin
        if (lat_cnt != 0) begin
          lat_cnt <= lat_cnt - 1;
        end else begin
          icb_rsp_s.rsp_valid <= 1'b1;
          icb_rsp_s.rsp_rdata <= cur.is_mul
                                  ? gen_mul(cur.tile_col, beat_idx)
                                  : gen_shf(cur.tile_col, beat_idx);
          beat_idx <= beat_idx + 1;

          if (beat_idx + 1 == cur.beats_total) begin
            cur <= '{default:'0};
          end
        end
      end
    end
  end

  // ---------- 监视 DUT 的内部状态（可选） ----------
`ifdef TB_BIND_SM
  typedef enum logic [1:0] {IDLE=2'd0, LOAD=2'd1, COMPUTE=2'd2, TILE_COMPLETE=2'd3} st_e;
  module sm_probe(
    input logic clk,
    input logic [1:0] state,
    input logic       load_phase  // 0: MUL, 1: SHIFT
  );
    logic [1:0] state_q;
    always_ff @(posedge clk) begin
      state_q <= state;
      if (state != state_q) begin
        string sn;
        case (state)
          2'd0: sn="IDLE";
          2'd1: sn="LOAD";
          2'd2: sn="COMPUTE";
          2'd3: sn="TILE_COMPLETE";
          default: sn="UNK";
        endcase
        $display("[%0t] STATE -> %s  (load_phase=%0d)", $time, sn, load_phase);
      end
    end
  endmodule
  // 若你的内部名不同，改这里实参
  bind vec_requant sm_probe u_sm_probe(.clk(clk), .state(state), .load_phase(load_phase));
`endif

  // ---------- Golden（用于 per-tensor 校验输出） ----------
  function automatic signed [31:0] left_shift_apply(input signed [31:0] val, input signed [31:0] shift_s);
    reg [5:0] lsh;
    begin
      lsh = (shift_s > 0) ? shift_s[5:0] : 6'd0;
      left_shift_apply = (lsh == 0) ? val : (val <<< lsh);
    end
  endfunction

  function automatic signed [31:0] doubling_high_mult_round(input signed [31:0] a, input signed [31:0] mlt);
    reg signed [63:0] prod, prod2, adj;
    begin
      prod  = a * mlt;
      prod2 = prod <<< 1;
      adj   = prod2 + 64'sh0000_0000_4000_0000;
      doubling_high_mult_round = adj >>> 31;
    end
  endfunction

  function automatic signed [31:0] divide_by_power_of_two_round(input signed [31:0] val, input [5:0] rsh);
    reg signed [31:0] add;
    begin
      if (rsh == 0) divide_by_power_of_two_round = val;
      else begin
        add = (val >= 0) ? (32'sd1 <<< (rsh - 1))
                         : ((32'sd1 <<< (rsh - 1)) - 32'sd1);
        divide_by_power_of_two_round = (val + add) >>> rsh;
      end
    end
  endfunction

  function automatic signed [7:0] golden_lane_tensor(
      input signed [31:0] x,
      input signed [31:0] pt_mul,
      input signed [31:0] pt_shf,
      input signed [31:0] act_min, input signed [31:0] act_max,
      input signed [31:0] dst_off
  );
    logic signed [31:0] sneg, a, hm, rq;
    logic [5:0] rsh;
    begin
      sneg = ~pt_shf + 1'b1;
      rsh  = (pt_shf < 0) ? sneg[5:0] : 6'd0;
      a  = left_shift_apply(x, pt_shf);
      hm = doubling_high_mult_round(a, pt_mul);
      rq = divide_by_power_of_two_round(hm, rsh);
      rq = rq + dst_off;
      if (rq < act_min) rq = act_min;
      if (rq > act_max) rq = act_max;
      if      (rq >  32'sd127)  golden_lane_tensor = 8'sd127;
      else if (rq < -32'sd128)  golden_lane_tensor = -8'sd128;
      else                      golden_lane_tensor = rq[7:0];
    end
  endfunction

  // ---------- 工具 ----------
  // task automatic feed_one_row(input int row_idx);
  //   int i;
  //   begin
  //     for (i=0;i<VLEN;i++) in_vec_s32[i] = row_idx*1000 + i;
  //     in_valid = 1'b1; //
  //     //in_valid = 1'b0;
  //   end
  // endtask
  task automatic feed_one_row(input int row_idx);
  int i;
  int valid_cols;
  begin
    // 在 TB 中知道 cfg_per_channel 与 m，按需生成尾0
    if (!cfg_per_channel) begin
      valid_cols = (m + VLEN - 1) / VLEN; // 错误写法示例，实际要是 f_lane_need(m, VLEN, 0)
      // 正确写法：
      valid_cols = (m > VLEN) ? VLEN : m; // 仅对第一 tile 情况的快速处理
      // 更通用：
      // valid_cols = (m >= VLEN) ? VLEN : m;
    end else begin
      // per-channel 情况 TB 通常填满 16（或者按 lane_need_q 填）
      valid_cols = VLEN;
    end

    for (i=0; i<VLEN; i++)
      in_vec_s32[i] = (i < valid_cols) ? (row_idx*1000 + i) : 0;

    in_valid = 1'b1;
    // @(posedge clk);
    // in_valid = 1'b0;
  end
endtask

  // 统计 out_valid 的个数（等待 n 次 out_valid 脉冲）
  task automatic wait_out_rows(input int n);
    int seen;
    int to;
    begin
      seen = 1;
      to   = 1000;
      while ((seen < n) && (to > 0)) begin
        @(posedge clk);
        if (out_valid) seen++;
        to--;
      end
      if (seen < n) begin
        $display("[%0t] ERROR: wait_out_rows timeout seen=%0d expected=%0d", $time, seen, n);
        $fatal;
      end
    end
  endtask

  // 按 tile 喂数据：每次喂 min(VLEN, 剩余k) 行
  // 确保在 quant_params_valid 上升沿后的下一个周期开始喂入
  task automatic feed_rows_per_k(input int k_total);
    int fed;
    int rows_this_tile;
    //int row_idx;
    int to;
    reg qpv_d;
    begin
      fed = 0;
      //row_idx = 0;

      while (fed < k_total) begin
        rows_this_tile = ((k_total - fed) >= VLEN) ? VLEN : (k_total - fed);

        // 等待 quant_params_valid 上升（若已经为1也要在 next cycle 开始）
        // 先同步，检测 edge
        // @(posedge clk);
        // qpv_d = quant_params_valid;
        // to = 5000;
        // while ((qpv_d == quant_params_valid) && (to > 0)) begin
        //   // 如果 quant_params_valid 目前为 0，会在这里循环直到变为1
        //   // 如果已经是1，则此循环马上退出（因为 qpv_d==1 and quant_params_valid==1 -> need next posedge below)
        //   @(posedge clk);
        //   to -= 1;
        // end
        // if (to == 0) begin
        //   $display("[%0t] ERROR: timeout waiting for quant_params_valid to change (maybe DUT stuck)", $time);
        //   $fatal;
        // end

        // 确保在 quant_params_valid 抬高后的下一个时钟周期才开始发 in_valid（edge-to-next-cycle）
        @(posedge clk);

        // now feed rows_this_tile lines
        for (int i = 0; i < rows_this_tile; i++) begin
          // for (int j = 0; j < VLEN; j++) in_vec_s32[j] = row_idx*1000 + j;
          // in_valid = 1'b1; @(posedge clk);
          // in_valid = 1'b0;
          feed_one_row(rows_this_tile);
          //row_idx++;
        end
        
        // 等待这 rows_this_tile 行都被计算完成（对应 rows_this_tile 个 out_valid）
        wait_out_rows(rows_this_tile);

        fed += rows_this_tile;

        // 等 DUT 完成本 tile 并回到 IDLE（quant_params_valid 会被 DUT 拉回 0）
        // 先等待下一个时钟再等待 quant_params_valid == 0
        //repeat(3) @(posedge clk);
        // to = 5000;
        // while ((quant_params_valid != 1'b0) && (to > 0)) begin
        //   @(posedge clk);
        //   to -= 1;
        // end
        // if (to == 0) begin
        //   $display("[%0t] ERROR: timeout waiting for quant_params_valid to clear after tile", $time);
        //   $fatal;
        // end

      end
    end
  endtask

  // ICB 命令顺序断言（per-channel）
  int pc_cmd_seen;
  int pc_cmd_seen_clr;
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pc_cmd_seen <= 0;
    end else if (pc_cmd_seen_clr) begin
      pc_cmd_seen <= 0;
    end else begin
      if (cfg_per_channel && icb_cmd_m.valid && icb_cmd_s.ready && icb_cmd_m.read) begin
        // ---- 把声明放在块首，且不初始化 ----
        int          pair_idx;
        int          tile_in_row;
        bit          is_mul;
        int          need;
        int          exp_len;
        logic [31:0] exp_addr;

        // ---- 先计算期望 ----
        pair_idx    = pc_cmd_seen >> 1;                 // 每两个命令一个 tile，计算目前处理的tile数量
        tile_in_row = pair_idx % TILES_PER_ROW_PC;      //当前命令对在一行中处于第几个tile
        is_mul      = (pc_cmd_seen[0] == 1'b0);

        if (M_COLS_PC - tile_in_row*VLEN > 0) begin
          if ((M_COLS_PC - tile_in_row*VLEN) >= VLEN) need = VLEN;
          else                                        need = (M_COLS_PC - tile_in_row*VLEN);
        end else begin
          need = 0;
        end

        exp_len  = (need>0) ? (need-1) : 0;
        exp_addr = (is_mul ? MUL_BASE : SH_BASE) + tile_in_row*VLEN*BYTES_PER_WORD;

        // ---- 断言 ----
        assert(icb_cmd_m.len == exp_len)
          else $fatal("[%0t] LEN mismatch: got=%0d exp=%0d (tile=%0d %s)",
                      $time, icb_cmd_m.len, exp_len, tile_in_row, is_mul?"mul":"shf");

        assert(icb_cmd_m.addr == exp_addr)
          else $fatal("[%0t] ADDR mismatch: got=0x%08x exp=0x%08x (tile=%0d %s)",
                      $time, icb_cmd_m.addr, exp_addr, tile_in_row, is_mul?"mul":"shf");

        pc_cmd_seen <= pc_cmd_seen + 1;
      end
    end
  end

  // ---------- Testcases ----------
  task automatic run_per_tensor_case();
    // 本地变量声明在最前
    int r;
    int i;
    int cmds_before;

    $display("\n==== PER-TENSOR CASE START ====\n");
    cmds_before = total_cmds;

    init_cfg          <= 0;
    cfg_per_channel   <= 0;
    activation_min_in <= -128;
    activation_max_in <=  127;
    dst_offset_in     <= 0;

    // per-tensor 固定量化参数
    multiplier_in     <= 32'sh4000_0000;
    shift_in          <= 32'sd0;
    k                 <= K_ROWS_PT;
    m                 <= M_COLS_PT;

    in_valid          <= 0;
    for (r=0;r<VLEN;r++) in_vec_s32[r] <= 0;

    @(posedge clk); init_cfg <= 1; @(posedge clk); init_cfg <= 0;

    // 驱动 16 行；per-tensor 下不应发 ICB 命令
    for (r=0; r<k; r++) begin
      feed_one_row(r);
      @(posedge clk) in_valid = 1'b0;
      //@(posedge clk);
      if (out_valid) begin
        for (i=0;i<VLEN;i++) begin
          logic [7:0] g;
          g = golden_lane_tensor(in_vec_s32[i],
                                 multiplier_in, shift_in,
                                 activation_min_in, activation_max_in, dst_offset_in);
          assert(out_vec_s8[i] === g)
            else $fatal("per-tensor lane %0d mismatch: got=%0d exp=%0d", i, out_vec_s8[i], g);
        end
      end
    end

    repeat(10) @(posedge clk);

    assert(total_cmds == cmds_before)
      else $fatal("per-tensor: DUT should not issue ICB read; saw %0d new cmds",
                  total_cmds - cmds_before);

    $display("\n==== PER-TENSOR CASE PASS ====\n");
  endtask


  task automatic run_per_channel_case();
    int r;
    int target_cmds;
    int timeout;
    int NUM_COL_TILES;
    $display("\n==== PER-CHANNEL CASE START ====\n");

    // 基本配置
    init_cfg          <= 0;
    cfg_per_channel   <= 1;
    activation_min_in <= -128;
    activation_max_in <=  127;
    dst_offset_in     <= 0;
    multiplier_in     <= MUL_BASE;   // 基地址复用进接口
    shift_in          <= SH_BASE;
    k                 <= K_ROWS_PC;  // 行数
    m                 <= M_COLS_PC;  // 列数
    in_valid          <= 0;
    for (r = 0; r < VLEN; r++) in_vec_s32[r] = 0;

    // 初始化
    @(posedge clk); init_cfg <= 1; @(posedge clk); init_cfg <= 0;

    // 观察 ICB 的统计从 0 开始
    pc_cmd_seen_clr = 1'b1; @(posedge clk); pc_cmd_seen_clr = 1'b0;
    NUM_COL_TILES = (M_COLS_PC + VLEN - 1) / VLEN;
    // ★ 核心：按 tile 喂行（例如 k=30 → 先喂16行，再喂14行；k=1 → 只喂1行）
    for (int tc = 0; tc < NUM_COL_TILES; tc++) begin
      feed_rows_per_k(K_ROWS_PC);
    end

    // ICB 命令条数检查：只与列方向有关 = ceil(m/16) × (MUL+SHIFT)
    target_cmds = ((M_COLS_PC + VLEN - 1) / VLEN) * 2;
    timeout     = 500;
    while (pc_cmd_seen < target_cmds && timeout > 0) begin
      @(posedge clk); timeout--;
    end
    assert (timeout > 0)
      else $fatal("per-channel: timeout. cmd count got=%0d exp=%0d", pc_cmd_seen, target_cmds);
        repeat (10) @(posedge clk);

    $display("\n==== PER-CHANNEL CASE PASS ====\n");
  endtask

  // ---------- grant=req ----------
  initial begin
    load_quant_granted = 1'b0;
    forever begin
      @(posedge clk);
      load_quant_granted <= load_quant_req;
    end
  end

  // ---------- Top Stimulus ----------
  initial begin
    @(posedge rstn);
    repeat(3) @(posedge clk);

    run_per_tensor_case();
    repeat(20) @(posedge clk);

    run_per_channel_case();
    repeat(40) @(posedge clk);

    $display("\n==== ALL TESTS PASS ====\n");
    $finish;
  end

  initial begin
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0, requant_tb);   // TB 全部
    $fsdbDumpvars(0, dut);          // DUT 顶层全部 I/O
    $fsdbDumpMDA(0, dut);           // 抓多维/数组 (in_vec_s32/out_vec_s8/ch_* 等)
  end

  // 可视化输出（可选）
  always_ff @(posedge clk) begin
    if (out_valid) begin
      int i;
      $write("[%0t] OUT:", $time);
      for (i=0;i<VLEN;i++) $write(" %0d", out_vec_s8[i]);
      $write("\n");
    end
  end

endmodule
