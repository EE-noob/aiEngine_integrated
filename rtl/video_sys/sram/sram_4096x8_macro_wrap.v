// 4096x8 single-port SRAM wrapper built on a 2048x16 SRAM macro.
// Keeps the original simple-sram interface used in ov5640_icb_top.
//
// Interface matches module `sram` used in this repo:
//   clk, din[DW-1:0], addr[AW-1:0], cs, we, wem[MW-1:0], dout[DW-1:0]
//
// This wrapper packs two 8-bit addresses into one 16-bit word of the
// macro. Address mapping:
//   word_addr = addr[AW-1:1]  // 2048 deep
//   byte_sel  = addr[0]       // 0: low byte, 1: high byte
//
// The macro expected by default is `RAMSP2048X16_rtl_top` with ports:
//   Q[15:0], CLK, CEN, WEN[15:0], A[10:0], D[15:0],
//   EMA[2:0], EMAW[1:0], GWEN, RET1N
//
// Notes on control polarity (common convention):
//   CEN  : active low (0 = enable)
//   GWEN : active low (0 = write cycle)
//   WEN  : active low bit-write enables (0 = write the bit)
//   RET1N: tie-high to disable retention
// If your macro uses different polarities, adjust the ties below.

module sram_4096x8_macro_wrap #(
    parameter DP = 4096,   // depth in bytes
    parameter DW = 8,      // data width in bits
    parameter MW = 1,      // mask width (bytes)
    parameter AW = 12      // address width for 4096 depth
)(
    input                  clk,
    input      [DW-1:0]    din,
    input      [AW-1:0]    addr,
    input                  cs,
    input                  we,
    input      [MW-1:0]    wem,
    output reg [DW-1:0]    dout
);

    // Sanity for this specific wrapper
    initial begin
        if (DP != 4096 || DW != 8 || MW != 1 || AW != 12) begin
            $display("[sram_4096x8_macro_wrap] Parameter set not supported. DP=%0d DW=%0d MW=%0d AW=%0d", DP, DW, MW, AW);
        end
    end

    // Map 4096x8 -> 2048x16
    wire [10:0] word_addr = addr[AW-1:1];
    wire        byte_sel  = addr[0];

    // Write detection (original simple SRAM: cs & we)
    wire write_en = cs & we & wem[0];

    // Macro controls (active-low conventions)
    wire        cen_n  = 1'b0;           // always enabled (original cs permanently 1)
    wire        gwen_n = ~write_en;      // 0 during write, 1 otherwise
    wire [15:0] wen_n  = write_en
                         ? (byte_sel ? 16'h00FF : 16'hFF00) // 0 on the selected byte
                         : 16'hFFFF;                        // no write when reading/idle

    // Data packing for write
    wire [15:0] din16 = byte_sel ? {din, 8'h00} : {8'h00, din};

    // Read data from macro (registered by macro). We select byte next cycle.
    wire [15:0] q16;
    reg         byte_sel_r;

    always @(posedge clk) begin
        // Match the 1-cycle read latency behavior: capture byte select when reading
        if (cs & ~we) begin
            byte_sel_r <= byte_sel;
        end
    end

`ifdef USE_SRAM_MACRO
    // Tie values for technology-specific pins; adjust if your PDK requires others
    localparam [2:0] EMA_TIE  = 3'b000;
    localparam [1:0] EMAW_TIE = 2'b00;

    RAMSP2048X16 u_macro (
        .Q     (q16),
        .CLK   (clk),
        .CEN   (cen_n),
        .WEN   (wen_n),
        .A     (word_addr),
        .D     (din16),
        .EMA   (EMA_TIE),
        .EMAW  (EMAW_TIE),
        .GWEN  (gwen_n),
        .RET1N (1'b1)
    );
`else
    // Generic behavioral 2048x16 memory model for simulation when the macro is absent
    reg [15:0] mem [0:2047];
    reg [10:0] raddr_q;
    always @(posedge clk) begin
        // Read address register (always enabled like the vendor macro)
        raddr_q <= word_addr;
        if (!gwen_n) begin
            // Bit-write behavior per wen_n
            if (!byte_sel) begin
                if (wen_n[0]  == 1'b0) mem[word_addr][0]  <= din16[0];
                if (wen_n[1]  == 1'b0) mem[word_addr][1]  <= din16[1];
                if (wen_n[2]  == 1'b0) mem[word_addr][2]  <= din16[2];
                if (wen_n[3]  == 1'b0) mem[word_addr][3]  <= din16[3];
                if (wen_n[4]  == 1'b0) mem[word_addr][4]  <= din16[4];
                if (wen_n[5]  == 1'b0) mem[word_addr][5]  <= din16[5];
                if (wen_n[6]  == 1'b0) mem[word_addr][6]  <= din16[6];
                if (wen_n[7]  == 1'b0) mem[word_addr][7]  <= din16[7];
            end else begin
                if (wen_n[8]  == 1'b0) mem[word_addr][8]  <= din16[8];
                if (wen_n[9]  == 1'b0) mem[word_addr][9]  <= din16[9];
                if (wen_n[10] == 1'b0) mem[word_addr][10] <= din16[10];
                if (wen_n[11] == 1'b0) mem[word_addr][11] <= din16[11];
                if (wen_n[12] == 1'b0) mem[word_addr][12] <= din16[12];
                if (wen_n[13] == 1'b0) mem[word_addr][13] <= din16[13];
                if (wen_n[14] == 1'b0) mem[word_addr][14] <= din16[14];
                if (wen_n[15] == 1'b0) mem[word_addr][15] <= din16[15];
            end
        end
    end
    assign q16 = mem[raddr_q];
`endif

    // Output byte selection, aligned with macro read latency
    always @(posedge clk) begin
        dout <= byte_sel_r ? q16[15:8] : q16[7:0];
    end

endmodule

