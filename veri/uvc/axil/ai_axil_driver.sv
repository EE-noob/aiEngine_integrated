`ifndef AI_AXIL_DRIVER_SV
`define AI_AXIL_DRIVER_SV

`include "npu_reg_defines.svh"

class ai_axil_driver extends uvm_driver #(npu_seq_item);
    `uvm_component_utils(ai_axil_driver)

    localparam bit [31:0] MEM_START_ADDR = 32'h0000_0001;

    virtual axil_if vif;
    uvm_analysis_port #(npu_seq_item) item_collected_port;

    bit [31:0] ia_base_addr;
    bit [31:0] wgt_base_addr;
    bit [31:0] bias_base_addr;
    bit [31:0] out_base_addr;
    bit [31:0] reg_shadow [bit[11:0]];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axil_if)::get(this, "", "axil_vif", vif)) begin
            `uvm_fatal(get_type_name(), "axil_vif is not set via config DB")
        end
    endfunction

    virtual task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
        vif.drv_cb.awvalid <= 1'b0;
        vif.drv_cb.wvalid  <= 1'b0;
        vif.drv_cb.bready  <= 1'b0;
        vif.drv_cb.arvalid <= 1'b0;
        vif.drv_cb.rready  <= 1'b0;
        vif.drv_cb.awaddr  <= '0;
        vif.drv_cb.awprot  <= 3'b0;
        vif.drv_cb.wdata   <= '0;
        vif.drv_cb.wstrb   <= {(32/8){1'b0}};
        vif.drv_cb.araddr  <= '0;
        vif.drv_cb.arprot  <= 3'b0;
    endtask

    virtual task run_phase(uvm_phase phase);
        npu_seq_item req;
        forever begin
            seq_item_port.get_next_item(req);
            item_collected_port.write(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_item(npu_seq_item req);
        case (req.cmd_kind)
            NPU_AUTO: begin
                addr_generate(req);
                reg_wr_all_config(req);
                send_mat_mult(req);
            end
            NPU_WR_REG: begin
                reg_wr(req.reg_addr[11:0], req.reg_data);
            end
            NPU_RD_REG: begin
                reg_rd(req.reg_addr[11:0], req.reg_data, req.reg_check_en);
            end
            NPU_TRIGGER: begin
                send_mat_mult(req);
            end
            NPU_LOAD_MEM: begin
                addr_generate(req);
            end
        endcase
    endtask

    task addr_generate(npu_seq_item req);
        int ia_size, wgt_size, bias_size;
        ia_size = req.matrix_k * req.matrix_n;
        wgt_size = req.matrix_n * req.matrix_m;
        bias_size = req.matrix_n * 4;

        ia_base_addr   = MEM_START_ADDR;
        wgt_base_addr  = ia_base_addr + ((ia_size + 3) & 32'hFFFF_FF01);
        bias_base_addr = wgt_base_addr + ((wgt_size + 3) & 32'hFFFF_FF01);
        out_base_addr  = bias_base_addr + ((bias_size + 3) & 32'hFFFF_FF01);
    endtask

    // task mat_wr(npu_seq_item req);
    //     gen_mem_info(req);
    // endtask

    task axil_write(bit [15:0] addr, bit [31:0] data);
        int wait_cnt;
        wait_cnt = 0;

        @(posedge vif.clk);
        vif.drv_cb.awaddr  <= addr;
        vif.drv_cb.awprot  <= 3'b000;
        vif.drv_cb.awvalid <= 1'b1;
        vif.drv_cb.wdata   <= data;
        vif.drv_cb.wstrb   <= 4'hF;
        vif.drv_cb.wvalid  <= 1'b1;

        // Keep AW/W valid asserted until both channels handshake.
        while ((vif.drv_cb.awready !== 1'b1) || (vif.drv_cb.wready !== 1'b1)) begin
            @(posedge vif.clk);
            wait_cnt++;
            if ((wait_cnt % 10000) == 0) begin
                `uvm_info("AXIL_BUS", $sformatf("Waiting AW/W ready... addr=0x%04h awready=%0b wready=%0b cycles=%0d", addr, vif.drv_cb.awready, vif.drv_cb.wready, wait_cnt), UVM_LOW)
            end
        end

        @(posedge vif.clk);
        vif.drv_cb.awvalid <= 1'b0;
        vif.drv_cb.wvalid  <= 1'b0;

        vif.drv_cb.bready <= 1'b1;
        wait_cnt = 0;
        while (vif.drv_cb.bvalid !== 1'b1) begin
            @(posedge vif.clk);
            wait_cnt++;
            if ((wait_cnt % 10000) == 0) begin
                `uvm_info("AXIL_BUS", $sformatf("Waiting B valid... addr=0x%04h cycles=%0d", addr, wait_cnt), UVM_LOW)
            end
        end
        @(posedge vif.clk);
        vif.drv_cb.bready <= 1'b0;
    endtask

    task axil_read(bit [15:0] addr, output bit [31:0] data);
        int wait_cnt;
        wait_cnt = 0;

        @(posedge vif.clk);
        vif.drv_cb.araddr  <= addr;
        vif.drv_cb.arprot  <= 3'b000;
        vif.drv_cb.arvalid <= 1'b1;

        while (vif.drv_cb.arready !== 1'b1) begin
            @(posedge vif.clk);
            wait_cnt++;
            if ((wait_cnt % 10000) == 0) begin
                `uvm_info("AXIL_BUS", $sformatf("Waiting AR ready... addr=0x%04h arready=%0b cycles=%0d", addr, vif.drv_cb.arready, wait_cnt), UVM_LOW)
            end
        end
        @(posedge vif.clk);
        vif.drv_cb.arvalid <= 1'b0;

        vif.drv_cb.rready <= 1'b1;
        wait_cnt = 0;
        while (vif.drv_cb.rvalid !== 1'b1) begin
            @(posedge vif.clk);
            wait_cnt++;
            if ((wait_cnt % 10000) == 0) begin
                `uvm_info("AXIL_BUS", $sformatf("Waiting R valid... addr=0x%04h cycles=%0d", addr, wait_cnt), UVM_LOW)
            end
        end
        data = vif.drv_cb.rdata;
        @(posedge vif.clk);
        vif.drv_cb.rready <= 1'b0;
    endtask

    function automatic bit [15:0] reg_axil_addr(bit [11:0] reg_addr);
        return {reg_addr, 2'b00};
    endfunction

    function string reg_name(bit [11:0] addr);
        case (addr)
            `ADDR_NPU_CTRL:      return "NPU_CTRL";
            `ADDR_NPU_STATUS:    return "NPU_STATUS";
            `ADDR_NPU_WB_DATA:   return "NPU_WB_DATA";
            `ADDR_NPU_IA_REUSE:  return "NPU_IA_REUSE";
            `ADDR_NPU_W_REUSE:   return "NPU_W_REUSE";
            `ADDR_NPU_LHS_BASE:       return "NPU_LHS_BASE";
            `ADDR_NPU_RHS_BASE:       return "NPU_RHS_BASE";
            `ADDR_NPU_DST_BASE:       return "NPU_DST_BASE";
            `ADDR_NPU_BIAS_BASE:      return "NPU_BIAS_BASE";
            `ADDR_NPU_K:      return "NPU_K";
            `ADDR_NPU_N:      return "NPU_N";
            `ADDR_NPU_M:      return "NPU_M";
            `ADDR_NPU_DST_STRIDE_B:    return "NPU_DST_STRIDE_B";
            `ADDR_NPU_LHS_STRIDE_B:    return "NPU_LHS_STRIDE_B";
            `ADDR_NPU_RHS_STRIDE_B:    return "NPU_RHS_STRIDE_B";
            `ADDR_NPU_LHS_ZP:    return "NPU_LHS_ZP";
            `ADDR_NPU_RHS_ZP:    return "NPU_RHS_ZP";
            `ADDR_NPU_DST_ZP:    return "NPU_DST_ZP";
            `ADDR_NPU_Q_MULT:      return "NPU_Q_MULT";
            `ADDR_NPU_Q_SHIFT:     return "NPU_Q_SHIFT";
            `ADDR_NPU_ACT_MIN:       return "NPU_ACT_MIN";
            `ADDR_NPU_ACT_MAX:       return "NPU_ACT_MAX";
            `ADDR_NPU_DATAFLOW:      return "NPU_DATAFLOW";
            default:                  return $sformatf("UNKNOWN_REG(0x%03h)", addr);
        endcase
    endfunction

    task reg_wr(bit [11:0] addr, bit [31:0] data);
        string name;
        name = reg_name(addr);
        `uvm_info("AXIL_REG", $sformatf("REG WR: Addr=0x%03h (%s) Data=0x%08h", addr, name, data), UVM_MEDIUM)
        axil_write(reg_axil_addr(addr), data);
        reg_shadow[addr] = data;
    endtask

    task reg_rd(input bit [11:0] addr, inout bit [31:0] data, input bit check_en = 1'b1);
        bit [31:0] rdata;
        bit [31:0] expected;
        string name;
        name = reg_name(addr);
        expected = data;
        `uvm_info("AXIL_REG", $sformatf("REG RD: Addr=0x%03h (%s) Exp=0x%08h", addr, name, expected), UVM_MEDIUM)
        axil_read(reg_axil_addr(addr), rdata);
        `uvm_info("AXIL_REG", $sformatf("register_RD got response: rsp_rdat=0x%08h, expected=0x%08h, reg=%s", rdata, expected, name), UVM_HIGH)
        if (check_en && (rdata !== expected)) begin
            `uvm_error("AXIL_REG", $sformatf("REG Read Mismatch! Addr=0x%03h (%s) Exp=0x%08h Act=0x%08h", addr, name, expected, rdata))
        end
        data = rdata;
    endtask

    task reg_wr_all_config(npu_seq_item req);
        reg_wr(`ADDR_NPU_LHS_BASE, ia_base_addr);
        reg_wr(`ADDR_NPU_RHS_BASE, wgt_base_addr);
        reg_wr(`ADDR_NPU_DST_BASE, out_base_addr);
        reg_wr(`ADDR_NPU_BIAS_BASE, bias_base_addr);

        reg_wr(`ADDR_NPU_K, req.matrix_k);
        reg_wr(`ADDR_NPU_M, req.matrix_m);
        reg_wr(`ADDR_NPU_N, req.matrix_n);

        reg_wr(`ADDR_NPU_LHS_STRIDE_B, req.matrix_n);
        reg_wr(`ADDR_NPU_RHS_STRIDE_B, req.matrix_n);
        reg_wr(`ADDR_NPU_DST_STRIDE_B, req.matrix_m);

        reg_wr(`ADDR_NPU_LHS_ZP, req.lhs_offset);
        reg_wr(`ADDR_NPU_RHS_ZP, req.rhs_offset);
        reg_wr(`ADDR_NPU_DST_ZP, req.dst_offset);
        reg_wr(`ADDR_NPU_Q_MULT,   req.quant_multiplier);
        reg_wr(`ADDR_NPU_Q_SHIFT,  req.quant_shift);

        reg_wr(`ADDR_NPU_ACT_MIN, req.act_min);
        reg_wr(`ADDR_NPU_ACT_MAX, req.act_max);
    endtask

    function automatic bit [31:0] get_reg_or_default(bit [11:0] addr, bit [31:0] dft);
        if (reg_shadow.exists(addr)) begin
            return reg_shadow[addr];
        end
        return dft;
    endfunction

    function automatic string get_case_name();
        string case_name;
        if (!$value$plusargs("MEM_GEN_CASE_NAME=%s", case_name) || (case_name == "")) begin
            if (!$value$plusargs("case=%s", case_name) || (case_name == "")) begin
                if (!$value$plusargs("UVM_TESTNAME=%s", case_name) || (case_name == "")) begin
                    case_name = "test_case_runtime";
                end
            end
        end
        return case_name;
    endfunction

    function automatic string get_case_dir();
        return $sformatf("../tb/%s", get_case_name());
    endfunction

    function automatic int infer_out_base(npu_seq_item req);
        int ia_size, wgt_size, bias_size;
        int ia_base, wgt_base, bias_base;

        ia_size = req.matrix_k * req.matrix_n;
        wgt_size = req.matrix_n * req.matrix_m;
        bias_size = req.matrix_n * 4;

        ia_base = 32'h0000_0001;
        wgt_base = ia_base + ((ia_size + 3) & 32'hFFFF_FF01);
        bias_base = wgt_base + ((wgt_size + 3) & 32'hFFFF_FF01);
        return bias_base + ((bias_size + 3) & 32'hFFFF_FF01);
    endfunction

    task automatic dump_compare_output_matrix(npu_seq_item req);
        int k_val;
        int m_val;
        int dst_base;
        int dst_stride;
        int byte_addr;
        int word_addr;
        int lane;
        int row;
        int col;
        int scan_rc;
        int exp_val;
        int act_val;
        int mismatch_cnt;
        int report_cnt;
        int exp_extra;
        integer fd_actual;
        integer fd_actual_mem;
        integer fd_expected;
        bit [31:0] mem_word;
        bit [31:0] actual_mem_word;
        int actual_mem_byte_idx;
        string case_dir;
        string actual_path;
        string actual_mem_path;
        string expected_path;

        k_val = req.matrix_k;
        m_val = req.matrix_m;
        // In mem-gen flow, registers are programmed by sequence; use real programmed values.
        dst_base = get_reg_or_default(`ADDR_NPU_DST_BASE, infer_out_base(req));
        dst_stride = get_reg_or_default(`ADDR_NPU_DST_STRIDE_B, req.matrix_m);
        `uvm_info("AXIL_MAT_CHK", $sformatf("Compare window: dst_base=0x%08h dst_stride=%0d K=%0d M=%0d", dst_base, dst_stride, k_val, m_val), UVM_MEDIUM)

        if ((k_val <= 0) || (m_val <= 0) || (dst_stride <= 0)) begin
            `uvm_error("AXIL_MAT_CHK", $sformatf("Invalid matrix shape/stride for compare: K=%0d M=%0d DST_STRIDE=%0d", k_val, m_val, dst_stride))
            return;
        end

        case_dir = get_case_dir();
        void'($system($sformatf("mkdir -p %s", case_dir)));
        actual_path = {case_dir, "/actual_dst.txt"};
        actual_mem_path = {case_dir, "/actual_dst.mem"};
        expected_path = {case_dir, "/expected_dst.txt"};

        fd_actual = $fopen(actual_path, "w");
        if (fd_actual == 0) begin
            `uvm_error("AXIL_MAT_CHK", $sformatf("Cannot open %s for writing", actual_path))
            return;
        end

        fd_actual_mem = $fopen(actual_mem_path, "w");
        if (fd_actual_mem == 0) begin
            `uvm_error("AXIL_MAT_CHK", $sformatf("Cannot open %s for writing", actual_mem_path))
            $fclose(fd_actual);
            return;
        end

        fd_expected = $fopen(expected_path, "r");
        if (fd_expected == 0) begin
            `uvm_error("AXIL_MAT_CHK", $sformatf("Cannot open %s for reading", expected_path))
            $fclose(fd_actual);
            $fclose(fd_actual_mem);
            return;
        end

        mismatch_cnt = 0;
        report_cnt = 0;
        actual_mem_word = 32'h0;
        actual_mem_byte_idx = 0;

        for (row = 0; row < k_val; row = row + 1) begin
            for (col = 0; col < m_val; col = col + 1) begin
                byte_addr = dst_base + row * dst_stride + col;
                word_addr = byte_addr >> 2;
                lane = byte_addr & 32'h3;

                `ifdef DUT_AXI_SOC
	                mem_word = $root.tb_top.u_soc_top.u_axi_sim_ram.mem_r[word_addr];
`elsif DUT_AXIL
                mem_word = $root.tb_top.u_axil_top_with_ram.u_axi_sim_ram.mem_r[word_addr];
`else
                mem_word = 32'h0;
`endif
                act_val = $signed(mem_word[(lane * 8) +: 8]);

                if (col == 0) begin
                    $fwrite(fd_actual, "%0d", act_val);
                end else begin
                    $fwrite(fd_actual, " %0d", act_val);
                end

                actual_mem_word[(actual_mem_byte_idx % 4) * 8 +: 8] = act_val[7:0];
                actual_mem_byte_idx = actual_mem_byte_idx + 1;
                if ((actual_mem_byte_idx % 4) == 0) begin
                    $fwrite(fd_actual_mem, "%08h\n", actual_mem_word);
                    actual_mem_word = 32'h0;
                end

                scan_rc = $fscanf(fd_expected, "%d", exp_val);
                if (scan_rc != 1) begin
                    mismatch_cnt = mismatch_cnt + 1;
                    if (report_cnt < 20) begin
                        `uvm_error("AXIL_MAT_CHK", $sformatf("Expected file ended early at row=%0d col=%0d", row, col))
                        report_cnt = report_cnt + 1;
                    end
                end else if (act_val != exp_val) begin
                    mismatch_cnt = mismatch_cnt + 1;
                    if (report_cnt < 20) begin
                        `uvm_error("AXIL_MAT_CHK", $sformatf("Mismatch at row=%0d col=%0d: exp=%0d act=%0d (byte_addr=0x%08h)", row, col, exp_val, act_val, byte_addr))
                        report_cnt = report_cnt + 1;
                    end
                end
            end
            $fwrite(fd_actual, "\n");
        end

        if ((actual_mem_byte_idx % 4) != 0) begin
            $fwrite(fd_actual_mem, "%08h\n", actual_mem_word);
        end

        scan_rc = $fscanf(fd_expected, "%d", exp_extra);
        if (scan_rc == 1) begin
            mismatch_cnt = mismatch_cnt + 1;
            `uvm_error("AXIL_MAT_CHK", "Expected file has extra data beyond KxM matrix")
        end

        $fclose(fd_expected);
        $fclose(fd_actual);
        $fclose(fd_actual_mem);

        if (mismatch_cnt == 0) begin
            $display("\033[32m[PASS] AXIL output matrix compare matched (%0d x %0d)\033[0m", k_val, m_val);
            `uvm_info("AXIL_MAT_CHK", $sformatf("PASS output matrix compare matched (%0d x %0d). actual=%s expected=%s", k_val, m_val, actual_path, expected_path), UVM_LOW)
        end else begin
            $display("\033[31m[FAIL] AXIL output matrix compare failed: mismatch_cnt=%0d\033[0m", mismatch_cnt);
            `uvm_error("AXIL_MAT_CHK", $sformatf("Output matrix compare failed: mismatch_cnt=%0d, reported=%0d. actual=%s expected=%s", mismatch_cnt, report_cnt, actual_path, expected_path))
        end
    endtask



    task send_mat_mult(npu_seq_item req);
        bit [31:0] ctrl;
        int cfg_dataflow_mode;

        ctrl = 32'h0;
        cfg_dataflow_mode = 0;
        void'($value$plusargs("RAL_MEM_GEN_DATAFLOW=%d", cfg_dataflow_mode));
        ctrl[2] = req.per_ch;
        ctrl[1] = (req.a_w == 2);
        ctrl[3] = cfg_dataflow_mode[0];
        ctrl[4] = 1'b1;
        ctrl[0] = 1'b1;

        // Trigger NPU through AXIL special CTRL register (bit0=start pulse).
        reg_wr(`ADDR_NPU_CTRL, ctrl);
    endtask

endclass

`endif
