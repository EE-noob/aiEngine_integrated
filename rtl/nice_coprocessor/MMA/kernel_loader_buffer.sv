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

  logic signed [DATA_WIDTH-1:0] mem [SLOT_COUNT][SIZE][SIZE];
  logic [SLOT_W-1:0] wr_slot;
  logic [SLOT_W-1:0] rd_slot;
  logic [SLOT_W-1:0] load_slot;
  logic [$clog2(SIZE)-1:0] send_row_idx;
  logic [COUNT_W-1:0] valid_count;
  logic send_active;
  logic send_pending;
  logic load_busy;
  bit kernel_buf_trace_en;

  assign load_ready = !load_busy && (valid_count < COUNT_W'(SLOT_COUNT));
  assign weight_data_valid = (valid_count != '0) && !send_active && !send_pending;

  initial begin
    kernel_buf_trace_en = 1'b0;
    if ($test$plusargs("MMA_KERNEL_BUF_TRACE")) kernel_buf_trace_en = 1'b1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_slot             <= '0;
      rd_slot             <= '0;
      load_slot           <= '0;
      send_row_idx        <= '0;
      valid_count         <= '0;
      send_active         <= 1'b0;
      send_pending        <= 1'b0;
      load_busy           <= 1'b0;
      store_weight_req    <= 1'b0;
      weight_sending_done <= 1'b0;
      for (int s = 0; s < SLOT_COUNT; s++) begin
        for (int r = 0; r < SIZE; r++) begin
          for (int c = 0; c < SIZE; c++) begin
            mem[s][r][c] <= '0;
          end
        end
      end
      for (int c = 0; c < SIZE; c++) begin
        weight_out[c] <= '0;
      end
    end else begin
      logic load_complete_event;
      logic send_complete_event;

      load_complete_event = load_done && load_busy;
      send_complete_event = 1'b0;
      store_weight_req    <= 1'b0;
      weight_sending_done <= 1'b0;

      if (load_start && load_ready) begin
        load_busy <= 1'b1;
        load_slot <= wr_slot;
        for (int r = 0; r < SIZE; r++) begin
          for (int c = 0; c < SIZE; c++) begin
            mem[wr_slot][r][c] <= '0;
          end
        end
      end

      if (row_valid && load_busy) begin
        for (int c = 0; c < SIZE; c++) begin
          mem[load_slot][row_idx][c] <= row_data[c];
        end
      end

      if (load_complete_event) begin
        load_busy <= 1'b0;
        wr_slot   <= wr_slot + 1'b1;
      end

      if (send_start && weight_data_valid) begin
        send_pending <= 1'b1;
      end

      if (send_pending && (valid_count != '0) && !send_active) begin
        send_active       <= 1'b1;
        send_pending      <= 1'b0;
        store_weight_req  <= 1'b1;
        for (int c = 0; c < SIZE; c++) begin
          weight_out[c] <= mem[rd_slot][SIZE - 1][c];
        end
        if (kernel_buf_trace_en) begin
          $display("[KBUF_TRACE] time=%0t send row=%0d w0=%0d w1=%0d w2=%0d w3=%0d w4=%0d",
                   $time, SIZE - 1,
                   mem[rd_slot][SIZE - 1][0], mem[rd_slot][SIZE - 1][1],
                   mem[rd_slot][SIZE - 1][2], mem[rd_slot][SIZE - 1][3],
                   mem[rd_slot][SIZE - 1][4]);
        end
        if (SIZE == 1) begin
          send_active         <= 1'b0;
          weight_sending_done <= 1'b1;
          send_complete_event = 1'b1;
        end else begin
          send_row_idx <= $bits(send_row_idx)'(SIZE - 2);
        end
      end else if (send_active) begin
        store_weight_req <= 1'b1;
        for (int c = 0; c < SIZE; c++) begin
          weight_out[c] <= mem[rd_slot][send_row_idx][c];
        end
        if (kernel_buf_trace_en) begin
          $display("[KBUF_TRACE] time=%0t send row=%0d w0=%0d w1=%0d w2=%0d w3=%0d w4=%0d",
                   $time, send_row_idx,
                   mem[rd_slot][send_row_idx][0], mem[rd_slot][send_row_idx][1],
                   mem[rd_slot][send_row_idx][2], mem[rd_slot][send_row_idx][3],
                   mem[rd_slot][send_row_idx][4]);
        end
        if (send_row_idx == '0) begin
          send_active         <= 1'b0;
          weight_sending_done <= 1'b1;
          send_complete_event = 1'b1;
        end else begin
          send_row_idx <= send_row_idx - 1'b1;
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
