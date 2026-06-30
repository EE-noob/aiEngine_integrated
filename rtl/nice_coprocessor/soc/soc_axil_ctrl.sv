module soc_axil_ctrl #(
    parameter int unsigned AXIL_ADDR_WIDTH = 32,
    parameter int unsigned AXIL_DATA_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_awaddr,
    input  wire [2:0]                   s_axil_awprot,
    input  wire                         s_axil_awvalid,
    output wire                         s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]   s_axil_wdata,
    input  wire [AXIL_DATA_WIDTH/8-1:0] s_axil_wstrb,
    input  wire                         s_axil_wvalid,
    output wire                         s_axil_wready,
    output logic [1:0]                  s_axil_bresp,
    output logic                        s_axil_bvalid,
    input  wire                         s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_araddr,
    input  wire [2:0]                   s_axil_arprot,
    input  wire                         s_axil_arvalid,
    output wire                         s_axil_arready,
    output logic [AXIL_DATA_WIDTH-1:0]  s_axil_rdata,
    output logic [1:0]                  s_axil_rresp,
    output logic                        s_axil_rvalid,
    input  wire                         s_axil_rready,

    input  wire                         cpu_trap,
    output logic                        soc_finish,
    output logic [31:0]                 soc_status,
    output logic [31:0]                 soc_progress
);

    logic [AXIL_ADDR_WIDTH-1:0] awaddr_q;
    logic [AXIL_DATA_WIDTH-1:0] wdata_q;
    logic [AXIL_DATA_WIDTH/8-1:0] wstrb_q;
    logic aw_seen_q;
    logic w_seen_q;
    logic progress_trace_en;
    longint unsigned cycle_q;

    wire aw_fire = s_axil_awvalid && s_axil_awready;
    wire w_fire  = s_axil_wvalid  && s_axil_wready;
    wire ar_fire = s_axil_arvalid && s_axil_arready;
    wire wr_ready = (aw_seen_q || aw_fire) && (w_seen_q || w_fire) && !s_axil_bvalid;

    initial begin
        progress_trace_en = 1'b0;
        if ($test$plusargs("SOC_PROGRESS_TRACE")) progress_trace_en = 1'b1;
    end

    assign s_axil_awready = !aw_seen_q && !s_axil_bvalid;
    assign s_axil_wready  = !w_seen_q && !s_axil_bvalid;
    assign s_axil_arready = !s_axil_rvalid;

    function automatic logic [31:0] apply_wstrb(
        input logic [31:0] old_value,
        input logic [31:0] new_value,
        input logic [3:0]  strb
    );
        logic [31:0] result;
        begin
            result = old_value;
            for (int i = 0; i < 4; i++) begin
                if (strb[i]) begin
                    result[8*i +: 8] = new_value[8*i +: 8];
                end
            end
            apply_wstrb = result;
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awaddr_q      <= '0;
            wdata_q       <= '0;
            wstrb_q       <= '0;
            aw_seen_q     <= 1'b0;
            w_seen_q      <= 1'b0;
            s_axil_bresp  <= 2'b00;
            s_axil_bvalid <= 1'b0;
            s_axil_rdata  <= '0;
            s_axil_rresp  <= 2'b00;
            s_axil_rvalid <= 1'b0;
            soc_finish    <= 1'b0;
            soc_status    <= 32'b0;
            soc_progress  <= 32'b0;
            cycle_q       <= '0;
        end else begin
            cycle_q <= cycle_q + 1'b1;

            if (aw_fire) begin
                awaddr_q  <= s_axil_awaddr;
                aw_seen_q <= 1'b1;
            end
            if (w_fire) begin
                wdata_q  <= s_axil_wdata;
                wstrb_q  <= s_axil_wstrb;
                w_seen_q <= 1'b1;
            end

            if (wr_ready) begin
                unique case ((aw_seen_q ? awaddr_q[3:2] : s_axil_awaddr[3:2]))
                    2'b00: begin
                        soc_finish <= 1'b1;
                        soc_status <= apply_wstrb(soc_status,
                                                  w_seen_q ? wdata_q[31:0] : s_axil_wdata[31:0],
                                                  w_seen_q ? wstrb_q[3:0] : s_axil_wstrb[3:0]);
                        if (progress_trace_en) begin
                            $display("[SOC_PROGRESS_TRACE] cycle=%0d finish status=%08x progress=%08x",
                                     cycle_q,
                                     apply_wstrb(soc_status,
                                                 w_seen_q ? wdata_q[31:0] : s_axil_wdata[31:0],
                                                 w_seen_q ? wstrb_q[3:0] : s_axil_wstrb[3:0]),
                                     soc_progress);
                        end
                    end
                    2'b11: begin
                        soc_progress <= apply_wstrb(soc_progress,
                                                    w_seen_q ? wdata_q[31:0] : s_axil_wdata[31:0],
                                                    w_seen_q ? wstrb_q[3:0] : s_axil_wstrb[3:0]);
                        if (progress_trace_en) begin
                            $display("[SOC_PROGRESS_TRACE] cycle=%0d progress=%08x",
                                     cycle_q,
                                     apply_wstrb(soc_progress,
                                                 w_seen_q ? wdata_q[31:0] : s_axil_wdata[31:0],
                                                 w_seen_q ? wstrb_q[3:0] : s_axil_wstrb[3:0]));
                        end
                    end
                    default: begin
                    end
                endcase
                aw_seen_q     <= 1'b0;
                w_seen_q      <= 1'b0;
                s_axil_bresp  <= 2'b00;
                s_axil_bvalid <= 1'b1;
            end

            if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
            end

            if (ar_fire) begin
                unique case (s_axil_araddr[3:2])
                    2'b00: s_axil_rdata <= soc_status;
                    2'b01: s_axil_rdata <= {31'b0, soc_finish};
                    2'b10: s_axil_rdata <= {31'b0, cpu_trap};
                    2'b11: s_axil_rdata <= soc_progress;
                    default: s_axil_rdata <= '0;
                endcase
                s_axil_rresp  <= 2'b00;
                s_axil_rvalid <= 1'b1;
            end else if (s_axil_rvalid && s_axil_rready) begin
                s_axil_rvalid <= 1'b0;
            end
        end
    end

    wire _unused = |s_axil_awprot | |s_axil_arprot;

endmodule
