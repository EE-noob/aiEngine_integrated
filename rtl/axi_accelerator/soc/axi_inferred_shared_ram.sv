// Dual-port 11.875 MiB RAM behind two AXI BRAM Controllers.
// 10 MiB uses all 320 URAM288 blocks; 1.875 MiB uses 480 RAMB36 tiles.
// This leaves enough BRAM sites for the board SoC's RAMB18 instances.
module axi_inferred_shared_ram (
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME BRAM_PORTA, READ_LATENCY 2" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK" *)
    input  wire        clka,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA RST" *)
    input  wire        rsta,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA EN" *)
    input  wire        ena,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA WE" *)
    input  wire [3:0]  wea,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR" *)
    input  wire [31:0] addra,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA DIN" *)
    input  wire [31:0] dina,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *)
    output wire [31:0] douta,

    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME BRAM_PORTB, READ_LATENCY 2" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB CLK" *)
    input  wire        clkb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB RST" *)
    input  wire        rstb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB EN" *)
    input  wire        enb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB WE" *)
    input  wire [3:0]  web,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB ADDR" *)
    input  wire [31:0] addrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DIN" *)
    input  wire [31:0] dinb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DOUT" *)
    output wire [31:0] doutb
);
    localparam [31:0] BANK_BYTES = 32'h0002_0000; // 128 KiB
    localparam [31:0] TOTAL_BYTES = 32'h00BE_0000; // 11.875 MiB
    localparam integer URAM_BANK_COUNT = 80; // 10 MiB, 320 URAM288
    localparam integer BRAM_FULL_BANK_COUNT = 15; // 1.875 MiB
    localparam integer BANK_COUNT = (TOTAL_BYTES + BANK_BYTES - 1) / BANK_BYTES;

    // The controller's BRAM_ADDR is byte-offset encoded; its low byte-lane
    // bits are implicit for the 32-bit port. Preserve the byte offsets used
    // by the bank map (confirmed at runtime in the SoC simulation).
    wire [31:0] byte_addra = addra;
    wire [31:0] byte_addrb = addrb;
    wire [31:0] bank_douta [0:BANK_COUNT-1];
    wire [31:0] bank_doutb [0:BANK_COUNT-1];
    wire [6:0] bank_a = byte_addra[23:17];
    wire [6:0] bank_b = byte_addrb[23:17];
    wire valid_a = byte_addra < TOTAL_BYTES;
    wire valid_b = byte_addrb < TOTAL_BYTES;
    reg [6:0] bank_a_q1, bank_a_q2, bank_b_q1, bank_b_q2;
    reg valid_a_q1, valid_a_q2, valid_b_q1, valid_b_q2;

    genvar bank;
    generate
`ifdef DSA_SIM_BMG_ONLY
        // Initialization tests only access the model in the BMG window.
        // Exclude unused URAM XPM models to avoid their simulation startup cost.
        for (bank = 0; bank < URAM_BANK_COUNT; bank = bank + 1) begin : gen_bank
            assign bank_douta[bank] = 32'b0;
            assign bank_doutb[bank] = 32'b0;
        end
`else
        for (bank = 0; bank < BANK_COUNT; bank = bank + 1) begin : gen_bank
            wire ena_bank = ena && valid_a && (bank_a == bank);
            wire enb_bank = enb && valid_b && (bank_b == bank);
            if (bank < URAM_BANK_COUNT) begin : gen_uram
                axi_inferred_shared_ram_bank #(.RAM_STYLE("ultra")) ram (
                    .clk(clka), .rsta(rsta), .ena(ena_bank), .wea(wea),
                    .addra(byte_addra[16:3]), .addra_hi(byte_addra[2]),
                    .dina(dina), .douta(bank_douta[bank]),
                    .rstb(rstb), .enb(enb_bank), .web(web),
                    .addrb(byte_addrb[16:3]), .addrb_hi(byte_addrb[2]),
                    .dinb(dinb), .doutb(bank_doutb[bank])
                );
            end else begin : gen_bram
                axi_inferred_shared_ram_bank #(.RAM_STYLE("block")) ram (
                    .clk(clka), .rsta(rsta), .ena(ena_bank), .wea(wea),
                    .addra(byte_addra[16:3]), .addra_hi(byte_addra[2]),
                    .dina(dina), .douta(bank_douta[bank]),
                    .rstb(rstb), .enb(enb_bank), .web(web),
                    .addrb(byte_addrb[16:3]), .addrb_hi(byte_addrb[2]),
                    .dinb(dinb), .doutb(bank_doutb[bank])
                );
            end
        end
`endif
    endgenerate

    // Align address decode with the two-cycle BRAM/URAM read data pipeline.
    always @(posedge clka) begin
        bank_a_q1 <= bank_a;
        bank_a_q2 <= bank_a_q1;
        bank_b_q1 <= bank_b;
        bank_b_q2 <= bank_b_q1;
        valid_a_q1 <= valid_a;
        valid_a_q2 <= valid_a_q1;
        valid_b_q1 <= valid_b;
        valid_b_q2 <= valid_b_q1;
    end
    assign douta = valid_a_q2 ? bank_douta[bank_a_q2] : 32'b0;
    assign doutb = valid_b_q2 ? bank_doutb[bank_b_q2] : 32'b0;
endmodule

module axi_inferred_shared_ram_bank #(
    parameter RAM_STYLE = "ultra",
    parameter integer ADDR_WIDTH = 14,
    parameter integer DEPTH_WORDS = 16384
) (
    input wire clk,
    input wire rsta,
    input wire ena,
    input wire [3:0] wea,
    input wire [ADDR_WIDTH-1:0] addra,
    input wire addra_hi,
    input wire [31:0] dina,
    output wire [31:0] douta,
    input wire rstb,
    input wire enb,
    input wire [3:0] web,
    input wire [ADDR_WIDTH-1:0] addrb,
    input wire addrb_hi,
    input wire [31:0] dinb,
    output wire [31:0] doutb
);
    wire [63:0] douta_wide, doutb_wide;
    reg addra_hi_q, addrb_hi_q;
    wire [7:0] wea_wide = addra_hi ? {wea, 4'b0000} : {4'b0000, wea};
    wire [63:0] dina_wide = addra_hi ? {dina, 32'b0} : {32'b0, dina};
    wire [7:0] web_wide = addrb_hi ? {web, 4'b0000} : {4'b0000, web};
    wire [63:0] dinb_wide = addrb_hi ? {dinb, 32'b0} : {32'b0, dinb};
    assign douta = addra_hi_q ? douta_wide[63:32] : douta_wide[31:0];
    assign doutb = addrb_hi_q ? doutb_wide[63:32] : doutb_wide[31:0];

    // XPM's TDP template makes the 64-bit URAM/BRAM geometry explicit while
    // retaining the handwritten 32-bit AXI BRAM interface and byte writes.
    xpm_memory_tdpram #(
        .ADDR_WIDTH_A(ADDR_WIDTH), .ADDR_WIDTH_B(ADDR_WIDTH),
        .AUTO_SLEEP_TIME(0),
        .BYTE_WRITE_WIDTH_A(8), .BYTE_WRITE_WIDTH_B(8),
        .CLOCKING_MODE("common_clock"),
        .ECC_MODE("no_ecc"),
        .MEMORY_INIT_FILE("none"), .MEMORY_INIT_PARAM("0"),
        .MEMORY_OPTIMIZATION("true"),
        .MEMORY_PRIMITIVE(RAM_STYLE), .MEMORY_SIZE(DEPTH_WORDS*64),
        .MESSAGE_CONTROL(0), .READ_DATA_WIDTH_A(64), .READ_DATA_WIDTH_B(64),
        .READ_LATENCY_A(2), .READ_LATENCY_B(2),
        .READ_RESET_VALUE_A("0"), .READ_RESET_VALUE_B("0"),
        .RST_MODE_A("SYNC"), .RST_MODE_B("SYNC"),
        .SIM_ASSERT_CHK(0), .USE_EMBEDDED_CONSTRAINT(0), .USE_MEM_INIT(0),
        .WAKEUP_TIME("disable_sleep"), .WRITE_DATA_WIDTH_A(64),
        .WRITE_DATA_WIDTH_B(64), .WRITE_MODE_A("no_change"),
        .WRITE_MODE_B("no_change"), .WRITE_PROTECT(1)
    ) mem (
        .sleep(1'b0),
        .clka(clk), .rsta(rsta), .ena(ena), .regcea(1'b1),
        .wea(wea_wide), .addra(addra), .dina(dina_wide),
        .injectsbiterra(1'b0), .injectdbiterra(1'b0),
        .douta(douta_wide), .sbiterra(), .dbiterra(),
        .clkb(clk), .rstb(rstb), .enb(enb), .regceb(1'b1),
        .web(web_wide), .addrb(addrb), .dinb(dinb_wide),
        .injectsbiterrb(1'b0), .injectdbiterrb(1'b0),
        .doutb(doutb_wide), .sbiterrb(), .dbiterrb()
    );

    always @(posedge clk) begin
        if (rsta) addra_hi_q <= 1'b0;
        else if (ena && (wea == 4'b0)) addra_hi_q <= addra_hi;
    end

    always @(posedge clk) begin
        if (rstb) addrb_hi_q <= 1'b0;
        else if (enb && (web == 4'b0)) addrb_hi_q <= addrb_hi;
    end
endmodule
