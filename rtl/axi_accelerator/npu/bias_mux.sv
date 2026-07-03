module bias_mux #(
    parameter int unsigned SIZE       = 4,
    parameter int unsigned DATA_WIDTH = 32
) (
    input  logic                          bias_sleep,
    input  logic signed [DATA_WIDTH-1:0]   bias_in   [SIZE],
    input  logic signed [DATA_WIDTH-1:0]   ps_in     [SIZE],
    output logic signed [DATA_WIDTH-1:0]   sum_in    [SIZE]
);

  always_comb begin
    for (int i = 0; i < SIZE; i++) begin
      sum_in[i] = bias_sleep ? ps_in[i] : bias_in[i];
    end
  end

endmodule