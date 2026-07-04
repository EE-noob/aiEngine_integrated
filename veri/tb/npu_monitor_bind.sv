`ifndef NPU_MONITOR_BIND_SV
`define NPU_MONITOR_BIND_SV

bind npu_top npu_monitor u_npu_monitor (
    .clk       (clk),
    .rst_n     (rst_n),
    .calc_start(calc_start),
    .done_valid(done_valid),
    .done_ready(done_ready),
    .err_code  (err_code)
);

`endif
