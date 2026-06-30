`include "icb_types.svh"

module icb_read_dma_adapter #(
    parameter int unsigned BUS_WIDTH = 32,
    parameter int unsigned REG_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,

    input  icb_ext_cmd_m_t icb_cmd_m,
    output icb_ext_cmd_s_t icb_cmd_s,
    output icb_ext_rsp_s_t icb_rsp_s,
    input  icb_ext_rsp_m_t icb_rsp_m,

    input  logic dma_granted,
    output logic dma_req,
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
    input  logic [BUS_WIDTH-1:0] dma_raw_data,
    input  logic dma_raw_valid,
    input  logic dma_done
);

    typedef enum logic [1:0] {S_IDLE, S_START, S_ACTIVE} state_t;
    state_t state;
    logic [REG_WIDTH-1:0] addr_r;
    logic [3:0] len_r;

    wire cmd_hs = icb_cmd_m.valid && icb_cmd_s.ready;

    assign icb_cmd_s.ready = (state == S_IDLE) && dma_granted && icb_cmd_m.read;
    assign icb_rsp_s = '{
        rsp_valid: (state == S_ACTIVE) && dma_raw_valid,
        rsp_rdata: dma_raw_data,
        rsp_err: 1'b0
    };

    assign dma_req = (state != S_IDLE) || (icb_cmd_m.valid && icb_cmd_m.read);
    assign dma_start = (state == S_START) && dma_granted;
    assign dma_is_write = 1'b0;
    assign dma_linear_read_mode = 1'b0;
    assign dma_base_addr = addr_r;
    assign dma_row_stride = REG_WIDTH'(BUS_WIDTH / 8);
    assign dma_rows_to_read = REG_WIDTH'(1);
    assign dma_burst_len_m1 = len_r;
    assign dma_slot_id = 1'b0;
    assign dma_use_16bits = 1'b0;
    assign dma_lhs_zp = '0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            addr_r <= '0;
            len_r <= '0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (cmd_hs) begin
                        addr_r <= REG_WIDTH'(icb_cmd_m.addr);
                        len_r <= icb_cmd_m.len[3:0];
                        state <= S_START;
                    end
                end
                S_START: begin
                    if (dma_start) state <= S_ACTIVE;
                end
                S_ACTIVE: begin
                    if (dma_done) state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
