`ifndef ics_BASE_SEQUENCE_SV
`define ics_BASE_SEQUENCE_SV

class ics_base_sequence extends uvm_sequence#(ics_mst_tr);
    `uvm_object_utils(ics_base_sequence)

    virtual ics_if     vif;
    function new(string name = "ics_base_sequence");
        super.new(name);
    endfunction: new

    extern task pre_body();

    extern task post_body();

endclass: ics_base_sequence

task ics_base_sequence::pre_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
        phase = get_starting_phase();
    `else
        phase = starting_phase;
    `endif

    if(phase != null) begin
        phase.raise_objection(this, get_type_name());
        `uvm_info(get_type_name(), "Raised objection...", UVM_MEDIUM)
    end

    if(!uvm_config_db#(virtual ics_if)::get(null,"","ics_vif",vif)) begin
        `uvm_fatal(get_full_name(),$psprintf("Got vif failed!"))
    end
endtask: pre_body

task ics_base_sequence::post_body();
    uvm_phase phase; 
    `ifdef UVM_VERSION_1_2
        phase = get_starting_phase();
    `else
        phase = starting_phase;
    `endif

    if(phase != null) begin
        phase.drop_objection(this, get_type_name());
        `uvm_info(get_type_name(), "Dropped objection...", UVM_MEDIUM)
    end
endtask: post_body

`endif
