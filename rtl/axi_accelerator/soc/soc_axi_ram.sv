module soc_axi_ram #(
    parameter int unsigned DP = 512,
    parameter int unsigned DW = 32,
    parameter int unsigned AW = 32,
    parameter string       MEM_PATH = "",
    parameter int unsigned INIT_EN = 0,
    parameter int unsigned READ_OUTSTANDING = 4,
    parameter int unsigned WRITE_OUTSTANDING = READ_OUTSTANDING
) (
    input  wire             clk,
    input  wire             rst_n,

    input  wire             s_axi_awvalid,
    output wire             s_axi_awready,
    input  wire [AW-1:0]    s_axi_awaddr,
    input  wire [3:0]       s_axi_awcache,
    input  wire [2:0]       s_axi_awprot,
    input  wire [1:0]       s_axi_awlock,
    input  wire [1:0]       s_axi_awburst,
    input  wire [7:0]       s_axi_awlen,
    input  wire [2:0]       s_axi_awsize,

    input  wire             s_axi_wvalid,
    output wire             s_axi_wready,
    input  wire [DW-1:0]    s_axi_wdata,
    input  wire [DW/8-1:0]  s_axi_wstrb,
    input  wire             s_axi_wlast,

    output logic            s_axi_bvalid,
    input  wire             s_axi_bready,
    output logic [1:0]      s_axi_bresp,

    input  wire             s_axi_arvalid,
    output wire             s_axi_arready,
    input  wire [AW-1:0]    s_axi_araddr,
    input  wire [3:0]       s_axi_arcache,
    input  wire [2:0]       s_axi_arprot,
    input  wire [1:0]       s_axi_arlock,
    input  wire [1:0]       s_axi_arburst,
    input  wire [7:0]       s_axi_arlen,
    input  wire [2:0]       s_axi_arsize,

    output logic            s_axi_rvalid,
    input  wire             s_axi_rready,
    output logic [DW-1:0]   s_axi_rdata,
    output logic [1:0]      s_axi_rresp,
    output logic            s_axi_rlast,

    input  wire             mem_reload_req
);

    localparam int unsigned BYTEW = DW / 8;
    localparam int unsigned ADDR_LSB = (BYTEW <= 1) ? 0 : $clog2(BYTEW);
    localparam int unsigned ADDR_BITS = (DP <= 1) ? 1 : $clog2(DP);
    localparam int unsigned WORD_ADDR_BITS = AW - ADDR_LSB;
    localparam int unsigned RD_DEPTH = (READ_OUTSTANDING < 1) ? 1 : READ_OUTSTANDING;
    localparam int unsigned WR_DEPTH = (WRITE_OUTSTANDING < 1) ? 1 : WRITE_OUTSTANDING;
    localparam int unsigned RD_PTR_W = (RD_DEPTH < 2) ? 1 : $clog2(RD_DEPTH);
    localparam int unsigned WR_PTR_W = (WR_DEPTH < 2) ? 1 : $clog2(WR_DEPTH);
    localparam int unsigned RD_CNT_W = (RD_DEPTH < 2) ? 1 : $clog2(RD_DEPTH + 1);
    localparam int unsigned WR_CNT_W = (WR_DEPTH < 2) ? 1 : $clog2(WR_DEPTH + 1);
    localparam int unsigned RD_USED_W = RD_CNT_W + 1;
    localparam int unsigned WR_USED_W = WR_CNT_W + 1;

    (* ram_style = "block" *) logic [DW-1:0] mem_r [0:DP-1];

    logic [AW-1:0] rd_addr_q [0:RD_DEPTH-1];
    logic [7:0]    rd_len_q  [0:RD_DEPTH-1];
    logic [RD_PTR_W-1:0] rd_wr_ptr_q;
    logic [RD_PTR_W-1:0] rd_rd_ptr_q;
    logic [RD_CNT_W-1:0] rd_count_q;
    logic rd_cmd_valid_q;
    logic [WORD_ADDR_BITS-1:0] rd_word_addr_q;
    logic [7:0] rd_len_active_q;
    logic [7:0] rd_beat_q;
    logic rd_error_accum_q;
    logic rd_resp_oob_q;
    logic [DW-1:0] mem_rd_data_q;

    logic [AW-1:0] wr_addr_q [0:WR_DEPTH-1];
    logic [7:0]    wr_len_q  [0:WR_DEPTH-1];
    logic [WR_PTR_W-1:0] wr_aw_wr_ptr_q;
    logic [WR_PTR_W-1:0] wr_aw_rd_ptr_q;
    logic [WR_CNT_W-1:0] wr_aw_count_q;
    logic wr_cmd_valid_q;
    logic [WORD_ADDR_BITS-1:0] wr_word_addr_q;
    logic [7:0] wr_len_active_q;
    logic [7:0] wr_beat_q;
    logic wr_error_accum_q;
`ifndef SYNTHESIS
    logic [7:0] ar_ready_delay_q;
    logic [7:0] r_rsp_delay_q;
    logic [7:0] aw_ready_delay_q;
    logic [7:0] w_ready_delay_q;
`endif

    logic [1:0] wr_b_resp_q  [0:WR_DEPTH-1];
`ifndef SYNTHESIS
    (* ram_style = "registers" *) logic [7:0] wr_b_delay_q [0:WR_DEPTH-1];
`endif
    logic [WR_PTR_W-1:0] wr_b_wr_ptr_q;
    logic [WR_PTR_W-1:0] wr_b_rd_ptr_q;
    logic [WR_CNT_W-1:0] wr_b_count_q;

`ifndef SYNTHESIS
    integer ddr_rand_lat_en;
    integer ddr_cmd_max_lat;
    integer ddr_w_max_lat;
    integer ddr_rsp_max_lat;
    integer ram_fixed_lat;
    integer data_mem_base_word_q;
    string mem_path_q;
    string data_mem_path_q;
`else
    localparam int ddr_cmd_max_lat = 0;
    localparam int ddr_w_max_lat   = 0;
    localparam int ddr_rsp_max_lat = 0;
`endif

    wire ar_fire = s_axi_arvalid && s_axi_arready;
    wire r_fire  = s_axi_rvalid  && s_axi_rready;
    wire aw_fire = s_axi_awvalid && s_axi_awready;
    wire w_fire  = s_axi_wvalid  && s_axi_wready;
    wire b_fire  = s_axi_bvalid  && s_axi_bready;

    function automatic [RD_PTR_W-1:0] inc_rd_ptr(input [RD_PTR_W-1:0] ptr);
        if (RD_DEPTH <= 1) inc_rd_ptr = '0;
        else if (ptr == RD_PTR_W'(RD_DEPTH - 1)) inc_rd_ptr = '0;
        else inc_rd_ptr = ptr + 1'b1;
    endfunction

    function automatic [WR_PTR_W-1:0] inc_wr_ptr(input [WR_PTR_W-1:0] ptr);
        if (WR_DEPTH <= 1) inc_wr_ptr = '0;
        else if (ptr == WR_PTR_W'(WR_DEPTH - 1)) inc_wr_ptr = '0;
        else inc_wr_ptr = ptr + 1'b1;
    endfunction

    function automatic [7:0] ram_response_delay(input integer max_lat);
`ifndef SYNTHESIS
        integer value;
        begin
            if (ram_fixed_lat >= 0) begin
                value = ram_fixed_lat;
                ram_response_delay = (value > 255) ? 8'hff : value[7:0];
            end else if ((ddr_rand_lat_en == 0) || (max_lat <= 0)) begin
                ram_response_delay = 8'd0;
            end else begin
                value = $urandom_range(max_lat, 0);
                ram_response_delay = (value > 255) ? 8'hff : value[7:0];
            end
        end
`else
        ram_response_delay = 8'd0;
`endif
    endfunction

    function automatic logic addr_oob(input logic [AW-1:0] byte_addr);
        if (AW > (ADDR_LSB + ADDR_BITS)) begin
            addr_oob = |byte_addr[AW-1:ADDR_LSB + ADDR_BITS];
        end else begin
            addr_oob = 1'b0;
        end
    endfunction

    function automatic logic [ADDR_BITS-1:0] word_idx(input logic [AW-1:0] byte_addr);
        word_idx = byte_addr[ADDR_LSB + ADDR_BITS - 1:ADDR_LSB];
    endfunction

`ifndef SYNTHESIS
    wire ram_rsp_delay_enabled = (ram_fixed_lat > 0) ||
                                 ((ddr_rand_lat_en != 0) && (ddr_rsp_max_lat > 0));
    wire rd_pipe_cmd_mode = !ram_rsp_delay_enabled;
    wire ar_ready_delay_clear = (ar_ready_delay_q == 8'd0);
    wire r_rsp_delay_clear = (r_rsp_delay_q == 8'd0);
    wire aw_ready_delay_clear = (aw_ready_delay_q == 8'd0);
    wire w_ready_delay_clear = (w_ready_delay_q == 8'd0);
`else
    wire rd_pipe_cmd_mode = 1'b1;
    wire ar_ready_delay_clear = 1'b1;
    wire r_rsp_delay_clear = 1'b1;
    wire aw_ready_delay_clear = 1'b1;
    wire w_ready_delay_clear = 1'b1;
`endif
    wire rd_pipe_beat = s_axi_rvalid && s_axi_rready && !s_axi_rlast;
    wire rd_pipe_cmd_base = rd_pipe_cmd_mode && s_axi_rvalid && s_axi_rready && s_axi_rlast;
    wire rd_pipe_cmd_from_queue = rd_pipe_cmd_base && (rd_count_q != '0);
    wire rd_pipe_cmd_from_ar = rd_pipe_cmd_base && (rd_count_q == '0) && ar_fire;
    wire rd_pipe_cmd = rd_pipe_cmd_from_queue || rd_pipe_cmd_from_ar;
    wire [WORD_ADDR_BITS-1:0] rd_pipe_cmd_word_addr =
        rd_pipe_cmd_from_queue ? rd_addr_q[rd_rd_ptr_q][AW-1:ADDR_LSB] :
                                 s_axi_araddr[AW-1:ADDR_LSB];
    wire [7:0] rd_pipe_cmd_len =
        rd_pipe_cmd_from_queue ? rd_len_q[rd_rd_ptr_q] : s_axi_arlen;
    wire [7:0] rd_issue_beat = rd_pipe_cmd ? 8'd0 :
                               rd_pipe_beat ? (rd_beat_q + 8'd1) : rd_beat_q;
    wire [7:0] rd_issue_len = rd_pipe_cmd ? rd_pipe_cmd_len : rd_len_active_q;
    wire [WORD_ADDR_BITS-1:0] rd_issue_word_addr =
        rd_pipe_cmd ? rd_pipe_cmd_word_addr :
        rd_pipe_beat ? (rd_word_addr_q + WORD_ADDR_BITS'(1)) : rd_word_addr_q;
    wire rd_issue_oob = (WORD_ADDR_BITS > ADDR_BITS) ?
                         |rd_issue_word_addr[WORD_ADDR_BITS-1:ADDR_BITS] : 1'b0;
    wire rd_can_issue = rd_cmd_valid_q && (!s_axi_rvalid || rd_pipe_beat || rd_pipe_cmd) &&
                        r_rsp_delay_clear;
    wire rd_issue_any = rd_can_issue || rd_pipe_cmd;
    wire rd_issue_last = (rd_issue_beat == rd_issue_len);
    wire [1:0] rd_issue_resp =
        ((rd_pipe_cmd ? 1'b0 : rd_error_accum_q) || rd_issue_oob) ? 2'b10 : 2'b00;
    // Always enable the physical BRAM read when an AXI read beat is issued.
    // Out-of-range accesses are reported with SLVERR and zeroed at the R channel,
    // so the physical address can safely wrap to the implemented depth. Keeping
    // OOB decode off the BRAM EN path avoids a long address/carry chain.
    wire mem_rd_en = rd_issue_any;
    wire [ADDR_BITS-1:0] mem_rd_addr = rd_issue_word_addr[ADDR_BITS-1:0];

    wire [RD_USED_W-1:0] rd_slots_used =
        RD_USED_W'(rd_count_q) + (rd_cmd_valid_q ? RD_USED_W'(1) : RD_USED_W'(0));
    wire [WR_USED_W-1:0] wr_aw_slots_used =
        WR_USED_W'(wr_aw_count_q) + (wr_cmd_valid_q ? WR_USED_W'(1) : WR_USED_W'(0));
    wire rd_queue_full = (rd_slots_used >= RD_USED_W'(RD_DEPTH));
    wire wr_aw_queue_full = (wr_aw_slots_used >= WR_USED_W'(WR_DEPTH));
    wire wr_b_queue_full = (wr_b_count_q == WR_CNT_W'(WR_DEPTH));
    wire wr_b_pop = b_fire;
    wire wr_has_addr_for_w = wr_cmd_valid_q;
    wire wr_active_oob = (WORD_ADDR_BITS > ADDR_BITS) ?
                         |wr_word_addr_q[WORD_ADDR_BITS-1:ADDR_BITS] : 1'b0;
    wire wr_last_expected = (wr_beat_q == wr_len_active_q);

    assign s_axi_arready = !rd_queue_full && ar_ready_delay_clear;
    assign s_axi_awready = !wr_aw_queue_full && aw_ready_delay_clear;
    assign s_axi_wready  = wr_has_addr_for_w &&
                            ((wr_b_count_q < WR_CNT_W'(WR_DEPTH)) || wr_b_pop) &&
                            w_ready_delay_clear;
    assign s_axi_rdata = rd_resp_oob_q ? '0 : mem_rd_data_q;

    always @(posedge clk) begin
        if (mem_rd_en) begin
            mem_rd_data_q <= mem_r[mem_rd_addr];
        end
    end

    always @(posedge clk) begin
        if (w_fire && !wr_active_oob) begin
            for (int i = 0; i < DW/8; i++) begin
                if (s_axi_wstrb[i]) begin
                    mem_r[wr_word_addr_q[ADDR_BITS-1:0]][8*i +: 8] <=
                        s_axi_wdata[8*i +: 8];
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_wr_ptr_q       <= '0;
            rd_rd_ptr_q       <= '0;
            rd_count_q        <= '0;
            rd_cmd_valid_q    <= 1'b0;
            rd_word_addr_q    <= '0;
            rd_len_active_q   <= 8'd0;
            rd_beat_q         <= 8'd0;
            rd_error_accum_q  <= 1'b0;
            rd_resp_oob_q     <= 1'b0;
`ifndef SYNTHESIS
            ar_ready_delay_q  <= 8'd0;
            r_rsp_delay_q     <= 8'd0;
`endif
            s_axi_rvalid      <= 1'b0;
            s_axi_rresp       <= 2'b00;
            s_axi_rlast       <= 1'b0;
        end else begin
            logic rd_cmd_finish;
            logic rd_cmd_can_load;
            logic rd_cmd_load_from_queue;
            logic rd_cmd_load_from_ar;
            logic rd_enqueue;
            logic rd_dequeue;

            rd_cmd_finish = r_fire && s_axi_rlast;
            rd_cmd_can_load = !rd_cmd_valid_q || rd_cmd_finish;
            rd_cmd_load_from_queue = rd_cmd_can_load && (rd_count_q != '0);
            rd_cmd_load_from_ar = rd_cmd_can_load && (rd_count_q == '0) && ar_fire;
            rd_enqueue = ar_fire && !rd_cmd_load_from_ar;
            rd_dequeue = rd_cmd_load_from_queue;

`ifndef SYNTHESIS
            if (ar_fire) begin
                if (!rd_cmd_load_from_ar) begin
                    rd_addr_q[rd_wr_ptr_q] <= s_axi_araddr;
                    rd_len_q[rd_wr_ptr_q]  <= s_axi_arlen;
                    rd_wr_ptr_q <= inc_rd_ptr(rd_wr_ptr_q);
                end
                ar_ready_delay_q <= ram_response_delay(ddr_cmd_max_lat);
            end else if (ar_ready_delay_q != 8'd0) begin
                ar_ready_delay_q <= ar_ready_delay_q - 8'd1;
            end
`else
            if (ar_fire && !rd_cmd_load_from_ar) begin
                rd_addr_q[rd_wr_ptr_q] <= s_axi_araddr;
                rd_len_q[rd_wr_ptr_q]  <= s_axi_arlen;
                rd_wr_ptr_q <= inc_rd_ptr(rd_wr_ptr_q);
            end
`endif

            unique case ({rd_enqueue, rd_dequeue})
                2'b10: rd_count_q <= rd_count_q + 1'b1;
                2'b01: rd_count_q <= rd_count_q - 1'b1;
                default: rd_count_q <= rd_count_q;
            endcase

            if (rd_issue_any) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rlast  <= rd_issue_last;
                s_axi_rresp  <= rd_issue_resp;
                rd_resp_oob_q <= rd_issue_oob;
                if (rd_issue_oob) rd_error_accum_q <= 1'b1;
            end

            if (r_fire) begin
                if (!rd_issue_any) begin
                    s_axi_rvalid <= 1'b0;
                    s_axi_rlast  <= 1'b0;
                end
                if (s_axi_rlast) begin
                    rd_cmd_valid_q   <= 1'b0;
                    rd_beat_q        <= 8'd0;
                    rd_error_accum_q <= 1'b0;
                end else begin
                    rd_beat_q      <= rd_beat_q + 8'd1;
                    rd_word_addr_q <= rd_word_addr_q + WORD_ADDR_BITS'(1);
`ifndef SYNTHESIS
                    r_rsp_delay_q  <= 8'd0;
`endif
                end
            end
`ifndef SYNTHESIS
            else if (rd_cmd_valid_q && !s_axi_rvalid && (r_rsp_delay_q != 8'd0)) begin
                r_rsp_delay_q <= r_rsp_delay_q - 8'd1;
            end
`endif

            if (rd_cmd_load_from_queue) begin
`ifndef SYNTHESIS
                r_rsp_delay_q    <= ram_response_delay(ddr_rsp_max_lat);
`endif
                rd_cmd_valid_q  <= 1'b1;
                rd_word_addr_q  <= rd_addr_q[rd_rd_ptr_q][AW-1:ADDR_LSB];
                rd_len_active_q <= rd_len_q[rd_rd_ptr_q];
                rd_beat_q       <= 8'd0;
                rd_error_accum_q <= rd_pipe_cmd ? rd_issue_oob : 1'b0;
                rd_rd_ptr_q <= inc_rd_ptr(rd_rd_ptr_q);
            end else if (rd_cmd_load_from_ar) begin
`ifndef SYNTHESIS
                r_rsp_delay_q    <= ram_response_delay(ddr_rsp_max_lat);
`endif
                rd_cmd_valid_q  <= 1'b1;
                rd_word_addr_q  <= s_axi_araddr[AW-1:ADDR_LSB];
                rd_len_active_q <= s_axi_arlen;
                rd_beat_q       <= 8'd0;
                rd_error_accum_q <= rd_pipe_cmd ? rd_issue_oob : 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_aw_wr_ptr_q    <= '0;
            wr_aw_rd_ptr_q    <= '0;
            wr_aw_count_q     <= '0;
            wr_cmd_valid_q    <= 1'b0;
            wr_word_addr_q    <= '0;
            wr_len_active_q   <= 8'd0;
            wr_beat_q         <= 8'd0;
            wr_error_accum_q  <= 1'b0;
`ifndef SYNTHESIS
            aw_ready_delay_q  <= 8'd0;
            w_ready_delay_q   <= 8'd0;
`endif
            wr_b_wr_ptr_q     <= '0;
            wr_b_rd_ptr_q     <= '0;
            wr_b_count_q      <= '0;
            s_axi_bvalid      <= 1'b0;
            s_axi_bresp       <= 2'b00;
        end else begin
            logic wr_cmd_finish;
            logic wr_cmd_can_load;
            logic wr_cmd_load_from_queue;
            logic wr_cmd_load_from_aw;
            logic wr_aw_enqueue;
            logic wr_aw_dequeue;
            logic wr_b_push;
            logic [1:0] wr_b_push_resp;

            wr_cmd_finish = w_fire && (s_axi_wlast || wr_last_expected);
            wr_cmd_can_load = !wr_cmd_valid_q || wr_cmd_finish;
            wr_cmd_load_from_queue = wr_cmd_can_load && (wr_aw_count_q != '0);
            wr_cmd_load_from_aw = wr_cmd_can_load && (wr_aw_count_q == '0) && aw_fire;
            wr_aw_enqueue = aw_fire && !wr_cmd_load_from_aw;
            wr_aw_dequeue = wr_cmd_load_from_queue;
            wr_b_push = 1'b0;
            wr_b_push_resp = 2'b00;

`ifndef SYNTHESIS
            if (aw_fire) begin
                if (!wr_cmd_load_from_aw) begin
                    wr_addr_q[wr_aw_wr_ptr_q] <= s_axi_awaddr;
                    wr_len_q[wr_aw_wr_ptr_q]  <= s_axi_awlen;
                    wr_aw_wr_ptr_q <= inc_wr_ptr(wr_aw_wr_ptr_q);
                end
                aw_ready_delay_q <= ram_response_delay(ddr_cmd_max_lat);
            end else if (aw_ready_delay_q != 8'd0) begin
                aw_ready_delay_q <= aw_ready_delay_q - 8'd1;
            end
`else
            if (aw_fire && !wr_cmd_load_from_aw) begin
                wr_addr_q[wr_aw_wr_ptr_q] <= s_axi_awaddr;
                wr_len_q[wr_aw_wr_ptr_q]  <= s_axi_awlen;
                wr_aw_wr_ptr_q <= inc_wr_ptr(wr_aw_wr_ptr_q);
            end
`endif

            if (w_fire) begin
                logic wr_oob;
                logic wr_error_next;

                wr_oob = wr_active_oob;
                wr_error_next = wr_error_accum_q | wr_oob | (s_axi_wlast != wr_last_expected);

                if (s_axi_wlast || wr_last_expected) begin
                    wr_b_push_resp = wr_error_next ? 2'b10 : 2'b00;
                    wr_b_push = 1'b1;
                    wr_cmd_valid_q <= 1'b0;
                    wr_beat_q <= 8'd0;
                    wr_error_accum_q <= 1'b0;
                end else begin
                    wr_beat_q <= wr_beat_q + 8'd1;
                    wr_word_addr_q <= wr_word_addr_q + WORD_ADDR_BITS'(1);
                    wr_error_accum_q <= wr_error_next;
                end
            end
`ifndef SYNTHESIS
            else if (w_ready_delay_q != 8'd0) begin
                w_ready_delay_q <= w_ready_delay_q - 8'd1;
            end
`endif

            unique case ({wr_aw_enqueue, wr_aw_dequeue})
                2'b10: wr_aw_count_q <= wr_aw_count_q + 1'b1;
                2'b01: wr_aw_count_q <= wr_aw_count_q - 1'b1;
                default: wr_aw_count_q <= wr_aw_count_q;
            endcase

            if (wr_cmd_load_from_queue) begin
`ifndef SYNTHESIS
                w_ready_delay_q  <= ram_response_delay(ddr_w_max_lat);
`endif
                wr_cmd_valid_q  <= 1'b1;
                wr_word_addr_q  <= wr_addr_q[wr_aw_rd_ptr_q][AW-1:ADDR_LSB];
                wr_len_active_q <= wr_len_q[wr_aw_rd_ptr_q];
                wr_beat_q       <= 8'd0;
                wr_error_accum_q <= 1'b0;
                wr_aw_rd_ptr_q <= inc_wr_ptr(wr_aw_rd_ptr_q);
            end else if (wr_cmd_load_from_aw) begin
`ifndef SYNTHESIS
                w_ready_delay_q  <= ram_response_delay(ddr_w_max_lat);
`endif
                wr_cmd_valid_q  <= 1'b1;
                wr_word_addr_q  <= s_axi_awaddr[AW-1:ADDR_LSB];
                wr_len_active_q <= s_axi_awlen;
                wr_beat_q       <= 8'd0;
                wr_error_accum_q <= 1'b0;
            end

            if (b_fire) begin
                s_axi_bvalid <= 1'b0;
                wr_b_rd_ptr_q <= inc_wr_ptr(wr_b_rd_ptr_q);
            end

            if (!s_axi_bvalid && (wr_b_count_q != '0)) begin
`ifndef SYNTHESIS
                if (wr_b_delay_q[wr_b_rd_ptr_q] == 8'd0) begin
                    s_axi_bvalid <= 1'b1;
                    s_axi_bresp  <= wr_b_resp_q[wr_b_rd_ptr_q];
                end else begin
                    wr_b_delay_q[wr_b_rd_ptr_q] <= wr_b_delay_q[wr_b_rd_ptr_q] - 8'd1;
                end
`else
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= wr_b_resp_q[wr_b_rd_ptr_q];
`endif
            end

            if (wr_b_push) begin
                wr_b_resp_q[wr_b_wr_ptr_q] <= wr_b_push_resp;
`ifndef SYNTHESIS
                wr_b_delay_q[wr_b_wr_ptr_q] <= ram_response_delay(ddr_rsp_max_lat);
`endif
                wr_b_wr_ptr_q <= inc_wr_ptr(wr_b_wr_ptr_q);
            end

            unique case ({wr_b_push, b_fire})
                2'b10: wr_b_count_q <= wr_b_count_q + 1'b1;
                2'b01: wr_b_count_q <= wr_b_count_q - 1'b1;
                default: wr_b_count_q <= wr_b_count_q;
            endcase
        end
    end

`ifndef SYNTHESIS
    task automatic load_initial_mem();
        if ((INIT_EN != 0) && mem_path_q != "") begin
            $display("soc_axi_ram: loading memory from %s", mem_path_q);
            $readmemh(mem_path_q, mem_r);
        end
        if (data_mem_path_q != "") begin
            $display("soc_axi_ram: overlay memory from %s at word %0d",
                     data_mem_path_q, data_mem_base_word_q);
            $readmemh(data_mem_path_q, mem_r, data_mem_base_word_q);
        end
    endtask

    initial begin
        ddr_rand_lat_en = 0;
        ddr_cmd_max_lat = 0;
        ddr_w_max_lat = 0;
        ddr_rsp_max_lat = 0;
        ram_fixed_lat = -1;
        data_mem_base_word_q = 0;
        mem_path_q = MEM_PATH;
        data_mem_path_q = "";

        void'($value$plusargs("SOC_CPU_MEM=%s", mem_path_q));
        void'($value$plusargs("SOC_NPU_MEM=%s", data_mem_path_q));
        void'($value$plusargs("SOC_DATA_MEM=%s", data_mem_path_q));
        void'($value$plusargs("SOC_DATA_MEM_BASE_WORD=%d", data_mem_base_word_q));
        void'($value$plusargs("DDR_RAND_LAT=%d", ddr_rand_lat_en));
        void'($value$plusargs("DDR_CMD_MAX_LAT=%d", ddr_cmd_max_lat));
        void'($value$plusargs("DDR_W_MAX_LAT=%d", ddr_w_max_lat));
        void'($value$plusargs("DDR_RSP_MAX_LAT=%d", ddr_rsp_max_lat));
        void'($value$plusargs("RAM_RAND_LAT=%d", ddr_rand_lat_en));
        void'($value$plusargs("RAM_CMD_MAX_LAT=%d", ddr_cmd_max_lat));
        void'($value$plusargs("RAM_W_MAX_LAT=%d", ddr_w_max_lat));
        void'($value$plusargs("RAM_RSP_MAX_LAT=%d", ddr_rsp_max_lat));
        void'($value$plusargs("RAM_FIXED_LAT=%d", ram_fixed_lat));

        if (ram_fixed_lat >= 0) begin
            $display("soc_axi_ram: RAM fixed response latency enabled fixed=%0d cycles",
                     ram_fixed_lat);
        end else if (ddr_rand_lat_en != 0) begin
            $display("soc_axi_ram: RAM random response latency enabled cmd_max=%0d w_max=%0d rsp_max=%0d",
                     ddr_cmd_max_lat, ddr_w_max_lat, ddr_rsp_max_lat);
        end
        load_initial_mem();
    end

    always @(posedge clk) begin
        if (mem_reload_req) begin
            $display("soc_axi_ram: runtime memory reload");
            load_initial_mem();
        end
    end
`else
    initial begin
        if ((INIT_EN != 0) && (MEM_PATH != "")) begin
            $readmemh(MEM_PATH, mem_r);
        end
    end
`endif

    wire _unused_axi_attr =
        |s_axi_awcache | |s_axi_awprot | |s_axi_awlock | |s_axi_awburst | |s_axi_awsize |
        |s_axi_arcache | |s_axi_arprot | |s_axi_arlock | |s_axi_arburst | |s_axi_arsize;

endmodule
