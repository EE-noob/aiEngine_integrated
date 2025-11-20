`ifndef AI_NICE_MONITOR_SV
`define AI_NICE_MONITOR_SV

class ai_nice_monitor extends uvm_monitor;
    `uvm_component_utils(ai_nice_monitor)

    virtual nice_if vif;
    uvm_analysis_port#(ai_nice_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual nice_if)::get(this, "", "nice_vif", vif)) begin
            `uvm_fatal(get_type_name(), "nice_vif is not set via config DB")
        end
        ap = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        ai_nice_seq_item tr;
        wait (vif.nice_rst_n == 1'b1);
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.nice_req_valid && vif.mon_cb.nice_req_ready) begin
                tr = ai_nice_seq_item::type_id::create("mon_tr", this);
                tr.inst = vif.mon_cb.nice_req_inst;
                tr.rs1  = vif.mon_cb.nice_req_rs1;
                tr.rs2  = vif.mon_cb.nice_req_rs2;
                ap.write(tr);
            end
        end
    endtask
endclass

`endif

