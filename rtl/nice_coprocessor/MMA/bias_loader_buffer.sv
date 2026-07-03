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
    parameter int unsigned GROUP_BLOCKS_MAX = 1
) (
    input  logic clk,
    input  logic rst_n,

    input  logic                 init_cfg,
    input  logic                 load_start,
    input  logic                 load_bank,
    input  logic [REG_WIDTH-1:0] load_block_idx,
    input  logic                 load_word_valid [BUS_WIDTH/8],
    input  logic [REG_WIDTH-1:0] load_word_row,
    input  logic [$clog2(SIZE * (DATA_WIDTH / 8))-1:0] load_word_col_base,
    input  logic signed [DMA_DATA_WIDTH-1:0] load_word_data [BUS_WIDTH/8],
    input  logic                 load_done,

    input  logic                 active_bank,
    input  logic [REG_WIDTH-1:0] current_block_idx,

    output logic                 bias_valid,
    output logic                 load_block_valid,
    output logic signed [DATA_WIDTH-1:0] data_out [SIZE],
    output logic signed [DATA_WIDTH-1:0] group_data_out [GROUP_BLOCKS_MAX * SIZE]
);

  localparam int BYTES_PER_WORD = DATA_WIDTH / 8;
  localparam int BYTE_SHIFT = $clog2(BYTES_PER_WORD);
  localparam int BYTE_MASK = BYTES_PER_WORD - 1;
  localparam int GROUP_ELEMS = GROUP_BLOCKS_MAX * SIZE;

  logic [DATA_WIDTH-1:0]        bank_words [2][GROUP_ELEMS];
  logic                         bank_loaded [2];
  logic [REG_WIDTH-1:0]         bank_block_idx [2];
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
      load_word_row_q      <= load_word_row;
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
        for (int word_i = 0; word_i < GROUP_ELEMS; word_i++) begin
          bank_words[b][word_i] <= '0;
        end
      end
    end else if (load_start) begin
      for (int word_i = 0; word_i < GROUP_ELEMS; word_i++) begin
        bank_words[load_bank][word_i] <= '0;
      end
    end else begin
`else
    if (!init_cfg && !load_start) begin
`endif
      for (int i = 0; i < BUS_WIDTH/8; i++) begin
        if (load_word_valid_q[i]) begin
          automatic int byte_offset;
          automatic int word_idx;
          automatic int byte_lane;

          byte_offset = int'(load_word_col_base_q) + i;
          word_idx    = (int'(load_word_row_q) * SIZE) + (byte_offset >> BYTE_SHIFT);
          byte_lane   = byte_offset & BYTE_MASK;
          if ((word_idx < GROUP_ELEMS) && (byte_lane < BYTES_PER_WORD)) begin
            bank_words[load_bank_q][word_idx][byte_lane*8 +: 8] <= load_word_data_q[i][7:0];
          end
        end
      end
    end
  end

  assign bias_valid = bank_loaded[active_bank] && (bank_block_idx[active_bank] == current_block_idx);
  assign load_block_valid = (bank_loaded[1'b0] && (bank_block_idx[1'b0] == load_block_idx)) ||
                            (bank_loaded[1'b1] && (bank_block_idx[1'b1] == load_block_idx));

  always_comb begin
    for (int gi = 0; gi < GROUP_ELEMS; gi++) begin
      group_data_out[gi] = $signed(bank_words[active_bank][gi]);
    end

    for (int i = 0; i < SIZE; i++) begin
      data_out[i] = $signed(bank_words[active_bank][i]);
    end
  end

endmodule
