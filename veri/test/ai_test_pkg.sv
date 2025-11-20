`ifndef AI_TEST_PKG_SV
`define AI_TEST_PKG_SV

package ai_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import ai_dcmi_pkg::*;
    import ai_cam_pkg::*;
    import ai_nice_pkg::*;
    import ai_env_pkg::*;

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
            ai_dcmi_sequence dcmi_seq;
            ai_cam_sequence  cam_seq;
            ai_nice_sequence nice_seq;

            phase.raise_objection(this);

            dcmi_seq = ai_dcmi_sequence::type_id::create("dcmi_seq");
            cam_seq  = ai_cam_sequence ::type_id::create("cam_seq");
            nice_seq = ai_nice_sequence::type_id::create("nice_seq");

            fork
                dcmi_seq.start(env.dcmi_agent.seqr);
                cam_seq .start(env.cam_agent .seqr);
                nice_seq.start(env.nice_agent.seqr);
            join

            phase.drop_objection(this);
        endtask
    endclass

endpackage : ai_test_pkg

`endif
