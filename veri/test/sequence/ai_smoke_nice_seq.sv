`ifndef AI_SMOKE_NICE_SEQ_SV
`define AI_SMOKE_NICE_SEQ_SV

// Smoke sequence for nice-core request/response interface.
// Sends a few random instructions through ai_nice_agent.
class ai_smoke_nice_seq extends uvm_sequence#(ai_nice_seq_item);
    `uvm_object_utils(ai_smoke_nice_seq)

    function new(string name = "ai_smoke_nice_seq");
        super.new(name);
    endfunction

    virtual task body();
        ai_nice_seq_item tr;

        `uvm_info(get_type_name(), "Starting ai_smoke_nice_seq", UVM_MEDIUM)

        repeat (4) begin
            tr = ai_nice_seq_item::type_id::create("nice_tr", , get_full_name());
            assert(tr.randomize());
            `uvm_info(get_type_name(),
                      $sformatf("Driving nice transaction inst=0x%08h", tr.inst),
                      UVM_MEDIUM)
            start_item(tr);
            finish_item(tr);
        end

        `uvm_info(get_type_name(), "Completed ai_smoke_nice_seq", UVM_MEDIUM)
    endtask
endclass

`endif

