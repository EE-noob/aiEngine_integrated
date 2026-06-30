module pico_native_to_axi #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32
) (
    input  wire                       clk,
    input  wire                       rst_n,

    input  wire                       mem_valid,
    input  wire                       mem_instr,
    input  wire [ADDR_WIDTH-1:0]      mem_addr,
    input  wire [DATA_WIDTH-1:0]      mem_wdata,
    input  wire [DATA_WIDTH/8-1:0]    mem_wstrb,
    output wire                       mem_ready,
    output wire [DATA_WIDTH-1:0]      mem_rdata,

    output wire                       m_axi_arvalid,
    input  wire                       m_axi_arready,
    output wire [ADDR_WIDTH-1:0]      m_axi_araddr,
    output wire [3:0]                 m_axi_arcache,
    output wire [2:0]                 m_axi_arprot,
    output wire [1:0]                 m_axi_arlock,
    output wire [1:0]                 m_axi_arburst,
    output wire [7:0]                 m_axi_arlen,
    output wire [2:0]                 m_axi_arsize,

    output wire                       m_axi_awvalid,
    input  wire                       m_axi_awready,
    output wire [ADDR_WIDTH-1:0]      m_axi_awaddr,
    output wire [3:0]                 m_axi_awcache,
    output wire [2:0]                 m_axi_awprot,
    output wire [1:0]                 m_axi_awlock,
    output wire [1:0]                 m_axi_awburst,
    output wire [7:0]                 m_axi_awlen,
    output wire [2:0]                 m_axi_awsize,

    input  wire                       m_axi_rvalid,
    output wire                       m_axi_rready,
    input  wire [DATA_WIDTH-1:0]      m_axi_rdata,
    input  wire [1:0]                 m_axi_rresp,
    input  wire                       m_axi_rlast,

    output wire                       m_axi_wvalid,
    input  wire                       m_axi_wready,
    output wire [DATA_WIDTH-1:0]      m_axi_wdata,
    output wire [DATA_WIDTH/8-1:0]    m_axi_wstrb,
    output wire                       m_axi_wlast,

    input  wire                       m_axi_bvalid,
    output wire                       m_axi_bready,
    input  wire [1:0]                 m_axi_bresp
);

    localparam int unsigned BYTEW = DATA_WIDTH / 8;
    localparam logic [2:0] AXI_SIZE = (BYTEW <= 1) ? 3'd0 :
                                      (BYTEW <= 2) ? 3'd1 :
                                      (BYTEW <= 4) ? 3'd2 :
                                      (BYTEW <= 8) ? 3'd3 : 3'd4;

    picorv32_axi_adapter u_adapter (
        .clk(clk),
        .resetn(rst_n),
        .mem_axi_awvalid(m_axi_awvalid),
        .mem_axi_awready(m_axi_awready),
        .mem_axi_awaddr(m_axi_awaddr),
        .mem_axi_awprot(m_axi_awprot),
        .mem_axi_wvalid(m_axi_wvalid),
        .mem_axi_wready(m_axi_wready),
        .mem_axi_wdata(m_axi_wdata),
        .mem_axi_wstrb(m_axi_wstrb),
        .mem_axi_bvalid(m_axi_bvalid),
        .mem_axi_bready(m_axi_bready),
        .mem_axi_arvalid(m_axi_arvalid),
        .mem_axi_arready(m_axi_arready),
        .mem_axi_araddr(m_axi_araddr),
        .mem_axi_arprot(m_axi_arprot),
        .mem_axi_rvalid(m_axi_rvalid),
        .mem_axi_rready(m_axi_rready),
        .mem_axi_rdata(m_axi_rdata),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata)
    );

    assign m_axi_arcache = 4'b0011;
    assign m_axi_arlock  = 2'b00;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arsize  = AXI_SIZE;

    assign m_axi_awcache = 4'b0011;
    assign m_axi_awlock  = 2'b00;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awlen   = 8'd0;
    assign m_axi_awsize  = AXI_SIZE;
    assign m_axi_wlast   = 1'b1;

    bit trace_en;

    initial begin
        trace_en = $test$plusargs("SOC_CPU_AXI_TRACE");
    end

    always @(posedge clk) begin
        if (trace_en && rst_n) begin
            if (mem_valid || mem_ready || m_axi_arvalid || m_axi_rvalid ||
                m_axi_awvalid || m_axi_wvalid || m_axi_bvalid) begin
                $display("[SOC_CPU_AXI] t=%0t mem_v=%0b mem_rdy=%0b instr=%0b addr=%08h wstrb=%b rdata=%08h ar=%0b/%0b r=%0b/%0b aw=%0b/%0b w=%0b/%0b b=%0b/%0b",
                         $time, mem_valid, mem_ready, mem_instr, mem_addr,
                         mem_wstrb, mem_rdata,
                         m_axi_arvalid, m_axi_arready,
                         m_axi_rvalid, m_axi_rready,
                         m_axi_awvalid, m_axi_awready,
                         m_axi_wvalid, m_axi_wready,
                         m_axi_bvalid, m_axi_bready);
            end
        end
    end

    wire _unused_axi_resp = |m_axi_rresp | m_axi_rlast | |m_axi_bresp;

endmodule
