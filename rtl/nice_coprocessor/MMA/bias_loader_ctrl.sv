/*
 * bias_loader_ctrl -- group-based bias block loading.
 *
 * A group contains bias_step_blocks consecutive SIZE-wide bias blocks.  WS uses
 * one block per group.  IS uses one group per IA reuse window, so R output
 * column tiles can receive their bias values without relying on a two-block
 * lookahead path.
 */

module bias_loader_ctrl #(
    parameter int unsigned SIZE      = 8,
    parameter int unsigned REG_WIDTH = 32
) (
    input  logic clk,
    input  logic rst_n,

    input  logic                 init_cfg,
    input  logic [REG_WIDTH-1:0] bias_base,
    input  logic [REG_WIDTH-1:0] m,
    input  logic [REG_WIDTH-1:0] bias_step_blocks,
    input  logic                 bias_switch,
    input  logic                 bias_last_loop,

    output logic                 load_bias_req,
    input  logic                 load_bias_granted,

    input  logic                 dma_busy,
    input  logic                 dma_done,
    input  logic                 load_block_valid,

    output logic                 dma_start,
    output logic [REG_WIDTH-1:0] dma_base_addr,
    output logic [REG_WIDTH-1:0] dma_rows_to_read,
    output logic [3:0]           dma_burst_len_m1,
    output logic                 load_bank,

    output logic [REG_WIDTH-1:0] current_block_idx,
    output logic [REG_WIDTH-1:0] load_block_idx,
    output logic [REG_WIDTH-1:0] next_block_idx,
    output logic [REG_WIDTH-1:0] group_blocks_needed,
    output logic                 active_bank,
    output logic                 switch_pending
);

  localparam int BYTES_PER_ELEM = 4;

  typedef enum logic [2:0] {
    S_IDLE = 3'd0,
    S_REQ  = 3'd1,
    S_LOAD = 3'd2,
    S_WAIT = 3'd3,
    S_DONE = 3'd4
  } state_t;

  state_t state;
  logic [REG_WIDTH-1:0] num_blocks;
  logic [REG_WIDTH-1:0] last_block_elems;
  logic                 bias_switch_d;
  logic                 bias_switch_last_loop_pending;

  wire bias_switch_rise = bias_switch && !bias_switch_d;

  function automatic logic [REG_WIDTH-1:0] f_step_blocks();
    if (bias_step_blocks == 0) f_step_blocks = REG_WIDTH'(1);
    else                       f_step_blocks = bias_step_blocks;
  endfunction

  function automatic logic [REG_WIDTH-1:0] f_block_elems(input logic [REG_WIDTH-1:0] blk_idx);
    if (num_blocks == 0) begin
      f_block_elems = '0;
    end else if (blk_idx < num_blocks - 1) begin
      f_block_elems = REG_WIDTH'(SIZE);
    end else begin
      f_block_elems = last_block_elems;
    end
  endfunction

  function automatic logic [3:0] f_group_burst_len(input logic [REG_WIDTH-1:0] blk_idx,
                                                   input logic [REG_WIDTH-1:0] group_blocks);
    if (group_blocks == 0) begin
      f_group_burst_len = 4'd0;
    end else if (group_blocks == 1) begin
      f_group_burst_len = 4'(f_block_elems(blk_idx) - 1);
    end else begin
      // Multi-row DMA uses one burst length for every row.  Tail padding is
      // ignored by consumers through valid-lane counts.
      f_group_burst_len = 4'(SIZE - 1);
    end
  endfunction

  function automatic logic [REG_WIDTH-1:0] f_group_blocks(input logic [REG_WIDTH-1:0] blk_idx);
    logic [REG_WIDTH-1:0] remaining;
    begin
      if (num_blocks == 0) begin
        f_group_blocks = '0;
      end else begin
        remaining = (blk_idx < num_blocks) ? (num_blocks - blk_idx) : REG_WIDTH'(1);
        f_group_blocks = (f_step_blocks() < remaining) ? f_step_blocks() : remaining;
        if (f_group_blocks == 0) f_group_blocks = REG_WIDTH'(1);
      end
    end
  endfunction

  function automatic logic [REG_WIDTH-1:0] f_advance_block(input logic [REG_WIDTH-1:0] blk_idx);
    logic [REG_WIDTH-1:0] adv;
    begin
      if (num_blocks == 0) begin
        f_advance_block = '0;
      end else begin
        adv = blk_idx + f_step_blocks();
        f_advance_block = adv % num_blocks;
      end
    end
  endfunction

  function automatic logic f_is_last_group(input logic [REG_WIDTH-1:0] blk_idx,
                                           input logic [REG_WIDTH-1:0] group_blocks);
    if (num_blocks == 0) f_is_last_group = 1'b1;
    else                 f_is_last_group = ((blk_idx + group_blocks) >= num_blocks);
  endfunction

  task automatic setup_load(input logic [REG_WIDTH-1:0] blk_idx);
    logic [REG_WIDTH-1:0] blocks;
    begin
      blocks = f_group_blocks(blk_idx);
      load_block_idx      <= blk_idx;
      next_block_idx      <= f_advance_block(blk_idx);
      group_blocks_needed <= blocks;
      dma_base_addr       <= bias_base + REG_WIDTH'(blk_idx * SIZE * BYTES_PER_ELEM);
      dma_rows_to_read    <= blocks;
      dma_burst_len_m1    <= f_group_burst_len(blk_idx, blocks);
    end
  endtask

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state             <= S_IDLE;
      num_blocks        <= '0;
      last_block_elems  <= '0;
      current_block_idx <= '0;
      load_block_idx    <= '0;
      next_block_idx    <= '0;
      group_blocks_needed <= '0;
      active_bank       <= 1'b0;
      load_bank         <= 1'b0;
      load_bias_req     <= 1'b0;
      dma_start         <= 1'b0;
      dma_base_addr     <= '0;
      dma_rows_to_read  <= '0;
      dma_burst_len_m1  <= '0;
      bias_switch_d     <= 1'b0;
      switch_pending    <= 1'b0;
      bias_switch_last_loop_pending <= 1'b0;
    end else begin
      dma_start <= 1'b0;
      bias_switch_d <= bias_switch;

      if (init_cfg) begin
        automatic logic [REG_WIDTH-1:0] init_num_blocks;
        automatic logic [REG_WIDTH-1:0] init_last_block_elems;

        init_num_blocks       = (m == 0) ? '0 : ((m + SIZE - 1) / SIZE);
        init_last_block_elems = (m == 0) ? '0 :
                                ((m % SIZE) == 0 ? REG_WIDTH'(SIZE) : (m % SIZE));

        num_blocks        <= init_num_blocks;
        last_block_elems  <= init_last_block_elems;
        current_block_idx <= '0;
        active_bank       <= 1'b0;
        load_bank         <= 1'b0;
        load_bias_req     <= (m != 0);
        switch_pending    <= (m != 0);
        bias_switch_last_loop_pending <= 1'b0;
        state             <= (m == 0) ? S_DONE : S_REQ;

        load_block_idx      <= '0;
        next_block_idx      <= (init_num_blocks == 0) ? '0 : f_advance_block('0);
        group_blocks_needed <= (init_num_blocks == 0) ? '0 :
                               ((f_step_blocks() < init_num_blocks) ? f_step_blocks() : init_num_blocks);
        dma_base_addr       <= bias_base;
        dma_rows_to_read    <= (init_num_blocks == 0) ? '0 :
                               ((f_step_blocks() < init_num_blocks) ? f_step_blocks() : init_num_blocks);
        dma_burst_len_m1    <= (init_num_blocks <= 1)
                               ? 4'(init_last_block_elems - 1)
                               : 4'(SIZE - 1);
      end else begin
        if (bias_switch_rise) begin
          bias_switch_last_loop_pending <= bias_last_loop;
        end

        unique case (state)
          S_IDLE: begin
            load_bias_req <= 1'b0;
          end

          S_REQ: begin
            load_bias_req <= 1'b1;
            if (load_bias_granted) begin
              load_bias_req <= 1'b0;
              dma_start     <= 1'b1;
              state         <= S_LOAD;
            end
          end

          S_LOAD: begin
            if (dma_done) begin
              active_bank    <= load_bank;
              switch_pending <= 1'b0;
              state          <= S_WAIT;
            end
          end

          S_WAIT: begin
            if (bias_switch_rise) begin
              if (f_is_last_group(current_block_idx, group_blocks_needed) && bias_last_loop) begin
                state         <= S_DONE;
                load_bias_req <= 1'b0;
              end else begin
                logic [REG_WIDTH-1:0] next_blk;
                next_blk = f_advance_block(current_block_idx);
                current_block_idx <= next_blk;
                load_bank         <= ~active_bank;
                switch_pending    <= 1'b1;
                setup_load(next_blk);
                state             <= S_REQ;
              end
            end
          end

          S_DONE: begin
            load_bias_req <= 1'b0;
          end

          default: state <= S_IDLE;
        endcase
      end
    end
  end

  // Keep formally unused inputs visible to lint without changing behavior.
  wire unused_dma_busy = dma_busy;
  wire unused_load_block_valid = load_block_valid;

endmodule
