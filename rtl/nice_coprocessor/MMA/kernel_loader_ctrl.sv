module kernel_loader_ctrl #(
    parameter int unsigned SIZE      = 4,
    parameter int unsigned REG_WIDTH = 32
) (
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        cfg_valid,
    input  logic [REG_WIDTH-1:0]        cfg_k,
    input  logic [REG_WIDTH-1:0]        cfg_n,
    input  logic [REG_WIDTH-1:0]        cfg_m,
    input  logic [REG_WIDTH-1:0]        cfg_rhs_base,
    input  logic [REG_WIDTH-1:0]        cfg_rhs_row_stride_b,
    input  logic signed [REG_WIDTH-1:0] cfg_rhs_zp,
    input  logic                        cfg_use_16bits,
    input  logic [REG_WIDTH-1:0]        cfg_ia_reuse_num,
    input  logic [REG_WIDTH-1:0]        cfg_w_reuse_num,
    input  logic                        load_weight_granted,
    input  logic                        send_weight_trigger,
    input  logic                        buf_weight_data_valid,
    input  logic                        buf_weight_sending_done,
    output logic                        load_weight_req,
    output logic                        dma_start,
    output logic [REG_WIDTH-1:0]        dma_tile_base_addr,
    output logic [REG_WIDTH-1:0]        dma_rows_to_read,
    output logic [REG_WIDTH-1:0]        dma_row_stride_b,
    output logic signed [REG_WIDTH-1:0] dma_rhs_zp,
    output logic                        buf_load_start,
    output logic                        buf_send_start,
    output logic [REG_WIDTH-1:0]        dma_valid_cols,
    output logic                        ctrl_all_done,
    output logic [REG_WIDTH-1:0]        tile_row_dbg,
    output logic [REG_WIDTH-1:0]        tile_col_dbg,
    output logic [REG_WIDTH-1:0]        repeat_dbg
);

  typedef enum logic [2:0] {S_IDLE, S_REQ_LOAD, S_LOAD, S_WAIT_SEND, S_SEND, S_DONE} state_t;

  state_t state;

  logic [REG_WIDTH-1:0] tile_rows_total;
  logic [REG_WIDTH-1:0] tile_cols_total;
  logic [REG_WIDTH-1:0] output_row_tiles_total;
  logic [REG_WIDTH-1:0] l2_groups_total;
  logic [REG_WIDTH-1:0] repeat_total;
  logic [REG_WIDTH-1:0] current_group_width;
  logic [REG_WIDTH-1:0] rows_remaining;

  logic [REG_WIDTH-1:0] cur_tile_row;
  logic [REG_WIDTH-1:0] cur_repeat;
  logic [REG_WIDTH-1:0] cur_l2;
  logic [REG_WIDTH-1:0] cur_col_in_group;
  logic [REG_WIDTH-1:0] group_base_col;

  function automatic logic [REG_WIDTH-1:0] ceil_div(input logic [REG_WIDTH-1:0] a,
                                                    input logic [REG_WIDTH-1:0] b);
    if (b == 0) ceil_div = '0;
    else        ceil_div = (a + b - 1) / b;
  endfunction

  function automatic logic [REG_WIDTH-1:0] min_u(input logic [REG_WIDTH-1:0] a,
                                                 input logic [REG_WIDTH-1:0] b);
    min_u = (a < b) ? a : b;
  endfunction

  always_comb begin
    // Top-level GEMM dimensions are KxN times NxM.  The RHS/kernel matrix
    // therefore has cfg_n rows and cfg_m columns; cfg_k controls how many
    // output-row groups consume the same RHS stream.
    tile_rows_total   = ceil_div(cfg_n, SIZE);
    tile_cols_total   = ceil_div(cfg_m, SIZE);
    output_row_tiles_total = ceil_div(cfg_k, SIZE);
    l2_groups_total   = ceil_div(tile_cols_total, (cfg_w_reuse_num == 0) ? 1 : cfg_w_reuse_num);
    repeat_total      = ceil_div(output_row_tiles_total, (cfg_ia_reuse_num == 0) ? 1 : cfg_ia_reuse_num);
    if (repeat_total == 0) repeat_total = 1;
    group_base_col    = cur_l2 * ((cfg_w_reuse_num == 0) ? 1 : cfg_w_reuse_num);
    current_group_width = min_u(cfg_w_reuse_num, tile_cols_total - group_base_col);
    if (current_group_width == 0) begin
      current_group_width = (cfg_w_reuse_num == 0) ? 1 : cfg_w_reuse_num;
    end

    tile_row_dbg = cur_tile_row;
    tile_col_dbg = group_base_col + cur_col_in_group;
    repeat_dbg   = cur_repeat;

    rows_remaining = cfg_n - (cur_tile_row * SIZE);

    load_weight_req = (state == S_REQ_LOAD);
    dma_start       = (state == S_REQ_LOAD) && load_weight_granted;
    buf_load_start  = dma_start;
    buf_send_start  = ((state == S_LOAD) || (state == S_WAIT_SEND))
            && send_weight_trigger
            && buf_weight_data_valid;
    ctrl_all_done   = (state == S_DONE);

    dma_tile_base_addr = cfg_rhs_base
                       + (cur_tile_row * SIZE * cfg_rhs_row_stride_b)
                       + ((group_base_col + cur_col_in_group) * SIZE * (cfg_use_16bits ? 2 : 1));
    dma_rows_to_read   = min_u(SIZE, rows_remaining);
    dma_row_stride_b   = cfg_rhs_row_stride_b;
    dma_rhs_zp         = cfg_rhs_zp;
    if ((group_base_col + cur_col_in_group + 1) * SIZE > cfg_m) begin
      dma_valid_cols = cfg_m - ((group_base_col + cur_col_in_group) * SIZE);
    end else begin
      dma_valid_cols = SIZE;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= S_IDLE;
      cur_tile_row    <= '0;
      cur_repeat      <= '0;
      cur_l2          <= '0;
      cur_col_in_group<= '0;
    end else begin
      case (state)
        S_IDLE: begin
          if (cfg_valid) begin
            cur_tile_row     <= '0;
            cur_repeat       <= '0;
            cur_l2           <= '0;
            cur_col_in_group <= '0;
            state            <= S_REQ_LOAD;
          end
        end

        S_REQ_LOAD: begin
          if (load_weight_granted) begin
            state <= S_LOAD;
          end
        end

        S_LOAD: begin
          if (send_weight_trigger && buf_weight_data_valid) begin
            state <= S_SEND;
          end else if (buf_weight_data_valid) begin
            state <= S_WAIT_SEND;
          end
        end

        S_WAIT_SEND: begin
          if (buf_send_start) begin
            state <= S_SEND;
          end
        end

        S_SEND: begin
          if (buf_weight_sending_done) begin
            if (cur_repeat + 1 >= repeat_total
                && cur_l2 + 1 >= l2_groups_total
                && cur_tile_row + 1 >= tile_rows_total
                && cur_col_in_group + 1 >= current_group_width) begin
              state <= S_DONE;
            end else begin
              if (cur_col_in_group + 1 < current_group_width) begin
                cur_col_in_group <= cur_col_in_group + 1;
              end else begin
                cur_col_in_group <= '0;
                if (cur_tile_row + 1 < tile_rows_total) begin
                  cur_tile_row <= cur_tile_row + 1;
                end else begin
                  cur_tile_row <= '0;
                  if (cur_l2 + 1 < l2_groups_total) begin
                    cur_l2 <= cur_l2 + 1;
                  end else begin
                    cur_l2 <= '0;
                    cur_repeat <= cur_repeat + 1;
                  end
                end
              end
              state <= S_REQ_LOAD;
            end
          end
        end

        S_DONE: begin
          if (!cfg_valid) begin
            state <= S_IDLE;
          end
        end
      endcase
    end
  end

endmodule
