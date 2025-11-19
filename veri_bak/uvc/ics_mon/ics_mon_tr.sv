`ifndef ics_mon_TR__SV
`define ics_mon_TR__SV

class ics_mon_tr extends uvm_sequence_item;

    // 输出接口
    logic                   ics_out_sof;     // 输出起始标志，与第一个有效数据对齐
    logic                   ics_out_eof;     // 输出结束标志，与最后一个有效数据对齐
    logic                   ics_out_vld;     // 输出数据有效标志
    logic [3:0]             ics_out_num;     // 12行数据中有效行数指示，取值1~12
    logic [119:0]           ics_out_data;    // 输出数据，120bit
    
    //todo: complete tr_cons
    //constraint tr_cons{

    //}

    //todo: fill field automation list
    `uvm_object_utils_begin(ics_mon_tr)
        //`uvm_field_int(rx_lp_data,UVM_ALL_ON)
    `uvm_object_utils_end

    extern function new(string name="__NO_NAME__");
endclass: ics_mon_tr

function ics_mon_tr::new(string name="__NO_NAME__");
    super.new(name);
endfunction

`endif
