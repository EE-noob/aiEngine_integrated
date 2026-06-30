`include "icb_types.svh"

module icb_write_dma_adapter #(
    parameter int unsigned BUS_WIDTH = 32,
    parameter int unsigned REG_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,

    input  icb_ext_cmd_m_t icb_cmd_m,
    output icb_ext_cmd_s_t icb_cmd_s,
    input  icb_ext_wr_m_t  icb_wr_m,
    output icb_ext_wr_s_t  icb_wr_s,
    output icb_ext_rsp_s_t icb_rsp_s,
    input  icb_ext_rsp_m_t icb_rsp_m,

    input  logic dma_granted,
    output logic dma_start,
    output logic dma_is_write,
    output logic dma_linear_read_mode,
    output logic [REG_WIDTH-1:0] dma_base_addr,
    output logic [REG_WIDTH-1:0] dma_row_stride,
    output logic [REG_WIDTH-1:0] dma_rows_to_read,
    output logic [3:0] dma_burst_len_m1,
    output logic dma_slot_id,
    output logic dma_use_16bits,
    output logic signed [REG_WIDTH-1:0] dma_lhs_zp,
    output logic [BUS_WIDTH-1:0] dma_src_wdata,
    output logic [BUS_WIDTH/8-1:0] dma_src_wmask,
    output logic dma_src_wvalid,
    input  logic dma_src_wready,
    input  logic dma_done
);

    typedef enum logic [2:0] {S_IDLE, S_START, S_STREAM, S_WAIT_DONE, S_RESP} state_t;
    state_t state;
    logic [REG_WIDTH-1:0] addr_r;

    wire cmd_hs = icb_cmd_m.valid && icb_cmd_s.ready;
    wire w_hs = icb_wr_m.w_valid && icb_wr_s.w_ready;
    wire rsp_hs = icb_rsp_s.rsp_valid && icb_rsp_m.rsp_ready;

    assign icb_cmd_s.ready = (state == S_IDLE) && dma_granted && !icb_cmd_m.read;
    assign icb_wr_s.w_ready = (state == S_STREAM) && dma_src_wready;
    assign icb_rsp_s = '{
        rsp_valid: (state == S_RESP),
        rsp_rdata: '0,
        rsp_err: 1'b0
    };

    assign dma_start = (state == S_START) && dma_granted;
    assign dma_is_write = 1'b1;
    assign dma_linear_read_mode = 1'b0;
    assign dma_base_addr = addr_r;
    assign dma_row_stride = REG_WIDTH'(BUS_WIDTH / 8);
    assign dma_rows_to_read = REG_WIDTH'(1);
    assign dma_burst_len_m1 = 4'd0;
    assign dma_slot_id = 1'b0;
    assign dma_use_16bits = 1'b0;
    assign dma_lhs_zp = '0;
    assign dma_src_wdata = icb_wr_m.wdata;
    assign dma_src_wmask = icb_wr_m.wmask;
    assign dma_src_wvalid = (state == S_STREAM) && icb_wr_m.w_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            addr_r <= '0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (cmd_hs) begin
                        addr_r <= REG_WIDTH'(icb_cmd_m.addr);
                        state <= S_START;
                    end
                end
                S_START: begin
                    if (dma_start) state <= S_STREAM;
                end
                S_STREAM: begin
                    if (w_hs) state <= S_WAIT_DONE;
                end
                S_WAIT_DONE: begin
                    if (dma_done) state <= S_RESP;
                end
                S_RESP: begin
                    if (rsp_hs) state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
