`ifndef AI_NICE_IF_SV
`define AI_NICE_IF_SV

interface nice_if(
    input logic nice_clk,
    input logic nice_rst_n
);

    // NICE Request Channel (CPU -> NICE Core)
    logic        nice_req_valid;
    logic        nice_req_ready;
    logic [31:0] nice_req_inst;
    logic [31:0] nice_req_rs1;
    logic [31:0] nice_req_rs2;

    // NICE Response Channel (NICE Core -> CPU)
    logic        nice_rsp_valid;
    logic        nice_rsp_ready;
    logic [31:0] nice_rsp_rdat;
    logic        nice_rsp_err;

    // NICE Status
    logic        nice_active;
    logic        nice_mem_holdup;

    // ICB Interface (NICE Core -> Memory)
    logic        nice_icb_cmd_valid;
    logic        nice_icb_cmd_ready;
    logic [31:0] nice_icb_cmd_addr;
    logic        nice_icb_cmd_read;
    logic [31:0] nice_icb_cmd_wdata;
    logic [1:0]  nice_icb_cmd_size;
    logic        nice_icb_rsp_valid;
    logic        nice_icb_rsp_ready;
    logic [31:0] nice_icb_rsp_rdata;
    logic        nice_icb_rsp_err;

    // Clocking block for driver (drives request, samples response)
    clocking drv_cb @(posedge nice_clk);
        default input #1step output #1ns;
        
        output nice_req_valid;
        output nice_req_inst;
        output nice_req_rs1;
        output nice_req_rs2;
        output nice_rsp_ready;
        
        input  nice_req_ready;
        input  nice_rsp_valid;
        input  nice_rsp_rdat;
        input  nice_rsp_err;
        input  nice_active;
        input  nice_mem_holdup;
    endclocking

    // Clocking block for monitor
    clocking mon_cb @(posedge nice_clk);
        default input #1step;
        
        input nice_req_valid;
        input nice_req_ready;
        input nice_req_inst;
        input nice_req_rs1;
        input nice_req_rs2;
        input nice_rsp_valid;
        input nice_rsp_ready;
        input nice_rsp_rdat;
        input nice_rsp_err;
        input nice_icb_cmd_valid;
        input nice_icb_cmd_ready;
        input nice_icb_cmd_addr;
        input nice_icb_cmd_read;
    endclocking

    // Modports
    modport driver (clocking drv_cb, input nice_clk, input nice_rst_n);
    modport monitor (clocking mon_cb, input nice_clk, input nice_rst_n);

endinterface

`endif
