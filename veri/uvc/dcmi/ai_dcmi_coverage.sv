`ifndef AI_DCMI_COVERAGE_SV
`define AI_DCMI_COVERAGE_SV

class ai_dcmi_coverage extends uvm_subscriber#(ai_dcmi_seq_item);
    `uvm_component_utils(ai_dcmi_coverage)

    ai_dcmi_seq_item tr;

    covergroup cg_dcmi;
        option.per_instance = 1;
        addr_cp : coverpoint tr.addr;
        read_cp : coverpoint tr.read;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tr = ai_dcmi_seq_item::type_id::create("tr_cov");
        cg_dcmi = new();
    endfunction

    virtual function void write(ai_dcmi_seq_item t);
        tr = t;
        cg_dcmi.sample();
    endfunction
endclass

`endif

