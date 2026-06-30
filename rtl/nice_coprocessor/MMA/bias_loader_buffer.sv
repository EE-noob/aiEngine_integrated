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
    input  logic [REG_WIDTH-1:0] next_block_idx,

    output logic                 bias_valid,
    output logic                 load_block_valid,
    output logic                 next_bias_valid,
    output logic signed [DATA_WIDTH-1:0] data_out [SIZE],
    output logic signed [DATA_WIDTH-1:0] next_data_out [SIZE],
    output logic signed [DATA_WIDTH-1:0] group_data_out [GROUP_BLOCKS_MAX * SIZE]
);

  localparam int BYTES_PER_WORD = DATA_WIDTH / 8;
  localparam int GROUP_ELEMS = GROUP_BLOCKS_MAX * SIZE;
  localparam int GROUP_BYTES = GROUP_ELEMS * BYTES_PER_WORD;

  logic [7:0]                   bank_bytes [2][GROUP_BYTES];
  logic                         bank_loaded [2];
  logic [REG_WIDTH-1:0]         bank_block_idx [2];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int b = 0; b < 2; b++) begin
        bank_loaded[b]    <= 1'b0;
        bank_block_idx[b] <= '0;
      end
    end else begin
      if (init_cfg) begin
        for (int b = 0; b < 2; b++) begin
          bank_loaded[b]    <= 1'b0;
          bank_block_idx[b] <= '0;
          for (int i = 0; i < GROUP_BYTES; i++) begin
            bank_bytes[b][i] <= '0;
          end
        end
      end

      if (load_start) begin
        bank_loaded[load_bank]    <= 1'b0;
        bank_block_idx[load_bank] <= load_block_idx;
        for (int i = 0; i < GROUP_BYTES; i++) begin
          bank_bytes[load_bank][i] <= '0;
        end
      end

      for (int i = 0; i < BUS_WIDTH/8; i++) begin
        if (load_word_valid[i]) begin
          automatic int byte_idx;

          byte_idx = (int'(load_word_row) * SIZE * BYTES_PER_WORD) +
                     int'(load_word_col_base) + i;
          if (byte_idx < GROUP_BYTES) begin
            bank_bytes[load_bank][byte_idx] <= load_word_data[i][7:0];
          end
        end
      end

      if (load_done) begin
        bank_loaded[load_bank] <= 1'b1;
      end
    end
  end

  assign bias_valid = bank_loaded[active_bank] && (bank_block_idx[active_bank] == current_block_idx);
  assign load_block_valid = (bank_loaded[1'b0] && (bank_block_idx[1'b0] == load_block_idx)) ||
                            (bank_loaded[1'b1] && (bank_block_idx[1'b1] == load_block_idx));

  logic next_bank0_valid;
  logic next_bank1_valid;

  assign next_bank0_valid = bank_loaded[1'b0] && (bank_block_idx[1'b0] == next_block_idx);
  assign next_bank1_valid = bank_loaded[1'b1] && (bank_block_idx[1'b1] == next_block_idx);
  assign next_bias_valid = next_bank0_valid || next_bank1_valid;

  always_comb begin
    for (int gi = 0; gi < GROUP_ELEMS; gi++) begin
      automatic int byte_base;
      byte_base = gi * BYTES_PER_WORD;
      if (bias_valid) begin
        group_data_out[gi] = $signed({
          bank_bytes[active_bank][byte_base + 3],
          bank_bytes[active_bank][byte_base + 2],
          bank_bytes[active_bank][byte_base + 1],
          bank_bytes[active_bank][byte_base]
        });
      end else begin
        group_data_out[gi] = '0;
      end
    end

    for (int i = 0; i < SIZE; i++) begin
      automatic int byte_base;
      byte_base = i * BYTES_PER_WORD;
      if (bias_valid) begin
        data_out[i] = $signed({
          bank_bytes[active_bank][byte_base + 3],
          bank_bytes[active_bank][byte_base + 2],
          bank_bytes[active_bank][byte_base + 1],
          bank_bytes[active_bank][byte_base]
        });
      end else begin
        data_out[i] = '0;
      end

      if (next_bank0_valid) begin
        next_data_out[i] = $signed({
          bank_bytes[1'b0][byte_base + 3],
          bank_bytes[1'b0][byte_base + 2],
          bank_bytes[1'b0][byte_base + 1],
          bank_bytes[1'b0][byte_base]
        });
      end else if (next_bank1_valid) begin
        next_data_out[i] = $signed({
          bank_bytes[1'b1][byte_base + 3],
          bank_bytes[1'b1][byte_base + 2],
          bank_bytes[1'b1][byte_base + 1],
          bank_bytes[1'b1][byte_base]
        });
      end else begin
        next_data_out[i] = '0;
      end
    end
  end

endmodule
