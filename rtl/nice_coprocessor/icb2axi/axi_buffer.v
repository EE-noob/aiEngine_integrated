module axi_buffer
  #(
    parameter CHNL_FIFO_DP = 2,
    //parameter CHNL_FIFO_CUT_READY = 2,
    parameter AW = 32,
    parameter DW = 32 
    )
  (
	  input i_clk,
	  input i_rst_n,
  input  i_axi_arvalid,
  output i_axi_arready,
  input  [AW-1:0] i_axi_araddr,
  input  [3:0] i_axi_arcache,
  input  [2:0] i_axi_arprot,
  input  [1:0] i_axi_arlock,
  input  [1:0] i_axi_arburst,
  input  [3:0] i_axi_arlen,
  input  [2:0] i_axi_arsize,

  input  i_axi_awvalid,
  output i_axi_awready,
  input  [AW-1:0] i_axi_awaddr,
  input  [3:0] i_axi_awcache,
  input  [2:0] i_axi_awprot,
  input  [1:0] i_axi_awlock,
  input  [1:0] i_axi_awburst,
  input  [3:0] i_axi_awlen,
  input  [2:0] i_axi_awsize,

  output i_axi_rvalid,
  input  i_axi_rready,
  output [DW-1:0] i_axi_rdata,
  output [1:0] i_axi_rresp,
  output i_axi_rlast,

  input  i_axi_wvalid,
  output i_axi_wready,
  input  [DW-1:0] i_axi_wdata,
  input  [(DW/8)-1:0] i_axi_wstrb,
  input  i_axi_wlast,

  output i_axi_bvalid,
  input  i_axi_bready,
  output [1:0] i_axi_bresp,

  input o_clk,
  input o_rst_n,
  output o_axi_arvalid,
  input  o_axi_arready,
  output [AW-1:0] o_axi_araddr,
  output [3:0] o_axi_arcache,
  output [2:0] o_axi_arprot,
  output [1:0] o_axi_arlock,
  output [1:0] o_axi_arburst,
  output [3:0] o_axi_arlen,
  output [2:0] o_axi_arsize,

  output o_axi_awvalid,
  input  o_axi_awready,
  output [AW-1:0] o_axi_awaddr,
  output [3:0] o_axi_awcache,
  output [2:0] o_axi_awprot,
  output [1:0] o_axi_awlock,
  output [1:0] o_axi_awburst,
  output [3:0] o_axi_awlen,
  output [2:0] o_axi_awsize,

  input  o_axi_rvalid,
  output o_axi_rready,
  input  [DW-1:0] o_axi_rdata,
  input  [1:0] o_axi_rresp,
  input  o_axi_rlast,

  output o_axi_wvalid,
  input  o_axi_wready,
  output [DW-1:0] o_axi_wdata,
  output [(DW/8)-1:0] o_axi_wstrb,
  output o_axi_wlast,

  input  o_axi_bvalid,
  output o_axi_bready,
  input  [1:0] o_axi_bresp
  );


localparam AR_CHNL_W = 4+3+2+4+3+2+AW;
localparam AW_CHNL_W = AR_CHNL_W;

wire [AR_CHNL_W -1:0] i_axi_ar_chnl = 
    {
    i_axi_araddr,
    i_axi_arcache,
    i_axi_arprot ,
    i_axi_arlock ,
    i_axi_arburst,
    i_axi_arlen  ,
    i_axi_arsize  
    };

wire [AR_CHNL_W -1:0] o_axi_ar_chnl;
assign   {
    o_axi_araddr,
    o_axi_arcache,
    o_axi_arprot ,
    o_axi_arlock ,
    o_axi_arburst,
    o_axi_arlen  ,
    o_axi_arsize   
    } = o_axi_ar_chnl;

  fifo_async # (
    //.CUT_READY (FIFO_CUT_READY),
    //.MSKO      (1),
    .DP  (CHNL_FIFO_DP),
    .DW  (AR_CHNL_W),
	.ASYNC(1),
	.FLAG_ACTIVE_HIGH(1)
  ) u_fifo_async (
	  /*autoinst*/
	.i_clk                  (i_clk), //input
	.i_rst_n                (i_rst_n), //input
	.i_data                 (i_axi_ar_chnl), //input
	.i_valid                   (i_axi_arvalid), //input
	.i_ready                 (i_axi_arready), //output
	.o_clk                  (o_clk), //input
	.o_rst_n                (o_rst_n), //input
	.o_data                 (o_axi_ar_chnl), //output
	.o_ready                   (o_axi_arready), //input
	.o_valid                (o_axi_arvalid)  //output
);
	
wire [AW_CHNL_W-1:0] i_axi_aw_chnl = 
    {
    i_axi_awaddr,
    i_axi_awcache,
    i_axi_awprot ,
    i_axi_awlock ,
    i_axi_awburst,
    i_axi_awlen  ,
    i_axi_awsize  
    };

wire [AW_CHNL_W-1:0] o_axi_aw_chnl;
assign   {
    o_axi_awaddr,
    o_axi_awcache,
    o_axi_awprot ,
    o_axi_awlock ,
    o_axi_awburst,
    o_axi_awlen  ,
    o_axi_awsize  
    } = o_axi_aw_chnl;

fifo_async #(
    //.CUT_READY (CHNL_FIFO_CUT_READY),
    //.MSKO      (0),
    .DP  (CHNL_FIFO_DP),
    .DW  (AW_CHNL_W),
	.ASYNC(1),
	.FLAG_ACTIVE_HIGH(1)
) o_axi_aw_fifo (
	.i_clk(i_clk),
	.i_rst_n(i_rst_n),
  .i_ready    (i_axi_awready),
  .i_valid    (i_axi_awvalid),
  .i_data    (i_axi_aw_chnl ),

  .o_clk(o_clk),
  .o_rst_n(o_rst_n),
  .o_valid    (o_axi_awvalid ),
  .o_ready    (o_axi_awready),
  .o_data    (o_axi_aw_chnl)
  );


localparam W_CHNL_W = DW+(DW/8)+1;
wire [W_CHNL_W-1:0] i_axi_w_chnl = {
                                                i_axi_wdata,
                                                i_axi_wstrb,
                                                i_axi_wlast
                                                 };
wire [W_CHNL_W-1:0] o_axi_w_chnl;
assign { 
         o_axi_wdata,
         o_axi_wstrb,
         o_axi_wlast} = o_axi_w_chnl;

fifo_async #(
    //.CUT_READY (CHNL_FIFO_CUT_READY),
    //.MSKO      (0),
    .DP  (CHNL_FIFO_DP),
    .DW  (W_CHNL_W),
	.ASYNC(1),
	.FLAG_ACTIVE_HIGH(1)
) o_axi_wdata_fifo(
	.i_clk(i_clk),
	.i_rst_n(i_rst_n),
  .i_ready    (i_axi_wready),
  .i_valid    (i_axi_wvalid),
  .i_data    (i_axi_w_chnl ),

  .o_clk(o_clk),
  .o_rst_n(o_rst_n),
  .o_valid    (o_axi_wvalid),
  .o_ready    (o_axi_wready),
  .o_data    (o_axi_w_chnl)
);
//


localparam R_CHNL_W = DW+2+1;
wire [R_CHNL_W-1:0] o_axi_r_chnl = {
                                                o_axi_rdata,
                                                o_axi_rresp,
                                                o_axi_rlast 
                                                 };
wire [R_CHNL_W-1:0] i_axi_r_chnl;
assign {
        i_axi_rdata,
        i_axi_rresp,
        i_axi_rlast} = i_axi_r_chnl;

fifo_async # (
    //.CUT_READY (CHNL_FIFO_CUT_READY),
    //.MSKO      (0),
    .DP  (CHNL_FIFO_DP),
    .DW  (R_CHNL_W),
	.ASYNC(1),
	.FLAG_ACTIVE_HIGH(1)
) o_axi_rdata_fifo(
	.i_clk(o_clk),
	.i_rst_n(o_rst_n),
  .i_ready    (o_axi_rready),
  .i_valid    (o_axi_rvalid),
  .i_data    (o_axi_r_chnl ),

  .o_clk(i_clk),
  .o_rst_n(i_rst_n),
  .o_valid    (i_axi_rvalid),
  .o_ready    (i_axi_rready),
  .o_data    (i_axi_r_chnl)
  );


localparam B_CHNL_W = 2;

wire [B_CHNL_W -1:0] o_axi_b_chnl = {
           o_axi_bresp
           };

wire [B_CHNL_W -1:0] i_axi_b_chnl;
assign {
           i_axi_bresp
           } = i_axi_b_chnl;

fifo_async #(
    //.CUT_READY (CHNL_FIFO_CUT_READY),
    //.MSKO      (0),
    .DP  (CHNL_FIFO_DP),
    .DW  (B_CHNL_W),
	.ASYNC(1),
	.FLAG_ACTIVE_HIGH(1)
) o_axi_bresp_fifo (
	.i_clk(o_clk),
	.i_rst_n(o_rst_n),
  .i_ready    (o_axi_bready     ),
  .i_valid    (o_axi_bvalid     ),
  .i_data    (o_axi_b_chnl),

  .o_clk(i_clk),
  .o_rst_n(i_rst_n),
  .o_valid    (i_axi_bvalid),
  .o_ready    (i_axi_bready),
  .o_data    (i_axi_b_chnl)
  );



endmodule 

