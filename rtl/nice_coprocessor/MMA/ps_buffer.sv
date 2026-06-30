module ps_buffer #(
    parameter int unsigned SIZE       = 16,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned FRAME_COUNT = SIZE,
    parameter int unsigned MAX_IA_REUSE = 2
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic signed [DATA_WIDTH-1:0] data_in       [0:SIZE-1],
    input  logic                         ia_row_valid,
    input  logic                         ia_calc_done,
    input  logic                         ia_tile_start,
    input  logic                         ia_l1_switch,
    input  logic                         send_ia_trigger,
    input  logic                         ia_is_init_data,
    input  logic                         replay_enable,
    output logic signed [DATA_WIDTH-1:0] data_out      [0:SIZE-1],
    output logic signed [DATA_WIDTH-1:0] acc_data_out  [0:SIZE-1],
    output logic                         acc_data_valid,
    output logic                         tile_calc_over
);
    localparam int unsigned MAX_FRAME_LEN = ((MAX_IA_REUSE + 1) * SIZE) - 1;
    // Store at most FRAME_COUNT reusable partial-sum frames, but keep one
    // extra max-sized frame worth of storage so a newly generated frame never
    // overwrites the frame that is being replayed in the same L1 pass.
    localparam int unsigned DEPTH = MAX_FRAME_LEN * (FRAME_COUNT + 1);

    logic signed [DATA_WIDTH-1:0] fifo_data_out    [0:SIZE-1];
    logic signed [DATA_WIDTH-1:0] de_diag_data_out [0:SIZE-1];

    logic                         de_diag_data_valid;
    logic                         de_diag_tile_calc_over;

    genvar lane;
    generate
        for (lane = 0; lane < SIZE; lane++) begin : gen_ps_buffer_fifo
            logic unused_input_valid;
            logic unused_is_init_data;
            logic unused_ia_l1_switch;
            logic unused_send_ia_trigger;

            ps_buffer_fifo #(
                .DEPTH     (DEPTH),
                .DATA_WIDTH(DATA_WIDTH),
                .FRAME_COUNT(FRAME_COUNT)
            ) u_ps_buffer_fifo (
                .clk              (clk),
                .rst_n            (rst_n),
                .data_in          (data_in[lane]),
                .input_valid_i    (ia_row_valid & ~ia_calc_done),
                .is_init_data_i   (ia_is_init_data),
                .ia_l1_switch_i   (ia_l1_switch),
                .send_ia_trigger_i(send_ia_trigger),
                .replay_enable_i  (replay_enable),
                .data_out         (fifo_data_out[lane]),
                .input_valid_o    (unused_input_valid),
                .is_init_data_o   (unused_is_init_data),
                .ia_l1_switch_o   (unused_ia_l1_switch),
                .send_ia_trigger_o(unused_send_ia_trigger)
            );
        end
    endgenerate

    de_diagonalizer #(
        .SIZE      (SIZE),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_de_diagonalizer (
        .clk             (clk),
        .rst_n           (rst_n),
        .data_in         (data_in),
        .input_valid_i   (ia_calc_done),
        .burst_start_i   (ia_tile_start),
        .burst_last_i    (ia_l1_switch),
        .data_out        (de_diag_data_out),
        .data_valid_o    (de_diag_data_valid),
        .tile_calc_over_o(de_diag_tile_calc_over)
    );

    always_comb begin
        for (int lane_idx = 0; lane_idx < SIZE; lane_idx++) begin
            data_out[lane_idx]     = fifo_data_out[lane_idx];
            acc_data_out[lane_idx] = de_diag_data_out[lane_idx];
        end
    end

    // acc_data_valid and tile_calc_over are owned only by de_diagonalizer.
    assign acc_data_valid = de_diag_data_valid;
    assign tile_calc_over = de_diag_tile_calc_over;
endmodule
