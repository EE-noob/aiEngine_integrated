`ifndef AI_ENV_PKG_SV
`define AI_ENV_PKG_SV

package ai_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import UVC packages
    import ai_dcmi_pkg::*;
    import ai_cam_pkg::*;
    import ai_nice_pkg::*;

    // Environment that instantiates all agents
    class ai_env extends uvm_env;
        `uvm_component_utils(ai_env)

        ai_dcmi_agent dcmi_agent;
        ai_cam_agent  cam_agent;
        ai_nice_agent nice_agent;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            dcmi_agent = ai_dcmi_agent::type_id::create("dcmi_agent", this);
            cam_agent  = ai_cam_agent ::type_id::create("cam_agent" , this);
            nice_agent = ai_nice_agent::type_id::create("nice_agent", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            uvm_root::get().print_topology();
        endfunction
    endclass

endpackage : ai_env_pkg

`endif

