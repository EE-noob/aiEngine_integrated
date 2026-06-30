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
    output logic                         weight_data_valid,
    output logic                         weight_sending_done,
    output logic                         store_weight_req,
    output logic signed [DATA_WIDTH-1:0] weight_out [SIZE]
);

  logic signed [DATA_WIDTH-1:0] mem [SIZE][SIZE];
  logic [$clog2(SIZE)-1:0] send_row_idx;
  logic send_active;
  logic send_pending;
  logic buf_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      send_row_idx         <= '0;
      send_active          <= 1'b0;
      send_pending         <= 1'b0;
      buf_valid            <= 1'b0;
      store_weight_req     <= 1'b0;
      weight_sending_done  <= 1'b0;
      for (int r = 0; r < SIZE; r++) begin
        for (int c = 0; c < SIZE; c++) begin
          mem[r][c] <= '0;
        end
      end
      for (int c = 0; c < SIZE; c++) begin
        weight_out[c] <= '0;
      end
    end else begin
      store_weight_req    <= 1'b0;
      weight_sending_done <= 1'b0;

      if (load_start) begin
        buf_valid   <= 1'b0;
        send_active <= 1'b0;
        send_pending <= 1'b0;
        send_row_idx <= '0;
        for (int r = 0; r < SIZE; r++) begin
          for (int c = 0; c < SIZE; c++) begin
            mem[r][c] <= '0;
          end
        end
        for (int c = 0; c < SIZE; c++) begin
          weight_out[c] <= '0;
        end
      end

      if (row_valid) begin
        for (int c = 0; c < SIZE; c++) begin
          mem[row_idx][c] <= row_data[c];
        end
      end

      if (load_done) begin
        buf_valid <= 1'b1;
      end

      if (send_start) begin
        send_pending <= 1'b1;
      end

      if (send_pending && buf_valid && !send_active) begin
        send_active  <= 1'b1;
        send_pending <= 1'b0;
        store_weight_req <= 1'b1;
        for (int c = 0; c < SIZE; c++) begin
          weight_out[c] <= mem[SIZE - 1][c];
        end
        if (SIZE == 1) begin
          send_active         <= 1'b0;
          buf_valid           <= 1'b0;
          weight_sending_done <= 1'b1;
        end else begin
          send_row_idx <= $bits(send_row_idx)'(SIZE - 2);
        end
      end else if (send_active) begin
        store_weight_req <= 1'b1;
        for (int c = 0; c < SIZE; c++) begin
          weight_out[c] <= mem[send_row_idx][c];
        end
        if (send_row_idx == '0) begin
          send_active         <= 1'b0;
          buf_valid           <= 1'b0;
          weight_sending_done <= 1'b1;
        end else begin
          send_row_idx <= send_row_idx - 1;
        end
      end
    end
  end

  assign weight_data_valid = buf_valid && !send_active && !send_pending;

endmodule
