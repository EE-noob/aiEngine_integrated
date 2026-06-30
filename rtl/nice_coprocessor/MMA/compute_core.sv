module compute_core #(
    parameter int unsigned SIZE       = 16,
    parameter int unsigned DATA_WIDTH = 16,
    parameter int unsigned WEIGHT_WIDTH = 16,
    parameter int unsigned PS_FRAME_COUNT = SIZE,
    parameter int unsigned MAX_IA_REUSE = 2
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         store_weight_req,
    input  logic signed [WEIGHT_WIDTH-1:0] weight_in [SIZE],
    input  logic signed [DATA_WIDTH-1:0] ia_vec_in   [SIZE],
    input  logic                         ia_row_valid,
    input  logic                         ia_tile_start,
    input  logic                         ia_calc_done,
    input  logic                         ia_is_init_data,
    input  logic                         ia_l1_switch,
    input  logic                         send_ia_trigger,
    input  logic                         bias_sleep,
    input  logic signed [31:0]           bias_in     [SIZE],

    output logic signed [31:0]           acc_data_out[SIZE],
    output logic                         acc_data_valid,
    output logic                         partial_sum_calc_over,
    output logic                         tile_calc_over
);

    logic signed [31:0] bias_or_ps_sum [0:SIZE-1];
    logic signed [31:0] systolic_sum   [0:SIZE-1];
    logic signed [31:0] ps_data_out    [0:SIZE-1];
    logic signed [31:0] ps_acc_out     [0:SIZE-1];
    logic               ps_acc_data_valid;
    logic               ps_tile_calc_over;

    localparam int unsigned PS_BURST_CYCLES = (2 * SIZE) - 1;
    localparam int unsigned PS_CNT_W        = (PS_BURST_CYCLES < 2) ? 1 :
                                               $clog2(PS_BURST_CYCLES + 1);

    logic [PS_CNT_W-1:0] ps_tail_cnt;
    logic                ia_row_valid_d;
    logic                ps_burst_is_final;
    logic                ps_burst_is_init;
    logic                ps_burst_is_l1_last;

    logic                ps_burst_start;
    logic                ps_stream_valid;
    logic                ps_calc_done;
    logic                ps_is_init_data;
    logic                ps_tile_switch;
    logic                ps_group_switch;
    logic                ps_stream_valid_d;
    logic                ps_burst_start_d;
    logic                ps_calc_done_d;
    logic                ps_is_init_data_d;
    logic                ps_tile_switch_d;
    logic                ps_group_switch_d;
    logic                final_group_calc_pending;
    logic                partial_sum_calc_over_r;
    logic [SIZE:0]       ia_tile_start_pipe;
    logic                ps_tile_start_aligned;
    bit                  compute_trace_en;

    initial begin
        compute_trace_en = 1'b0;
        if ($test$plusargs("MMA_COMPUTE_TRACE")) compute_trace_en = 1'b1;
    end

    localparam int unsigned PS_EFFECTIVE_FRAME_COUNT =
        (PS_FRAME_COUNT < 1) ? MAX_IA_REUSE : (PS_FRAME_COUNT * MAX_IA_REUSE);

    assign ps_tile_start_aligned = ia_tile_start_pipe[SIZE];
    assign ps_burst_start = ps_tile_start_aligned;

    // IA cache emits a whole L1 group as one tall diagonal stream.  Keep the
    // partial-sum stream valid for all IA rows, then drain SIZE-1 tail cycles.
    assign ps_stream_valid = ia_row_valid | (ps_tail_cnt != '0);
    assign ps_calc_done    = ps_stream_valid & (ia_row_valid ? ia_calc_done    : ps_burst_is_final);
    assign ps_is_init_data = ps_stream_valid & (ia_row_valid ? ia_is_init_data : ps_burst_is_init);
    assign ps_tile_switch  = ps_stream_valid & ~ia_row_valid & (ps_tail_cnt == PS_CNT_W'(1));
    assign ps_group_switch = ps_tile_switch & ps_burst_is_l1_last;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ia_row_valid_d    <= 1'b0;
            ps_tail_cnt       <= '0;
            ps_burst_is_final <= 1'b0;
            ps_burst_is_init  <= 1'b0;
            ps_burst_is_l1_last <= 1'b0;
            ps_stream_valid_d <= 1'b0;
            ps_burst_start_d  <= 1'b0;
            ps_calc_done_d    <= 1'b0;
            ps_is_init_data_d <= 1'b0;
            ps_tile_switch_d  <= 1'b0;
            ps_group_switch_d <= 1'b0;
            final_group_calc_pending <= 1'b0;
            partial_sum_calc_over_r  <= 1'b0;
            ia_tile_start_pipe       <= '0;
        end else begin
            partial_sum_calc_over_r <= 1'b0;
            ia_row_valid_d <= ia_row_valid;
            ia_tile_start_pipe <= {ia_tile_start_pipe[SIZE-1:0], ia_tile_start};
            ps_stream_valid_d <= ps_stream_valid;
            ps_burst_start_d  <= ps_burst_start;
            ps_calc_done_d    <= ps_calc_done;
            ps_is_init_data_d <= ps_is_init_data;
            ps_tile_switch_d  <= ps_tile_switch;
            ps_group_switch_d <= ps_group_switch;

            if (ia_row_valid) begin
                ps_tail_cnt       <= PS_CNT_W'(SIZE - 1);
                ps_burst_is_final <= ia_calc_done;
                ps_burst_is_init  <= ia_is_init_data;
                ps_burst_is_l1_last <= ps_burst_start ? ia_l1_switch
                                                       : (ps_burst_is_l1_last | ia_l1_switch);
            end else if (ps_tail_cnt != '0) begin
                ps_tail_cnt <= ps_tail_cnt - 1'b1;
                if (ia_l1_switch) begin
                    ps_burst_is_l1_last <= 1'b1;
                end
            end else begin
                ps_burst_is_final <= 1'b0;
                ps_burst_is_init  <= 1'b0;
                ps_burst_is_l1_last <= 1'b0;
            end

            if (ps_group_switch_d) begin
                if (ps_calc_done_d) begin
                    final_group_calc_pending <= 1'b1;
                end else begin
                    partial_sum_calc_over_r <= 1'b1;
                end
            end

            if ((final_group_calc_pending || (ps_group_switch_d && ps_calc_done_d)) && ps_tile_calc_over) begin
                partial_sum_calc_over_r  <= 1'b1;
                final_group_calc_pending <= 1'b0;
            end

            if (compute_trace_en &&
                (ia_tile_start || ps_burst_start_d || ps_calc_done_d ||
                 ps_acc_data_valid || ps_tile_calc_over || partial_sum_calc_over_r)) begin
                $display("[COMPUTE_TRACE] time=%0t ia_start=%0d ia_valid=%0d ia_calc=%0d ps_start=%0d ps_calc_d=%0d acc_valid=%0d tile_over=%0d partial_over=%0d",
                         $time, ia_tile_start, ia_row_valid, ia_calc_done,
                         ps_burst_start_d, ps_calc_done_d, ps_acc_data_valid,
                         ps_tile_calc_over, partial_sum_calc_over_r);
            end
        end
    end

    bias_mux #(
        .SIZE      (SIZE),
        .DATA_WIDTH(32)
    ) u_bias_mux (
        .bias_sleep(bias_sleep),
        .bias_in   (bias_in),
        .ps_in     (ps_data_out),
        .sum_in    (bias_or_ps_sum)
    );

    ws_systolic_array #(
        .SIZE         (SIZE),
        .DATA_IN_WIDTH(DATA_WIDTH),
        .WEIGHT_WIDTH (WEIGHT_WIDTH),
        .ACC_WIDTH    (32)
    ) u_systolic_array (
        .clk             (clk),
        .store_weight_req(store_weight_req),
        .weight_in       (weight_in),
        .data_in         (ia_vec_in),
        .sum_in          (bias_or_ps_sum),
        .sum_out         (systolic_sum)
    );

    ps_buffer #(
        .SIZE      (SIZE),
        .DATA_WIDTH(32),
        .FRAME_COUNT(PS_EFFECTIVE_FRAME_COUNT),
        .MAX_IA_REUSE(MAX_IA_REUSE)
    ) u_ps_buffer (
        .clk            (clk),
        .rst_n          (rst_n),
        .data_in        (systolic_sum),
        .ia_row_valid   (ps_stream_valid_d),
        .ia_calc_done   (ps_calc_done_d),
        .ia_tile_start  (ps_burst_start_d),
        .ia_l1_switch   (ps_tile_switch_d),
        .send_ia_trigger(ia_tile_start),
        .ia_is_init_data(ps_is_init_data_d),
        .replay_enable  (bias_sleep),
        .data_out       (ps_data_out),
        .acc_data_out   (ps_acc_out),
        .acc_data_valid (ps_acc_data_valid),
        .tile_calc_over (ps_tile_calc_over)
    );

    assign acc_data_valid = ps_acc_data_valid;
    assign partial_sum_calc_over = partial_sum_calc_over_r;
    assign tile_calc_over = ps_tile_calc_over;

    always_comb begin
        for (int i = 0; i < SIZE; i++) begin
            acc_data_out[i] = ps_acc_out[i];
        end
    end

endmodule
