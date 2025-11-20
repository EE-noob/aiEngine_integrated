`ifndef AI_CAM_SEQUENCE_SV
`define AI_CAM_SEQUENCE_SV

class ai_cam_sequence extends uvm_sequence#(ai_cam_seq_item);
    `uvm_object_utils(ai_cam_sequence)

    function new(string name = "ai_cam_sequence");
        super.new(name);
    endfunction

    virtual task body();
        ai_cam_seq_item tr;
        tr = ai_cam_seq_item::type_id::create("cam_tr", , get_full_name());
        tr.frame_id    = 0;
        tr.num_lines   = 8;
        tr.line_pixels = 32;
        tr.start_pixel = 8'h10;
        start_item(tr);
        finish_item(tr);
    endtask
endclass

`endif

