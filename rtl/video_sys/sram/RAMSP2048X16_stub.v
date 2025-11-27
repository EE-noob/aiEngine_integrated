// Simple behavioral stub for 2048x16 single-port SRAM macro RAMSP2048X16.
// This is only for lint/CDC/formal; replace with technology macro in synthesis.

`ifndef RAMSP2048X16
`define RAMSP2048X16

module RAMSP2048X16 (
    output reg [15:0] Q,
    input             CLK,
    input             CEN,   // active low chip enable
    input      [15:0] WEN,   // active low write enables per bit
    input      [10:0] A,
    input      [15:0] D,
    input      [2:0]  EMA,
    input      [1:0]  EMAW,
    input             GWEN,  // active low global write enable
    input             RET1N  // retention control (ignored here)
);

`ifndef SYNTHESIS
    // Simple behavioral model for simulation / CDC
    reg [15:0] mem [0:2047];
    integer i;

    always @(posedge CLK) begin
        if (!CEN) begin
            // Write on active-low GWEN and WEN bits
            if (!GWEN) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (!WEN[i]) begin
                        mem[A][i] <= D[i];
                    end
                end
            end
            // Read
            Q <= mem[A];
        end
    end
`else
    // For synthesis / DC, avoid large inferred memories; treat as black box.
    always @(posedge CLK) begin
        Q <= 16'h0;
    end
`endif

endmodule

`endif // RAMSP2048X16
