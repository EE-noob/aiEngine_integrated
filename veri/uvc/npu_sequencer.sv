`ifndef NPU_SEQUENCER_SV
`define NPU_SEQUENCER_SV

class npu_sequencer extends uvm_sequencer#(npu_seq_item);
    `uvm_component_utils(npu_sequencer)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

`endif

