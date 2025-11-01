`timescale 1ns/1ps
`include "define.svh"
`include "icb_types.svh"

module bias_loader_tb;

  localparam int SIZE           = 16;
  localparam int DATA_WIDTH     = 32;
  localparam int REG_WIDTH      = 32;
  localparam int BYTES_PER_WORD = `E203_XLEN/8;
  localparam int LAT            = 2;   // ICB 响应延迟
  localparam int PS_PER_TILE    = 4;   // 一个 tile 做 4 次部分和
  localparam int CYCLES_PER_PS  = 6;   // 每次部分和窗口持续 6 个时钟

  // ---------------- DUT 端口 ----------------
  logic                     clk = 0, rst_n = 0;
  logic                     init_cfg;
  logic [REG_WIDTH-1:0]     bias_base;
  logic [REG_WIDTH-1:0]     k, m;

  icb_ext_cmd_m_t           icb_cmd_m;
  icb_ext_wr_m_t            icb_wr_m;
  icb_ext_cmd_s_t           icb_cmd_s;
  icb_ext_wr_s_t            icb_wr_s;
  icb_ext_rsp_s_t           icb_rsp_s;
  icb_ext_rsp_m_t           icb_rsp_m;

  logic                     partial_sum_calc_over;
  logic                     tile_calc_over;

  logic                     load_bias_req, load_bias_granted;
  logic                     bias_valid;

  logic [DATA_WIDTH-1:0]    data_out [SIZE];

  // 时钟
  always #5 clk = ~clk;

  // ---------------- DUT ----------------
  bias_loader #(
    .SIZE(SIZE), .DATA_WIDTH(DATA_WIDTH), .REG_WIDTH(REG_WIDTH)
  ) dut (
    .clk, .rst_n,
    .init_cfg,
    .bias_base, .k, .m,
    .icb_cmd_m, .icb_wr_m, .icb_cmd_s, .icb_wr_s, .icb_rsp_s, .icb_rsp_m,
    .partial_sum_calc_over, .tile_calc_over,
    .load_bias_req, .load_bias_granted,
    .bias_valid,
    .data_out
  );

  // ---------------- ICB 从设备模型 ----------------
  assign icb_cmd_s.ready  = 1'b1;
  assign icb_wr_s.w_ready = 1'b1;

  typedef struct packed {
    int tile_idx;
    int beats_total; // len+1
  } tr_t;

  tr_t q[$];
  tr_t cur;
  int  lat_cnt, beat_idx;

  function automatic int f_tile_idx(input logic [31:0] a);
    return integer'((a - bias_base) / (SIZE*BYTES_PER_WORD));
  endfunction
  function automatic logic [31:0] gen_bias(input int tile, input int lane);
    return 32'hB000_0000 + tile*32 + lane;
  endfunction

  // 捕获命令
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q.delete();
    else if (icb_cmd_m.valid && icb_cmd_s.ready && icb_cmd_m.read) begin
      tr_t t;
      t.tile_idx    = f_tile_idx(icb_cmd_m.addr);
      t.beats_total = icb_cmd_m.len + 1;
      q.push_back(t);
      $display("[%0t] ICB CMD: addr=0x%08x len=%0d tile=%0d",
               $time, icb_cmd_m.addr, icb_cmd_m.len, t.tile_idx);
    end
  end

  // 发送响应
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      icb_rsp_s.rsp_valid <= 1'b0;
      icb_rsp_s.rsp_rdata <= '0;
      cur <= '{default:'0}; lat_cnt <= 0; beat_idx <= 0;
    end else begin
      icb_rsp_s.rsp_valid <= 1'b0;
      if ((cur.beats_total==0) && (q.size()>0)) begin
        cur <= q.pop_front(); lat_cnt <= LAT; beat_idx <= 0;
      end
      if (cur.beats_total!=0) begin
        if (lat_cnt!=0) lat_cnt <= lat_cnt - 1;
        else begin
          icb_rsp_s.rsp_valid <= 1'b1;
          icb_rsp_s.rsp_rdata <= gen_bias(cur.tile_idx, beat_idx);
          beat_idx <= beat_idx + 1;
          if ((beat_idx+1)==cur.beats_total) cur <= '{default:'0};
        end
      end
    end
  end

  // grant=req
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) load_bias_granted <= 1'b0;
    else        load_bias_granted <= load_bias_req;
  end

  // ---------------- 工具函数/任务 ----------------
// 计算第二维该 tile 需要的有效列数（用于校验尾块补 0）
  function automatic int cols_need(input int total_m, input int vlen, input int t);
  int remain = (total_m > (t*vlen)) ? (total_m - t*vlen) : 0;
  return (remain>=vlen) ? vlen : remain;
endfunction

// 校验偏置（有效 lane 等于 need，其他 lane=0）
task automatic check_bias_vec(input int tile_idx, input int need);
  for (int i=0; i<SIZE; i++) begin
    logic [31:0] exp = (i<need) ? (32'hB000_0000 + tile_idx*32 + i) : 32'd0; // 与 ICB 模型一致
    if (data_out[i] !== exp)
      $fatal("[%0t] EXPECT bias: lane%0d got=0x%08x exp=0x%08x (tile=%0d need=%0d)",
             $time, i, data_out[i], exp, tile_idx, need);
  end
endtask

task automatic check_all_zero();
  for (int i=0; i<SIZE; i++)
    if (data_out[i] !== 32'd0)
      $fatal("[%0t] EXPECT zero: lane%0d got=0x%08x", $time, i, data_out[i]);
endtask

// 严格 4 次部分和的 tile 流程
task automatic run_one_tile(input int tile_idx);
  int need = cols_need(m, SIZE, tile_idx);
  int ps_cnt = 0;

  // 等待偏置有效（预取完成）
  wait (bias_valid==1'b1);
  @(posedge clk);

  // 第一次部分和窗口：持续若干拍，输出必须是偏置
  repeat (CYCLES_PER_PS) begin
    check_bias_vec(tile_idx, need);
    @(posedge clk);
  end
  partial_sum_calc_over = 1'b1; @(posedge clk);
  partial_sum_calc_over = 1'b0; ps_cnt++; @(posedge clk);

  // 第 2/3/4 次部分和窗口：输出必须是 0，每次窗口尾打一拍 ps_over
  for (int ps=2; ps<=PS_PER_TILE; ps++) begin
    repeat (CYCLES_PER_PS) begin
      check_all_zero();
      @(posedge clk);
    end
    partial_sum_calc_over = 1'b1; @(posedge clk);
    partial_sum_calc_over = 1'b0; ps_cnt++; @(posedge clk);
  end

  // 确保恰好 4 次 ps_over
  assert (ps_cnt == PS_PER_TILE)
    else $fatal("[%0t] ps_over count error: got=%0d exp=%0d", $time, ps_cnt, PS_PER_TILE);

  // 整个 tile 结束 → 触发下一块预取
      @(posedge clk);
  tile_calc_over <= 1'b1; @(posedge clk);
  tile_calc_over <= 1'b0; @(posedge clk);

  // bias_valid 应在 tile_over 后被清
  assert (bias_valid==1'b0)
    else $fatal("[%0t] bias_valid should clear after tile_calc_over", $time);
endtask


  // ---------------- 主激励 ----------------
  initial begin
    partial_sum_calc_over <= 1'b0;
    tile_calc_over        <= 1'b0;
    init_cfg              <= 1'b0;
    bias_base             <= 32'h6000_0000;
    k <= 10; m <= 26;

    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    // init：触发首块预取
    @(posedge clk); init_cfg <= 1;
    @(posedge clk); init_cfg <= 0;

    // 跑两个 tile：tile0(16 lanes 满) + tile1(10 lanes 尾块)
    run_one_tile(0);
    run_one_tile(1);

    $display("\n==== ALL TESTS PASS (multi-PS per tile) ====\n");
    $finish;
  end

  // 可视化
  always_ff @(posedge clk) begin
    if (dut.use_bias_now) begin
      $write("[%0t] data_out:", $time);
      for (int i=0;i<SIZE;i++) $write(" %0d", data_out[i]);
      $write("\n");
    end
  end

  initial begin
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0, bias_loader_tb);   // TB 全部
    $fsdbDumpvars(0, dut);          // DUT 顶层全部 I/O
    $fsdbDumpMDA(0, dut);           // 抓多维/数组 (in_vec_s32/out_vec_s8/ch_* 等)
  end

endmodule
