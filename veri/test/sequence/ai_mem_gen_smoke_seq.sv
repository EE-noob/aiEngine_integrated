`ifndef AI_MEM_GEN_SMOKE_SEQ_SV
`define AI_MEM_GEN_SMOKE_SEQ_SV

`include "ai_csr_defines.svh"

class ai_mem_gen_smoke_seq extends uvm_sequence#(ai_nice_seq_item);
    `uvm_object_utils(ai_mem_gen_smoke_seq)

    virtual nice_if vif;

    function new(string name = "ai_mem_gen_smoke_seq");
        super.new(name);
    endfunction

    function automatic string get_utn_name();
        string utn_name;
        if (!$value$plusargs("UVM_TESTNAME=%s", utn_name) || (utn_name == "")) begin
            utn_name = "test_case_runtime";
        end
        return utn_name;
    endfunction

    task automatic write_csr(bit [31:0] addr, bit [31:0] data);
        ai_nice_seq_item tr;
        `uvm_do_with(tr, {
            cmd_kind == NICE_WR_CSR;
            csr_addr == addr;
            csr_data == data;
        })
    endtask

    task automatic parse_config(
        input string cfg_path,
        output int cfg_k,
        output int cfg_n,
        output int cfg_m,
        output int cfg_lhs_dtype,
        output int cfg_quant_mode,
        output int lhs_addr,
        output int rhs_addr,
        output int bias_addr,
        output int output_base_addr,
        output int lhs_row_stride,
        output int rhs_row_stride,
        output int dst_row_stride,
        output int lhs_offset,
        output int rhs_offset,
        output int dst_offset,
        output int dst_mult,
        output int dst_shift,
        output int act_min,
        output int act_max
    );
        integer fd;
        string line;
        int tmp;

        cfg_k = 0;
        cfg_n = 0;
        cfg_m = 0;
        cfg_lhs_dtype = 1;
        cfg_quant_mode = 0;
        lhs_addr = 0;
        rhs_addr = 0;
        bias_addr = 0;
        output_base_addr = 0;
        lhs_row_stride = 0;
        rhs_row_stride = 0;
        dst_row_stride = 0;
        lhs_offset = 0;
        rhs_offset = 0;
        dst_offset = 0;
        dst_mult = 0;
        dst_shift = 0;
        act_min = -128;
        act_max = 127;

        fd = $fopen(cfg_path, "r");
        if (fd == 0) begin
            `uvm_fatal("CFG_PARSE", $sformatf("Cannot open config file: %s", cfg_path))
        end

        while (!$feof(fd)) begin
            void'($fgets(line, fd));
            if ($sscanf(line, "K = %d", tmp) == 1) cfg_k = tmp;
            else if ($sscanf(line, "N = %d", tmp) == 1) cfg_n = tmp;
            else if ($sscanf(line, "M = %d", tmp) == 1) cfg_m = tmp;
            else if ($sscanf(line, "lhs_dtype = %d", tmp) == 1) cfg_lhs_dtype = tmp;
            else if ($sscanf(line, "quant_mode = %d", tmp) == 1) cfg_quant_mode = tmp;
            else if ($sscanf(line, "lhs_addr = %d", tmp) == 1) lhs_addr = tmp;
            else if ($sscanf(line, "rhs_addr = %d", tmp) == 1) rhs_addr = tmp;
            else if ($sscanf(line, "bias_addr = %d", tmp) == 1) bias_addr = tmp;
            else if ($sscanf(line, "output_base_addr = %d", tmp) == 1) output_base_addr = tmp;
            else if ($sscanf(line, "lhs_row_stride = %d", tmp) == 1) lhs_row_stride = tmp;
            else if ($sscanf(line, "rhs_row_stride = %d", tmp) == 1) rhs_row_stride = tmp;
            else if ($sscanf(line, "dst_row_stride = %d", tmp) == 1) dst_row_stride = tmp;
            else if ($sscanf(line, "lhs_offset = %d", tmp) == 1) lhs_offset = tmp;
            else if ($sscanf(line, "rhs_offset = %d", tmp) == 1) rhs_offset = tmp;
            else if ($sscanf(line, "dst_offset = %d", tmp) == 1) dst_offset = tmp;
            else if ($sscanf(line, "dst_mult = %d", tmp) == 1) dst_mult = tmp;
            else if ($sscanf(line, "dst_shift = %d", tmp) == 1) dst_shift = tmp;
            else if ($sscanf(line, "act_min = %d", tmp) == 1) act_min = tmp;
            else if ($sscanf(line, "act_max = %d", tmp) == 1) act_max = tmp;
        end

        $fclose(fd);

        if ((cfg_k <= 0) || (cfg_n <= 0) || (cfg_m <= 0)) begin
            `uvm_fatal("CFG_PARSE", $sformatf("Invalid K/N/M from %s: K=%0d N=%0d M=%0d", cfg_path, cfg_k, cfg_n, cfg_m))
        end
    endtask

    virtual task body();
        ai_nice_seq_item tr;
        string utn_name;
        string case_dir;
        string cfg_path;
        string cmd;
        string fix_mode_arg;
        int rc;

        int gen_k;
        int gen_n;
        int gen_m;
        int gen_lhs_dtype;
        int gen_fix_mode;
        int gen_quant_mode;

        int cfg_k;
        int cfg_n;
        int cfg_m;
        int cfg_lhs_dtype;
        int cfg_quant_mode;
        int lhs_addr;
        int rhs_addr;
        int bias_addr;
        int output_base_addr;
        int lhs_row_stride;
        int rhs_row_stride;
        int dst_row_stride;
        int lhs_offset;
        int rhs_offset;
        int dst_offset;
        int dst_mult;
        int dst_shift;
        int act_min;
        int act_max;

        `uvm_info(get_type_name(), "Start ai_mem_gen_smoke_seq", UVM_MEDIUM)

        // Only determine required generator arguments in sequence.
        gen_k = 24;
        gen_n = 32;
        gen_m = 16;
        gen_lhs_dtype = 1;
        gen_fix_mode = 1;
        gen_quant_mode = 0;

        utn_name = get_utn_name();
        case_dir = $sformatf("../tb/%s", utn_name);
        cfg_path = {case_dir, "/config.txt"};
        fix_mode_arg = (gen_fix_mode != 0) ? "--fix_mode" : "";

        cmd = $sformatf(
            "cd ../tb && python ./generate_test_case_complex_mem.py --K %0d --N %0d --M %0d --lhs_dtype %0d %s --quant_mode %0d --out_dir ./%s",
            gen_k, gen_n, gen_m, gen_lhs_dtype, fix_mode_arg, gen_quant_mode, utn_name
        );
        `uvm_info("MEM_GEN_SEQ", {"Run: ", cmd}, UVM_LOW)

        rc = $system(cmd);
        if (rc != 0) begin
            `uvm_fatal("MEM_GEN_SEQ", $sformatf("generate_test_case_complex_mem.py failed, rc=%0d", rc))
        end

        if (!uvm_config_db#(virtual nice_if)::get(null, "*", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Failed to get nice_if from uvm_config_db in sequence")
        end

        @(posedge vif.nice_clk);
        vif.mem_reload_req <= 1'b1;
        @(posedge vif.nice_clk);
        vif.mem_reload_req <= 1'b0;
        repeat(2) @(posedge vif.nice_clk);

        parse_config(
            cfg_path,
            cfg_k,
            cfg_n,
            cfg_m,
            cfg_lhs_dtype,
            cfg_quant_mode,
            lhs_addr,
            rhs_addr,
            bias_addr,
            output_base_addr,
            lhs_row_stride,
            rhs_row_stride,
            dst_row_stride,
            lhs_offset,
            rhs_offset,
            dst_offset,
            dst_mult,
            dst_shift,
            act_min,
            act_max
        );

        `uvm_info("MEM_GEN_SEQ", $sformatf("Config loaded: K=%0d N=%0d M=%0d lhs=0x%08h rhs=0x%08h bias=0x%08h out=0x%08h",
            cfg_k, cfg_n, cfg_m, lhs_addr, rhs_addr, bias_addr, output_base_addr), UVM_MEDIUM)
        uvm_top.print_topology();
        write_csr(`ADDR_MULT_LHS_PTR,   lhs_addr[31:0]);
        write_csr(`ADDR_MULT_RHS_PTR,   rhs_addr[31:0]);
        write_csr(`ADDR_MULT_BIAS_PTR,  bias_addr[31:0]);
        write_csr(`ADDR_MULT_DST_PTR,   output_base_addr[31:0]);

        write_csr(`ADDR_MULT_LHS_ROWS,  cfg_k[31:0]);
        write_csr(`ADDR_MULT_RHS_ROWS,  cfg_m[31:0]);
        write_csr(`ADDR_MULT_RHS_COLS,  cfg_n[31:0]);

        write_csr(`ADDR_MULT_LHS_STRIDE, lhs_row_stride[31:0]);
        write_csr(`ADDR_MULT_RHS_STRIDE, rhs_row_stride[31:0]);
        write_csr(`ADDR_MULT_DST_STRIDE, dst_row_stride[31:0]);

        write_csr(`ADDR_MULT_LHS_OFFSET, lhs_offset[31:0]);
        write_csr(`ADDR_MULT_RHS_OFFSET, rhs_offset[31:0]);
        write_csr(`ADDR_MULT_DST_OFFSET, dst_offset[31:0]);
        write_csr(`ADDR_MULT_DST_MULT,   dst_mult[31:0]);
        write_csr(`ADDR_MULT_DST_SHIFT,  dst_shift[31:0]);
        write_csr(`ADDR_MULT_ACT_MIN,    act_min[31:0]);
        write_csr(`ADDR_MULT_ACT_MAX,    act_max[31:0]);

        // Trigger calc_mult after seq-side mem generation/reload and config programming.
        `uvm_do_with(tr, {
            cmd_kind == NICE_TRIGGER;
            matrix_k == cfg_k;
            matrix_n == cfg_n;
            matrix_m == cfg_m;
            fix_mode == gen_fix_mode;
            per_ch == cfg_quant_mode[0];
            a_w == ((cfg_lhs_dtype == 2) ? 2 : 1);
            b_w == 1;
            bias_w == 2;
            out_w == 1;
        })

        `uvm_info(get_type_name(), "End ai_mem_gen_smoke_seq", UVM_MEDIUM)
    endtask
endclass

`endif
