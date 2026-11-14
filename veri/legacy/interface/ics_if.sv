`ifndef ics_IF__SV
`define ics_IF__SV

interface ics_if (input logic clk, input logic rst_n);
    parameter setup_time = 0.1ns;
    parameter hold_time = 0.1ns;

    // 控制输入
    logic                     ics_start;         // 启动信号，单拍脉冲
    logic [30:0]              ics_c_init;       // 随机序列x2(n)初相,就是Cinit
    logic [3:0]               ics_q_size;        // 合并处理基本单元参数 Q

    // 三路配置参数输入
    logic                     ics_part0_en;
    logic [10:0]              ics_part0_n_size;  // part0 输入bit长度 N0
    logic [13:0]              ics_part0_e_size;  // part0 交织后bit总长度 E0
    logic [13:0]              ics_part0_l_size;  // part0 交织后有效bit长度 L0
    logic [13:0]              ics_part0_st_idx;  // part0 有效bit起始位置 S0
    logic                     ics_part1_en;
    logic [10:0]              ics_part1_n_size;
    logic [13:0]              ics_part1_e_size;
    logic [13:0]              ics_part1_l_size;
    logic [13:0]              ics_part1_st_idx;
    logic                     ics_part2_en;
    logic [10:0]              ics_part2_n_size;
    logic [13:0]              ics_part2_e_size;
    logic [13:0]              ics_part2_l_size;
    logic [13:0]              ics_part2_st_idx;

    // IN_BUF 读接口
    logic                     ics_rd_en;
    logic [4:0]               ics_rd_addr;
    logic [127:0]             ics_rd_data;

    // FILO 读接口（Combine使用）
    logic part0_filoA_rdA_en; 
    logic part0_filoB_rdA_en;
    logic part1_filoA_rdA_en; 
    logic part1_filoB_rdA_en;
    logic part2_filoA_rdA_en; 
    logic part2_filoB_rdA_en;
    logic [9:0] part0_filoA_rdA_data; 
    logic [9:0] part0_filoB_rdA_data;
    logic [9:0] part1_filoA_rdA_data; 
    logic [9:0] part1_filoB_rdA_data;
    logic [9:0] part2_filoA_rdA_data; 
    logic [9:0] part2_filoB_rdA_data;
    logic part0_filoA_rdB_en; 
    logic part0_filoB_rdB_en;
    logic part1_filoA_rdB_en; 
    logic part1_filoB_rdB_en;
    logic part2_filoA_rdB_en; 
    logic part2_filoB_rdB_en;
    logic [3:0] part0_filoA_rdB_data; 
    logic [3:0] part0_filoB_rdB_data;
    logic [3:0] part1_filoA_rdB_data; 
    logic [3:0] part1_filoB_rdB_data;
    logic [3:0] part2_filoA_rdB_data; 
    logic [3:0] part2_filoB_rdB_data;
    logic part0_filoA_rd1_en; 
    logic part0_filoB_rd1_en;
    logic part1_filoA_rd1_en; 
    logic part1_filoB_rd1_en;
    logic part2_filoA_rd1_en; 
    logic part2_filoB_rd1_en;
    logic part0_filoA_rd1_data;
    logic part0_filoB_rd1_data;
    logic part1_filoA_rd1_data;
    logic part1_filoB_rd1_data;
    logic part2_filoA_rd1_data;
    logic part2_filoB_rd1_data;
    logic part0_filoA_empty;
    logic part0_filoA_rdy4rd;
    logic part0_filoB_empty;
    logic part0_filoB_rdy4rd;
    logic part1_filoA_empty;
    logic part1_filoA_rdy4rd;
    logic part1_filoB_empty;
    logic part1_filoB_rdy4rd;
    logic part2_filoA_empty;
    logic part2_filoA_rdy4rd;
    logic part2_filoB_empty;
    logic part2_filoB_rdy4rd;
    logic [$clog2(128+1)-1:0] part0_filoA_cnt;
    logic [$clog2(128+1)-1:0] part0_filoB_cnt;
    logic [$clog2(128+1)-1:0] part1_filoA_cnt;
    logic [$clog2(128+1)-1:0] part1_filoB_cnt;
    logic [$clog2(128+1)-1:0] part2_filoA_cnt;
    logic [$clog2(128+1)-1:0] part2_filoB_cnt;

    // ICS输出接口
    logic         ics_out_sof;     // 输出起始标志，与第一个有效数据对齐
    logic         ics_out_eof;     // 输出结束标志，与最后一个有效数据对齐
    logic         ics_out_vld;     // 输出数据有效标志
    logic [3:0]   ics_out_num;     // 12行数据中有效行数指示，取值1~12
    logic [119:0] ics_out_data;    // 输出数据，120bit

clocking drv_cb @ (posedge clk);
    default input #setup_time output #hold_time;
    // Control
    output                      ics_start;
    output                      ics_c_init;
    output                      ics_q_size;
    output                      ics_part0_en;
    output                      ics_part0_n_size;
    output                      ics_part0_e_size;
    output                      ics_part0_l_size;
    output                      ics_part0_st_idx;
    output                      ics_part1_en;
    output                      ics_part1_n_size;
    output                      ics_part1_e_size;
    output                      ics_part1_l_size;
    output                      ics_part1_st_idx;
    output                      ics_part2_en;
    output                      ics_part2_n_size;
    output                      ics_part2_e_size;
    output                      ics_part2_l_size;
    output                      ics_part2_st_idx;

    // Data
    output                      ics_rd_data;
endclocking: drv_cb

clocking mon_cb @ (posedge clk);
    default input #setup_time output #hold_time;
    input                       ics_rd_en;
    input                       ics_rd_addr;

    // I2C output
    input                       part0_filoA_rdA_en;
    input                       part0_filoB_rdA_en;
    input                       part1_filoA_rdA_en;
    input                       part1_filoB_rdA_en;
    input                       part2_filoA_rdA_en;
    input                       part2_filoB_rdA_en;
    input                       part0_filoA_rdA_data;
    input                       part0_filoB_rdA_data;
    input                       part1_filoA_rdA_data;
    input                       part1_filoB_rdA_data;
    input                       part2_filoA_rdA_data;
    input                       part2_filoB_rdA_data;
    input                       part0_filoA_rdB_en;
    input                       part0_filoB_rdB_en;
    input                       part1_filoA_rdB_en;
    input                       part1_filoB_rdB_en;
    input                       part2_filoA_rdB_en;
    input                       part2_filoB_rdB_en;
    input                       part0_filoA_rdB_data;
    input                       part0_filoB_rdB_data;
    input                       part1_filoA_rdB_data;
    input                       part1_filoB_rdB_data;
    input                       part2_filoA_rdB_data;
    input                       part2_filoB_rdB_data;
    input                       part0_filoA_rd1_en;
    input                       part0_filoB_rd1_en;
    input                       part1_filoA_rd1_en;
    input                       part1_filoB_rd1_en;
    input                       part2_filoA_rd1_en;
    input                       part2_filoB_rd1_en;
    input                       part0_filoA_rd1_data;
    input                       part0_filoB_rd1_data;
    input                       part1_filoA_rd1_data;
    input                       part1_filoB_rd1_data;
    input                       part2_filoA_rd1_data;
    input                       part2_filoB_rd1_data;
    input                       part0_filoA_empty;
    input                       part0_filoA_rdy4rd;
    input                       part0_filoB_empty;
    input                       part0_filoB_rdy4rd;
    input                       part1_filoA_empty;
    input                       part1_filoA_rdy4rd;
    input                       part1_filoB_empty;
    input                       part1_filoB_rdy4rd;
    input                       part2_filoA_empty;
    input                       part2_filoA_rdy4rd;
    input                       part2_filoB_empty;
    input                       part2_filoB_rdy4rd;
    input                       part0_filoA_cnt;
    input                       part0_filoB_cnt;
    input                       part1_filoA_cnt;
    input                       part1_filoB_cnt;
    input                       part2_filoA_cnt;
    input                       part2_filoB_cnt;

    // ICS output
    input                       ics_out_sof;
    input                       ics_out_eof;
    input                       ics_out_vld;
    input                       ics_out_num;
    input                       ics_out_data;
endclocking: mon_cb


endinterface: ics_if

`endif