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
    input  logic                        buf_load_ready,
    input  logic                        load_done,
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

  typedef enum logic [1:0] {S_IDLE, S_RUN, S_DONE} state_t;

  state_t state;

  logic [REG_WIDTH-1:0] tile_rows_total;
  logic [REG_WIDTH-1:0] tile_cols_total;
  logic [REG_WIDTH-1:0] output_row_tiles_total;
  logic [REG_WIDTH-1:0] l2_groups_total;
  logic [REG_WIDTH-1:0] repeat_total;
  logic [REG_WIDTH-1:0] current_group_width;
  logic [REG_WIDTH-1:0] rows_remaining;
  logic [REG_WIDTH-1:0] total_tiles;
  logic [REG_WIDTH-1:0] w_reuse_norm;
  logic [REG_WIDTH-1:0] ia_reuse_norm;

  logic [REG_WIDTH-1:0] load_tile_row;
  logic [REG_WIDTH-1:0] load_repeat;
  logic [REG_WIDTH-1:0] load_l2;
  logic [REG_WIDTH-1:0] load_col_in_group;
  logic [REG_WIDTH-1:0] group_base_col;
  logic [REG_WIDTH-1:0] load_tile_col;
  logic [REG_WIDTH-1:0] loaded_count;
  logic [REG_WIDTH-1:0] sent_count;
  logic                 load_complete;

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
    ia_reuse_norm = (cfg_ia_reuse_num == 0) ? REG_WIDTH'(1) : cfg_ia_reuse_num;
    w_reuse_norm  = (cfg_w_reuse_num  == 0) ? REG_WIDTH'(1) : cfg_w_reuse_num;

    tile_rows_total        = ceil_div(cfg_n, SIZE);
    tile_cols_total        = ceil_div(cfg_m, SIZE);
    output_row_tiles_total = ceil_div(cfg_k, SIZE);
    l2_groups_total        = ceil_div(tile_cols_total, w_reuse_norm);
    repeat_total           = ceil_div(output_row_tiles_total, ia_reuse_norm);
    if (repeat_total == 0) repeat_total = REG_WIDTH'(1);

    total_tiles = tile_rows_total * tile_cols_total * repeat_total;
    if (total_tiles == 0) total_tiles = REG_WIDTH'(1);

    group_base_col = load_l2 * w_reuse_norm;
    if (tile_cols_total > group_base_col) begin
      current_group_width = min_u(w_reuse_norm, tile_cols_total - group_base_col);
    end else begin
      current_group_width = REG_WIDTH'(1);
    end
    if (current_group_width == 0) current_group_width = REG_WIDTH'(1);

    load_tile_col = group_base_col + load_col_in_group;
    rows_remaining = (cfg_n > (load_tile_row * SIZE))
                   ? (cfg_n - (load_tile_row * SIZE))
                   : REG_WIDTH'(0);

    load_complete = (loaded_count >= total_tiles);

    tile_row_dbg = load_tile_row;
    tile_col_dbg = load_tile_col;
    repeat_dbg   = load_repeat;

    load_weight_req = (state == S_RUN) && !load_complete && buf_load_ready;
    dma_start       = load_weight_req && load_weight_granted;
    buf_load_start  = dma_start;
    buf_send_start  = (state == S_RUN) && send_weight_trigger && buf_weight_data_valid;
    ctrl_all_done   = (state == S_DONE);

    dma_tile_base_addr = cfg_rhs_base
                       + (load_tile_row * SIZE * cfg_rhs_row_stride_b)
                       + (load_tile_col * SIZE * (cfg_use_16bits ? 2 : 1));
    dma_rows_to_read   = min_u(SIZE, rows_remaining);
    dma_row_stride_b   = cfg_rhs_row_stride_b;
    dma_rhs_zp         = cfg_rhs_zp;
    if (((load_tile_col + 1) * SIZE) > cfg_m) begin
      dma_valid_cols = (cfg_m > (load_tile_col * SIZE))
                     ? (cfg_m - (load_tile_col * SIZE))
                     : REG_WIDTH'(1);
    end else begin
      dma_valid_cols = REG_WIDTH'(SIZE);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state             <= S_IDLE;
      load_tile_row     <= '0;
      load_repeat       <= '0;
      load_l2           <= '0;
      load_col_in_group <= '0;
      loaded_count      <= '0;
      sent_count        <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          if (cfg_valid) begin
            load_tile_row     <= '0;
            load_repeat       <= '0;
            load_l2           <= '0;
            load_col_in_group <= '0;
            loaded_count      <= '0;
            sent_count        <= '0;
            state             <= S_RUN;
          end
        end

        S_RUN: begin
          if (load_done) begin
            loaded_count <= loaded_count + 1'b1;
            if (load_col_in_group + 1 < current_group_width) begin
              load_col_in_group <= load_col_in_group + 1'b1;
            end else begin
              load_col_in_group <= '0;
              if (load_tile_row + 1 < tile_rows_total) begin
                load_tile_row <= load_tile_row + 1'b1;
              end else begin
                load_tile_row <= '0;
                if (load_l2 + 1 < l2_groups_total) begin
                  load_l2 <= load_l2 + 1'b1;
                end else begin
                  load_l2 <= '0;
                  load_repeat <= load_repeat + 1'b1;
                end
              end
            end
          end

          if (buf_weight_sending_done) begin
            sent_count <= sent_count + 1'b1;
            if (sent_count + 1 >= total_tiles) begin
              state <= S_DONE;
            end
          end
        end

        S_DONE: begin
          if (!cfg_valid) begin
            state <= S_IDLE;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
