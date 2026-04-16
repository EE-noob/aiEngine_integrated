`ifndef AI_NICE_PKG_SV
`define AI_NICE_PKG_SV

// NOTE: de-packaged mode. Keep this file as a compile unit aggregator.
import uvm_pkg::*;
`include "uvm_macros.svh"

`include "ai_nice_tr.sv"
`include "ai_nice_reg_adapter.sv"
`include "ai_nice_reg_model.sv"
`include "ai_nice_sequencer.sv"
`include "ai_nice_driver.sv"
`include "ai_nice_monitor.sv"
`include "../axil/ai_axil_driver.sv"
`include "../axil/ai_axil_agent.sv"
`include "ai_nice_coverage.sv"
`include "ai_nice_scoreboard.sv"
`include "ai_nice_agent.sv"

`endif
