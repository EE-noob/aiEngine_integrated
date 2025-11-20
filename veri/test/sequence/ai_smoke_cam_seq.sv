`ifndef AI_SMOKE_CAM_SEQ_SV
`define AI_SMOKE_CAM_SEQ_SV

// Smoke sequence for camera pixel interface.
// Generates a simple frame with a small number of lines/pixels.
class ai_smoke_cam_seq extends uvm_sequence#(ai_cam_seq_item);
    `uvm_object_utils(ai_smoke_cam_seq)

    function new(string name = "ai_smoke_cam_seq");
        super.new(name);
    endfunction

    virtual task body();
        ai_cam_seq_item tr;
        tr = ai_cam_seq_item::type_id::create("cam_tr", , get_full_name());
        tr.frame_id    = 0;
        tr.num_lines   = 8;
        tr.line_pixels = 32;
        tr.start_pixel = 8'h10;

        `uvm_info(get_type_name(), "Starting ai_smoke_cam_seq", UVM_MEDIUM)
        start_item(tr);
        finish_item(tr);
        `uvm_info(get_type_name(), "Completed ai_smoke_cam_seq", UVM_MEDIUM)
    endtask
endclass

`endif

