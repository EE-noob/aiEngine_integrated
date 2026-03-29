`ifndef AI_ENV_PKG_SV
`define AI_ENV_PKG_SV

// NOTE: de-packaged mode.
import uvm_pkg::*;
`include "uvm_macros.svh"

class ai_env extends uvm_env;
    `uvm_component_utils(ai_env)

    ai_nice_agent       nice_agent;
    ai_nice_scoreboard  nice_scb;
    ai_nice_reg_block   regmodel;
    ai_nice_reg_adapter reg_adapter;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        nice_agent   = ai_nice_agent::type_id::create("nice_agent", this);
        nice_scb     = ai_nice_scoreboard::type_id::create("nice_scb", this);
        regmodel     = ai_nice_reg_block::type_id::create("regmodel", this);
        reg_adapter  = ai_nice_reg_adapter::type_id::create("reg_adapter");

        regmodel.build();
        regmodel.reset();
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        nice_agent.analysis_port.connect(nice_scb.analysis_imp);
        regmodel.default_map.set_sequencer(nice_agent.seqr, reg_adapter);
        regmodel.default_map.set_auto_predict(1);

        uvm_root::get().print_topology();
    endfunction
endclass

`endif
