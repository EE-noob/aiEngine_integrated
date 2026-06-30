`ifndef MMA_MONITOR_SV
`define MMA_MONITOR_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

module mma_monitor (
    input logic       clk,
    input logic       rst_n,
    input logic       calc_start,
    input logic       wb_valid,
    input logic       wb_ready,
    input logic [1:0] err_code
);
  logic calc_start_d;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      calc_start_d <= 1'b0;
    end else begin
      calc_start_d <= calc_start;

      if (calc_start && !calc_start_d) begin
        $root.tb_top.nice_vif.mma_calc_start_toggle = ~$root.tb_top.nice_vif.mma_calc_start_toggle;
        fork
          begin
            wait (wb_valid && wb_ready);
            $root.tb_top.nice_vif.mma_err_code = err_code;
            $root.tb_top.nice_vif.mma_wb_handshake_toggle = ~$root.tb_top.nice_vif.mma_wb_handshake_toggle;

            case (err_code)
              2'b00: `uvm_info("mma_monitor", "writeback handshake ok, status 00=normal", UVM_HIGH)
              2'b01: `uvm_error("mma_monitor", "writeback handshake ok, status 01=config_error")
              2'b10: `uvm_error("mma_monitor", "writeback handshake ok, status 10=resource_missing")
              default: `uvm_error("mma_monitor", $sformatf("writeback handshake ok, status %b=unknown", err_code))
            endcase
          end
        join_none
      end
    end
  end
endmodule

`endif
