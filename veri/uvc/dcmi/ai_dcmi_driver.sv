`ifndef AI_DCMI_DRIVER_SV
`define AI_DCMI_DRIVER_SV

class ai_dcmi_driver extends uvm_driver#(ai_dcmi_seq_item);
    `uvm_component_utils(ai_dcmi_driver)

    virtual dcmi_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dcmi_if)::get(this, "", "dcmi_vif", vif)) begin
            `uvm_fatal(get_type_name(), "dcmi_vif is not set via config DB")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        ai_dcmi_seq_item req;

        // Default values
        vif.drv_cb.dcmi_icb_cmd_valid <= 1'b0;
        vif.drv_cb.dcmi_icb_rsp_ready <= 1'b1;

        // Wait reset deassert
        wait (vif.icb_rst_n == 1'b1);

        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_transfer(ai_dcmi_seq_item tr);
        // Simple single-beat ICB-like transfer
        vif.drv_cb.dcmi_icb_cmd_addr  <= tr.addr;
        vif.drv_cb.dcmi_icb_cmd_read  <= tr.read;
        vif.drv_cb.dcmi_icb_cmd_wdata <= tr.wdata;
        vif.drv_cb.dcmi_icb_cmd_wmask <= tr.wmask;

        // Issue command
        vif.drv_cb.dcmi_icb_cmd_valid <= 1'b1;
        do @(vif.drv_cb); while (!vif.drv_cb.dcmi_icb_cmd_ready);
        vif.drv_cb.dcmi_icb_cmd_valid <= 1'b0;

        // For read, wait response
        if (tr.read) begin
            do @(vif.drv_cb); while (!vif.drv_cb.dcmi_icb_rsp_valid);
            tr.rdata = vif.drv_cb.dcmi_icb_rsp_rdata;
        end
    endtask
endclass

`endif

