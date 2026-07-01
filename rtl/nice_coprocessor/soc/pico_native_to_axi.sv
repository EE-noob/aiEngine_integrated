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

    logic [ADDR_WIDTH-1:0]   addr_q;
    logic [DATA_WIDTH-1:0]   wdata_q;
    logic [DATA_WIDTH/8-1:0] wstrb_q;
    logic                    instr_q;
    logic                    read_busy_q;
    logic                    ar_pending_q;
    logic                    write_busy_q;
    logic                    aw_pending_q;
    logic                    w_pending_q;

    wire bridge_idle   = !read_busy_q && !write_busy_q;
    wire mem_write_req = mem_valid && (mem_wstrb != '0);
    wire mem_read_req  = mem_valid && (mem_wstrb == '0);
    wire new_read_req  = bridge_idle && mem_read_req;
    wire new_write_req = bridge_idle && mem_write_req;

    wire ar_fire = m_axi_arvalid && m_axi_arready;
    wire r_fire  = m_axi_rvalid && m_axi_rready;
    wire aw_fire = m_axi_awvalid && m_axi_awready;
    wire w_fire  = m_axi_wvalid && m_axi_wready;
    wire b_fire  = m_axi_bvalid && m_axi_bready;

    assign m_axi_arvalid = new_read_req || (read_busy_q && ar_pending_q);
    assign m_axi_araddr  = new_read_req ? mem_addr : addr_q;
    assign m_axi_arprot  = (new_read_req ? mem_instr : instr_q) ? 3'b100 : 3'b000;

    assign m_axi_awvalid = new_write_req || (write_busy_q && aw_pending_q);
    assign m_axi_awaddr  = new_write_req ? mem_addr : addr_q;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_wvalid  = new_write_req || (write_busy_q && w_pending_q);
    assign m_axi_wdata   = new_write_req ? mem_wdata : wdata_q;
    assign m_axi_wstrb   = new_write_req ? mem_wstrb : wstrb_q;

    assign m_axi_rready = read_busy_q || new_read_req;
    assign m_axi_bready = write_busy_q || new_write_req;
    assign mem_ready = r_fire || b_fire;
    assign mem_rdata = r_fire ? m_axi_rdata : '0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_q       <= '0;
            wdata_q      <= '0;
            wstrb_q      <= '0;
            instr_q      <= 1'b0;
            read_busy_q  <= 1'b0;
            ar_pending_q <= 1'b0;
            write_busy_q <= 1'b0;
            aw_pending_q <= 1'b0;
            w_pending_q  <= 1'b0;
        end else begin
            if (new_read_req) begin
                addr_q       <= mem_addr;
                instr_q      <= mem_instr;
                read_busy_q  <= !r_fire;
                ar_pending_q <= !ar_fire;
            end else if (read_busy_q) begin
                if (ar_fire) begin
                    ar_pending_q <= 1'b0;
                end
                if (r_fire) begin
                    read_busy_q  <= 1'b0;
                    ar_pending_q <= 1'b0;
                end
            end

            if (new_write_req) begin
                addr_q       <= mem_addr;
                wdata_q      <= mem_wdata;
                wstrb_q      <= mem_wstrb;
                write_busy_q <= !b_fire;
                aw_pending_q <= !aw_fire;
                w_pending_q  <= !w_fire;
            end else if (write_busy_q) begin
                if (aw_fire) begin
                    aw_pending_q <= 1'b0;
                end
                if (w_fire) begin
                    w_pending_q <= 1'b0;
                end
                if (b_fire) begin
                    write_busy_q <= 1'b0;
                    aw_pending_q <= 1'b0;
                    w_pending_q  <= 1'b0;
                end
            end
        end
    end

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

`ifndef SYNTHESIS
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
`endif

    wire _unused_axi_resp = |m_axi_rresp | m_axi_rlast | |m_axi_bresp;

endmodule
