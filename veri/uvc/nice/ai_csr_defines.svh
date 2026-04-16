`ifndef AI_CSR_DEFINES_SVH
`define AI_CSR_DEFINES_SVH

// CSR Addresses
// Pointer Registers
`define ADDR_MULT_LHS_PTR        12'h7C0
`define ADDR_MULT_RHS_PTR        12'h7C1
`define ADDR_MULT_DST_PTR        12'h7C2
`define ADDR_MULT_BIAS_PTR       12'h7C3

// Dimension & Stride Registers
`define ADDR_MULT_LHS_ROWS       12'h7C4 // K (A Rows)
`define ADDR_MULT_RHS_COLS       12'h7C5 // N (B Rows / Inner Dim)
`define ADDR_MULT_RHS_ROWS       12'h7C6 // M (B Cols / Output Channels)
`define ADDR_MULT_DST_STRIDE     12'h7C7 // C Row Stride
`define ADDR_MULT_LHS_STRIDE     12'h7C8 // A Row Stride
`define ADDR_MULT_RHS_STRIDE     12'h7C9 // B Col Stride

// Quantization & Activation Registers
`define ADDR_MULT_LHS_OFFSET     12'h7CA // A Zero Point
`define ADDR_MULT_RHS_OFFSET     12'h7CB // B Zero Point
`define ADDR_MULT_DST_OFFSET     12'h7CC // Output Zero Point
`define ADDR_MULT_DST_MULT       12'h7CD // Multiplier (Scalar or Pointer)
`define ADDR_MULT_DST_SHIFT      12'h7CE // Shift (Scalar or Pointer)
`define ADDR_MULT_ACT_MIN        12'h7CF // Activation Min
`define ADDR_MULT_ACT_MAX        12'h7D0 // Activation Max

// AXI-Lite Special Registers (mma_axil_top)
`define ADDR_AXIL_REG_CTRL       12'h000
`define ADDR_AXIL_REG_STATUS     12'h001
`define ADDR_AXIL_REG_WB_DATA    12'h002
`define ADDR_AXIL_REG_WB_INFO    12'h003

// Instruction Encodings
`define NICE_CUSTOM_1            7'b0101011
`define NICE_CUSTOM_3            7'b1111011
`define NICE_MAT_MULT_FUNCT7     7'h01
`define NICE_FUNCT3              3'b111
`define NICE_CSRWR_FUNCT3        3'b010
`define NICE_CSRR_FUNCT3         3'b100

`endif
