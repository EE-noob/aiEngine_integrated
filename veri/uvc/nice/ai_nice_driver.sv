`ifndef AI_NICE_DRIVER_SV
`define AI_NICE_DRIVER_SV

class ai_nice_driver extends uvm_driver#(ai_nice_seq_item);
    `uvm_component_utils(ai_nice_driver)

    virtual nice_if vif;
    int unsigned wait_cycles;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual nice_if)::get(this, "", "nice_vif", vif)) begin
            `uvm_fatal(get_type_name(), "nice_vif is not set via config DB")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        ai_nice_seq_item req;

        // Default outputs
        vif.drv_cb.nice_req_valid <= 1'b0;
        vif.drv_cb.nice_req_inst  <= '0;
        vif.drv_cb.nice_req_rs1   <= '0;
        vif.drv_cb.nice_req_rs2   <= '0;
        vif.drv_cb.nice_rsp_ready <= 1'b1;

        // Wait reset release
        wait (vif.nice_rst_n == 1'b1);

        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_item(ai_nice_seq_item tr);
        // Drive request
        vif.drv_cb.nice_req_inst  <= tr.inst;
        vif.drv_cb.nice_req_rs1   <= tr.rs1;
        vif.drv_cb.nice_req_rs2   <= tr.rs2;

        vif.drv_cb.nice_req_valid <= 1'b1;
        // Wait for DUT to accept, but timeout to avoid deadlock
        wait_cycles = 0;
        do begin
            @(vif.drv_cb);
            wait_cycles++;
        end while (!vif.drv_cb.nice_req_ready && wait_cycles < 1000);
        vif.drv_cb.nice_req_valid <= 1'b0;

        // Wait for response
        wait_cycles = 0;
        do begin
            @(vif.drv_cb);
            wait_cycles++;
        end while (!vif.drv_cb.nice_rsp_valid && wait_cycles < 2000);

        if (vif.drv_cb.nice_rsp_valid) begin
            tr.rsp_rdat = vif.drv_cb.nice_rsp_rdat;
            tr.rsp_err  = vif.drv_cb.nice_rsp_err;
        end
        else begin
            tr.rsp_rdat = '0;
            tr.rsp_err  = 1'b0;
        end
    endtask
endclass

`endif
