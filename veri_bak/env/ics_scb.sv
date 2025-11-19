`ifndef ics_SCB__SV
`define ics_SCB__SV
class ics_scb extends uvm_scoreboard;
    ics_mon_tr      expect_queue[$];
    uvm_blocking_get_port   #(ics_mon_tr)   exp_port;
    uvm_blocking_get_port   #(ics_mon_tr)   act_port;
    `uvm_component_utils(ics_scb)

    extern function new(string name, uvm_component parent = null);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task main_phase(uvm_phase phase);
endclass

function ics_scb::new(string name, uvm_component parent = null);
    super.new(name, parent);
endfunction

function void ics_scb::build_phase(uvm_phase phase);
    super.build_phase(phase);
    exp_port = new("exp_port",this);
    act_port = new("act_port",this);
endfunction

task ics_scb::main_phase(uvm_phase phase);
    //ics_mon_tr  get_expect, get_actual, tmp_tran;
    //bit result;

    //super.main_phase(phase);
    //fork
    //    while(1)begin
    //        exp_port.get(get_expect);
    //        expect_queue.push_back(get_expect);
    //    end
    //    while(1)begin
    //        act_port.get(get_actual);
    //        if(expect_queue.size() > 0) begin
    //            tmp_tran = expect_queue.pop_front();
    //            result = get_actual.compare(tmp_tran);
    //            if(result) begin
    //                `uvm_info(get_full_name(),"Compare SUCCESSFUL", UVM_MEDIUM);
    //            end
    //            else begin
    //                `uvm_error(get_full_name(),"Compare ERROR");
    //                `uvm_info(get_full_name(),"the expect pkt is", UVM_NONE);
    //                tmp_tran.print();
    //                `uvm_info(get_full_name(),"the actual pkt is", UVM_NONE);
    //                get_actual.print();
    //            end
    //        end
    //        else begin
    //            `uvm_error(get_full_name(), "Receive pkt from DUT, while the Expect Queue is empty");
    //            `uvm_info(get_full_name(),"the unexpected pkt is", UVM_NONE);
    //            get_actual.print();
    //        end
    //    end
    //join

endtask: main_phase

`endif
