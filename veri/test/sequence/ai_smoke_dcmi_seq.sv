`ifndef AI_SMOKE_DCMI_SEQ_SV
`define AI_SMOKE_DCMI_SEQ_SV

// Smoke sequence for DCMI ICB interface.
// Drives a couple of writes and one read on dcmi_if via ai_dcmi_agent.
class ai_smoke_dcmi_seq extends uvm_sequence#(ai_dcmi_seq_item);
    `uvm_object_utils(ai_smoke_dcmi_seq)

    function new(string name = "ai_smoke_dcmi_seq");
        super.new(name);
    endfunction

    virtual task body();
        ai_dcmi_seq_item tr;

        `uvm_info(get_type_name(), "Starting ai_smoke_dcmi_seq", UVM_MEDIUM)

        // A couple of dummy writes then a read
        repeat (2) begin
            tr = ai_dcmi_seq_item::type_id::create("wr_tr", , get_full_name());
            tr.read  = 1'b0;
            tr.addr  = 32'h0000_0000;
            tr.wdata = $urandom();
            tr.wmask = 4'hF;
            start_item(tr);
            finish_item(tr);
        end

        tr = ai_dcmi_seq_item::type_id::create("rd_tr", , get_full_name());
        tr.read  = 1'b1;
        tr.addr  = 32'h0000_0000;
        tr.wdata = '0;
        tr.wmask = 4'h0;
        start_item(tr);
        finish_item(tr);

        `uvm_info(get_type_name(), "Completed ai_smoke_dcmi_seq", UVM_MEDIUM)
    endtask
endclass

`endif

