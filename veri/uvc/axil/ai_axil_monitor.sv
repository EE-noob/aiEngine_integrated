`ifndef AI_AXIL_MONITOR_SV
`define AI_AXIL_MONITOR_SV

`include "mma_csr_defines.svh"

class ai_axil_monitor extends uvm_monitor;
    `uvm_component_utils(ai_axil_monitor)

    virtual axil_if axil_vif;
    virtual nice_if nice_vif;
    mma_reg_block regmodel;
    uvm_analysis_port#(mma_seq_item) rsp_ap;

    bit enable_mem_gen_on_calc_start;
    bit prev_calc_tog;
    bit trigger_cfg_valid;
    bit [31:0] last_trigger_cfg;
    bit [15:0] awaddr_q[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axil_if)::get(this, "", "axil_vif", axil_vif)) begin
            `uvm_fatal(get_type_name(), "axil_vif is not set via config DB")
        end
        if (!uvm_config_db#(virtual nice_if)::get(this, "", "vif", nice_vif)) begin
            `uvm_fatal(get_type_name(), "nice vif is not set via config DB")
        end
        rsp_ap = new("rsp_ap", this);
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

    function automatic int unsigned get_reg_mirror(mma_csr_reg rg, string name);
        uvm_reg_data_t value;
        if (rg == null) begin
            `uvm_fatal(get_type_name(), $sformatf("regmodel.%s is null", name))
        end
        value = rg.get_mirrored_value();
        return int'(value[31:0]);
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
        `uvm_info("AXIL_MEM_GEN_MON", {"Run: ", cmd}, UVM_LOW)

        rc = $system(cmd);
        if (rc != 0) begin
            `uvm_fatal("AXIL_MEM_GEN_MON", $sformatf("generate_test_case_complex_mem.py failed, rc=%0d", rc))
        end

        @(posedge nice_vif.nice_clk);
        nice_vif.mem_reload_req <= 1'b1;
        @(posedge nice_vif.nice_clk);
        nice_vif.mem_reload_req <= 1'b0;
        `uvm_info("AXIL_MEM_GEN_MON", "main_extram.mem regenerated and mem_reload_req pulsed on calc_start", UVM_LOW)
    endtask

    task automatic wait_irq_and_trigger_scb();
        mma_seq_item tr;
        bit [31:0] status;
        int timeout;
        int timeout_max;
        int poll_cnt;

        timeout_max = 500_000_000;
        void'($value$plusargs("AXIL_DONE_TIMEOUT=%d", timeout_max));
        timeout = timeout_max;
        poll_cnt = 0;

        while ((timeout > 0) && (axil_vif.mon_cb.mma_irq[2] !== 1'b1)) begin
            @(axil_vif.mon_cb);
            timeout--;
            poll_cnt++;
            if ((poll_cnt % 10000) == 0) begin
                `uvm_info("AXIL_WAIT", $sformatf("Waiting MMA irq[2]... polls=%0d/%0d irq=0x%08h status=0x%08h",
                    poll_cnt, timeout_max, axil_vif.mon_cb.mma_irq, axil_vif.mon_cb.mma_status), UVM_LOW)
            end
        end

        status = axil_vif.mon_cb.mma_status;
        if (axil_vif.mon_cb.mma_irq[2] !== 1'b1) begin
            `uvm_error("AXIL_TIMEOUT", $sformatf("Timeout waiting MMA irq[2]; polls=%0d status=0x%08h", poll_cnt, status))
            return;
        end

        if (!status[2]) begin
            `uvm_error("AXIL_DONE", $sformatf("irq[2] asserted but REG_STATUS[2] is low, status=0x%08h", status))
            return;
        end

        case (status[5:4])
            2'b00: begin
                `uvm_info("AXIL_DONE", $sformatf("MMA done by irq[2] after %0d polls, status=0x%08h err=00", poll_cnt, status), UVM_LOW)
                tr = mma_seq_item::type_id::create("axil_mon_rsp_tr", this);
                tr.cmd_kind = MMA_TRIGGER;
                tr.csr_data = status;
                rsp_ap.write(tr);
            end
            2'b01: `uvm_error("AXIL_DONE", $sformatf("MMA done but err=01(config error), status=0x%08h", status))
            2'b10: `uvm_error("AXIL_DONE", $sformatf("MMA done but err=10(resource missing), status=0x%08h", status))
            default: `uvm_error("AXIL_DONE", $sformatf("MMA done but err=%b(unknown), status=0x%08h", status[5:4], status))
        endcase
    endtask

    function automatic void sample_ctrl_write();
        bit [15:0] addr;

        if (axil_vif.mon_cb.awvalid && axil_vif.mon_cb.awready) begin
            awaddr_q.push_back(axil_vif.mon_cb.awaddr);
        end

        if (axil_vif.mon_cb.wvalid && axil_vif.mon_cb.wready && (awaddr_q.size() > 0)) begin
            addr = awaddr_q.pop_front();
            if (addr == {`ADDR_AXIL_REG_CTRL, 2'b00}) begin
                last_trigger_cfg = 32'h0;
                last_trigger_cfg[9] = axil_vif.mon_cb.wdata[2];
                last_trigger_cfg[8:7] = axil_vif.mon_cb.wdata[1] ? 2 : 1;
                trigger_cfg_valid = axil_vif.mon_cb.wdata[0];
                if (axil_vif.mon_cb.wdata[0]) begin
                    `uvm_info(get_type_name(), $sformatf("AXIL CTRL start captured: wdata=0x%08h trigger_cfg=0x%08h",
                        axil_vif.mon_cb.wdata, last_trigger_cfg), UVM_LOW)
                end
            end
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        wait (nice_vif.nice_rst_n == 1'b1);
        prev_calc_tog = nice_vif.mon_cb.mma_calc_start_toggle;

        forever begin
            @(axil_vif.mon_cb);
            sample_ctrl_write();

            if (nice_vif.mon_cb.mma_calc_start_toggle != prev_calc_tog) begin
                prev_calc_tog = nice_vif.mon_cb.mma_calc_start_toggle;
                phase.raise_objection(this, "wait AXIL irq[2]");
                `uvm_info(get_type_name(), "calc_start detected in AXIL monitor", UVM_LOW)
                if (enable_mem_gen_on_calc_start) begin
                    generate_mem_from_ral_mirror();
                end
                wait_irq_and_trigger_scb();
                phase.drop_objection(this, "AXIL irq[2] completed");
            end
        end
    endtask
endclass

`endif
