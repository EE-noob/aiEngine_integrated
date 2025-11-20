`ifndef AI_TEST_PKG_SV
`define AI_TEST_PKG_SV

package ai_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import ai_dcmi_pkg::*;
    import ai_cam_pkg::*;
    import ai_nice_pkg::*;
    import ai_env_pkg::*;

    // Smoke sequences for each interface/agent
    `include "sequence/ai_smoke_dcmi_seq.sv"
    `include "sequence/ai_smoke_cam_seq.sv"
    `include "sequence/ai_smoke_nice_seq.sv"
    // Top-level smoke sequence that coordinates all UVCs
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
            smoke_seq.dcmi_seqr = env.dcmi_agent.seqr;
            smoke_seq.cam_seqr  = env.cam_agent .seqr;
            smoke_seq.nice_seqr = env.nice_agent.seqr;

            // Run the top-level smoke sequence; use dcmi_agent sequencer as parent
            smoke_seq.start(env.dcmi_agent.seqr);

            `uvm_info(get_type_name(), "ai_smoke_test main_phase end, dropping objection", UVM_MEDIUM)
            phase.drop_objection(this);
        endtask
    endclass

endpackage : ai_test_pkg

`endif
