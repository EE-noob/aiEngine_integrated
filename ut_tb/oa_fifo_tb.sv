`timescale 1ns/1ps

// Integration TB: vec_s8_to_fifo <-> oa_writer
// - Feeds a single 16x16 tile into FIFO
// - oa_writer reads via output_* handshake and emits ICB writes
// - Logs writes and checks expected count

`include "C:/Users/92150/Desktop/tflm_dsa/rtl/rtl_new/icb_types.svh"

module oa_fifo_tb();
  localparam int REG_WIDTH = 32;
  localparam int VLEN      = 16;

  // Clock and reset
  reg clk;
  reg rst_n;
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz
  end
  initial begin
    rst_n = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
  end

  // FIFO input
  reg                      in_valid;
  reg  [VLEN*8-1:0]        in_vec_s8;

  // oa_writer config/control
  reg                      init_cfg;
  reg                      write_oa_trigger;
  wire                     write_oa_req;
  reg                      write_oa_granted;
  reg  [REG_WIDTH-1:0]     dst_base;
  reg  [REG_WIDTH-1:0]     dst_row_stride_b;
  reg  [REG_WIDTH-1:0]     k;
  reg  [REG_WIDTH-1:0]     m;
  reg  [REG_WIDTH-1:0]     tile_count;

  // FIFO <-> oa_writer handshake/data
  wire                     oa_fifo_req;          // from FIFO to oa_writer
  wire [$clog2(VLEN)-1:0]  vec_valid_num_col;   // from oa_writer to FIFO (cols-1)
  wire                     output_valid;        // from FIFO
  wire                     output_ready;        // from oa_writer
  wire [3:0]               output_mask;         // from FIFO
  wire [31:0]              output_data;         // from FIFO
  wire                     output_row_switch;   // from FIFO
  wire                     fifo_full_flag;      // from FIFO (unused in TB)

  // ICB bus
  localparam bit ENABLE_BACKPRESSURE = 1'b1;
  icb_ext_cmd_m_t icb_ext_cmd_m;
  icb_ext_cmd_s_t icb_ext_cmd_s;
  icb_ext_wr_m_t  icb_ext_wr_m;
  icb_ext_wr_s_t  icb_ext_wr_s;
  icb_ext_rsp_s_t icb_ext_rsp_s;
  icb_ext_rsp_m_t icb_ext_rsp_m;

  // Backpressure generators for ICB ready: randomly hold ready low for bursts
  localparam int CMD_LOW_MAX = 5;
  localparam int WR_LOW_MAX  = 7;

  reg cmd_ready;
  reg wr_ready;
  integer cmd_low_cnt;
  integer wr_low_cnt;
  reg [31:0] bp_lfsr;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bp_lfsr     <= 32'hBA5E_EDD5;
      cmd_ready   <= 1'b1;
      wr_ready    <= 1'b1;
      cmd_low_cnt <= 0;
      wr_low_cnt  <= 0;
    end else if (!ENABLE_BACKPRESSURE) begin
      bp_lfsr     <= 32'hBA5E_EDD5;
      cmd_ready   <= 1'b1;
      wr_ready    <= 1'b1;
      cmd_low_cnt <= 0;
      wr_low_cnt  <= 0;
    end else begin
      bp_lfsr <= {bp_lfsr[30:0], bp_lfsr[31] ^ bp_lfsr[21] ^ bp_lfsr[1] ^ bp_lfsr[0]};

      // Command channel backpressure: only start a low burst when a valid cmd is present
      if (cmd_low_cnt > 0) begin
        cmd_low_cnt <= cmd_low_cnt - 1;
        cmd_ready   <= 1'b0;
      end else begin
        // default high
        cmd_ready   <= 1'b1;
        cmd_low_cnt <= 0;
        // randomly decide to inject a stall only if master is presenting a command
        if (icb_ext_cmd_m.valid && (bp_lfsr[2:0] == 3'b000)) begin
          cmd_ready   <= 1'b0;
          cmd_low_cnt <= (bp_lfsr[6:3] % CMD_LOW_MAX) + 1;
        end
      end

      // Write-data channel backpressure: only start a low burst when write data is valid
      if (wr_low_cnt > 0) begin
        wr_low_cnt <= wr_low_cnt - 1;
        wr_ready   <= 1'b0;
      end else begin
        // default high
        wr_ready   <= 1'b1;
        wr_low_cnt <= 0;
        // randomly decide to inject a stall only if master is presenting data
        if (icb_ext_wr_m.w_valid && (bp_lfsr[5:3] <= 3'b001)) begin
          wr_ready   <= 1'b0;
          wr_low_cnt <= (bp_lfsr[9:6] % WR_LOW_MAX) + 1;
        end
      end
    end
  end

  assign icb_ext_cmd_s.ready   = ENABLE_BACKPRESSURE ? cmd_ready : 1'b1;
  assign icb_ext_wr_s.w_ready  = ENABLE_BACKPRESSURE ? wr_ready : 1'b1;
  assign icb_ext_rsp_s         = '{rsp_valid:1'b0, rsp_rdata:'0, rsp_err:1'b0};


  // Always-ready command slave, ignore responses

  // Grant bus when both writer requests and FIFO has data ready.
  // This avoids early-row timeout inside oa_writer.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_oa_granted <= 1'b0;
    end else begin
      // simple model: grant whenever requested
      write_oa_granted <= write_oa_req;
    end
  end

  // DUTs
  vec_s8_to_fifo #(
    .VLEN(VLEN)
  ) u_fifo (
    .clk              (clk),
    .rst_n            (rst_n),
    .in_valid         (in_valid),
    .in_vec_s8        (in_vec_s8),
    .oa_fifo_req       (oa_fifo_req),
    .vec_valid_num_col(vec_valid_num_col),
    .output_valid     (output_valid),
    .output_ready     (output_ready),
    .output_row_switch(output_row_switch),
    .output_mask      (output_mask),
    .output_data      (output_data),
    .fifo_full_flag   (fifo_full_flag)
  );

  // Debug: observe handshake edges (can be commented out later)
  reg oa_fifo_req_q_dbg;
  always @(posedge clk) begin
    oa_fifo_req_q_dbg <= oa_fifo_req;
    if (rst_n && oa_fifo_req && !oa_fifo_req_q_dbg) $display("DBG: oa_fifo_req rise @%0t", $time);
    if (rst_n && !oa_fifo_req && oa_fifo_req_q_dbg) $display("DBG: oa_fifo_req fall @%0t", $time);
  end

  oa_writer #(
    .VLEN(VLEN),
    .DATA_WIDTH(8),
    .REG_WIDTH(REG_WIDTH)
  ) u_writer (
    .clk               (clk),
    .rst_n             (rst_n),
    .init_cfg          (init_cfg),
    .write_oa_trigger  (write_oa_trigger),
    .write_oa_req      (write_oa_req),
    .write_oa_granted  (write_oa_granted),
    .dst_base          (dst_base),
    .dst_row_stride_b  (dst_row_stride_b),
    .k                 (k),
    .m                 (m),
    .tile_count        (tile_count),
    .oa_fifo_req       (oa_fifo_req),
    .vec_valid_num_col (vec_valid_num_col),
    .output_valid      (output_valid),
    .switch_row        (output_row_switch),
    .output_ready      (output_ready),
    .output_mask       (output_mask),
    .output_data       (output_data),
    .icb_ext_cmd_m     (icb_ext_cmd_m),
    .icb_ext_cmd_s     (icb_ext_cmd_s),
    .icb_ext_wr_m     (icb_ext_wr_m),
    .icb_ext_wr_s     (icb_ext_wr_s),
    .icb_ext_rsp_s     (icb_ext_rsp_s),
    .icb_ext_rsp_m     (icb_ext_rsp_m),
    .write_done        (),
    .oa_calc_over     ()
  );

  // Write logging
  reg [31:0] log_addr [0:1023];
  reg [31:0] log_data [0:1023];
  reg [3:0]  log_mask [0:1023];
  integer    log_cnt;
  integer    exp_writes;

  // Tile-local scoreboard (helps debug without waves)
  reg        tile_chk_en;
  reg [31:0] tile_base_dbg;
  reg [31:0] tile_stride_dbg;
  integer    tile_rows_dbg;
  integer    tile_beats_dbg;
  integer    tile_local_cnt;
  reg [3:0]  tile_row_beat_mask[0:VLEN-1]; // 4 beats per row

  // Progress watchdog: stop if no new writes for many cycles
  integer wd_cnt;
  integer wd_last_log_cnt;
  localparam integer WD_MAX = 2000000; // cycles without progress
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wd_cnt          <= 0;
      wd_last_log_cnt <= -1;
    end else begin
      if (log_cnt !== wd_last_log_cnt) begin
        wd_last_log_cnt <= log_cnt;
        wd_cnt          <= 0;
      end else if (wd_cnt < WD_MAX) begin
        wd_cnt <= wd_cnt + 1;
      end else begin
        $display("WATCHDOG TIMEOUT: no write progress for %0d cycles (log_cnt=%0d)", WD_MAX, log_cnt);
        $finish;
      end
    end
  end
  wire cmd_fire = icb_ext_cmd_m.valid && icb_ext_cmd_s.ready;
  wire wr_fire  = icb_ext_wr_m.w_valid && icb_ext_wr_s.w_ready;
  reg  [31:0] cur_write_addr;
  reg         have_cmd_addr;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_write_addr <= '0;
      have_cmd_addr  <= 1'b0;
      log_cnt        <= 0;
    end else begin
      if (wr_fire) begin
        reg [31:0] addr_for_log;
        addr_for_log = cmd_fire ? icb_ext_cmd_m.addr : cur_write_addr;
        log_addr[log_cnt] <= addr_for_log;
        log_data[log_cnt] <= icb_ext_wr_m.wdata;
        log_mask[log_cnt] <= icb_ext_wr_m.wmask;
        //$display("@%0t WRITE addr=0x%08x data=0x%08x mask=%b", $time, addr_for_log, icb_ext_wr_m.wdata, icb_ext_wr_m.wmask);
        log_cnt <= log_cnt + 1;

        // Tile-local scoreboard: count only writes within current tile window
        if (tile_chk_en) begin
          int delta;
          int row_idx;
          int beat_idx;
          delta    = addr_for_log - tile_base_dbg;
          if (delta >= 0) begin
            row_idx  = delta / tile_stride_dbg;
            beat_idx = (delta % tile_stride_dbg) / 4;
            if ((row_idx >= 0) && (row_idx < tile_rows_dbg) && (beat_idx >= 0) && (beat_idx < tile_beats_dbg)) begin
              tile_row_beat_mask[row_idx][beat_idx] <= 1'b1;
              tile_local_cnt <= tile_local_cnt + 1;
            end
          end
        end
      end
      if (cmd_fire && wr_fire) begin
        cur_write_addr <= icb_ext_cmd_m.addr + 32'd4;
        have_cmd_addr  <= 1'b1;
      end else if (cmd_fire) begin
        cur_write_addr <= icb_ext_cmd_m.addr;
        have_cmd_addr  <= 1'b1;
      end else if (wr_fire && have_cmd_addr) begin
        cur_write_addr <= cur_write_addr + 32'd4;
      end
    end
  end

  // Helpers
  function integer ceil_div;
    input integer a, b; begin ceil_div = (a + b - 1)/b; end
  endfunction

  // Pack one batch (<=16 rows) for tile(TR,TC). Each row holds 16 bytes.
  // Byte pattern encodes row and tile-column to make beats unique:
  //   byte[c] = ((TR*VLEN + r) << 4) | (TC*VLEN + c)
  task feed_batch(input int TR, input int TC, input int rows_valid);
    integer r, c;
    begin
      for (r = 0; r < rows_valid; r = r + 1) begin
        in_valid = 1'b1;
        for (c = 0; c < VLEN; c = c + 1) begin
          in_vec_s8[c*8 +: 8] = ((TR*VLEN + r) << 4) | (TC*VLEN + c);
        end
        @(negedge clk);
      end
      in_valid = 1'b0; // batch end
      @(negedge clk);
    end
  endtask

  // Run a complete case with given M,K and addressing; stream batches per tile
  task run_case_fifo(
      input int M_ROWS,
      input int K_COLS,
      input [31:0] BASE_ADDR,
      input [31:0] ROW_STRIDE
  );
    int tile_rows, tile_cols;
    int TR, TC;
    int rows_valid, cols_valid, beats;
    int exp_total_writes, exp_so_far, exp_this;
    begin
      $display("\n--- RUN fifo-case: M=%0d K=%0d base=0x%08x stride=%0d ---", M_ROWS, K_COLS, BASE_ADDR, ROW_STRIDE);
      // Configure DUT
      dst_base         = BASE_ADDR;
      dst_row_stride_b = ROW_STRIDE;
      // k=rows, m=cols
      k                = M_ROWS;
      m                = K_COLS;
      tile_rows        = ceil_div(M_ROWS, VLEN);
      tile_cols        = ceil_div(K_COLS, VLEN);
      tile_count       = tile_rows * tile_cols;
      log_cnt          = 0;

      // Apply config
      @(posedge clk);
      init_cfg = 1'b1; @(posedge clk); init_cfg = 1'b0;
      @(posedge clk);
      write_oa_trigger = 1'b1; @(posedge clk); write_oa_trigger = 1'b0;

      // Compute expected total writes
      exp_total_writes = 0;
      for (TR = 0; TR < tile_rows; TR = TR + 1) begin
        for (TC = 0; TC < tile_cols; TC = TC + 1) begin
          rows_valid = (M_ROWS - TR*VLEN > VLEN) ? VLEN : (M_ROWS - TR*VLEN);
          cols_valid = (K_COLS - TC*VLEN > VLEN) ? VLEN : (K_COLS - TC*VLEN);
          beats      = ceil_div(cols_valid, 4);
          exp_total_writes += rows_valid * beats;
        end
      end

      // Stream per-tile batches; wait each tile to finish by log_cnt
      exp_so_far = 0;
      for (TR = 0; TR < tile_rows; TR = TR + 1) begin
        for (TC = 0; TC < tile_cols; TC = TC + 1) begin
          rows_valid = (M_ROWS - TR*VLEN > VLEN) ? VLEN : (M_ROWS - TR*VLEN);
          cols_valid = (K_COLS - TC*VLEN > VLEN) ? VLEN : (K_COLS - TC*VLEN);
          beats      = ceil_div(cols_valid, 4);
          exp_this   = rows_valid * beats;

          // Feed this tile's data
          //$display("feed tile (TR=%0d,TC=%0d) rows=%0d cols=%0d beats/row=%0d exp_writes+=%0d", TR, TC, rows_valid, cols_valid, beats, exp_this);

          // Setup tile-local scoreboard
          tile_chk_en      = 1'b1;
          tile_base_dbg    = BASE_ADDR + (TR*VLEN)*ROW_STRIDE + (TC*VLEN);
          tile_stride_dbg  = ROW_STRIDE;
          tile_rows_dbg    = rows_valid;
          tile_beats_dbg   = beats;
          tile_local_cnt   = 0;
          for (int rr = 0; rr < VLEN; rr = rr + 1) begin
            tile_row_beat_mask[rr] = 4'b0000;
          end

          feed_batch(TR, TC, rows_valid);

          // Wait until writer completes this tile's writes, with progress prints
          begin : wait_tile_progress
            integer target_cnt;
            integer tile_wd;
            target_cnt = exp_so_far + exp_this;
            tile_wd    = 0;
            while (log_cnt < target_cnt) begin
              @(posedge clk);
              tile_wd = tile_wd + 1;
              if ((tile_wd % 200000) == 0) begin
                //$display("[tile-wait] @%0t TR=%0d TC=%0d progress=%0d/%0d (rows=%0d beats=%0d) local=%0d/%0d",
               //          $time, TR, TC, log_cnt-exp_so_far, exp_this, rows_valid, beats, tile_local_cnt, exp_this);
              end
              if (tile_wd >= 2000000) begin
              //  $display("[tile-timeout] TR=%0d TC=%0d stuck: progress=%0d/%0d log_cnt=%0d local=%0d/%0d", TR, TC,
              //           log_cnt-exp_so_far, exp_this, log_cnt, tile_local_cnt, exp_this);
                // Dump first few rows with missing beats (expected mask = (1<<beats)-1)
                for (int rr = 0; rr < rows_valid; rr = rr + 1) begin
                  int exp_mask;
                  exp_mask = (tile_beats_dbg <= 0) ? 0 : ((1 << tile_beats_dbg) - 1);
                  if (tile_row_beat_mask[rr] !== exp_mask[3:0]) begin
                   // $display("[tile-miss] row=%0d mask_seen=%b expected_mask=%b (beats=%0d)", rr, tile_row_beat_mask[rr], exp_mask[3:0], tile_beats_dbg);
                    if (rr > 8) break; // limit dump
                  end
                end
                $finish;
              end
            end
          end

          // Tile-local scoreboard off
          tile_chk_en = 1'b0;
          exp_so_far += exp_this;

          // small gap
          repeat (3) @(posedge clk);
        end
      end

      // Final check (non-fatal; report mismatch if any)
      if (log_cnt !== exp_total_writes) begin
        $display("WARN: (fifo) write count differs. got=%0d exp=%0d (M=%0d K=%0d)", log_cnt, exp_total_writes, M_ROWS, K_COLS);
      end else begin
        $display("PASS (fifo): %0d writes verified for case M=%0d K=%0d.", log_cnt, M_ROWS, K_COLS);
      end
    end
  endtask

  // Test sequence
  initial begin
    // Waves
    $dumpfile("oa_fifo_tb.vcd");
    $dumpvars(0, oa_fifo_tb);

    // defaults
    in_valid         = 1'b0;
    in_vec_s8        = '0;
    init_cfg         = 1'b0;
    write_oa_trigger = 1'b0;
    dst_base         = 32'h0000_0100;
    dst_row_stride_b = 32'h0000_0040; // 64B per row
    k                = '0;
    m                = '0;
    tile_count       = '0;
    log_cnt          = 0;

    @(posedge rst_n);
    @(posedge clk);

    // Cases similar to oa_writer_tb
    // A: Small boundary 5x7
    run_case_fifo(5, 7, 32'h0000_0100, 32'h0000_0040);
    // reset between cases to keep DUTs clean
    rst_n = 1'b0; repeat (4) @(posedge clk); rst_n = 1'b1; repeat (4) @(posedge clk);
    // B: Mixed boundary 20x23 => 2x2 tiles
    run_case_fifo(20, 23, 32'h0000_1000, 32'h0000_0080);
    rst_n = 1'b0; repeat (4) @(posedge clk); rst_n = 1'b1; repeat (4) @(posedge clk);
    // C: Full tile 16x16
    run_case_fifo(16, 16, 32'h0000_2000, 32'h0000_0040);
    rst_n = 1'b0; repeat (4) @(posedge clk); rst_n = 1'b1; repeat (4) @(posedge clk);
    // D: Two tile rows 32x16
    run_case_fifo(32, 16, 32'h0000_3000, 32'h0000_0100);
    rst_n = 1'b0; repeat (4) @(posedge clk); rst_n = 1'b1; repeat (4) @(posedge clk);
    // vec_valid_num_col sweep on K to cover diverse values
    run_case_fifo(3, 17, 32'h0000_3100, 32'h0000_0040);
    rst_n = 1'b0; repeat (4) @(posedge clk); rst_n = 1'b1; repeat (4) @(posedge clk);
    run_case_fifo(3, 18, 32'h0000_3200, 32'h0000_0040);
    rst_n = 1'b0; repeat (4) @(posedge clk); rst_n = 1'b1; repeat (4) @(posedge clk);
    run_case_fifo(3, 20, 32'h0000_3300, 32'h0000_0040);
    rst_n = 1'b0; repeat (4) @(posedge clk); rst_n = 1'b1; repeat (4) @(posedge clk);
    run_case_fifo(3, 31, 32'h0000_3400, 32'h0000_0040);
    rst_n = 1'b0; repeat (4) @(posedge clk); rst_n = 1'b1; repeat (4) @(posedge clk);
    run_case_fifo(3, 32, 32'h0000_3500, 32'h0000_0040);
    rst_n = 1'b0; repeat (4) @(posedge clk); rst_n = 1'b1; repeat (4) @(posedge clk);
    run_case_fifo(3, 33, 32'h0000_3600, 32'h0000_0040);

    $display("All FIFO integration tests completed.");
    $finish;
  end

  // Timeout guard
  initial begin
    #40000000; // 40ms guard to cover multiple cases
    $display("TIMEOUT - finishing simulation");
    $finish;
  end

endmodule

