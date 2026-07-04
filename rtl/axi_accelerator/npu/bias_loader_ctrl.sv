/*
 * bias_loader_ctrl -- compact on-demand bias group loader.
 *
 * The previous controller kept a prefetch path plus duplicated "next group"
 * metadata.  That was good for hiding a small amount of bias latency, but it
 * cost several thousand LUTs after synthesis.  This version keeps the external
 * handshake semantics and the two-bank buffer, but loads the next group only
 * when the compute schedule raises bias_switch.  The NPU controller already
 * waits for bias_valid before issuing IA, so correctness is preserved while the
 * control network is much smaller.
 */

module bias_loader_ctrl #(
    parameter int unsigned SIZE      = 8,
    parameter int unsigned REG_WIDTH = 32,
    parameter int unsigned COUNT_WIDTH = REG_WIDTH
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
    output logic [7:0]           dma_burst_len_m1,
    output logic                 load_bank,

    output logic [COUNT_WIDTH-1:0] current_block_idx,
    output logic [COUNT_WIDTH-1:0] load_block_idx,
    output logic [COUNT_WIDTH-1:0] group_blocks_needed,
    output logic                 active_bank,
    output logic                 switch_pending
);

  localparam int unsigned SIZE_SHIFT = $clog2(SIZE);
  localparam int unsigned BLOCK_ADDR_SHIFT = SIZE_SHIFT + 2;
  localparam int unsigned CNT_W = (COUNT_WIDTH < 1) ? 1 : COUNT_WIDTH;
  typedef logic [CNT_W-1:0] count_t;

  typedef enum logic [3:0] {
    S_IDLE       = 4'd0,
    S_INIT_GEOM  = 4'd1,
    S_INIT_LAST  = 4'd2,
    S_INIT_MARK  = 4'd3,
    S_INIT_GROUP = 4'd4,
    S_CMD        = 4'd5,
    S_REQ        = 4'd6,
    S_LOAD       = 4'd7,
    S_WAIT       = 4'd8,
    S_NEXT_IDX   = 4'd9,
    S_NEXT_MARK  = 4'd10,
    S_NEXT_GROUP = 4'd11
  } state_t;

  (* fsm_encoding = "sequential" *) state_t state;

  logic [REG_WIDTH-1:0] cfg_bias_base;
  count_t cfg_m;
  count_t cfg_bias_step_blocks;
  count_t num_blocks;
  count_t last_block_elems;
  count_t step_blocks_eff;
  count_t last_group_start_idx;
  logic                 current_is_last_group;
  logic                 bias_switch_d;

  wire bias_switch_rise = bias_switch && !bias_switch_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state                  <= S_IDLE;
      cfg_bias_base          <= '0;
      cfg_m                  <= '0;
      cfg_bias_step_blocks   <= '0;
      num_blocks             <= '0;
      last_block_elems       <= '0;
      step_blocks_eff        <= count_t'(1);
      last_group_start_idx   <= '0;
      current_is_last_group  <= 1'b1;
      current_block_idx      <= '0;
      load_block_idx         <= '0;
      group_blocks_needed    <= '0;
      active_bank            <= 1'b0;
      load_bank              <= 1'b0;
      switch_pending         <= 1'b0;
      load_bias_req          <= 1'b0;
      dma_start              <= 1'b0;
      dma_base_addr          <= '0;
      dma_rows_to_read       <= '0;
      dma_burst_len_m1       <= '0;
      bias_switch_d          <= 1'b0;
    end else begin
      dma_start     <= 1'b0;
      bias_switch_d <= bias_switch;

      if (init_cfg) begin
        cfg_bias_base        <= bias_base;
        cfg_m                <= count_t'(m);
        cfg_bias_step_blocks <= count_t'(bias_step_blocks);
        num_blocks           <= '0;
        last_block_elems     <= '0;
        step_blocks_eff      <= count_t'(1);
        last_group_start_idx <= '0;
        current_is_last_group <= 1'b1;
        current_block_idx    <= '0;
        load_block_idx       <= '0;
        group_blocks_needed  <= '0;
        active_bank          <= 1'b0;
        load_bank            <= 1'b0;
        switch_pending       <= 1'b0;
        load_bias_req        <= 1'b0;
        dma_base_addr        <= bias_base;
        dma_rows_to_read     <= '0;
        dma_burst_len_m1     <= '0;
        state                <= S_INIT_GEOM;
      end else begin
        unique case (state)
          S_IDLE: begin
            load_bias_req <= 1'b0;
            switch_pending <= 1'b0;
          end

          S_INIT_GEOM: begin
            num_blocks       <= (cfg_m == '0) ? '0 :
                                ((cfg_m + count_t'(SIZE - 1)) >> SIZE_SHIFT);
            last_block_elems <= (cfg_m == '0) ? '0 :
                                (((cfg_m & count_t'(SIZE - 1)) == '0)
                                  ? count_t'(SIZE)
                                  : (cfg_m & count_t'(SIZE - 1)));
            step_blocks_eff  <= (cfg_bias_step_blocks == '0) ? count_t'(1) :
                                cfg_bias_step_blocks;
            state            <= S_INIT_LAST;
          end

          S_INIT_LAST: begin
            last_group_start_idx <= (num_blocks <= step_blocks_eff) ? '0 :
                                    (num_blocks - step_blocks_eff);
            state                <= S_INIT_MARK;
          end

          S_INIT_MARK: begin
            current_is_last_group <= (num_blocks == '0) ||
                                     (last_group_start_idx == '0);
            current_block_idx     <= '0;
            load_block_idx        <= '0;
            active_bank           <= 1'b0;
            load_bank             <= 1'b0;
            state                 <= S_INIT_GROUP;
          end

          S_INIT_GROUP: begin
            group_blocks_needed <= (num_blocks == '0) ? '0 :
                                   (current_is_last_group
                                     ? num_blocks
                                     : step_blocks_eff);
            state               <= S_CMD;
          end

          S_CMD: begin
            dma_base_addr    <= cfg_bias_base + (REG_WIDTH'(load_block_idx) << BLOCK_ADDR_SHIFT);
            dma_rows_to_read <= REG_WIDTH'(group_blocks_needed);
            if (group_blocks_needed == '0) begin
              dma_burst_len_m1 <= 8'd0;
            end else if ((group_blocks_needed == count_t'(1)) &&
                         current_is_last_group) begin
              dma_burst_len_m1 <= 8'(last_block_elems - REG_WIDTH'(1));
            end else begin
              dma_burst_len_m1 <= 8'(SIZE - 1);
            end
            switch_pending <= (group_blocks_needed != '0);
            load_bias_req  <= (group_blocks_needed != '0);
            state          <= (group_blocks_needed == '0) ? S_IDLE : S_REQ;
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
              if (current_is_last_group && bias_last_loop) begin
                load_bias_req   <= 1'b0;
                switch_pending  <= 1'b0;
                state           <= S_IDLE;
              end else begin
                switch_pending        <= (num_blocks != '0);
                load_bank             <= ~active_bank;
                state                 <= (num_blocks == '0) ? S_IDLE : S_NEXT_IDX;
              end
            end
          end

          S_NEXT_IDX: begin
            load_block_idx <= current_is_last_group ? '0 :
                              (current_block_idx + step_blocks_eff);
            state          <= S_NEXT_MARK;
          end

          S_NEXT_MARK: begin
            current_block_idx     <= load_block_idx;
            current_is_last_group <= (num_blocks == '0) ||
                                     (load_block_idx >= last_group_start_idx);
            state                 <= S_NEXT_GROUP;
          end

          S_NEXT_GROUP: begin
            group_blocks_needed <= (num_blocks == '0) ? '0 :
                                   (current_is_last_group
                                     ? (num_blocks - load_block_idx)
                                     : step_blocks_eff);
            state               <= S_CMD;
          end

          default: state <= S_IDLE;
        endcase
      end
    end
  end

  wire unused_dma_busy = dma_busy;
  wire unused_load_block_valid = load_block_valid;

endmodule
