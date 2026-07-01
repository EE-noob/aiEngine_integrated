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
    localparam int unsigned RD_DEPTH = (READ_OUTSTANDING < 1) ? 1 : READ_OUTSTANDING;
    localparam int unsigned WR_DEPTH = (WRITE_OUTSTANDING < 1) ? 1 : WRITE_OUTSTANDING;
    localparam int unsigned RD_PTR_W = (RD_DEPTH < 2) ? 1 : $clog2(RD_DEPTH);
    localparam int unsigned WR_PTR_W = (WR_DEPTH < 2) ? 1 : $clog2(WR_DEPTH);
    localparam int unsigned RD_CNT_W = (RD_DEPTH < 2) ? 1 : $clog2(RD_DEPTH + 1);
    localparam int unsigned WR_CNT_W = (WR_DEPTH < 2) ? 1 : $clog2(WR_DEPTH + 1);

    (* ram_style = "block" *) logic [DW-1:0] mem_r [0:DP-1];

    logic [AW-1:0] rd_addr_q [0:RD_DEPTH-1];
    logic [7:0]    rd_len_q  [0:RD_DEPTH-1];
    logic [RD_PTR_W-1:0] rd_wr_ptr_q;
    logic [RD_PTR_W-1:0] rd_rd_ptr_q;
    logic [RD_CNT_W-1:0] rd_count_q;
    logic [7:0] rd_beat_q;
    logic rd_error_accum_q;
    logic rd_direct_out_q;
    logic [7:0] ar_ready_delay_q;
    logic [7:0] r_rsp_delay_q;
    logic rd_resp_oob_q;
    logic [DW-1:0] mem_rd_data_q;

    logic [AW-1:0] wr_addr_q [0:WR_DEPTH-1];
    logic [7:0]    wr_len_q  [0:WR_DEPTH-1];
    logic [WR_PTR_W-1:0] wr_aw_wr_ptr_q;
    logic [WR_PTR_W-1:0] wr_aw_rd_ptr_q;
    logic [WR_CNT_W-1:0] wr_aw_count_q;
    logic [7:0] wr_beat_q;
    logic wr_error_accum_q;
    logic [7:0] aw_ready_delay_q;
    logic [7:0] w_ready_delay_q;

    logic [1:0] wr_b_resp_q  [0:WR_DEPTH-1];
    logic [7:0] wr_b_delay_q [0:WR_DEPTH-1];
    logic [WR_PTR_W-1:0] wr_b_wr_ptr_q;
    logic [WR_PTR_W-1:0] wr_b_rd_ptr_q;
    logic [WR_CNT_W-1:0] wr_b_count_q;

`ifndef SYNTHESIS
    integer ddr_rand_lat_en;
    integer ddr_cmd_max_lat;
    integer ddr_w_max_lat;
    integer ddr_rsp_max_lat;
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
    wire rd_pop  = r_fire && s_axi_rlast;
`ifndef SYNTHESIS
    wire rd_direct_fire = ar_fire && !s_axi_rvalid && (rd_count_q == '0) &&
                          (s_axi_arlen == 8'd0) && (ddr_rand_lat_en == 0);
`else
    wire rd_direct_fire = ar_fire && !s_axi_rvalid && (rd_count_q == '0) &&
                          (s_axi_arlen == 8'd0);
`endif

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

    function automatic [7:0] random_ddr_delay(input integer max_lat);
`ifndef SYNTHESIS
        integer value;
        begin
            if ((ddr_rand_lat_en == 0) || (max_lat <= 0)) begin
                random_ddr_delay = 8'd0;
            end else begin
                value = $urandom_range(max_lat, 0);
                random_ddr_delay = (value > 255) ? 8'hff : value[7:0];
            end
        end
`else
        random_ddr_delay = 8'd0;
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

    wire rd_can_issue = !s_axi_rvalid;
    wire rd_issue_queue = rd_can_issue && !rd_direct_fire &&
                          (rd_count_q != '0) && (r_rsp_delay_q == 8'd0);
    wire [AW-1:0] rd_queue_byte_addr =
        rd_addr_q[rd_rd_ptr_q] + (AW'(rd_beat_q) << ADDR_LSB);
    wire rd_issue_any = rd_direct_fire || rd_issue_queue;
    wire [AW-1:0] rd_issue_byte_addr = rd_direct_fire ? s_axi_araddr : rd_queue_byte_addr;
    wire rd_issue_oob = addr_oob(rd_issue_byte_addr);
    wire rd_issue_last = rd_direct_fire ? 1'b1 : (rd_beat_q == rd_len_q[rd_rd_ptr_q]);
    wire [1:0] rd_issue_resp = (rd_error_accum_q || rd_issue_oob) ? 2'b10 : 2'b00;
    wire mem_rd_en = rd_issue_any && !rd_issue_oob;
    wire [ADDR_BITS-1:0] mem_rd_addr = word_idx(rd_issue_byte_addr);

    wire rd_queue_full = (rd_count_q == RD_CNT_W'(RD_DEPTH));
    wire wr_aw_queue_full = (wr_aw_count_q == WR_CNT_W'(WR_DEPTH));
    wire wr_b_queue_full = (wr_b_count_q == WR_CNT_W'(WR_DEPTH));
    wire wr_b_pop = b_fire;
    wire wr_has_addr_for_w = (wr_aw_count_q != '0) || aw_fire;

    assign s_axi_arready = !rd_queue_full && (ar_ready_delay_q == 8'd0);
    assign s_axi_awready = !wr_aw_queue_full && (aw_ready_delay_q == 8'd0);
    assign s_axi_wready  = wr_has_addr_for_w &&
                            ((wr_b_count_q < WR_CNT_W'(WR_DEPTH)) || wr_b_pop) &&
                            (w_ready_delay_q == 8'd0);
    assign s_axi_rdata = rd_resp_oob_q ? '0 : mem_rd_data_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            mem_rd_data_q <= '0;
        end else if (mem_rd_en) begin
            mem_rd_data_q <= mem_r[mem_rd_addr];
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_wr_ptr_q       <= '0;
            rd_rd_ptr_q       <= '0;
            rd_count_q        <= '0;
            rd_beat_q         <= 8'd0;
            rd_error_accum_q  <= 1'b0;
            rd_direct_out_q   <= 1'b0;
            rd_resp_oob_q     <= 1'b0;
            ar_ready_delay_q  <= 8'd0;
            r_rsp_delay_q     <= 8'd0;
            s_axi_rvalid      <= 1'b0;
            s_axi_rresp       <= 2'b00;
            s_axi_rlast       <= 1'b0;
        end else begin
            if (ar_fire) begin
                if (!rd_direct_fire) begin
                    rd_addr_q[rd_wr_ptr_q] <= s_axi_araddr;
                    rd_len_q[rd_wr_ptr_q]  <= s_axi_arlen;
                    rd_wr_ptr_q <= inc_rd_ptr(rd_wr_ptr_q);
                    if (!rd_pop || rd_direct_out_q) rd_count_q <= rd_count_q + 1'b1;
                end
                ar_ready_delay_q <= random_ddr_delay(ddr_cmd_max_lat);
            end else if (ar_ready_delay_q != 8'd0) begin
                ar_ready_delay_q <= ar_ready_delay_q - 8'd1;
            end

            if (rd_issue_any) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rlast  <= rd_issue_last;
                s_axi_rresp  <= rd_issue_resp;
                rd_resp_oob_q <= rd_issue_oob;
                rd_direct_out_q <= rd_direct_fire;
                if (!rd_direct_fire && rd_issue_oob) rd_error_accum_q <= 1'b1;
            end else if (rd_can_issue && (rd_count_q != '0) && (r_rsp_delay_q != 8'd0)) begin
                r_rsp_delay_q <= r_rsp_delay_q - 8'd1;
            end

            if (r_fire) begin
                s_axi_rvalid <= 1'b0;
                s_axi_rlast  <= 1'b0;
                if (s_axi_rlast) begin
                    if (rd_direct_out_q) begin
                        rd_direct_out_q <= 1'b0;
                    end else begin
                        rd_rd_ptr_q      <= inc_rd_ptr(rd_rd_ptr_q);
                        rd_beat_q        <= 8'd0;
                        rd_error_accum_q <= 1'b0;
                        if (!ar_fire) rd_count_q <= rd_count_q - 1'b1;
                    end
                end else begin
                    rd_beat_q     <= rd_beat_q + 8'd1;
                    r_rsp_delay_q <= random_ddr_delay(ddr_rsp_max_lat);
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_aw_wr_ptr_q    <= '0;
            wr_aw_rd_ptr_q    <= '0;
            wr_aw_count_q     <= '0;
            wr_beat_q         <= 8'd0;
            wr_error_accum_q  <= 1'b0;
            aw_ready_delay_q  <= 8'd0;
            w_ready_delay_q   <= 8'd0;
            wr_b_wr_ptr_q     <= '0;
            wr_b_rd_ptr_q     <= '0;
            wr_b_count_q      <= '0;
            s_axi_bvalid      <= 1'b0;
            s_axi_bresp       <= 2'b00;
        end else begin
            logic wr_cmd_pop;
            logic wr_b_push;
            logic [1:0] wr_b_push_resp;

            wr_cmd_pop = 1'b0;
            wr_b_push = 1'b0;
            wr_b_push_resp = 2'b00;

            if (aw_fire) begin
                wr_addr_q[wr_aw_wr_ptr_q] <= s_axi_awaddr;
                wr_len_q[wr_aw_wr_ptr_q]  <= s_axi_awlen;
                wr_aw_wr_ptr_q <= inc_wr_ptr(wr_aw_wr_ptr_q);
                aw_ready_delay_q <= random_ddr_delay(ddr_cmd_max_lat);
            end else if (aw_ready_delay_q != 8'd0) begin
                aw_ready_delay_q <= aw_ready_delay_q - 8'd1;
            end

            if (w_fire) begin
                logic use_queued_aw;
                logic [AW-1:0] wr_base_addr;
                logic [7:0] wr_cur_len;
                logic [AW-1:0] wr_cur_addr;
                logic wr_oob;
                logic wr_last_expected;
                logic wr_error_next;

                use_queued_aw = (wr_aw_count_q != '0);
                wr_base_addr = use_queued_aw ? wr_addr_q[wr_aw_rd_ptr_q] : s_axi_awaddr;
                wr_cur_len = use_queued_aw ? wr_len_q[wr_aw_rd_ptr_q] : s_axi_awlen;
                wr_cur_addr = wr_base_addr + (AW'(wr_beat_q) << ADDR_LSB);
                wr_oob = addr_oob(wr_cur_addr);
                wr_last_expected = (wr_beat_q == wr_cur_len);
                wr_error_next = wr_error_accum_q | wr_oob | (s_axi_wlast != wr_last_expected);

                if (!wr_oob) begin
                    for (int i = 0; i < DW/8; i++) begin
                        if (s_axi_wstrb[i]) begin
                            mem_r[word_idx(wr_cur_addr)][8*i +: 8] <= s_axi_wdata[8*i +: 8];
                        end
                    end
                end

                if (s_axi_wlast || wr_last_expected) begin
                    wr_cmd_pop = 1'b1;
                    wr_b_push_resp = wr_error_next ? 2'b10 : 2'b00;
                    wr_b_push = 1'b1;
                    wr_aw_rd_ptr_q <= inc_wr_ptr(wr_aw_rd_ptr_q);
                    wr_beat_q <= 8'd0;
                    wr_error_accum_q <= 1'b0;
                end else begin
                    wr_beat_q <= wr_beat_q + 8'd1;
                    wr_error_accum_q <= wr_error_next;
                end
                w_ready_delay_q <= random_ddr_delay(ddr_w_max_lat);
            end else if (w_ready_delay_q != 8'd0) begin
                w_ready_delay_q <= w_ready_delay_q - 8'd1;
            end

            unique case ({aw_fire, wr_cmd_pop})
                2'b10: wr_aw_count_q <= wr_aw_count_q + 1'b1;
                2'b01: wr_aw_count_q <= wr_aw_count_q - 1'b1;
                default: wr_aw_count_q <= wr_aw_count_q;
            endcase

            if (b_fire) begin
                s_axi_bvalid <= 1'b0;
                wr_b_rd_ptr_q <= inc_wr_ptr(wr_b_rd_ptr_q);
            end

            if (!s_axi_bvalid && (wr_b_count_q != '0)) begin
                if (wr_b_delay_q[wr_b_rd_ptr_q] == 8'd0) begin
                    s_axi_bvalid <= 1'b1;
                    s_axi_bresp  <= wr_b_resp_q[wr_b_rd_ptr_q];
                end else begin
                    wr_b_delay_q[wr_b_rd_ptr_q] <= wr_b_delay_q[wr_b_rd_ptr_q] - 8'd1;
                end
            end

            if (wr_b_push) begin
                wr_b_resp_q[wr_b_wr_ptr_q] <= wr_b_push_resp;
                wr_b_delay_q[wr_b_wr_ptr_q] <= random_ddr_delay(ddr_rsp_max_lat);
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
        if (INIT_EN && mem_path_q != "") begin
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
        data_mem_base_word_q = 0;
        mem_path_q = MEM_PATH;
        data_mem_path_q = "";

        void'($value$plusargs("SOC_CPU_MEM=%s", mem_path_q));
        void'($value$plusargs("SOC_MMA_MEM=%s", data_mem_path_q));
        void'($value$plusargs("SOC_DATA_MEM=%s", data_mem_path_q));
        void'($value$plusargs("SOC_DATA_MEM_BASE_WORD=%d", data_mem_base_word_q));
        void'($value$plusargs("DDR_RAND_LAT=%d", ddr_rand_lat_en));
        void'($value$plusargs("DDR_CMD_MAX_LAT=%d", ddr_cmd_max_lat));
        void'($value$plusargs("DDR_W_MAX_LAT=%d", ddr_w_max_lat));
        void'($value$plusargs("DDR_RSP_MAX_LAT=%d", ddr_rsp_max_lat));

        if (ddr_rand_lat_en != 0) begin
            $display("soc_axi_ram: DDR random latency enabled cmd_max=%0d w_max=%0d rsp_max=%0d",
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
        if (INIT_EN && MEM_PATH != "") begin
            $readmemh(MEM_PATH, mem_r);
        end
    end
`endif

    wire _unused_axi_attr =
        |s_axi_awcache | |s_axi_awprot | |s_axi_awlock | |s_axi_awburst | |s_axi_awsize |
        |s_axi_arcache | |s_axi_arprot | |s_axi_arlock | |s_axi_arburst | |s_axi_arsize;

endmodule
