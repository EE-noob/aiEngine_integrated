/*
 * axi_block_dma_arbiter -- AXI-native DMA front-end for MMA clients
 * ================================================================
 *
 * Read clients (IA/kernel/bias/quant) share the AXI read engine through a
 * small priority arbiter.  The OA writer owns the AXI write engine directly.
 * This preserves the existing loader-side handshake semantics while allowing
 * AXI read traffic and OA writeback to run concurrently.
 */

module axi_block_dma_arbiter #(
    parameter int unsigned DATA_WIDTH   = 16,
    parameter int unsigned KERNEL_WIDTH = DATA_WIDTH,
    parameter int unsigned SIZE         = 16,
    parameter int unsigned DMA_SIZE     = SIZE,
    parameter int unsigned BUS_WIDTH    = 32,
    parameter int unsigned REG_WIDTH    = 32,
    parameter int unsigned CACHE_BLOCKS = 4,
    parameter int unsigned READ_OUTSTANDING = 4,
    parameter int unsigned WRITE_OUTSTANDING = READ_OUTSTANDING
) (
    input logic clk,
    input logic rst_n,

    input  logic ia_req,
    output logic ia_granted,
    input  logic ia_start,
    input  logic ia_is_write,
    input  logic ia_linear_read_mode,
    input  logic [REG_WIDTH-1:0] ia_base_addr,
    input  logic [REG_WIDTH-1:0] ia_row_stride,
    input  logic [REG_WIDTH-1:0] ia_rows_to_read,
    input  logic [3:0] ia_burst_len_m1,
    input  logic [$clog2(CACHE_BLOCKS)-1:0] ia_slot_id,
    input  logic ia_use_16bits,
    input  logic signed [REG_WIDTH-1:0] ia_lhs_zp,
    output logic ia_busy,
    output logic ia_done,
    output logic [$clog2(CACHE_BLOCKS)-1:0] ia_wr_slot,
    output logic [$clog2(SIZE)-1:0] ia_wr_row,
    output logic [$clog2(SIZE)-1:0] ia_wr_col_base,
    output logic signed [DATA_WIDTH-1:0] ia_wr_data [BUS_WIDTH/8],
    output logic ia_wr_valid [BUS_WIDTH/8],
    output logic ia_wr_use_16bits,

    input  logic kernel_req,
    output logic kernel_granted,
    input  logic kernel_start,
    input  logic kernel_is_write,
    input  logic kernel_linear_read_mode,
    input  logic [REG_WIDTH-1:0] kernel_base_addr,
    input  logic [REG_WIDTH-1:0] kernel_row_stride,
    input  logic [REG_WIDTH-1:0] kernel_rows_to_read,
    input  logic [3:0] kernel_burst_len_m1,
    input  logic kernel_slot_id,
    input  logic kernel_use_16bits,
    input  logic signed [REG_WIDTH-1:0] kernel_lhs_zp,
    output logic kernel_busy,
    output logic kernel_done,
    output logic [$clog2(SIZE)-1:0] kernel_wr_row,
    output logic [$clog2(SIZE)-1:0] kernel_wr_col_base,
    output logic signed [KERNEL_WIDTH-1:0] kernel_wr_data [BUS_WIDTH/8],
    output logic kernel_wr_valid [BUS_WIDTH/8],

    input  logic bias_req,
    output logic bias_granted,
    input  logic bias_start,
    input  logic bias_is_write,
    input  logic bias_linear_read_mode,
    input  logic [REG_WIDTH-1:0] bias_base_addr,
    input  logic [REG_WIDTH-1:0] bias_row_stride,
    input  logic [REG_WIDTH-1:0] bias_rows_to_read,
    input  logic [3:0] bias_burst_len_m1,
    input  logic bias_slot_id,
    input  logic bias_use_16bits,
    input  logic signed [REG_WIDTH-1:0] bias_lhs_zp,
    output logic bias_busy,
    output logic bias_done,
    output logic bias_wr_slot,
    output logic [$clog2(DMA_SIZE)-1:0] bias_wr_row,
    output logic [$clog2(DMA_SIZE)-1:0] bias_wr_col_base,
    output logic signed [7:0] bias_wr_data [BUS_WIDTH/8],
    output logic bias_wr_valid [BUS_WIDTH/8],
    output logic bias_wr_use_16bits,

    input  logic quant_req,
    output logic quant_granted,
    input  logic quant_start,
    input  logic quant_is_write,
    input  logic quant_linear_read_mode,
    input  logic [REG_WIDTH-1:0] quant_base_addr,
    input  logic [REG_WIDTH-1:0] quant_row_stride,
    input  logic [REG_WIDTH-1:0] quant_rows_to_read,
    input  logic [3:0] quant_burst_len_m1,
    input  logic quant_slot_id,
    input  logic quant_use_16bits,
    input  logic signed [REG_WIDTH-1:0] quant_lhs_zp,
    output logic quant_busy,
    output logic quant_done,
    output logic [BUS_WIDTH-1:0] quant_raw_data,
    output logic quant_raw_valid,

    input  logic oa_req,
    output logic oa_granted,
    input  logic oa_start,
    input  logic oa_is_write,
    input  logic oa_linear_read_mode,
    input  logic [REG_WIDTH-1:0] oa_base_addr,
    input  logic [REG_WIDTH-1:0] oa_row_stride,
    input  logic [REG_WIDTH-1:0] oa_rows_to_read,
    input  logic [3:0] oa_burst_len_m1,
    input  logic oa_slot_id,
    input  logic oa_use_16bits,
    input  logic signed [REG_WIDTH-1:0] oa_lhs_zp,
    input  logic [BUS_WIDTH-1:0] oa_src_wdata,
    input  logic [BUS_WIDTH/8-1:0] oa_src_wmask,
    input  logic oa_src_wvalid,
    output logic oa_src_wready,
    output logic oa_busy,
    output logic oa_done,

    output logic                   m_axi_arvalid,
    input  logic                   m_axi_arready,
    output logic [  REG_WIDTH-1:0] m_axi_araddr,
    output logic [            7:0] m_axi_arlen,
    output logic [            2:0] m_axi_arsize,
    output logic [            1:0] m_axi_arburst,
    input  logic                   m_axi_rvalid,
    output logic                   m_axi_rready,
    input  logic [  BUS_WIDTH-1:0] m_axi_rdata,
    input  logic [            1:0] m_axi_rresp,
    input  logic                   m_axi_rlast,

    output logic                   m_axi_awvalid,
    input  logic                   m_axi_awready,
    output logic [  REG_WIDTH-1:0] m_axi_awaddr,
    output logic [            7:0] m_axi_awlen,
    output logic [            2:0] m_axi_awsize,
    output logic [            1:0] m_axi_awburst,
    output logic                   m_axi_wvalid,
    input  logic                   m_axi_wready,
    output logic [  BUS_WIDTH-1:0] m_axi_wdata,
    output logic [BUS_WIDTH/8-1:0] m_axi_wstrb,
    output logic                   m_axi_wlast,
    input  logic                   m_axi_bvalid,
    output logic                   m_axi_bready,
    input  logic [            1:0] m_axi_bresp
);

    localparam int BYTE_PER_BEAT = BUS_WIDTH / 8;

    typedef enum logic [2:0] {
        C_IA     = 3'd0,
        C_KERNEL = 3'd1,
        C_BIAS   = 3'd2,
        C_QUANT  = 3'd3,
        C_NONE   = 3'd7
    } client_e;

    client_e rd_client, rd_next_client;
    logic rd_active;
    logic rd_started;
    logic rd_dma_start;
    logic rd_dma_busy;
    logic rd_dma_done;
    logic rd_error;

    logic rd_dma_linear_read_mode;
    logic [REG_WIDTH-1:0] rd_dma_base_addr;
    logic [REG_WIDTH-1:0] rd_dma_row_stride;
    logic [REG_WIDTH-1:0] rd_dma_rows_to_read;
    logic [3:0] rd_dma_burst_len_m1;
    logic [$clog2(CACHE_BLOCKS)-1:0] rd_dma_slot_id;
    logic rd_dma_use_16bits;
    logic signed [REG_WIDTH-1:0] rd_dma_lhs_zp;

    logic [$clog2(CACHE_BLOCKS)-1:0] dma_wr_slot;
    logic [$clog2(DMA_SIZE)-1:0] dma_wr_row;
    logic [$clog2(DMA_SIZE)-1:0] dma_wr_col_base;
    logic signed [DATA_WIDTH-1:0] dma_wr_data [BYTE_PER_BEAT];
    logic dma_wr_valid [BYTE_PER_BEAT];
    logic dma_wr_use_16bits;
    logic [BUS_WIDTH-1:0] dma_raw_data;
    logic dma_raw_valid;
    logic [$clog2(DMA_SIZE)-1:0] dma_raw_row;
    logic [$clog2(DMA_SIZE)-1:0] dma_raw_col_base;

    logic wr_active;
    logic wr_started;
    logic wr_dma_start;
    logic wr_dma_busy;
    logic wr_dma_done;
    logic wr_error;
    logic wr_src_wready;

    wire unused_ia_is_write = ia_is_write;
    wire unused_kernel_is_write = kernel_is_write;
    wire unused_bias_is_write = bias_is_write;
    wire unused_quant_is_write = quant_is_write;
    wire unused_oa_is_write = oa_is_write;
    wire unused_oa_linear_read_mode = oa_linear_read_mode;
    wire unused_oa_slot_id = oa_slot_id;
    wire unused_oa_use_16bits = oa_use_16bits;
    wire signed [REG_WIDTH-1:0] unused_oa_lhs_zp = oa_lhs_zp;
    wire unused_rd_error = rd_error;
    wire unused_wr_error = wr_error;
    wire [BUS_WIDTH-1:0] unused_dma_raw = dma_raw_data;
    wire [$clog2(DMA_SIZE)-1:0] unused_dma_raw_row = dma_raw_row;
    wire [$clog2(DMA_SIZE)-1:0] unused_dma_raw_col_base = dma_raw_col_base;

    always_comb begin
        if (kernel_req) rd_next_client = C_KERNEL;
        else if (quant_req) rd_next_client = C_QUANT;
        else if (ia_req) rd_next_client = C_IA;
        else if (bias_req) rd_next_client = C_BIAS;
        else rd_next_client = C_NONE;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_client  <= C_NONE;
            rd_active  <= 1'b0;
            rd_started <= 1'b0;
        end else begin
            if (!rd_active) begin
                if (rd_next_client != C_NONE) begin
                    rd_client  <= rd_next_client;
                    rd_active  <= 1'b1;
                    rd_started <= 1'b0;
                end
            end else if (!rd_started) begin
                if (rd_dma_start) begin
                    rd_started <= 1'b1;
                end else if ((rd_client == C_IA     && !ia_req) ||
                             (rd_client == C_KERNEL && !kernel_req) ||
                             (rd_client == C_BIAS   && !bias_req) ||
                             (rd_client == C_QUANT  && !quant_req)) begin
                    rd_client  <= C_NONE;
                    rd_active  <= 1'b0;
                    rd_started <= 1'b0;
                end
            end else if (rd_dma_done) begin
                rd_client  <= C_NONE;
                rd_active  <= 1'b0;
                rd_started <= 1'b0;
            end
        end
    end

    assign ia_granted     = rd_active && (rd_client == C_IA);
    assign kernel_granted = rd_active && (rd_client == C_KERNEL);
    assign bias_granted   = rd_active && (rd_client == C_BIAS);
    assign quant_granted  = rd_active && (rd_client == C_QUANT);

    assign ia_busy     = ia_granted && rd_dma_busy;
    assign kernel_busy = kernel_granted && rd_dma_busy;
    assign bias_busy   = bias_granted && rd_dma_busy;
    assign quant_busy  = quant_granted && rd_dma_busy;

    assign ia_done     = ia_granted && rd_dma_done;
    assign kernel_done = kernel_granted && rd_dma_done;
    assign bias_done   = bias_granted && rd_dma_done;
    assign quant_done  = quant_granted && rd_dma_done;

    always_comb begin
        rd_dma_start            = 1'b0;
        rd_dma_linear_read_mode = 1'b0;
        rd_dma_base_addr        = '0;
        rd_dma_row_stride       = '0;
        rd_dma_rows_to_read     = '0;
        rd_dma_burst_len_m1     = '0;
        rd_dma_slot_id          = '0;
        rd_dma_use_16bits       = 1'b0;
        rd_dma_lhs_zp           = '0;

        unique case (rd_client)
            C_IA: begin
                rd_dma_start            = ia_start && ia_granted && !rd_started;
                rd_dma_linear_read_mode = ia_linear_read_mode;
                rd_dma_base_addr        = ia_base_addr;
                rd_dma_row_stride       = ia_row_stride;
                rd_dma_rows_to_read     = ia_rows_to_read;
                rd_dma_burst_len_m1     = ia_burst_len_m1;
                rd_dma_slot_id          = ia_slot_id;
                rd_dma_use_16bits       = ia_use_16bits;
                rd_dma_lhs_zp           = ia_lhs_zp;
            end
            C_KERNEL: begin
                rd_dma_start            = kernel_start && kernel_granted && !rd_started;
                rd_dma_linear_read_mode = kernel_linear_read_mode;
                rd_dma_base_addr        = kernel_base_addr;
                rd_dma_row_stride       = kernel_row_stride;
                rd_dma_rows_to_read     = kernel_rows_to_read;
                rd_dma_burst_len_m1     = kernel_burst_len_m1;
                rd_dma_slot_id          = '0;
                rd_dma_slot_id[0]       = kernel_slot_id;
                rd_dma_use_16bits       = kernel_use_16bits;
                rd_dma_lhs_zp           = kernel_lhs_zp;
            end
            C_BIAS: begin
                rd_dma_start            = bias_start && bias_granted && !rd_started;
                rd_dma_linear_read_mode = bias_linear_read_mode;
                rd_dma_base_addr        = bias_base_addr;
                rd_dma_row_stride       = bias_row_stride;
                rd_dma_rows_to_read     = bias_rows_to_read;
                rd_dma_burst_len_m1     = bias_burst_len_m1;
                rd_dma_slot_id          = '0;
                rd_dma_slot_id[0]       = bias_slot_id;
                rd_dma_use_16bits       = bias_use_16bits;
                rd_dma_lhs_zp           = bias_lhs_zp;
            end
            C_QUANT: begin
                rd_dma_start            = quant_start && quant_granted && !rd_started;
                rd_dma_linear_read_mode = quant_linear_read_mode;
                rd_dma_base_addr        = quant_base_addr;
                rd_dma_row_stride       = quant_row_stride;
                rd_dma_rows_to_read     = quant_rows_to_read;
                rd_dma_burst_len_m1     = quant_burst_len_m1;
                rd_dma_slot_id          = '0;
                rd_dma_slot_id[0]       = quant_slot_id;
                rd_dma_use_16bits       = quant_use_16bits;
                rd_dma_lhs_zp           = quant_lhs_zp;
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_active  <= 1'b0;
            wr_started <= 1'b0;
        end else begin
            if (!wr_active) begin
                if (oa_req) begin
                    wr_active  <= 1'b1;
                    wr_started <= 1'b0;
                end
            end else if (!wr_started) begin
                if (wr_dma_start) begin
                    wr_started <= 1'b1;
                end else if (!oa_req) begin
                    wr_active  <= 1'b0;
                    wr_started <= 1'b0;
                end
            end else if (wr_dma_done) begin
                wr_active  <= 1'b0;
                wr_started <= 1'b0;
            end
        end
    end

    assign oa_granted = wr_active;
    assign wr_dma_start = oa_start && oa_granted && !wr_started;
    assign oa_busy = oa_granted && wr_dma_busy;
    assign oa_done = oa_granted && wr_dma_done;
    assign oa_src_wready = oa_granted && wr_src_wready;

    for (genvar i = 0; i < BYTE_PER_BEAT; i++) begin : gen_route_wr
        assign ia_wr_data[i]      = dma_wr_data[i];
        assign ia_wr_valid[i]     = ia_granted && dma_wr_valid[i];
        assign kernel_wr_data[i]  = KERNEL_WIDTH'($signed(dma_wr_data[i]));
        assign kernel_wr_valid[i] = kernel_granted && dma_wr_valid[i];
        assign bias_wr_data[i]    = dma_wr_data[i][7:0];
        assign bias_wr_valid[i]   = bias_granted && dma_wr_valid[i];
    end

    assign ia_wr_slot       = dma_wr_slot;
    assign ia_wr_row        = dma_wr_row[$clog2(SIZE)-1:0];
    assign ia_wr_col_base   = dma_wr_col_base[$clog2(SIZE)-1:0];
    assign ia_wr_use_16bits = dma_wr_use_16bits;

    assign kernel_wr_row      = dma_wr_row[$clog2(SIZE)-1:0];
    assign kernel_wr_col_base = dma_wr_col_base[$clog2(SIZE)-1:0];

    assign bias_wr_slot       = dma_wr_slot[0];
    assign bias_wr_row        = dma_wr_row;
    assign bias_wr_col_base   = dma_wr_col_base;
    assign bias_wr_use_16bits = dma_wr_use_16bits;

    assign quant_raw_data  = dma_raw_data;
    assign quant_raw_valid = quant_granted && dma_raw_valid;

    axi_dual_block_dma #(
        .DATA_WIDTH  (DATA_WIDTH),
        .SIZE        (DMA_SIZE),
        .BUS_WIDTH   (BUS_WIDTH),
        .REG_WIDTH   (REG_WIDTH),
        .CACHE_BLOCKS(CACHE_BLOCKS),
	        .READ_OUTSTANDING(READ_OUTSTANDING),
	        .WRITE_OUTSTANDING(WRITE_OUTSTANDING)
    ) u_dma (
        .clk                (clk),
        .rst_n              (rst_n),
        .rd_start           (rd_dma_start),
        .rd_linear_read_mode(rd_dma_linear_read_mode),
        .rd_base_addr       (rd_dma_base_addr),
        .rd_row_stride      (rd_dma_row_stride),
        .rd_rows_to_read    (rd_dma_rows_to_read),
        .rd_valid_cols      (REG_WIDTH'(DMA_SIZE)),
        .rd_burst_len_m1    (rd_dma_burst_len_m1),
        .rd_slot_id         (rd_dma_slot_id),
        .rd_use_16bits      (rd_dma_use_16bits),
        .rd_lhs_zp          (rd_dma_lhs_zp),
        .rd_busy            (rd_dma_busy),
        .rd_done            (rd_dma_done),
        .wr_start           (wr_dma_start),
        .wr_base_addr       (oa_base_addr),
        .wr_row_stride      (oa_row_stride),
        .wr_rows_to_write   (oa_rows_to_read),
        .wr_burst_len_m1    (oa_burst_len_m1),
        .wr_busy            (wr_dma_busy),
        .wr_done            (wr_dma_done),
        .src_wdata          (oa_src_wdata),
        .src_wmask          (oa_src_wmask),
        .src_wvalid         (oa_src_wvalid),
        .src_wready         (wr_src_wready),
        .m_axi_arvalid      (m_axi_arvalid),
        .m_axi_arready      (m_axi_arready),
        .m_axi_araddr       (m_axi_araddr),
        .m_axi_arlen        (m_axi_arlen),
        .m_axi_arsize       (m_axi_arsize),
        .m_axi_arburst      (m_axi_arburst),
        .m_axi_rvalid       (m_axi_rvalid),
        .m_axi_rready       (m_axi_rready),
        .m_axi_rdata        (m_axi_rdata),
        .m_axi_rresp        (m_axi_rresp),
        .m_axi_rlast        (m_axi_rlast),
        .m_axi_awvalid      (m_axi_awvalid),
        .m_axi_awready      (m_axi_awready),
        .m_axi_awaddr       (m_axi_awaddr),
        .m_axi_awlen        (m_axi_awlen),
        .m_axi_awsize       (m_axi_awsize),
        .m_axi_awburst      (m_axi_awburst),
        .m_axi_wvalid       (m_axi_wvalid),
        .m_axi_wready       (m_axi_wready),
        .m_axi_wdata        (m_axi_wdata),
        .m_axi_wstrb        (m_axi_wstrb),
        .m_axi_wlast        (m_axi_wlast),
        .m_axi_bvalid       (m_axi_bvalid),
        .m_axi_bready       (m_axi_bready),
        .m_axi_bresp        (m_axi_bresp),
        .wr_slot            (dma_wr_slot),
        .wr_row             (dma_wr_row),
        .wr_col_base        (dma_wr_col_base),
        .wr_data            (dma_wr_data),
        .wr_valid           (dma_wr_valid),
        .wr_use_16bits      (dma_wr_use_16bits),
        .rd_raw_data        (dma_raw_data),
        .rd_raw_valid       (dma_raw_valid),
        .rd_raw_row         (dma_raw_row),
        .rd_raw_col_base    (dma_raw_col_base),
        .rd_error           (rd_error),
        .wr_error           (wr_error)
    );

endmodule
