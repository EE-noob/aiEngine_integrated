`ifndef AI_CAM_AGENT_SV
`define AI_CAM_AGENT_SV

class ai_cam_agent extends uvm_agent;
    `uvm_component_utils(ai_cam_agent)

    ai_cam_sequencer seqr;
    ai_cam_driver    drv;
    ai_cam_monitor   mon;
    ai_cam_coverage  cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            seqr = ai_cam_sequencer::type_id::create("seqr", this);
            drv  = ai_cam_driver   ::type_id::create("drv" , this);
        end
        mon = ai_cam_monitor ::type_id::create("mon", this);
        cov = ai_cam_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(seqr.seq_item_export);
        end
        mon.ap.connect(cov.analysis_export);
    endfunction
endclass

`endif

