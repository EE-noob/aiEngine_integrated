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

  localparam int unsigned SIZE_SHIFT = $clog2(SIZE);

  typedef enum logic [1:0] {S_IDLE, S_RUN, S_DONE} state_t;

  state_t state;

  logic [REG_WIDTH-1:0] tile_rows_total;
  logic [REG_WIDTH-1:0] tile_cols_total;
  logic [REG_WIDTH-1:0] l2_groups_total;
  logic [REG_WIDTH-1:0] repeat_total;
  logic [REG_WIDTH-1:0] current_group_width;
  logic [REG_WIDTH-1:0] valid_n_rows;
  logic [REG_WIDTH-1:0] valid_m_cols;
  logic [REG_WIDTH-1:0] elem_bytes;
  logic [REG_WIDTH-1:0] w_reuse_norm;
  logic [REG_WIDTH-1:0] ia_reuse_norm;
  logic [REG_WIDTH-1:0] cfg_tile_rows_total;
  logic [REG_WIDTH-1:0] cfg_tile_cols_total;
  logic [REG_WIDTH-1:0] cfg_output_row_tiles_total;
  logic [REG_WIDTH-1:0] cfg_l2_groups_total;
  logic [REG_WIDTH-1:0] cfg_repeat_total;
  logic [REG_WIDTH-1:0] last_n_rows;
  logic [REG_WIDTH-1:0] last_m_cols;
  logic [REG_WIDTH-1:0] cfg_last_n_rows;
  logic [REG_WIDTH-1:0] cfg_last_m_cols;
  logic [REG_WIDTH-1:0] cfg_first_group_width;
  logic [REG_WIDTH-1:0] first_group_width;

  logic [REG_WIDTH-1:0] load_tile_row;
  logic [REG_WIDTH-1:0] load_repeat;
  logic [REG_WIDTH-1:0] load_l2;
  logic [REG_WIDTH-1:0] load_col_in_group;
  logic [REG_WIDTH-1:0] group_base_col;
  logic [REG_WIDTH-1:0] load_tile_col;
  logic [REG_WIDTH-1:0] loaded_count;
  logic [REG_WIDTH-1:0] sent_count;
  logic                 load_complete;
  logic                 all_loads_done;
  logic                 last_col_in_group;
  logic                 last_tile_row;
  logic                 last_l2_group;
  logic                 last_repeat;
  logic                 final_load_done;
  logic                 load_complete_after;
  logic [REG_WIDTH-1:0] loaded_count_after;
  logic [REG_WIDTH-1:0] w_reuse_total;
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
  logic [REG_WIDTH-1:0] next_group_base_col;
  logic [REG_WIDTH-1:0] remaining_cols_after_group;
  logic [REG_WIDTH-1:0] next_group_width;

  function automatic logic [REG_WIDTH-1:0] ceil_div_pow2(input logic [REG_WIDTH-1:0] a,
                                                         input logic [REG_WIDTH-1:0] pow2);
    logic [REG_WIDTH-1:0] biased;
    begin
      biased = a + pow2 - REG_WIDTH'(1);
      unique case (pow2)
        REG_WIDTH'(1):    ceil_div_pow2 = biased;
        REG_WIDTH'(2):    ceil_div_pow2 = biased >> 1;
        REG_WIDTH'(4):    ceil_div_pow2 = biased >> 2;
        REG_WIDTH'(8):    ceil_div_pow2 = biased >> 3;
        REG_WIDTH'(16):   ceil_div_pow2 = biased >> 4;
        REG_WIDTH'(32):   ceil_div_pow2 = biased >> 5;
        REG_WIDTH'(64):   ceil_div_pow2 = biased >> 6;
        REG_WIDTH'(128):  ceil_div_pow2 = biased >> 7;
        REG_WIDTH'(256):  ceil_div_pow2 = biased >> 8;
        REG_WIDTH'(512):  ceil_div_pow2 = biased >> 9;
        REG_WIDTH'(1024): ceil_div_pow2 = biased >> 10;
        default:          ceil_div_pow2 = biased;
      endcase
    end
  endfunction

  always_comb begin
    ia_reuse_norm = (cfg_ia_reuse_num == 0) ? REG_WIDTH'(1) : cfg_ia_reuse_num;
    w_reuse_norm  = (cfg_w_reuse_num  == 0) ? REG_WIDTH'(1) : cfg_w_reuse_num;

    cfg_tile_rows_total        = ceil_div_pow2(cfg_n, REG_WIDTH'(SIZE));
    cfg_tile_cols_total        = ceil_div_pow2(cfg_m, REG_WIDTH'(SIZE));
    cfg_output_row_tiles_total = ceil_div_pow2(cfg_k, REG_WIDTH'(SIZE));
    cfg_l2_groups_total        = ceil_div_pow2(cfg_tile_cols_total, w_reuse_norm);
    cfg_repeat_total           = ceil_div_pow2(cfg_output_row_tiles_total, ia_reuse_norm);
    if (cfg_tile_rows_total == 0) cfg_tile_rows_total = REG_WIDTH'(1);
    if (cfg_tile_cols_total == 0) cfg_tile_cols_total = REG_WIDTH'(1);
    if (cfg_l2_groups_total == 0) cfg_l2_groups_total = REG_WIDTH'(1);
    if (cfg_repeat_total == 0) cfg_repeat_total = REG_WIDTH'(1);

    cfg_last_n_rows = cfg_n & REG_WIDTH'(SIZE - 1);
    cfg_last_m_cols = cfg_m & REG_WIDTH'(SIZE - 1);
    if (cfg_last_n_rows == 0) cfg_last_n_rows = REG_WIDTH'(SIZE);
    if (cfg_last_m_cols == 0) cfg_last_m_cols = REG_WIDTH'(SIZE);

    if (cfg_tile_cols_total < w_reuse_norm) begin
      cfg_first_group_width = cfg_tile_cols_total;
    end else begin
      cfg_first_group_width = w_reuse_norm;
    end
    if (cfg_first_group_width == 0) cfg_first_group_width = REG_WIDTH'(1);

    if (tile_cols_total < w_reuse_total) begin
      first_group_width = tile_cols_total;
    end else begin
      first_group_width = w_reuse_total;
    end
    if (first_group_width == 0) first_group_width = REG_WIDTH'(1);

    next_group_base_col = group_base_col + current_group_width;
    if (tile_cols_total > next_group_base_col) begin
      remaining_cols_after_group = tile_cols_total - next_group_base_col;
    end else begin
      remaining_cols_after_group = REG_WIDTH'(0);
    end
    if (remaining_cols_after_group == 0) begin
      next_group_width = REG_WIDTH'(1);
    end else if (remaining_cols_after_group < w_reuse_total) begin
      next_group_width = remaining_cols_after_group;
    end else begin
      next_group_width = w_reuse_total;
    end

    load_tile_col = group_base_col + load_col_in_group;
    valid_n_rows = (load_tile_row == tile_rows_total - 1) ? last_n_rows : REG_WIDTH'(SIZE);
    valid_m_cols = (load_tile_col == tile_cols_total - 1) ? last_m_cols : REG_WIDTH'(SIZE);
    if (valid_n_rows == 0) valid_n_rows = REG_WIDTH'(1);
    if (valid_m_cols == 0) valid_m_cols = REG_WIDTH'(1);
    elem_bytes = cfg_use_16bits ? REG_WIDTH'(2) : REG_WIDTH'(1);

    cfg_col_addr_step = cfg_rhs_row_stride_b << SIZE_SHIFT;
    cfg_row_addr_step = cfg_use_16bits ? (REG_WIDTH'(SIZE) << 1) : REG_WIDTH'(SIZE);
    unique case (w_reuse_norm)
      REG_WIDTH'(1):    cfg_group_addr_step = cfg_col_addr_step;
      REG_WIDTH'(2):    cfg_group_addr_step = cfg_col_addr_step << 1;
      REG_WIDTH'(4):    cfg_group_addr_step = cfg_col_addr_step << 2;
      REG_WIDTH'(8):    cfg_group_addr_step = cfg_col_addr_step << 3;
      REG_WIDTH'(16):   cfg_group_addr_step = cfg_col_addr_step << 4;
      REG_WIDTH'(32):   cfg_group_addr_step = cfg_col_addr_step << 5;
      REG_WIDTH'(64):   cfg_group_addr_step = cfg_col_addr_step << 6;
      REG_WIDTH'(128):  cfg_group_addr_step = cfg_col_addr_step << 7;
      REG_WIDTH'(256):  cfg_group_addr_step = cfg_col_addr_step << 8;
      REG_WIDTH'(512):  cfg_group_addr_step = cfg_col_addr_step << 9;
      REG_WIDTH'(1024): cfg_group_addr_step = cfg_col_addr_step << 10;
      default:          cfg_group_addr_step = cfg_col_addr_step;
    endcase

    last_col_in_group = (load_col_in_group + 1 >= current_group_width);
    last_tile_row     = (load_tile_row + 1 >= tile_rows_total);
    last_l2_group     = (load_l2 + 1 >= l2_groups_total);
    last_repeat       = (load_repeat + 1 >= repeat_total);
    final_load_done   = load_done && last_col_in_group && last_tile_row && last_l2_group && last_repeat;
    loaded_count_after = loaded_count + (load_done ? REG_WIDTH'(1) : REG_WIDTH'(0));

    load_complete = all_loads_done;
    load_complete_after = all_loads_done || final_load_done;

    tile_row_dbg = load_tile_row;
    tile_col_dbg = load_tile_col;
    repeat_dbg   = load_repeat;

    load_weight_req = (state == S_RUN) && !load_complete && buf_load_ready;
    dma_start       = load_weight_req && load_weight_granted;
    buf_load_start  = dma_start;
    buf_send_start  = (state == S_RUN) && send_weight_trigger && buf_weight_data_valid;
    ctrl_all_done   = (state == S_DONE);

    // W is column-flattened: each DMA "row" is one output column,
    // and each burst reads contiguous N/K elements from that column.
    dma_tile_base_addr = group_base_addr + row_addr_offset + col_addr_offset;
    dma_rows_to_read   = valid_m_cols;
    dma_row_stride_b   = cfg_rhs_row_stride_b;
    dma_rhs_zp         = cfg_rhs_zp;
    dma_valid_cols     = valid_n_rows;
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
      tile_rows_total     <= REG_WIDTH'(1);
      tile_cols_total     <= REG_WIDTH'(1);
      l2_groups_total     <= REG_WIDTH'(1);
      repeat_total        <= REG_WIDTH'(1);
      last_n_rows         <= REG_WIDTH'(SIZE);
      last_m_cols         <= REG_WIDTH'(SIZE);
      current_group_width <= REG_WIDTH'(1);
      w_reuse_total       <= REG_WIDTH'(1);
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
            current_group_width <= cfg_first_group_width;
            w_reuse_total       <= w_reuse_norm;
            base_addr_reg       <= cfg_rhs_base;
            col_addr_step       <= cfg_col_addr_step;
            row_addr_step       <= cfg_row_addr_step;
            group_addr_step     <= cfg_group_addr_step;
            group_base_col      <= '0;
            group_base_addr     <= cfg_rhs_base;
            row_addr_offset     <= '0;
            col_addr_offset     <= '0;
            state               <= S_RUN;
          end
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
                  group_base_col      <= next_group_base_col;
                  current_group_width <= next_group_width;
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
