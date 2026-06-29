`ifndef NICE_IF_SV
`define NICE_IF_SV

interface nice_if (
    input  logic nice_clk,
    input  logic nice_rst_n
);

    // Request/response between external master and nice-core
    logic                       nice_active;
    logic                       nice_mem_holdup;
    logic                       nice_req_valid;
    logic                       nice_req_ready;
    logic [31:0]                nice_req_inst;
    logic [31:0]                nice_req_rs1;
    logic [31:0]                nice_req_rs2;
    logic                       nice_rsp_valid;
    logic                       nice_rsp_ready;
    logic [31:0]                nice_rsp_rdat;
    logic                       nice_rsp_err;

    // Trigger memory reload in SRAM model after python mem generation.
    logic                       mem_reload_req;

    // ICB interface towards memory (monitor only)
    logic                       nice_icb_cmd_valid;
    logic                       nice_icb_cmd_ready;
    logic [31:0]                nice_icb_cmd_addr;
    logic                       nice_icb_cmd_read;
    logic [31:0]                nice_icb_cmd_wdata;
    logic [1:0]                 nice_icb_cmd_size;
    logic                       nice_icb_rsp_valid;
    logic                       nice_icb_rsp_ready;
    logic [31:0]                nice_icb_rsp_rdata;
    logic                       nice_icb_rsp_err;

    // MMA monitor <-> UVM monitor synchronization (no package dependency)
    logic                       mma_calc_start_toggle;
    logic                       mma_wb_handshake_toggle;
    logic [1:0]                 mma_err_code;

    // Driver clocking block
    clocking drv_cb @(posedge nice_clk);
        default input #1step output #1step;
        output nice_req_valid;
        output nice_req_inst;
        output nice_req_rs1;
        output nice_req_rs2;
        output nice_rsp_ready;
        output mem_reload_req;
        input  nice_req_ready;
        input  nice_rsp_valid;
        input  nice_rsp_rdat;
        input  nice_rsp_err;
    endclocking

    // Monitor clocking block (read-only view)
    clocking mon_cb @(posedge nice_clk);
        default input #1step output #1step;
        input nice_active;
        input nice_mem_holdup;
        input nice_req_valid;
        input nice_req_ready;
        input nice_req_inst;
        input nice_req_rs1;
        input nice_req_rs2;
        input nice_rsp_valid;
        input nice_rsp_ready;
        input nice_rsp_rdat;
        input nice_rsp_err;
        input mem_reload_req;
        input nice_icb_cmd_valid;
        input nice_icb_cmd_ready;
        input nice_icb_cmd_addr;
        input nice_icb_cmd_read;
        input nice_icb_cmd_wdata;
        input nice_icb_cmd_size;
        input nice_icb_rsp_valid;
        input nice_icb_rsp_ready;
        input nice_icb_rsp_rdata;
        input nice_icb_rsp_err;
        input mma_calc_start_toggle;
        input mma_wb_handshake_toggle;
        input mma_err_code;
    endclocking


    // SRAM helpers used by class-based UVM components to avoid illegal package XMR.
    function automatic bit [31:0] read_sram_word(input int unsigned word_addr);
`ifdef DUT_AXI_SOC
        read_sram_word = $root.tb_top.u_soc_top.cpu_mem[word_addr];
`elsif DUT_AXIL
        read_sram_word = $root.tb_top.u_axil_top_with_ram.u_axi_sim_ram.mem_r[word_addr];
`else
        read_sram_word = $root.tb_top.u_sram_icb.u_sram.u_sirv_sim_ram.mem_r[word_addr];
`endif
    endfunction

    task automatic check_main_extram_mem(output int mismatch_cnt);
`ifdef DUT_AXI_SOC
        mismatch_cnt = 0;
`elsif DUT_AXIL
        mismatch_cnt = 0;
        $root.tb_top.u_axil_top_with_ram.u_axi_sim_ram.check_mem_file("../tb/main_extram.mem", 0, 127, mismatch_cnt);
`else
        mismatch_cnt = 0;
        $root.tb_top.u_sram_icb.u_sram.u_sirv_sim_ram.check_mem_file("../tb/main_extram.mem", 0, 127, mismatch_cnt);
`endif
    endtask

    modport drv (
        input  nice_clk,
        input  nice_rst_n,
        clocking drv_cb
    );

    modport mon (
        input  nice_clk,
        input  nice_rst_n,
        clocking mon_cb
    );

endinterface

`endif
