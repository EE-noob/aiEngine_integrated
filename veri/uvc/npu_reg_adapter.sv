`ifndef NPU_REG_ADAPTER_SV
`define NPU_REG_ADAPTER_SV

class npu_reg_adapter extends uvm_reg_adapter;
    `uvm_object_utils(npu_reg_adapter)

    function new(string name = "npu_reg_adapter");
        super.new(name);
        supports_byte_enable = 0;
        provides_responses   = 0;
    endfunction

    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        npu_seq_item tr;

        tr = npu_seq_item::type_id::create("reg_tr");
        tr.cmd_kind     = (rw.kind == UVM_READ) ? NPU_RD_REG : NPU_WR_REG;
        tr.reg_addr     = rw.addr[31:0];
        tr.reg_data     = rw.data;
        tr.reg_check_en = 1'b0;
        return tr;
    endfunction

    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        npu_seq_item tr;

        if (!$cast(tr, bus_item)) begin
            `uvm_fatal("REG_ADAPT", "bus_item is not npu_seq_item")
        end

        rw.kind   = (tr.cmd_kind == NPU_RD_REG) ? UVM_READ : UVM_WRITE;
        rw.addr   = tr.reg_addr;
        rw.data   = tr.reg_data;
        rw.status = UVM_IS_OK;
    endfunction
endclass

`endif
