`ifndef AI_TEST_PKG_SV
`define AI_TEST_PKG_SV

package ai_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import ai_nice_pkg::*;
    import ai_env_pkg::*;

    // Smoke sequence，用于驱动 NICE UVC
    `include "sequence/ai_smoke_nice_seq.sv"
    // Top-level smoke sequence that coordinates all UVCs（此处仅 NICE）
    `include "sequence/ai_smoke_seq.sv"

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
            
            // Ensure nice_agent is valid before assignment (Force Recompile)
            if (env.nice_agent == null) begin
                `uvm_fatal("TEST", "env.nice_agent is null")
            end

            smoke_seq.nice_seqr = env.nice_agent.seqr;

            // Run the top-level smoke sequence; parent 随便选一个 sequencer
            smoke_seq.start(env.nice_agent.seqr);

            `uvm_info(get_type_name(), "ai_smoke_test main_phase end, dropping objection", UVM_MEDIUM)
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
            if (env.nice_agent == null) begin
                `uvm_fatal("TEST", "env.nice_agent is null")
            end
            nice_seq.start(env.nice_agent.seqr);

            `uvm_info(get_type_name(), "smoke_test main_phase end, dropping objection", UVM_MEDIUM)
            #0.1us; // 防止UVM提前退出，给driver/monitor收尾
            phase.drop_objection(this);
        endtask
    endclass

endpackage : ai_test_pkg

`endif
