`ifndef AI_NICE_TR_SV
`define AI_NICE_TR_SV

class ai_nice_seq_item extends uvm_sequence_item;
    rand bit [31:0] inst;
    rand bit [31:0] rs1;
    rand bit [31:0] rs2;
         bit [31:0] rsp_rdat;
         bit        rsp_err;

    `uvm_object_utils_begin(ai_nice_seq_item)
        `uvm_field_int(inst    , UVM_ALL_ON)
        `uvm_field_int(rs1     , UVM_ALL_ON)
        `uvm_field_int(rs2     , UVM_ALL_ON)
        `uvm_field_int(rsp_rdat, UVM_NOPACK)
        `uvm_field_int(rsp_err , UVM_NOPACK)
    `uvm_object_utils_end

    function new(string name = "ai_nice_seq_item");
        super.new(name);
    endfunction
endclass

`endif

