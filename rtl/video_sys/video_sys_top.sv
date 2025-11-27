 // //`include "define.svh"
 `include "e203_defines.v"
 `include "config.v"
module video_sys_top #(
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
)(
    // ICB 时钟域
    input  wire             icb_clk,
    input  wire             icb_rst_n,
    

    
    // ICB 接口
    input  wire             dcmi_icb_cmd_valid,
    output wire             dcmi_icb_cmd_ready,
    input  wire [31:0]      dcmi_icb_cmd_addr,
    input  wire             dcmi_icb_cmd_read,
    input  wire [31:0]      dcmi_icb_cmd_wdata,
    input  wire [3:0]       dcmi_icb_cmd_wmask,
    output wire             dcmi_icb_rsp_valid,
    input  wire             dcmi_icb_rsp_ready,
    output wire [31:0]      dcmi_icb_rsp_rdata,
    
    // 摄像头时钟域
    input  wire             cam_pclk,
    output  wire             cam_rst_n,

    // 摄像头接口
    input  wire             cam_vsync,
    input  wire             cam_href,
    input  wire [7:0]       cam_data
    //,

    // // SRAM ICB 接口
    //   // input                   clk,
    //   // input                   rst_n,
    //   input                   i_icb_cmd_valid,
    //   output                  i_icb_cmd_ready,
    //   input                   i_icb_cmd_read,
    //   input  [AW-1:0]         i_icb_cmd_addr,
    //   input  [DW-1:0]         i_icb_cmd_wdata,
    //   input  [MW-1:0]         i_icb_cmd_wmask,
    //   input  [USR_W-1:0]      i_icb_cmd_usr,
    //   output                  i_icb_rsp_valid,
    //   input                   i_icb_rsp_ready,
    //   output [DW-1:0]         i_icb_rsp_rdata,
    //   output [USR_W-1:0]      i_icb_rsp_usr,
    //   input                   tcm_cgstop,
    //   input                   test_mode
);


 //wire sram_icb_cmd_valid;
 //wire sram_icb_cmd_ready;
 //wire [31:0] sram_icb_cmd_addr;
 //wire sram_icb_cmd_read;
 //wire [`E203_XLEN-1:0] sram_icb_cmd_wdata;
 //wire [`E203_XLEN/8-1:0] sram_icb_cmd_wmask;
 //wire sram_icb_rsp_valid;
 //wire sram_icb_rsp_ready;
 //wire [`E203_XLEN-1:0] sram_icb_rsp_rdata;



   ov5640_icb_top u_ov5640_icb_top (
   .icb_clk            (icb_clk),
   .icb_rst_n          (icb_rst_n),
   .cam_pclk           (cam_pclk),
   .cam_rst_n          (cam_rst_n),

   .dcmi_icb_cmd_valid (dcmi_icb_cmd_valid),
   .dcmi_icb_cmd_ready (dcmi_icb_cmd_ready),
   .dcmi_icb_cmd_addr  (dcmi_icb_cmd_addr),
   .dcmi_icb_cmd_read  (dcmi_icb_cmd_read),
   .dcmi_icb_cmd_wdata (dcmi_icb_cmd_wdata),
   .dcmi_icb_cmd_wmask (dcmi_icb_cmd_wmask),
   .dcmi_icb_rsp_valid (dcmi_icb_rsp_valid),
   .dcmi_icb_rsp_ready (dcmi_icb_rsp_ready),
   .dcmi_icb_rsp_rdata (dcmi_icb_rsp_rdata),

   .cam_vsync          (cam_vsync),
   .cam_href           (cam_href),
   .cam_data           (cam_data)

 );

  //  sram_icb #(
  //    .DW(`E203_XLEN),
  //    .MW(`E203_XLEN/8),
  //    .AW(19),
  //    .AW_LSB(2), // 字节寻址
  //    .USR_W(1),
  //    .DP(131072),
  //    .FORCE_X2ZERO(1)
  //  ) u_sram_icb (
  //     .clk(icb_clk),
  //     .rst_n(icb_rst_n),
  //     .i_icb_cmd_valid(sram_icb_cmd_valid),
  //     .i_icb_cmd_ready(sram_icb_cmd_ready),
  //     .i_icb_cmd_read(sram_icb_cmd_read),
  //     .i_icb_cmd_addr(sram_icb_cmd_addr[18:0]),
  //     .i_icb_cmd_wdata(sram_icb_cmd_wdata),
  //     .i_icb_cmd_wmask(sram_icb_cmd_wmask),
  //     .i_icb_cmd_usr(1'b0),
  //     .i_icb_rsp_valid(sram_icb_rsp_valid),
  //     .i_icb_rsp_ready(sram_icb_rsp_ready),
  //     .i_icb_rsp_rdata(sram_icb_rsp_rdata),
  //     .i_icb_rsp_usr(),
  //     .tcm_cgstop(1'b0),
  //     .test_mode(1'b0)
  // );
endmodule