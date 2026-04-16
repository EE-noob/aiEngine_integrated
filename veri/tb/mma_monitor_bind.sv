`ifndef MMA_MONITOR_BIND_SV
`define MMA_MONITOR_BIND_SV

bind mma_top mma_monitor u_mma_monitor (
    .clk       (clk),
    .rst_n     (rst_n),
    .calc_start(calc_start),
    .wb_valid  (wb_valid),
    .wb_ready  (wb_ready),
    .err_code  (err_code)
);

`endif
