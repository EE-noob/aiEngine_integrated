`ifndef TOP_AI_ENGINE_TB_SV
`define TOP_AI_ENGINE_TB_SV

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

module tb_top;

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

`ifdef DUT_AXIL
    logic                       m_icb_cmd_valid;
    logic                       m_icb_cmd_ready;
    logic [31:0]                m_icb_cmd_addr;
    logic                       m_icb_cmd_read;
    logic [3:0]                 m_icb_cmd_len;
    logic [31:0]                m_icb_cmd_wdata;
    logic [3:0]                 m_icb_cmd_wmask;
    logic                       m_icb_w_valid;
    logic                       m_icb_w_ready;
    logic                       m_icb_rsp_valid;
    logic                       m_icb_rsp_ready;
    logic [31:0]                m_icb_rsp_rdata;
    logic                       m_icb_rsp_err;
    logic                       mma_busy;
`endif

`ifndef DUT_AXIL
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
`else
    mma_axil_top #(
        .AXIL_DATA_WIDTH(32),
        .AXIL_ADDR_WIDTH(16),
        .ICB_ADDR_WIDTH(32),
        .ICB_LEN_W(4)
    ) u_mma_axil_top (
        .clk              (nice_clk),
        .rst_n            (nice_rst_n),
        .s_axil_awaddr    (axil_vif.awaddr),
        .s_axil_awprot    (axil_vif.awprot),
        .s_axil_awvalid   (axil_vif.awvalid),
        .s_axil_awready   (axil_vif.awready),
        .s_axil_wdata     (axil_vif.wdata),
        .s_axil_wstrb     (axil_vif.wstrb),
        .s_axil_wvalid    (axil_vif.wvalid),
        .s_axil_wready    (axil_vif.wready),
        .s_axil_bresp     (axil_vif.bresp),
        .s_axil_bvalid    (axil_vif.bvalid),
        .s_axil_bready    (axil_vif.bready),
        .s_axil_araddr    (axil_vif.araddr),
        .s_axil_arprot    (axil_vif.arprot),
        .s_axil_arvalid   (axil_vif.arvalid),
        .s_axil_arready   (axil_vif.arready),
        .s_axil_rdata     (axil_vif.rdata),
        .s_axil_rresp     (axil_vif.rresp),
        .s_axil_rvalid    (axil_vif.rvalid),
        .s_axil_rready    (axil_vif.rready),
        .m_icb_cmd_valid  (m_icb_cmd_valid),
        .m_icb_cmd_ready  (m_icb_cmd_ready),
        .m_icb_cmd_addr   (m_icb_cmd_addr),
        .m_icb_cmd_read   (m_icb_cmd_read),
        .m_icb_cmd_len    (m_icb_cmd_len),
        .m_icb_cmd_wdata  (m_icb_cmd_wdata),
        .m_icb_cmd_wmask  (m_icb_cmd_wmask),
        .m_icb_w_valid    (m_icb_w_valid),
        .m_icb_w_ready    (m_icb_w_ready),
        .m_icb_rsp_valid  (m_icb_rsp_valid),
        .m_icb_rsp_ready  (m_icb_rsp_ready),
        .m_icb_rsp_rdata  (m_icb_rsp_rdata),
        .m_icb_rsp_err    (m_icb_rsp_err),
        .mma_busy         (mma_busy)
    );

      wire                      axil_sram_icb_cmd_valid;
      wire                      axil_sram_icb_cmd_ready;
      wire                      axil_sram_icb_cmd_read;
      wire [31:0]               axil_sram_icb_cmd_addr;
      wire [31:0]               axil_sram_icb_cmd_wdata;
      wire [3:0]                axil_sram_icb_cmd_wmask;
      wire                      axil_sram_icb_rsp_valid;
      wire                      axil_sram_icb_rsp_ready;
      wire [31:0]               axil_sram_icb_rsp_rdata;
      wire                      axil_sram_icb_rsp_err;

      // AXIL path should use the same bridge as NICE path.
      // The ad-hoc cmd/w valid merge can block MMA progress and wb_valid.
      icb_unalign_bridge #(
          .WIDTH(32),
          .ADDR_W(32),
          .OUTS_DEPTH(16),
          .ICB_LEN_W(4)
      ) u_axil_icb_bridge (
          .clk             (nice_clk),
          .rst_n           (nice_rst_n),
          .sa_icb_cmd_valid(m_icb_cmd_valid),
          .sa_icb_cmd_ready(m_icb_cmd_ready),
          .sa_icb_cmd_addr (m_icb_cmd_addr),
          .sa_icb_cmd_read (m_icb_cmd_read),
          .sa_icb_cmd_len  (m_icb_cmd_len),
          .sa_icb_cmd_wdata(m_icb_cmd_wdata),
          .sa_icb_cmd_wmask(m_icb_cmd_wmask),
          .sa_icb_w_valid  (m_icb_w_valid),
          .sa_icb_w_ready  (m_icb_w_ready),
          .sa_icb_rsp_valid(m_icb_rsp_valid),
          .sa_icb_rsp_ready(m_icb_rsp_ready),
          .sa_icb_rsp_rdata(m_icb_rsp_rdata),
          .sa_icb_rsp_err  (m_icb_rsp_err),
          .m_icb_cmd_valid (axil_sram_icb_cmd_valid),
          .m_icb_cmd_ready (axil_sram_icb_cmd_ready),
          .m_icb_cmd_addr  (axil_sram_icb_cmd_addr),
          .m_icb_cmd_read  (axil_sram_icb_cmd_read),
          .m_icb_cmd_wdata (axil_sram_icb_cmd_wdata),
          .m_icb_cmd_wmask (axil_sram_icb_cmd_wmask),
          .m_icb_rsp_valid (axil_sram_icb_rsp_valid),
          .m_icb_rsp_ready (axil_sram_icb_rsp_ready),
          .m_icb_rsp_rdata (axil_sram_icb_rsp_rdata),
          .m_icb_rsp_err   (axil_sram_icb_rsp_err)
      );

      sram_icb #( ) u_sram_icb (
          .clk             (nice_clk),
          .rst_n           (nice_rst_n),
          .i_icb_cmd_valid (axil_sram_icb_cmd_valid),
          .i_icb_cmd_ready (axil_sram_icb_cmd_ready),
          .i_icb_cmd_read  (axil_sram_icb_cmd_read),
          .i_icb_cmd_addr  (axil_sram_icb_cmd_addr[18:0]),
          .i_icb_cmd_wdata (axil_sram_icb_cmd_wdata),
          .i_icb_cmd_wmask (axil_sram_icb_cmd_wmask),
          .i_icb_cmd_usr   (1'b0),
          .i_icb_rsp_valid (axil_sram_icb_rsp_valid),
          .i_icb_rsp_ready (axil_sram_icb_rsp_ready),
          .i_icb_rsp_rdata (axil_sram_icb_rsp_rdata),
          .i_icb_rsp_usr   (),
          .tcm_cgstop      (1'b0),
          .test_mode       (1'b0),
          .mem_reload_req  (nice_vif.mem_reload_req)
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

    initial begin
        string testname;
        string dut_sel;
        ai_env_cfg cfg;

        cfg = ai_env_cfg::type_id::create("cfg");
`ifdef DUT_AXIL
        cfg.dut_kind = AI_DUT_AXIL;
`else
        cfg.dut_kind = AI_DUT_NICE;
`endif

        if ($value$plusargs("DUT_SEL=%s", dut_sel)) begin
            if ((dut_sel == "axil") || (dut_sel == "AXIL")) begin
                cfg.dut_kind = AI_DUT_AXIL;
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
