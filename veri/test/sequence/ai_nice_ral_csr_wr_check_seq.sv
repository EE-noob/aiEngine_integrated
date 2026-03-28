`ifndef AI_NICE_RAL_CSR_WR_CHECK_SEQ_SV
`define AI_NICE_RAL_CSR_WR_CHECK_SEQ_SV

class ai_nice_ral_csr_wr_check_seq extends uvm_sequence#(ai_nice_seq_item);
    `uvm_object_utils(ai_nice_ral_csr_wr_check_seq)

    ai_nice_reg_block regmodel;

    function new(string name = "ai_nice_ral_csr_wr_check_seq");
        super.new(name);
    endfunction

    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t fd_data;
        uvm_reg_data_t rd_data;
        uvm_reg        regs[$];

        if (regmodel == null) begin
            `uvm_fatal(get_type_name(), "regmodel is null, please assign before sequence start")
        end

        regmodel.default_map.get_registers(regs);
        if (regs.size() == 0) begin
            `uvm_fatal(get_type_name(), "default_map has no registers")
        end

        `uvm_info(get_type_name(),
                  $sformatf("RAL sequence start: iterate all regs on default_map, reg_num=%0d", regs.size()),
                  UVM_MEDIUM)

        foreach (regs[i]) begin
            string         reg_name;
            uvm_reg_addr_t reg_off;

            reg_name = regs[i].get_name();
            reg_off  = regs[i].get_offset(regmodel.default_map);

            // Check NICE if(frontdoor) write correctness for each mapped reg.
            fd_data = (32'h1000_0000 ^ (reg_off << 4) ^ i) & 32'hFFFF_FFFF;
            regs[i].write(status, fd_data, UVM_FRONTDOOR, regmodel.default_map, this);
            if (status != UVM_IS_OK) begin
                `uvm_error("RAL", $sformatf("FD write failed on %s (0x%03h)", reg_name, reg_off))
                continue;
            end

            regs[i].read(status, rd_data, UVM_BACKDOOR, regmodel.default_map, this);
            if (status != UVM_IS_OK) begin
                `uvm_error("RAL", $sformatf("BD read failed on %s (0x%03h)", reg_name, reg_off))
                continue;
            end

            if (rd_data[31:0] !== fd_data[31:0]) begin
                `uvm_error("RAL", $sformatf("FD->BD mismatch on %s (0x%03h) exp=0x%08h act=0x%08h",
                                             reg_name, reg_off, fd_data, rd_data))
            end
        end

        // Keep one explicit backdoor path sanity check.
        fd_data = 32'hA5A5_5A5A;
        regmodel.mult_dst_mult.write(status, fd_data, UVM_BACKDOOR, regmodel.default_map, this);
        regmodel.mult_dst_mult.read(status, rd_data, UVM_BACKDOOR, regmodel.default_map, this);
        if ((status != UVM_IS_OK) || (rd_data[31:0] !== fd_data[31:0])) begin
            `uvm_error("RAL", $sformatf("BD sanity check failed on mult_dst_mult exp=0x%08h act=0x%08h", fd_data, rd_data))
        end

        `uvm_info(get_type_name(), "RAL sequence end", UVM_MEDIUM)
    endtask
endclass

`endif
