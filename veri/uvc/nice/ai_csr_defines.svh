`ifndef AI_CSR_DEFINES_SVH
`define AI_CSR_DEFINES_SVH

// CSR Addresses
`define ADDR_MULT_LHS_PTR        12'h7C0
`define ADDR_MULT_RHS_PTR        12'h7C1
`define ADDR_MULT_DST_PTR        12'h7C2
`define ADDR_MULT_BIAS_PTR       12'h7C3
`define ADDR_MULT_LHS_OFFSET     12'h7C4
`define ADDR_MULT_RHS_OFFSET     12'h7C5
`define ADDR_MULT_DST_OFFSET     12'h7C6 // Output Zero Point
`define ADDR_MULT_DST_MULT       12'h7C7
`define ADDR_MULT_DST_SHIFT      12'h7C8
`define ADDR_MULT_LHS_ROWS       12'h7C9 // M
`define ADDR_MULT_RHS_ROWS       12'h7CA // K
`define ADDR_MULT_RHS_COLS       12'h7CB // N
`define ADDR_MULT_LHS_STRIDE     12'h7CC
`define ADDR_MULT_RHS_STRIDE     12'h7CD
`define ADDR_MULT_DST_STRIDE     12'h7CE
`define ADDR_MULT_ACT_MIN        12'h7CF
`define ADDR_MULT_ACT_MAX        12'h7D0

// Instruction Encodings
`define NICE_CUSTOM_1            7'b0101011
`define NICE_CUSTOM_3            7'b1111011
`define NICE_MAT_MULT_FUNCT7     7'h01
`define NICE_FUNCT3              3'b111
`define NICE_CSRWR_FUNCT3        3'b010
`define NICE_CSRR_FUNCT3         3'b100

`endif
