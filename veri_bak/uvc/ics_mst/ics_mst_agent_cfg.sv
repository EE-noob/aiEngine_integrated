`ifndef ics_mst_AGENT_CFG__SV
`define ics_mst_AGENT_CFG__SV
class ics_mst_agent_cfg extends ics_mst_agent_cfg_base;

    `uvm_object_utils_begin(ics_mst_agent_cfg)
    `uvm_object_utils_end

    extern function new(string name = "__NO_NAME__");

endclass

function ics_mst_agent_cfg::new(string name = "__NO_NAME__");
    super.new(name);
    this.cov_en=0;

endfunction

`endif
