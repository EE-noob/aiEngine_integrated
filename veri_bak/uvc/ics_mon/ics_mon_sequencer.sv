`ifndef ics_mon_SEQUENCER__SV
`define ics_mon_SEQUENCER__SV

class ics_mon_sequencer extends uvm_sequencer#(ics_mon_tr);

    `uvm_component_utils(ics_mon_sequencer)

    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);

endclass

function ics_mon_sequencer::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction

function void ics_mon_sequencer::build_phase(uvm_phase phase);
    super.build_phase(phase);
endfunction: build_phase

`endif
