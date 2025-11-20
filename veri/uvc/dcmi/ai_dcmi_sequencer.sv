`ifndef AI_DCMI_SEQUENCER_SV
`define AI_DCMI_SEQUENCER_SV

class ai_dcmi_sequencer extends uvm_sequencer#(ai_dcmi_seq_item);
    `uvm_component_utils(ai_dcmi_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

`endif

