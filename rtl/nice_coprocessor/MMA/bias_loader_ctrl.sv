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

  localparam int SIZE_SHIFT = $clog2(SIZE);
  localparam int BLOCK_ADDR_SHIFT = SIZE_SHIFT + 2;

  typedef enum logic [2:0] {
    S_IDLE = 3'd0,
    S_REQ  = 3'd1,
    S_LOAD = 3'd2,
    S_WAIT = 3'd3,
    S_DONE = 3'd4
  } state_t;

  state_t state;
  logic [REG_WIDTH-1:0] cfg_bias_base;
  logic [REG_WIDTH-1:0] num_blocks;
  logic [REG_WIDTH-1:0] last_block_elems;
  logic [REG_WIDTH-1:0] step_blocks_eff;
  logic [REG_WIDTH-1:0] last_group_start_idx;
  logic                 bias_switch_d;
  logic                 bias_switch_last_loop_pending;
  logic                 load_is_prefetch;
  logic                 prefetch_valid;
  logic                 prefetch_promoted;
  logic                 finish_after_load;
  logic                 prefetch_bank;
  logic [REG_WIDTH-1:0] prefetch_block_idx;
  logic                 current_is_last_group;
  logic [REG_WIDTH-1:0] next_group_blocks;
  logic [REG_WIDTH-1:0] next_rows_to_read;
  logic [REG_WIDTH-1:0] next_base_addr;
  logic [3:0]           next_burst_len_m1;
  logic                 next_is_last_group;
  logic                 next_meta_pending;
  logic                 init_count_pending;
  logic                 init_group_pending;
  logic                 init_cmd_pending;
  logic [REG_WIDTH-1:0] init_bias_base_r;
  logic [REG_WIDTH-1:0] init_m_r;
  logic [REG_WIDTH-1:0] init_step_blocks_r;
  logic [REG_WIDTH-1:0] init_num_blocks_r;
  logic [REG_WIDTH-1:0] init_last_block_elems_r;
  logic [REG_WIDTH-1:0] init_last_group_start_idx_r;
  logic [REG_WIDTH-1:0] init_group_blocks_r;
  logic [REG_WIDTH-1:0] init_next_block_r;
  logic [REG_WIDTH-1:0] init_next_group_blocks_r;
  logic [REG_WIDTH-1:0] init_next_base_addr_r;
  logic                 init_current_is_last_group_r;
  logic                 init_next_is_last_group_r;
  logic [3:0]           init_dma_burst_len_m1_r;
  logic [3:0]           init_next_burst_len_m1_r;

  wire bias_switch_rise = bias_switch && !bias_switch_d;

  function automatic logic f_is_last_group(input logic [REG_WIDTH-1:0] blk_idx);
    if (num_blocks == 0) f_is_last_group = 1'b1;
    else                 f_is_last_group = (blk_idx >= last_group_start_idx);
  endfunction

  function automatic logic [REG_WIDTH-1:0] f_group_blocks(input logic [REG_WIDTH-1:0] blk_idx);
    if (num_blocks == 0) begin
      f_group_blocks = '0;
    end else if (blk_idx >= last_group_start_idx) begin
      f_group_blocks = num_blocks - blk_idx;
    end else begin
      f_group_blocks = step_blocks_eff;
    end
  endfunction

  function automatic logic [3:0] f_group_burst_len(input logic [REG_WIDTH-1:0] group_blocks,
                                                   input logic                 is_last_group);
    if (group_blocks == 0) begin
      f_group_burst_len = 4'd0;
    end else if ((group_blocks == 1) && is_last_group) begin
      f_group_burst_len = 4'(last_block_elems - 1);
    end else begin
      // Multi-row DMA uses one burst length for every row.  Tail padding is
      // ignored by consumers through valid-lane counts.
      f_group_burst_len = 4'(SIZE - 1);
    end
  endfunction

  function automatic logic [REG_WIDTH-1:0] f_advance_block(input logic [REG_WIDTH-1:0] blk_idx);
    begin
      if (num_blocks == 0) begin
        f_advance_block = '0;
      end else if (blk_idx >= last_group_start_idx) begin
        f_advance_block = '0;
      end else begin
        f_advance_block = blk_idx + step_blocks_eff;
      end
    end
  endfunction

  function automatic logic [REG_WIDTH-1:0] f_block_base(input logic [REG_WIDTH-1:0] blk_idx);
    f_block_base = cfg_bias_base + (blk_idx << BLOCK_ADDR_SHIFT);
  endfunction

  task automatic refresh_next_metadata(input logic [REG_WIDTH-1:0] blk_idx);
    logic [REG_WIDTH-1:0] blocks;
    logic                 is_last;
    begin
      blocks = f_group_blocks(blk_idx);
      is_last = f_is_last_group(blk_idx);
      next_group_blocks <= blocks;
      next_rows_to_read <= blocks;
      next_base_addr    <= f_block_base(blk_idx);
      next_burst_len_m1 <= f_group_burst_len(blocks, is_last);
      next_is_last_group <= is_last;
    end
  endtask

  task automatic advance_next_after(input logic [REG_WIDTH-1:0] blk_idx);
    begin
      next_block_idx    <= f_advance_block(blk_idx);
      next_meta_pending <= 1'b1;
    end
  endtask

  task automatic setup_load_cmd(input logic [REG_WIDTH-1:0] blk_idx,
                                input logic [REG_WIDTH-1:0] rows,
                                input logic [REG_WIDTH-1:0] base_addr,
                                input logic [3:0]           burst_len_m1);
    begin
      load_block_idx      <= blk_idx;
      dma_base_addr       <= base_addr;
      dma_rows_to_read    <= rows;
      dma_burst_len_m1    <= burst_len_m1;
    end
  endtask

  task automatic request_cached_next(input logic bank,
                                     input logic is_prefetch);
    begin
      setup_load_cmd(next_block_idx, next_rows_to_read, next_base_addr, next_burst_len_m1);
      load_bank          <= bank;
      load_is_prefetch   <= is_prefetch;
      prefetch_promoted  <= 1'b0;
      finish_after_load  <= 1'b0;
      load_bias_req      <= 1'b1;
      state              <= S_REQ;
    end
  endtask

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state             <= S_IDLE;
      cfg_bias_base     <= '0;
      num_blocks        <= '0;
      last_block_elems  <= '0;
      step_blocks_eff   <= REG_WIDTH'(1);
      last_group_start_idx <= '0;
      current_block_idx <= '0;
      load_block_idx    <= '0;
      next_block_idx    <= '0;
      group_blocks_needed <= '0;
      current_is_last_group <= 1'b1;
      next_group_blocks <= '0;
      next_rows_to_read <= '0;
      next_base_addr    <= '0;
      next_burst_len_m1 <= '0;
      next_is_last_group <= 1'b1;
      next_meta_pending <= 1'b0;
      init_count_pending <= 1'b0;
      init_group_pending <= 1'b0;
      init_cmd_pending <= 1'b0;
      init_bias_base_r <= '0;
      init_m_r <= '0;
      init_step_blocks_r <= REG_WIDTH'(1);
      init_num_blocks_r <= '0;
      init_last_block_elems_r <= '0;
      init_last_group_start_idx_r <= '0;
      init_group_blocks_r <= '0;
      init_next_block_r <= '0;
      init_next_group_blocks_r <= '0;
      init_next_base_addr_r <= '0;
      init_current_is_last_group_r <= 1'b1;
      init_next_is_last_group_r <= 1'b1;
      init_dma_burst_len_m1_r <= '0;
      init_next_burst_len_m1_r <= '0;
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
      load_is_prefetch  <= 1'b0;
      prefetch_valid    <= 1'b0;
      prefetch_promoted <= 1'b0;
      finish_after_load <= 1'b0;
      prefetch_bank     <= 1'b0;
      prefetch_block_idx <= '0;
    end else begin
      dma_start <= 1'b0;
      bias_switch_d <= bias_switch;

      if (init_cfg) begin
        init_count_pending <= 1'b1;
        init_group_pending <= 1'b0;
        init_cmd_pending <= 1'b0;
        init_bias_base_r  <= bias_base;
        init_m_r          <= m;
        init_step_blocks_r <= (bias_step_blocks == 0) ? REG_WIDTH'(1) : bias_step_blocks;
        cfg_bias_base     <= bias_base;
        num_blocks        <= '0;
        last_block_elems  <= '0;
        step_blocks_eff   <= REG_WIDTH'(1);
        last_group_start_idx <= '0;
        current_block_idx <= '0;
        active_bank       <= 1'b0;
        load_bank         <= 1'b0;
        load_bias_req     <= 1'b0;
        switch_pending    <= 1'b0;
        bias_switch_last_loop_pending <= 1'b0;
        load_is_prefetch  <= 1'b0;
        prefetch_valid    <= 1'b0;
        prefetch_promoted <= 1'b0;
        finish_after_load <= 1'b0;
        prefetch_bank     <= 1'b0;
        prefetch_block_idx <= '0;
        state             <= S_IDLE;

        load_block_idx      <= '0;
        next_block_idx      <= '0;
        group_blocks_needed <= '0;
        current_is_last_group <= 1'b1;
        next_group_blocks   <= '0;
        next_rows_to_read   <= '0;
        next_base_addr      <= bias_base;
        next_burst_len_m1   <= '0;
        next_is_last_group  <= 1'b1;
        next_meta_pending   <= 1'b0;
        dma_base_addr       <= bias_base;
        dma_rows_to_read    <= '0;
        dma_burst_len_m1    <= '0;
      end else if (init_count_pending) begin
        automatic logic [REG_WIDTH-1:0] init_num_blocks;
        automatic logic [REG_WIDTH-1:0] init_last_block_elems;
        automatic logic [REG_WIDTH-1:0] init_tail_elems;
        automatic logic [REG_WIDTH-1:0] init_last_group_start_idx;

        init_count_pending <= 1'b0;
        init_group_pending <= 1'b1;
        init_num_blocks    = (init_m_r == REG_WIDTH'(0)) ? '0 : ((init_m_r + REG_WIDTH'(SIZE - 1)) >> SIZE_SHIFT);
        init_tail_elems    = init_m_r & REG_WIDTH'(SIZE - 1);
        init_last_block_elems = (init_m_r == 0) ? '0 :
                                ((init_tail_elems == '0) ? REG_WIDTH'(SIZE) : init_tail_elems);
        init_last_group_start_idx = (init_num_blocks <= init_step_blocks_r) ? '0 :
                                    (init_num_blocks - init_step_blocks_r);
        init_num_blocks_r <= init_num_blocks;
        init_last_block_elems_r <= init_last_block_elems;
        init_last_group_start_idx_r <= init_last_group_start_idx;
      end else if (init_group_pending) begin
        automatic logic [REG_WIDTH-1:0] init_group_blocks;
        automatic logic [REG_WIDTH-1:0] init_next_block;
        automatic logic [REG_WIDTH-1:0] init_next_group_blocks;
        automatic logic                 init_current_is_last_group;
        automatic logic                 init_next_is_last_group;

        init_group_pending <= 1'b0;
        init_cmd_pending   <= 1'b1;
        init_group_blocks = (init_num_blocks_r == REG_WIDTH'(0)) ? '0 :
                            ((REG_WIDTH'(0) >= init_last_group_start_idx_r)
                              ? init_num_blocks_r
                              : init_step_blocks_r);
        if (init_num_blocks_r <= REG_WIDTH'(1)) begin
          init_next_block = '0;
        end else if (init_step_blocks_r >= init_num_blocks_r) begin
          init_next_block = '0;
        end else begin
          init_next_block = init_step_blocks_r;
        end
        init_next_group_blocks = (init_num_blocks_r == REG_WIDTH'(0)) ? '0 :
                                 ((init_next_block >= init_last_group_start_idx_r)
                                   ? (init_num_blocks_r - init_next_block)
                                   : init_step_blocks_r);
        init_current_is_last_group = (init_num_blocks_r == REG_WIDTH'(0)) ? 1'b1 :
                                     (REG_WIDTH'(0) >= init_last_group_start_idx_r);
        init_next_is_last_group = (init_num_blocks_r == REG_WIDTH'(0)) ? 1'b1 :
                                  (init_next_block >= init_last_group_start_idx_r);

        init_group_blocks_r <= init_group_blocks;
        init_next_block_r <= init_next_block;
        init_next_group_blocks_r <= init_next_group_blocks;
        init_next_base_addr_r <= init_bias_base_r + (init_next_block << BLOCK_ADDR_SHIFT);
        init_current_is_last_group_r <= init_current_is_last_group;
        init_next_is_last_group_r <= init_next_is_last_group;
        init_dma_burst_len_m1_r <= ((init_group_blocks == REG_WIDTH'(0)) ? 4'd0 :
                                    (((init_group_blocks == REG_WIDTH'(1)) && init_current_is_last_group)
                                      ? 4'(init_last_block_elems_r - REG_WIDTH'(1))
                                      : 4'(SIZE - 1)));
        init_next_burst_len_m1_r <= ((init_next_group_blocks == REG_WIDTH'(0)) ? 4'd0 :
                                     (((init_next_group_blocks == REG_WIDTH'(1)) && init_next_is_last_group)
                                       ? 4'(init_last_block_elems_r - REG_WIDTH'(1))
                                       : 4'(SIZE - 1)));
      end else if (init_cmd_pending) begin
        init_cmd_pending <= 1'b0;

        cfg_bias_base     <= init_bias_base_r;
        num_blocks        <= init_num_blocks_r;
        last_block_elems  <= init_last_block_elems_r;
        step_blocks_eff   <= init_step_blocks_r;
        last_group_start_idx <= init_last_group_start_idx_r;
        load_bias_req     <= (init_num_blocks_r != REG_WIDTH'(0));
        switch_pending    <= (init_num_blocks_r != REG_WIDTH'(0));
        state             <= (init_num_blocks_r == REG_WIDTH'(0)) ? S_DONE : S_REQ;

        load_block_idx      <= '0;
        next_block_idx      <= init_next_block_r;
        group_blocks_needed <= init_group_blocks_r;
        current_is_last_group <= init_current_is_last_group_r;
        next_group_blocks   <= init_next_group_blocks_r;
        next_rows_to_read   <= init_next_group_blocks_r;
        next_base_addr      <= init_next_base_addr_r;
        next_burst_len_m1   <= init_next_burst_len_m1_r;
        next_is_last_group  <= init_next_is_last_group_r;
        next_meta_pending   <= 1'b0;
        dma_base_addr       <= init_bias_base_r;
        dma_rows_to_read    <= init_group_blocks_r;
        dma_burst_len_m1    <= init_dma_burst_len_m1_r;
      end else begin
        if (next_meta_pending) begin
          refresh_next_metadata(next_block_idx);
          next_meta_pending <= 1'b0;
        end

        if (bias_switch_rise) begin
          bias_switch_last_loop_pending <= bias_last_loop;
        end

        unique case (state)
          S_IDLE: begin
            load_bias_req <= 1'b0;
          end

          S_REQ: begin
            load_bias_req <= 1'b1;
            if (bias_switch_rise && load_is_prefetch &&
                current_is_last_group &&
                bias_last_loop) begin
              load_bias_req     <= 1'b0;
              prefetch_valid    <= 1'b0;
              prefetch_promoted <= 1'b0;
              state             <= S_DONE;
            end else begin
              if (bias_switch_rise && load_is_prefetch) begin
                current_block_idx <= load_block_idx;
                group_blocks_needed <= next_group_blocks;
                current_is_last_group <= next_is_last_group;
                advance_next_after(load_block_idx);
                switch_pending    <= 1'b1;
                load_is_prefetch  <= 1'b0;
              end
            if (load_bias_granted) begin
              load_bias_req <= 1'b0;
              dma_start     <= 1'b1;
              state         <= S_LOAD;
            end
            end
          end

          S_LOAD: begin
            if (bias_switch_rise && load_is_prefetch) begin
              if (current_is_last_group &&
                  bias_last_loop) begin
                finish_after_load <= 1'b1;
              end else begin
                current_block_idx <= load_block_idx;
                group_blocks_needed <= next_group_blocks;
                current_is_last_group <= next_is_last_group;
                advance_next_after(load_block_idx);
                switch_pending    <= 1'b1;
                prefetch_promoted <= 1'b1;
              end
            end
            if (dma_done) begin
              if (finish_after_load ||
                  (bias_switch_rise &&
                   current_is_last_group &&
                   bias_last_loop)) begin
                prefetch_valid    <= 1'b0;
                prefetch_promoted <= 1'b0;
                switch_pending    <= 1'b0;
                state             <= S_DONE;
              end else if (load_is_prefetch &&
                           !(prefetch_promoted || bias_switch_rise)) begin
                prefetch_valid     <= 1'b1;
                prefetch_block_idx <= load_block_idx;
                prefetch_bank      <= load_bank;
                prefetch_promoted  <= 1'b0;
                state              <= S_WAIT;
              end else begin
                active_bank        <= load_bank;
                prefetch_valid     <= 1'b0;
                prefetch_promoted  <= 1'b0;
                switch_pending     <= 1'b0;
                state              <= S_WAIT;
              end
            end
          end

          S_WAIT: begin
            if (bias_switch_rise) begin
              if (current_is_last_group && bias_last_loop) begin
                state         <= S_DONE;
                load_bias_req <= 1'b0;
                prefetch_valid <= 1'b0;
              end else begin
                if (prefetch_valid && (prefetch_block_idx == next_block_idx)) begin
                  current_block_idx <= next_block_idx;
                  group_blocks_needed <= next_group_blocks;
                  current_is_last_group <= next_is_last_group;
                  active_bank       <= prefetch_bank;
                  switch_pending    <= 1'b1;
                  prefetch_valid    <= 1'b0;
                  advance_next_after(next_block_idx);
                end else begin
                  current_block_idx <= next_block_idx;
                  group_blocks_needed <= next_group_blocks;
                  current_is_last_group <= next_is_last_group;
                  switch_pending    <= 1'b1;
                  prefetch_valid    <= 1'b0;
                  request_cached_next(~active_bank, 1'b0);
                  advance_next_after(next_block_idx);
                end
              end
            end else begin
              if (switch_pending) begin
                switch_pending <= 1'b0;
              end else if (!next_meta_pending &&
                  !prefetch_valid &&
                  (next_block_idx != current_block_idx) &&
                  !(current_is_last_group && bias_last_loop)) begin
                request_cached_next(~active_bank, 1'b1);
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
