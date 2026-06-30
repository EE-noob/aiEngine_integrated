module ps_buffer_fifo #(
    parameter int unsigned DEPTH      = 16,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned FRAME_COUNT = 1
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic signed [DATA_WIDTH-1:0] data_in,
    input  logic                         input_valid_i,
    input  logic                         is_init_data_i,
    input  logic                         ia_l1_switch_i,
    input  logic                         send_ia_trigger_i,
    input  logic                         replay_enable_i,
    output logic signed [DATA_WIDTH-1:0] data_out,
    output logic                         input_valid_o,
    output logic                         is_init_data_o,
    output logic                         ia_l1_switch_o,
    output logic                         send_ia_trigger_o
);
    localparam int unsigned ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam int unsigned CNT_W  = (DEPTH <= 1) ? 1 : $clog2(DEPTH + 1);
    localparam int unsigned FRAME_IDX_W = (FRAME_COUNT <= 1) ? 1 : $clog2(FRAME_COUNT);
    localparam int unsigned FRAME_CNT_W = (FRAME_COUNT < 1) ? 1 : $clog2(FRAME_COUNT + 1);

    localparam logic [ADDR_W-1:0] DEPTH_LAST_ADDR = DEPTH - 1;
    localparam logic [CNT_W-1:0]  DEPTH_COUNT     = DEPTH;
    localparam logic [FRAME_CNT_W-1:0] FRAME_COUNT_C = FRAME_CNT_W'(FRAME_COUNT);

    logic [ADDR_W-1:0]             write_ptr;
    logic [ADDR_W-1:0]             read_ptr;
    logic [ADDR_W-1:0]             write_base;
    logic [ADDR_W-1:0]             read_base;
    logic [CNT_W-1:0]              frame_len;
    logic [CNT_W-1:0]              frame_len_fifo [FRAME_COUNT];
    logic [FRAME_IDX_W-1:0]        frame_wr_ptr;
    logic [FRAME_IDX_W-1:0]        frame_rd_ptr;
    logic [FRAME_CNT_W-1:0]        frame_count;
    logic [CNT_W-1:0]              replay_count;
    logic                         ia_l1_switch_i_d;
    logic                         send_ia_trigger_i_d;

    logic                         ram_write_en;
    logic                         ram_read_en;
    logic [ADDR_W-1:0]             ram_write_addr;
    logic [ADDR_W-1:0]             ram_read_addr;
    logic [CNT_W-1:0]              write_ptr_ext;
    logic [CNT_W-1:0]              frame_len_next;
    logic signed [DATA_WIDTH-1:0] ram_read_data;
    logic                         replay_data_valid;
    bit                           ps_trace_en;

    initial begin
        ps_trace_en = 1'b0;
        if ($test$plusargs("MMA_PS_TRACE")) ps_trace_en = 1'b1;
    end

    assign ram_write_en   = input_valid_i;
    assign ram_read_en    = (replay_count != '0);
    assign ram_write_addr = add_mod_depth(write_base, write_ptr);
    assign ram_read_addr  = read_ptr;
    assign write_ptr_ext  = write_ptr;
    assign frame_len_next = input_valid_i ? (write_ptr_ext + 1'b1) : write_ptr_ext;
    assign frame_len      = (frame_count != '0) ? frame_len_fifo[frame_rd_ptr] : '0;

    // RAM read data is valid in the same externally-observed cycle as
    // replay_data_valid because both are registered on the same clock edge.
    assign data_out = replay_data_valid ? ram_read_data : '0;

    pseudo_dual_port_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_W)
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

    function automatic logic [ADDR_W-1:0] add_mod_depth(
        input logic [ADDR_W-1:0] base,
        input logic [CNT_W-1:0]  offset
    );
        logic [CNT_W:0] next_ext;
        begin
            next_ext = CNT_W'(base) + offset;
            if (next_ext >= DEPTH_COUNT) begin
                next_ext = next_ext - DEPTH_COUNT;
            end
            add_mod_depth = next_ext[ADDR_W-1:0];
        end
    endfunction

    function automatic logic [ADDR_W-1:0] inc_mod_depth(input logic [ADDR_W-1:0] addr);
        begin
            inc_mod_depth = (addr == DEPTH_LAST_ADDR) ? '0 : (addr + 1'b1);
        end
    endfunction

    function automatic logic [FRAME_IDX_W-1:0] inc_frame_ptr(input logic [FRAME_IDX_W-1:0] ptr);
        begin
            if (FRAME_COUNT <= 1) begin
                inc_frame_ptr = '0;
            end else if (ptr == FRAME_IDX_W'(FRAME_COUNT - 1)) begin
                inc_frame_ptr = '0;
            end else begin
                inc_frame_ptr = ptr + 1'b1;
            end
        end
    endfunction

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
            input_valid_o       <= 1'b0;
            is_init_data_o      <= 1'b0;
            ia_l1_switch_o      <= 1'b0;
            send_ia_trigger_o   <= 1'b0;
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

            input_valid_o       <= input_valid_i;
            is_init_data_o      <= is_init_data_i;
            ia_l1_switch_o      <= ia_l1_switch_i;
            send_ia_trigger_o   <= send_ia_trigger_i;

            // Align external data_out masking with the synchronous RAM read.
            replay_data_valid <= ram_read_en;

            if (input_valid_i) begin
                write_ptr <= write_ptr + 1'b1;
            end

            if (ia_l1_switch_i && !ia_l1_switch_i_d) begin
                if (frame_len_next != '0) begin
                    frame_len_fifo[frame_wr_ptr] <= frame_len_next;
                    frame_wr_ptr <= inc_frame_ptr(frame_wr_ptr);
                    write_base <= add_mod_depth(write_base, frame_len_next);
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
                    read_base    <= add_mod_depth(read_base, frame_len);
                    replay_count <= frame_len;
                    frame_rd_ptr <= inc_frame_ptr(frame_rd_ptr);
                    if (ps_trace_en) begin
                        $display("[PS_TRACE] time=%0t pop frame_len=%0d frame_count=%0d read_base=%0d",
                                 $time, frame_len, frame_count, read_base);
                    end
                end else if (ps_trace_en && (replay_count != '0)) begin
                    $display("[PS_TRACE] time=%0t ignore trigger replay_count=%0d frame_count=%0d",
                             $time, replay_count, frame_count);
                end
            end else if (replay_count != '0) begin
                if (replay_count == 1) begin
                    replay_count <= '0;
                end else begin
                    replay_count <= replay_count - 1'b1;
                    read_ptr     <= inc_mod_depth(read_ptr);
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
