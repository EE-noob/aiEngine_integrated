`ifndef AI_DCMI_SEQUENCE_SV
`define AI_DCMI_SEQUENCE_SV

class ai_dcmi_sequence extends uvm_sequence#(ai_dcmi_seq_item);
    `uvm_object_utils(ai_dcmi_sequence)

    function new(string name = "ai_dcmi_sequence");
        super.new(name);
    endfunction

    virtual task body();
        ai_dcmi_seq_item tr;

        // Default: a couple of dummy writes then a read
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
    endtask
endclass

`endif

