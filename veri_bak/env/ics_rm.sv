`ifndef ics_RM__SV
`define ics_RM__SV
class ics_rm extends uvm_component;

    uvm_blocking_get_port   #(ics_mst_tr)       in_port;
    uvm_analysis_port       #(ics_mon_tr)       out_port;

    extern function new(string name, uvm_component parent);
    extern function void build_phase(uvm_phase phase);
    extern virtual  task main_phase (uvm_phase phase);

    `uvm_component_utils(ics_rm)

endclass

function ics_rm::new(string name, uvm_component parent);
    super.new(name,parent);
endfunction

function void ics_rm::build_phase(uvm_phase phase); 
    super.build_phase(phase);
    in_port = new("in_port", this);
    out_port= new("out_port", this);
endfunction

task ics_rm::main_phase(uvm_phase phase);
    //ics_mst_tr  tr;
    //ics_mst_tr  new_tr;
    //ics_mon_tr   out_tr;
    //super.main_phase(phase);
    //while(1) begin
    //    in_port.get(tr);
    //    new_tr = new("new_tr");
    //    $cast(new_tr,tr.clone());
    //    `uvm_info(get_full_name(),"Get one tr, and copy it", UVM_MEDIUM)
    //    //todo:Add reference model behavior here
    //    out_port.write(out_tr);
    //end
endtask

`endif
