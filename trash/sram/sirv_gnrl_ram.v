module sirv_gnrl_ram #(
  parameter DP = 512,
  parameter DW = 32,
  parameter MW = 4,
  parameter AW = 32,
  parameter FORCE_X2ZERO = 0,
  parameter MEM_PATH = "",
  parameter INIT_EN = 0
)(
  input             clk,
  input             rst_n,
  input             cs,
  input             we,
  input  [MW-1:0]   wem,
  input  [AW-1:0]   addr,
  input  [DW-1:0]   din,
  output [DW-1:0]   dout,
  output            sd,
  output            ds,
  output            ls
);
  reg [DW-1:0] mem [0:DP-1];
  reg [DW-1:0] dout_r;

  always @(posedge clk) begin
    if (cs) begin
      if (we) begin
        for (integer i = 0; i < MW; i = i + 1) begin
          if (wem[i]) mem[addr][i*8 +: 8] <= din[i*8 +: 8];
        end
      end else begin
        dout_r <= mem[addr];
      end
    end
  end
  assign dout = dout_r;
  assign sd = 0;
  assign ds = 0;
  assign ls = 0;
  
  initial begin
      if (INIT_EN) begin
          $readmemh(MEM_PATH, mem);
      end
  end
endmodule
