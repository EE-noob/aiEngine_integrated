`include "e203_defines.v"

module mma_axil_top #(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter WEIGHT_WIDTH    = 16,
    parameter DATA_WIDTH      = 16,
    parameter SIZE            = 16,
    parameter BUS_WIDTH       = 32,
    parameter REG_WIDTH       = 32,
    parameter ICB_ADDR_WIDTH  = 32,
    parameter ICB_LEN_W       = 4,
	    parameter IA_CACHE_BLOCKS = 4,
	    parameter PS_FRAME_COUNT  = SIZE,
	    parameter AXI_READ_OUTSTANDING = 4,
	    parameter AXI_WRITE_OUTSTANDING = AXI_READ_OUTSTANDING,
    parameter [31:0] IRQ_STATUS_MASK = 32'h0000_0004
) (
    input  wire clk,
    input  wire rst_n,

    // AXI-Lite slave interface
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

    // Native AXI master interface from MMA DMA
    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,
    output wire [ICB_ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [3:0]                   m_axi_arcache,
    output wire [2:0]                   m_axi_arprot,
    output wire [1:0]                   m_axi_arlock,
    output wire [1:0]                   m_axi_arburst,
    output wire [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,

    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,
    output wire [ICB_ADDR_WIDTH-1:0]    m_axi_awaddr,
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

    // PicoRV32-style interrupt interface
    output wire [31:0]                  irq,
    input  wire [31:0]                  eoi,

    // Optional status output
    output wire                         mma_busy
);

    localparam [11:0] REG_CTRL     = 12'h000;
    localparam [11:0] REG_STATUS   = 12'h001;
    localparam [11:0] REG_WB_DATA  = 12'h002;
    localparam [11:0] REG_WB_INFO  = 12'h003;
    localparam [11:0] REG_IA_REUSE = 12'h004;
    localparam [11:0] REG_W_REUSE  = 12'h005;
    localparam [11:0] CSR_ADDR_MIN = 12'h7C0;
    localparam [11:0] CSR_ADDR_MAX = 12'h7D0;

    // AXI-Lite register request bus from verilog-axi
    wire [AXIL_ADDR_WIDTH-1:0] reg_wr_addr;
    wire [AXIL_DATA_WIDTH-1:0] reg_wr_data;
    wire [AXIL_DATA_WIDTH/8-1:0] reg_wr_strb;
    wire reg_wr_en;
    wire reg_wr_wait;
    wire reg_wr_ack;

    wire [AXIL_ADDR_WIDTH-1:0] reg_rd_addr;
    wire reg_rd_en;
    wire [AXIL_DATA_WIDTH-1:0] reg_rd_data;
    wire reg_rd_wait;
    wire reg_rd_ack;

    // CSR request wires
    reg                  csr_req;
    reg                  is_csr_read;
    reg  [11:0]          csr_addr;
    reg  [REG_WIDTH-1:0] csr_wdata;
    wire                 csr_ready;
    wire [REG_WIDTH-1:0] csr_rdata;

    // CSR outputs used by MMA
    wire [REG_WIDTH-1:0] lhs_base;
    wire [REG_WIDTH-1:0] rhs_base;
    wire [REG_WIDTH-1:0] dst_base_csr;
    wire [REG_WIDTH-1:0] bias_base;
    wire signed [REG_WIDTH-1:0] lhs_zp;
    wire signed [REG_WIDTH-1:0] rhs_zp;
    wire signed [REG_WIDTH-1:0] dst_zp;
    wire signed [REG_WIDTH-1:0] q_mult_pt;
    wire signed [REG_WIDTH-1:0] q_shift_pt;
    wire [REG_WIDTH-1:0] m;
    wire [REG_WIDTH-1:0] k;
    wire [REG_WIDTH-1:0] n;
    wire [REG_WIDTH-1:0] lhs_row_stride_b;
    wire [REG_WIDTH-1:0] dst_row_stride_b;
    wire [REG_WIDTH-1:0] rhs_col_stride_b;
    wire signed [REG_WIDTH-1:0] act_min;
    wire signed [REG_WIDTH-1:0] act_max;

    // MMA/WBU write-back path
    wire                 mma_sa_ready;
    wire                 mma_wb_valid;
    wire                 mma_wb_ready;
    wire [1:0]           mma_err_code;
    wire [REG_WIDTH-1:0] mma_wb_data;

    wire                 csr_wb_valid;
    wire                 csr_wb_ready;
    wire [REG_WIDTH-1:0] csr_wb_data;
    wire [REG_WIDTH-1:0] csr_ia_reuse_num_unused;
    wire [REG_WIDTH-1:0] csr_w_reuse_num_unused;
    wire                 csr_dataflow_mode_unused;

    wire                 nice_rsp_valid;
    wire [REG_WIDTH-1:0] nice_rsp_rdat;
    wire                 nice_rsp_err;
    wire                 nice_rsp_ready;

    // Local control/status registers
    reg cfg_16bits_ia_reg;
    reg cfg_dataflow_mode_reg;
    reg use_per_channel_reg;
    reg [REG_WIDTH-1:0] cfg_ia_reuse_num_reg;
    reg [REG_WIDTH-1:0] cfg_w_reuse_num_reg;
    reg calc_start_pulse;
    reg mma_busy_reg;
    reg done_sticky;
    reg [REG_WIDTH-1:0] last_wb_data;
    reg last_wb_valid;
    reg [31:0] irq_req_reg;
    reg [31:0] status_irq_bits_d;

    wire [31:0] status_bits;
    wire [31:0] status_irq_bits;
    wire [31:0] status_irq_set;

    wire [11:0] wr_word_addr = reg_wr_addr[13:2];
    wire [11:0] rd_word_addr = reg_rd_addr[13:2];

    wire wr_is_ctrl = reg_wr_en && (wr_word_addr == REG_CTRL);
	    wire wr_is_ia_reuse = reg_wr_en && (wr_word_addr == REG_IA_REUSE);
	    wire wr_is_w_reuse  = reg_wr_en && (wr_word_addr == REG_W_REUSE);
	    wire wr_is_csr  = reg_wr_en && (wr_word_addr >= CSR_ADDR_MIN) && (wr_word_addr <= CSR_ADDR_MAX);
	    wire rd_is_csr  = reg_rd_en && (rd_word_addr >= CSR_ADDR_MIN) && (rd_word_addr <= CSR_ADDR_MAX);
	    wire ctrl_start_write = wr_is_ctrl && reg_wr_strb[0] && reg_wr_data[0];

    wire csr_conflict = wr_is_csr && rd_is_csr;

    assign reg_wr_wait = 1'b0;
    assign reg_wr_ack  = reg_wr_en;
    assign reg_rd_wait = csr_conflict;
    assign reg_rd_ack  = reg_rd_en && !csr_conflict;

    assign nice_rsp_ready = 1'b1;
    assign mma_wb_data = {{(REG_WIDTH-2){1'b0}}, mma_err_code};
    assign mma_busy = mma_busy_reg;
    assign irq = irq_req_reg;
    assign status_bits = {24'b0, csr_ready, nice_rsp_err, mma_err_code,
                          last_wb_valid, done_sticky, mma_busy_reg, mma_sa_ready};
    assign status_irq_bits = status_bits & IRQ_STATUS_MASK;
    assign status_irq_set = status_irq_bits & ~status_irq_bits_d;

    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arlock  = 2'b00;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awlock  = 2'b00;

    // AXI-Lite frontend from verilog-axi
    axil_reg_if #(
        .DATA_WIDTH(AXIL_DATA_WIDTH),
        .ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .STRB_WIDTH(AXIL_DATA_WIDTH/8),
        .TIMEOUT(16)
    ) u_axil_reg_if (
        .clk(clk),
        .rst(!rst_n),
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
        .reg_wr_addr(reg_wr_addr),
        .reg_wr_data(reg_wr_data),
        .reg_wr_strb(reg_wr_strb),
        .reg_wr_en(reg_wr_en),
        .reg_wr_wait(reg_wr_wait),
        .reg_wr_ack(reg_wr_ack),
        .reg_rd_addr(reg_rd_addr),
        .reg_rd_en(reg_rd_en),
        .reg_rd_data(reg_rd_data),
        .reg_rd_wait(reg_rd_wait),
        .reg_rd_ack(reg_rd_ack)
    );

    // Translate AXI register accesses to csr_unit requests
    always @(*) begin
        csr_req     = 1'b0;
        is_csr_read = 1'b0;
        csr_addr    = 12'b0;
        csr_wdata   = {REG_WIDTH{1'b0}};

        if (wr_is_csr) begin
            csr_req     = 1'b1;
            is_csr_read = 1'b0;
            csr_addr    = wr_word_addr;
            csr_wdata   = reg_wr_data[REG_WIDTH-1:0];
        end else if (rd_is_csr && !csr_conflict) begin
            csr_req     = 1'b1;
            is_csr_read = 1'b1;
            csr_addr    = rd_word_addr;
        end
    end

    // Readback mux for AXI-Lite reads
    reg [AXIL_DATA_WIDTH-1:0] reg_rd_data_r;
    always @(*) begin
        reg_rd_data_r = {AXIL_DATA_WIDTH{1'b0}};

        case (rd_word_addr)
            REG_CTRL: begin
                reg_rd_data_r[3:1] = {cfg_dataflow_mode_reg, use_per_channel_reg, cfg_16bits_ia_reg};
            end
            REG_STATUS: begin
                reg_rd_data_r[7:0] = status_bits[7:0];
            end
            REG_WB_DATA: begin
                reg_rd_data_r = last_wb_data;
            end
            REG_WB_INFO: begin
                reg_rd_data_r[0] = last_wb_valid;
            end
            REG_IA_REUSE: begin
                reg_rd_data_r = cfg_ia_reuse_num_reg;
            end
            REG_W_REUSE: begin
                reg_rd_data_r = cfg_w_reuse_num_reg;
            end
            default: begin
                if ((rd_word_addr >= CSR_ADDR_MIN) && (rd_word_addr <= CSR_ADDR_MAX)) begin
                    reg_rd_data_r = csr_rdata;
                end
            end
        endcase
    end
    assign reg_rd_data = reg_rd_data_r;

    // Control and status registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_16bits_ia_reg   <= 1'b0;
            cfg_dataflow_mode_reg <= 1'b0;
            use_per_channel_reg <= 1'b0;
            cfg_ia_reuse_num_reg <= {REG_WIDTH{1'b0}};
            cfg_w_reuse_num_reg  <= {REG_WIDTH{1'b0}};
            calc_start_pulse    <= 1'b0;
            mma_busy_reg        <= 1'b0;
            done_sticky         <= 1'b0;
            last_wb_data        <= {REG_WIDTH{1'b0}};
            last_wb_valid       <= 1'b0;
            irq_req_reg         <= 32'b0;
            status_irq_bits_d   <= 32'b0;
        end else begin
            calc_start_pulse <= 1'b0;
            irq_req_reg <= (irq_req_reg | status_irq_set) & ~eoi;
            status_irq_bits_d <= status_irq_bits;

	            if (wr_is_ctrl) begin
	                if (reg_wr_strb[0]) begin
	                    cfg_16bits_ia_reg   <= reg_wr_data[1];
	                    use_per_channel_reg <= reg_wr_data[2];
	                    cfg_dataflow_mode_reg <= reg_wr_data[3];
	                    if (reg_wr_data[0]) begin
	                        calc_start_pulse <= 1'b1;
	                        mma_busy_reg <= 1'b1;
	                        done_sticky <= 1'b0;
	                        last_wb_valid <= 1'b0;
	                    end
	                    if (reg_wr_data[8] && !reg_wr_data[0]) begin
	                        done_sticky <= 1'b0;
	                    end
	                    if (reg_wr_data[9] && !reg_wr_data[0]) begin
	                        last_wb_valid <= 1'b0;
	                    end
	                end
	            end

            if (wr_is_ia_reuse) begin
                cfg_ia_reuse_num_reg <= reg_wr_data[REG_WIDTH-1:0];
            end

            if (wr_is_w_reuse) begin
                cfg_w_reuse_num_reg <= reg_wr_data[REG_WIDTH-1:0];
            end

            if (calc_start_pulse) begin
                mma_busy_reg <= 1'b1;
            end

	            if (mma_wb_valid && mma_wb_ready && !ctrl_start_write) begin
	                mma_busy_reg <= 1'b0;
	                done_sticky  <= 1'b1;
	            end

            if (nice_rsp_valid && nice_rsp_ready && !ctrl_start_write) begin
                last_wb_data  <= nice_rsp_rdat;
                last_wb_valid <= 1'b1;
            end
        end
    end

    csr_unit #(
        .REG_WIDTH(REG_WIDTH)
    ) u_csr_unit (
        .clk(clk),
        .rst_n(rst_n),
        .csr_req(csr_req),
        .is_csr_read(is_csr_read),
        .csr_addr(csr_addr),
        .csr_wdata(csr_wdata),
        .csr_ready(csr_ready),
        .csr_rdata(csr_rdata),
        .csr_wb_valid(csr_wb_valid),
        .csr_wb_ready(csr_wb_ready),
        .csr_wb_data(csr_wb_data),
        .lhs_base(lhs_base),
        .rhs_base(rhs_base),
        .dst_base(dst_base_csr),
        .bias_base(bias_base),
        .lhs_zp(lhs_zp),
        .rhs_zp(rhs_zp),
        .dst_zp(dst_zp),
        .q_mult_pt(q_mult_pt),
        .q_shift_pt(q_shift_pt),
        .m(m),
        .k(k),
        .n(n),
        .lhs_row_stride_b(lhs_row_stride_b),
        .dst_row_stride_b(dst_row_stride_b),
        .rhs_col_stride_b(rhs_col_stride_b),
        .cfg_ia_reuse_num(csr_ia_reuse_num_unused),
        .cfg_w_reuse_num(csr_w_reuse_num_unused),
        .cfg_dataflow_mode(csr_dataflow_mode_unused),
        .act_min(act_min),
        .act_max(act_max)
    );

    mma_top #(
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .BUS_WIDTH(BUS_WIDTH),
        .REG_WIDTH(REG_WIDTH),
        .ADDR_WIDTH(ICB_ADDR_WIDTH),
        .ICB_LEN_W(ICB_LEN_W),
        .IA_CACHE_BLOCKS(IA_CACHE_BLOCKS),
	        .PS_FRAME_COUNT(PS_FRAME_COUNT),
	        .AXI_READ_OUTSTANDING(AXI_READ_OUTSTANDING),
	        .AXI_WRITE_OUTSTANDING(AXI_WRITE_OUTSTANDING)
    ) u_mma_top (
        .clk(clk),
        .rst_n(rst_n),
        .calc_start(calc_start_pulse),
        .cfg_16bits_ia(cfg_16bits_ia_reg),
        .cfg_dataflow_mode(cfg_dataflow_mode_reg),
        .cfg_ia_reuse_num(cfg_ia_reuse_num_reg),
        .cfg_w_reuse_num(cfg_w_reuse_num_reg),
        .sa_ready(mma_sa_ready),
        .wb_valid(mma_wb_valid),
        .wb_ready(mma_wb_ready),
        .err_code(mma_err_code),
        .lhs_base(lhs_base),
        .rhs_base(rhs_base),
        .dst_base(dst_base_csr),
        .bias_base(bias_base),
        .lhs_zp(lhs_zp),
        .rhs_zp(rhs_zp),
        .dst_zp(dst_zp),
        .q_mult_pt(q_mult_pt),
        .q_shift_pt(q_shift_pt),
        .use_per_channel(use_per_channel_reg),
        .k(k),
        .n(n),
        .m(m),
        .lhs_row_stride_b(lhs_row_stride_b),
        .dst_row_stride_b(dst_row_stride_b),
        .rhs_col_stride_b(rhs_col_stride_b),
        .act_min(act_min),
        .act_max(act_max),
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

    wbu #(
        .DW(REG_WIDTH)
    ) u_wbu (
        .clk(clk),
        .rst_n(rst_n),
        .csr_wb_valid(csr_wb_valid),
        .csr_wb_ready(csr_wb_ready),
        .csr_wb_data(csr_wb_data),
        .mma_wb_valid(mma_wb_valid),
        .mma_wb_ready(mma_wb_ready),
        .mma_wb_data(mma_wb_data),
        .nice_rsp_valid(nice_rsp_valid),
        .nice_rsp_ready(nice_rsp_ready),
        .nice_rsp_rdat(nice_rsp_rdat),
        .nice_rsp_err(nice_rsp_err)
    );

endmodule
