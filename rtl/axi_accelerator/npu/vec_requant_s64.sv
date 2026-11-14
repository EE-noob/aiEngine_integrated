// TFLM/NMSIS-NN int16 x int8 requantization.
// The systolic dot product and bias path remain s32. The biased accumulator is
// sign-extended before this pipeline so the NMSIS s64 requantization arithmetic
// is preserved without widening the systolic array.
module vec_requant_s64 #(
    parameter int unsigned VLEN = 16
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         init_cfg,
    input  logic signed [31:0]           activation_min_in,
    input  logic signed [31:0]           activation_max_in,
    input  logic signed [31:0]           multiplier_in[VLEN],
    input  logic signed [31:0]           shift_in[VLEN],
    input  logic                         in_valid,
    input  logic                         in_tile_done,
    input  logic signed [63:0]           in_vec_s64[VLEN],
    output logic                         out_valid,
    output logic                         out_tile_done,
    output logic signed [15:0]           out_vec_s16[VLEN]
);

    logic signed [31:0] activation_min_r;
    logic signed [31:0] activation_max_r;
    logic [4:0] valid_pipe;
    logic [4:0] tile_done_pipe;

    function automatic logic signed [31:0] reduce_multiplier(
        input logic signed [31:0] multiplier
    );
        begin
            if (multiplier < 32'sh7fff0000) begin
                reduce_multiplier = (multiplier + 32'sd32768) >>> 16;
            end else begin
                reduce_multiplier = 32'sh00007fff;
            end
        end
    endfunction

    assign out_valid = valid_pipe[4];
    assign out_tile_done = tile_done_pipe[4];

    always_ff @(posedge clk) begin
        if (!rst_n || init_cfg) begin
            activation_min_r <= '0;
            activation_max_r <= '0;
            valid_pipe <= '0;
            tile_done_pipe <= '0;
        end else begin
            valid_pipe <= {valid_pipe[3:0], in_valid};
            tile_done_pipe <= {tile_done_pipe[3:0], in_valid && in_tile_done};
        end

        if (init_cfg) begin
            activation_min_r <= activation_min_in;
            activation_max_r <= activation_max_in;
        end
    end

    for (genvar lane = 0; lane < VLEN; lane++) begin : gen_lane
        logic signed [63:0] acc_s0;
        logic signed [31:0] multiplier_s0;
        logic signed [31:0] shift_s0;
        (* use_dsp = "yes" *) logic signed [63:0] product_s1;
        logic signed [31:0] shift_s1;
        logic signed [31:0] shifted_s2;
        logic signed [31:0] rounded_s3;
        integer right_shift_i;

        always_comb begin
            right_shift_i = 14 - shift_s1;
            if (right_shift_i < 0) begin
                right_shift_i = 0;
            end else if (right_shift_i > 63) begin
                right_shift_i = 63;
            end
        end

        always_ff @(posedge clk) begin
            if (!rst_n || init_cfg) begin
                acc_s0 <= '0;
                multiplier_s0 <= '0;
                shift_s0 <= '0;
                product_s1 <= '0;
                shift_s1 <= '0;
                shifted_s2 <= '0;
                rounded_s3 <= '0;
                out_vec_s16[lane] <= '0;
            end else begin
                if (in_valid) begin
                    acc_s0 <= in_vec_s64[lane];
                    multiplier_s0 <= reduce_multiplier(multiplier_in[lane]);
                    shift_s0 <= shift_in[lane];
                end
                product_s1 <= acc_s0 * multiplier_s0;
                shift_s1 <= shift_s0;
                shifted_s2 <= product_s1 >>> right_shift_i;
                rounded_s3 <= (shifted_s2 + 32'sd1) >>> 1;

                if (valid_pipe[3]) begin
                    if (rounded_s3 < activation_min_r) begin
                        out_vec_s16[lane] <= activation_min_r[15:0];
                    end else if (rounded_s3 > activation_max_r) begin
                        out_vec_s16[lane] <= activation_max_r[15:0];
                    end else if (rounded_s3 < -32'sd32768) begin
                        out_vec_s16[lane] <= -16'sd32768;
                    end else if (rounded_s3 > 32'sd32767) begin
                        out_vec_s16[lane] <= 16'sd32767;
                    end else begin
                        out_vec_s16[lane] <= rounded_s3[15:0];
                    end
                end
            end
        end
    end

endmodule
