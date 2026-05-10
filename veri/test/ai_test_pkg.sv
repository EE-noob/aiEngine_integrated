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
`include "sequence/ai_ral_mem_gen_on_calc_start_seq.sv"

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

class ai_axi_soc_c_test extends ai_base_test;
    `uvm_component_utils(ai_axi_soc_c_test)

    function new(string name = "ai_axi_soc_c_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task automatic parse_soc_config(
        input string cfg_path,
        output int output_base_addr,
        output int expected_dst_size
    );
        integer fd;
        string line;
        int tmp;

        output_base_addr = 0;
        expected_dst_size = 0;

        fd = $fopen(cfg_path, "r");
        if (fd == 0) begin
            `uvm_fatal("SOC_CFG", $sformatf("Cannot open %s", cfg_path))
        end

        while (!$feof(fd)) begin
            void'($fgets(line, fd));
            if ($sscanf(line, "output_base_addr = %d", tmp) == 1) output_base_addr = tmp;
            else if ($sscanf(line, "expected_dst_size = %d", tmp) == 1) expected_dst_size = tmp;
        end
        $fclose(fd);

        if (expected_dst_size <= 0) begin
            `uvm_fatal("SOC_CFG", $sformatf("Invalid expected_dst_size=%0d from %s", expected_dst_size, cfg_path))
        end
    endtask

    task automatic check_soc_output(
        input string expected_path,
        input int output_base_addr,
        input int expected_dst_size
    );
`ifdef DUT_AXI_SOC
        integer fd;
        integer ret;
        int byte_idx;
        int word_addr;
        int lane;
        int mismatch_cnt;
        reg [31:0] exp_word;
        reg [31:0] act_word;
        reg [7:0] exp_byte;
        reg [7:0] act_byte;

        fd = $fopen(expected_path, "r");
        if (fd == 0) begin
            `uvm_fatal("SOC_CHK", $sformatf("Cannot open %s", expected_path))
        end

        mismatch_cnt = 0;
        exp_word = 32'h0;

        for (byte_idx = 0; byte_idx < expected_dst_size; byte_idx = byte_idx + 1) begin
            if ((byte_idx % 4) == 0) begin
                ret = $fscanf(fd, "%h\n", exp_word);
                if (ret != 1) begin
                    `uvm_fatal("SOC_CHK", $sformatf("Cannot parse expected word at byte %0d from %s", byte_idx, expected_path))
                end
            end

            word_addr = (output_base_addr + byte_idx) >> 2;
            lane = (output_base_addr + byte_idx) & 32'h3;
            act_word = $root.tb_top.u_soc_top.u_axil_top_with_ram.u_axi_sim_ram.mem_r[word_addr];
            exp_byte = exp_word[((byte_idx & 3) * 8) +: 8];
            act_byte = act_word[(lane * 8) +: 8];

            if (act_byte !== exp_byte) begin
                mismatch_cnt++;
                if (mismatch_cnt <= 16) begin
                    `uvm_error("SOC_CHK", $sformatf("Mismatch byte[%0d] mem_byte_addr=0x%08h exp=0x%02h act=0x%02h",
                        byte_idx, output_base_addr + byte_idx, exp_byte, act_byte))
                end
            end
        end

        $fclose(fd);

        if (mismatch_cnt != 0) begin
            `uvm_error("SOC_CHK", $sformatf("AXI SoC output mismatches: %0d bytes", mismatch_cnt))
        end else begin
            `uvm_info("SOC_CHK", $sformatf("AXI SoC output matched %0d bytes at base 0x%08h",
                expected_dst_size, output_base_addr), UVM_LOW)
        end
`else
        `uvm_fatal("SOC_CHK", "ai_axi_soc_c_test must run with DUT_MODE=axi_soc")
`endif
    endtask

    virtual task main_phase(uvm_phase phase);
        string soc_case_dir;
        string cfg_path;
        string expected_path;
        int output_base_addr;
        int expected_dst_size;
        int timeout_cycles;
        int cycles;

        phase.raise_objection(this);

        if (!$value$plusargs("SOC_CASE_DIR=%s", soc_case_dir)) begin
            soc_case_dir = "../tb/axi_soc_case";
        end
        if (!$value$plusargs("SOC_TIMEOUT_CYCLES=%d", timeout_cycles)) begin
            timeout_cycles = 2000000;
        end

        cfg_path = {soc_case_dir, "/config.txt"};
        expected_path = {soc_case_dir, "/expected.mem"};
        parse_soc_config(cfg_path, output_base_addr, expected_dst_size);

`ifdef DUT_AXI_SOC
        `uvm_info(get_type_name(), $sformatf("Waiting for PicoRV32 C test finish, timeout=%0d cycles", timeout_cycles), UVM_LOW)
        cycles = 0;
        while (!$root.tb_top.soc_finish && (cycles < timeout_cycles)) begin
            @(posedge $root.tb_top.nice_clk);
            cycles++;
        end

        if (!$root.tb_top.soc_finish) begin
            `uvm_error("SOC_TEST", $sformatf("Timeout waiting for soc_finish after %0d cycles", cycles))
        end else begin
            `uvm_info("SOC_TEST", $sformatf("soc_finish asserted after %0d cycles, soc_status=0x%08h cpu_trap=%0b",
                cycles, $root.tb_top.soc_status, $root.tb_top.cpu_trap), UVM_LOW)
        end

        if ($root.tb_top.cpu_trap) begin
            `uvm_error("SOC_TEST", "PicoRV32 cpu_trap asserted")
        end

        if ($root.tb_top.soc_status !== 32'h1) begin
            `uvm_error("SOC_TEST", $sformatf("C program reported failure status=0x%08h", $root.tb_top.soc_status))
        end

        check_soc_output(expected_path, output_base_addr, expected_dst_size);
`else
        `uvm_fatal("SOC_TEST", "ai_axi_soc_c_test must run with DUT_MODE=axi_soc")
`endif

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

    mma_coverage cov;

    function new(string name = "ai_coverage_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cov = mma_coverage::type_id::create("cov", this);
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

class ai_ral_mem_gen_on_calc_start_test extends ai_base_test;
    `uvm_component_utils(ai_ral_mem_gen_on_calc_start_test)

    function new(string name = "ai_ral_mem_gen_on_calc_start_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        uvm_config_db#(bit)::set(this, "env.nice_agent.monitor", "enable_mem_gen_on_calc_start", 1'b1);
        uvm_config_db#(bit)::set(this, "env.axil_agent.monitor", "enable_mem_gen_on_calc_start", 1'b1);
        super.build_phase(phase);
    endfunction

    virtual task main_phase(uvm_phase phase);
        ai_ral_mem_gen_on_calc_start_seq ral_mem_seq;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), "ai_ral_mem_gen_on_calc_start_test main_phase start", UVM_MEDIUM)

        if ((env == null) || (env.active_seqr == null) || (env.regmodel == null)) begin
            `uvm_fatal("TEST", "env/active_seqr/regmodel is null")
        end

        ral_mem_seq = ai_ral_mem_gen_on_calc_start_seq::type_id::create("ral_mem_seq");
        ral_mem_seq.regmodel = env.regmodel;

        #1000ns;
        ral_mem_seq.start(env.active_seqr);

        `uvm_info(get_type_name(), "ai_ral_mem_gen_on_calc_start_test main_phase end", UVM_MEDIUM)
        #20us;
        phase.drop_objection(this);
    endtask
endclass

`endif
