module ps_buffer #(
    parameter int unsigned SIZE       = 16,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned FRAME_COUNT = SIZE,
    parameter int unsigned MAX_IA_REUSE = 2
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic signed [DATA_WIDTH-1:0] data_in       [0:SIZE-1],
    input  logic                         ia_row_valid,
    input  logic                         ia_calc_done,
    input  logic                         ia_tile_start,
    input  logic                         ia_l1_switch,
    input  logic                         send_ia_trigger,
    input  logic                         ia_is_init_data,
    input  logic                         replay_enable,
    output logic signed [DATA_WIDTH-1:0] data_out      [0:SIZE-1],
    output logic signed [DATA_WIDTH-1:0] acc_data_out  [0:SIZE-1],
    output logic                         acc_data_valid,
    output logic                         tile_calc_over,
    output logic                         stream_calc_over
);
    localparam int unsigned MAX_FRAME_LEN = ((MAX_IA_REUSE + 1) * SIZE) - 1;
    // Store at most FRAME_COUNT reusable partial-sum frames, but keep one
    // extra max-sized frame worth of storage so a newly generated frame never
    // overwrites the frame that is being replayed in the same L1 pass.
    localparam int unsigned DEPTH = MAX_FRAME_LEN * (FRAME_COUNT + 1);
    localparam int unsigned FIFO_VEC_WIDTH = DATA_WIDTH * SIZE;

    logic signed [DATA_WIDTH-1:0] fifo_data_out    [0:SIZE-1];
    logic signed [DATA_WIDTH-1:0] de_diag_data_out [0:SIZE-1];
    logic [FIFO_VEC_WIDTH-1:0]    fifo_data_in_vec;
    logic [FIFO_VEC_WIDTH-1:0]    fifo_data_out_vec;

    logic                         de_diag_data_valid;
    logic                         de_diag_tile_calc_over;
    logic                         de_diag_stream_calc_over;

    always_comb begin
        fifo_data_in_vec = '0;
        for (int lane_idx = 0; lane_idx < SIZE; lane_idx++) begin
            fifo_data_in_vec[lane_idx*DATA_WIDTH +: DATA_WIDTH] = data_in[lane_idx];
            fifo_data_out[lane_idx] = fifo_data_out_vec[lane_idx*DATA_WIDTH +: DATA_WIDTH];
        end
    end

    ps_buffer_wide_fifo #(
        .DEPTH      (DEPTH),
        .DATA_WIDTH (FIFO_VEC_WIDTH),
        .FRAME_COUNT(FRAME_COUNT)
    ) u_ps_buffer_fifo (
        .clk              (clk),
        .rst_n            (rst_n),
        .data_in          (fifo_data_in_vec),
        .input_valid_i    (ia_row_valid & ~ia_calc_done),
        .ia_l1_switch_i   (ia_l1_switch),
        .send_ia_trigger_i(send_ia_trigger),
        .replay_enable_i  (replay_enable),
        .data_out         (fifo_data_out_vec)
    );

    de_diagonalizer #(
        .SIZE      (SIZE),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_de_diagonalizer (
        .clk             (clk),
        .rst_n           (rst_n),
        .data_in         (data_in),
        .input_valid_i   (ia_calc_done),
        .burst_start_i   (ia_tile_start),
        .burst_last_i    (ia_l1_switch),
        .data_out        (de_diag_data_out),
        .data_valid_o    (de_diag_data_valid),
        .tile_calc_over_o(de_diag_tile_calc_over),
        .stream_calc_over_o(de_diag_stream_calc_over)
    );

    always_comb begin
        for (int lane_idx = 0; lane_idx < SIZE; lane_idx++) begin
            data_out[lane_idx]     = fifo_data_out[lane_idx];
            acc_data_out[lane_idx] = de_diag_data_out[lane_idx];
        end
    end

    // acc_data_valid and tile_calc_over are owned only by de_diagonalizer.
    assign acc_data_valid = de_diag_data_valid;
    assign tile_calc_over = de_diag_tile_calc_over;
    assign stream_calc_over = de_diag_stream_calc_over;
endmodule

module ps_buffer_wide_fifo #(
    parameter int unsigned DEPTH       = 16,
    parameter int unsigned DATA_WIDTH  = 512,
    parameter int unsigned FRAME_COUNT = 1
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  input_valid_i,
    input  logic                  ia_l1_switch_i,
    input  logic                  send_ia_trigger_i,
    input  logic                  replay_enable_i,
    output logic [DATA_WIDTH-1:0] data_out
);
    localparam int unsigned ADDR_W      = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam int unsigned CNT_W       = (DEPTH <= 1) ? 1 : $clog2(DEPTH + 1);
    localparam int unsigned FRAME_IDX_W = (FRAME_COUNT <= 1) ? 1 : $clog2(FRAME_COUNT);
    localparam int unsigned FRAME_CNT_W = (FRAME_COUNT < 1) ? 1 : $clog2(FRAME_COUNT + 1);
    localparam int unsigned EXT_W       = CNT_W + 1;

    localparam logic [ADDR_W-1:0]      DEPTH_LAST_ADDR = ADDR_W'(DEPTH - 1);
    localparam logic [CNT_W-1:0]       DEPTH_COUNT     = CNT_W'(DEPTH);
    localparam logic [FRAME_CNT_W-1:0] FRAME_COUNT_C   = FRAME_CNT_W'(FRAME_COUNT);

    logic [ADDR_W-1:0]      write_ptr;
    logic [ADDR_W-1:0]      read_ptr;
    logic [ADDR_W-1:0]      write_base;
    logic [ADDR_W-1:0]      read_base;
    logic [CNT_W-1:0]       frame_len;
    logic [CNT_W-1:0]       frame_len_fifo [FRAME_COUNT];
    logic [FRAME_IDX_W-1:0] frame_wr_ptr;
    logic [FRAME_IDX_W-1:0] frame_rd_ptr;
    logic [FRAME_CNT_W-1:0] frame_count;
    logic [CNT_W-1:0]       replay_count;
    logic                   ia_l1_switch_i_d;
    logic                   send_ia_trigger_i_d;

    logic                   ram_write_en;
    logic                   ram_read_en;
    logic [ADDR_W-1:0]      ram_write_addr;
    logic [ADDR_W-1:0]      ram_read_addr;
    logic [CNT_W-1:0]       write_ptr_ext;
    logic [CNT_W-1:0]       frame_len_next;
    logic [DATA_WIDTH-1:0]  ram_read_data;
    logic                   replay_data_valid;
    logic [CNT_W:0]         ram_write_addr_ext;
    logic [CNT_W:0]         write_base_next_ext;
    logic [CNT_W:0]         read_base_next_ext;
    logic [ADDR_W-1:0]      write_base_next;
    logic [ADDR_W-1:0]      read_base_next;
    logic [ADDR_W-1:0]      read_ptr_inc;
    logic [FRAME_IDX_W-1:0] frame_wr_ptr_inc;
    logic [FRAME_IDX_W-1:0] frame_rd_ptr_inc;

`ifndef SYNTHESIS
    bit ps_trace_en;

    initial begin
        ps_trace_en = 1'b0;
        if ($test$plusargs("MMA_PS_TRACE")) ps_trace_en = 1'b1;
    end
`else
    localparam bit ps_trace_en = 1'b0;
`endif

    assign ram_write_en   = input_valid_i;
    assign ram_read_en    = (replay_count != '0);
    assign ram_read_addr  = read_ptr;
    assign write_ptr_ext  = write_ptr;
    assign frame_len_next = input_valid_i ? (write_ptr_ext + 1'b1) : write_ptr_ext;
    assign frame_len      = (frame_count != '0) ? frame_len_fifo[frame_rd_ptr] : '0;

    assign ram_write_addr_ext = EXT_W'(write_base) + EXT_W'(write_ptr);
    assign write_base_next_ext = EXT_W'(write_base) + EXT_W'(frame_len_next);
    assign read_base_next_ext = EXT_W'(read_base) + EXT_W'(frame_len);
    assign ram_write_addr = (ram_write_addr_ext >= EXT_W'(DEPTH_COUNT)) ?
                            ADDR_W'(ram_write_addr_ext - EXT_W'(DEPTH_COUNT)) :
                            ADDR_W'(ram_write_addr_ext);
    assign write_base_next = (write_base_next_ext >= EXT_W'(DEPTH_COUNT)) ?
                             ADDR_W'(write_base_next_ext - EXT_W'(DEPTH_COUNT)) :
                             ADDR_W'(write_base_next_ext);
    assign read_base_next = (read_base_next_ext >= EXT_W'(DEPTH_COUNT)) ?
                            ADDR_W'(read_base_next_ext - EXT_W'(DEPTH_COUNT)) :
                            ADDR_W'(read_base_next_ext);
    assign read_ptr_inc = (read_ptr == DEPTH_LAST_ADDR) ? '0 : (read_ptr + 1'b1);
    assign frame_wr_ptr_inc = (FRAME_COUNT <= 1) ? '0 :
                              ((frame_wr_ptr == FRAME_IDX_W'(FRAME_COUNT - 1)) ?
                               '0 : (frame_wr_ptr + 1'b1));
    assign frame_rd_ptr_inc = (FRAME_COUNT <= 1) ? '0 :
                              ((frame_rd_ptr == FRAME_IDX_W'(FRAME_COUNT - 1)) ?
                               '0 : (frame_rd_ptr + 1'b1));

    assign data_out = replay_data_valid ? ram_read_data : '0;

    pseudo_dual_port_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH (ADDR_W)
    ) u_ps_fifo_ram (
        .clk   (clk),
        .ena   (1'b1),
        .enb   (ram_read_en),
        .wea   (ram_write_en),
        .addra (ram_write_addr),
        .dia   (data_in),
        .addrb (ram_read_addr),
        .dob   (ram_read_data)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr           <= '0;
            read_ptr            <= '0;
            write_base          <= '0;
            read_base           <= '0;
            frame_wr_ptr        <= '0;
            frame_rd_ptr        <= '0;
            frame_count         <= '0;
            replay_count        <= '0;
            ia_l1_switch_i_d    <= 1'b0;
            send_ia_trigger_i_d <= 1'b0;
            replay_data_valid   <= 1'b0;
            for (int frame_i = 0; frame_i < FRAME_COUNT; frame_i++) begin
                frame_len_fifo[frame_i] <= '0;
            end
        end else begin
            logic push_frame;
            logic pop_frame;

            push_frame = ia_l1_switch_i && !ia_l1_switch_i_d && (frame_len_next != '0);
            pop_frame  = send_ia_trigger_i && !send_ia_trigger_i_d &&
                         replay_enable_i && (frame_count != '0) &&
                         (replay_count == '0);

            ia_l1_switch_i_d    <= ia_l1_switch_i;
            send_ia_trigger_i_d <= send_ia_trigger_i;
            replay_data_valid   <= ram_read_en;

            if (input_valid_i) begin
                write_ptr <= write_ptr + 1'b1;
            end

            if (ia_l1_switch_i && !ia_l1_switch_i_d) begin
                if (frame_len_next != '0) begin
                    frame_len_fifo[frame_wr_ptr] <= frame_len_next;
                    frame_wr_ptr <= frame_wr_ptr_inc;
                    write_base   <= write_base_next;
                    if (ps_trace_en) begin
                        $display("[PS_TRACE] time=%0t push frame_len=%0d frame_count=%0d write_base=%0d",
                                 $time, frame_len_next, frame_count, write_base);
                    end
                end
                write_ptr    <= '0;
                replay_count <= '0;
            end

            if (send_ia_trigger_i && !send_ia_trigger_i_d) begin
                if (pop_frame) begin
                    read_ptr     <= read_base;
                    read_base    <= read_base_next;
                    replay_count <= frame_len;
                    frame_rd_ptr <= frame_rd_ptr_inc;
                    if (ps_trace_en) begin
                        $display("[PS_TRACE] time=%0t pop frame_len=%0d frame_count=%0d read_base=%0d",
                                 $time, frame_len, frame_count, read_base);
                    end
                end else if (ps_trace_en && (replay_count != '0)) begin
                    $display("[PS_TRACE] time=%0t ignore trigger replay_count=%0d frame_count=%0d",
                             $time, replay_count, frame_count);
                end
            end

            if (!push_frame && !pop_frame && (replay_count != '0)) begin
                if (replay_count == 1) begin
                    replay_count <= '0;
                end else begin
                    replay_count <= replay_count - 1'b1;
                    read_ptr     <= read_ptr_inc;
                end
            end

            if (push_frame && !pop_frame) begin
                if (frame_count < FRAME_COUNT_C) begin
                    frame_count <= frame_count + 1'b1;
                end
            end else if (!push_frame && pop_frame) begin
                frame_count <= frame_count - 1'b1;
            end
        end
    end
endmodule
