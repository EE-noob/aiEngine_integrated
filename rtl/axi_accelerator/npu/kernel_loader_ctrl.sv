module kernel_loader_ctrl #(
    parameter int unsigned SIZE      = 4,
    parameter int unsigned REG_WIDTH = 32,
    parameter int unsigned COUNT_WIDTH = REG_WIDTH
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
    input logic [REG_WIDTH-1:0] cfg_row_groups,
    input logic [REG_WIDTH-1:0] cfg_row_tail_tiles,
    input logic [REG_WIDTH-1:0] cfg_col_groups,
    input logic [REG_WIDTH-1:0] cfg_col_tail_tiles,
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

  localparam int unsigned SIZE_SHIFT = $clog2(SIZE);
  localparam int unsigned CNT_W = (COUNT_WIDTH < 1) ? 1 : COUNT_WIDTH;
  typedef logic [CNT_W-1:0] count_t;

  typedef enum logic [1:0] {S_IDLE, S_INIT, S_RUN, S_DONE} state_t;

  state_t state;

  count_t tile_rows_total;
  count_t tile_cols_total;
  count_t l2_groups_total;
  count_t repeat_total;
  count_t current_group_width;
  count_t valid_n_rows;
  count_t valid_m_cols;
  logic [REG_WIDTH-1:0] elem_bytes;
  count_t w_reuse_norm;
  count_t ia_reuse_norm;
  count_t cfg_tile_rows_total;
  count_t cfg_tile_cols_total;
  count_t cfg_output_row_tiles_total;
  count_t cfg_l2_groups_total;
  count_t cfg_repeat_total;
  count_t last_n_rows;
  count_t last_m_cols;
  count_t cfg_last_n_rows;
  count_t cfg_last_m_cols;
  count_t cfg_group_tail_cols;
  count_t cfg_last_group_width;
  count_t first_group_width;

  count_t load_tile_row;
  count_t load_repeat;
  count_t load_l2;
  count_t load_col_in_group;
  count_t group_base_col;
  count_t load_tile_col;
  count_t loaded_count;
  count_t sent_count;
  logic                 load_complete;
  logic                 all_loads_done;
  logic                 last_col_in_group;
  logic                 last_tile_row;
  logic                 last_l2_group;
  logic                 last_repeat;
  logic                 final_load_done;
  logic                 load_complete_after;
  count_t loaded_count_after;
  count_t w_reuse_total;
  logic [REG_WIDTH-1:0] base_addr_reg;
  logic [REG_WIDTH-1:0] col_addr_step;
  logic [REG_WIDTH-1:0] row_addr_step;
  logic [REG_WIDTH-1:0] group_addr_step;
  logic [REG_WIDTH-1:0] group_base_addr;
  logic [REG_WIDTH-1:0] row_addr_offset;
  logic [REG_WIDTH-1:0] col_addr_offset;
  logic [REG_WIDTH-1:0] cfg_col_addr_step;
  logic [REG_WIDTH-1:0] cfg_row_addr_step;
  logic [REG_WIDTH-1:0] cfg_group_addr_step;
  count_t last_group_width;
  count_t following_group_width;

  function automatic count_t ceil_div_pow2(input logic [REG_WIDTH-1:0] a,
                                           input count_t pow2);
    logic [REG_WIDTH-1:0] biased;
    begin
      biased = a + REG_WIDTH'(pow2) - REG_WIDTH'(1);
      unique case (pow2)
        count_t'(1):    ceil_div_pow2 = count_t'(biased);
        count_t'(2):    ceil_div_pow2 = count_t'(biased >> 1);
        count_t'(4):    ceil_div_pow2 = count_t'(biased >> 2);
        count_t'(8):    ceil_div_pow2 = count_t'(biased >> 3);
        count_t'(16):   ceil_div_pow2 = count_t'(biased >> 4);
        count_t'(32):   ceil_div_pow2 = count_t'(biased >> 5);
        count_t'(64):   ceil_div_pow2 = count_t'(biased >> 6);
        count_t'(128):  ceil_div_pow2 = count_t'(biased >> 7);
        count_t'(256):  ceil_div_pow2 = count_t'(biased >> 8);
        count_t'(512):  ceil_div_pow2 = count_t'(biased >> 9);
        count_t'(1024): ceil_div_pow2 = count_t'(biased >> 10);
        default:        ceil_div_pow2 = count_t'(biased);
      endcase
    end
  endfunction

  always_comb begin
    ia_reuse_norm = (cfg_ia_reuse_num == 0) ? count_t'(1) : count_t'(cfg_ia_reuse_num);
    w_reuse_norm  = (cfg_w_reuse_num  == 0) ? count_t'(1) : count_t'(cfg_w_reuse_num);

    cfg_tile_rows_total        = ceil_div_pow2(cfg_n, count_t'(SIZE));
    cfg_tile_cols_total        = ceil_div_pow2(cfg_m, count_t'(SIZE));
    cfg_output_row_tiles_total = ceil_div_pow2(cfg_k, count_t'(SIZE));
    cfg_l2_groups_total = count_t'(cfg_col_groups);
    cfg_repeat_total = count_t'(cfg_row_groups);
    if (cfg_tile_rows_total == 0) cfg_tile_rows_total = count_t'(1);
    if (cfg_tile_cols_total == 0) cfg_tile_cols_total = count_t'(1);
    if (cfg_l2_groups_total == 0) cfg_l2_groups_total = count_t'(1);
    if (cfg_repeat_total == 0) cfg_repeat_total = count_t'(1);

    cfg_last_n_rows = count_t'(cfg_n & REG_WIDTH'(SIZE - 1));
    cfg_last_m_cols = count_t'(cfg_m & REG_WIDTH'(SIZE - 1));
    if (cfg_last_n_rows == 0) cfg_last_n_rows = count_t'(SIZE);
    if (cfg_last_m_cols == 0) cfg_last_m_cols = count_t'(SIZE);

    cfg_group_tail_cols = count_t'(cfg_col_tail_tiles);
    cfg_last_group_width = count_t'(cfg_col_tail_tiles);

    if (tile_cols_total < w_reuse_total) begin
      first_group_width = tile_cols_total;
    end else begin
      first_group_width = w_reuse_total;
    end
    if (first_group_width == 0) first_group_width = count_t'(1);

    if ((load_l2 + count_t'(2)) >= l2_groups_total) begin
      following_group_width = last_group_width;
    end else begin
      following_group_width = w_reuse_total;
    end

    load_tile_col = group_base_col + load_col_in_group;
    valid_n_rows = (load_tile_row == tile_rows_total - count_t'(1)) ? last_n_rows : count_t'(SIZE);
    valid_m_cols = (load_tile_col == tile_cols_total - count_t'(1)) ? last_m_cols : count_t'(SIZE);
    if (valid_n_rows == 0) valid_n_rows = count_t'(1);
    if (valid_m_cols == 0) valid_m_cols = count_t'(1);
    elem_bytes = cfg_use_16bits ? REG_WIDTH'(2) : REG_WIDTH'(1);

    cfg_col_addr_step = cfg_rhs_row_stride_b << SIZE_SHIFT;
    cfg_row_addr_step = cfg_use_16bits ? (REG_WIDTH'(SIZE) << 1) : REG_WIDTH'(SIZE);
    unique case (w_reuse_norm)
      count_t'(1):    cfg_group_addr_step = cfg_col_addr_step;
      count_t'(2):    cfg_group_addr_step = cfg_col_addr_step << 1;
      count_t'(4):    cfg_group_addr_step = cfg_col_addr_step << 2;
      count_t'(8):    cfg_group_addr_step = cfg_col_addr_step << 3;
      count_t'(16):   cfg_group_addr_step = cfg_col_addr_step << 4;
      count_t'(25):   cfg_group_addr_step = (cfg_col_addr_step << 4) + (cfg_col_addr_step << 3) + cfg_col_addr_step;
      count_t'(32):   cfg_group_addr_step = cfg_col_addr_step << 5;
      count_t'(64):   cfg_group_addr_step = cfg_col_addr_step << 6;
      count_t'(128):  cfg_group_addr_step = cfg_col_addr_step << 7;
      count_t'(256):  cfg_group_addr_step = cfg_col_addr_step << 8;
      count_t'(512):  cfg_group_addr_step = cfg_col_addr_step << 9;
      count_t'(1024): cfg_group_addr_step = cfg_col_addr_step << 10;
      default:          cfg_group_addr_step = cfg_col_addr_step;
    endcase

    last_col_in_group = (load_col_in_group + count_t'(1) >= current_group_width);
    last_tile_row     = (load_tile_row + count_t'(1) >= tile_rows_total);
    last_l2_group     = (load_l2 + count_t'(1) >= l2_groups_total);
    last_repeat       = (load_repeat + count_t'(1) >= repeat_total);
    final_load_done   = load_done && last_col_in_group && last_tile_row && last_l2_group && last_repeat;
    loaded_count_after = loaded_count + (load_done ? count_t'(1) : count_t'(0));

    load_complete = all_loads_done;
    load_complete_after = all_loads_done || final_load_done;

    tile_row_dbg = REG_WIDTH'(load_tile_row);
    tile_col_dbg = REG_WIDTH'(load_tile_col);
    repeat_dbg   = REG_WIDTH'(load_repeat);

    load_weight_req = (state == S_RUN) && !load_complete && buf_load_ready;
    dma_start       = load_weight_req && load_weight_granted;
    buf_load_start  = dma_start;
    buf_send_start  = (state == S_RUN) && send_weight_trigger && buf_weight_data_valid;
    ctrl_all_done   = (state == S_DONE);

    // W is column-flattened: each DMA "row" is one output column,
    // and each burst reads contiguous N/K elements from that column.
    dma_tile_base_addr = group_base_addr + row_addr_offset + col_addr_offset;
    dma_rows_to_read   = REG_WIDTH'(valid_m_cols);
    dma_row_stride_b   = cfg_rhs_row_stride_b;
    dma_rhs_zp         = cfg_rhs_zp;
    dma_valid_cols     = REG_WIDTH'(valid_n_rows);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state               <= S_IDLE;
      load_tile_row       <= '0;
      load_repeat         <= '0;
      load_l2             <= '0;
      load_col_in_group   <= '0;
      loaded_count        <= '0;
      sent_count          <= '0;
      all_loads_done      <= 1'b0;
      tile_rows_total     <= count_t'(1);
      tile_cols_total     <= count_t'(1);
      l2_groups_total     <= count_t'(1);
      repeat_total        <= count_t'(1);
      last_n_rows         <= count_t'(SIZE);
      last_m_cols         <= count_t'(SIZE);
      current_group_width <= count_t'(1);
      w_reuse_total       <= count_t'(1);
      last_group_width    <= count_t'(SIZE);
      base_addr_reg       <= '0;
      col_addr_step       <= '0;
      row_addr_step       <= REG_WIDTH'(SIZE);
      group_addr_step     <= '0;
      group_base_col      <= '0;
      group_base_addr     <= '0;
      row_addr_offset     <= '0;
      col_addr_offset     <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          if (cfg_valid) begin
            load_tile_row       <= '0;
            load_repeat         <= '0;
            load_l2             <= '0;
            load_col_in_group   <= '0;
            loaded_count        <= '0;
            sent_count          <= '0;
            all_loads_done      <= 1'b0;
            tile_rows_total     <= cfg_tile_rows_total;
            tile_cols_total     <= cfg_tile_cols_total;
            l2_groups_total     <= cfg_l2_groups_total;
            repeat_total        <= cfg_repeat_total;
            last_n_rows         <= cfg_last_n_rows;
            last_m_cols         <= cfg_last_m_cols;
            current_group_width <= count_t'(1);
            w_reuse_total       <= w_reuse_norm;
            last_group_width    <= cfg_last_group_width;
            base_addr_reg       <= cfg_rhs_base;
            col_addr_step       <= cfg_col_addr_step;
            row_addr_step       <= cfg_row_addr_step;
            group_addr_step     <= cfg_group_addr_step;
            group_base_col      <= '0;
            group_base_addr     <= cfg_rhs_base;
            row_addr_offset     <= '0;
            col_addr_offset     <= '0;
            state               <= S_INIT;
          end
        end

        S_INIT: begin
          current_group_width <= first_group_width;
          group_base_addr     <= base_addr_reg;
          state               <= S_RUN;
        end

        S_RUN: begin
          if (load_done) begin
            loaded_count <= loaded_count + 1'b1;
            if (final_load_done) begin
              all_loads_done <= 1'b1;
            end

            if (!last_col_in_group) begin
              load_col_in_group <= load_col_in_group + 1'b1;
              col_addr_offset   <= col_addr_offset + col_addr_step;
            end else begin
              load_col_in_group <= '0;
              col_addr_offset   <= '0;
              if (!last_tile_row) begin
                load_tile_row   <= load_tile_row + 1'b1;
                row_addr_offset <= row_addr_offset + row_addr_step;
              end else begin
                load_tile_row   <= '0;
                row_addr_offset <= '0;
                if (!last_l2_group) begin
                  load_l2             <= load_l2 + 1'b1;
                  group_base_col      <= group_base_col + current_group_width;
                  current_group_width <= following_group_width;
                  group_base_addr     <= group_base_addr + group_addr_step;
                end else begin
                  load_l2             <= '0;
                  group_base_col      <= '0;
                  current_group_width <= first_group_width;
                  group_base_addr     <= base_addr_reg;
                  if (!last_repeat) begin
                    load_repeat <= load_repeat + 1'b1;
                  end
                end
              end
            end
          end

          if (buf_weight_sending_done) begin
            sent_count <= sent_count + 1'b1;
            if (load_complete_after && (sent_count + 1 >= loaded_count_after)) begin
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
