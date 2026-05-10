`ifndef MMA_SEQUENCER_SV
`define MMA_SEQUENCER_SV

class mma_sequencer extends uvm_sequencer#(mma_seq_item);
    `uvm_component_utils(mma_sequencer)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

`endif

