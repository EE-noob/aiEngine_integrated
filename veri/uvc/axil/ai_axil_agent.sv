`ifndef AI_AXIL_AGENT_SV
`define AI_AXIL_AGENT_SV

class ai_axil_agent extends uvm_agent;
    `uvm_component_utils(ai_axil_agent)

    ai_axil_driver    driver;
    ai_axil_monitor   monitor;
    mma_sequencer   seqr;
    uvm_analysis_port #(mma_seq_item) req_ap;
    uvm_analysis_port #(mma_seq_item) rsp_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver  = ai_axil_driver::type_id::create("driver", this);
        monitor = ai_axil_monitor::type_id::create("monitor", this);
        seqr    = mma_sequencer::type_id::create("seqr", this);
        req_ap  = new("req_ap", this);
        rsp_ap  = new("rsp_ap", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(seqr.seq_item_export);
        driver.item_collected_port.connect(req_ap);
        monitor.rsp_ap.connect(rsp_ap);
    endfunction
endclass

`endif
