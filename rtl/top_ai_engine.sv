`include "e203_defines.v"
 `include "config.v"
 `include "icb_types.svh"
 module top_ai_engine #(
    // video_sys_top parameters
    parameter ADDR_WIDTH = 12,
    parameter IMAGE_SIZE = 1 << ADDR_WIDTH,
    parameter WAIT_FRAME = 4'd10,
    parameter DW = 32,
    parameter MW = 4,
    parameter AW = 19,
    parameter AW_LSB = 2,
    parameter USR_W = 1,
    parameter DP = 131072,
    parameter FORCE_X2ZERO = 1
) (
    // e203_subsys_nice_core signals
    input                        nice_clk,
    input                        nice_rst_n,
    output                       nice_active,
    output                       nice_mem_holdup,
    input                        nice_req_valid,
    output                       nice_req_ready,
    input  [     `E203_XLEN-1:0] nice_req_inst,
    input  [     `E203_XLEN-1:0] nice_req_rs1,
    input  [     `E203_XLEN-1:0] nice_req_rs2,
    output                       nice_rsp_valid,
    input                        nice_rsp_ready,
    output [     `E203_XLEN-1:0] nice_rsp_rdat,
    output                       nice_rsp_err,
    output                       nice_icb_cmd_valid,
    input                        nice_icb_cmd_ready,
    output [`E203_ADDR_SIZE-1:0] nice_icb_cmd_addr,
    output                       nice_icb_cmd_read,
    output [     `E203_XLEN-1:0] nice_icb_cmd_wdata,
    //output [  `E203_XLEN_MW-1:0] nice_icb_cmd_wmask,
    output [                1:0] nice_icb_cmd_size,
    input                        nice_icb_rsp_valid,
    output                       nice_icb_rsp_ready,
    input  [     `E203_XLEN-1:0] nice_icb_rsp_rdata,
    input                        nice_icb_rsp_err,

    // video_sys_top signals
    input  wire             icb_clk,
    input  wire             icb_rst_n,
    input  wire             dcmi_icb_cmd_valid,
    output wire             dcmi_icb_cmd_ready,
    input  wire [31:0]      dcmi_icb_cmd_addr,
    input  wire             dcmi_icb_cmd_read,
    input  wire [31:0]      dcmi_icb_cmd_wdata,
    input  wire [3:0]       dcmi_icb_cmd_wmask,
    output wire             dcmi_icb_rsp_valid,
    input  wire             dcmi_icb_rsp_ready,
    output wire [31:0]      dcmi_icb_rsp_rdata,
    input  wire             cam_pclk,
    output  wire             cam_rst_n,
    input  wire             cam_vsync,
    input  wire             cam_href,
    input  wire [7:0]       cam_data
    
    // ,
    // input                   i_icb_cmd_valid,
    // output                  i_icb_cmd_ready,
    // input                   i_icb_cmd_read,
    // input  [AW-1:0]         i_icb_cmd_addr,
    // input  [DW-1:0]         i_icb_cmd_wdata,
    // input  [MW-1:0]         i_icb_cmd_wmask,
    // input  [USR_W-1:0]      i_icb_cmd_usr,
    // output                  i_icb_rsp_valid,
    // input                   i_icb_rsp_ready,
    // output [DW-1:0]         i_icb_rsp_rdata,
    // output [USR_W-1:0]      i_icb_rsp_usr,
    // input                   tcm_cgstop,
    // input                   test_mode
);
logic [  `E203_XLEN_MW-1:0] nice_icb_cmd_wmask;//弃用
    // Instance 1: e203_subsys_nice_core
    e203_subsys_nice_core e203_subsys_nice_core_inst (
        .nice_clk(nice_clk),
        .nice_rst_n(nice_rst_n),
        .nice_active(nice_active),
        .nice_mem_holdup(nice_mem_holdup),
        .nice_req_valid(nice_req_valid),
        .nice_req_ready(nice_req_ready),
        .nice_req_inst(nice_req_inst),
        .nice_req_rs1(nice_req_rs1),
        .nice_req_rs2(nice_req_rs2),
        .nice_rsp_valid(nice_rsp_valid),
        .nice_rsp_ready(nice_rsp_ready),
        .nice_rsp_rdat(nice_rsp_rdat),
        .nice_rsp_err(nice_rsp_err),
        .nice_icb_cmd_valid(nice_icb_cmd_valid),
        .nice_icb_cmd_ready(nice_icb_cmd_ready),
        .nice_icb_cmd_addr(nice_icb_cmd_addr),
        .nice_icb_cmd_read(nice_icb_cmd_read),
        .nice_icb_cmd_wdata(nice_icb_cmd_wdata),
        .nice_icb_cmd_wmask(nice_icb_cmd_wmask),
        .nice_icb_cmd_size(nice_icb_cmd_size),
        .nice_icb_rsp_valid(nice_icb_rsp_valid),
        .nice_icb_rsp_ready(nice_icb_rsp_ready),
        .nice_icb_rsp_rdata(nice_icb_rsp_rdata),
        .nice_icb_rsp_err(nice_icb_rsp_err)
    );

    // // Instance 2: video_sys_top
    // video_sys_top #(
    //     .ADDR_WIDTH(ADDR_WIDTH),
    //     .IMAGE_SIZE(IMAGE_SIZE),
    //     .WAIT_FRAME(WAIT_FRAME),
    //     .DW(DW),
    //     .MW(MW),
    //     .AW(AW),
    //     .AW_LSB(AW_LSB),
    //     .USR_W(USR_W),
    //     .DP(DP),
    //     .FORCE_X2ZERO(FORCE_X2ZERO)
    // ) video_sys_top_inst (
    //     .icb_clk(icb_clk),
    //     .icb_rst_n(icb_rst_n),
    //     .dcmi_icb_cmd_valid(dcmi_icb_cmd_valid),
    //     .dcmi_icb_cmd_ready(dcmi_icb_cmd_ready),
    //     .dcmi_icb_cmd_addr(dcmi_icb_cmd_addr),
    //     .dcmi_icb_cmd_read(dcmi_icb_cmd_read),
    //     .dcmi_icb_cmd_wdata(dcmi_icb_cmd_wdata),
    //     .dcmi_icb_cmd_wmask(dcmi_icb_cmd_wmask),
    //     .dcmi_icb_rsp_valid(dcmi_icb_rsp_valid),
    //     .dcmi_icb_rsp_ready(dcmi_icb_rsp_ready),
    //     .dcmi_icb_rsp_rdata(dcmi_icb_rsp_rdata),
    //     .cam_pclk(cam_pclk),
    //     .cam_rst_n(cam_rst_n),
    //     .cam_vsync(cam_vsync),
    //     .cam_href(cam_href),
    //     .cam_data(cam_data)
        
    //     // ,
    //     // .i_icb_cmd_valid(i_icb_cmd_valid),
    //     // .i_icb_cmd_ready(i_icb_cmd_ready),
    //     // .i_icb_cmd_read(i_icb_cmd_read),
    //     // .i_icb_cmd_addr(i_icb_cmd_addr),
    //     // .i_icb_cmd_wdata(i_icb_cmd_wdata),
    //     // .i_icb_cmd_wmask(i_icb_cmd_wmask),
    //     // .i_icb_cmd_usr(i_icb_cmd_usr),
    //     // .i_icb_rsp_valid(i_icb_rsp_valid),
    //     // .i_icb_rsp_ready(i_icb_rsp_ready),
    //     // .i_icb_rsp_rdata(i_icb_rsp_rdata),
    //     // .i_icb_rsp_usr(i_icb_rsp_usr),
    //     // .tcm_cgstop(tcm_cgstop),
    //     // .test_mode(test_mode)
    // );

endmodule
