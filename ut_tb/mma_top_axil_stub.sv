module mma_top #(
    parameter WEIGHT_WIDTH = 8,
    parameter DATA_WIDTH   = 16,
    parameter SIZE         = 16,
    parameter BUS_WIDTH    = 32,
    parameter REG_WIDTH    = 32,
    parameter ADDR_WIDTH   = 32,
    parameter ICB_LEN_W    = 4
) (
    input wire clk,
    input wire rst_n,
    input wire calc_start,
    input wire cfg_16bits_ia,
    output wire sa_ready,
    output wire wb_valid,
    input wire wb_ready,
    output wire [1:0] err_code,
    input wire [REG_WIDTH-1:0] lhs_base,
    input wire [REG_WIDTH-1:0] rhs_base,
    input wire [REG_WIDTH-1:0] dst_base,
    input wire [REG_WIDTH-1:0] bias_base,
    input wire signed [REG_WIDTH-1:0] lhs_zp,
    input wire signed [REG_WIDTH-1:0] rhs_zp,
    input wire signed [REG_WIDTH-1:0] dst_zp,
    input wire signed [REG_WIDTH-1:0] q_mult_pt,
    input wire signed [REG_WIDTH-1:0] q_shift_pt,
    input wire use_per_channel,
    input wire [REG_WIDTH-1:0] k,
    input wire [REG_WIDTH-1:0] n,
    input wire [REG_WIDTH-1:0] m,
    input wire [REG_WIDTH-1:0] lhs_row_stride_b,
    input wire [REG_WIDTH-1:0] dst_row_stride_b,
    input wire [REG_WIDTH-1:0] rhs_col_stride_b,
    input wire signed [REG_WIDTH-1:0] act_min,
    input wire signed [REG_WIDTH-1:0] act_max,
    output wire sa_icb_cmd_valid,
    input  wire sa_icb_cmd_ready,
    output wire [ADDR_WIDTH-1:0] sa_icb_cmd_addr,
    output wire sa_icb_cmd_read,
    output wire [ICB_LEN_W-1:0] sa_icb_cmd_len,
    output wire [BUS_WIDTH-1:0] sa_icb_cmd_wdata,
    output wire [BUS_WIDTH/8-1:0] sa_icb_cmd_wmask,
    output wire sa_icb_w_valid,
    input wire sa_icb_w_ready,
    input wire sa_icb_rsp_valid,
    output wire sa_icb_rsp_ready,
    input wire [BUS_WIDTH-1:0] sa_icb_rsp_rdata,
    input wire sa_icb_rsp_err
);

assign sa_ready = 1'b1;
assign wb_valid = 1'b0;
assign err_code = 2'b00;
assign sa_icb_cmd_valid = 1'b0;
assign sa_icb_cmd_addr = {ADDR_WIDTH{1'b0}};
assign sa_icb_cmd_read = 1'b0;
assign sa_icb_cmd_len = {ICB_LEN_W{1'b0}};
assign sa_icb_cmd_wdata = {BUS_WIDTH{1'b0}};
assign sa_icb_cmd_wmask = {(BUS_WIDTH/8){1'b0}};
assign sa_icb_w_valid = 1'b0;
assign sa_icb_rsp_ready = 1'b1;

endmodule
