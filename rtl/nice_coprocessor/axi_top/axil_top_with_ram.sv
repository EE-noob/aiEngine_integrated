module axil_top_with_ram #(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter WEIGHT_WIDTH    = 8,
    parameter DATA_WIDTH      = 16,
    parameter SIZE            = 16,
    parameter BUS_WIDTH       = 32,
    parameter REG_WIDTH       = 32,
    parameter ICB_ADDR_WIDTH  = 32,
    parameter ICB_LEN_W       = 4,
    parameter MEM_DP          = 512,
    parameter MEM_PATH        = "",
    parameter MEM_INIT_EN     = 0,
    parameter [31:0] IRQ_STATUS_MASK = 32'h0000_0004
) (
    input  wire clk,
    input  wire rst_n,

    // AXI-Lite slave interface to configure MMA
    input  wire [AXIL_ADDR_WIDTH-1:0]     s_axil_awaddr,
    input  wire [2:0]                     s_axil_awprot,
    input  wire                           s_axil_awvalid,
    output wire                           s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]     s_axil_wdata,
    input  wire [AXIL_DATA_WIDTH/8-1:0]   s_axil_wstrb,
    input  wire                           s_axil_wvalid,
    output wire                           s_axil_wready,
    output wire [1:0]                     s_axil_bresp,
    output wire                           s_axil_bvalid,
    input  wire                           s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]     s_axil_araddr,
    input  wire [2:0]                     s_axil_arprot,
    input  wire                           s_axil_arvalid,
    output wire                           s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]     s_axil_rdata,
    output wire [1:0]                     s_axil_rresp,
    output wire                           s_axil_rvalid,
    input  wire                           s_axil_rready,

    output wire [31:0]                    irq,
    input  wire [31:0]                    eoi,

    input  wire                           mem_reload_req,
    output wire                           mma_busy
);

    // Legacy ICB sideband outputs from mma_axil_top (kept for debug)
    wire                          legacy_icb_cmd_valid;
    wire [ICB_ADDR_WIDTH-1:0]     legacy_icb_cmd_addr;
    wire                          legacy_icb_cmd_read;
    wire [ICB_LEN_W-1:0]          legacy_icb_cmd_len;
    wire [BUS_WIDTH-1:0]          legacy_icb_cmd_wdata;
    wire [BUS_WIDTH/8-1:0]        legacy_icb_cmd_wmask;
    wire                          legacy_icb_w_valid;
    wire                          legacy_icb_rsp_ready;

    // AXI master interconnect between mma_axil_top and axi_sim_ram
    wire                          m_axi_arvalid;
    wire                          m_axi_arready;
    wire [ICB_ADDR_WIDTH-1:0]     m_axi_araddr;
    wire [3:0]                    m_axi_arcache;
    wire [2:0]                    m_axi_arprot;
    wire [1:0]                    m_axi_arlock;
    wire [1:0]                    m_axi_arburst;
    wire [3:0]                    m_axi_arlen;
    wire [2:0]                    m_axi_arsize;

    wire                          m_axi_awvalid;
    wire                          m_axi_awready;
    wire [ICB_ADDR_WIDTH-1:0]     m_axi_awaddr;
    wire [3:0]                    m_axi_awcache;
    wire [2:0]                    m_axi_awprot;
    wire [1:0]                    m_axi_awlock;
    wire [1:0]                    m_axi_awburst;
    wire [3:0]                    m_axi_awlen;
    wire [2:0]                    m_axi_awsize;

    wire                          m_axi_rvalid;
    wire                          m_axi_rready;
    wire [BUS_WIDTH-1:0]          m_axi_rdata;
    wire [1:0]                    m_axi_rresp;
    wire                          m_axi_rlast;

    wire                          m_axi_wvalid;
    wire                          m_axi_wready;
    wire [BUS_WIDTH-1:0]          m_axi_wdata;
    wire [BUS_WIDTH/8-1:0]        m_axi_wstrb;
    wire                          m_axi_wlast;

    wire                          m_axi_bvalid;
    wire                          m_axi_bready;
    wire [1:0]                    m_axi_bresp;

    mma_axil_top #(
        .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .BUS_WIDTH(BUS_WIDTH),
        .REG_WIDTH(REG_WIDTH),
        .ICB_ADDR_WIDTH(ICB_ADDR_WIDTH),
        .ICB_LEN_W(ICB_LEN_W),
        .IRQ_STATUS_MASK(IRQ_STATUS_MASK)
    ) u_mma_axil_top (
        .clk(clk),
        .rst_n(rst_n),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awprot(s_axil_awprot),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arprot(s_axil_arprot),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready),

        .m_icb_cmd_valid(legacy_icb_cmd_valid),
        .m_icb_cmd_ready(1'b0),
        .m_icb_cmd_addr(legacy_icb_cmd_addr),
        .m_icb_cmd_read(legacy_icb_cmd_read),
        .m_icb_cmd_len(legacy_icb_cmd_len),
        .m_icb_cmd_wdata(legacy_icb_cmd_wdata),
        .m_icb_cmd_wmask(legacy_icb_cmd_wmask),
        .m_icb_w_valid(legacy_icb_w_valid),
        .m_icb_w_ready(1'b0),
        .m_icb_rsp_valid(1'b0),
        .m_icb_rsp_ready(legacy_icb_rsp_ready),
        .m_icb_rsp_rdata({BUS_WIDTH{1'b0}}),
        .m_icb_rsp_err(1'b0),

        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),

        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),

        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),

        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),

        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),

        .irq(irq),
        .eoi(eoi),

        .mma_busy(mma_busy)
    );

    axi_sim_ram #(
        .DP(MEM_DP),
        .DW(BUS_WIDTH),
        .AW(ICB_ADDR_WIDTH),
        .MEM_PATH(MEM_PATH),
        .INIT_EN(MEM_INIT_EN)
    ) u_axi_sim_ram (
        .clk(clk),
        .rst_n(rst_n),
        .s_axi_awvalid(m_axi_awvalid),
        .s_axi_awready(m_axi_awready),
        .s_axi_awaddr(m_axi_awaddr),
        .s_axi_awcache(m_axi_awcache),
        .s_axi_awprot(m_axi_awprot),
        .s_axi_awlock(m_axi_awlock),
        .s_axi_awburst(m_axi_awburst),
        .s_axi_awlen(m_axi_awlen),
        .s_axi_awsize(m_axi_awsize),
        .s_axi_wvalid(m_axi_wvalid),
        .s_axi_wready(m_axi_wready),
        .s_axi_wdata(m_axi_wdata),
        .s_axi_wstrb(m_axi_wstrb),
        .s_axi_wlast(m_axi_wlast),
        .s_axi_bvalid(m_axi_bvalid),
        .s_axi_bready(m_axi_bready),
        .s_axi_bresp(m_axi_bresp),
        .s_axi_arvalid(m_axi_arvalid),
        .s_axi_arready(m_axi_arready),
        .s_axi_araddr(m_axi_araddr),
        .s_axi_arcache(m_axi_arcache),
        .s_axi_arprot(m_axi_arprot),
        .s_axi_arlock(m_axi_arlock),
        .s_axi_arburst(m_axi_arburst),
        .s_axi_arlen(m_axi_arlen),
        .s_axi_arsize(m_axi_arsize),
        .s_axi_rvalid(m_axi_rvalid),
        .s_axi_rready(m_axi_rready),
        .s_axi_rdata(m_axi_rdata),
        .s_axi_rresp(m_axi_rresp),
        .s_axi_rlast(m_axi_rlast),
        .mem_reload_req(mem_reload_req)
    );

endmodule
