`ifndef AI_ENV_PKG_SV
`define AI_ENV_PKG_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

typedef enum int { AI_DUT_NICE = 0, AI_DUT_AXIL = 1, AI_DUT_AXI_SOC = 2 } ai_dut_kind_e;

class ai_env_cfg extends uvm_object;
    `uvm_object_utils(ai_env_cfg)

    ai_dut_kind_e dut_kind = AI_DUT_NICE;

    function new(string name = "ai_env_cfg");
        super.new(name);
    endfunction
endclass

class ai_env extends uvm_env;
    `uvm_component_utils(ai_env)

    ai_env_cfg          cfg;
    ai_nice_agent       nice_agent;
    ai_axil_agent       axil_agent;
    mma_scoreboard     mma_scb;
    mma_reg_block      regmodel;
    mma_reg_adapter    reg_adapter;
    mma_sequencer      active_seqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ai_env_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = ai_env_cfg::type_id::create("cfg");
            cfg.dut_kind = AI_DUT_NICE;
        end

        regmodel   = mma_reg_block::type_id::create("regmodel", this);
        reg_adapter = mma_reg_adapter::type_id::create("reg_adapter");
        regmodel.build();
        regmodel.reset();

        mma_scb = mma_scoreboard::type_id::create("mma_scb", this);

        if (cfg.dut_kind == AI_DUT_NICE) begin
            nice_agent = ai_nice_agent::type_id::create("nice_agent", this);
        end else if (cfg.dut_kind == AI_DUT_AXIL) begin
            axil_agent = ai_axil_agent::type_id::create("axil_agent", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (cfg.dut_kind == AI_DUT_NICE) begin
            nice_agent.req_ap.connect(mma_scb.analysis_req_imp);
            nice_agent.rsp_ap.connect(mma_scb.analysis_rsp_imp);
            mma_scb.regmodel = regmodel;
            nice_agent.monitor.regmodel = regmodel;
            regmodel.default_map.set_sequencer(nice_agent.seqr, reg_adapter);
            regmodel.default_map.set_auto_predict(1);
            active_seqr = nice_agent.seqr;
        end else if (cfg.dut_kind == AI_DUT_AXIL) begin
            axil_agent.req_ap.connect(mma_scb.analysis_req_imp);
            axil_agent.rsp_ap.connect(mma_scb.analysis_rsp_imp);
            mma_scb.regmodel = regmodel;
            axil_agent.monitor.regmodel = regmodel;
            regmodel.default_map.set_sequencer(axil_agent.seqr, reg_adapter);
            regmodel.default_map.set_auto_predict(1);
            active_seqr = axil_agent.seqr;
        end else begin
            mma_scb.regmodel = regmodel;
            active_seqr = null;
        end
    endfunction
endclass

`endif
