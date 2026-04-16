`ifndef AI_AXIL_AGENT_SV
`define AI_AXIL_AGENT_SV

class ai_axil_agent extends uvm_agent;
    `uvm_component_utils(ai_axil_agent)

    ai_axil_driver    driver;
    ai_nice_sequencer seqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver = ai_axil_driver::type_id::create("driver", this);
        seqr   = ai_nice_sequencer::type_id::create("seqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

`endif
