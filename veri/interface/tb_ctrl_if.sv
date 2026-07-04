`ifndef TB_CTRL_IF_SV
`define TB_CTRL_IF_SV

interface tb_ctrl_if (
    input logic clk,
    input logic rst_n
);

    // Testbench-side controls and NPU monitor synchronization.
    logic       mem_reload_req;
    logic       npu_calc_start_toggle;
    logic       npu_done_handshake_toggle;
    logic [1:0] npu_err_code;

    clocking drv_cb @(posedge clk);
        default input #1step output #1step;
        output mem_reload_req;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step output #1step;
        input mem_reload_req;
        input npu_calc_start_toggle;
        input npu_done_handshake_toggle;
        input npu_err_code;
    endclocking

    function automatic bit [31:0] read_sram_word(input int unsigned word_addr);
`ifdef DUT_AXI_SOC
        read_sram_word = $root.tb_top.u_soc_top.u_axi_sim_ram.mem_r[word_addr];
`elsif DUT_AXIL
        read_sram_word = $root.tb_top.u_axil_top_with_ram.u_axi_sim_ram.mem_r[word_addr];
`else
        read_sram_word = 32'h0;
`endif
    endfunction

    task automatic check_main_extram_mem(output int mismatch_cnt);
`ifdef DUT_AXIL
        mismatch_cnt = 0;
        $root.tb_top.u_axil_top_with_ram.u_axi_sim_ram.check_mem_file("../tb/main_extram.mem", 0, 127, mismatch_cnt);
`else
        mismatch_cnt = 0;
`endif
    endtask

    modport drv (
        input  clk,
        input  rst_n,
        clocking drv_cb
    );

    modport mon (
        input  clk,
        input  rst_n,
        clocking mon_cb
    );

endinterface

`endif
