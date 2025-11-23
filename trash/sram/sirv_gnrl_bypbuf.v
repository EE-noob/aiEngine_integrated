module sirv_gnrl_bypbuf #(
  parameter DP = 8,
  parameter DW = 32
)(
  input           i_vld,
  output          i_rdy,
  input  [DW-1:0] i_dat,
  output          o_vld,
  input           o_rdy,
  output [DW-1:0] o_dat,
  input           clk,
  input           rst_n
);
  // Simple bypass buffer implementation (1-deep FIFO / Register Slice)
  reg [DW-1:0] buff_dat;
  reg          buff_vld;
  
  assign i_rdy = (~buff_vld) | o_rdy;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buff_vld <= 1'b0;
      buff_dat <= {DW{1'b0}};
    end else begin
      if (i_vld && i_rdy) begin
        buff_vld <= 1'b1;
        buff_dat <= i_dat;
      end else if (o_rdy) begin
        buff_vld <= 1'b0;
      end
    end
  end
  
  assign o_vld = buff_vld;
  assign o_dat = buff_dat;
  
endmodule
