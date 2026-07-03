`ifndef MMA_PKG_SV
`define MMA_PKG_SV

// NOTE: de-packaged mode. Keep this file as a compile unit aggregator.
import uvm_pkg::*;
`include "uvm_macros.svh"

`include "mma_tr.sv"
`include "mma_reg_adapter.sv"
`include "mma_reg_model.sv"
`include "mma_sequencer.sv"
`include "axil/ai_axil_driver.sv"
`include "axil/ai_axil_monitor.sv"
`include "axil/ai_axil_agent.sv"
`include "mma_coverage.sv"
`include "mma_scoreboard.sv"

`endif
