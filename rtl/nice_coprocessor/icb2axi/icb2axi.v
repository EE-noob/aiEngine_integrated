module icb2axi # (
  parameter AXI_FIFO_DP = 2, // This is to optionally add the pipeline stage for AXI bus
                             //   if the depth is 0, then means pass through, not add pipeline
                             //   if the depth is 2, then means added one ping-pong buffer stage
  //parameter AXI_FIFO_CUT_READY = 1, // This is to cut the back-pressure signal if you set as 1
  parameter AW = 32,
  parameter FIFO_OUTS_NUM = 8,
  parameter FIFO_CUT_READY = 0,
  parameter DW = 64 // 64 or 32 bits
) (
  input  i_clk,
  input  i_rst_n,

  input              i_icb_cmd_valid, 
  output             i_icb_cmd_ready, 
  input  [1-1:0]     i_icb_cmd_read, 
  input  [AW-1:0]    i_icb_cmd_addr, 
  input  [DW-1:0]    i_icb_cmd_wdata, 
  input  [DW/8-1:0]  i_icb_cmd_wmask,
  input  [1:0]       i_icb_cmd_size,

  output             i_icb_rsp_valid, 
  input              i_icb_rsp_ready, 
  output             i_icb_rsp_err,
  output [DW-1:0]    i_icb_rsp_rdata, 
  
  input  o_clk,
  input  o_rst_n,

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

  wire i_axi_arvalid;
  wire i_axi_arready;
  wire [AW-1:0] i_axi_araddr;
  wire [3:0] i_axi_arcache;
  wire [2:0] i_axi_arprot;
  wire [1:0] i_axi_arlock;
  wire [1:0] i_axi_arburst;
  wire [3:0] i_axi_arlen;
  wire [2:0] i_axi_arsize;

  wire i_axi_awvalid;
  wire i_axi_awready;
  wire [AW-1:0] i_axi_awaddr;
  wire [3:0] i_axi_awcache;
  wire [2:0] i_axi_awprot;
  wire [1:0] i_axi_awlock;
  wire [1:0] i_axi_awburst;
  wire [3:0] i_axi_awlen;
  wire [2:0] i_axi_awsize;

  wire i_axi_rvalid;
  wire i_axi_rready;
  wire [DW-1:0] i_axi_rdata;
  wire [1:0] i_axi_rresp;
  wire i_axi_rlast;

  wire i_axi_wvalid;
  wire i_axi_wready;
  wire [DW-1:0] i_axi_wdata;
  wire [(DW/8)-1:0] i_axi_wstrb;
  wire i_axi_wlast;

  wire i_axi_bvalid;
  wire i_axi_bready;
  wire [1:0] i_axi_bresp;


  //////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////
  // Convert the ICB to AXI Read/Write address and Wdata channel
  //
  //   Generate the AXI address channel valid which is direct got 
  //     from ICB command channel
  assign i_axi_arvalid = i_icb_cmd_valid & i_icb_cmd_read;
  
  // If it is the read transaction, need to pass to AR channel only
  // If it is the write transaction, need to pass to AW and W channel both
      // But in all case, need to check FIFO is not ful
  wire rw_fifo_full;
  assign i_icb_cmd_ready = (~rw_fifo_full) & 
             (i_icb_cmd_read ? i_axi_arready : (i_axi_awready & i_axi_wready));
  assign i_axi_awvalid = i_icb_cmd_valid & (~i_icb_cmd_read) & i_axi_wready  & (~rw_fifo_full);
  assign i_axi_wvalid  = i_icb_cmd_valid & (~i_icb_cmd_read) & i_axi_awready & (~rw_fifo_full); 
  //
  
  //   Generate the AXI address channel address which is direct got 
  //     from ICB command channel
  assign i_axi_araddr = i_icb_cmd_addr;
  assign i_axi_awaddr = i_icb_cmd_addr;
  
  //
  // For these attribute signals we just make it tied to zero
  assign i_axi_arcache = 4'b0;
  assign i_axi_awcache = 4'b0;
  assign i_axi_arprot =  3'b0;
  assign i_axi_awprot =  3'b0;
  assign i_axi_arlock = 2'b0;
  assign i_axi_awlock = 2'b0;
  //
  // The ICB does not support burst now, so just make it fixed
  assign i_axi_arburst = 2'b0;
  assign i_axi_awburst = 2'b0;
  assign i_axi_arlen = 4'b0;
  assign i_axi_awlen = 4'b0;
  
  generate 
    if(DW==32) begin:dw_32
      assign i_axi_arsize = 3'b10;
      assign i_axi_awsize = 3'b10;
    end
    if(DW==64) begin:dw_64
      assign i_axi_arsize = 3'b11;
      assign i_axi_awsize = 3'b11;
    end
  endgenerate
  
  // Generate the Write data channel
  assign i_axi_wdata = i_icb_cmd_wdata;
  assign i_axi_wstrb = i_icb_cmd_wmask;
  assign i_axi_wlast = 1'b1;

  wire rw_fifo_wen = i_icb_cmd_valid & i_icb_cmd_ready;
  wire rw_fifo_ren = i_icb_rsp_valid & i_icb_rsp_ready;

  wire rw_fifo_i_ready;
  wire rw_fifo_i_valid = rw_fifo_wen;
  wire rw_fifo_o_valid ;
  wire rw_fifo_o_ready = rw_fifo_ren;

  assign rw_fifo_full    = (~rw_fifo_i_ready);
  wire rw_fifo_empty   = (~rw_fifo_o_valid);

  wire i_icb_rsp_read;

  fifo_async # (
    //.CUT_READY (FIFO_CUT_READY),
    //.MSKO      (1),
    .DP  (FIFO_OUTS_NUM),
    .DW  (1),
	.ASYNC(0),
	.FLAG_ACTIVE_HIGH(1)
  ) u_fifo_sync_read (
	  /*autoinst*/
	.i_clk                  (i_clk                          ), //input
	.i_rst_n                (i_rst_n                        ), //input
	.i_data                 (i_icb_cmd_read), //input
	.i_valid                (rw_fifo_i_valid), //input
	.i_ready                (rw_fifo_i_ready), //output
	.o_clk                  (i_clk), //input
	.o_rst_n                (i_rst_n), //input
	.o_data                 (i_icb_rsp_read), //output
	.o_ready                (rw_fifo_o_ready), //input
	.o_valid                (rw_fifo_o_valid)  //output
);

//////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////
// Generate the response channel
  assign i_icb_rsp_valid = i_icb_rsp_read ? i_axi_rvalid : i_axi_bvalid;
  assign i_axi_rready = i_icb_rsp_read & i_icb_rsp_ready;
  assign i_axi_bready = (~i_icb_rsp_read) & i_icb_rsp_ready;

  assign i_icb_rsp_err = i_icb_rsp_read ? i_axi_rresp[1] //SLVERR or DECERR 
                                        : i_axi_bresp[1];
  assign i_icb_rsp_rdata = i_icb_rsp_read ? i_axi_rdata : {DW{1'b0}}; 

  axi_buffer #(
     .CHNL_FIFO_DP         (AXI_FIFO_DP       ), 
     //.CHNL_FIFO_CUT_READY  (AXI_FIFO_CUT_READY),
     .AW                   (AW),
     .DW                   (DW) 
    ) u_axi_buffer (
	.i_clk(i_clk),
	.i_rst_n(i_rst_n),
    .i_axi_arvalid   (i_axi_arvalid),
    .i_axi_arready   (i_axi_arready),
    .i_axi_araddr    (i_axi_araddr ),
    .i_axi_arcache   (i_axi_arcache),
    .i_axi_arprot    (i_axi_arprot ),
    .i_axi_arlock    (i_axi_arlock ),
    .i_axi_arburst   (i_axi_arburst),
    .i_axi_arlen     (i_axi_arlen  ),
    .i_axi_arsize    (i_axi_arsize ),
                                   
    .i_axi_awvalid   (i_axi_awvalid),
    .i_axi_awready   (i_axi_awready),
    .i_axi_awaddr    (i_axi_awaddr ),
    .i_axi_awcache   (i_axi_awcache),
    .i_axi_awprot    (i_axi_awprot ),
    .i_axi_awlock    (i_axi_awlock ),
    .i_axi_awburst   (i_axi_awburst),
    .i_axi_awlen     (i_axi_awlen  ),
    .i_axi_awsize    (i_axi_awsize ),
                                   
    .i_axi_rvalid    (i_axi_rvalid ),
    .i_axi_rready    (i_axi_rready ),
    .i_axi_rdata     (i_axi_rdata  ),
    .i_axi_rresp     (i_axi_rresp  ),
    .i_axi_rlast     (i_axi_rlast  ),
                                   
    .i_axi_wvalid    (i_axi_wvalid ),
    .i_axi_wready    (i_axi_wready ),
    .i_axi_wdata     (i_axi_wdata  ),
    .i_axi_wstrb     (i_axi_wstrb  ),
    .i_axi_wlast     (i_axi_wlast  ),
                                   
    .i_axi_bvalid    (i_axi_bvalid ),
    .i_axi_bready    (i_axi_bready ),
    .i_axi_bresp     (i_axi_bresp  ),

	.o_clk           (o_clk),
	.o_rst_n         (o_rst_n),
                                   
    .o_axi_arvalid   (o_axi_arvalid),
    .o_axi_arready   (o_axi_arready),
    .o_axi_araddr    (o_axi_araddr ),
    .o_axi_arcache   (o_axi_arcache),
    .o_axi_arprot    (o_axi_arprot ),
    .o_axi_arlock    (o_axi_arlock ),
    .o_axi_arburst   (o_axi_arburst),
    .o_axi_arlen     (o_axi_arlen  ),
    .o_axi_arsize    (o_axi_arsize ),
                      
    .o_axi_awvalid   (o_axi_awvalid),
    .o_axi_awready   (o_axi_awready),
    .o_axi_awaddr    (o_axi_awaddr ),
    .o_axi_awcache   (o_axi_awcache),
    .o_axi_awprot    (o_axi_awprot ),
    .o_axi_awlock    (o_axi_awlock ),
    .o_axi_awburst   (o_axi_awburst),
    .o_axi_awlen     (o_axi_awlen  ),
    .o_axi_awsize    (o_axi_awsize ),
                     
    .o_axi_rvalid    (o_axi_rvalid ),
    .o_axi_rready    (o_axi_rready ),
    .o_axi_rdata     (o_axi_rdata  ),
    .o_axi_rresp     (o_axi_rresp  ),
    .o_axi_rlast     (o_axi_rlast  ),
                    
    .o_axi_wvalid    (o_axi_wvalid ),
    .o_axi_wready    (o_axi_wready ),
    .o_axi_wdata     (o_axi_wdata  ),
    .o_axi_wstrb     (o_axi_wstrb  ),
    .o_axi_wlast     (o_axi_wlast  ),
                   
    .o_axi_bvalid    (o_axi_bvalid ),
    .o_axi_bready    (o_axi_bready ),
    .o_axi_bresp     (o_axi_bresp  )
  );

endmodule
