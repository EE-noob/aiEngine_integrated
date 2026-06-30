module kernel_loader #(
	    parameter int unsigned DATA_WIDTH   = 8,
	    parameter int unsigned SIZE         = 4,
	    parameter int unsigned BUS_WIDTH    = 32,
	    parameter int unsigned REG_WIDTH    = 32,
	    parameter int unsigned CACHE_BLOCKS = 1,
	    parameter bit          EXTERNAL_DMA = 1'b0
	) (
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        init_cfg,
    output logic                        load_weight_req,
    input  logic                        load_weight_granted,
    input  logic                        send_weight_trigger,
    input  logic [REG_WIDTH-1:0]        k,
    input  logic [REG_WIDTH-1:0]        n,
    input  logic [REG_WIDTH-1:0]        m,
    input  logic [REG_WIDTH-1:0]        rhs_base,
    input  logic [REG_WIDTH-1:0]        rhs_row_stride_b,
    input  logic signed [REG_WIDTH-1:0] rhs_zp,
    input  logic                        use_16bits,
    input  logic [REG_WIDTH-1:0]        ia_reuse_num,
    input  logic [REG_WIDTH-1:0]        w_reuse_num,
    output logic                        icb_cmd_valid,
    input  logic                        icb_cmd_ready,
    output logic                        icb_cmd_read,
    output logic [REG_WIDTH-1:0]        icb_cmd_addr,
    output logic [3:0]                  icb_cmd_len,
	    input  logic                        icb_rsp_valid,
	    output logic                        icb_rsp_ready,
	    input  logic [BUS_WIDTH-1:0]        icb_rsp_rdata,
	    input  logic                        icb_rsp_err,
	    output logic                        ext_dma_start,
	    output logic                        ext_dma_is_write,
	    output logic                        ext_dma_linear_read_mode,
	    output logic [REG_WIDTH-1:0]        ext_dma_base_addr,
	    output logic [REG_WIDTH-1:0]        ext_dma_row_stride,
	    output logic [REG_WIDTH-1:0]        ext_dma_rows_to_read,
	    output logic [3:0]                  ext_dma_burst_len_m1,
	    output logic                        ext_dma_slot_id,
	    output logic                        ext_dma_use_16bits,
	    output logic signed [REG_WIDTH-1:0] ext_dma_lhs_zp,
	    input  logic                        ext_dma_busy,
	    input  logic                        ext_dma_done,
	    input  logic [$clog2(SIZE)-1:0]     ext_dma_wr_row,
	    input  logic [$clog2(SIZE)-1:0]     ext_dma_wr_col_base,
	    input  logic signed [DATA_WIDTH-1:0] ext_dma_wr_data [BUS_WIDTH/8],
	    input  logic                        ext_dma_wr_valid[BUS_WIDTH/8],
	    output logic                        weight_sending_done,
	    output logic                        load_weight_done,
	    output logic                        store_weight_req,
    output logic signed [DATA_WIDTH-1:0] weight_out [SIZE],
    output logic                        weight_data_valid
);

  typedef enum logic [1:0] {TOP_IDLE, TOP_INIT, TOP_RUN} top_state_t;

  top_state_t top_state;

  logic [REG_WIDTH-1:0] cfg_k, cfg_n, cfg_m;
  logic [REG_WIDTH-1:0] cfg_rhs_base, cfg_rhs_row_stride_b;
  logic signed [REG_WIDTH-1:0] cfg_rhs_zp;
  logic cfg_use_16bits;
  logic [REG_WIDTH-1:0] cfg_ia_reuse_num, cfg_w_reuse_num;

  logic cfg_valid;
  logic ctrl_all_done;

  logic                        dma_start;
  logic [REG_WIDTH-1:0]        dma_tile_base_addr;
  logic [REG_WIDTH-1:0]        dma_rows_to_read;
  logic [REG_WIDTH-1:0]        dma_row_stride_b;
  logic [REG_WIDTH-1:0]        dma_valid_cols;
  logic signed [REG_WIDTH-1:0] dma_rhs_zp;
  logic                        buf_load_start;
  logic                        buf_send_start;
  logic                        dma_busy;
	  logic                        dma_done;
	  assign load_weight_done = dma_done;

	  logic                        dma_row_valid;
	  logic [$clog2(SIZE)-1:0]     dma_row_idx;
	  logic signed [DATA_WIDTH-1:0] dma_row_data [SIZE];
	  localparam int BYTE_PER_BEAT = BUS_WIDTH / 8;
	  localparam int ELEM_PER_BEAT_S8 = BYTE_PER_BEAT;
	  localparam int ELEM_PER_BEAT_S16 = BYTE_PER_BEAT / 2;
	  logic [REG_WIDTH-1:0] dma_elems_per_beat;
	  logic [REG_WIDTH-1:0] dma_beats_per_row;
	  logic [3:0]           dma_burst_len_m1;

	  always_comb begin
	    dma_elems_per_beat = cfg_use_16bits ? REG_WIDTH'(ELEM_PER_BEAT_S16) : REG_WIDTH'(ELEM_PER_BEAT_S8);
	    if (dma_valid_cols == 0) begin
	      dma_beats_per_row = REG_WIDTH'(1);
	    end else begin
	      dma_beats_per_row = (dma_valid_cols + dma_elems_per_beat - 1) / dma_elems_per_beat;
	      if (dma_beats_per_row == 0) dma_beats_per_row = REG_WIDTH'(1);
	    end
	    dma_burst_len_m1 = 4'(dma_beats_per_row - 1);
	  end

	  assign ext_dma_start            = dma_start;
	  assign ext_dma_is_write         = 1'b0;
	  assign ext_dma_linear_read_mode = 1'b0;
	  assign ext_dma_base_addr        = dma_tile_base_addr;
	  assign ext_dma_row_stride       = dma_row_stride_b;
	  assign ext_dma_rows_to_read     = dma_rows_to_read;
	  assign ext_dma_burst_len_m1     = dma_burst_len_m1;
	  assign ext_dma_slot_id          = 1'b0;
	  assign ext_dma_use_16bits       = cfg_use_16bits;
	  assign ext_dma_lhs_zp           = dma_rhs_zp;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      top_state          <= TOP_IDLE;
      cfg_valid          <= 1'b0;
      cfg_k              <= '0;
      cfg_n              <= '0;
      cfg_m              <= '0;
      cfg_rhs_base       <= '0;
      cfg_rhs_row_stride_b <= '0;
      cfg_rhs_zp         <= '0;
      cfg_use_16bits     <= 1'b0;
      cfg_ia_reuse_num   <= '0;
      cfg_w_reuse_num    <= '0;
    end else begin
      case (top_state)
        TOP_IDLE: begin
          cfg_valid <= 1'b0;
          if (init_cfg) begin
            top_state <= TOP_INIT;
          end
        end

        TOP_INIT: begin
          cfg_k               <= k;
          cfg_n               <= n;
          cfg_m               <= m;
          cfg_rhs_base        <= rhs_base;
          cfg_rhs_row_stride_b<= rhs_row_stride_b;
          cfg_rhs_zp          <= rhs_zp;
          cfg_use_16bits      <= use_16bits;
          cfg_ia_reuse_num    <= ia_reuse_num;
          cfg_w_reuse_num     <= w_reuse_num;
          cfg_valid           <= 1'b1;
          top_state           <= TOP_RUN;
        end

        TOP_RUN: begin
          if (ctrl_all_done) begin
            cfg_valid  <= 1'b0;
            top_state  <= TOP_IDLE;
          end
        end
      endcase
    end
  end

  kernel_loader_ctrl #(
    .SIZE      (SIZE),
    .REG_WIDTH (REG_WIDTH)
  ) u_ctrl (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .cfg_valid             (cfg_valid),
    .cfg_k                 (cfg_k),
    .cfg_n                 (cfg_n),
    .cfg_m                 (cfg_m),
    .cfg_rhs_base          (cfg_rhs_base),
    .cfg_rhs_row_stride_b  (cfg_rhs_row_stride_b),
    .cfg_rhs_zp            (cfg_rhs_zp),
    .cfg_use_16bits        (cfg_use_16bits),
    .cfg_ia_reuse_num      (cfg_ia_reuse_num),
    .cfg_w_reuse_num       (cfg_w_reuse_num),
    .load_weight_granted   (load_weight_granted),
    .send_weight_trigger    (send_weight_trigger),
    .buf_weight_data_valid  (weight_data_valid),
    .buf_weight_sending_done(weight_sending_done),
    .load_weight_req       (load_weight_req),
    .dma_start             (dma_start),
    .dma_tile_base_addr    (dma_tile_base_addr),
    .dma_rows_to_read      (dma_rows_to_read),
    .dma_row_stride_b      (dma_row_stride_b),
    .dma_valid_cols        (dma_valid_cols),
    .dma_rhs_zp            (dma_rhs_zp),
    .buf_load_start        (buf_load_start),
    .buf_send_start        (buf_send_start),
    .ctrl_all_done         (ctrl_all_done),
    .tile_row_dbg          (),
    .tile_col_dbg          (),
    .repeat_dbg            ()
  );

	  generate
	    if (EXTERNAL_DMA) begin : gen_external_dma
	      logic signed [DATA_WIDTH-1:0] row_acc [SIZE];
	      logic signed [DATA_WIDTH-1:0] row_acc_n [SIZE];
	      logic signed [DATA_WIDTH-1:0] row_emit [SIZE];
	      logic signed [DATA_WIDTH-1:0] row_emit_n [SIZE];
	      logic row_valid_pending;
	      logic [$clog2(SIZE)-1:0] row_idx_pending;
	      logic ext_done_q;
	      logic beat_valid;
	      logic last_ext_beat;

	      always_comb begin
	        beat_valid = 1'b0;
	        for (int i = 0; i < BYTE_PER_BEAT; i++) begin
	          beat_valid |= ext_dma_wr_valid[i];
	        end
	        last_ext_beat = beat_valid &&
	          ((REG_WIDTH'(ext_dma_wr_col_base) + dma_elems_per_beat) >= dma_valid_cols);
	        for (int c = 0; c < SIZE; c++) begin
	          row_acc_n[c] = row_acc[c];
	          row_emit_n[c] = row_acc[c];
	        end
	        if (dma_start) begin
	          for (int c = 0; c < SIZE; c++) begin
	            row_acc_n[c] = '0;
	            row_emit_n[c] = '0;
	          end
	        end
	        if (beat_valid) begin
	          for (int i = 0; i < BYTE_PER_BEAT; i++) begin
	            automatic int col;
	            col = int'(ext_dma_wr_col_base) + i;
	            if (ext_dma_wr_valid[i] && col < SIZE && REG_WIDTH'(col) < dma_valid_cols) begin
	              row_emit_n[col] = ext_dma_wr_data[i];
	              if (!last_ext_beat) row_acc_n[col] = ext_dma_wr_data[i];
	            end
	          end
	          if (last_ext_beat) begin
	            for (int c = 0; c < SIZE; c++) begin
	              row_acc_n[c] = '0;
	            end
	          end
	        end
	      end

	      always_ff @(posedge clk or negedge rst_n) begin
	        if (!rst_n) begin
	          dma_busy <= 1'b0;
	          dma_done <= 1'b0;
	          dma_row_valid <= 1'b0;
	          dma_row_idx <= '0;
	          row_valid_pending <= 1'b0;
	          row_idx_pending <= '0;
	          ext_done_q <= 1'b0;
	          for (int c = 0; c < SIZE; c++) begin
	            row_acc[c] <= '0;
	            row_emit[c] <= '0;
	            dma_row_data[c] <= '0;
	          end
	        end else begin
	          dma_busy <= ext_dma_busy;
	          ext_done_q <= ext_dma_done;
	          dma_done <= ext_done_q;
	          dma_row_valid <= row_valid_pending;
	          if (row_valid_pending) begin
	            dma_row_idx <= row_idx_pending;
	            for (int c = 0; c < SIZE; c++) begin
	              dma_row_data[c] <= row_emit[c];
	            end
	          end
	          row_valid_pending <= 1'b0;
	          for (int c = 0; c < SIZE; c++) begin
	            row_acc[c] <= row_acc_n[c];
	          end
	          if (last_ext_beat) begin
	            row_valid_pending <= 1'b1;
	            row_idx_pending <= ext_dma_wr_row;
	            for (int c = 0; c < SIZE; c++) begin
	              row_emit[c] <= row_emit_n[c];
	            end
	          end
	        end
	      end

	      assign icb_cmd_valid = 1'b0;
	      assign icb_cmd_read  = 1'b1;
	      assign icb_cmd_addr  = '0;
	      assign icb_cmd_len   = '0;
	      assign icb_rsp_ready = 1'b0;
	    end else begin : gen_internal_dma
	      kernel_block_dma #(
	        .DATA_WIDTH (DATA_WIDTH),
	        .SIZE       (SIZE),
	        .BUS_WIDTH  (BUS_WIDTH),
	        .REG_WIDTH  (REG_WIDTH)
	      ) u_dma (
	        .clk            (clk),
	        .rst_n          (rst_n),
	        .start          (dma_start),
	        .tile_base_addr (dma_tile_base_addr),
	        .row_stride_b   (dma_row_stride_b),
	        .rows_to_read   (dma_rows_to_read),
	        .valid_cols     (dma_valid_cols),
	        .rhs_zp         (dma_rhs_zp),
	        .use_16bits     (cfg_use_16bits),
	        .busy           (dma_busy),
	        .done           (dma_done),
	        .row_valid      (dma_row_valid),
	        .row_idx        (dma_row_idx),
	        .row_data       (dma_row_data),
	        .icb_cmd_valid  (icb_cmd_valid),
	        .icb_cmd_ready  (icb_cmd_ready),
	        .icb_cmd_read   (icb_cmd_read),
	        .icb_cmd_addr   (icb_cmd_addr),
	        .icb_cmd_len    (icb_cmd_len),
	        .icb_rsp_valid  (icb_rsp_valid),
	        .icb_rsp_ready  (icb_rsp_ready),
	        .icb_rsp_rdata  (icb_rsp_rdata),
	        .icb_rsp_err    (icb_rsp_err)
	      );
	    end
	  endgenerate

  kernel_loader_buffer #(
    .DATA_WIDTH (DATA_WIDTH),
    .SIZE       (SIZE)
  ) u_buf (
    .clk                 (clk),
    .rst_n               (rst_n),
    .load_start          (buf_load_start),
    .row_valid           (dma_row_valid),
    .row_idx             (dma_row_idx),
    .row_data            (dma_row_data),
    .load_done           (dma_done),
    .send_start          (buf_send_start),
    .weight_data_valid   (weight_data_valid),
    .weight_sending_done (weight_sending_done),
    .store_weight_req    (store_weight_req),
    .weight_out          (weight_out)
  );

endmodule
