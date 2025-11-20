`ifndef AI_CAM_TR_SV
`define AI_CAM_TR_SV

class ai_cam_seq_item extends uvm_sequence_item;
    rand int unsigned frame_id;
    rand int unsigned num_lines;
    rand int unsigned line_pixels;
    rand byte         start_pixel;

    `uvm_object_utils_begin(ai_cam_seq_item)
        `uvm_field_int(frame_id   , UVM_ALL_ON)
        `uvm_field_int(num_lines  , UVM_ALL_ON)
        `uvm_field_int(line_pixels, UVM_ALL_ON)
        `uvm_field_int(start_pixel, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ai_cam_seq_item");
        super.new(name);
    endfunction
endclass

`endif

