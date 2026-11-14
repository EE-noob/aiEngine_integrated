// Linear output FIFO for TFLM int16 activations.  A 32-bit AXI beat carries
// two little-endian s16 elements.
module vec_s16_to_fifo #(
    parameter int unsigned VLEN  = 16,
    parameter int unsigned BANKS = 16
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         in_valid,
    input  logic                         in_tile_done,
    input  logic [VLEN*16-1:0]           in_vec_s16,
    output logic                         oa_fifo_req,
    input  logic [31:0]                  reserve_banks,
    input  logic [$clog2(VLEN)-1:0]      vec_valid_num_col,
    output logic                         output_valid,
    input  logic                         output_ready,
    output logic                         output_row_switch,
    output logic [3:0]                   output_mask,
    output logic [31:0]                  output_data,
    output logic                         fifo_full_flag
);

    localparam int PTR_WIDTH = (VLEN <= 1) ? 1 : $clog2(VLEN);
    localparam int COUNT_WIDTH = $clog2(VLEN + 1);
    localparam int ROW_BEATS = (VLEN + 1) >> 1;
    localparam int BEAT_WIDTH = (ROW_BEATS <= 1) ? 1 : $clog2(ROW_BEATS);
    localparam int BANK_WIDTH = (BANKS <= 1) ? 1 : $clog2(BANKS);
    localparam int BANK_COUNT_WIDTH = (BANKS <= 1) ? 1 : $clog2(BANKS + 1);
    localparam int MEM_DEPTH = BANKS * VLEN;
    localparam int MEM_ADDR_W = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH);

    logic [COUNT_WIDTH-1:0] bank_count[0:BANKS-1];
    logic [BANKS-1:0] bank_ready;
    logic [BANK_COUNT_WIDTH-1:0] ready_bank_count_q;
    logic [COUNT_WIDTH-1:0] active_read_count_q;
    logic [BANK_WIDTH-1:0] write_bank;
    logic [BANK_WIDTH-1:0] read_bank;
    logic [PTR_WIDTH-1:0] write_ptr;
    logic [PTR_WIDTH-1:0] read_ptr;
    logic [BEAT_WIDTH-1:0] beat_idx;
    logic [$clog2(VLEN)-1:0] vec_valid_num_col_q;
    logic stream_active;
    logic data_valid;
    logic ram_read_valid_q;
    logic [VLEN*16-1:0] ram_rd_data;
    logic [MEM_ADDR_W-1:0] ram_wr_addr;
    logic [MEM_ADDR_W-1:0] ram_rd_addr;
    logic [PTR_WIDTH-1:0] next_read_row;
    logic [BANK_COUNT_WIDTH-1:0] reserve_bank_count;
    logic [BANK_COUNT_WIDTH-1:0] used_bank_count;
    logic [BANK_COUNT_WIDTH-1:0] free_bank_count;
`ifndef SYNTHESIS
    bit oa_trace_en;
`else
    localparam bit oa_trace_en = 1'b0;
`endif

    function automatic logic [BANK_WIDTH-1:0] next_bank(
        input logic [BANK_WIDTH-1:0] bank
    );
        if (bank == BANK_WIDTH'(BANKS - 1)) next_bank = '0;
        else next_bank = bank + 1'b1;
    endfunction

    wire write_bank_blocked = bank_ready[write_bank];
    wire next_write_bank_blocked = bank_ready[next_bank(write_bank)];
    wire finish_write_bank = in_valid && in_tile_done;
    wire [COUNT_WIDTH-1:0] write_rows_next =
        in_valid ? COUNT_WIDTH'(write_ptr + 1'b1) : COUNT_WIDTH'(write_ptr);
    wire read_bank_ready = bank_ready[read_bank] && (bank_count[read_bank] != '0);
    wire start_stream = !stream_active && read_bank_ready;
    wire [COUNT_WIDTH-1:0] output_col_count =
        COUNT_WIDTH'(vec_valid_num_col_q) + COUNT_WIDTH'(1);
    wire [COUNT_WIDTH-1:0] last_beat_idx_cur =
        (output_col_count == '0) ? '0 : ((output_col_count - 1'b1) >> 1);
    wire output_fire = output_ready && output_valid;
    wire last_beat_in_row = output_fire &&
        (COUNT_WIDTH'(beat_idx) == last_beat_idx_cur);
    wire last_row_in_bank = last_beat_in_row &&
        ((COUNT_WIDTH'(read_ptr) + 1'b1) >= active_read_count_q);
    wire read_next_row = last_beat_in_row && !last_row_in_bank;
    wire ram_read_en = start_stream || read_next_row;

    assign output_valid = stream_active && data_valid;
    assign output_row_switch = last_beat_in_row;

    always_comb begin
        reserve_bank_count = (reserve_banks == 0) ? BANK_COUNT_WIDTH'(1) :
                             (reserve_banks >= 32'(BANKS)) ? BANK_COUNT_WIDTH'(BANKS) :
                             BANK_COUNT_WIDTH'(reserve_banks);
        used_bank_count = ready_bank_count_q +
                          ((write_ptr != '0) ? BANK_COUNT_WIDTH'(1) : '0);
        free_bank_count = (used_bank_count >= BANK_COUNT_WIDTH'(BANKS)) ? '0 :
                          (BANK_COUNT_WIDTH'(BANKS) - used_bank_count);
        fifo_full_flag = write_bank_blocked || next_write_bank_blocked ||
                         (free_bank_count < reserve_bank_count);

        next_read_row = start_stream ? '0 : (read_ptr + 1'b1);
        ram_wr_addr = MEM_ADDR_W'((int'(write_bank) * VLEN) + int'(write_ptr));
        ram_rd_addr = MEM_ADDR_W'((int'(read_bank) * VLEN) + int'(next_read_row));

        output_data = 32'b0;
        output_mask = 4'b0;
        if (stream_active && data_valid) begin
            output_data = ram_rd_data[int'(beat_idx)*32 +: 32];
            if ((COUNT_WIDTH'(beat_idx) << 1) + COUNT_WIDTH'(2) <= output_col_count) begin
                output_mask = 4'b1111;
            end else begin
                output_mask = 4'b0011;
            end
        end
    end

    vec_s8_fifo_row_ram #(
        .DATA_WIDTH(VLEN * 16),
        .DEPTH(MEM_DEPTH),
        .ADDR_WIDTH(MEM_ADDR_W)
    ) u_ram (
        .clk(clk),
        .wr_en(in_valid && !write_bank_blocked),
        .wr_addr(ram_wr_addr),
        .wr_data(in_vec_s16),
        .rd_en(ram_read_en),
        .rd_addr(ram_rd_addr),
        .rd_data(ram_rd_data)
    );

`ifndef SYNTHESIS
    initial begin
        oa_trace_en = 1'b0;
        if ($test$plusargs("NPU_OA_TRACE")) oa_trace_en = 1'b1;
    end
`endif

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            write_bank <= '0;
            read_bank <= '0;
            write_ptr <= '0;
            read_ptr <= '0;
            beat_idx <= '0;
            vec_valid_num_col_q <= '0;
            stream_active <= 1'b0;
            data_valid <= 1'b0;
            ram_read_valid_q <= 1'b0;
            oa_fifo_req <= 1'b0;
            bank_ready <= '0;
            ready_bank_count_q <= '0;
            active_read_count_q <= '0;
            for (int bank_idx = 0; bank_idx < BANKS; bank_idx++) begin
                bank_count[bank_idx] <= '0;
            end
        end else begin
            oa_fifo_req <= read_bank_ready && !stream_active;
            ram_read_valid_q <= ram_read_en;

            if (finish_write_bank && !write_bank_blocked) begin
                bank_count[write_bank] <= write_rows_next;
                bank_ready[write_bank] <= 1'b1;
                write_ptr <= '0;
                write_bank <= next_bank(write_bank);
                if (!last_row_in_bank) ready_bank_count_q <= ready_bank_count_q + 1'b1;
                if (oa_trace_en) begin
                    $display("[OA16_TRACE] time=%0t fifo_bank_ready bank=%0d rows=%0d vcol=%0d",
                             $time, write_bank, write_rows_next, vec_valid_num_col);
                end
            end else if (in_valid && !write_bank_blocked) begin
                write_ptr <= write_ptr + 1'b1;
            end

            if (start_stream) begin
                stream_active <= 1'b1;
                data_valid <= 1'b0;
                read_ptr <= '0;
                beat_idx <= '0;
                active_read_count_q <= bank_count[read_bank];
                vec_valid_num_col_q <= vec_valid_num_col;
                if (oa_trace_en) begin
                    $display("[OA16_TRACE] time=%0t fifo_stream_start bank=%0d rows=%0d vcol=%0d",
                             $time, read_bank, bank_count[read_bank], vec_valid_num_col);
                end
            end else if (stream_active && !data_valid && ram_read_valid_q) begin
                data_valid <= 1'b1;
            end else if (stream_active && (read_ptr == '0) &&
                         (beat_idx == '0) && !output_ready) begin
                // A ready bank can be selected before oa_writer advances to
                // that tile. Keep its tail-column metadata synchronized until
                // the first beat is actually accepted.
                vec_valid_num_col_q <= vec_valid_num_col;
            end else if (output_fire) begin
                if (last_row_in_bank) begin
                    stream_active <= 1'b0;
                    data_valid <= 1'b0;
                    read_ptr <= '0;
                    beat_idx <= '0;
                    active_read_count_q <= '0;
                    bank_ready[read_bank] <= 1'b0;
                    bank_count[read_bank] <= '0;
                    read_bank <= next_bank(read_bank);
                    if (!(finish_write_bank && !write_bank_blocked)) begin
                        ready_bank_count_q <= ready_bank_count_q - 1'b1;
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

    always_ff @(posedge clk) begin
        if (rst_n && oa_trace_en && output_valid && output_ready) begin
            $display("[OA16_TRACE] time=%0t fifo_out bank=%0d row=%0d beat=%0d mask=%b data=%08x rows=%0d cols=%0d",
                     $time, read_bank, read_ptr, beat_idx, output_mask,
                     output_data, active_read_count_q, output_col_count);
        end
    end

endmodule
