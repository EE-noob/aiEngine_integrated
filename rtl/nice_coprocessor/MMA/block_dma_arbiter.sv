module block_dma_arbiter #(
    parameter int unsigned DATA_WIDTH   = 16,
    parameter int unsigned KERNEL_WIDTH = DATA_WIDTH,
    parameter int unsigned SIZE         = 16,
    parameter int unsigned DMA_SIZE     = SIZE,
    parameter int unsigned BUS_WIDTH    = 32,
    parameter int unsigned REG_WIDTH    = 32,
    parameter int unsigned CACHE_BLOCKS = 4
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

    output logic icb_cmd_valid,
    input  logic icb_cmd_ready,
    output logic icb_cmd_read,
    output logic [REG_WIDTH-1:0] icb_cmd_addr,
    output logic [3:0] icb_cmd_len,
    output logic [BUS_WIDTH-1:0] icb_cmd_wdata,
    output logic [BUS_WIDTH/8-1:0] icb_cmd_wmask,
    output logic icb_w_valid,
    input  logic icb_w_ready,
    input  logic icb_rsp_valid,
    output logic icb_rsp_ready,
    input  logic [BUS_WIDTH-1:0] icb_rsp_rdata,
    input  logic icb_rsp_err
);

    localparam int BYTE_PER_BEAT = BUS_WIDTH / 8;
    typedef enum logic [2:0] {
        C_IA     = 3'd0,
        C_KERNEL = 3'd1,
        C_BIAS   = 3'd2,
        C_QUANT  = 3'd3,
        C_OA     = 3'd4,
        C_NONE   = 3'd7
    } client_e;

    client_e active_client, next_client;
    logic active;
    logic dma_started;
    logic dma_start;
    logic dma_is_write;
    logic dma_linear_read_mode;
    logic [REG_WIDTH-1:0] dma_base_addr;
    logic [REG_WIDTH-1:0] dma_row_stride;
    logic [REG_WIDTH-1:0] dma_rows_to_read;
    logic [3:0] dma_burst_len_m1;
    logic [$clog2(CACHE_BLOCKS)-1:0] dma_slot_id;
    logic dma_use_16bits;
    logic signed [REG_WIDTH-1:0] dma_lhs_zp;
    logic dma_busy;
    logic dma_done;
    logic [BUS_WIDTH-1:0] dma_src_wdata;
    logic [BUS_WIDTH/8-1:0] dma_src_wmask;
    logic dma_src_wvalid;
    logic dma_src_wready;
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
    bit dma_trace_en;
    integer dma_trace_rsp_count;

    initial begin
        dma_trace_en = 1'b0;
        if ($test$plusargs("MMA_DMA_TRACE")) dma_trace_en = 1'b1;
    end

    always_comb begin
        if (oa_req) next_client = C_OA;
        else if (kernel_req) next_client = C_KERNEL;
        else if (ia_req) next_client = C_IA;
        else if (quant_req) next_client = C_QUANT;
        else if (bias_req) next_client = C_BIAS;
        else next_client = C_NONE;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_client <= C_NONE;
            active <= 1'b0;
            dma_started <= 1'b0;
        end else begin
            if (!active) begin
                if (next_client != C_NONE) begin
                    active_client <= next_client;
                    active <= 1'b1;
                    dma_started <= 1'b0;
                end
            end else begin
                if (!dma_started) begin
                    if (dma_start) begin
                        dma_started <= 1'b1;
                    end else if ((active_client == C_IA     && !ia_req) ||
                        (active_client == C_KERNEL && !kernel_req) ||
                        (active_client == C_BIAS   && !bias_req) ||
                        (active_client == C_QUANT  && !quant_req) ||
                        (active_client == C_OA     && !oa_req)) begin
                        active <= 1'b0;
                        active_client <= C_NONE;
                    end
                end else if (dma_done) begin
                    active <= 1'b0;
                    active_client <= C_NONE;
                    dma_started <= 1'b0;
                end
            end
        end
    end

    assign ia_granted     = active && active_client == C_IA;
    assign kernel_granted = active && active_client == C_KERNEL;
    assign bias_granted   = active && active_client == C_BIAS;
    assign quant_granted  = active && active_client == C_QUANT;
    assign oa_granted     = active && active_client == C_OA;

    assign ia_busy     = ia_granted && dma_busy;
    assign kernel_busy = kernel_granted && dma_busy;
    assign bias_busy   = bias_granted && dma_busy;
    assign quant_busy  = quant_granted && dma_busy;
    assign oa_busy     = oa_granted && dma_busy;

    assign ia_done     = ia_granted && dma_done;
    assign kernel_done = kernel_granted && dma_done;
    assign bias_done   = bias_granted && dma_done;
    assign quant_done  = quant_granted && dma_done;
    assign oa_done     = oa_granted && dma_done;

    always_comb begin
        dma_start            = 1'b0;
        dma_is_write         = 1'b0;
        dma_linear_read_mode = 1'b0;
        dma_base_addr        = '0;
        dma_row_stride       = '0;
        dma_rows_to_read     = '0;
        dma_burst_len_m1     = '0;
        dma_slot_id          = '0;
        dma_use_16bits       = 1'b0;
        dma_lhs_zp           = '0;
        dma_src_wdata        = '0;
        dma_src_wmask        = '0;
        dma_src_wvalid       = 1'b0;
        unique case (active_client)
            C_IA: begin
                dma_start            = ia_start && ia_granted && !dma_started;
                dma_is_write         = ia_is_write;
                dma_linear_read_mode = ia_linear_read_mode;
                dma_base_addr        = ia_base_addr;
                dma_row_stride       = ia_row_stride;
                dma_rows_to_read     = ia_rows_to_read;
                dma_burst_len_m1     = ia_burst_len_m1;
                dma_slot_id          = ia_slot_id;
                dma_use_16bits       = ia_use_16bits;
                dma_lhs_zp           = ia_lhs_zp;
            end
            C_KERNEL: begin
                dma_start            = kernel_start && kernel_granted && !dma_started;
                dma_is_write         = kernel_is_write;
                dma_linear_read_mode = kernel_linear_read_mode;
                dma_base_addr        = kernel_base_addr;
                dma_row_stride       = kernel_row_stride;
                dma_rows_to_read     = kernel_rows_to_read;
                dma_burst_len_m1     = kernel_burst_len_m1;
                dma_slot_id          = '0;
                dma_slot_id[0]       = kernel_slot_id;
                dma_use_16bits       = kernel_use_16bits;
                dma_lhs_zp           = kernel_lhs_zp;
            end
            C_BIAS: begin
                dma_start            = bias_start && bias_granted && !dma_started;
                dma_is_write         = bias_is_write;
                dma_linear_read_mode = bias_linear_read_mode;
                dma_base_addr        = bias_base_addr;
                dma_row_stride       = bias_row_stride;
                dma_rows_to_read     = bias_rows_to_read;
                dma_burst_len_m1     = bias_burst_len_m1;
                dma_slot_id          = '0;
                dma_slot_id[0]       = bias_slot_id;
                dma_use_16bits       = bias_use_16bits;
                dma_lhs_zp           = bias_lhs_zp;
            end
            C_QUANT: begin
                dma_start            = quant_start && quant_granted && !dma_started;
                dma_is_write         = quant_is_write;
                dma_linear_read_mode = quant_linear_read_mode;
                dma_base_addr        = quant_base_addr;
                dma_row_stride       = quant_row_stride;
                dma_rows_to_read     = quant_rows_to_read;
                dma_burst_len_m1     = quant_burst_len_m1;
                dma_slot_id          = '0;
                dma_slot_id[0]       = quant_slot_id;
                dma_use_16bits       = quant_use_16bits;
                dma_lhs_zp           = quant_lhs_zp;
            end
            C_OA: begin
                dma_start            = oa_start && oa_granted && !dma_started;
                dma_is_write         = oa_is_write;
                dma_linear_read_mode = oa_linear_read_mode;
                dma_base_addr        = oa_base_addr;
                dma_row_stride       = oa_row_stride;
                dma_rows_to_read     = oa_rows_to_read;
                dma_burst_len_m1     = oa_burst_len_m1;
                dma_slot_id          = '0;
                dma_slot_id[0]       = oa_slot_id;
                dma_use_16bits       = oa_use_16bits;
                dma_lhs_zp           = oa_lhs_zp;
                dma_src_wdata        = oa_src_wdata;
                dma_src_wmask        = oa_src_wmask;
                dma_src_wvalid       = oa_src_wvalid;
            end
            default: ;
        endcase
    end

	    assign oa_src_wready = oa_granted && dma_src_wready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_trace_rsp_count <= 0;
        end else if (dma_start) begin
            dma_trace_rsp_count <= 0;
            if (dma_trace_en) begin
                $display("[DMA_TRACE] time=%0t start client=%0d write=%0b base=%h stride=%0d rows=%0d len=%0d slot=%0d",
                         $time, active_client, dma_is_write, dma_base_addr,
                         dma_row_stride, dma_rows_to_read, dma_burst_len_m1,
                         dma_slot_id);
            end
        end else if (dma_trace_en && dma_raw_valid) begin
            if (dma_trace_rsp_count < 8) begin
                $write("[DMA_TRACE] time=%0t rsp client=%0d row=%0d col=%0d raw=%h use16=%0b lanes:",
                       $time, active_client, dma_raw_row, dma_raw_col_base, dma_raw_data,
                       dma_wr_use_16bits);
                for (int i = 0; i < BYTE_PER_BEAT; i++) begin
                    if (dma_wr_valid[i]) begin
                        $write(" [%0d]=%0d(0x%0h)", i, dma_wr_data[i], dma_wr_data[i]);
                    end
                end
                $write("\n");
            end
            dma_trace_rsp_count <= dma_trace_rsp_count + 1;
        end
    end

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

    block_dma #(
        .DATA_WIDTH  (DATA_WIDTH),
        .SIZE        (DMA_SIZE),
        .BUS_WIDTH   (BUS_WIDTH),
        .REG_WIDTH   (REG_WIDTH),
        .CACHE_BLOCKS(CACHE_BLOCKS)
    ) u_dma (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (dma_start),
        .is_write        (dma_is_write),
        .linear_read_mode(dma_linear_read_mode),
        .tile_base_addr  (dma_base_addr),
        .row_stride      (dma_row_stride),
        .rows_to_read    (dma_rows_to_read),
        .burst_len_m1    (dma_burst_len_m1),
        .slot_id         (dma_slot_id),
        .use_16bits      (dma_use_16bits),
        .lhs_zp          (dma_lhs_zp),
        .busy            (dma_busy),
        .tile_done       (dma_done),
        .src_wdata       (dma_src_wdata),
        .src_wmask       (dma_src_wmask),
        .src_wvalid      (dma_src_wvalid),
        .src_wready      (dma_src_wready),
        .icb_cmd_valid   (icb_cmd_valid),
        .icb_cmd_ready   (icb_cmd_ready),
        .icb_cmd_read    (icb_cmd_read),
        .icb_cmd_addr    (icb_cmd_addr),
        .icb_cmd_len     (icb_cmd_len),
        .icb_cmd_wdata   (icb_cmd_wdata),
        .icb_cmd_wmask   (icb_cmd_wmask),
        .icb_w_valid     (icb_w_valid),
        .icb_w_ready     (icb_w_ready),
        .icb_rsp_valid   (icb_rsp_valid),
        .icb_rsp_ready   (icb_rsp_ready),
        .icb_rsp_rdata   (icb_rsp_rdata),
        .icb_rsp_err     (icb_rsp_err),
        .wr_slot         (dma_wr_slot),
        .wr_row          (dma_wr_row),
        .wr_col_base     (dma_wr_col_base),
        .wr_data         (dma_wr_data),
        .wr_valid        (dma_wr_valid),
        .wr_use_16bits   (dma_wr_use_16bits),
        .rd_raw_data     (dma_raw_data),
        .rd_raw_valid    (dma_raw_valid),
        .rd_raw_row      (dma_raw_row),
        .rd_raw_col_base (dma_raw_col_base)
    );

endmodule
