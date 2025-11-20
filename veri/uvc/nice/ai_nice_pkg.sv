`ifndef AI_NICE_PKG_SV
`define AI_NICE_PKG_SV

package ai_nice_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "ai_nice_tr.sv"
    `include "ai_nice_sequencer.sv"
    `include "ai_nice_driver.sv"
    `include "ai_nice_monitor.sv"
    `include "ai_nice_coverage.sv"
    `include "ai_nice_agent.sv"
    `include "ai_nice_sequence.sv"

endpackage : ai_nice_pkg

`endif

