module npu_axil_top #(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter WEIGHT_WIDTH    = 16,
    parameter DATA_WIDTH      = 16,
    parameter SIZE            = 16,
    parameter BUS_WIDTH       = 32,
    parameter REG_WIDTH       = 32,
    parameter AXI_ADDR_WIDTH  = 32,
    parameter NPU_ADDR_WIDTH  = AXI_ADDR_WIDTH,
    parameter IA_CACHE_BLOCKS = 4,
    parameter PS_FRAME_COUNT  = SIZE,
    parameter AXI_READ_OUTSTANDING = 4,
    parameter AXI_WRITE_OUTSTANDING = AXI_READ_OUTSTANDING,
    parameter ENABLE_IS_MODE = 1,
    parameter ENABLE_PER_CHANNEL = 1,
    parameter ENABLE_CLOCK_GATING = 1
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

    output wire                         irq,
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
    wire cfg_16x8_reg;
    wire cfg_dataflow_mode_reg;
    wire use_per_channel_reg;
    wire [REG_WIDTH-1:0] cfg_ia_reuse_num_reg;
    wire [REG_WIDTH-1:0] cfg_w_reuse_num_reg;
    wire [REG_WIDTH-1:0] cfg_row_groups_reg;
    wire [REG_WIDTH-1:0] cfg_row_tail_tiles_reg;
    wire [REG_WIDTH-1:0] cfg_col_groups_reg;
    wire [REG_WIDTH-1:0] cfg_col_tail_tiles_reg;
    wire calc_start_pulse;
    wire npu_sa_ready;
    wire npu_done_valid;
    wire npu_done_ready;
    wire [1:0] npu_err_code;
    wire [31:0] status_bits;
    wire [NPU_ADDR_WIDTH-1:0] npu_m_axi_araddr;
    wire [NPU_ADDR_WIDTH-1:0] npu_m_axi_awaddr;
    wire npu_core_clk;
    logic [1:0] npu_clk_reset_warmup_q;
    logic npu_clk_req_q;
    logic npu_start_pending_q;
    logic npu_start_warmup_q;
    logic npu_done_seen_q;
    wire npu_clk_gate_en;
    wire npu_core_calc_start;
    wire npu_done_fire;
    wire npu_axi_idle;

    assign npu_done_fire = npu_done_valid && npu_done_ready;
    assign npu_axi_idle = !m_axi_arvalid && !m_axi_awvalid && !m_axi_wvalid &&
                          !m_axi_rready && !m_axi_bready &&
                          !m_axi_rvalid && !m_axi_bvalid;

    generate
        if (ENABLE_CLOCK_GATING != 0) begin : g_npu_clock_gate
            assign npu_clk_gate_en = (|npu_clk_reset_warmup_q) ||
                                     npu_clk_req_q ||
                                     calc_start_pulse ||
                                     npu_start_pending_q ||
                                     npu_busy ||
                                     !npu_axi_idle;
`ifdef XILINX_FPGA
            BUFGCE #(
                .SIM_DEVICE("7SERIES")
            ) u_npu_clk_bufgce (
                .I (clk),
                .CE(npu_clk_gate_en),
                .O (npu_core_clk)
            );
`elsif XILINX_CLK_WIZ_IP
            BUFGCE #(
                .SIM_DEVICE("7SERIES")
            ) u_npu_clk_bufgce (
                .I (clk),
                .CE(npu_clk_gate_en),
                .O (npu_core_clk)
            );
`else
            logic npu_clk_gate_latch;

            always_latch begin
                if (!rst_n) begin
                    npu_clk_gate_latch <= 1'b1;
                end else if (!clk) begin
                    npu_clk_gate_latch <= npu_clk_gate_en;
                end
            end

            assign npu_core_clk = clk & npu_clk_gate_latch;
`endif
        end else begin : g_npu_clock_direct
            assign npu_clk_gate_en = 1'b1;
            assign npu_core_clk = clk;
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            npu_clk_reset_warmup_q <= 2'b11;
            npu_clk_req_q          <= 1'b0;
            npu_start_pending_q    <= 1'b0;
            npu_start_warmup_q     <= 1'b0;
            npu_done_seen_q        <= 1'b0;
        end else begin
            npu_clk_reset_warmup_q <= {npu_clk_reset_warmup_q[0], 1'b0};

            if (calc_start_pulse) begin
                npu_clk_req_q       <= 1'b1;
                npu_start_pending_q <= 1'b1;
                npu_start_warmup_q  <= (ENABLE_CLOCK_GATING != 0);
                npu_done_seen_q     <= 1'b0;
            end else begin
                if (npu_clk_req_q) begin
                    npu_start_warmup_q <= 1'b0;
                end
                if (npu_core_calc_start) begin
                    npu_start_pending_q <= 1'b0;
                end
                if (npu_done_fire) begin
                    npu_done_seen_q <= 1'b1;
                end
                if (npu_done_seen_q && npu_sa_ready && !npu_done_valid && npu_axi_idle) begin
                    npu_clk_req_q       <= 1'b0;
                    npu_start_pending_q <= 1'b0;
                    npu_start_warmup_q  <= 1'b0;
                    npu_done_seen_q     <= 1'b0;
                end
            end
        end
    end

    assign npu_core_calc_start = (ENABLE_CLOCK_GATING != 0)
                               ? (npu_start_pending_q && !npu_start_warmup_q && npu_sa_ready)
                               : calc_start_pulse;

    generate
        if (AXI_ADDR_WIDTH > NPU_ADDR_WIDTH) begin : g_extend_npu_addr
            assign m_axi_araddr = {{(AXI_ADDR_WIDTH - NPU_ADDR_WIDTH){1'b0}}, npu_m_axi_araddr};
            assign m_axi_awaddr = {{(AXI_ADDR_WIDTH - NPU_ADDR_WIDTH){1'b0}}, npu_m_axi_awaddr};
        end else if (AXI_ADDR_WIDTH == NPU_ADDR_WIDTH) begin : g_direct_npu_addr
            assign m_axi_araddr = npu_m_axi_araddr;
            assign m_axi_awaddr = npu_m_axi_awaddr;
        end else begin : g_truncate_npu_addr
            assign m_axi_araddr = npu_m_axi_araddr[AXI_ADDR_WIDTH-1:0];
            assign m_axi_awaddr = npu_m_axi_awaddr[AXI_ADDR_WIDTH-1:0];
        end
    endgenerate

    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arlock  = npu_busy ? 2'b01 : 2'b00;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awlock  = npu_busy ? 2'b01 : 2'b00;

    npu_axil_reg_if #(
        .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .REG_WIDTH(REG_WIDTH)
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
        .cfg_16x8(cfg_16x8_reg),
        .cfg_dataflow_mode(cfg_dataflow_mode_reg),
        .use_per_channel(use_per_channel_reg),
        .cfg_ia_reuse_num(cfg_ia_reuse_num_reg),
        .cfg_w_reuse_num(cfg_w_reuse_num_reg),
        .cfg_row_groups(cfg_row_groups_reg),
        .cfg_row_tail_tiles(cfg_row_tail_tiles_reg),
        .cfg_col_groups(cfg_col_groups_reg),
        .cfg_col_tail_tiles(cfg_col_tail_tiles_reg),
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
        .npu_done_valid(npu_done_valid),
        .npu_done_ready(npu_done_ready),
        .npu_err_code(npu_err_code),
        .irq(irq),
        .npu_busy(npu_busy),
        .status_bits(status_bits)
    );

    npu_top #(
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .BUS_WIDTH(BUS_WIDTH),
        .REG_WIDTH(REG_WIDTH),
        .ADDR_WIDTH(NPU_ADDR_WIDTH),
        .IA_CACHE_BLOCKS(IA_CACHE_BLOCKS),
        .PS_FRAME_COUNT(PS_FRAME_COUNT),
        .AXI_READ_OUTSTANDING(AXI_READ_OUTSTANDING),
        .AXI_WRITE_OUTSTANDING(AXI_WRITE_OUTSTANDING),
        .ENABLE_IS_MODE(ENABLE_IS_MODE),
        .ENABLE_PER_CHANNEL(ENABLE_PER_CHANNEL)
    ) u_npu_top (
        .clk(npu_core_clk),
        .rst_n(rst_n),
        .calc_start(npu_core_calc_start),
        .cfg_16bits_ia(cfg_16bits_ia_reg),
        .cfg_16x8(cfg_16x8_reg),
        .cfg_dataflow_mode(cfg_dataflow_mode_reg),
        .cfg_ia_reuse_num(cfg_ia_reuse_num_reg),
        .cfg_w_reuse_num(cfg_w_reuse_num_reg),
        .cfg_row_groups(cfg_row_groups_reg),
        .cfg_row_tail_tiles(cfg_row_tail_tiles_reg),
        .cfg_col_groups(cfg_col_groups_reg),
        .cfg_col_tail_tiles(cfg_col_tail_tiles_reg),
        .sa_ready(npu_sa_ready),
        .done_valid(npu_done_valid),
        .done_ready(npu_done_ready),
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
        .m_axi_araddr(npu_m_axi_araddr),
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
        .m_axi_awaddr(npu_m_axi_awaddr),
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
