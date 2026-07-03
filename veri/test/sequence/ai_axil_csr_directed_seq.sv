`ifndef AI_AXIL_CSR_DIRECTED_SEQ_SV
`define AI_AXIL_CSR_DIRECTED_SEQ_SV

`include "mma_csr_defines.svh"

class ai_axil_csr_directed_seq extends uvm_sequence#(mma_seq_item);
    `uvm_object_utils(ai_axil_csr_directed_seq)

    function new(string name = "ai_axil_csr_directed_seq");
        super.new(name);
    endfunction

    task automatic csr_write(bit [11:0] addr, bit [31:0] data);
        mma_seq_item tr;
        tr = mma_seq_item::type_id::create("csr_write_tr");
        start_item(tr);
        tr.cmd_kind = MMA_WR_CSR;
        tr.csr_addr = addr;
        tr.csr_data = data;
        tr.csr_check_en = 1'b0;
        finish_item(tr);
    endtask

    task automatic csr_read(bit [11:0] addr, bit [31:0] expected, bit check_en = 1'b1);
        mma_seq_item tr;
        tr = mma_seq_item::type_id::create("csr_read_tr");
        start_item(tr);
        tr.cmd_kind = MMA_RD_CSR;
        tr.csr_addr = addr;
        tr.csr_data = expected;
        tr.csr_check_en = check_en;
        finish_item(tr);
    endtask

    task automatic csr_write_read(bit [11:0] addr, bit [31:0] data);
        csr_write(addr, data);
        csr_read(addr, data, 1'b1);
    endtask

    virtual task body();
        bit [11:0] csr_addrs[$];
        bit [31:0] csr_data[$];

        `uvm_info(get_type_name(), "Start AXI-Lite CSR directed sequence", UVM_MEDIUM)

        csr_addrs.push_back(`ADDR_MULT_LHS_PTR);    csr_data.push_back(32'h0000_0101);
        csr_addrs.push_back(`ADDR_MULT_RHS_PTR);    csr_data.push_back(32'h0000_1204);
        csr_addrs.push_back(`ADDR_MULT_DST_PTR);    csr_data.push_back(32'h0000_2408);
        csr_addrs.push_back(`ADDR_MULT_BIAS_PTR);   csr_data.push_back(32'h0000_3000);
        csr_addrs.push_back(`ADDR_MULT_LHS_ROWS);   csr_data.push_back(32'd17);
        csr_addrs.push_back(`ADDR_MULT_RHS_COLS);   csr_data.push_back(32'd31);
        csr_addrs.push_back(`ADDR_MULT_RHS_ROWS);   csr_data.push_back(32'd19);
        csr_addrs.push_back(`ADDR_MULT_DST_STRIDE); csr_data.push_back(32'd23);
        csr_addrs.push_back(`ADDR_MULT_LHS_STRIDE); csr_data.push_back(32'd37);
        csr_addrs.push_back(`ADDR_MULT_RHS_STRIDE); csr_data.push_back(32'd41);
        csr_addrs.push_back(`ADDR_MULT_LHS_OFFSET); csr_data.push_back(32'hFFFF_FF81);
        csr_addrs.push_back(`ADDR_MULT_RHS_OFFSET); csr_data.push_back(32'h0000_0003);
        csr_addrs.push_back(`ADDR_MULT_DST_OFFSET); csr_data.push_back(32'hFFFF_FF80);
        csr_addrs.push_back(`ADDR_MULT_DST_MULT);   csr_data.push_back(32'h0001_7A35);
        csr_addrs.push_back(`ADDR_MULT_DST_SHIFT);  csr_data.push_back(32'hFFFF_FFF7);
        csr_addrs.push_back(`ADDR_MULT_ACT_MIN);    csr_data.push_back(32'hFFFF_FF80);
        csr_addrs.push_back(`ADDR_MULT_ACT_MAX);    csr_data.push_back(32'h0000_007F);

        foreach (csr_addrs[i]) begin
            csr_write_read(csr_addrs[i], csr_data[i]);
        end

        // Exercise local AXI-Lite control/status decode without starting MMA.
        csr_write_read(`ADDR_AXIL_REG_CTRL, 32'h0000_000E);
        csr_write_read(`ADDR_AXIL_REG_IA_REUSE, 32'd5);
        csr_write_read(`ADDR_AXIL_REG_W_REUSE, 32'd7);
        csr_read(`ADDR_AXIL_REG_STATUS, 32'h0, 1'b0);
        csr_read(`ADDR_AXIL_REG_WB_DATA, 32'h0, 1'b0);
        csr_read(`ADDR_AXIL_REG_WB_INFO, 32'h0, 1'b0);

        // Clear readable control bits and check default readback on an unmapped word address.
        csr_write_read(`ADDR_AXIL_REG_CTRL, 32'h0000_0000);
        csr_write(12'h006, 32'hDEAD_BEEF);
        csr_read(12'h006, 32'h0000_0000, 1'b1);
        csr_read(12'h7D4, 32'h0000_0000, 1'b1);

        `uvm_info(get_type_name(), "End AXI-Lite CSR directed sequence", UVM_MEDIUM)
    endtask
endclass

`endif
