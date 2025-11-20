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

    // Video system ICB and camera side
    logic             dcmi_icb_cmd_valid;
    logic             dcmi_icb_cmd_ready;
    logic [31:0]      dcmi_icb_cmd_addr;
    logic             dcmi_icb_cmd_read;
    logic [31:0]      dcmi_icb_cmd_wdata;
    logic [3:0]       dcmi_icb_cmd_wmask;
    logic             dcmi_icb_rsp_valid;
    logic             dcmi_icb_rsp_ready;
    logic [31:0]      dcmi_icb_rsp_rdata;

    logic             cam_rst_n;
    logic             cam_vsync;
    logic             cam_href;
    logic [7:0]       cam_data;

    // Interfaces
    dcmi_if dcmi_vif (
        .icb_clk  (icb_clk),
        .icb_rst_n(icb_rst_n)
    );

    cam_if cam_vif (
        .cam_pclk(cam_pclk)
    );

    nice_if nice_vif (
        .nice_clk (nice_clk),
        .nice_rst_n(nice_rst_n)
    );

    // DUT instance
    top_ai_engine u_top_ai_engine (
        // e203_subsys_nice_core signals
        .nice_clk          (nice_clk),
        .nice_rst_n        (nice_rst_n),
        .nice_active       (nice_active),
        .nice_mem_holdup   (nice_mem_holdup),
        .nice_req_valid    (nice_req_valid),
        .nice_req_ready    (nice_req_ready),
        .nice_req_inst     (nice_req_inst),
        .nice_req_rs1      (nice_req_rs1),
        .nice_req_rs2      (nice_req_rs2),
        .nice_rsp_valid    (nice_rsp_valid),
        .nice_rsp_ready    (nice_rsp_ready),
        .nice_rsp_rdat     (nice_rsp_rdat),
        .nice_rsp_err      (nice_rsp_err),
        .nice_icb_cmd_valid(nice_icb_cmd_valid),
        .nice_icb_cmd_ready(nice_icb_cmd_ready),
        .nice_icb_cmd_addr (nice_icb_cmd_addr),
        .nice_icb_cmd_read (nice_icb_cmd_read),
        .nice_icb_cmd_wdata(nice_icb_cmd_wdata),
        .nice_icb_cmd_size (nice_icb_cmd_size),
        .nice_icb_rsp_valid(nice_icb_rsp_valid),
        .nice_icb_rsp_ready(nice_icb_rsp_ready),
        .nice_icb_rsp_rdata(nice_icb_rsp_rdata),
        .nice_icb_rsp_err  (nice_icb_rsp_err),

        // video_sys_top signals
        .icb_clk           (icb_clk),
        .icb_rst_n         (icb_rst_n),
        .dcmi_icb_cmd_valid(dcmi_icb_cmd_valid),
        .dcmi_icb_cmd_ready(dcmi_icb_cmd_ready),
        .dcmi_icb_cmd_addr (dcmi_icb_cmd_addr),
        .dcmi_icb_cmd_read (dcmi_icb_cmd_read),
        .dcmi_icb_cmd_wdata(dcmi_icb_cmd_wdata),
        .dcmi_icb_cmd_wmask(dcmi_icb_cmd_wmask),
        .dcmi_icb_rsp_valid(dcmi_icb_rsp_valid),
        .dcmi_icb_rsp_ready(dcmi_icb_rsp_ready),
        .dcmi_icb_rsp_rdata(dcmi_icb_rsp_rdata),
        .cam_pclk          (cam_pclk),
        .cam_rst_n         (cam_rst_n),
        .cam_vsync         (cam_vsync),
        .cam_href          (cam_href),
        .cam_data          (cam_data)
    );

    // Connect DUT video ICB and camera to interfaces
    assign dcmi_vif.dcmi_icb_cmd_valid = dcmi_icb_cmd_valid;
    assign dcmi_icb_cmd_ready          = dcmi_vif.dcmi_icb_cmd_ready;
    assign dcmi_vif.dcmi_icb_cmd_addr  = dcmi_icb_cmd_addr;
    assign dcmi_vif.dcmi_icb_cmd_read  = dcmi_icb_cmd_read;
    assign dcmi_vif.dcmi_icb_cmd_wdata = dcmi_icb_cmd_wdata;
    assign dcmi_vif.dcmi_icb_cmd_wmask = dcmi_icb_cmd_wmask;
    assign dcmi_vif.dcmi_icb_rsp_valid = dcmi_icb_rsp_valid;
    assign dcmi_icb_rsp_ready          = dcmi_vif.dcmi_icb_rsp_ready;
    assign dcmi_vif.dcmi_icb_rsp_rdata = dcmi_icb_rsp_rdata;

    assign cam_vif.cam_rst_n = cam_rst_n;
    assign cam_vif.cam_vsync = cam_vsync;
    assign cam_vif.cam_href  = cam_href;
    assign cam_vif.cam_data  = cam_data;

    // Connect nice interface to DUT sideband signals
    assign nice_vif.nice_active     = nice_active;
    assign nice_vif.nice_mem_holdup = nice_mem_holdup;

    assign nice_req_valid = nice_vif.nice_req_valid;
    assign nice_req_inst  = nice_vif.nice_req_inst;
    assign nice_req_rs1   = nice_vif.nice_req_rs1;
    assign nice_req_rs2   = nice_vif.nice_req_rs2;
    assign nice_vif.nice_req_ready  = nice_req_ready;

    assign nice_rsp_ready          = nice_vif.nice_rsp_ready;
    assign nice_vif.nice_rsp_valid = nice_rsp_valid;
    assign nice_vif.nice_rsp_rdat  = nice_rsp_rdat;
    assign nice_vif.nice_rsp_err   = nice_rsp_err;

    // Monitor ICB between nice-core and memory
    assign nice_vif.nice_icb_cmd_valid = nice_icb_cmd_valid;
    assign nice_vif.nice_icb_cmd_ready = nice_icb_cmd_ready;
    assign nice_vif.nice_icb_cmd_addr  = nice_icb_cmd_addr;
    assign nice_vif.nice_icb_cmd_read  = nice_icb_cmd_read;
    assign nice_vif.nice_icb_cmd_wdata = nice_icb_cmd_wdata;
    assign nice_vif.nice_icb_cmd_size  = nice_icb_cmd_size;
    assign nice_vif.nice_icb_rsp_valid = nice_icb_rsp_valid;
    assign nice_vif.nice_icb_rsp_ready = nice_icb_rsp_ready;
    assign nice_vif.nice_icb_rsp_rdata = nice_icb_rsp_rdata;
    assign nice_vif.nice_icb_rsp_err   = nice_icb_rsp_err;

    // Simple stub for memory side of nice ICB
    initial begin
        nice_icb_cmd_ready = 1'b1;
        nice_icb_rsp_valid = 1'b0;
        nice_icb_rsp_rdata = '0;
        nice_icb_rsp_err   = 1'b0;
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
        uvm_config_db#(virtual dcmi_if)::set(uvm_root::get(), "*", "dcmi_vif", dcmi_vif);
        uvm_config_db#(virtual cam_if )::set(uvm_root::get(), "*", "cam_vif" , cam_vif);
        uvm_config_db#(virtual nice_if)::set(uvm_root::get(), "*", "nice_vif", nice_vif);

        if (!$value$plusargs("UVM_TESTNAME=%s", uvm_top.get_full_name())) begin
            run_test("ai_smoke_test");
        end
        else begin
            run_test();
        end
    end

endmodule : tb_top

`endif
