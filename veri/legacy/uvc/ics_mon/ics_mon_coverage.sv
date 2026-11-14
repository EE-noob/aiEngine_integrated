`ifndef ics_mon_COVERAGE__SV
`define ics_mon_COVERAGE__SV
class ics_mon_coverage extends uvm_object;

    ics_mon_tr              tr;

    //todo: add covergroup to get function coverage
    //covergroup ics_mon_tr_cg;
    //    option.per_instance=1;
    //    cov_full_addr: coverpoint tr.address
    //    {
    //        bins lo = {0};
    //        bins hi = {255};
    //    }
    //endgroup

    //function new(string name);
    //    ics_mon_tr_cg=new();
    //    ics_mon_tr_cg.set_inst_name("ics_mon_tr_cg");
    //endfunction

    //virtual function void sample_tr(ics_mon_tr tr);
    //    this.tr = tr;
    //    ics_mon_tr_cg.sample();
    //endfunction
    
endclass
`endif
