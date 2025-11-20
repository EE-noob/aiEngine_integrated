`ifndef AI_CAM_MONITOR_SV
`define AI_CAM_MONITOR_SV

class ai_cam_monitor extends uvm_monitor;
    `uvm_component_utils(ai_cam_monitor)

    virtual cam_if vif;
    uvm_analysis_port#(ai_cam_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cam_if)::get(this, "", "cam_vif", vif)) begin
            `uvm_fatal(get_type_name(), "cam_vif is not set via config DB")
        end
        ap = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        ai_cam_seq_item tr;
        int unsigned frame_count;

        frame_count = 0;
        wait (vif.mon_cb.cam_rst_n == 1'b1);
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.cam_vsync == 1'b1) begin
                tr = ai_cam_seq_item::type_id::create("mon_tr", this);
                tr.frame_id    = frame_count++;
                tr.num_lines   = 0;
                tr.line_pixels = 0;
                tr.start_pixel = 8'h0;
                ap.write(tr);
            end
        end
    endtask
endclass

`endif

