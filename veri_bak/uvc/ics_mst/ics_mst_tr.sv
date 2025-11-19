`ifndef ics_mst_TR__SV
`define ics_mst_TR__SV

class ics_mst_tr extends uvm_sequence_item;

    rand bit          ics_start;        // 启动信号，单周期脉冲
    rand bit  [30:0]  ics_c_init;       // 随机序列x2(n)初相;就是Cinit
    rand bit  [3:0]   ics_q_size;       // 合并处理基本单元参数 Q

    rand bit          ics_part0_en;     // part0 使能
    rand bit  [10:0]  ics_part0_n_size; // part0 待交织数据 bit 长度 N0
    rand bit  [13:0]  ics_part0_e_size; // part0 交织处理后总 bit 长度 E0
    rand bit  [13:0]  ics_part0_l_size; // part0 交织处理后有效 bit 长度 L0
    rand bit  [13:0]  ics_part0_st_idx; // part0 有效数据起始点 S0

    rand bit          ics_part1_en;     // part1 使能
    rand bit  [10:0]  ics_part1_n_size; // part1 待交织数据 bit 长度 N1
    rand bit  [13:0]  ics_part1_e_size; // part1 交织处理后总 bit 长度 E1
    rand bit  [13:0]  ics_part1_l_size; // part1 交织处理后有效 bit 长度 L1
    rand bit  [13:0]  ics_part1_st_idx; // part1 有效数据起始点 S1

    rand bit          ics_part2_en;     // part2 使能
    rand bit  [10:0]  ics_part2_n_size; // part2 待交织数据 bit 长度 N2
    rand bit  [13:0]  ics_part2_e_size; // part2 交织处理后总 bit 长度 E2
    rand bit  [13:0]  ics_part2_l_size; // part2 交织处理后有效 bit 长度 L2
    rand bit  [13:0]  ics_part2_st_idx; // part2 有效数据起始点 S2

    // Handle by ics_mem_model
    //bit          ics_rd_en;        // 待交织数据读使能
    //bit  [4:0]   ics_rd_addr;      // 待读地址
    //bit  [127:0] ics_rd_data;      // 待读数据，每拍返回连续128bit

    //todo: complete tr_cons
    //constraint pid_cons{
    //    tx_pid dist {
    //        4'b0001 := 10,
    //        4'b1001 := 10,
    //        4'b0011 := 10,
    //        4'b1011 := 10,
    //        4'b0111 := 10,
    //        4'b1111 := 10
    //        
    //    };
    //}


    //todo: fill field automation list
    `uvm_object_utils_begin(ics_mst_tr)
        `uvm_field_int(ics_start,UVM_ALL_ON)
    `uvm_object_utils_end

    extern function new(string name="__NO_NAME__");
endclass: ics_mst_tr

function ics_mst_tr::new(string name="__NO_NAME__");
    super.new(name);
endfunction

`endif