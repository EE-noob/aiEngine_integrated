`ifndef TOP_AI_ENGINE_TB_SV
`define TOP_AI_ENGINE_TB_SV

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

module tb_top #(
    parameter int unsigned DUT_SIZE            = 16,
    parameter int unsigned DUT_IA_CACHE_BLOCKS = 4,
    parameter int unsigned DUT_PS_FRAME_COUNT  = DUT_SIZE,
    parameter int unsigned DUT_CPU_MEM_DP      = 524288,
    parameter int unsigned DUT_AXI_READ_OUTSTANDING  = 4,
    parameter int unsigned DUT_AXI_WRITE_OUTSTANDING = DUT_AXI_READ_OUTSTANDING,
    parameter bit          DUT_BYPASS_RAM_PINGPONG = 1'b1
);

    logic nice_clk;
    logic nice_rst_n;
    logic icb_clk;
    logic icb_rst_n;
    logic cam_pclk;

    nice_if nice_vif (
        .nice_clk  (nice_clk),
        .nice_rst_n(nice_rst_n)
    );

    axil_if #(
        .AXIL_ADDR_WIDTH(16),
        .AXIL_DATA_WIDTH(32)
    ) axil_vif (
        .clk  (nice_clk),
        .rst_n(nice_rst_n)
    );

`ifndef DUT_AXIL
`ifndef DUT_AXI_SOC
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
    logic [3:0]                 nice_icb_cmd_wmask;
`endif
`endif

`ifdef DUT_AXIL
    logic                       mma_busy;
    logic [31:0]                mma_irq;
    logic [31:0]                mma_eoi;
    localparam int unsigned     AXIL_MEM_DP = 131072;

    assign mma_eoi = 32'h0;
    assign axil_vif.mma_irq = mma_irq;
    assign axil_vif.mma_status = u_axil_top_with_ram.u_mma_axil_top.status_bits;
`endif

`ifdef DUT_AXI_SOC
    logic                       soc_mma_busy;
    logic [31:0]                soc_mma_irq;
    logic [31:0]                soc_mma_eoi;
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
        .BYPASS_RAM_PINGPONG(DUT_BYPASS_RAM_PINGPONG),
        .CPU_MEM_PATH("../tb/axi_soc_case/cpu.mem")
    ) u_soc_top (
        .clk            (nice_clk),
        .rst_n          (nice_rst_n),
        .mem_reload_req (nice_vif.mem_reload_req),
        .mma_busy       (soc_mma_busy),
        .mma_irq        (soc_mma_irq),
        .mma_eoi        (soc_mma_eoi),
        .uart_tx        (soc_uart_tx),
        .uart_rx        (soc_uart_rx),
        .soc_finish     (soc_finish),
        .soc_status     (soc_status),
        .cpu_trap       (cpu_trap)
    );

    assign nice_vif.nice_active     = 1'b0;
    assign nice_vif.nice_mem_holdup = 1'b0;
    assign nice_vif.nice_req_ready  = 1'b0;
    assign nice_vif.nice_rsp_valid  = 1'b0;
    assign nice_vif.nice_rsp_rdat   = 32'h0;
    assign nice_vif.nice_rsp_err    = 1'b0;
    assign nice_vif.nice_icb_cmd_valid = 1'b0;
    assign nice_vif.nice_icb_cmd_ready = 1'b0;
    assign nice_vif.nice_icb_cmd_addr  = 32'h0;
    assign nice_vif.nice_icb_cmd_read  = 1'b0;
    assign nice_vif.nice_icb_cmd_wdata = 32'h0;
    assign nice_vif.nice_icb_cmd_size  = 2'b0;
    assign nice_vif.nice_icb_rsp_valid = 1'b0;
    assign nice_vif.nice_icb_rsp_ready = 1'b0;
    assign nice_vif.nice_icb_rsp_rdata = 32'h0;
    assign nice_vif.nice_icb_rsp_err   = 1'b0;
`elsif DUT_AXIL
    axil_top_with_ram #(
        .AXIL_DATA_WIDTH(32),
        .AXIL_ADDR_WIDTH(16),
        .ICB_ADDR_WIDTH(32),
        .ICB_LEN_W(4),
        .SIZE(DUT_SIZE),
        .IA_CACHE_BLOCKS(DUT_IA_CACHE_BLOCKS),
        .PS_FRAME_COUNT(DUT_PS_FRAME_COUNT),
        .MEM_DP(AXIL_MEM_DP),
        .MEM_PATH("../tb/main_extram.mem"),
        .MEM_INIT_EN(1)
    ) u_axil_top_with_ram (
        .clk             (nice_clk),
        .rst_n           (nice_rst_n),
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
        .irq             (mma_irq),
        .eoi             (mma_eoi),
        .mem_reload_req  (nice_vif.mem_reload_req),
        .mma_busy        (mma_busy)
    );
    assign nice_vif.nice_active     = 1'b0;
    assign nice_vif.nice_mem_holdup = 1'b0;
    assign nice_vif.nice_req_ready  = 1'b0;
    assign nice_vif.nice_rsp_valid  = 1'b0;
    assign nice_vif.nice_rsp_rdat   = 32'h0;
    assign nice_vif.nice_rsp_err    = 1'b0;
    assign nice_vif.nice_icb_cmd_valid = 1'b0;
    assign nice_vif.nice_icb_cmd_ready = 1'b0;
    assign nice_vif.nice_icb_cmd_addr  = 32'h0;
    assign nice_vif.nice_icb_cmd_read  = 1'b0;
    assign nice_vif.nice_icb_cmd_wdata = 32'h0;
    assign nice_vif.nice_icb_cmd_size  = 2'b0;
    assign nice_vif.nice_icb_rsp_valid = 1'b0;
    assign nice_vif.nice_icb_rsp_ready = 1'b0;
    assign nice_vif.nice_icb_rsp_rdata = 32'h0;
    assign nice_vif.nice_icb_rsp_err   = 1'b0;
`else
    top_ai_engine u_top_ai_engine (
        .nice_clk          (nice_clk),
        .nice_rst_n        (nice_rst_n),
        .nice_active       (nice_vif.nice_active),
        .nice_mem_holdup   (nice_vif.nice_mem_holdup),
        .nice_req_valid    (nice_vif.nice_req_valid),
        .nice_req_ready    (nice_vif.nice_req_ready),
        .nice_req_inst     (nice_vif.nice_req_inst),
        .nice_req_rs1      (nice_vif.nice_req_rs1),
        .nice_req_rs2      (nice_vif.nice_req_rs2),
        .nice_rsp_valid    (nice_vif.nice_rsp_valid),
        .nice_rsp_ready    (nice_vif.nice_rsp_ready),
        .nice_rsp_rdat     (nice_vif.nice_rsp_rdat),
        .nice_rsp_err      (nice_vif.nice_rsp_err),
        .nice_icb_cmd_valid(nice_icb_cmd_valid),
        .nice_icb_cmd_ready(nice_icb_cmd_ready),
        .nice_icb_cmd_addr (nice_icb_cmd_addr),
        .nice_icb_cmd_read (nice_icb_cmd_read),
        .nice_icb_cmd_wdata(nice_icb_cmd_wdata),
        .nice_icb_cmd_size (nice_icb_cmd_size),
        .nice_icb_cmd_wmask(nice_icb_cmd_wmask),
        .nice_icb_rsp_valid(nice_icb_rsp_valid),
        .nice_icb_rsp_ready(nice_icb_rsp_ready),
        .nice_icb_rsp_rdata(nice_icb_rsp_rdata),
        .nice_icb_rsp_err  (nice_icb_rsp_err),
        .icb_clk           (icb_clk),
        .icb_rst_n         (icb_rst_n),
        .dcmi_icb_cmd_valid(1'b0),
        .dcmi_icb_cmd_ready(),
        .dcmi_icb_cmd_addr ('0),
        .dcmi_icb_cmd_read (1'b0),
        .dcmi_icb_cmd_wdata('0),
        .dcmi_icb_cmd_wmask('0),
        .dcmi_icb_rsp_valid(),
        .dcmi_icb_rsp_ready(1'b1),
        .dcmi_icb_rsp_rdata(),
        .cam_pclk          (cam_pclk),
        .cam_rst_n         (),
        .cam_vsync         (1'b0),
        .cam_href          (1'b0),
        .cam_data          (8'b0)
    );

    sram_icb #( ) u_sram_icb (
        .clk             (nice_clk),
        .rst_n           (nice_rst_n),
        .i_icb_cmd_valid (nice_icb_cmd_valid),
        .i_icb_cmd_ready (nice_icb_cmd_ready),
        .i_icb_cmd_read  (nice_icb_cmd_read),
        .i_icb_cmd_addr  (nice_icb_cmd_addr),
        .i_icb_cmd_wdata (nice_icb_cmd_wdata),
        .i_icb_cmd_wmask (nice_icb_cmd_wmask),
        .i_icb_cmd_usr   (1'b0),
        .i_icb_rsp_valid (nice_icb_rsp_valid),
        .i_icb_rsp_ready (nice_icb_rsp_ready),
        .i_icb_rsp_rdata (nice_icb_rsp_rdata),
        .i_icb_rsp_usr   (),
        .tcm_cgstop      (1'b0),
        .test_mode       (1'b0),
        .mem_reload_req  (nice_vif.mem_reload_req)
    );
    assign nice_icb_rsp_err = 1'b0;
`endif

    initial begin
        nice_clk = 1'b0;
        icb_clk  = 1'b0;
        cam_pclk = 1'b0;
        forever begin
            #5ns  nice_clk = ~nice_clk;
            #5ns  icb_clk  = ~icb_clk;
            #5ns  cam_pclk = ~cam_pclk;
        end
    end

    initial begin
        nice_rst_n = 1'b0;
        icb_rst_n  = 1'b0;
        repeat (3) @(posedge nice_clk);
        nice_rst_n = 1'b1;
        icb_rst_n  = 1'b1;
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
        wait (nice_rst_n === 1'b1);
        repeat (4) @(posedge nice_clk);
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
            repeat (pico_uart_bit_period + pico_uart_half_period) @(posedge nice_clk);

            for (pico_uart_bit_idx = 0; pico_uart_bit_idx < 8; pico_uart_bit_idx++) begin
                pico_uart_buffer[pico_uart_bit_idx] = soc_uart_tx;
                if (pico_uart_bit_idx != 7) begin
                    repeat (pico_uart_bit_period) @(posedge nice_clk);
                end
            end

            repeat (pico_uart_bit_period) @(posedge nice_clk);

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
        wait (nice_rst_n === 1'b1);
        if (soc_progress_trace) begin
            $display("[SOC_PROGRESS] trace enabled");
        end
        forever begin
            @(posedge nice_clk);
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
        cfg.dut_kind = AI_DUT_NICE;
`endif

        if ($value$plusargs("DUT_SEL=%s", dut_sel)) begin
            if ((dut_sel == "axil") || (dut_sel == "AXIL")) begin
                cfg.dut_kind = AI_DUT_AXIL;
            end else if ((dut_sel == "axi_soc") || (dut_sel == "AXI_SOC")) begin
                cfg.dut_kind = AI_DUT_AXI_SOC;
            end else begin
                cfg.dut_kind = AI_DUT_NICE;
            end
        end

        uvm_config_db#(ai_env_cfg)::set(uvm_root::get(), "*", "cfg", cfg);
        uvm_config_db#(virtual nice_if)::set(uvm_root::get(), "*", "vif", nice_vif);
        uvm_config_db#(virtual axil_if)::set(uvm_root::get(), "*", "axil_vif", axil_vif);

        if (!$value$plusargs("UVM_TESTNAME=%s", testname)) begin
            testname = "ai_smoke_test";
        end

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
