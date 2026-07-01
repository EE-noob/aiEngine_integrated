module soc_axi_pingpong_chan #(
    parameter int unsigned WIDTH = 1
) (
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire                   s_valid,
    output wire                   s_ready,
    input  wire [WIDTH-1:0]       s_data,

    output wire                   m_valid,
    input  wire                   m_ready,
    output wire [WIDTH-1:0]       m_data
);

    logic [WIDTH-1:0] data0_q;
    logic [WIDTH-1:0] data1_q;
    logic             rd_sel_q;
    logic             wr_sel_q;
    logic [1:0]       count_q;

    wire push = s_valid && s_ready;
    wire pop  = m_valid && m_ready;

    assign s_ready = (count_q != 2'd2);
    assign m_valid = (count_q != 2'd0);
    assign m_data  = rd_sel_q ? data1_q : data0_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data0_q  <= '0;
            data1_q  <= '0;
            rd_sel_q <= 1'b0;
            wr_sel_q <= 1'b0;
            count_q  <= 2'd0;
        end else begin
            if (push) begin
                if (wr_sel_q) begin
                    data1_q <= s_data;
                end else begin
                    data0_q <= s_data;
                end
                wr_sel_q <= ~wr_sel_q;
            end

            if (pop) begin
                rd_sel_q <= ~rd_sel_q;
            end

            unique case ({push, pop})
                2'b10: count_q <= count_q + 2'd1;
                2'b01: count_q <= count_q - 2'd1;
                default: count_q <= count_q;
            endcase
        end
    end

endmodule

module soc_axil_pingpong_buffer #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [ADDR_WIDTH-1:0]        s_axil_awaddr,
    input  wire [2:0]                   s_axil_awprot,
    input  wire                         s_axil_awvalid,
    output wire                         s_axil_awready,
    input  wire [DATA_WIDTH-1:0]        s_axil_wdata,
    input  wire [DATA_WIDTH/8-1:0]      s_axil_wstrb,
    input  wire                         s_axil_wvalid,
    output wire                         s_axil_wready,
    output wire [1:0]                   s_axil_bresp,
    output wire                         s_axil_bvalid,
    input  wire                         s_axil_bready,
    input  wire [ADDR_WIDTH-1:0]        s_axil_araddr,
    input  wire [2:0]                   s_axil_arprot,
    input  wire                         s_axil_arvalid,
    output wire                         s_axil_arready,
    output wire [DATA_WIDTH-1:0]        s_axil_rdata,
    output wire [1:0]                   s_axil_rresp,
    output wire                         s_axil_rvalid,
    input  wire                         s_axil_rready,

    output wire [ADDR_WIDTH-1:0]        m_axil_awaddr,
    output wire [2:0]                   m_axil_awprot,
    output wire                         m_axil_awvalid,
    input  wire                         m_axil_awready,
    output wire [DATA_WIDTH-1:0]        m_axil_wdata,
    output wire [DATA_WIDTH/8-1:0]      m_axil_wstrb,
    output wire                         m_axil_wvalid,
    input  wire                         m_axil_wready,
    input  wire [1:0]                   m_axil_bresp,
    input  wire                         m_axil_bvalid,
    output wire                         m_axil_bready,
    output wire [ADDR_WIDTH-1:0]        m_axil_araddr,
    output wire [2:0]                   m_axil_arprot,
    output wire                         m_axil_arvalid,
    input  wire                         m_axil_arready,
    input  wire [DATA_WIDTH-1:0]        m_axil_rdata,
    input  wire [1:0]                   m_axil_rresp,
    input  wire                         m_axil_rvalid,
    output wire                         m_axil_rready
);

    localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8;
    localparam int unsigned AW_WIDTH = ADDR_WIDTH + 3;
    localparam int unsigned W_WIDTH  = DATA_WIDTH + STRB_WIDTH;
    localparam int unsigned B_WIDTH  = 2;
    localparam int unsigned AR_WIDTH = ADDR_WIDTH + 3;
    localparam int unsigned R_WIDTH  = DATA_WIDTH + 2;

    wire [AW_WIDTH-1:0] s_aw_payload;
    wire [AW_WIDTH-1:0] m_aw_payload;
    wire [W_WIDTH-1:0]  s_w_payload;
    wire [W_WIDTH-1:0]  m_w_payload;
    wire [B_WIDTH-1:0]  s_b_payload;
    wire [B_WIDTH-1:0]  m_b_payload;
    wire [AR_WIDTH-1:0] s_ar_payload;
    wire [AR_WIDTH-1:0] m_ar_payload;
    wire [R_WIDTH-1:0]  s_r_payload;
    wire [R_WIDTH-1:0]  m_r_payload;

    assign s_aw_payload = {s_axil_awaddr, s_axil_awprot};
    assign {m_axil_awaddr, m_axil_awprot} = m_aw_payload;

    assign s_w_payload = {s_axil_wdata, s_axil_wstrb};
    assign {m_axil_wdata, m_axil_wstrb} = m_w_payload;

    assign s_b_payload = m_axil_bresp;
    assign s_axil_bresp = m_b_payload;

    assign s_ar_payload = {s_axil_araddr, s_axil_arprot};
    assign {m_axil_araddr, m_axil_arprot} = m_ar_payload;

    assign s_r_payload = {m_axil_rdata, m_axil_rresp};
    assign {s_axil_rdata, s_axil_rresp} = m_r_payload;

    soc_axi_pingpong_chan #(.WIDTH(AW_WIDTH)) u_aw_buf (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(s_axil_awvalid),
        .s_ready(s_axil_awready),
        .s_data(s_aw_payload),
        .m_valid(m_axil_awvalid),
        .m_ready(m_axil_awready),
        .m_data(m_aw_payload)
    );

    soc_axi_pingpong_chan #(.WIDTH(W_WIDTH)) u_w_buf (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(s_axil_wvalid),
        .s_ready(s_axil_wready),
        .s_data(s_w_payload),
        .m_valid(m_axil_wvalid),
        .m_ready(m_axil_wready),
        .m_data(m_w_payload)
    );

    soc_axi_pingpong_chan #(.WIDTH(B_WIDTH)) u_b_buf (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(m_axil_bvalid),
        .s_ready(m_axil_bready),
        .s_data(s_b_payload),
        .m_valid(s_axil_bvalid),
        .m_ready(s_axil_bready),
        .m_data(m_b_payload)
    );

    soc_axi_pingpong_chan #(.WIDTH(AR_WIDTH)) u_ar_buf (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(s_axil_arvalid),
        .s_ready(s_axil_arready),
        .s_data(s_ar_payload),
        .m_valid(m_axil_arvalid),
        .m_ready(m_axil_arready),
        .m_data(m_ar_payload)
    );

    soc_axi_pingpong_chan #(.WIDTH(R_WIDTH)) u_r_buf (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(m_axil_rvalid),
        .s_ready(m_axil_rready),
        .s_data(s_r_payload),
        .m_valid(s_axil_rvalid),
        .m_ready(s_axil_rready),
        .m_data(m_r_payload)
    );

endmodule

module soc_axi_pingpong_buffer #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,
    input  wire [ADDR_WIDTH-1:0]        s_axi_araddr,
    input  wire [3:0]                   s_axi_arcache,
    input  wire [2:0]                   s_axi_arprot,
    input  wire [1:0]                   s_axi_arlock,
    input  wire [1:0]                   s_axi_arburst,
    input  wire [7:0]                   s_axi_arlen,
    input  wire [2:0]                   s_axi_arsize,
    output wire                         s_axi_rvalid,
    input  wire                         s_axi_rready,
    output wire [DATA_WIDTH-1:0]        s_axi_rdata,
    output wire [1:0]                   s_axi_rresp,
    output wire                         s_axi_rlast,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,
    input  wire [ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  wire [3:0]                   s_axi_awcache,
    input  wire [2:0]                   s_axi_awprot,
    input  wire [1:0]                   s_axi_awlock,
    input  wire [1:0]                   s_axi_awburst,
    input  wire [7:0]                   s_axi_awlen,
    input  wire [2:0]                   s_axi_awsize,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,
    input  wire [DATA_WIDTH-1:0]        s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]      s_axi_wstrb,
    input  wire                         s_axi_wlast,
    output wire                         s_axi_bvalid,
    input  wire                         s_axi_bready,
    output wire [1:0]                   s_axi_bresp,

    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,
    output wire [ADDR_WIDTH-1:0]        m_axi_araddr,
    output wire [3:0]                   m_axi_arcache,
    output wire [2:0]                   m_axi_arprot,
    output wire [1:0]                   m_axi_arlock,
    output wire [1:0]                   m_axi_arburst,
    output wire [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,
    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready,
    input  wire [DATA_WIDTH-1:0]        m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,
    output wire [ADDR_WIDTH-1:0]        m_axi_awaddr,
    output wire [3:0]                   m_axi_awcache,
    output wire [2:0]                   m_axi_awprot,
    output wire [1:0]                   m_axi_awlock,
    output wire [1:0]                   m_axi_awburst,
    output wire [7:0]                   m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,
    output wire                         m_axi_wvalid,
    input  wire                         m_axi_wready,
    output wire [DATA_WIDTH-1:0]        m_axi_wdata,
    output wire [DATA_WIDTH/8-1:0]      m_axi_wstrb,
    output wire                         m_axi_wlast,
    input  wire                         m_axi_bvalid,
    output wire                         m_axi_bready,
    input  wire [1:0]                   m_axi_bresp
);

    localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8;
    localparam int unsigned AR_WIDTH = ADDR_WIDTH + 4 + 3 + 2 + 2 + 8 + 3;
    localparam int unsigned AW_WIDTH = AR_WIDTH;
    localparam int unsigned W_WIDTH  = DATA_WIDTH + STRB_WIDTH + 1;
    localparam int unsigned R_WIDTH  = DATA_WIDTH + 2 + 1;
    localparam int unsigned B_WIDTH  = 2;

    wire [AR_WIDTH-1:0] s_ar_payload;
    wire [AR_WIDTH-1:0] m_ar_payload;
    wire [AW_WIDTH-1:0] s_aw_payload;
    wire [AW_WIDTH-1:0] m_aw_payload;
    wire [W_WIDTH-1:0]  s_w_payload;
    wire [W_WIDTH-1:0]  m_w_payload;
    wire [R_WIDTH-1:0]  s_r_payload;
    wire [R_WIDTH-1:0]  m_r_payload;
    wire [B_WIDTH-1:0]  s_b_payload;
    wire [B_WIDTH-1:0]  m_b_payload;

    assign s_ar_payload = {s_axi_araddr, s_axi_arcache, s_axi_arprot,
                           s_axi_arlock, s_axi_arburst, s_axi_arlen,
                           s_axi_arsize};
    assign {m_axi_araddr, m_axi_arcache, m_axi_arprot, m_axi_arlock,
            m_axi_arburst, m_axi_arlen, m_axi_arsize} = m_ar_payload;

    assign s_aw_payload = {s_axi_awaddr, s_axi_awcache, s_axi_awprot,
                           s_axi_awlock, s_axi_awburst, s_axi_awlen,
                           s_axi_awsize};
    assign {m_axi_awaddr, m_axi_awcache, m_axi_awprot, m_axi_awlock,
            m_axi_awburst, m_axi_awlen, m_axi_awsize} = m_aw_payload;

    assign s_w_payload = {s_axi_wdata, s_axi_wstrb, s_axi_wlast};
    assign {m_axi_wdata, m_axi_wstrb, m_axi_wlast} = m_w_payload;

    assign s_r_payload = {m_axi_rdata, m_axi_rresp, m_axi_rlast};
    assign {s_axi_rdata, s_axi_rresp, s_axi_rlast} = m_r_payload;

    assign s_b_payload = m_axi_bresp;
    assign s_axi_bresp = m_b_payload;

    soc_axi_pingpong_chan #(.WIDTH(AR_WIDTH)) u_ar_buf (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(s_axi_arvalid),
        .s_ready(s_axi_arready),
        .s_data(s_ar_payload),
        .m_valid(m_axi_arvalid),
        .m_ready(m_axi_arready),
        .m_data(m_ar_payload)
    );

    soc_axi_pingpong_chan #(.WIDTH(AW_WIDTH)) u_aw_buf (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(s_axi_awvalid),
        .s_ready(s_axi_awready),
        .s_data(s_aw_payload),
        .m_valid(m_axi_awvalid),
        .m_ready(m_axi_awready),
        .m_data(m_aw_payload)
    );

    soc_axi_pingpong_chan #(.WIDTH(W_WIDTH)) u_w_buf (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(s_axi_wvalid),
        .s_ready(s_axi_wready),
        .s_data(s_w_payload),
        .m_valid(m_axi_wvalid),
        .m_ready(m_axi_wready),
        .m_data(m_w_payload)
    );

    soc_axi_pingpong_chan #(.WIDTH(R_WIDTH)) u_r_buf (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(m_axi_rvalid),
        .s_ready(m_axi_rready),
        .s_data(s_r_payload),
        .m_valid(s_axi_rvalid),
        .m_ready(s_axi_rready),
        .m_data(m_r_payload)
    );

    soc_axi_pingpong_chan #(.WIDTH(B_WIDTH)) u_b_buf (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(m_axi_bvalid),
        .s_ready(m_axi_bready),
        .s_data(s_b_payload),
        .m_valid(s_axi_bvalid),
        .m_ready(s_axi_bready),
        .m_data(m_b_payload)
    );

endmodule
