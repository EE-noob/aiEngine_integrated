`ifndef AI_NICE_AGENT_SV
`define AI_NICE_AGENT_SV

class ai_nice_agent extends uvm_agent;
    `uvm_component_utils(ai_nice_agent)

    ai_nice_driver    driver;
    ai_nice_sequencer seqr; // Renamed from 'sequencer' to 'seqr' to match test usage
    
    // Analysis Port for Scoreboard connection
    uvm_analysis_port #(ai_nice_seq_item) analysis_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver = ai_nice_driver::type_id::create("driver", this);
        seqr   = ai_nice_sequencer::type_id::create("seqr", this);
        analysis_port = new("analysis_port", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(seqr.seq_item_export);
        driver.item_collected_port.connect(this.analysis_port);
    endfunction
endclass

`endif

