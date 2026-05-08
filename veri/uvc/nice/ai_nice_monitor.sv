`ifndef AI_NICE_MONITOR_SV
`define AI_NICE_MONITOR_SV

class ai_nice_monitor extends uvm_monitor;
    `uvm_component_utils(ai_nice_monitor)

    virtual nice_if vif;
    uvm_analysis_port#(ai_nice_seq_item) rsp_ap;
    int unsigned pending_calc_cnt;
    bit prev_calc_tog;
    bit prev_wb_tog;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual nice_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "vif is not set via config DB")
        end
        rsp_ap = new("rsp_ap", this);
        pending_calc_cnt = 0;
    endfunction

    virtual task run_phase(uvm_phase phase);
        ai_nice_seq_item tr;
        wait (vif.nice_rst_n == 1'b1);
        prev_calc_tog = vif.mon_cb.mma_calc_start_toggle;
        prev_wb_tog = vif.mon_cb.mma_wb_handshake_toggle;

        forever begin
            @(vif.mon_cb);

            if (vif.mon_cb.mma_calc_start_toggle != prev_calc_tog) begin
                prev_calc_tog = vif.mon_cb.mma_calc_start_toggle;
                pending_calc_cnt++;
                phase.raise_objection(this, "wait wb_valid&&wb_ready handshake");
                `uvm_info(get_type_name(), $sformatf("calc_start detected, pending=%0d", pending_calc_cnt), UVM_LOW)
            end

            // if (vif.mon_cb.mma_wb_handshake_toggle != prev_wb_tog) begin
            //     prev_wb_tog = vif.mon_cb.mma_wb_handshake_toggle;

            //     case (vif.mon_cb.mma_err_code)
            //         2'b00: begin
            //             `uvm_info(get_type_name(), "wb握手成功, err_code=00(正常), 启动矩阵比对", UVM_LOW)
            //             tr = ai_nice_seq_item::type_id::create("mon_rsp_tr", this);
            //             tr.cmd_kind = NICE_TRIGGER;
            //             tr.csr_data = {30'b0, vif.mon_cb.mma_err_code};
            //             rsp_ap.write(tr);
            //         end
            //         2'b01: `uvm_error(get_type_name(), "wb握手成功, err_code=01(配置错误), 不启动矩阵比对")
            //         2'b10: `uvm_error(get_type_name(), "wb握手成功, err_code=10(资源缺失), 不启动矩阵比对")
            //         default: `uvm_error(get_type_name(), $sformatf("wb握手成功, err_code=%b(未知), 不启动矩阵比对", vif.mon_cb.mma_err_code))
            //     endcase

            //     if (pending_calc_cnt > 0) begin
            //         pending_calc_cnt--;
            //         phase.drop_objection(this, "wb handshake completed");
            //     end
            // end
        end
    endtask
endclass

`endif
