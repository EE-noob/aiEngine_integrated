`ifndef AI_CAM_DRIVER_SV
`define AI_CAM_DRIVER_SV

class ai_cam_driver extends uvm_driver#(ai_cam_seq_item);
    `uvm_component_utils(ai_cam_driver)

    virtual cam_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cam_if)::get(this, "", "cam_vif", vif)) begin
            `uvm_fatal(get_type_name(), "cam_vif is not set via config DB")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        ai_cam_seq_item req;

        // Default
        vif.drv_cb.cam_vsync <= 1'b0;
        vif.drv_cb.cam_href  <= 1'b0;
        vif.drv_cb.cam_data  <= '0;

        // Wait camera reset released from DUT
        wait (vif.drv_cb.cam_rst_n == 1'b1);

        forever begin
            seq_item_port.get_next_item(req);
            drive_frame(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_frame(ai_cam_seq_item tr);
        int unsigned line;
        int unsigned pix;
        byte         pixel_value;

        pixel_value = tr.start_pixel;

        // VSYNC pulse
        vif.drv_cb.cam_vsync <= 1'b1;
        @(vif.drv_cb);
        vif.drv_cb.cam_vsync <= 1'b0;

        for (line = 0; line < tr.num_lines; line++) begin
            for (pix = 0; pix < tr.line_pixels; pix++) begin
                vif.drv_cb.cam_href <= 1'b1;
                vif.drv_cb.cam_data <= pixel_value;
                pixel_value++;
                @(vif.drv_cb);
            end
            vif.drv_cb.cam_href <= 1'b0;
            vif.drv_cb.cam_data <= '0;
            repeat (8) @(vif.drv_cb);
        end
    endtask
endclass

`endif

