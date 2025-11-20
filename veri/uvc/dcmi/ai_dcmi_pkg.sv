`ifndef AI_DCMI_PKG_SV
`define AI_DCMI_PKG_SV

package ai_dcmi_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "ai_dcmi_tr.sv"
    `include "ai_dcmi_sequencer.sv"
    `include "ai_dcmi_driver.sv"
    `include "ai_dcmi_monitor.sv"
    `include "ai_dcmi_coverage.sv"
    `include "ai_dcmi_agent.sv"
    `include "ai_dcmi_sequence.sv"

endpackage : ai_dcmi_pkg

`endif

