`ifndef AI_TEST_PKG_SV
`define AI_TEST_PKG_SV

// NOTE: de-packaged mode.
import uvm_pkg::*;
`include "uvm_macros.svh"

`include "sequence/ai_smoke_nice_seq.sv"
`include "sequence/ai_smoke_seq.sv"
`include "sequence/ai_nice_cov_seq.sv"
`include "sequence/ai_nice_ral_csr_wr_check_seq.sv"
`include "sequence/ai_mem_gen_smoke_seq.sv"

class ai_base_test extends uvm_test;
    `uvm_component_utils(ai_base_test)

    ai_env env;

    function new(string name = "ai_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = ai_env::type_id::create("env", this);
    endfunction

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int unsigned error_cnt;
        int unsigned fatal_cnt;

        super.report_phase(phase);

        svr = uvm_report_server::get_server();
        error_cnt = svr.get_severity_count(UVM_ERROR);
        fatal_cnt = svr.get_severity_count(UVM_FATAL);

        if ((error_cnt == 0) && (fatal_cnt == 0)) begin
            print_big_pass();
            `uvm_info("TEST_RESULT", "TEST PASS: no UVM_ERROR or UVM_FATAL reported", UVM_NONE)
        end else begin
            print_big_fail();
            `uvm_info("TEST_RESULT", $sformatf("TEST FAIL: UVM_ERROR=%0d UVM_FATAL=%0d", error_cnt, fatal_cnt), UVM_NONE)
        end
    endfunction

    virtual function void print_big_pass();
        $display("\033[32mPPPPPPPPPPPP   AAAAAAAA    SSSSSSSSSS   SSSSSSSSSS\033[0m");
        $display("\033[32mPPPPPPPPPPPP  AAAAAAAAAA  SSSSSSSSSSSS SSSSSSSSSSSS\033[0m");
        $display("\033[32mPPPP    PPPP AA      AA  SSSS         SSSS        \033[0m");
        $display("\033[32mPPPPPPPPPPPP AAAAAAAAAAAA  SSSSSSSSSS   SSSSSSSSSS  \033[0m");
        $display("\033[32mPPPP        PP          PP         SSSS         SSSS\033[0m");
        $display("\033[32mPPPP        PP          PP SSSSSSSSSSSS SSSSSSSSSSSS\033[0m");
        $display("\033[32mPPPP        PP          PP  SSSSSSSSSS   SSSSSSSSSS \033[0m");
    endfunction

    virtual function void print_big_fail();
        $display("\033[31mFFFFFFFFFFFFF    AAAAAAAA    IIIIIIIIII  LL          \033[0m");
        $display("\033[31mFFFFFFFFFFFFF   AAAAAAAAAA   IIIIIIIIII  LL          \033[0m");
        $display("\033[31mFFFF           AA      AA       II      LL          \033[0m");
        $display("\033[31mFFFFFFFFFFF   AAAAAAAAAAAA      II      LL          \033[0m");
        $display("\033[31mFFFF          AA          AA      II      LL          \033[0m");
        $display("\033[31mFFFF          AA          AA   IIIIIIIIII LLLLLLLLLLL \033[0m");
        $display("\033[31mFFFF          AA          AA   IIIIIIIIII LLLLLLLLLLL \033[0m");
    endfunction
endclass

class ai_smoke_test extends ai_base_test;
    `uvm_component_utils(ai_smoke_test)

    function new(string name = "ai_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task main_phase(uvm_phase phase);
        ai_smoke_seq smoke_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "ai_smoke_test main_phase start", UVM_MEDIUM)

        smoke_seq = ai_smoke_seq::type_id::create("smoke_seq");

        if (env.active_seqr == null) begin
            `uvm_fatal("TEST", "env.active_seqr is null")
        end

        smoke_seq.nice_seqr = env.active_seqr;

        #100;
        smoke_seq.start(env.active_seqr);

        `uvm_info(get_type_name(), "ai_smoke_test main_phase end, dropping objection", UVM_MEDIUM)
        #100us;
        phase.drop_objection(this);
    endtask
endclass

class smoke_test extends ai_base_test;
    `uvm_component_utils(smoke_test)

    function new(string name = "smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task main_phase(uvm_phase phase);
        ai_smoke_nice_seq nice_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "smoke_test main_phase start", UVM_MEDIUM)

        nice_seq = ai_smoke_nice_seq::type_id::create("nice_seq");
        if (env.active_seqr == null) begin
            `uvm_fatal("TEST", "env.active_seqr is null")
        end

        #1000ns;
        nice_seq.start(env.active_seqr);

        `uvm_info(get_type_name(), "smoke_test main_phase end, dropping objection", UVM_MEDIUM)
        #10us;
        phase.drop_objection(this);
    endtask
endclass

class ai_coverage_test extends ai_base_test;
    `uvm_component_utils(ai_coverage_test)

    ai_nice_coverage cov;

    function new(string name = "ai_coverage_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cov = ai_nice_coverage::type_id::create("cov", this);
    endfunction

    virtual task main_phase(uvm_phase phase);
        ai_nice_cov_seq cov_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "ai_coverage_test main_phase start", UVM_MEDIUM)

        cov_seq = ai_nice_cov_seq::type_id::create("cov_seq");
        cov_seq.cov = this.cov;

        if (env.nice_agent != null) begin
            cov_seq.start(env.active_seqr);
        end else begin
            cov_seq.start(null);
        end

        `uvm_info(get_type_name(), "ai_coverage_test main_phase end", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask
endclass

class ai_nice_ral_csr_wr_check_test extends ai_base_test;
    `uvm_component_utils(ai_nice_ral_csr_wr_check_test)

    function new(string name = "ai_nice_ral_csr_wr_check_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task main_phase(uvm_phase phase);
        ai_nice_ral_csr_wr_check_seq ral_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "ai_nice_ral_csr_wr_check_test main_phase start", UVM_MEDIUM)

        ral_seq = ai_nice_ral_csr_wr_check_seq::type_id::create("ral_seq");

        if ((env == null) || (env.active_seqr == null) || (env.regmodel == null)) begin
            `uvm_fatal("TEST", "env/active_seqr/regmodel is null")
        end

        ral_seq.regmodel = env.regmodel;

        #1000ns;
        ral_seq.start(env.active_seqr);

        `uvm_info(get_type_name(), "ai_nice_ral_csr_wr_check_test main_phase end", UVM_MEDIUM)
        #2us;
        phase.drop_objection(this);
    endtask
endclass

class ai_mem_gen_smoke_test extends ai_base_test;
    `uvm_component_utils(ai_mem_gen_smoke_test)

    function new(string name = "ai_mem_gen_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task main_phase(uvm_phase phase);
        ai_mem_gen_smoke_seq mem_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "ai_mem_gen_smoke_test main_phase start", UVM_MEDIUM)

        if ((env == null) || (env.active_seqr == null)) begin
            `uvm_fatal("TEST", "env/active_seqr is null")
        end

        mem_seq = ai_mem_gen_smoke_seq::type_id::create("mem_seq");
        #1000ns;
        mem_seq.start(env.active_seqr);

        `uvm_info(get_type_name(), "ai_mem_gen_smoke_test main_phase end", UVM_MEDIUM)
        #20us;
        phase.drop_objection(this);
    endtask
endclass

`endif
