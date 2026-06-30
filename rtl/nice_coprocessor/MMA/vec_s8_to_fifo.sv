module vec_s8_to_fifo #(
    parameter integer VLEN  = 16,
    parameter integer BANKS = 16
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 in_valid,
    input  wire                 in_tile_done,
    input  wire [   VLEN*8-1:0] in_vec_s8,
    output reg                  oa_fifo_req,
    input  wire                 transpose_mode,
    input  wire [$clog2(VLEN)-1:0] vec_valid_num_col,
    input  wire [$clog2(VLEN)-1:0] vec_valid_num_row,
    output wire                 output_valid,
    input  wire                 output_ready,
    output wire                 output_row_switch,
    output reg  [          3:0] output_mask,
    output reg  [         31:0] output_data,
    output reg                  fifo_full_flag
);

  localparam integer PTR_WIDTH   = (VLEN <= 1) ? 1 : $clog2(VLEN);
  localparam integer COUNT_WIDTH = $clog2(VLEN + 1);
  localparam integer ROW_BEATS   = (VLEN + 3) / 4;
  localparam integer BEAT_WIDTH  = (ROW_BEATS <= 1) ? 1 : $clog2(ROW_BEATS);
  localparam integer BANK_WIDTH  = (BANKS <= 1) ? 1 : $clog2(BANKS);

  reg [VLEN*8-1:0] fifo_mem [0:BANKS-1][0:VLEN-1];
  reg [COUNT_WIDTH-1:0] bank_count [0:BANKS-1];
  reg [BANKS-1:0] bank_ready;

  reg [BANK_WIDTH-1:0]  write_bank;
  reg [BANK_WIDTH-1:0]  read_bank;
  reg [PTR_WIDTH-1:0]   write_ptr;
  reg [PTR_WIDTH-1:0]   read_ptr;
  reg                   stream_active;
  reg [BEAT_WIDTH-1:0]  beat_idx;
  reg [$clog2(VLEN)-1:0] vec_valid_num_col_tmp;
  reg [$clog2(VLEN)-1:0] vec_valid_num_row_tmp;
  reg                   transpose_mode_tmp;
  reg                   in_valid_q;
  bit                   oa_trace_en;

  wire in_valid_fall = in_valid_q & ~in_valid;
  wire write_bank_blocked = bank_ready[write_bank];
  wire has_partial_write_bank = (write_ptr != '0);
  // A temporary valid gap can appear between cached IA slots.  Only the
  // explicit tile_done marker is allowed to publish a bank to the writer.
  wire finish_write_bank = in_valid && in_tile_done;
  wire [COUNT_WIDTH-1:0] write_rows_next =
      in_valid ? (COUNT_WIDTH'(write_ptr) + COUNT_WIDTH'(1)) : COUNT_WIDTH'(write_ptr);
  wire [COUNT_WIDTH-1:0] active_read_count = bank_count[read_bank];
  wire [COUNT_WIDTH-1:0] output_row_count =
      transpose_mode_tmp ? (COUNT_WIDTH'(vec_valid_num_row_tmp) + COUNT_WIDTH'(1))
                         : active_read_count;
  wire [COUNT_WIDTH-1:0] output_col_count =
      transpose_mode_tmp ? active_read_count
                         : (COUNT_WIDTH'(vec_valid_num_col_tmp) + COUNT_WIDTH'(1));
  wire read_bank_ready = bank_ready[read_bank] && (bank_count[read_bank] != '0);
  wire [COUNT_WIDTH-1:0] last_beat_idx_cur =
      (output_col_count == '0) ? '0 : ((output_col_count - COUNT_WIDTH'(1)) / COUNT_WIDTH'(4));
  wire last_beat_in_row = output_ready && stream_active &&
                          (COUNT_WIDTH'(beat_idx) == last_beat_idx_cur);
  wire last_row_in_bank = last_beat_in_row &&
                          ((COUNT_WIDTH'(read_ptr) + COUNT_WIDTH'(1)) >= output_row_count);

  // Compatibility debug names used by existing testbenches.
  wire write_sel = write_bank[0];
  wire read_sel  = read_bank[0];
  wire bank_ready0 = bank_ready[0];
  wire bank_ready1 = (BANKS > 1) ? bank_ready[1] : 1'b0;
  wire [COUNT_WIDTH-1:0] bank_count0 = bank_count[0];
  wire [COUNT_WIDTH-1:0] bank_count1 = (BANKS > 1) ? bank_count[1] : '0;

  assign output_valid = stream_active;
  assign output_row_switch = last_beat_in_row;

  initial begin
    oa_trace_en = 1'b0;
    if ($test$plusargs("MMA_OA_TRACE")) oa_trace_en = 1'b1;
  end

  function automatic [BANK_WIDTH-1:0] next_bank(input [BANK_WIDTH-1:0] bank);
    begin
      if (bank == BANK_WIDTH'(BANKS - 1)) next_bank = '0;
      else                               next_bank = bank + 1'b1;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_valid_q <= 1'b0;
    end else begin
      in_valid_q <= in_valid;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_bank   <= '0;
      read_bank    <= '0;
      write_ptr    <= '0;
      read_ptr     <= '0;
      stream_active <= 1'b0;
      beat_idx     <= '0;
      vec_valid_num_col_tmp <= '0;
      vec_valid_num_row_tmp <= '0;
      transpose_mode_tmp <= 1'b0;
      oa_fifo_req  <= 1'b0;
      fifo_full_flag <= 1'b0;
      bank_ready   <= '0;
      for (int bank_idx = 0; bank_idx < BANKS; bank_idx++) begin
        bank_count[bank_idx] <= '0;
      end
    end else begin
      fifo_full_flag <= write_bank_blocked;
      oa_fifo_req    <= read_bank_ready && !stream_active;

      if (in_valid && !write_bank_blocked) begin
        fifo_mem[write_bank][write_ptr] <= in_vec_s8;
      end

      if (finish_write_bank && !write_bank_blocked) begin
        bank_count[write_bank] <= write_rows_next;
        bank_ready[write_bank] <= 1'b1;
        if (oa_trace_en) begin
          $display("[OA_TRACE] time=%0t fifo_bank_ready bank=%0d rows=%0d transpose=%0d vcol=%0d vrow=%0d",
                   $time, write_bank, write_rows_next, transpose_mode,
                   vec_valid_num_col, vec_valid_num_row);
        end
        write_ptr <= '0;
        write_bank <= next_bank(write_bank);
      end else if (in_valid && !write_bank_blocked) begin
        write_ptr <= write_ptr + 1'b1;
      end

      if (!stream_active && read_bank_ready) begin
        stream_active <= 1'b1;
        beat_idx      <= '0;
        read_ptr      <= '0;
        vec_valid_num_col_tmp <= vec_valid_num_col;
        vec_valid_num_row_tmp <= vec_valid_num_row;
        transpose_mode_tmp <= transpose_mode;
        if (oa_trace_en) begin
          $display("[OA_TRACE] time=%0t fifo_stream_start bank=%0d rows=%0d transpose=%0d vcol=%0d vrow=%0d",
                   $time, read_bank, bank_count[read_bank], transpose_mode,
                   vec_valid_num_col, vec_valid_num_row);
        end
      end else if (stream_active && (read_ptr == '0) && (beat_idx == '0) && !output_ready) begin
        vec_valid_num_col_tmp <= vec_valid_num_col;
        vec_valid_num_row_tmp <= vec_valid_num_row;
        transpose_mode_tmp <= transpose_mode;
      end else if (last_beat_in_row) begin
        beat_idx <= '0;
        if (last_row_in_bank) begin
          stream_active <= 1'b0;
          read_ptr      <= '0;
          bank_ready[read_bank] <= 1'b0;
          bank_count[read_bank] <= '0;
          read_bank <= next_bank(read_bank);
        end else begin
          read_ptr <= read_ptr + 1'b1;
        end
      end else if (stream_active && output_ready) begin
        beat_idx <= beat_idx + 1'b1;
      end
    end
  end

  integer valid_cols_i;
  integer beat_col_start_i;
  integer valid_in_beat_i;
  integer out_byte_i;
  integer src_row_i;

  always @(*) begin
    output_data = 32'b0;
    output_mask = 4'b0;
    valid_cols_i = output_col_count;
    beat_col_start_i = beat_idx * 4;
    valid_in_beat_i = valid_cols_i - beat_col_start_i;
    if (valid_in_beat_i > 4) valid_in_beat_i = 4;
    if (valid_in_beat_i < 0) valid_in_beat_i = 0;

    if (stream_active) begin
      if (transpose_mode_tmp) begin
        for (out_byte_i = 0; out_byte_i < 4; out_byte_i = out_byte_i + 1) begin
          src_row_i = beat_col_start_i + out_byte_i;
          if (src_row_i < active_read_count) begin
            output_data[out_byte_i*8+:8] =
                fifo_mem[read_bank][src_row_i][read_ptr*8+:8];
          end
        end
      end else begin
        output_data = fifo_mem[read_bank][read_ptr][beat_idx*32+:32];
      end

      case (valid_in_beat_i)
        1: output_mask = 4'b0001;
        2: output_mask = 4'b0011;
        3: output_mask = 4'b0111;
        4: output_mask = 4'b1111;
        default: output_mask = 4'b0000;
      endcase
    end
  end

  always @(posedge clk) begin
    if (rst_n && oa_trace_en && output_valid && output_ready) begin
      $display("[OA_TRACE] time=%0t fifo_out bank=%0d row=%0d beat=%0d mask=%b data=%08x rows=%0d cols=%0d transpose=%0d",
               $time, read_bank, read_ptr, beat_idx, output_mask, output_data,
               output_row_count, output_col_count, transpose_mode_tmp);
    end
  end

endmodule
