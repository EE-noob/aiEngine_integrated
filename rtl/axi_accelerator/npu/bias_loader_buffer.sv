/*
 * bias_loader_buffer — 双 bank 数据存储
 * ============================================================
 */

module bias_loader_buffer #(
    parameter int unsigned SIZE       = 8,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned DMA_DATA_WIDTH = 8,
    parameter int unsigned BUS_WIDTH  = 32,
    parameter int unsigned REG_WIDTH  = 32,
    parameter int unsigned COUNT_WIDTH = REG_WIDTH,
    parameter int unsigned GROUP_BLOCKS_MAX = 1
) (
    input  logic clk,
    input  logic rst_n,

    input  logic                 init_cfg,
    input  logic                 load_start,
    input  logic                 load_bank,
    input  logic [COUNT_WIDTH-1:0] load_block_idx,
    input  logic                 load_word_valid [BUS_WIDTH/8],
    input  logic [REG_WIDTH-1:0] load_word_row,
    input  logic [$clog2(SIZE * (DATA_WIDTH / 8))-1:0] load_word_col_base,
    input  logic signed [DMA_DATA_WIDTH-1:0] load_word_data [BUS_WIDTH/8],
    input  logic                 load_done,

    input  logic                 active_bank,
    input  logic [COUNT_WIDTH-1:0] current_block_idx,

    input  logic [$clog2(GROUP_BLOCKS_MAX * SIZE)-1:0] group_read_idx,
    output logic                 bias_valid,
    output logic                 load_block_valid,
    output logic signed [DATA_WIDTH-1:0] data_out [SIZE],
    output logic signed [DATA_WIDTH-1:0] group_data_scalar
);

  localparam int BYTES_PER_WORD = DATA_WIDTH / 8;
  localparam int BYTE_SHIFT = $clog2(BYTES_PER_WORD);
  localparam int GROUP_ELEMS = GROUP_BLOCKS_MAX * SIZE;
  localparam int CNT_W = (COUNT_WIDTH < 1) ? 1 : COUNT_WIDTH;

  (* ram_style = "distributed" *) logic [DATA_WIDTH-1:0] bank0_words [GROUP_ELEMS];
  (* ram_style = "distributed" *) logic [DATA_WIDTH-1:0] bank1_words [GROUP_ELEMS];
  logic [DATA_WIDTH-1:0]        bank_lane_words [2][SIZE];
  logic                         bank_loaded [2];
  logic [CNT_W-1:0]             bank_block_idx [2];
  logic                         load_bank_q;
  logic                         load_word_valid_q [BUS_WIDTH/8];
  logic [REG_WIDTH-1:0]         load_word_row_q;
  logic [$clog2(SIZE * (DATA_WIDTH / 8))-1:0] load_word_col_base_q;
  logic signed [DMA_DATA_WIDTH-1:0] load_word_data_q [BUS_WIDTH/8];
  logic                         load_done_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_bank_q          <= 1'b0;
      load_word_row_q      <= '0;
      load_word_col_base_q <= '0;
      load_done_q          <= 1'b0;
      for (int i = 0; i < BUS_WIDTH/8; i++) begin
        load_word_valid_q[i] <= 1'b0;
        load_word_data_q[i]  <= '0;
      end
    end else begin
      load_bank_q          <= load_bank;
      if (GROUP_BLOCKS_MAX == 1) begin
        load_word_row_q    <= '0;
      end else begin
        load_word_row_q    <= load_word_row;
      end
      load_word_col_base_q <= load_word_col_base;
      load_done_q          <= load_done;
      for (int i = 0; i < BUS_WIDTH/8; i++) begin
        load_word_valid_q[i] <= load_word_valid[i] && !load_start && !init_cfg;
        load_word_data_q[i]  <= load_word_data[i];
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int b = 0; b < 2; b++) begin
        bank_loaded[b]    <= 1'b0;
        bank_block_idx[b] <= '0;
      end
    end else if (init_cfg) begin
      for (int b = 0; b < 2; b++) begin
        bank_loaded[b]    <= 1'b0;
        bank_block_idx[b] <= '0;
      end
    end else begin
      if (load_start) begin
        bank_loaded[load_bank]    <= 1'b0;
        bank_block_idx[load_bank] <= load_block_idx;
      end else if (load_done_q) begin
        bank_loaded[load_bank_q] <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk) begin
`ifndef SYNTHESIS
    if (!rst_n || init_cfg) begin
      for (int b = 0; b < 2; b++) begin
        for (int lane_i = 0; lane_i < SIZE; lane_i++) begin
          bank_lane_words[b][lane_i] <= '0;
        end
      end
      for (int word_i = 0; word_i < GROUP_ELEMS; word_i++) begin
        bank0_words[word_i] <= '0;
        bank1_words[word_i] <= '0;
      end
    end else if (load_start) begin
      for (int word_i = 0; word_i < GROUP_ELEMS; word_i++) begin
        if (load_bank) begin
          bank1_words[word_i] <= '0;
        end else begin
          bank0_words[word_i] <= '0;
        end
      end
      for (int lane_i = 0; lane_i < SIZE; lane_i++) begin
        bank_lane_words[load_bank][lane_i] <= '0;
      end
    end else begin
`else
    if (!init_cfg && !load_start) begin
`endif
      if (load_word_valid_q[0]) begin
        automatic int byte_offset;
        automatic int word_idx;
        automatic logic [DATA_WIDTH-1:0] packed_word;

        byte_offset = int'(load_word_col_base_q);
        if (GROUP_BLOCKS_MAX == 1) begin
          word_idx = byte_offset >> BYTE_SHIFT;
        end else begin
          word_idx = (int'(load_word_row_q) * SIZE) + (byte_offset >> BYTE_SHIFT);
        end

        packed_word = '0;
        for (int byte_i = 0; byte_i < BYTES_PER_WORD; byte_i++) begin
          packed_word[byte_i*8 +: 8] = load_word_data_q[byte_i][7:0];
        end

        if (word_idx < GROUP_ELEMS) begin
          if (load_bank_q) begin
            bank1_words[word_idx] <= packed_word;
          end else begin
            bank0_words[word_idx] <= packed_word;
          end
          if (word_idx < SIZE) begin
            bank_lane_words[load_bank_q][word_idx] <= packed_word;
          end
        end
      end
    end
  end

  assign bias_valid = bank_loaded[active_bank] && (bank_block_idx[active_bank] == current_block_idx);
  assign load_block_valid = (bank_loaded[1'b0] && (bank_block_idx[1'b0] == load_block_idx)) ||
                            (bank_loaded[1'b1] && (bank_block_idx[1'b1] == load_block_idx));

  assign group_data_scalar = active_bank
                           ? $signed(bank1_words[group_read_idx])
                           : $signed(bank0_words[group_read_idx]);

  always_comb begin
    for (int i = 0; i < SIZE; i++) begin
      data_out[i] = $signed(bank_lane_words[active_bank][i]);
    end
  end

endmodule
