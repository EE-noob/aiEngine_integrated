`ifndef AI_RAL_MEM_GEN_ON_CALC_START_SEQ_SV
`define AI_RAL_MEM_GEN_ON_CALC_START_SEQ_SV

`include "mma_csr_defines.svh"

class ai_ral_mem_gen_on_calc_start_seq extends ai_mem_gen_smoke_seq;
    `uvm_object_utils(ai_ral_mem_gen_on_calc_start_seq)

    mma_reg_block regmodel;

    function new(string name = "ai_ral_mem_gen_on_calc_start_seq");
        super.new(name);
    endfunction

    task automatic parse_config_ext(
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
        int dst_mult_addr;
        int dst_shift_addr;

        parse_config(cfg_path, cfg_k, cfg_n, cfg_m, cfg_lhs_dtype, cfg_quant_mode,
                     lhs_addr, rhs_addr, bias_addr, output_base_addr,
                     lhs_row_stride, rhs_row_stride, dst_row_stride,
                     lhs_offset, rhs_offset, dst_offset,
                     dst_mult, dst_shift, act_min, act_max);

        dst_mult_addr = 0;
        dst_shift_addr = 0;
        begin
            integer fd;
            string line;
            int tmp;

            fd = $fopen(cfg_path, "r");
            if (fd == 0) begin
                `uvm_fatal("CFG_PARSE", $sformatf("Cannot open config file: %s", cfg_path))
            end
            while (!$feof(fd)) begin
                void'($fgets(line, fd));
                if ($sscanf(line, "dst_mult_addr = %d", tmp) == 1) dst_mult_addr = tmp;
                else if ($sscanf(line, "dst_shift_addr = %d", tmp) == 1) dst_shift_addr = tmp;
            end
            $fclose(fd);
        end

        if (cfg_quant_mode != 0) begin
            dst_mult = dst_mult_addr;
            dst_shift = dst_shift_addr;
        end
    endtask

    task automatic ral_write(mma_csr_reg rg, bit [31:0] data, string name);
        uvm_status_e status;

        if (rg == null) begin
            `uvm_fatal(get_type_name(), $sformatf("regmodel.%s is null", name))
        end

        rg.write(status, data, UVM_FRONTDOOR, regmodel.default_map, this);
        if (status != UVM_IS_OK) begin
            `uvm_fatal("RAL_MEM_GEN", $sformatf("Frontdoor write failed on %s data=0x%08h", name, data))
        end
        `uvm_info("RAL_MEM_GEN", $sformatf("FD write %-18s = 0x%08h", name, data), UVM_LOW)
    endtask

    virtual task body();
        mma_seq_item tr;
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
        int gen_seed;

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

        if (regmodel == null) begin
            `uvm_fatal(get_type_name(), "regmodel is null, please assign before sequence start")
        end

        gen_k = 24;
        gen_n = 32;
        gen_m = 16;
        gen_lhs_dtype = 1;
        gen_fix_mode = 1;
        gen_quant_mode = 0;
        gen_seed = 1;
        void'($value$plusargs("RAL_MEM_GEN_K=%d", gen_k));
        void'($value$plusargs("RAL_MEM_GEN_N=%d", gen_n));
        void'($value$plusargs("RAL_MEM_GEN_M=%d", gen_m));
        void'($value$plusargs("RAL_MEM_GEN_LHS_DTYPE=%d", gen_lhs_dtype));
        void'($value$plusargs("RAL_MEM_GEN_FIX_MODE=%d", gen_fix_mode));
        void'($value$plusargs("RAL_MEM_GEN_QUANT_MODE=%d", gen_quant_mode));
        void'($value$plusargs("RAL_MEM_GEN_SEED=%d", gen_seed));

        utn_name = get_utn_name();
        case_dir = $sformatf("../tb/%s", utn_name);
        cfg_path = {case_dir, "/config.txt"};
        fix_mode_arg = (gen_fix_mode != 0) ? "--fix_mode" : "";

        // Pre-generate once only to obtain the CSR values. The monitor regenerates
        // and reloads the same memory image when it sees mma calc_start.
        cmd = $sformatf(
            "cd ../tb && python ./generate_test_case_complex_mem.py --K %0d --N %0d --M %0d --lhs_dtype %0d %s --quant_mode %0d --seed %0d --out_dir ./%s",
            gen_k, gen_n, gen_m, gen_lhs_dtype, fix_mode_arg, gen_quant_mode, gen_seed, utn_name
        );
        `uvm_info("RAL_MEM_GEN", {"Prepare config: ", cmd}, UVM_LOW)
        rc = $system(cmd);
        if (rc != 0) begin
            `uvm_fatal("RAL_MEM_GEN", $sformatf("generate_test_case_complex_mem.py failed, rc=%0d", rc))
        end

        parse_config_ext(
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

        `uvm_info("RAL_MEM_GEN", $sformatf("Config prepared: K=%0d N=%0d M=%0d lhs_dtype=%0d quant=%0d seed=%0d",
            cfg_k, cfg_n, cfg_m, cfg_lhs_dtype, cfg_quant_mode, gen_seed), UVM_MEDIUM)

        ral_write(regmodel.mult_lhs_ptr,    lhs_addr[31:0],          "mult_lhs_ptr");
        ral_write(regmodel.mult_rhs_ptr,    rhs_addr[31:0],          "mult_rhs_ptr");
        ral_write(regmodel.mult_bias_ptr,   bias_addr[31:0],         "mult_bias_ptr");
        ral_write(regmodel.mult_dst_ptr,    output_base_addr[31:0],  "mult_dst_ptr");

        ral_write(regmodel.mult_lhs_rows,   cfg_k[31:0],             "mult_lhs_rows");
        ral_write(regmodel.mult_rhs_rows,   cfg_m[31:0],             "mult_rhs_rows");
        ral_write(regmodel.mult_rhs_cols,   cfg_n[31:0],             "mult_rhs_cols");

        ral_write(regmodel.mult_lhs_stride, lhs_row_stride[31:0],    "mult_lhs_stride");
        ral_write(regmodel.mult_rhs_stride, rhs_row_stride[31:0],    "mult_rhs_stride");
        ral_write(regmodel.mult_dst_stride, dst_row_stride[31:0],    "mult_dst_stride");

        ral_write(regmodel.mult_lhs_offset, lhs_offset[31:0],        "mult_lhs_offset");
        ral_write(regmodel.mult_rhs_offset, rhs_offset[31:0],        "mult_rhs_offset");
        ral_write(regmodel.mult_dst_offset, dst_offset[31:0],        "mult_dst_offset");
        ral_write(regmodel.mult_dst_mult,   dst_mult[31:0],          "mult_dst_mult");
        ral_write(regmodel.mult_dst_shift,  dst_shift[31:0],         "mult_dst_shift");
        ral_write(regmodel.mult_act_min,    act_min[31:0],           "mult_act_min");
        ral_write(regmodel.mult_act_max,    act_max[31:0],           "mult_act_max");

        `uvm_do_with(tr, {
            cmd_kind == MMA_TRIGGER;
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
    endtask
endclass

`endif
