`ifndef TOP_AI_ENGINE_TB_SV
`define TOP_AI_ENGINE_TB_SV

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

module tb_top #(
    parameter int unsigned DUT_SIZE            = 16,
    parameter int unsigned DUT_IA_CACHE_BLOCKS = 4,
    parameter int unsigned DUT_PS_FRAME_COUNT  = DUT_SIZE,
    parameter int unsigned DUT_CPU_MEM_DP      = 65536,
    parameter int unsigned DUT_AXI_READ_OUTSTANDING  = 4,
    parameter int unsigned DUT_AXI_WRITE_OUTSTANDING = DUT_AXI_READ_OUTSTANDING,
    parameter bit          DUT_CPU_ENABLE_ICACHE = 1'b0,
    parameter bit          DUT_BYPASS_RAM_PINGPONG = 1'b1,
    parameter bit          DUT_RAM_WRITE_TIMING_BUFFER = 1'b1
);

    logic tb_clk;
    logic tb_rst_n;

    tb_ctrl_if tb_ctrl_vif (
        .clk  (tb_clk),
        .rst_n(tb_rst_n)
    );

    axil_if #(
        .AXIL_ADDR_WIDTH(16),
        .AXIL_DATA_WIDTH(32)
    ) axil_vif (
        .clk  (tb_clk),
        .rst_n(tb_rst_n)
    );

`ifdef DUT_AXIL
    logic                       npu_busy;
    logic                       npu_irq;
    localparam int unsigned     AXIL_MEM_DP = 131072;

    assign axil_vif.npu_irq = npu_irq;
    assign axil_vif.npu_status = u_axil_top_with_ram.u_npu_axil_top.status_bits;
`endif

`ifdef DUT_AXI_SOC
    logic                       soc_npu_busy;
    logic                       soc_npu_irq;
    logic                       soc_finish;
    logic [31:0]                soc_status;
    logic                       cpu_trap;
    logic                       soc_uart_tx;
    logic                       soc_uart_rx;
    localparam int unsigned     AXI_SOC_CPU_MEM_DP = DUT_CPU_MEM_DP;

    assign soc_uart_rx = 1'b1;

    soc_top #(
        .SIZE(DUT_SIZE),
        .IA_CACHE_BLOCKS(DUT_IA_CACHE_BLOCKS),
        .PS_FRAME_COUNT(DUT_PS_FRAME_COUNT),
        .AXI_READ_OUTSTANDING(DUT_AXI_READ_OUTSTANDING),
        .AXI_WRITE_OUTSTANDING(DUT_AXI_WRITE_OUTSTANDING),
        .CPU_MEM_DP(AXI_SOC_CPU_MEM_DP),
        .CPU_ENABLE_ICACHE(DUT_CPU_ENABLE_ICACHE),
        .BYPASS_RAM_PINGPONG(DUT_BYPASS_RAM_PINGPONG),
        .RAM_WRITE_TIMING_BUFFER(DUT_RAM_WRITE_TIMING_BUFFER),
        .CPU_MEM_PATH("../tb/axi_soc_case/cpu.mem")
    ) u_soc_top (
        .clk            (tb_clk),
        .rst_n          (tb_rst_n),
        .mem_reload_req (tb_ctrl_vif.mem_reload_req),
        .npu_busy       (soc_npu_busy),
        .npu_irq        (soc_npu_irq),
        .uart_tx        (soc_uart_tx),
        .uart_rx        (soc_uart_rx),
        .soc_finish     (soc_finish),
        .soc_status     (soc_status),
        .cpu_trap       (cpu_trap)
    );

`elsif DUT_AXIL
    axil_top_with_ram #(
        .AXIL_DATA_WIDTH(32),
        .AXIL_ADDR_WIDTH(16),
        .SIZE(DUT_SIZE),
        .IA_CACHE_BLOCKS(DUT_IA_CACHE_BLOCKS),
        .PS_FRAME_COUNT(DUT_PS_FRAME_COUNT),
        .MEM_DP(AXIL_MEM_DP),
        .MEM_PATH("../tb/main_extram.mem"),
        .MEM_INIT_EN(1)
    ) u_axil_top_with_ram (
        .clk             (tb_clk),
        .rst_n           (tb_rst_n),
        .s_axil_awaddr   (axil_vif.awaddr),
        .s_axil_awprot   (axil_vif.awprot),
        .s_axil_awvalid  (axil_vif.awvalid),
        .s_axil_awready  (axil_vif.awready),
        .s_axil_wdata    (axil_vif.wdata),
        .s_axil_wstrb    (axil_vif.wstrb),
        .s_axil_wvalid   (axil_vif.wvalid),
        .s_axil_wready   (axil_vif.wready),
        .s_axil_bresp    (axil_vif.bresp),
        .s_axil_bvalid   (axil_vif.bvalid),
        .s_axil_bready   (axil_vif.bready),
        .s_axil_araddr   (axil_vif.araddr),
        .s_axil_arprot   (axil_vif.arprot),
        .s_axil_arvalid  (axil_vif.arvalid),
        .s_axil_arready  (axil_vif.arready),
        .s_axil_rdata    (axil_vif.rdata),
        .s_axil_rresp    (axil_vif.rresp),
        .s_axil_rvalid   (axil_vif.rvalid),
        .s_axil_rready   (axil_vif.rready),
        .irq             (npu_irq),
        .mem_reload_req  (tb_ctrl_vif.mem_reload_req),
        .npu_busy        (npu_busy)
    );
`else
    initial begin
        $fatal(1, "Unsupported DUT build: define DUT_AXIL or DUT_AXI_SOC");
    end
`endif

    initial begin
        tb_clk = 1'b0;
        forever #5ns tb_clk = ~tb_clk;
    end

    initial begin
        tb_rst_n = 1'b0;
        tb_ctrl_vif.mem_reload_req = 1'b0;
        tb_ctrl_vif.npu_calc_start_toggle = 1'b0;
        tb_ctrl_vif.npu_done_handshake_toggle = 1'b0;
        tb_ctrl_vif.npu_err_code = 2'b00;
        repeat (3) @(posedge tb_clk);
        tb_rst_n = 1'b1;
    end

`ifdef DUT_AXI_SOC
    integer pico_uart_bit_period;
    integer pico_uart_half_period;
    reg [7:0] pico_uart_buffer;
    integer pico_uart_bit_idx;
    bit soc_progress_trace;
    logic [31:0] soc_progress_last;

    initial begin : pico_uart_monitor
        pico_uart_buffer = 8'h00;
        wait (tb_rst_n === 1'b1);
        repeat (4) @(posedge tb_clk);
	        $display("[PICO_UART] monitor enabled on soc_top.u_soc_uart.u_simpleuart.ser_tx");
        forever begin
            @(negedge soc_uart_tx);

            pico_uart_bit_period = $root.tb_top.u_soc_top.u_soc_uart.cfg_divider + 2;
            if (pico_uart_bit_period < 2) begin
                pico_uart_bit_period = 2;
            end
            pico_uart_half_period = pico_uart_bit_period / 2;
            if (pico_uart_half_period < 1) begin
                pico_uart_half_period = 1;
            end

            pico_uart_buffer = 8'h00;
            repeat (pico_uart_bit_period + pico_uart_half_period) @(posedge tb_clk);

            for (pico_uart_bit_idx = 0; pico_uart_bit_idx < 8; pico_uart_bit_idx++) begin
                pico_uart_buffer[pico_uart_bit_idx] = soc_uart_tx;
                if (pico_uart_bit_idx != 7) begin
                    repeat (pico_uart_bit_period) @(posedge tb_clk);
                end
            end

            repeat (pico_uart_bit_period) @(posedge tb_clk);

            if (pico_uart_buffer == 8'h0d) begin
                // Drop CR; BSP prints CRLF and the simulator console only needs LF.
            end else if (pico_uart_buffer == 8'h0a) begin
                $write("\n");
            end else if ((pico_uart_buffer >= 8'h20) && (pico_uart_buffer < 8'h7f)) begin
                $write("%c", pico_uart_buffer);
            end else begin
                $write("<%02x>", pico_uart_buffer);
            end
        end
    end

    initial begin : soc_progress_monitor
        soc_progress_trace = $test$plusargs("SOC_PROGRESS_TRACE");
        soc_progress_last = 32'hffff_ffff;
        wait (tb_rst_n === 1'b1);
        if (soc_progress_trace) begin
            $display("[SOC_PROGRESS] trace enabled");
        end
        forever begin
            @(posedge tb_clk);
            if (soc_progress_trace && (u_soc_top.soc_progress !== soc_progress_last)) begin
                soc_progress_last = u_soc_top.soc_progress;
                $display("[SOC_PROGRESS] time=%0t progress=0x%08h", $time, soc_progress_last);
            end
        end
    end
`endif

    initial begin
        string testname;
        string dut_sel;
        ai_env_cfg cfg;

        cfg = ai_env_cfg::type_id::create("cfg");
`ifdef DUT_AXIL
        cfg.dut_kind = AI_DUT_AXIL;
`elsif DUT_AXI_SOC
        cfg.dut_kind = AI_DUT_AXI_SOC;
`else
        cfg.dut_kind = AI_DUT_AXIL;
`endif

        if ($value$plusargs("DUT_SEL=%s", dut_sel)) begin
            if ((dut_sel == "axil") || (dut_sel == "AXIL")) begin
                cfg.dut_kind = AI_DUT_AXIL;
            end else if ((dut_sel == "axi_soc") || (dut_sel == "AXI_SOC")) begin
                cfg.dut_kind = AI_DUT_AXI_SOC;
            end else begin
                `uvm_fatal("DUT_SEL", $sformatf("Unsupported DUT_SEL=%s; use axil or axi_soc", dut_sel))
            end
        end

        uvm_config_db#(ai_env_cfg)::set(uvm_root::get(), "*", "cfg", cfg);
        uvm_config_db#(virtual tb_ctrl_if)::set(uvm_root::get(), "*", "tb_ctrl_vif", tb_ctrl_vif);
        uvm_config_db#(virtual axil_if)::set(uvm_root::get(), "*", "axil_vif", axil_vif);

        if (!$value$plusargs("UVM_TESTNAME=%s", testname)) begin
            testname = "ai_mem_gen_smoke_test";
        end

        uvm_config_db#(int unsigned)::set(null,"*","gempact_size",DUT_SIZE);
        uvm_config_db#(int unsigned)::set(null,"*","gempact_cache",DUT_IA_CACHE_BLOCKS);
        uvm_config_db#(int unsigned)::set(null,"*","gempact_ps",DUT_PS_FRAME_COUNT);
        run_test(testname);
    end

    initial begin
       if ($test$plusargs("dump_fsdb")) begin
            string fsdb_name;
            if (!$value$plusargs("fsdbfile+%s", fsdb_name)) begin
                fsdb_name = "tb_top.fsdb";
            end
            $fsdbDumpfile(fsdb_name);
            $fsdbDumpvars(0,"+all");
            $fsdbDumpSVA();
            $fsdbDumpMDA();
        end
    end

endmodule : tb_top

`endif
