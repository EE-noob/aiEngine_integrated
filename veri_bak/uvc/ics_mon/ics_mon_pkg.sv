`ifndef ics_mon_PKG_SV
`define ics_mon_PKG_SV


package ics_mon_pkg;
    `include "uvm_macros.svh"
    import uvm_pkg::*;
    
    `include "ics_mon_agent_cfg_base.sv"
    `include "ics_mon_agent_cfg.sv"
    `include "ics_mon_tr.sv"
    `include "ics_mon_coverage.sv"
    `include "ics_mon_sequencer.sv"
    `include "ics_mon_monitor.sv"
    `include "ics_mon_driver.sv"
    `include "ics_mon_reg_adapter.sv"
    `include "ics_mon_agent.sv"

endpackage: ics_mon_pkg

`endif
