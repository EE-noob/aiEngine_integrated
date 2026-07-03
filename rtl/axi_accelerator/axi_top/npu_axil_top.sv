module npu_axil_top #(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter WEIGHT_WIDTH    = 16,
    parameter DATA_WIDTH      = 16,
    parameter SIZE            = 16,
    parameter BUS_WIDTH       = 32,
    parameter REG_WIDTH       = 32,
    parameter AXI_ADDR_WIDTH  = 32,
    parameter IA_CACHE_BLOCKS = 4,
    parameter PS_FRAME_COUNT  = SIZE,
    parameter AXI_READ_OUTSTANDING = 4,
    parameter AXI_WRITE_OUTSTANDING = AXI_READ_OUTSTANDING,
    parameter [31:0] IRQ_STATUS_MASK = 32'h0000_0004
) (
    input  wire clk,
    input  wire rst_n,

    input  wire [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr,
    input  wire [2:0]                 s_axil_awprot,
    input  wire                       s_axil_awvalid,
    output wire                       s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0] s_axil_wdata,
    input  wire [AXIL_DATA_WIDTH/8-1:0] s_axil_wstrb,
    input  wire                       s_axil_wvalid,
    output wire                       s_axil_wready,
    output wire [1:0]                 s_axil_bresp,
    output wire                       s_axil_bvalid,
    input  wire                       s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0] s_axil_araddr,
    input  wire [2:0]                 s_axil_arprot,
    input  wire                       s_axil_arvalid,
    output wire                       s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0] s_axil_rdata,
    output wire [1:0]                 s_axil_rresp,
    output wire                       s_axil_rvalid,
    input  wire                       s_axil_rready,

    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [3:0]                   m_axi_arcache,
    output wire [2:0]                   m_axi_arprot,
    output wire [1:0]                   m_axi_arlock,
    output wire [1:0]                   m_axi_arburst,
    output wire [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,

    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [3:0]                   m_axi_awcache,
    output wire [2:0]                   m_axi_awprot,
    output wire [1:0]                   m_axi_awlock,
    output wire [1:0]                   m_axi_awburst,
    output wire [7:0]                   m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,

    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready,
    input  wire [BUS_WIDTH-1:0]         m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,

    output wire                         m_axi_wvalid,
    input  wire                         m_axi_wready,
    output wire [BUS_WIDTH-1:0]         m_axi_wdata,
    output wire [BUS_WIDTH/8-1:0]       m_axi_wstrb,
    output wire                         m_axi_wlast,

    input  wire                         m_axi_bvalid,
    output wire                         m_axi_bready,
    input  wire [1:0]                   m_axi_bresp,

    output wire [31:0]                  irq,
    input  wire [31:0]                  eoi,
    output wire                         npu_busy
);

    wire [REG_WIDTH-1:0] lhs_base_reg;
    wire [REG_WIDTH-1:0] rhs_base_reg;
    wire [REG_WIDTH-1:0] dst_base_reg;
    wire [REG_WIDTH-1:0] bias_base_reg;
    wire [REG_WIDTH-1:0] k_reg;
    wire [REG_WIDTH-1:0] n_reg;
    wire [REG_WIDTH-1:0] m_reg;
    wire [REG_WIDTH-1:0] lhs_row_stride_b_reg;
    wire [REG_WIDTH-1:0] rhs_col_stride_b_reg;
    wire [REG_WIDTH-1:0] dst_row_stride_b_reg;
    wire signed [REG_WIDTH-1:0] lhs_zp_reg;
    wire signed [REG_WIDTH-1:0] rhs_zp_reg;
    wire signed [REG_WIDTH-1:0] dst_zp_reg;
    wire signed [REG_WIDTH-1:0] q_mult_pt_reg;
    wire signed [REG_WIDTH-1:0] q_shift_pt_reg;
    wire signed [REG_WIDTH-1:0] act_min_reg;
    wire signed [REG_WIDTH-1:0] act_max_reg;
    wire cfg_16bits_ia_reg;
    wire cfg_dataflow_mode_reg;
    wire use_per_channel_reg;
    wire [REG_WIDTH-1:0] cfg_ia_reuse_num_reg;
    wire [REG_WIDTH-1:0] cfg_w_reuse_num_reg;
    wire calc_start_pulse;
    wire npu_sa_ready;
    wire npu_wb_valid;
    wire npu_wb_ready;
    wire [1:0] npu_err_code;
    wire [31:0] status_bits;

    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arlock  = 2'b00;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awlock  = 2'b00;

    npu_axil_reg_if #(
        .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .REG_WIDTH(REG_WIDTH),
        .IRQ_STATUS_MASK(IRQ_STATUS_MASK)
    ) u_npu_axil_reg_if (
        .clk(clk),
        .rst_n(rst_n),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awprot(s_axil_awprot),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arprot(s_axil_arprot),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready),
        .calc_start(calc_start_pulse),
        .cfg_16bits_ia(cfg_16bits_ia_reg),
        .cfg_dataflow_mode(cfg_dataflow_mode_reg),
        .use_per_channel(use_per_channel_reg),
        .cfg_ia_reuse_num(cfg_ia_reuse_num_reg),
        .cfg_w_reuse_num(cfg_w_reuse_num_reg),
        .lhs_base(lhs_base_reg),
        .rhs_base(rhs_base_reg),
        .dst_base(dst_base_reg),
        .bias_base(bias_base_reg),
        .lhs_zp(lhs_zp_reg),
        .rhs_zp(rhs_zp_reg),
        .dst_zp(dst_zp_reg),
        .q_mult_pt(q_mult_pt_reg),
        .q_shift_pt(q_shift_pt_reg),
        .k(k_reg),
        .n(n_reg),
        .m(m_reg),
        .lhs_row_stride_b(lhs_row_stride_b_reg),
        .rhs_col_stride_b(rhs_col_stride_b_reg),
        .dst_row_stride_b(dst_row_stride_b_reg),
        .act_min(act_min_reg),
        .act_max(act_max_reg),
        .npu_sa_ready(npu_sa_ready),
        .npu_wb_valid(npu_wb_valid),
        .npu_wb_ready(npu_wb_ready),
        .npu_err_code(npu_err_code),
        .irq(irq),
        .eoi(eoi),
        .npu_busy(npu_busy),
        .status_bits(status_bits)
    );

    npu_top #(
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .BUS_WIDTH(BUS_WIDTH),
        .REG_WIDTH(REG_WIDTH),
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .IA_CACHE_BLOCKS(IA_CACHE_BLOCKS),
        .PS_FRAME_COUNT(PS_FRAME_COUNT),
        .AXI_READ_OUTSTANDING(AXI_READ_OUTSTANDING),
        .AXI_WRITE_OUTSTANDING(AXI_WRITE_OUTSTANDING)
    ) u_npu_top (
        .clk(clk),
        .rst_n(rst_n),
        .calc_start(calc_start_pulse),
        .cfg_16bits_ia(cfg_16bits_ia_reg),
        .cfg_dataflow_mode(cfg_dataflow_mode_reg),
        .cfg_ia_reuse_num(cfg_ia_reuse_num_reg),
        .cfg_w_reuse_num(cfg_w_reuse_num_reg),
        .sa_ready(npu_sa_ready),
        .wb_valid(npu_wb_valid),
        .wb_ready(npu_wb_ready),
        .err_code(npu_err_code),
        .lhs_base(lhs_base_reg),
        .rhs_base(rhs_base_reg),
        .dst_base(dst_base_reg),
        .bias_base(bias_base_reg),
        .lhs_zp(lhs_zp_reg),
        .rhs_zp(rhs_zp_reg),
        .dst_zp(dst_zp_reg),
        .q_mult_pt(q_mult_pt_reg),
        .q_shift_pt(q_shift_pt_reg),
        .use_per_channel(use_per_channel_reg),
        .k(k_reg),
        .n(n_reg),
        .m(m_reg),
        .lhs_row_stride_b(lhs_row_stride_b_reg),
        .dst_row_stride_b(dst_row_stride_b_reg),
        .rhs_col_stride_b(rhs_col_stride_b_reg),
        .act_min(act_min_reg),
        .act_max(act_max_reg),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp)
    );

endmodule
