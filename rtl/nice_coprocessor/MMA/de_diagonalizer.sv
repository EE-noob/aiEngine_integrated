// 反阶梯化 / de-diagonalization unit.
//
// This module is the inverse of the staircase/diagonal setup stage. It receives
// stair-stepped lane data under input_valid_i and uses a triangular delay
// register group to realign the diagonal stream back into normal row vectors.
//
// For SIZE lanes, a complete stair-stepped burst contains 2*SIZE-1 cycles. The
// module emits SIZE valid vector rows after SIZE-1 cycles of fill latency, and
// pulses tile_calc_over_o for exactly one cycle together with the final valid row.
module de_diagonalizer #(
    parameter int unsigned SIZE       = 16,
    parameter int unsigned DATA_WIDTH = 32
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic signed [DATA_WIDTH-1:0] data_in       [0:SIZE-1],
    input  logic                         input_valid_i,
    input  logic                         burst_start_i,
    input  logic                         burst_last_i,

    output logic signed [DATA_WIDTH-1:0] data_out      [0:SIZE-1],
    output logic                         data_valid_o,
    output logic                         tile_calc_over_o
);
    localparam int unsigned MAX_DELAY  = (SIZE > 0) ? (SIZE - 1) : 0;
    localparam int unsigned LAST_STEP  = (SIZE > 0) ? ((2 * SIZE) - 2) : 0;
    localparam int unsigned STEP_CNT_W = (LAST_STEP < 1) ? 1 : $clog2(LAST_STEP + 2);
    localparam int unsigned ROW_CNT_W  = (SIZE <= 1) ? 1 : $clog2(SIZE);

    localparam logic [STEP_CNT_W-1:0] MAX_DELAY_C = STEP_CNT_W'(MAX_DELAY);
    localparam logic [STEP_CNT_W-1:0] LAST_STEP_C = STEP_CNT_W'(LAST_STEP);
    localparam logic [ROW_CNT_W-1:0]  LAST_ROW_C  = ROW_CNT_W'(SIZE - 1);

    logic [STEP_CNT_W-1:0] step_cnt;
    logic [ROW_CNT_W-1:0]  row_cnt;
    logic                  in_burst;
    logic                  row_valid_next;
    logic                  tile_over_next;

    always_comb begin
        row_valid_next = input_valid_i && (step_cnt >= MAX_DELAY_C);
        tile_over_next = row_valid_next && ((row_cnt == LAST_ROW_C) || burst_last_i);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_cnt         <= '0;
            row_cnt          <= '0;
            in_burst         <= 1'b0;
            data_valid_o     <= 1'b0;
            tile_calc_over_o <= 1'b0;
        end else begin
            data_valid_o     <= row_valid_next;
            tile_calc_over_o <= tile_over_next;

            if (burst_start_i) begin
                row_cnt <= '0;
            end else if (row_valid_next) begin
                row_cnt <= tile_over_next ? '0 : (row_cnt + 1'b1);
            end

            if (input_valid_i) begin
                in_burst <= 1'b1;

                if (burst_start_i || !in_burst) begin
                    step_cnt <= 'd1;
                end else if (step_cnt <= LAST_STEP_C) begin
                    step_cnt <= step_cnt + 1'b1;
                end
            end else begin
                in_burst <= 1'b0;
                step_cnt <= '0;
                row_cnt  <= '0;
            end
        end
    end

    genvar lane;
    generate
        for (lane = 0; lane < SIZE; lane++) begin : gen_de_diagonalizer_delay
            localparam int unsigned DELAY = SIZE - 1 - lane;

            logic signed [DATA_WIDTH-1:0] delay_line [0:DELAY];

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (int stage = 0; stage <= DELAY; stage++) begin
                        delay_line[stage] <= '0;
                    end
                end else if (burst_start_i) begin
                    delay_line[0] <= input_valid_i ? data_in[lane] : '0;
                    for (int stage = 1; stage <= DELAY; stage++) begin
                        delay_line[stage] <= '0;
                    end
                end else begin
                    delay_line[0] <= input_valid_i ? data_in[lane] : '0;
                    for (int stage = 1; stage <= DELAY; stage++) begin
                        delay_line[stage] <= delay_line[stage-1];
                    end
                end
            end

            assign data_out[lane] = delay_line[DELAY];
        end
    endgenerate
endmodule
