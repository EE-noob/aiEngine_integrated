`ifndef AI_ENV_PKG_SV
`define AI_ENV_PKG_SV

package ai_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import UVC packages (仅保留 NICE UVC)
    import ai_nice_pkg::*;

    // Environment that instantiates NICE agent only
    class ai_env extends uvm_env;
        `uvm_component_utils(ai_env)

        ai_nice_agent nice_agent;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            nice_agent = ai_nice_agent::type_id::create("nice_agent", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            uvm_root::get().print_topology();
        endfunction
    endclass

endpackage : ai_env_pkg

`endif
