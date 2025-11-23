module sirv_1cyc_sram_ctrl #(
  parameter DW = 32,
  parameter AW = 32,
  parameter MW = 4,
  parameter AW_LSB = 2,
  parameter USR_W = 1
)(
  output sram_ctrl_active,
  input  tcm_cgstop,
  
  input  uop_cmd_valid,
  output uop_cmd_ready,
  input  uop_cmd_read,
  input  [AW-1:0] uop_cmd_addr, 
  input  [DW-1:0] uop_cmd_wdata, 
  input  [MW-1:0] uop_cmd_wmask, 
  input  [USR_W-1:0] uop_cmd_usr, 
  
  output uop_rsp_valid,
  input  uop_rsp_ready,
  output [DW-1:0] uop_rsp_rdata, 
  output [USR_W-1:0] uop_rsp_usr, 
  
  output          ram_cs,  
  output          ram_we,  
  output [AW-AW_LSB-1:0] ram_addr, 
  output [MW-1:0] ram_wem,
  output [DW-1:0] ram_din,          
  input  [DW-1:0] ram_dout,
  output          clk_ram,
  
  input  test_mode,
  input  clk,
  input  rst_n
);
  // Simple 1-cycle SRAM controller logic
  assign uop_cmd_ready = 1'b1; // Always ready in this simple model
  
  assign ram_cs = uop_cmd_valid;
  assign ram_we = ~uop_cmd_read;
  assign ram_addr = uop_cmd_addr[AW-1:AW_LSB];
  assign ram_wem = uop_cmd_wmask;
  assign ram_din = uop_cmd_wdata;
  assign clk_ram = clk; // No clock gating for now
  
  reg rsp_valid_r;
  reg [USR_W-1:0] rsp_usr_r;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rsp_valid_r <= 1'b0;
      rsp_usr_r <= {USR_W{1'b0}};
    end else begin
      rsp_valid_r <= uop_cmd_valid;
      if (uop_cmd_valid) begin
         rsp_usr_r <= uop_cmd_usr;
      end
    end
  end
  
  assign uop_rsp_valid = rsp_valid_r;
  assign uop_rsp_rdata = ram_dout;
  assign uop_rsp_usr   = rsp_usr_r;
  
  assign sram_ctrl_active = uop_cmd_valid | uop_rsp_valid;
  
endmodule
