`ifndef AI_MEM_GEN_SMOKE_SEQ_SV
`define AI_MEM_GEN_SMOKE_SEQ_SV

`include "npu_reg_defines.svh"

class ai_mem_gen_smoke_seq extends uvm_sequence#(npu_seq_item);
    `uvm_object_utils(ai_mem_gen_smoke_seq)

    virtual tb_ctrl_if tb_ctrl_vif;
    virtual axil_if axil_vif;

    function new(string name = "ai_mem_gen_smoke_seq");
        super.new(name);
    endfunction

    function automatic string get_utn_name();
        string utn_name;
        if ($value$plusargs("MEM_GEN_CASE_NAME=%s", utn_name) && (utn_name != "")) begin
            return utn_name;
        end
        if (!$value$plusargs("UVM_TESTNAME=%s", utn_name) || (utn_name == "")) begin
            utn_name = "test_case_runtime";
        end
        return utn_name;
    endfunction

    task automatic write_reg(bit [31:0] addr, bit [31:0] data);
        npu_seq_item tr;
        `uvm_do_with(tr, {
            cmd_kind == NPU_WR_REG;
            reg_addr == addr;
            reg_data == data;
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

    // Testbench acts as the external host: no divider is added to the DUT.
    function automatic int host_floor_supported(input int value);
        int p;
        p=1;
        if (value==25) return 25;
        while ((p<<1)<=value) p<<=1;
        return p;
    endfunction
    function automatic void prepare_host_tiling(input int rows,cols,mode,per_channel,
        inout int r,w, output int rg,rt,cg,ct);
        int unsigned size,cache,ps;
        int tr,tc,rc,wc,wr,tmp;
        if (!uvm_config_db#(int unsigned)::get(null,"","gempact_size",size) ||
            !uvm_config_db#(int unsigned)::get(null,"","gempact_cache",cache) ||
            !uvm_config_db#(int unsigned)::get(null,"","gempact_ps",ps))
            `uvm_fatal("HOST_TILING","Missing hardware profile for external tiling")
        if (mode!=0) begin tmp=rows;rows=cols;cols=tmp;end
        tr=(rows+int'(size)-1)/int'(size);tc=(cols+int'(size)-1)/int'(size);
        tmp=(cache<2)?1:int'(cache/2);
        rc=host_floor_supported((tr<tmp)?tr:tmp);
        wr=(tc<int'(ps))?tc:int'(ps);wc=host_floor_supported(wr);
        r=host_floor_supported((r==0 || r>=rc)?rc:r);
        w=host_floor_supported((w==0 || w>=wc)?wc:w);
        if (mode!=0 && per_channel!=0 && r>wc) r=wc;
        if (mode!=0 && w<r && wr>=r) w=r;
        rg=(tr+r-1)/r;rt=(tr%r==0)?r:tr%r;
        cg=(tc+w-1)/w;ct=(tc%w==0)?w:tc%w;
    endfunction

    virtual task body();
        npu_seq_item tr;
        string utn_name;
        string case_dir;
        string cfg_path;
        string cmd;
        string py_bin;
        string fix_mode_arg;
        int rc;

        int gen_k;
        int gen_n;
        int gen_m;
        int gen_lhs_dtype;
        int gen_fix_mode;
        int gen_quant_mode;
        int gen_seed;
        int gen_dataflow_mode;
        int gen_ia_reuse;
        int gen_w_reuse;
        int host_rg,host_rt,host_cg,host_ct;

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
        int irq_wait;

        `uvm_info(get_type_name(), "Start ai_mem_gen_smoke_seq", UVM_MEDIUM)

        // Only determine required generator arguments in sequence.
        gen_k = 24;
        gen_n = 32;
        gen_m = 16;
        gen_lhs_dtype = 1;
        gen_fix_mode = 1;
        gen_quant_mode = 0;
        gen_seed = 1;
        gen_dataflow_mode = 0;
        gen_ia_reuse = 0;
        gen_w_reuse = 0;

        void'($value$plusargs("MEM_GEN_K=%d", gen_k));
        void'($value$plusargs("MEM_GEN_N=%d", gen_n));
        void'($value$plusargs("MEM_GEN_M=%d", gen_m));
        void'($value$plusargs("MEM_GEN_LHS_DTYPE=%d", gen_lhs_dtype));
        void'($value$plusargs("MEM_GEN_FIX_MODE=%d", gen_fix_mode));
        void'($value$plusargs("MEM_GEN_QUANT_MODE=%d", gen_quant_mode));
        void'($value$plusargs("MEM_GEN_SEED=%d", gen_seed));
        void'($value$plusargs("MEM_GEN_DATAFLOW=%d", gen_dataflow_mode));
        void'($value$plusargs("MEM_GEN_IA_REUSE=%d", gen_ia_reuse));
        void'($value$plusargs("MEM_GEN_W_REUSE=%d", gen_w_reuse));

        utn_name = get_utn_name();
        case_dir = $sformatf("../tb/%s", utn_name);
        cfg_path = {case_dir, "/config.txt"};
        fix_mode_arg = (gen_fix_mode != 0) ? "--fix_mode" : "";
        py_bin = "/home/yusen/opt/anaconda3/bin/python3";
        void'($value$plusargs("PYTHON_BIN=%s", py_bin));

        cmd = $sformatf(
            "cd ../tb && %s ./generate_test_case_complex_mem.py --K %0d --N %0d --M %0d --lhs_dtype %0d %s --quant_mode %0d --seed %0d --out_dir ./%s",
            py_bin, gen_k, gen_n, gen_m, gen_lhs_dtype, fix_mode_arg, gen_quant_mode, gen_seed, utn_name
        );
        `uvm_info("MEM_GEN_SEQ", {"Run: ", cmd}, UVM_LOW)

        rc = $system(cmd);
        if (rc != 0) begin
            `uvm_fatal("MEM_GEN_SEQ", $sformatf("generate_test_case_complex_mem.py failed, rc=%0d", rc))
        end

        if (!uvm_config_db#(virtual tb_ctrl_if)::get(null, "*", "tb_ctrl_vif", tb_ctrl_vif)) begin
            `uvm_fatal("NOVIF", "Failed to get tb_ctrl_if from uvm_config_db in sequence")
        end
        if (!uvm_config_db#(virtual axil_if)::get(null, "*", "axil_vif", axil_vif)) begin
            `uvm_fatal("NOVIF", "Failed to get axil_if from uvm_config_db in sequence")
        end

        @(posedge tb_ctrl_vif.clk);
        tb_ctrl_vif.mem_reload_req <= 1'b1;
        @(posedge tb_ctrl_vif.clk);
        tb_ctrl_vif.mem_reload_req <= 1'b0;
        repeat(2) @(posedge tb_ctrl_vif.clk);

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
        write_reg(`ADDR_NPU_LHS_BASE,   lhs_addr[31:0]);
        write_reg(`ADDR_NPU_RHS_BASE,   rhs_addr[31:0]);
        write_reg(`ADDR_NPU_BIAS_BASE,  bias_addr[31:0]);
        write_reg(`ADDR_NPU_DST_BASE,   output_base_addr[31:0]);

        write_reg(`ADDR_NPU_K,  cfg_k[31:0]);
        write_reg(`ADDR_NPU_M,  cfg_m[31:0]);
        write_reg(`ADDR_NPU_N,  cfg_n[31:0]);

        write_reg(`ADDR_NPU_LHS_STRIDE_B, lhs_row_stride[31:0]);
        write_reg(`ADDR_NPU_RHS_STRIDE_B, rhs_row_stride[31:0]);
        write_reg(`ADDR_NPU_DST_STRIDE_B, dst_row_stride[31:0]);

        write_reg(`ADDR_NPU_LHS_ZP, lhs_offset[31:0]);
        write_reg(`ADDR_NPU_RHS_ZP, rhs_offset[31:0]);
        write_reg(`ADDR_NPU_DST_ZP, dst_offset[31:0]);
        write_reg(`ADDR_NPU_Q_MULT,   dst_mult[31:0]);
        write_reg(`ADDR_NPU_Q_SHIFT,  dst_shift[31:0]);
        write_reg(`ADDR_NPU_ACT_MIN,    act_min[31:0]);
        write_reg(`ADDR_NPU_ACT_MAX,    act_max[31:0]);
        prepare_host_tiling(cfg_k,cfg_m,gen_dataflow_mode,cfg_quant_mode,
            gen_ia_reuse,gen_w_reuse,host_rg,host_rt,host_cg,host_ct);
        write_reg(`ADDR_NPU_ROW_GROUPS,host_rg);
        write_reg(`ADDR_NPU_ROW_TAIL_TILES,host_rt);
        write_reg(`ADDR_NPU_COL_GROUPS,host_cg);
        write_reg(`ADDR_NPU_COL_TAIL_TILES,host_ct);
        write_reg(`ADDR_NPU_IA_REUSE,   gen_ia_reuse[31:0]);
        write_reg(`ADDR_NPU_W_REUSE,    gen_w_reuse[31:0]);
        write_reg(`ADDR_NPU_DATAFLOW,   gen_dataflow_mode[31:0]);

        // Trigger calc_mult after seq-side mem generation/reload and config programming.
        `uvm_do_with(tr, {
            cmd_kind == NPU_TRIGGER;
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

        irq_wait = 0;
        while ((axil_vif.npu_irq !== 1'b1) && (irq_wait < 200000)) begin
            @(posedge tb_ctrl_vif.clk);
            irq_wait++;
        end
        if (axil_vif.npu_irq !== 1'b1) begin
            `uvm_error("STATUS_WC", $sformatf("Timeout waiting NPU irq before STATUS write-clear, status=0x%08h", axil_vif.npu_status))
        end else begin
            repeat (128) @(posedge tb_ctrl_vif.clk);
            write_reg(`ADDR_NPU_STATUS, 32'h0000_0004);
            repeat (4) @(posedge tb_ctrl_vif.clk);
            if ((axil_vif.npu_irq !== 1'b0) || (axil_vif.npu_status[2] != 1'b0)) begin
                `uvm_error("STATUS_WC", $sformatf("STATUS write-clear failed: irq=%0b status=0x%08h",
                    axil_vif.npu_irq, axil_vif.npu_status))
            end else begin
                `uvm_info("STATUS_WC", "STATUS[2] write-clear verified and irq deasserted", UVM_LOW)
            end
        end

        `uvm_info(get_type_name(), "End ai_mem_gen_smoke_seq", UVM_MEDIUM)
    endtask
endclass

`endif
