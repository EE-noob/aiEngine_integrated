`ifndef MMA_REG_ADAPTER_SV
`define MMA_REG_ADAPTER_SV

class mma_reg_adapter extends uvm_reg_adapter;
    `uvm_object_utils(mma_reg_adapter)

    function new(string name = "mma_reg_adapter");
        super.new(name);
        supports_byte_enable = 0;
        provides_responses   = 0;
    endfunction

    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        mma_seq_item tr;

        tr = mma_seq_item::type_id::create("reg_tr");
        tr.cmd_kind     = (rw.kind == UVM_READ) ? MMA_RD_CSR : MMA_WR_CSR;
        tr.csr_addr     = rw.addr[31:0];
        tr.csr_data     = rw.data;
        tr.csr_check_en = 1'b0;
        return tr;
    endfunction

    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        mma_seq_item tr;

        if (!$cast(tr, bus_item)) begin
            `uvm_fatal("REG_ADAPT", "bus_item is not mma_seq_item")
        end

        rw.kind   = (tr.cmd_kind == MMA_RD_CSR) ? UVM_READ : UVM_WRITE;
        rw.addr   = tr.csr_addr;
        rw.data   = tr.csr_data;
        rw.status = UVM_IS_OK;
    endfunction
endclass

`endif
