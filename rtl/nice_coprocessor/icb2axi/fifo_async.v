module fifo_async # (
	// When the depth is 1, the ready signal may relevant to next stage's ready, hence become logic
	// chains. Use CUT_READY to control it
	// When fifo depth is 1, the fifo is a signle stage
	   // if CUT_READY is set, then the back-pressure ready signal will be cut
	   //      off, and it can only pass 1 data every 2 cycles
	// When fifo depth is > 1, then it is actually a really fifo
	   //      The CUT_READY parameter have no impact to any logics
	//parameter CUT_READY = 0,
	//parameter MSKO = 0,// Mask out the data with valid or not
	parameter DP   = 8,// FIFO depth
	parameter DW   = 32,// FIFO width
	parameter ASYNC = 1,
	parameter FLAG_ACTIVE_HIGH = 1
) (
	input i_clk,
	input i_rst_n,
	input [DW-1:0] i_data,
	input i_valid,
	output i_ready,

	input o_clk,
	input o_rst_n,
	output [DW-1:0] o_data,
	input o_ready,
	output o_valid
);

parameter PW = (ASYNC) ? ($clog2(DP) + 1) : $clog2(DP);
parameter PW_EFF = $clog2(DP);

reg [DW-1:0] fifo [DP-1:0];

wire wr_en;
wire rd_en;
wire fifo_full;
wire fifo_empty;

assign wr_en = i_valid & (~fifo_full);
assign rd_en = o_ready & (~fifo_empty);

generate
	if(FLAG_ACTIVE_HIGH) begin: flag_active_high
		assign i_ready = ~fifo_full;
		assign o_valid = ~fifo_empty;
	end else begin: flag_active_low
		assign i_ready = fifo_full;
		assign o_valid = fifo_empty;
	end
endgenerate

// write pointer
reg [PW-1:0] wr_ptr;
wire [PW_EFF-1:0] wr_ptr_eff;
generate
	if(ASYNC) begin: wr_ptr_eff_async
		assign wr_ptr_eff = wr_ptr[PW-2:0];
	end else begin: wr_ptr_eff_sync
		assign wr_ptr_eff = wr_ptr;
	end
endgenerate

always @(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		wr_ptr <= {(PW) {1'b0}};
	end else begin
		wr_ptr <= wr_en ? (wr_ptr + 1'b1) : wr_ptr;
	end
end

// write data
integer i;
always @(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		for(i=0; i<DP; i=i+1) begin: fifo_reset
			fifo[i] <= {(DW) {1'b0}};
		end
	end else begin
		if(wr_en) begin
			fifo[wr_ptr_eff] <= i_data;
		end
	end
end

// read pointer
reg [PW-1:0] rd_ptr;
always @(posedge o_clk or negedge o_rst_n) begin
	if(!o_rst_n) begin
		rd_ptr <= {(PW) {1'b0}};
	end else begin
		rd_ptr <= rd_en ? (rd_ptr + 1'b1) : rd_ptr;
	end
end

// read data
//reg [DW-1:0] rd_data;
//assign o_data = rd_data;
//always @(posedge o_clk or negedge o_rst_n) begin
//	if(!o_rst_n) begin
//		rd_data <= {(DW) {1'b0}};
//	end else begin
//		if(rd_en) begin
//			rd_data <= fifo[rd_ptr[PW-2:0]];
//		end
//	end
//end
generate
	if(ASYNC)
		assign o_data = fifo[rd_ptr[PW-2:0]];
	else
		assign o_data = fifo[rd_ptr[PW-1:0]];
endgenerate

generate
	if(ASYNC == 1) begin: async_ctrl
		// grey convert
		wire [PW-1:0] wr_ptr_grey;
		wire [PW-1:0] rd_ptr_grey;
		assign wr_ptr_grey = wr_ptr ^ (wr_ptr >> 1);
		assign rd_ptr_grey = rd_ptr ^ (rd_ptr >> 1);

		// pointer sync
		reg [PW-1:0] wr_ptr_grey_r [1:0];
		always @(posedge o_clk or negedge o_rst_n) begin
			if(!o_rst_n) begin
				wr_ptr_grey_r[0] <= {(PW) {1'b0}};
				wr_ptr_grey_r[1] <= {(PW) {1'b0}};
			end else begin
				wr_ptr_grey_r[0] <= wr_ptr_grey;
				wr_ptr_grey_r[1] <= wr_ptr_grey_r[0];
			end
		end
		reg [PW-1:0] rd_ptr_grey_r [1:0];
		always @(posedge i_clk or negedge i_rst_n) begin
			if(!i_rst_n) begin
				rd_ptr_grey_r[0] <= {(PW) {1'b0}};
				rd_ptr_grey_r[1] <= {(PW) {1'b0}};
			end else begin
				rd_ptr_grey_r[0] <= rd_ptr_grey;
				rd_ptr_grey_r[1] <= rd_ptr_grey_r[0];
			end
		end

		// fifo_full
		if(PW == 1) begin
			assign fifo_full = (wr_ptr_grey == ~rd_ptr_grey_r[1][PW-1:PW-2]) ? 1'b1 : 1'b0;
		end else if(PW == 2) begin
			assign fifo_full = (wr_ptr_grey == ~rd_ptr_grey_r[1][PW-1:PW-2]) ? 1'b1 : 1'b0;
		end else begin
			assign fifo_full = (wr_ptr_grey == {~rd_ptr_grey_r[1][PW-1:PW-2], rd_ptr_grey_r[1][PW-3:0]}) ? 1'b1 : 1'b0;
		end
		// fifo_empty
		assign fifo_empty = (rd_ptr_grey == wr_ptr_grey_r[1]) ? 1'b1 : 1'b0;
	end else begin: sync_ctrl
		wire [PW-1:0] wr_ptr_plus_1;
		assign wr_ptr_plus_1 = wr_ptr[PW-1:0] + 1'b1;
		assign fifo_full = (wr_ptr_plus_1 == rd_ptr[PW-1:0]) ? 1'b1 : 1'b0;
		assign fifo_empty = (wr_ptr[PW-1:0] == rd_ptr[PW-1:0]) ? 1'b1 : 1'b0;
	end
endgenerate

endmodule 
