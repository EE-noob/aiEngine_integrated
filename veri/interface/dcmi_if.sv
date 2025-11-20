`ifndef DCMI_IF_SV
`define DCMI_IF_SV

interface dcmi_if (
    input  logic icb_clk,
    input  logic icb_rst_n
);

    logic             dcmi_icb_cmd_valid;
    logic             dcmi_icb_cmd_ready;
    logic [31:0]      dcmi_icb_cmd_addr;
    logic             dcmi_icb_cmd_read;
    logic [31:0]      dcmi_icb_cmd_wdata;
    logic [3:0]       dcmi_icb_cmd_wmask;
    logic             dcmi_icb_rsp_valid;
    logic             dcmi_icb_rsp_ready;
    logic [31:0]      dcmi_icb_rsp_rdata;

    clocking drv_cb @(posedge icb_clk);
        default input #1step output #1step;
        output dcmi_icb_cmd_valid;
        output dcmi_icb_cmd_addr;
        output dcmi_icb_cmd_read;
        output dcmi_icb_cmd_wdata;
        output dcmi_icb_cmd_wmask;
        output dcmi_icb_rsp_ready;
        input  dcmi_icb_cmd_ready;
        input  dcmi_icb_rsp_valid;
        input  dcmi_icb_rsp_rdata;
    endclocking

    clocking mon_cb @(posedge icb_clk);
        default input #1step output #1step;
        input dcmi_icb_cmd_valid;
        input dcmi_icb_cmd_ready;
        input dcmi_icb_cmd_addr;
        input dcmi_icb_cmd_read;
        input dcmi_icb_cmd_wdata;
        input dcmi_icb_cmd_wmask;
        input dcmi_icb_rsp_valid;
        input dcmi_icb_rsp_ready;
        input dcmi_icb_rsp_rdata;
    endclocking

    modport drv (
        input  icb_clk,
        input  icb_rst_n,
        clocking drv_cb
    );

    modport mon (
        input  icb_clk,
        input  icb_rst_n,
        clocking mon_cb
    );

endinterface

`endif

