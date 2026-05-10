`ifndef MMA_SCOREBOARD_SV
`define MMA_SCOREBOARD_SV

`uvm_analysis_imp_decl(_req)
`uvm_analysis_imp_decl(_rsp)

class mma_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(mma_scoreboard)

    uvm_analysis_imp_req #(mma_seq_item, mma_scoreboard) analysis_req_imp;
    uvm_analysis_imp_rsp #(mma_seq_item, mma_scoreboard) analysis_rsp_imp;
    mma_seq_item pending_q[$];
    virtual nice_if vif;
    mma_reg_block regmodel;
    bit [31:0] csr_shadow[bit [11:0]];

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual nice_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "vif is not set via config DB")
        end
    endfunction

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_req_imp = new("analysis_req_imp", this);
        analysis_rsp_imp = new("analysis_rsp_imp", this);
    endfunction

    virtual function void write_req(mma_seq_item tr);
        mma_seq_item cpy;
        if (tr.cmd_kind == MMA_WR_CSR) begin
            csr_shadow[tr.csr_addr[11:0]] = tr.csr_data;
        end

        if ((tr.cmd_kind == MMA_AUTO) || (tr.cmd_kind == MMA_TRIGGER)) begin
            cpy = mma_seq_item::type_id::create("pending_req_cpy");
            cpy.copy(tr);
            pending_q.push_back(cpy);
            tr.print();
        end
    endfunction

    // NOTE: scoreboard只接收“启动比对”信号，是否启动由monitor决定。
    virtual function void write_rsp(mma_seq_item tr);
        mma_seq_item req;
        if (pending_q.size() == 0) begin
            req = mma_seq_item::type_id::create("mirror_only_req");
            req.cmd_kind = MMA_TRIGGER;
            `uvm_info("mma_seq_item req q empty", $sformatf("Compare trigger arrived with no pending req, using RAL mirror only. Status=0x%08h", tr.csr_data), UVM_LOW)
        end else begin
            req = pending_q.pop_front();
        end
        `uvm_info("MULT_DONE", $sformatf("Matrix compare triggered. Status=0x%08h", tr.csr_data), UVM_LOW)
        dump_compare_output_matrix(req);
    endfunction

    function automatic string get_utn_name();
        string utn_name;
        if (!$value$plusargs("UVM_TESTNAME=%s", utn_name) || (utn_name == "")) begin
            utn_name = "test_case_runtime";
        end
        return utn_name;
    endfunction

    function automatic string get_case_dir();
        return $sformatf("../tb/%s", get_utn_name());
    endfunction

    function automatic int infer_out_base(mma_seq_item req);
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

    function automatic bit mirror_is_valid();
        if (regmodel == null) begin
            return 1'b0;
        end
        return ((regmodel.mult_lhs_rows.get_mirrored_value() != 0) &&
                (regmodel.mult_rhs_rows.get_mirrored_value() != 0) &&
                (regmodel.mult_dst_stride.get_mirrored_value() != 0));
    endfunction

    function automatic bit shadow_is_valid();
        return csr_shadow.exists(`ADDR_MULT_LHS_ROWS) &&
               csr_shadow.exists(`ADDR_MULT_RHS_ROWS) &&
               csr_shadow.exists(`ADDR_MULT_DST_PTR) &&
               csr_shadow.exists(`ADDR_MULT_DST_STRIDE) &&
               (csr_shadow[`ADDR_MULT_LHS_ROWS] != 0) &&
               (csr_shadow[`ADDR_MULT_RHS_ROWS] != 0) &&
               (csr_shadow[`ADDR_MULT_DST_STRIDE] != 0);
    endfunction

    function automatic void dump_compare_output_matrix(mma_seq_item req);
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

        if (mirror_is_valid()) begin
            uvm_reg_data_t mirror_k;
            uvm_reg_data_t mirror_m;
            uvm_reg_data_t mirror_dst_base;
            uvm_reg_data_t mirror_dst_stride;

            mirror_k = regmodel.mult_lhs_rows.get_mirrored_value();
            mirror_m = regmodel.mult_rhs_rows.get_mirrored_value();
            mirror_dst_base = regmodel.mult_dst_ptr.get_mirrored_value();
            mirror_dst_stride = regmodel.mult_dst_stride.get_mirrored_value();

            k_val = int'(mirror_k[31:0]);
            m_val = int'(mirror_m[31:0]);
            dst_base = int'(mirror_dst_base[31:0]);
            dst_stride = int'(mirror_dst_stride[31:0]);
        end else if (shadow_is_valid()) begin
            k_val = int'(csr_shadow[`ADDR_MULT_LHS_ROWS]);
            m_val = int'(csr_shadow[`ADDR_MULT_RHS_ROWS]);
            dst_base = int'(csr_shadow[`ADDR_MULT_DST_PTR]);
            dst_stride = int'(csr_shadow[`ADDR_MULT_DST_STRIDE]);
        end else begin
            k_val = req.matrix_k;
            m_val = req.matrix_m;
            dst_base = infer_out_base(req);
            dst_stride = req.matrix_m;
        end

        `uvm_info("MAT_CHK", $sformatf("Compare window: dst_base=0x%08h dst_stride=%0d K=%0d M=%0d mirror_valid=%0b shadow_valid=%0b",
            dst_base, dst_stride, k_val, m_val, mirror_is_valid(), shadow_is_valid()), UVM_MEDIUM)

        if ((k_val <= 0) || (m_val <= 0) || (dst_stride <= 0)) begin
            `uvm_error("MAT_CHK", $sformatf("Invalid matrix shape/stride for compare: K=%0d M=%0d DST_STRIDE=%0d", k_val, m_val, dst_stride))
            return;
        end

        case_dir = get_case_dir();
        void'($system($sformatf("mkdir -p %s", case_dir)));
        actual_path = {case_dir, "/actual_dst.txt"};
        actual_mem_path = {case_dir, "/actual_dst.mem"};
        expected_path = {case_dir, "/expected_dst.txt"};

        fd_actual = $fopen(actual_path, "w");
        if (fd_actual == 0) begin
            `uvm_error("MAT_CHK", $sformatf("Cannot open %s for writing", actual_path))
            return;
        end

        fd_actual_mem = $fopen(actual_mem_path, "w");
        if (fd_actual_mem == 0) begin
            `uvm_error("MAT_CHK", $sformatf("Cannot open %s for writing", actual_mem_path))
            $fclose(fd_actual);
            return;
        end

        fd_expected = $fopen(expected_path, "r");
        if (fd_expected == 0) begin
            `uvm_error("MAT_CHK", $sformatf("Cannot open %s for reading", expected_path))
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

                mem_word = vif.read_sram_word(word_addr);
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
                        `uvm_error("MAT_CHK", $sformatf("Expected file ended early at row=%0d col=%0d", row, col))
                        report_cnt = report_cnt + 1;
                    end
                end else if (act_val != exp_val) begin
                    mismatch_cnt = mismatch_cnt + 1;
                    if (report_cnt < 20) begin
                        `uvm_error("MAT_CHK", $sformatf("Mismatch at row=%0d col=%0d: exp=%0d act=%0d (byte_addr=0x%08h)", row, col, exp_val, act_val, byte_addr))
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
            `uvm_error("MAT_CHK", "Expected file has extra data beyond KxM matrix")
        end

        $fclose(fd_expected);
        $fclose(fd_actual);
        $fclose(fd_actual_mem);

        if (mismatch_cnt == 0) begin
            `uvm_info("MAT_CHK", $sformatf("PASS output matrix compare matched (%0d x %0d). actual=%s expected=%s", k_val, m_val, actual_path, expected_path), UVM_LOW)
        end else begin
            `uvm_error("MAT_CHK", $sformatf("Output matrix compare failed: mismatch_cnt=%0d, reported=%0d. actual=%s expected=%s", mismatch_cnt, report_cnt, actual_path, expected_path))
        end
    endfunction

endclass

`endif
