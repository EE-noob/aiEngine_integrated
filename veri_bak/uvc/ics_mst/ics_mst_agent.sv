`ifndef ics_mst_AGENT__SV
`define ics_mst_AGENT__SV
class ics_mst_agent extends uvm_agent;

    ics_mst_agent_cfg               cfg;
    virtual ics_if             vif;

    ics_mst_driver                  drv;
    ics_mst_monitor                 mon;
    ics_mst_sequencer               sqr;
    //ics_mst_rm                      rm;

    //ics_mst_reg_adapter             adapter;

    uvm_analysis_port   #(ics_mst_tr)   out_port;

    `uvm_component_utils_begin(ics_mst_agent)
        `uvm_field_object(cfg, UVM_ALL_ON)
    `uvm_component_utils_end

    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void connect_phase(uvm_phase phase);

endclass

function ics_mst_agent::new(string name, uvm_component parent);
    super.new(name,parent);
endfunction

function void ics_mst_agent::build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ics_mst_agent_cfg::type_id::create("cfg",this);

    if (!uvm_config_db#(virtual ics_if)::get(this,"","ics_vif",vif))begin
        `uvm_fatal(get_full_name(), $sformatf("Got vif failed!"))
    end

    //if (cfg.uvc_mode == REG_MASTER) begin
    //    adapter = ics_mst_reg_adapter::type_id::create("adapter", this);
    //end

    if (cfg.is_active == UVM_ACTIVE) begin
        sqr = ics_mst_sequencer::type_id::create("sqr",this);
        drv = ics_mst_driver::type_id::create("drv",this);
        drv.cfg = cfg;
    end
    mon = ics_mst_monitor::type_id::create("mon",this);
    mon.cfg = cfg;

    //if(cfg.rm_en) begin
    //    rm = ics_mst_rm::type_id::create("rm", this);
    //end

endfunction: build_phase

function void ics_mst_agent::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(cfg.is_active == UVM_ACTIVE) begin
        drv.seq_item_port.connect(sqr.seq_item_export);
        drv.sequencer = sqr;
    end
    out_port = mon.out_port;

endfunction:connect_phase
`endif
