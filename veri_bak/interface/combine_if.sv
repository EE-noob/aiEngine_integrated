// -------------------------
// filo_env_if.sv
// -------------------------
interface combine_if(input logic clk);

  // DUT 信号定义（保持原命名风格）
  logic      [9:0]           combine_data    [0:11];
  logic                      combine_valid;
  logic      [3:0]           combine_num;
endinterface