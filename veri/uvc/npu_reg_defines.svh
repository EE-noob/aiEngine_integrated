`ifndef AI_NPU_REG_DEFINES_SVH
`define AI_NPU_REG_DEFINES_SVH

// NPU AXI-Lite register word offsets
// Pointer Registers
`define ADDR_NPU_LHS_BASE        12'h004
`define ADDR_NPU_RHS_BASE        12'h005
`define ADDR_NPU_DST_BASE        12'h006
`define ADDR_NPU_BIAS_BASE       12'h007

// Dimension & Stride Registers
`define ADDR_NPU_K       12'h008 // K (A Rows)
`define ADDR_NPU_N       12'h009 // N (B Rows / Inner Dim)
`define ADDR_NPU_M       12'h00A // M (B Cols / Output Channels)
`define ADDR_NPU_LHS_STRIDE_B     12'h00B // A Row Stride
`define ADDR_NPU_RHS_STRIDE_B     12'h00C // B Col Stride
`define ADDR_NPU_DST_STRIDE_B     12'h00D // C Row Stride

// Quantization & Activation Registers
`define ADDR_NPU_LHS_ZP     12'h00E // A Zero Point
`define ADDR_NPU_RHS_ZP     12'h00F // B Zero Point
`define ADDR_NPU_DST_ZP     12'h010 // Output Zero Point
`define ADDR_NPU_Q_MULT       12'h011 // Multiplier (Scalar or Pointer)
`define ADDR_NPU_Q_SHIFT      12'h012 // Shift (Scalar or Pointer)
`define ADDR_NPU_ACT_MIN        12'h013 // Activation Min
`define ADDR_NPU_ACT_MAX        12'h014 // Activation Max
`define ADDR_NPU_IA_REUSE       12'h015 // IA cache row-tile reuse depth
`define ADDR_NPU_W_REUSE        12'h016 // W-side output-column reuse window
`define ADDR_NPU_DATAFLOW       12'h017 // 0=WS, 1=IS

`define ADDR_NPU_ROW_GROUPS         12'h018
`define ADDR_NPU_ROW_TAIL_TILES     12'h019
`define ADDR_NPU_COL_GROUPS         12'h01A
`define ADDR_NPU_COL_TAIL_TILES     12'h01B
`define ADDR_NPU_CONFIG_ABI     12'h01C

// AXI-Lite Special Registers (npu_axil_top)
`define ADDR_NPU_CTRL       12'h000
`define ADDR_NPU_STATUS     12'h001
`define ADDR_NPU_WB_DATA    12'h002

`endif
