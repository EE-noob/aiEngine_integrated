`ifndef AI_NICE_SEQUENCER_SV
`define AI_NICE_SEQUENCER_SV

class ai_nice_sequencer extends uvm_sequencer#(ai_nice_seq_item);
    `uvm_component_utils(ai_nice_sequencer)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

`endif

