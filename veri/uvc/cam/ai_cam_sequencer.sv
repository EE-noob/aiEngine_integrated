`ifndef AI_CAM_SEQUENCER_SV
`define AI_CAM_SEQUENCER_SV

class ai_cam_sequencer extends uvm_sequencer#(ai_cam_seq_item);
    `uvm_component_utils(ai_cam_sequencer)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

`endif

