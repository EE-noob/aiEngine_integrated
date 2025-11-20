`ifndef AI_NICE_COVERAGE_SV
`define AI_NICE_COVERAGE_SV

class ai_nice_coverage extends uvm_subscriber#(ai_nice_seq_item);
    `uvm_component_utils(ai_nice_coverage)

    ai_nice_seq_item tr;

    covergroup cg_nice;
        option.per_instance = 1;
        inst_cp : coverpoint tr.inst;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tr = ai_nice_seq_item::type_id::create("tr_cov");
        cg_nice = new();
    endfunction

    virtual function void write(ai_nice_seq_item t);
        tr = t;
        cg_nice.sample();
    endfunction
endclass

`endif

