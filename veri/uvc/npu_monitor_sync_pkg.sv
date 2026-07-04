`ifndef NPU_MONITOR_SYNC_PKG_SV
`define NPU_MONITOR_SYNC_PKG_SV

package npu_monitor_sync_pkg;
  bit [1:0] g_last_err_code = 2'b00;
  event g_calc_start_evt;
  event g_done_handshake_evt;
endpackage

`endif
