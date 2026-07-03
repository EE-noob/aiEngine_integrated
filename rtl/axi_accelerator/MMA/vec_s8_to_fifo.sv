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
    input  wire [          31:0] reserve_banks,
    input  wire [$clog2(VLEN)-1:0] vec_valid_num_col,
    input  wire [$clog2(VLEN)-1:0] vec_valid_num_row,
    output wire                 output_valid,
    input  wire                 output_ready,
    output wire                 output_row_switch,
    output reg  [          3:0] output_mask,
    output reg  [         31:0] output_data,
    output wire                 fifo_full_flag
);

  localparam integer PTR_WIDTH   = (VLEN <= 1) ? 1 : $clog2(VLEN);
  localparam integer COUNT_WIDTH = $clog2(VLEN + 1);
  localparam integer ROW_BEATS   = (VLEN + 3) >> 2;
  localparam integer BEAT_WIDTH  = (ROW_BEATS <= 1) ? 1 : $clog2(ROW_BEATS);
  localparam integer BANK_WIDTH  = (BANKS <= 1) ? 1 : $clog2(BANKS);
  localparam integer BANK_COUNT_WIDTH = (BANKS <= 1) ? 1 : $clog2(BANKS + 1);
  localparam integer ROW_BANKS   = 4;
  localparam integer MEM_DEPTH   = BANKS * ROW_BEATS;
  localparam integer MEM_ADDR_W  = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH);

  reg [COUNT_WIDTH-1:0] bank_count [0:BANKS-1];
  reg [BANKS-1:0] bank_ready;
  reg [BANK_COUNT_WIDTH-1:0] ready_bank_count_q;

  reg [BANK_WIDTH-1:0]  write_bank;
  reg [BANK_WIDTH-1:0]  read_bank;
  reg [PTR_WIDTH-1:0]   write_ptr;
  reg [PTR_WIDTH-1:0]   read_ptr;
  reg                   stream_active;
  reg                   data_valid;
  reg [BEAT_WIDTH-1:0]  beat_idx;
  reg [$clog2(VLEN)-1:0] vec_valid_num_col_tmp;
  reg [$clog2(VLEN)-1:0] vec_valid_num_row_tmp;
  reg                   transpose_mode_tmp;
  logic [VLEN*8-1:0]    ram_rd_data [ROW_BANKS];
  logic [MEM_ADDR_W-1:0] ram_wr_addr;
  logic [MEM_ADDR_W-1:0] ram_rd_addr [ROW_BANKS];
  logic [PTR_WIDTH-1:0] issue_read_ptr;
  logic [BEAT_WIDTH-1:0] issue_beat_idx;
  logic issue_transpose_mode;
  logic ram_read_en;
`ifndef SYNTHESIS
  bit                   oa_trace_en;
`else
  localparam bit        oa_trace_en = 1'b0;
`endif

  function automatic [BANK_WIDTH-1:0] next_bank(input [BANK_WIDTH-1:0] bank);
    begin
      if (bank == BANK_WIDTH'(BANKS - 1)) next_bank = '0;
      else                               next_bank = bank + 1'b1;
    end
  endfunction

  wire write_bank_blocked = bank_ready[write_bank];
  wire next_write_bank_blocked = bank_ready[next_bank(write_bank)];
  logic [BANK_COUNT_WIDTH-1:0] reserve_bank_count;
  logic [BANK_COUNT_WIDTH-1:0] used_bank_count;
  logic [BANK_COUNT_WIDTH-1:0] free_bank_count;
  logic                   fifo_watermark_full;
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
      (output_col_count == '0) ? '0 : ((output_col_count - COUNT_WIDTH'(1)) >> 2);
  wire output_fire = output_ready && output_valid;
  wire last_beat_in_row = output_fire &&
                          (COUNT_WIDTH'(beat_idx) == last_beat_idx_cur);
  wire last_row_in_bank = last_beat_in_row &&
                          ((COUNT_WIDTH'(read_ptr) + COUNT_WIDTH'(1)) >= output_row_count);
  wire start_stream = !stream_active && read_bank_ready;
  wire stream_has_next = output_fire && !last_row_in_bank;

  // Compatibility debug names used by existing testbenches.
  wire write_sel = write_bank[0];
  wire read_sel  = read_bank[0];
  wire bank_ready0 = bank_ready[0];
  wire bank_ready1 = (BANKS > 1) ? bank_ready[1] : 1'b0;
  wire [COUNT_WIDTH-1:0] bank_count0 = bank_count[0];
  wire [COUNT_WIDTH-1:0] bank_count1 = (BANKS > 1) ? bank_count[1] : '0;

  assign output_valid = stream_active && data_valid;
  assign output_row_switch = last_beat_in_row;
  always_comb begin
    if (reserve_banks == 32'd0) begin
      reserve_bank_count = BANK_COUNT_WIDTH'(1);
    end else if (reserve_banks >= 32'(BANKS)) begin
      reserve_bank_count = BANK_COUNT_WIDTH'(BANKS);
    end else begin
      reserve_bank_count = BANK_COUNT_WIDTH'(reserve_banks);
    end

    used_bank_count = ready_bank_count_q + ((write_ptr != '0) ? BANK_COUNT_WIDTH'(1) : BANK_COUNT_WIDTH'(0));
    free_bank_count = (used_bank_count >= BANK_COUNT_WIDTH'(BANKS))
                    ? '0
                    : (BANK_COUNT_WIDTH'(BANKS) - used_bank_count);
    fifo_watermark_full = (free_bank_count < reserve_bank_count);
  end

  assign fifo_full_flag = write_bank_blocked || next_write_bank_blocked || fifo_watermark_full;
  assign ram_read_en = start_stream || stream_has_next;

  always_comb begin
    issue_read_ptr = read_ptr;
    issue_beat_idx = beat_idx;
    issue_transpose_mode = transpose_mode_tmp;

    if (start_stream) begin
      issue_read_ptr = '0;
      issue_beat_idx = '0;
      issue_transpose_mode = transpose_mode;
    end else if (output_fire) begin
      if (last_beat_in_row) begin
        issue_read_ptr = read_ptr + 1'b1;
        issue_beat_idx = '0;
      end else begin
        issue_read_ptr = read_ptr;
        issue_beat_idx = beat_idx + 1'b1;
      end
    end
  end

  always_comb begin
    int wr_group;
    int wr_addr_i;

    wr_group = int'(COUNT_WIDTH'(write_ptr) >> 2);
    wr_addr_i = (int'(write_bank) * ROW_BEATS) + wr_group;
    ram_wr_addr = MEM_ADDR_W'(wr_addr_i);

    for (int rb = 0; rb < ROW_BANKS; rb++) begin
      int rd_group;
      int rd_addr_i;

      rd_group = issue_transpose_mode ? int'(COUNT_WIDTH'(issue_beat_idx))
                                      : int'(COUNT_WIDTH'(issue_read_ptr) >> 2);
      rd_addr_i = (int'(read_bank) * ROW_BEATS) + rd_group;
      ram_rd_addr[rb] = MEM_ADDR_W'(rd_addr_i);
    end
  end

  genvar ram_bank;
  generate
    for (ram_bank = 0; ram_bank < ROW_BANKS; ram_bank++) begin : gen_fifo_ram
      wire row_wr_en = in_valid && !write_bank_blocked && (2'(write_ptr) == 2'(ram_bank));

      vec_s8_fifo_row_ram #(
        .DATA_WIDTH(VLEN * 8),
        .DEPTH     (MEM_DEPTH),
        .ADDR_WIDTH(MEM_ADDR_W)
      ) u_fifo_ram (
        .clk    (clk),
        .wr_en  (row_wr_en),
        .wr_addr(ram_wr_addr),
        .wr_data(in_vec_s8),
        .rd_en  (ram_read_en),
        .rd_addr(ram_rd_addr[ram_bank]),
        .rd_data(ram_rd_data[ram_bank])
      );
    end
  endgenerate

`ifndef SYNTHESIS
  initial begin
    oa_trace_en = 1'b0;
    if ($test$plusargs("MMA_OA_TRACE")) oa_trace_en = 1'b1;
  end
`endif

  always @(posedge clk) begin
    if (!rst_n) begin
      write_bank   <= '0;
      read_bank    <= '0;
      write_ptr    <= '0;
      read_ptr     <= '0;
      stream_active <= 1'b0;
      data_valid   <= 1'b0;
      beat_idx     <= '0;
      vec_valid_num_col_tmp <= '0;
      vec_valid_num_row_tmp <= '0;
      transpose_mode_tmp <= 1'b0;
      oa_fifo_req  <= 1'b0;
      bank_ready   <= '0;
      ready_bank_count_q <= '0;
      for (int bank_idx = 0; bank_idx < BANKS; bank_idx++) begin
        bank_count[bank_idx] <= '0;
      end
    end else begin
      oa_fifo_req    <= read_bank_ready && !stream_active;

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
        if (!(output_fire && last_row_in_bank)) begin
          ready_bank_count_q <= ready_bank_count_q + BANK_COUNT_WIDTH'(1);
        end
      end else if (in_valid && !write_bank_blocked) begin
        write_ptr <= write_ptr + 1'b1;
      end

      if (start_stream) begin
        stream_active <= 1'b1;
        data_valid    <= 1'b1;
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
      end else if (output_fire) begin
        if (last_row_in_bank) begin
          stream_active <= 1'b0;
          data_valid    <= 1'b0;
          read_ptr      <= '0;
          beat_idx      <= '0;
          bank_ready[read_bank] <= 1'b0;
          bank_count[read_bank] <= '0;
          read_bank <= next_bank(read_bank);
          if (!(finish_write_bank && !write_bank_blocked)) begin
            ready_bank_count_q <= ready_bank_count_q - BANK_COUNT_WIDTH'(1);
          end
        end else if (last_beat_in_row) begin
          beat_idx <= '0;
          read_ptr <= read_ptr + 1'b1;
        end else begin
          beat_idx <= beat_idx + 1'b1;
        end
      end
    end
  end

  integer valid_cols_i;
  integer beat_col_start_i;
  integer valid_in_beat_i;
  integer out_byte_i;
  integer src_row_i;
  integer read_bank_i;

  always @(*) begin
    output_data = 32'b0;
    output_mask = 4'b0;
    valid_cols_i = int'(output_col_count);
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
                ram_rd_data[out_byte_i][int'(read_ptr)*8+:8];
          end
        end
      end else begin
        read_bank_i = int'(2'(read_ptr));
        output_data = ram_rd_data[read_bank_i][beat_idx*32+:32];
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

module vec_s8_fifo_row_ram #(
    parameter int unsigned DATA_WIDTH = 128,
    parameter int unsigned DEPTH = 16,
    parameter int unsigned ADDR_WIDTH = 4
) (
    input  logic                  clk,
    input  logic                  wr_en,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic                  rd_en,
    input  logic [ADDR_WIDTH-1:0] rd_addr,
    output logic [DATA_WIDTH-1:0] rd_data
);

  (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  always_ff @(posedge clk) begin
    if (wr_en) begin
      mem[wr_addr] <= wr_data;
    end
    if (rd_en) begin
      rd_data <= mem[rd_addr];
    end
  end

endmodule
