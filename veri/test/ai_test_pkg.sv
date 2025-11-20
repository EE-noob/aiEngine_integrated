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
            ai_smoke_dcmi_seq dcmi_seq;
            ai_smoke_cam_seq  cam_seq;
            ai_smoke_nice_seq nice_seq;

            phase.raise_objection(this);
            `uvm_info(get_type_name(), "ai_smoke_test main_phase start", UVM_MEDIUM)

            dcmi_seq = ai_smoke_dcmi_seq::type_id::create("dcmi_seq");
            cam_seq  = ai_smoke_cam_seq ::type_id::create("cam_seq");
            nice_seq = ai_smoke_nice_seq::type_id::create("nice_seq");

            fork
                dcmi_seq.start(env.dcmi_agent.seqr);
                cam_seq .start(env.cam_agent .seqr);
                nice_seq.start(env.nice_agent.seqr);
            join

            `uvm_info(get_type_name(), "ai_smoke_test main_phase end, dropping objection", UVM_MEDIUM)
            phase.drop_objection(this);
        endtask
    endclass

endpackage : ai_test_pkg

`endif
