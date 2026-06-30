module kernel_block_dma #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned SIZE       = 4,
    parameter int unsigned BUS_WIDTH  = 32,
    parameter int unsigned REG_WIDTH  = 32
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         start,
    input  logic [REG_WIDTH-1:0]         tile_base_addr,
    input  logic [REG_WIDTH-1:0]         row_stride_b,
    input  logic [REG_WIDTH-1:0]         rows_to_read,
    input  logic [REG_WIDTH-1:0]         valid_cols,
    input  logic signed [REG_WIDTH-1:0]  rhs_zp,
    input  logic                         use_16bits,
    output logic                         busy,
    output logic                         done,
    output logic                         row_valid,
    output logic [$clog2(SIZE)-1:0]      row_idx,
    output logic signed [DATA_WIDTH-1:0] row_data [SIZE],
    output logic                         icb_cmd_valid,
    input  logic                         icb_cmd_ready,
    output logic                         icb_cmd_read,
    output logic [REG_WIDTH-1:0]         icb_cmd_addr,
    output logic [3:0]                   icb_cmd_len,
    input  logic                         icb_rsp_valid,
    output logic                         icb_rsp_ready,
    input  logic [BUS_WIDTH-1:0]         icb_rsp_rdata,
    input  logic                         icb_rsp_err
);

  typedef enum logic [1:0] {S_IDLE, S_ISSUE, S_WAIT_RSP} state_t;
  state_t state;

  logic [REG_WIDTH-1:0] base_r;
  logic [REG_WIDTH-1:0] stride_r;
  logic [REG_WIDTH-1:0] rows_r;
  logic [REG_WIDTH-1:0] valid_cols_r;
  logic signed [REG_WIDTH-1:0] rhs_zp_r;
  logic use_16bits_r;
  logic [REG_WIDTH-1:0] row_cnt;
  logic [REG_WIDTH-1:0] rsp_beat_cnt;
  logic                         row_valid_pending;
  logic                         done_pending;
  logic [$clog2(SIZE)-1:0]      row_idx_pending;
  logic signed [DATA_WIDTH-1:0] row_data_pending [SIZE];

  assign icb_cmd_read  = 1'b1;
  localparam int BYTE_PER_BEAT = BUS_WIDTH / 8;
  localparam int ELEM_PER_BEAT_S8 = BYTE_PER_BEAT;
  localparam int ELEM_PER_BEAT_S16 = BYTE_PER_BEAT / 2;

  logic [REG_WIDTH-1:0] elems_per_beat;
  logic [REG_WIDTH-1:0] beats_per_row;
  logic [3:0]           beats_per_row_m1;

  always_comb begin
    elems_per_beat = use_16bits_r ? REG_WIDTH'(ELEM_PER_BEAT_S16) : REG_WIDTH'(ELEM_PER_BEAT_S8);
    if (valid_cols_r == 0) begin
      beats_per_row = REG_WIDTH'(1);
    end else begin
      beats_per_row = (valid_cols_r + elems_per_beat - 1) / elems_per_beat;
      if (beats_per_row == 0) beats_per_row = REG_WIDTH'(1);
    end
    beats_per_row_m1 = 4'(beats_per_row - 1);
  end

  assign icb_cmd_len   = beats_per_row_m1;
  assign icb_rsp_ready = (state == S_WAIT_RSP);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      busy         <= 1'b0;
      done         <= 1'b0;
      row_valid    <= 1'b0;
      row_idx      <= '0;
      row_cnt      <= '0;
      rsp_beat_cnt <= '0;
      base_r       <= '0;
      stride_r     <= '0;
      rows_r       <= '0;
      valid_cols_r <= '0;
      rhs_zp_r     <= '0;
      use_16bits_r <= 1'b0;
      row_valid_pending <= 1'b0;
      done_pending      <= 1'b0;
      row_idx_pending   <= '0;
      icb_cmd_valid <= 1'b0;
      icb_cmd_addr  <= '0;
      for (int i = 0; i < SIZE; i++) begin
        row_data[i] <= '0;
        row_data_pending[i] <= '0;
      end
    end else begin
      row_valid <= row_valid_pending;
      done      <= done_pending;
      if (row_valid_pending) begin
        row_idx <= row_idx_pending;
        for (int i = 0; i < SIZE; i++) begin
          row_data[i] <= row_data_pending[i];
        end
      end
      row_valid_pending <= 1'b0;
      done_pending      <= 1'b0;

      if (start && state == S_IDLE) begin
        busy     <= 1'b1;
        base_r   <= tile_base_addr;
        stride_r <= row_stride_b;
        rows_r   <= rows_to_read;
        valid_cols_r <= valid_cols;
        rhs_zp_r <= rhs_zp;
        use_16bits_r <= use_16bits;
        row_cnt  <= '0;
        rsp_beat_cnt <= '0;
        state    <= S_ISSUE;
      end

      case (state)
        S_IDLE: begin
          busy <= 1'b0;
          icb_cmd_valid <= 1'b0;
        end

        S_ISSUE: begin
          busy <= 1'b1;
          if (!icb_cmd_valid) begin
            icb_cmd_valid <= 1'b1;
            icb_cmd_addr  <= base_r + row_cnt * stride_r;
            rsp_beat_cnt  <= '0;
            for (int c = 0; c < SIZE; c++) begin
              row_data_pending[c] <= '0;
            end
          end
          if (icb_cmd_valid && icb_cmd_ready) begin
            icb_cmd_valid <= 1'b0;
            state <= S_WAIT_RSP;
          end
        end

        S_WAIT_RSP: begin
          busy <= 1'b1;
          if (icb_rsp_valid && icb_rsp_ready) begin
          if (icb_rsp_err) begin
              state <= S_IDLE;
              busy  <= 1'b0;
              done_pending <= 1'b1;
            end else begin
              if (use_16bits_r) begin
                for (int i = 0; i < ELEM_PER_BEAT_S16; i++) begin
                  automatic int col;
                  automatic logic signed [15:0] elem_s16;
                  automatic logic signed [DATA_WIDTH-1:0] zp_value;
                  col = int'(rsp_beat_cnt * ELEM_PER_BEAT_S16 + i);
                  elem_s16 = icb_rsp_rdata[i*16 +: 16];
                  zp_value = DATA_WIDTH'(rhs_zp_r);
                  if (col < SIZE && REG_WIDTH'(col) < valid_cols_r) begin
                    row_data_pending[col] <= DATA_WIDTH'($signed(elem_s16) + zp_value);
                  end
                end
              end else begin
                for (int i = 0; i < ELEM_PER_BEAT_S8; i++) begin
                  automatic int col;
                  automatic logic signed [7:0] elem_s8;
                  automatic logic signed [DATA_WIDTH-1:0] zp_value;
                  col = int'(rsp_beat_cnt * ELEM_PER_BEAT_S8 + i);
                  elem_s8 = icb_rsp_rdata[i*8 +: 8];
                  zp_value = DATA_WIDTH'(rhs_zp_r);
                  if (col < SIZE && REG_WIDTH'(col) < valid_cols_r) begin
                    row_data_pending[col] <= DATA_WIDTH'($signed(elem_s8) + zp_value);
                  end
                end
              end

              if (rsp_beat_cnt == beats_per_row - 1) begin
                row_idx_pending   <= row_cnt[$clog2(SIZE)-1:0];
                row_valid_pending <= 1'b1;
                rsp_beat_cnt      <= '0;
                if (row_cnt == rows_r - 1) begin
                  done_pending <= 1'b1;
                  state <= S_IDLE;
                  busy  <= 1'b0;
                end else begin
                  row_cnt <= row_cnt + 1;
                  state   <= S_ISSUE;
                end
              end else begin
                rsp_beat_cnt <= rsp_beat_cnt + 1;
              end
            end
          end
        end
      endcase
    end
  end

endmodule
