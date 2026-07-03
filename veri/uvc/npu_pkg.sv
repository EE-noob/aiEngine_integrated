`ifndef NPU_PKG_SV
`define NPU_PKG_SV

// NOTE: de-packaged mode. Keep this file as a compile unit aggregator.
import uvm_pkg::*;
`include "uvm_macros.svh"

`include "npu_tr.sv"
`include "npu_reg_adapter.sv"
`include "npu_reg_model.sv"
`include "npu_sequencer.sv"
`include "axil/ai_axil_driver.sv"
`include "axil/ai_axil_monitor.sv"
`include "axil/ai_axil_agent.sv"
`include "npu_coverage.sv"
`include "npu_scoreboard.sv"

`endif
