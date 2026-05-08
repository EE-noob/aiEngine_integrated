`ifndef AI_NICE_MONITOR_SV
`define AI_NICE_MONITOR_SV

`include "ai_csr_defines.svh"

class ai_nice_monitor extends uvm_monitor;
    `uvm_component_utils(ai_nice_monitor)

    virtual nice_if vif;
    ai_nice_reg_block regmodel;
    uvm_analysis_port#(ai_nice_seq_item) rsp_ap;
    int unsigned pending_calc_cnt;
    bit prev_calc_tog;
    bit prev_wb_tog;
    bit enable_mem_gen_on_calc_start;
    bit trigger_cfg_valid;
    bit [31:0] last_trigger_cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual nice_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "vif is not set via config DB")
        end
        rsp_ap = new("rsp_ap", this);
        pending_calc_cnt = 0;
        trigger_cfg_valid = 1'b0;
        last_trigger_cfg = 32'h0;
        enable_mem_gen_on_calc_start = 1'b0;
        void'(uvm_config_db#(bit)::get(this, "", "enable_mem_gen_on_calc_start", enable_mem_gen_on_calc_start));
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

    function automatic int unsigned get_reg_mirror(ai_nice_csr_reg rg, string name);
        uvm_reg_data_t value;
        if (rg == null) begin
            `uvm_fatal(get_type_name(), $sformatf("regmodel.%s is null", name))
        end
        value = rg.get_mirrored_value();
        return int'(value[31:0]);
    endfunction

    function automatic bit is_mat_mult_req();
        bit [31:0] inst;
        inst = vif.mon_cb.nice_req_inst;
        return (vif.mon_cb.nice_req_valid &&
                vif.mon_cb.nice_req_ready &&
                (inst[6:0] == `NICE_CUSTOM_1) &&
                (inst[14:12] == `NICE_FUNCT3) &&
                (inst[31:25] == `NICE_MAT_MULT_FUNCT7));
    endfunction

    task automatic generate_mem_from_ral_mirror();
        string utn_name;
        string cmd;
        string fix_mode_arg;
        int rc;
        int gen_k;
        int gen_n;
        int gen_m;
        int gen_lhs_dtype;
        int gen_quant_mode;
        int gen_fix_mode;
        int gen_seed;

        if (regmodel == null) begin
            `uvm_fatal(get_type_name(), "regmodel is null, cannot generate memory from RAL mirror")
        end

        gen_k = get_reg_mirror(regmodel.mult_lhs_rows, "mult_lhs_rows");
        gen_n = get_reg_mirror(regmodel.mult_rhs_cols, "mult_rhs_cols");
        gen_m = get_reg_mirror(regmodel.mult_rhs_rows, "mult_rhs_rows");
        if ((gen_k <= 0) || (gen_n <= 0) || (gen_m <= 0)) begin
            `uvm_fatal(get_type_name(), $sformatf("Invalid mirrored K/N/M: K=%0d N=%0d M=%0d", gen_k, gen_n, gen_m))
        end

        if (trigger_cfg_valid) begin
            gen_lhs_dtype  = (last_trigger_cfg[8:7] == 2) ? 2 : 1;
            gen_quant_mode = last_trigger_cfg[9];
        end else begin
            int lhs_stride;
            lhs_stride = get_reg_mirror(regmodel.mult_lhs_stride, "mult_lhs_stride");
            gen_lhs_dtype = (lhs_stride == (gen_n * 2)) ? 2 : 1;
            gen_quant_mode = 0;
        end

        gen_fix_mode = 1;
        gen_seed = 1;
        void'($value$plusargs("RAL_MEM_GEN_FIX_MODE=%d", gen_fix_mode));
        void'($value$plusargs("RAL_MEM_GEN_SEED=%d", gen_seed));

        utn_name = get_case_name();
        fix_mode_arg = (gen_fix_mode != 0) ? "--fix_mode" : "";
        cmd = $sformatf(
            "cd ../tb && python ./generate_test_case_complex_mem.py --K %0d --N %0d --M %0d --lhs_dtype %0d %s --quant_mode %0d --seed %0d --out_dir ./%s",
            gen_k, gen_n, gen_m, gen_lhs_dtype, fix_mode_arg, gen_quant_mode, gen_seed, utn_name
        );
        `uvm_info("MEM_GEN_MON", {"Run: ", cmd}, UVM_LOW)

        rc = $system(cmd);
        if (rc != 0) begin
            `uvm_fatal("MEM_GEN_MON", $sformatf("generate_test_case_complex_mem.py failed, rc=%0d", rc))
        end

        @(posedge vif.nice_clk);
        vif.mem_reload_req <= 1'b1;
        @(posedge vif.nice_clk);
        vif.mem_reload_req <= 1'b0;
        `uvm_info("MEM_GEN_MON", "main_extram.mem regenerated and mem_reload_req pulsed on calc_start", UVM_LOW)
    endtask

    task automatic wait_rsp_and_trigger_scb(uvm_phase phase);
        ai_nice_seq_item tr;
        bit [31:0] status;

        while (vif.mon_cb.nice_rsp_valid !== 1'b1) begin
            @(vif.mon_cb);
        end

        status = vif.mon_cb.nice_rsp_rdat;
        if (vif.mon_cb.nice_rsp_err) begin
            `uvm_error(get_type_name(), $sformatf("nice_rsp_valid with nice_rsp_err=1, status=0x%08h", status))
        end else begin
            case (status[1:0])
                2'b00: begin
                    `uvm_info(get_type_name(), $sformatf("nice_rsp_valid normal response, status=0x%08h", status), UVM_LOW)
                    tr = ai_nice_seq_item::type_id::create("mon_rsp_tr", this);
                    tr.cmd_kind = NICE_TRIGGER;
                    tr.csr_data = status;
                    rsp_ap.write(tr);
                end
                2'b01: `uvm_error(get_type_name(), $sformatf("nice_rsp_valid err=01(config error), status=0x%08h", status))
                2'b10: `uvm_error(get_type_name(), $sformatf("nice_rsp_valid err=10(resource missing), status=0x%08h", status))
                default: `uvm_error(get_type_name(), $sformatf("nice_rsp_valid err=%b(unknown), status=0x%08h", status[1:0], status))
            endcase
        end

        if (pending_calc_cnt > 0) begin
            pending_calc_cnt--;
            phase.drop_objection(this, "nice_rsp_valid completed");
        end
    endtask

    virtual task run_phase(uvm_phase phase);
        wait (vif.nice_rst_n == 1'b1);
        prev_calc_tog = vif.mon_cb.mma_calc_start_toggle;
        prev_wb_tog = vif.mon_cb.mma_wb_handshake_toggle;

        forever begin
            @(vif.mon_cb);

            if (is_mat_mult_req()) begin
                last_trigger_cfg = vif.mon_cb.nice_req_rs2;
                trigger_cfg_valid = 1'b1;
                `uvm_info(get_type_name(), $sformatf("mat_mult trigger cfg captured: 0x%08h", last_trigger_cfg), UVM_LOW)
            end

            if (vif.mon_cb.mma_calc_start_toggle != prev_calc_tog) begin
                prev_calc_tog = vif.mon_cb.mma_calc_start_toggle;
                pending_calc_cnt++;
                phase.raise_objection(this, "wait wb_valid&&wb_ready handshake");
                `uvm_info(get_type_name(), $sformatf("calc_start detected, pending=%0d", pending_calc_cnt), UVM_LOW)
                if (enable_mem_gen_on_calc_start) begin
                    generate_mem_from_ral_mirror();
                end
                wait_rsp_and_trigger_scb(phase);
            end

            if (vif.mon_cb.mma_wb_handshake_toggle != prev_wb_tog) begin
                prev_wb_tog = vif.mon_cb.mma_wb_handshake_toggle;
                case (vif.mon_cb.mma_err_code)
                    2'b00: `uvm_info(get_type_name(), "wb handshake detected, err_code=00(normal)", UVM_LOW)
                    2'b01: `uvm_error(get_type_name(), "wb handshake detected, err_code=01(config error)")
                    2'b10: `uvm_error(get_type_name(), "wb handshake detected, err_code=10(resource missing)")
                    default: `uvm_error(get_type_name(), $sformatf("wb handshake detected, err_code=%b(unknown)", vif.mon_cb.mma_err_code))
                endcase
            end
        end
    endtask
endclass

`endif
