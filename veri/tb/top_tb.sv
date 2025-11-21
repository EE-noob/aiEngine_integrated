`ifndef TOP_AI_ENGINE_TB_SV
`define TOP_AI_ENGINE_TB_SV

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import ai_env_pkg::*;
import ai_test_pkg::*;

module tb_top;

    // Clocks and resets
    logic nice_clk;
    logic nice_rst_n;
    logic icb_clk;
    logic icb_rst_n;
    logic cam_pclk;

    // e203 nice-core side
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

    // ICB between nice-core and external memory (stubbed)
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

    // Interface（仅验证 NICE 接口）
    nice_if nice_vif (
        .nice_clk  (nice_clk),
        .nice_rst_n(nice_rst_n)
    );

    // DUT instance
    top_ai_engine u_top_ai_engine (
        // e203_subsys_nice_core signals
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
        .nice_icb_cmd_valid(nice_vif.nice_icb_cmd_valid),
        .nice_icb_cmd_ready(nice_vif.nice_icb_cmd_ready),
        .nice_icb_cmd_addr (nice_vif.nice_icb_cmd_addr),
        .nice_icb_cmd_read (nice_vif.nice_icb_cmd_read),
        .nice_icb_cmd_wdata(nice_vif.nice_icb_cmd_wdata),
        .nice_icb_cmd_size (nice_vif.nice_icb_cmd_size),
        .nice_icb_rsp_valid(nice_vif.nice_icb_rsp_valid),
        .nice_icb_rsp_ready(nice_vif.nice_icb_rsp_ready),
        .nice_icb_rsp_rdata(nice_vif.nice_icb_rsp_rdata),
        .nice_icb_rsp_err  (nice_vif.nice_icb_rsp_err),

        // video_sys_top signals
        .icb_clk           (icb_clk),
        .icb_rst_n         (icb_rst_n),
        // DCMI/摄像头接口在本验证场景中不激活，保持为默认空闲值
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

    // Simple stub for memory side of nice ICB
    initial begin
        nice_vif.nice_icb_cmd_ready = 1'b1;
        nice_vif.nice_icb_rsp_valid = 1'b0;
        nice_vif.nice_icb_rsp_rdata = '0;
        nice_vif.nice_icb_rsp_err   = 1'b0;
    end

    // Clock generation
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

    // Reset generation
    initial begin
        nice_rst_n = 1'b0;
        icb_rst_n  = 1'b0;
        repeat (10) @(posedge nice_clk);
        nice_rst_n = 1'b1;
        icb_rst_n  = 1'b1;
    end

    // UVM configuration and run
    initial begin
        string testname;

        uvm_config_db#(virtual nice_if)::set(uvm_root::get(), "*", "vif", nice_vif);

        if (!$value$plusargs("UVM_TESTNAME=%s", testname)) begin
            testname = "ai_smoke_test";
        end

        run_test(testname);
    end

endmodule : tb_top

`endif
   