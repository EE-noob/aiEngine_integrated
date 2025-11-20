`ifndef AI_DCMI_TR_SV
`define AI_DCMI_TR_SV

class ai_dcmi_seq_item extends uvm_sequence_item;
    rand bit [31:0] addr;
    rand bit        read;
    rand bit [31:0] wdata;
    rand bit [3:0]  wmask;
         bit [31:0] rdata;

    `uvm_object_utils_begin(ai_dcmi_seq_item)
        `uvm_field_int(addr , UVM_ALL_ON)
        `uvm_field_int(read , UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(wmask, UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_NOPACK)
    `uvm_object_utils_end

    function new(string name = "ai_dcmi_seq_item");
        super.new(name);
    endfunction
endclass

`endif

