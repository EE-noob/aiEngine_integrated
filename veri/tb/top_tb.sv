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

    // // SRAM Model Instance connected to NICE ICB interface
    // ai_sram_model u_sram_model (
    //     .clk       (nice_clk),
    //     .rst_n     (nice_rst_n),
    //     
    //     .cmd_valid (nice_vif.nice_icb_cmd_valid),
    //     .cmd_ready (nice_vif.nice_icb_cmd_ready),
    //     .cmd_addr  (nice_vif.nice_icb_cmd_addr),
    //     .cmd_read  (nice_vif.nice_icb_cmd_read),
    //     .cmd_wdata (nice_vif.nice_icb_cmd_wdata),
    //     .cmd_size  (nice_vif.nice_icb_cmd_size),
    //     
    //     .rsp_valid (nice_vif.nice_icb_rsp_valid),
    //     .rsp_ready (nice_vif.nice_icb_rsp_ready),
    //     .rsp_rdata (nice_vif.nice_icb_rsp_rdata),
    //     .rsp_err   (nice_vif.nice_icb_rsp_err)
    // );

    // // Wmask generation for SRAM ICB
    // logic [3:0] nice_icb_cmd_wmask;
    // always_comb begin
    //     if (nice_vif.nice_icb_cmd_size == 2'b10) nice_icb_cmd_wmask = 4'b1111;
    //     else if (nice_vif.nice_icb_cmd_size == 2'b01) begin
    //         if (nice_vif.nice_icb_cmd_addr[1]) nice_icb_cmd_wmask = 4'b1100;
    //         else nice_icb_cmd_wmask = 4'b0011;
    //     end else begin // byte
    //         case (nice_vif.nice_icb_cmd_addr[1:0])
    //             2'b00: nice_icb_cmd_wmask = 4'b0001;
    //             2'b01: nice_icb_cmd_wmask = 4'b0010;
    //             2'b10: nice_icb_cmd_wmask = 4'b0100;
    //             2'b11: nice_icb_cmd_wmask = 4'b1000;
    //         endcase
    //     end
    // end

    // SRAM ICB Instance
    sram_icb #(

    ) u_sram_icb (
        .clk             (nice_clk),
        .rst_n           (nice_rst_n),
        .i_icb_cmd_valid (nice_vif.nice_icb_cmd_valid),
        .i_icb_cmd_ready (nice_vif.nice_icb_cmd_ready),
        .i_icb_cmd_read  (nice_vif.nice_icb_cmd_read),
        .i_icb_cmd_addr  (nice_vif.nice_icb_cmd_addr),
        .i_icb_cmd_wdata (nice_vif.nice_icb_cmd_wdata),
        .i_icb_cmd_wmask (nice_icb_cmd_wmask),
        .i_icb_cmd_usr   (1'b0),
        .i_icb_rsp_valid (nice_vif.nice_icb_rsp_valid),
        .i_icb_rsp_ready (nice_vif.nice_icb_rsp_ready),
        .i_icb_rsp_rdata (nice_vif.nice_icb_rsp_rdata),
        .i_icb_rsp_usr   (), 
        .tcm_cgstop      (1'b0),
        .test_mode       (1'b0)
    );
    
    assign nice_vif.nice_icb_rsp_err = 1'b0;

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
        repeat (3) @(posedge nice_clk);
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

    // ============================================================
    // FSDB Dump
    // ============================================================
    initial begin
       // if ($test$plusargs("dump_fsdb")) begin
            string fsdb_name;
            if (!$value$plusargs("fsdbfile+%s", fsdb_name)) begin
                fsdb_name = "tb_top.fsdb";
            end
            $fsdbDumpfile(fsdb_name);
            $fsdbDumpvars(0, tb_top);
            $fsdbDumpSVA();
            $fsdbDumpMDA();
            // Dump UVM components if needed, though usually handled by transaction recording
            // $fsdbDumpClassObject(uvm_root::get()); 
        end
    //end

endmodule : tb_top

`endif
