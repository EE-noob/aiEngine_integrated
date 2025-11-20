`ifndef AI_NICE_SEQUENCE_SV
`define AI_NICE_SEQUENCE_SV

class ai_nice_sequence extends uvm_sequence#(ai_nice_seq_item);
    `uvm_object_utils(ai_nice_sequence)

    function new(string name = "ai_nice_sequence");
        super.new(name);
    endfunction

    virtual task body();
        ai_nice_seq_item tr;

        // Send a few random instructions
        repeat (4) begin
            tr = ai_nice_seq_item::type_id::create("nice_tr", , get_full_name());
            assert(tr.randomize());
            start_item(tr);
            finish_item(tr);
        end
    endtask
endclass

`endif

