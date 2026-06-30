`include "uvm_macros.svh"
import uvm_pkg::*;

module axi_sim_ram #(
    parameter DP = 512,
    parameter DW = 32,
    parameter AW = 32,
    parameter MEM_PATH = "",
    parameter INIT_EN = 0
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

    output reg              s_axi_bvalid,
    input  wire             s_axi_bready,
    output reg  [1:0]       s_axi_bresp,

    input  wire             s_axi_arvalid,
    output wire             s_axi_arready,
    input  wire [AW-1:0]    s_axi_araddr,
    input  wire [3:0]       s_axi_arcache,
    input  wire [2:0]       s_axi_arprot,
    input  wire [1:0]       s_axi_arlock,
    input  wire [1:0]       s_axi_arburst,
    input  wire [7:0]       s_axi_arlen,
    input  wire [2:0]       s_axi_arsize,

    output reg              s_axi_rvalid,
    input  wire             s_axi_rready,
    output reg  [DW-1:0]    s_axi_rdata,
    output reg  [1:0]       s_axi_rresp,
    output reg              s_axi_rlast,

    input  wire             mem_reload_req
);

    localparam integer BYTEW = DW / 8;
    localparam integer ADDR_LSB = (BYTEW <= 1) ? 0 : $clog2(BYTEW);
    localparam integer ADDR_BITS = (DP <= 1) ? 1 : $clog2(DP);

    reg [DW-1:0] mem_r [0:DP-1];

    reg                 aw_pending;
    reg [AW-1:0]        aw_addr_q;
    reg [7:0]           aw_len_q;
    reg [7:0]           wr_beat_cnt;
    reg                 wr_error_q;

    reg                 rd_active;
    reg [AW-1:0]        rd_addr_q;
    reg [7:0]           rd_len_q;
    reg [7:0]           rd_beat_cnt;
    reg                 rd_error_q;

    wire aw_fire = s_axi_awvalid & s_axi_awready;
    wire w_fire  = s_axi_wvalid  & s_axi_wready;
    wire ar_fire = s_axi_arvalid & s_axi_arready;

    wire [AW-1:0] wr_cur_addr = aw_addr_q + (AW'(wr_beat_cnt) << ADDR_LSB);
    wire [AW-1:0] rd_cur_addr = rd_addr_q + (AW'(rd_beat_cnt) << ADDR_LSB);
    wire [ADDR_BITS-1:0] wr_idx = wr_cur_addr[ADDR_LSB + ADDR_BITS - 1:ADDR_LSB];
    wire [ADDR_BITS-1:0] rd_idx = rd_cur_addr[ADDR_LSB + ADDR_BITS - 1:ADDR_LSB];

    wire wr_oob;
    wire rd_oob;

    generate
        if (AW > (ADDR_LSB + ADDR_BITS)) begin : g_oob_check
            assign wr_oob = |wr_cur_addr[AW-1:ADDR_LSB + ADDR_BITS];
            assign rd_oob = |rd_cur_addr[AW-1:ADDR_LSB + ADDR_BITS];
        end else begin : g_no_oob
            assign wr_oob = 1'b0;
            assign rd_oob = 1'b0;
        end
    endgenerate

    assign s_axi_awready = (!aw_pending) && (!s_axi_bvalid);
    assign s_axi_wready  = aw_pending && (!s_axi_bvalid);
    assign s_axi_arready = (!rd_active) && (!s_axi_rvalid);

    integer i;
    string mem_path_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_pending   <= 1'b0;
            wr_beat_cnt  <= 8'd0;
            wr_error_q   <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            if (aw_fire) begin
                aw_pending <= 1'b1;
                aw_addr_q  <= s_axi_awaddr;
                aw_len_q   <= s_axi_awlen;
                wr_beat_cnt <= 8'd0;
                wr_error_q <= 1'b0;
            end

            if (w_fire) begin
                logic wr_error_next;
                wr_error_next = wr_error_q | wr_oob |
                                (s_axi_wlast != (wr_beat_cnt == aw_len_q));
                if (wr_oob) begin
                    wr_error_q <= wr_error_next;
                end else begin
                    for (i = 0; i < DW/8; i = i + 1) begin
                        if (s_axi_wstrb[i]) begin
                            mem_r[wr_idx][8*i +: 8] <= s_axi_wdata[8*i +: 8];
                        end
                    end
                end
                wr_error_q <= wr_error_next;
                if (s_axi_wlast || (wr_beat_cnt == aw_len_q)) begin
                    s_axi_bvalid <= 1'b1;
                    s_axi_bresp <= wr_error_next ? 2'b10 : 2'b00;
                    aw_pending <= 1'b0;
                end else begin
                    wr_beat_cnt <= wr_beat_cnt + 8'd1;
                end
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_active <= 1'b0;
            rd_addr_q <= '0;
            rd_len_q <= 8'd0;
            rd_beat_cnt <= 8'd0;
            rd_error_q <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= {DW{1'b0}};
            s_axi_rlast  <= 1'b0;
        end else begin
            if (ar_fire) begin
                rd_active <= 1'b1;
                rd_addr_q <= s_axi_araddr;
                rd_len_q <= s_axi_arlen;
                rd_beat_cnt <= 8'd0;
                rd_error_q <= 1'b0;
            end

            if (rd_active && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rlast  <= (rd_beat_cnt == rd_len_q);

                if (rd_oob) begin
                    s_axi_rresp <= 2'b10;
                    s_axi_rdata <= {DW{1'b0}};
                    rd_error_q <= 1'b1;
                end else begin
                    s_axi_rresp <= rd_error_q ? 2'b10 : 2'b00;
                    s_axi_rdata <= mem_r[rd_idx];
                end
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
                s_axi_rlast  <= 1'b0;
                if (rd_beat_cnt == rd_len_q) begin
                    rd_active <= 1'b0;
                end else begin
                    rd_beat_cnt <= rd_beat_cnt + 8'd1;
                end
            end
        end
    end

    initial begin
        mem_path_q = MEM_PATH;
        void'($value$plusargs("SOC_MMA_MEM=%s", mem_path_q));
        if (INIT_EN && mem_path_q != "") begin
            $display("axi_sim_ram: loading memory from %s", mem_path_q);
            $readmemh(mem_path_q, mem_r);
        end
    end

    task automatic reload_mem_from_file();
        if (mem_path_q != "") begin
            `uvm_info("RAM_RELOAD", $sformatf("axi_sim_ram runtime reload from %s", mem_path_q), UVM_LOW)
            $readmemh(mem_path_q, mem_r);
        end
    endtask

    task automatic check_mem_file(
        input string file_path,
        input integer start_word,
        input integer end_word,
        output integer mismatch_cnt
    );
        integer fd;
        integer ret;
        integer idx;
        reg [DW-1:0] exp_word;

        mismatch_cnt = 0;

        if ((start_word < 0) || (end_word < start_word)) begin
            `uvm_error("RAM_CHK", $sformatf("Invalid check range start=%0d end=%0d", start_word, end_word))
            mismatch_cnt = -1;
        end else begin
            fd = $fopen(file_path, "r");
            if (fd == 0) begin
                `uvm_error("RAM_CHK", $sformatf("Cannot open %s for check", file_path))
                mismatch_cnt = -1;
            end else begin
                idx = 0;
                while ((idx <= end_word) && !$feof(fd)) begin
                    ret = $fscanf(fd, "%h\n", exp_word);
                    if (ret != 1) begin
                        if (idx >= start_word) begin
                            mismatch_cnt = mismatch_cnt + 1;
                            `uvm_error("RAM_CHK", $sformatf("Parse failure at word[%0d] from %s", idx, file_path))
                        end
                    end else if (idx >= start_word) begin
                        if (mem_r[idx] !== exp_word) begin
                            mismatch_cnt = mismatch_cnt + 1;
                            `uvm_error("RAM_CHK", $sformatf("Mismatch word[%0d]: exp=0x%08h act=0x%08h", idx, exp_word, mem_r[idx]))
                        end
                    end
                    idx = idx + 1;
                end

                if (idx <= end_word) begin
                    mismatch_cnt = mismatch_cnt + 1;
                    `uvm_error("RAM_CHK", $sformatf("File %s ended early at word[%0d], expected up to word[%0d]", file_path, idx, end_word))
                end

                $fclose(fd);

                if (mismatch_cnt == 0) begin
                    `uvm_info("RAM_CHK", $sformatf("\033[1;32mPASS\033[0m RAM check matched %s in range [%0d:%0d]", file_path, start_word, end_word), UVM_LOW)
                end
            end
        end
    endtask

    always @(posedge clk) begin
        if (mem_reload_req) begin
            reload_mem_from_file();
        end
    end

    wire _unused_axi_attr =
        |s_axi_awcache | |s_axi_awprot | |s_axi_awlock | |s_axi_awburst | |s_axi_awsize |
        |s_axi_arcache | |s_axi_arprot | |s_axi_arlock | |s_axi_arburst | |s_axi_arsize;

endmodule
