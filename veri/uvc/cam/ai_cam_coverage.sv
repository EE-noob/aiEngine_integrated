`ifndef AI_CAM_COVERAGE_SV
`define AI_CAM_COVERAGE_SV

class ai_cam_coverage extends uvm_subscriber#(ai_cam_seq_item);
    `uvm_component_utils(ai_cam_coverage)

    ai_cam_seq_item tr;

    covergroup cg_cam;
        option.per_instance = 1;
        frame_cp : coverpoint tr.frame_id;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tr = ai_cam_seq_item::type_id::create("tr_cov");
        cg_cam = new();
    endfunction

    virtual function void write(ai_cam_seq_item t);
        tr = t;
        cg_cam.sample();
    endfunction
endclass

`endif

