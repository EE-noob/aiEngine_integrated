`ifndef AI_AXIL_REG_DIRECTED_SEQ_SV
`define AI_AXIL_REG_DIRECTED_SEQ_SV

`include "npu_reg_defines.svh"

class ai_axil_reg_directed_seq extends uvm_sequence#(npu_seq_item);
    `uvm_object_utils(ai_axil_reg_directed_seq)

    function new(string name = "ai_axil_reg_directed_seq");
        super.new(name);
    endfunction

    task automatic reg_write(bit [11:0] addr, bit [31:0] data);
        npu_seq_item tr;
        tr = npu_seq_item::type_id::create("reg_write_tr");
        start_item(tr);
        tr.cmd_kind = NPU_WR_REG;
        tr.reg_addr = addr;
        tr.reg_data = data;
        tr.reg_check_en = 1'b0;
        finish_item(tr);
    endtask

    task automatic reg_read(bit [11:0] addr, bit [31:0] expected, bit check_en = 1'b1);
        npu_seq_item tr;
        tr = npu_seq_item::type_id::create("reg_read_tr");
        start_item(tr);
        tr.cmd_kind = NPU_RD_REG;
        tr.reg_addr = addr;
        tr.reg_data = expected;
        tr.reg_check_en = check_en;
        finish_item(tr);
    endtask

    task automatic reg_write_read(bit [11:0] addr, bit [31:0] data);
        reg_write(addr, data);
        reg_read(addr, data, 1'b1);
    endtask

    virtual task body();
        bit [11:0] reg_addrs[$];
        bit [31:0] reg_data[$];

        `uvm_info(get_type_name(), "Start AXI-Lite REG directed sequence", UVM_MEDIUM)

        reg_addrs.push_back(`ADDR_NPU_LHS_BASE);    reg_data.push_back(32'h0000_0101);
        reg_addrs.push_back(`ADDR_NPU_RHS_BASE);    reg_data.push_back(32'h0000_1204);
        reg_addrs.push_back(`ADDR_NPU_DST_BASE);    reg_data.push_back(32'h0000_2408);
        reg_addrs.push_back(`ADDR_NPU_BIAS_BASE);   reg_data.push_back(32'h0000_3000);
        reg_addrs.push_back(`ADDR_NPU_K);   reg_data.push_back(32'd17);
        reg_addrs.push_back(`ADDR_NPU_N);   reg_data.push_back(32'd31);
        reg_addrs.push_back(`ADDR_NPU_M);   reg_data.push_back(32'd19);
        reg_addrs.push_back(`ADDR_NPU_DST_STRIDE_B); reg_data.push_back(32'd23);
        reg_addrs.push_back(`ADDR_NPU_LHS_STRIDE_B); reg_data.push_back(32'd37);
        reg_addrs.push_back(`ADDR_NPU_RHS_STRIDE_B); reg_data.push_back(32'd41);
        reg_addrs.push_back(`ADDR_NPU_LHS_ZP); reg_data.push_back(32'hFFFF_FF81);
        reg_addrs.push_back(`ADDR_NPU_RHS_ZP); reg_data.push_back(32'h0000_0003);
        reg_addrs.push_back(`ADDR_NPU_DST_ZP); reg_data.push_back(32'hFFFF_FF80);
        reg_addrs.push_back(`ADDR_NPU_Q_MULT);   reg_data.push_back(32'h0001_7A35);
        reg_addrs.push_back(`ADDR_NPU_Q_SHIFT);  reg_data.push_back(32'hFFFF_FFF7);
        reg_addrs.push_back(`ADDR_NPU_ACT_MIN);    reg_data.push_back(32'hFFFF_FF80);
        reg_addrs.push_back(`ADDR_NPU_ACT_MAX);    reg_data.push_back(32'h0000_007F);

        foreach (reg_addrs[i]) begin
            reg_write_read(reg_addrs[i], reg_data[i]);
        end

        // Exercise local AXI-Lite control/status decode without starting NPU.
        reg_write_read(`ADDR_NPU_CTRL, 32'h0000_001E);
        reg_write_read(`ADDR_NPU_IA_REUSE, 32'd5);
        reg_write_read(`ADDR_NPU_W_REUSE, 32'd7);
        reg_read(`ADDR_NPU_STATUS, 32'h0, 1'b0);
        reg_read(`ADDR_NPU_WB_DATA, 32'h0, 1'b0);

        // Clear readable control bits and check default readback on an unmapped word address.
        reg_write_read(`ADDR_NPU_CTRL, 32'h0000_0000);
        reg_write(12'h030, 32'hDEAD_BEEF);
        reg_read(12'h030, 32'h0000_0000, 1'b1);
        reg_read(12'h031, 32'h0000_0000, 1'b1);

        `uvm_info(get_type_name(), "End AXI-Lite REG directed sequence", UVM_MEDIUM)
    endtask
endclass

`endif
