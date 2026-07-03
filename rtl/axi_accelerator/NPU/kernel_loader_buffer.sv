module kernel_loader_buffer #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned SIZE       = 4
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         load_start,
    input  logic                         row_valid,
    input  logic [$clog2(SIZE)-1:0]      row_idx,
    input  logic signed [DATA_WIDTH-1:0] row_data [SIZE],
    input  logic                         load_done,
    input  logic                         send_start,
    output logic                         load_ready,
    output logic                         weight_data_valid,
    output logic                         weight_sending_done,
    output logic                         store_weight_req,
    output logic signed [DATA_WIDTH-1:0] weight_out [SIZE]
);

  localparam int unsigned SLOT_COUNT = 2;
  localparam int unsigned SLOT_W = 1;
  localparam int unsigned COUNT_W = 2;
  localparam int unsigned IDX_W = (SIZE <= 1) ? 1 : $clog2(SIZE);
  localparam int unsigned VALID_W = $clog2(SIZE + 1);
  localparam int unsigned ROW_VEC_W = DATA_WIDTH * SIZE;

  logic [SLOT_W-1:0] wr_slot;
  logic [SLOT_W-1:0] rd_slot;
  logic [SLOT_W-1:0] load_slot;
  logic [IDX_W-1:0] send_row_idx;
  logic [IDX_W-1:0] emit_col_idx;
  logic [COUNT_W-1:0] valid_count;
  logic [VALID_W-1:0] slot_valid_cols [SLOT_COUNT];
  logic [VALID_W-1:0] load_valid_cols;
  logic [VALID_W-1:0] send_valid_cols;
  logic send_active;
  logic send_pending;
  logic send_prefetch;
  logic load_busy;
  logic row_rd_en;
  logic [ROW_VEC_W-1:0] row_data_vec;
  logic [ROW_VEC_W-1:0] row_data_vec_q;
  logic [ROW_VEC_W-1:0] row_rd_data [SIZE];
  logic row_valid_q;
  logic load_done_q;
  logic [IDX_W-1:0] row_idx_q;
  logic [SIZE-1:0] row_wr_bank_q;
`ifndef SYNTHESIS
  bit kernel_buf_trace_en;

  assign load_ready = !load_busy && (valid_count < COUNT_W'(SLOT_COUNT));
  assign weight_data_valid = (valid_count != '0) && !send_active && !send_pending && !send_prefetch;

  initial begin
    kernel_buf_trace_en = 1'b0;
    if ($test$plusargs("NPU_KERNEL_BUF_TRACE")) kernel_buf_trace_en = 1'b1;
  end
`else
  localparam bit kernel_buf_trace_en = 1'b0;

  assign load_ready = !load_busy && (valid_count < COUNT_W'(SLOT_COUNT));
  assign weight_data_valid = (valid_count != '0) && !send_active && !send_pending && !send_prefetch;
`endif

  always_comb begin
    row_data_vec = '0;
    for (int c = 0; c < SIZE; c++) begin
      row_data_vec[c*DATA_WIDTH+:DATA_WIDTH] = row_data[c];
    end
  end

  genvar row_bank;
  generate
    for (row_bank = 0; row_bank < SIZE; row_bank++) begin : gen_row_ram
      wire row_wr_en = row_wr_bank_q[row_bank] && load_busy;

      kernel_loader_row_ram #(
        .DATA_WIDTH(ROW_VEC_W),
        .DEPTH     (SLOT_COUNT),
        .ADDR_WIDTH(SLOT_W)
      ) u_row_ram (
        .clk    (clk),
        .wr_en  (row_wr_en),
        .wr_addr(load_slot),
        .wr_data(row_data_vec_q),
        .rd_en  (row_rd_en),
        .rd_addr(rd_slot),
        .rd_data(row_rd_data[row_bank])
      );
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      wr_slot             <= '0;
      rd_slot             <= '0;
      load_slot           <= '0;
      send_row_idx        <= '0;
      emit_col_idx        <= '0;
      valid_count         <= '0;
      load_valid_cols     <= '0;
      send_valid_cols     <= '0;
      send_active         <= 1'b0;
      send_pending        <= 1'b0;
      send_prefetch       <= 1'b0;
      load_busy           <= 1'b0;
      row_valid_q         <= 1'b0;
      load_done_q         <= 1'b0;
      row_idx_q           <= '0;
      row_data_vec_q      <= '0;
      row_wr_bank_q       <= '0;
      row_rd_en           <= 1'b0;
      store_weight_req    <= 1'b0;
      weight_sending_done <= 1'b0;
      for (int c = 0; c < SIZE; c++) begin
        weight_out[c] <= '0;
      end
      for (int s = 0; s < SLOT_COUNT; s++) begin
        slot_valid_cols[s] <= '0;
      end
    end else begin
      logic load_complete_event;
      logic send_complete_event;
      logic [VALID_W-1:0] row_valid_cols_next;

      load_complete_event = load_done_q && load_busy;
      send_complete_event = 1'b0;
      row_valid_cols_next = load_valid_cols;
      if (row_valid_q && load_busy) begin
        if ((VALID_W'(row_idx_q) + VALID_W'(1)) > load_valid_cols) begin
          row_valid_cols_next = VALID_W'(row_idx_q) + VALID_W'(1);
        end
      end
      row_valid_q   <= row_valid;
      load_done_q   <= load_done;
      row_idx_q     <= row_idx;
      row_data_vec_q <= row_data_vec;
      row_wr_bank_q <= '0;
      if (row_valid) begin
        row_wr_bank_q[row_idx] <= 1'b1;
      end
      store_weight_req    <= 1'b0;
      weight_sending_done <= 1'b0;
      row_rd_en           <= 1'b0;

      if (load_start && load_ready) begin
        load_busy <= 1'b1;
        load_slot <= wr_slot;
        load_valid_cols <= '0;
      end

      if (row_valid_q && load_busy) begin
        load_valid_cols <= row_valid_cols_next;
      end

      if (load_complete_event) begin
        load_busy <= 1'b0;
        wr_slot   <= wr_slot + 1'b1;
        slot_valid_cols[load_slot] <= row_valid_cols_next;
      end

      if (send_start && weight_data_valid) begin
        send_pending <= 1'b1;
        row_rd_en <= 1'b1;
        send_valid_cols <= slot_valid_cols[rd_slot];
      end

      if (send_pending) begin
        send_pending  <= 1'b0;
        send_prefetch <= 1'b1;
      end else if (send_prefetch && (valid_count != '0) && !send_active) begin
        send_active       <= 1'b1;
        send_prefetch     <= 1'b0;
        store_weight_req  <= 1'b1;
        for (int c = 0; c < SIZE; c++) begin
          if (VALID_W'(c) < slot_valid_cols[rd_slot]) begin
            weight_out[c] <= $signed(row_rd_data[c][(SIZE-1)*DATA_WIDTH+:DATA_WIDTH]);
          end else begin
            weight_out[c] <= '0;
          end
        end
        if (kernel_buf_trace_en) begin
          $write("[KBUF_TRACE] time=%0t send row=%0d w=", $time, SIZE - 1);
          for (int dbg_c = 0; dbg_c < SIZE; dbg_c++) begin
            $write("%0d%s", $signed(row_rd_data[dbg_c][(SIZE-1)*DATA_WIDTH+:DATA_WIDTH]), (dbg_c == SIZE - 1) ? "" : ",");
          end
          $write("\n");
        end
        if (SIZE == 1) begin
          send_active         <= 1'b0;
          weight_sending_done <= 1'b1;
          send_complete_event = 1'b1;
        end else begin
          send_row_idx <= $bits(send_row_idx)'(SIZE - 2);
          emit_col_idx <= $bits(emit_col_idx)'(SIZE - 2);
        end
      end else if (send_active) begin
        store_weight_req <= 1'b1;
        for (int c = 0; c < SIZE; c++) begin
          if (VALID_W'(c) < send_valid_cols) begin
            weight_out[c] <= $signed(row_rd_data[c][int'(emit_col_idx)*DATA_WIDTH+:DATA_WIDTH]);
          end else begin
            weight_out[c] <= '0;
          end
        end
        if (kernel_buf_trace_en) begin
          $write("[KBUF_TRACE] time=%0t send row=%0d w=", $time, emit_col_idx);
          for (int dbg_c = 0; dbg_c < SIZE; dbg_c++) begin
            $write("%0d%s", $signed(row_rd_data[dbg_c][int'(emit_col_idx)*DATA_WIDTH+:DATA_WIDTH]), (dbg_c == SIZE - 1) ? "" : ",");
          end
          $write("\n");
        end
        if (send_row_idx == '0) begin
          send_active         <= 1'b0;
          weight_sending_done <= 1'b1;
          send_complete_event = 1'b1;
        end else begin
          send_row_idx <= send_row_idx - 1'b1;
          emit_col_idx <= emit_col_idx - 1'b1;
        end
      end

      unique case ({load_complete_event, send_complete_event})
        2'b10: valid_count <= valid_count + 1'b1;
        2'b01: valid_count <= valid_count - 1'b1;
        default: valid_count <= valid_count;
      endcase

      if (send_complete_event) begin
        rd_slot <= rd_slot + 1'b1;
      end
    end
  end

endmodule

module kernel_loader_row_ram #(
    parameter int unsigned DATA_WIDTH = 128,
    parameter int unsigned DEPTH = 2,
    parameter int unsigned ADDR_WIDTH = 1
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
