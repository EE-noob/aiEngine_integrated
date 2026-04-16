`ifndef AXIL_IF_SV
`define AXIL_IF_SV

interface axil_if #(
    parameter int AXIL_ADDR_WIDTH = 16,
    parameter int AXIL_DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n
);

    logic [AXIL_ADDR_WIDTH-1:0] awaddr;
    logic [2:0]                 awprot;
    logic                       awvalid;
    logic                       awready;

    logic [AXIL_DATA_WIDTH-1:0] wdata;
    logic [AXIL_DATA_WIDTH/8-1:0] wstrb;
    logic                       wvalid;
    logic                       wready;

    logic [1:0]                 bresp;
    logic                       bvalid;
    logic                       bready;

    logic [AXIL_ADDR_WIDTH-1:0] araddr;
    logic [2:0]                 arprot;
    logic                       arvalid;
    logic                       arready;

    logic [AXIL_DATA_WIDTH-1:0] rdata;
    logic [1:0]                 rresp;
    logic                       rvalid;
    logic                       rready;

    clocking drv_cb @(posedge clk);
        default input #1step output #1step;
        output awaddr, awprot, awvalid;
        input  awready;
        output wdata, wstrb, wvalid;
        input  wready;
        input  bresp, bvalid;
        output bready;
        output araddr, arprot, arvalid;
        input  arready;
        input  rdata, rresp, rvalid;
        output rready;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input awaddr, awprot, awvalid, awready;
        input wdata, wstrb, wvalid, wready;
        input bresp, bvalid, bready;
        input araddr, arprot, arvalid, arready;
        input rdata, rresp, rvalid, rready;
    endclocking

endinterface

`endif
