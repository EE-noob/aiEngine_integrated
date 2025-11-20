`ifndef AI_CAM_PKG_SV
`define AI_CAM_PKG_SV

package ai_cam_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "ai_cam_tr.sv"
    `include "ai_cam_sequencer.sv"
    `include "ai_cam_driver.sv"
    `include "ai_cam_monitor.sv"
    `include "ai_cam_coverage.sv"
    `include "ai_cam_agent.sv"
    `include "ai_cam_sequence.sv"

endpackage : ai_cam_pkg

`endif

