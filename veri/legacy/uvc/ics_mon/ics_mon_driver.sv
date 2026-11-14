`ifndef ics_mon_DRIVER__SV
`define ics_mon_DRIVER__SV

typedef class ics_mon_driver_cb;

class ics_mon_driver extends uvm_driver#(ics_mon_tr);

    int                 trans_cnt=0;
    virtual ics_if     vif;
    ics_mon_sequencer   sequencer;
    ics_mon_agent_cfg         cfg;
    bit                 drv_busy;

    `uvm_register_cb(ics_mon_driver, ics_mon_driver_cb)
    `uvm_component_utils_begin(ics_mon_driver)
    `uvm_component_utils_end

    extern function new(string name, uvm_component parent);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task     run_phase(uvm_phase phase);
    extern virtual task     reset_vif();
    extern virtual task     get_and_drive();
    extern virtual task     req_drive(ics_mon_tr tr);
    extern virtual task     timeout_mon();
    extern virtual task     dynamic_reset(uvm_phase phase);
    extern virtual task     reset_all(uvm_phase phase);
    
endclass

function ics_mon_driver::new(string name, uvm_component parent);
    super.new(name, parent);
endfunction: new

function void ics_mon_driver::build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual ics_if)::get(this,"","ics_vif",vif))begin
        `uvm_fatal(get_full_name(), $sformatf("Got vif failed!"))
    end

endfunction: build_phase

task ics_mon_driver::run_phase(uvm_phase phase);
    reset_vif();
    //if(cfg.drv_timeout_check_en)    timeout_mon();
    fork
        forever begin
            fork
                get_and_drive();
            join_none
            dynamic_reset(phase);
            disable fork;
        end
    join
endtask: run_phase

task ics_mon_driver::reset_vif();
    `uvm_info(get_full_name(), $sformatf("Reset signals by vif.CEN == 0.."), UVM_MEDIUM)
    //todo: fill this task according to initial value
    
    `uvm_info(get_full_name(), $sformatf("Reset finished"), UVM_MEDIUM);
endtask: reset_vif

task ics_mon_driver::get_and_drive();
    `uvm_info(get_full_name(), "get trans from seq_item_port and drive signals by vif", UVM_MEDIUM)
    forever begin
        seq_item_port.get_next_item(req);
        drv_busy=1;
        `uvm_do_callbacks(ics_mon_driver, ics_mon_driver_cb, pre_get_and_drive(req));
        req_drive(req);
        `uvm_do_callbacks(ics_mon_driver, ics_mon_driver_cb, pos_get_and_drive(req));
        seq_item_port.item_done();
        drv_busy=0;
    end
endtask: get_and_drive

task ics_mon_driver::req_drive(ics_mon_tr tr);
    trans_cnt++;
    `uvm_info(get_full_name(), $sformatf("get trans [%0d] and drive signals by vif", trans_cnt), UVM_MEDIUM)
    //todo: Finish signals drive according to protocol
    //@(vif.drv_cb iff(vif.rst_n === 1));
    //vif.drv_cb.rx_lp_data <= tr.rx_lp_data;
    `uvm_info(get_full_name(), $sformatf("end of a tr"), UVM_MEDIUM)
endtask: req_drive

task ics_mon_driver::timeout_mon();
    `uvm_info(get_full_name(), $sformatf("Enter timeout_mon function"), UVM_MEDIUM)
    fork
        forever begin
            wait(drv_busy == 1);
            fork: drv_busy_mon
                begin
                    #(cfg.drv_timeout_ns);
                    `uvm_fatal(get_full_name(), $sformatf("trans sending started before, but no further actions for %0d ns", cfg.drv_timeout_ns))
                end
                wait(drv_busy == 0);
            join_any
            disable drv_busy_mon;
        end
    join_none
endtask: timeout_mon

task ics_mon_driver::dynamic_reset(uvm_phase phase);
    wait(vif.rst_n);
    wait(!vif.rst_n);

    reset_all(phase);
endtask: dynamic_reset

task ics_mon_driver::reset_all(uvm_phase phase);
    reset_vif();
    while(sequencer.m_req_fifo.used()) begin
        seq_item_port.item_done(); 
    end
    drv_busy = 0;
endtask: reset_all

class ics_mon_driver_cb extends uvm_callback;
    `uvm_object_utils(ics_mon_driver_cb)

    function new(string name = "ics_mon_driver_cb");
        super.new(name);
    endfunction

    virtual function void pre_get_and_drive(ics_mon_tr tr);
        `uvm_info(get_full_name(), $sformatf("callback: pre_get_and_drive"), UVM_HIGH)
    endfunction

    virtual function void pos_get_and_drive(ics_mon_tr tr);
        `uvm_info(get_full_name(), $sformatf("callback: pos_get_and_drive"), UVM_HIGH)
    endfunction
endclass
`endif
