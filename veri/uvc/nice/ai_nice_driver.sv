`ifndef AI_NICE_DRIVER_SV
`define AI_NICE_DRIVER_SV

`include "mma_csr_defines.svh"

class ai_nice_driver extends uvm_driver#(mma_seq_item);
    `uvm_component_utils(ai_nice_driver)

    // Virtual interface
    virtual nice_if vif;

    // Internal address management
    bit [31:0] ia_base_addr;
    bit [31:0] wgt_base_addr;
    bit [31:0] out_base_addr;
    bit [31:0] bias_base_addr;

    // Keep a shadow of CSR values written through frontdoor.
    bit [31:0] csr_shadow [bit [11:0]];

    // Memory Map Constants
    localparam MEM_START_ADDR = 32'h0000_0001;

    uvm_analysis_port #(mma_seq_item) drv_done_ap;
    uvm_analysis_port #(mma_seq_item) item_collected_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        drv_done_ap = new("drv_done_ap", this);
        item_collected_port = new("item_collected_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual nice_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
        end
    endfunction

    virtual task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
        phase.raise_objection(this);
        `uvm_info(get_type_name(), "Reset phase: Initializing interface signals", UVM_MEDIUM)

        vif.nice_req_valid  <= 1'b0;
        vif.nice_req_inst   <= 32'h0;
        vif.nice_req_rs1    <= 32'h0;
        vif.nice_req_rs2    <= 32'h0;
        vif.nice_rsp_ready  <= 1'b1;
        vif.mem_reload_req  <= 1'b0;
        csr_shadow.delete();

        repeat(5) @(posedge vif.nice_clk);
        phase.drop_objection(this);
    endtask

    virtual task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Run phase: Starting driver loop", UVM_MEDIUM)

        forever begin
            seq_item_port.get_next_item(req);
            `uvm_info(get_type_name(), $sformatf("Got transaction: %s", req.convert2string()), UVM_HIGH)
            item_collected_port.write(req);
            drive_item(req);

            seq_item_port.item_done();
        end
    endtask

    task drive_item(mma_seq_item req);
        case (req.cmd_kind)
            MMA_AUTO: begin
                addr_generate(req);
                mat_wr(req);
                csr_wr_all_config(req);
                send_mat_mult(req);
            end
            MMA_WR_CSR: begin
                csr_wr(req.csr_addr[11:0], req.csr_data);
            end
            MMA_RD_CSR: begin
                csr_rd(req.csr_addr[11:0], req.csr_data, req.csr_check_en);
            end
            MMA_TRIGGER: begin
                send_mat_mult(req);
            end
            MMA_LOAD_MEM: begin
                addr_generate(req);
                mat_wr(req);
            end
        endcase
    endtask

    task addr_generate(mma_seq_item req);
        int ia_size, wgt_size, out_size, bias_size;

        ia_size = req.matrix_k * req.matrix_n;
        wgt_size = req.matrix_n * req.matrix_m;
        out_size = req.matrix_k * req.matrix_m;
        bias_size = req.matrix_n * 4;

        ia_base_addr   = MEM_START_ADDR;
        wgt_base_addr  = ia_base_addr + ((ia_size + 3) & 32'hFFFF_FF01);
        bias_base_addr = wgt_base_addr + ((wgt_size + 3) & 32'hFFFF_FF01);
        out_base_addr  = bias_base_addr + ((bias_size + 3) & 32'hFFFF_FF01);

        `uvm_info("DRV_ADDR", $sformatf("Gen Addrs: IA=%0h WGT=%0h BIAS=%0h OUT=%0h",
            ia_base_addr, wgt_base_addr, bias_base_addr, out_base_addr), UVM_HIGH)
    endtask

    task mat_wr(mma_seq_item req);
        if (req.ia_matrix_file != "") begin
            `uvm_info("DRV_MEM", $sformatf("Loading IA from file: %s", req.ia_matrix_file), UVM_MEDIUM)
        end else begin
            for(int r=0; r<req.matrix_m; r++) begin
                for(int c=0; c<req.matrix_k; c++) begin
                    bit [31:0] val = req.get_matrix_value(r, c);
                end
            end
            `uvm_info("DRV_MEM", "Generated and wrote random matrix data to RAM", UVM_MEDIUM)
        end
    endtask

    function string csr_name(bit [11:0] addr);
        case (addr)
            `ADDR_MULT_LHS_PTR:        return "MULT_LHS_PTR";
            `ADDR_MULT_RHS_PTR:        return "MULT_RHS_PTR";
            `ADDR_MULT_DST_PTR:        return "MULT_DST_PTR";
            `ADDR_MULT_BIAS_PTR:       return "MULT_BIAS_PTR";
            `ADDR_MULT_LHS_OFFSET:     return "MULT_LHS_OFFSET";
            `ADDR_MULT_RHS_OFFSET:     return "MULT_RHS_OFFSET";
            `ADDR_MULT_DST_OFFSET:     return "MULT_DST_OFFSET";
            `ADDR_MULT_DST_MULT:       return "MULT_DST_MULT";
            `ADDR_MULT_DST_SHIFT:      return "MULT_DST_SHIFT";
            `ADDR_MULT_LHS_ROWS:       return "MULT_LHS_ROWS";
            `ADDR_MULT_RHS_ROWS:       return "MULT_RHS_ROWS";
            `ADDR_MULT_RHS_COLS:       return "MULT_RHS_COLS";
            `ADDR_MULT_LHS_STRIDE:     return "MULT_LHS_STRIDE";
            `ADDR_MULT_RHS_STRIDE:     return "MULT_RHS_STRIDE";
            `ADDR_MULT_DST_STRIDE:     return "MULT_DST_STRIDE";
            `ADDR_MULT_ACT_MIN:        return "MULT_ACT_MIN";
            `ADDR_MULT_ACT_MAX:        return "MULT_ACT_MAX";
            default:                   return $sformatf("UNKNOWN_CSR(0x%03h)", addr);
        endcase
    endfunction

    task csr_wr(bit [11:0] addr, bit [31:0] data);
        string name = csr_name(addr);
        int wait_cycle;
        `uvm_info("DRV_CSR", $sformatf("CSR WR: Addr=0x%03h (%s) Data=0x%08h", addr, name, data), UVM_MEDIUM)
        `uvm_info("DRV_CSR", $sformatf("CSR_WR driving: req_valid=1, req_inst=0x%08h, req_rs1=0x%08h, req_rs2=0x%08h, csr_name=%s",
            {addr, 5'b00001, `NICE_CSRWR_FUNCT3, 5'b00000, `NICE_CUSTOM_3}, data, 32'h0, name), UVM_HIGH)
        @(posedge vif.nice_clk);
        vif.nice_req_valid <= 1'b1;
        vif.nice_req_inst  <= {addr, 5'b00001, `NICE_CSRWR_FUNCT3, 5'b00000, `NICE_CUSTOM_3};
        vif.nice_req_rs1   <= data;
        vif.nice_req_rs2   <= 32'h0;

        wait_cycle = 0;
        do begin
            @(posedge vif.nice_clk);
            wait_cycle++;
            if (wait_cycle % 10000 == 0)
                `uvm_info("DRV_CSR", $sformatf("Waiting for req_ready... (cycle=%0d, req_ready=%0b)", wait_cycle, vif.nice_req_ready), UVM_NONE)
        end while(vif.nice_req_ready !== 1'b1);

        vif.nice_req_valid <= 1'b0;

        wait_cycle = 0;
        while(vif.nice_rsp_valid !== 1'b1) begin
            @(posedge vif.nice_clk);
            wait_cycle++;
            if (wait_cycle % 10000 == 0)
                `uvm_info("DRV_CSR", $sformatf("Waiting for rsp_valid... (cycle=%0d, rsp_valid=%0b)", wait_cycle, vif.nice_rsp_valid), UVM_NONE)
        end

        csr_shadow[addr] = data;
        @(posedge vif.nice_clk);
    endtask

    task csr_rd(input bit [11:0] addr, inout bit [31:0] data, input bit check_en = 1'b1);
        bit [31:0] expected;
        bit [31:0] rdata;
        string name = csr_name(addr);
        expected = data;
        `uvm_info("DRV_CSR", $sformatf("CSR RD: Addr=0x%03h (%s) Exp=0x%08h", addr, name, expected), UVM_MEDIUM)
        `uvm_info("DRV_CSR", $sformatf("CSR_RD driving: req_valid=1, req_inst=0x%08h, req_rs1=0x%08h, req_rs2=0x%08h, csr_name=%s",
            {addr, 5'b00000, `NICE_CSRR_FUNCT3, 5'b00001, `NICE_CUSTOM_3}, 32'h0, 32'h0, name), UVM_HIGH)
        @(posedge vif.nice_clk);
        vif.nice_req_valid <= 1'b1;
        vif.nice_req_inst  <= {addr, 5'b00000, `NICE_CSRR_FUNCT3, 5'b00001, `NICE_CUSTOM_3};
        vif.nice_req_rs1   <= 32'h0;
        vif.nice_req_rs2   <= 32'h0;

        do begin
            @(posedge vif.nice_clk);
        end while(vif.nice_req_ready !== 1'b1);

        vif.nice_req_valid <= 1'b0;

        while(vif.nice_rsp_valid !== 1'b1) begin
            @(posedge vif.nice_clk);
        end

        rdata = vif.nice_rsp_rdat;
        `uvm_info("DRV_CSR", $sformatf("CSR_RD got response: rsp_rdat=0x%08h, expected=0x%08h, csr_name=%s", rdata, expected, name), UVM_HIGH)
        if (check_en && (rdata !== expected)) begin
             `uvm_error("DRV_CSR", $sformatf("CSR Read Mismatch! Addr=0x%03h (%s) Exp=0x%08h Act=0x%08h", addr, name, expected, rdata))
        end
        data = rdata;
        @(posedge vif.nice_clk);
    endtask

    task csr_wr_all_config(mma_seq_item req);
        csr_wr(`ADDR_MULT_LHS_PTR, ia_base_addr);
        csr_wr(`ADDR_MULT_RHS_PTR, wgt_base_addr);
        csr_wr(`ADDR_MULT_DST_PTR, out_base_addr);
        csr_wr(`ADDR_MULT_BIAS_PTR, bias_base_addr);

        csr_wr(`ADDR_MULT_LHS_ROWS, req.matrix_m);
        csr_wr(`ADDR_MULT_RHS_ROWS, req.matrix_k);
        csr_wr(`ADDR_MULT_RHS_COLS, req.matrix_n);

        csr_wr(`ADDR_MULT_LHS_STRIDE, req.matrix_n);
        csr_wr(`ADDR_MULT_RHS_STRIDE, req.matrix_n);
        csr_wr(`ADDR_MULT_DST_STRIDE, req.matrix_m);

        csr_wr(`ADDR_MULT_LHS_OFFSET, req.lhs_offset);
        csr_wr(`ADDR_MULT_RHS_OFFSET, req.rhs_offset);
        csr_wr(`ADDR_MULT_DST_OFFSET, req.dst_offset);
        csr_wr(`ADDR_MULT_DST_MULT,   req.quant_multiplier);
        csr_wr(`ADDR_MULT_DST_SHIFT,  req.quant_shift);

        csr_wr(`ADDR_MULT_ACT_MIN, req.act_min);
        csr_wr(`ADDR_MULT_ACT_MAX, req.act_max);
    endtask

    function automatic bit [31:0] get_csr_or_default(bit [11:0] addr, bit [31:0] dft);
        if (csr_shadow.exists(addr)) begin
            return csr_shadow[addr];
        end
        return dft;
    endfunction

    function automatic string get_case_name();
        string case_name;
        if (!$value$plusargs("case=%s", case_name) || (case_name == "")) begin
            if (!$value$plusargs("UVM_TESTNAME=%s", case_name) || (case_name == "")) begin
                case_name = "test_case_runtime";
            end
        end
        return case_name;
    endfunction

    function automatic string get_case_dir();
        return $sformatf("../tb/%s", get_case_name());
    endfunction



    task automatic dump_compare_output_matrix(mma_seq_item req);
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
        bit do_compare;

        k_val = get_csr_or_default(`ADDR_MULT_LHS_ROWS, req.matrix_k);
        m_val = get_csr_or_default(`ADDR_MULT_RHS_ROWS, req.matrix_m);
        dst_base = get_csr_or_default(`ADDR_MULT_DST_PTR, out_base_addr);
        dst_stride = get_csr_or_default(`ADDR_MULT_DST_STRIDE, m_val);

        `uvm_info("MAT_CHK", $sformatf("\033[1;34mCHECK META\033[0m dst_base=0x%08h dst_stride=%0d rows(K)=%0d cols(M)=%0d total_size=%0d byte_range=[0x%08h:0x%08h]",
            dst_base, dst_stride, k_val, m_val, k_val * m_val, dst_base, dst_base + ((k_val * dst_stride) + m_val - 1)), UVM_LOW)

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

        do_compare = 1'b1;
        fd_expected = $fopen(expected_path, "r");
        if (fd_expected == 0) begin
            do_compare = 1'b0;
            `uvm_warning("MAT_CHK", $sformatf("Cannot open %s for reading, dump actual only", expected_path))
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
                mem_word = $root.tb_top.u_soc_top.cpu_mem[word_addr];
`elsif DUT_AXIL
                mem_word = $root.tb_top.u_axil_top_with_ram.u_axi_sim_ram.mem_r[word_addr];
`else
                mem_word = $root.tb_top.u_sram_icb.u_sram.u_sirv_sim_ram.mem_r[word_addr];
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

                if (do_compare) begin
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
            end
            $fwrite(fd_actual, "\n");
        end

        if ((actual_mem_byte_idx % 4) != 0) begin
            $fwrite(fd_actual_mem, "%08h\n", actual_mem_word);
        end

        if (do_compare) begin
            scan_rc = $fscanf(fd_expected, "%d", exp_extra);
            if (scan_rc == 1) begin
                mismatch_cnt = mismatch_cnt + 1;
                `uvm_error("MAT_CHK", "Expected file has extra data beyond KxM matrix")
            end
        end

        if (fd_expected != 0) begin
            $fclose(fd_expected);
        end
        $fclose(fd_actual);
        $fclose(fd_actual_mem);

        if (do_compare) begin
            if (mismatch_cnt == 0) begin
                $display("\033[32m[PASS] NICE output matrix compare matched (%0d x %0d)\033[0m", k_val, m_val);
                `uvm_info("MAT_CHK", $sformatf("PASS output matrix compare matched (%0d x %0d). actual=%s expected=%s", k_val, m_val, actual_path, expected_path), UVM_LOW)
            end else begin
                $display("\033[31m[FAIL] NICE output matrix compare failed: mismatch_cnt=%0d\033[0m", mismatch_cnt);
                `uvm_error("MAT_CHK", $sformatf("Output matrix compare failed: mismatch_cnt=%0d, reported=%0d. actual=%s expected=%s", mismatch_cnt, report_cnt, actual_path, expected_path))
            end
        end else begin
            `uvm_info("MAT_CHK", $sformatf("Expected file missing, dumped actual only: %s", actual_path), UVM_LOW)
        end
    endtask

    task send_mat_mult(mma_seq_item req);
        bit [31:0] cfg;
        bit [31:0] trig_out_base;

        trig_out_base = get_csr_or_default(`ADDR_MULT_DST_PTR, out_base_addr);

        cfg = 0;
        cfg[9]   = req.per_ch;
        cfg[8:7] = req.a_w;
        cfg[6:5] = req.b_w;
        cfg[4:3] = req.bias_w;
        cfg[2:0] = req.out_w;

        `uvm_info("drv mult csr", $sformatf("Sending Matrix Mult: OutAddr=0x%08h CFG=0x%08h", trig_out_base, cfg), UVM_MEDIUM)
        `uvm_info("trig mult", $sformatf("MAT_MULT driving: req_valid=1, req_inst=0x%08h, req_rs1=0x%08h, req_rs2=0x%08h",
            {`NICE_MAT_MULT_FUNCT7, 5'b00010, 5'b00001, `NICE_FUNCT3, 5'b00011, `NICE_CUSTOM_1}, trig_out_base, cfg), UVM_HIGH)

        @(posedge vif.nice_clk);
        vif.nice_req_valid <= 1'b1;
        vif.nice_req_inst  <= {`NICE_MAT_MULT_FUNCT7, 5'b00010, 5'b00001, `NICE_FUNCT3, 5'b00011, `NICE_CUSTOM_1};
        vif.nice_req_rs1   <= trig_out_base;
        vif.nice_req_rs2   <= cfg;

        do begin
            @(posedge vif.nice_clk);
        end while(vif.nice_req_ready !== 1'b1);

        vif.nice_req_valid <= 1'b0;

        while(vif.nice_rsp_valid !== 1'b1) begin
            @(posedge vif.nice_clk);
        end
        `uvm_info("MULT Done", $sformatf("Matrix Mult Done. Status=0x%08h", vif.nice_rsp_rdat), UVM_NONE)
        drv_done_ap.write(req);
        @(posedge vif.nice_clk);
    endtask

endclass

`endif
