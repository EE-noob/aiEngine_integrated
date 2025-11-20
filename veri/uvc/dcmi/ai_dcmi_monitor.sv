`ifndef AI_DCMI_MONITOR_SV
`define AI_DCMI_MONITOR_SV

class ai_dcmi_monitor extends uvm_monitor;
    `uvm_component_utils(ai_dcmi_monitor)

    virtual dcmi_if vif;
    uvm_analysis_port#(ai_dcmi_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual dcmi_if)::get(this, "", "dcmi_vif", vif)) begin
            `uvm_fatal(get_type_name(), "dcmi_vif is not set via config DB")
        end
        ap = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        ai_dcmi_seq_item tr;
        wait (vif.icb_rst_n == 1'b1);
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.dcmi_icb_cmd_valid && vif.mon_cb.dcmi_icb_cmd_ready) begin
                tr = ai_dcmi_seq_item::type_id::create("mon_tr", this);
                tr.addr  = vif.mon_cb.dcmi_icb_cmd_addr;
                tr.read  = vif.mon_cb.dcmi_icb_cmd_read;
                tr.wdata = vif.mon_cb.dcmi_icb_cmd_wdata;
                tr.wmask = vif.mon_cb.dcmi_icb_cmd_wmask;
                ap.write(tr);
            end
        end
    endtask
endclass

`endif

