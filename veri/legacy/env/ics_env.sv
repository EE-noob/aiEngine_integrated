`ifndef ics_ENV__SV
`define ics_ENV__SV

class ics_env extends uvm_env;

    ics_mst_agent       i_agt;
    i2c_mon_agent       i2c_mon_agt;
    ics_mon_agent       o_agt;
    ics_rm              rm;
    ics_scb             scb;
    ics_mem_model       mem;
    ics_monitor         mon;
    combine_checker     com_chk;
    filo_collector      collector;


    uvm_tlm_analysis_fifo #(ics_mon_tr) agt_scb_fifo; // DUT output → scoreboard
    uvm_tlm_analysis_fifo #(ics_mst_tr) agt_rm_fifo;  // DUT input  → ref model
    uvm_tlm_analysis_fifo #(ics_mon_tr) rm_scb_fifo;  // RM output  → scoreboard

    function new(string name = "ics_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i_agt = ics_mst_agent::type_id::create("i_agt", this);
        o_agt = ics_mon_agent::type_id::create("o_agt", this);
        scb = ics_scb::type_id::create("scb",this);
        rm = ics_rm::type_id::create("rm",this);
        mem = ics_mem_model::type_id::create("mem",this);
        collector = filo_collector::type_id::create("collector",this);
        mon = ics_monitor::type_id::create("mon",this);
        com_chk = combine_checker::type_id::create("com_chk",this);
        agt_scb_fifo = new("agt_scb_fifo", this);
        agt_rm_fifo = new("agt_rm_fifo", this);
        rm_scb_fifo = new("rm_scb_fifo", this);
    endfunction

    extern virtual function void connect_phase(uvm_phase phase);

    `uvm_component_utils(ics_env)
endclass

function void ics_env::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    uvm_root::get().print_topology();

    i_agt.out_port.connect(agt_rm_fifo.analysis_export);
    rm.in_port.connect(agt_rm_fifo.blocking_get_export);
    rm.out_port.connect(rm_scb_fifo.analysis_export);
    scb.exp_port.connect(rm_scb_fifo.blocking_get_export);
    o_agt.out_port.connect(agt_scb_fifo.analysis_export);
    scb.act_port.connect(agt_scb_fifo.blocking_get_export);
endfunction

`endif
