`timescale 1ns/1ps

`include "ram_axi_vip_tb_include.svh"

import axi_vip_pkg::*;
import ram_axi_vip_bd_master_0_0_pkg::*;

module ram_axi_vip_tb;
  bit clock = 0;
  bit resetn = 0;
  int errors = 0;

  xil_axi_uint id = 0;
  xil_axi_ulong addr;
  xil_axi_len_t length = 0;
  xil_axi_size_t size;
  xil_axi_burst_t burst = XIL_AXI_BURST_TYPE_INCR;
  xil_axi_lock_t lock_type = XIL_AXI_ALOCK_NOLOCK;
  xil_axi_cache_t cache = 0;
  xil_axi_prot_t prot = 0;
  xil_axi_region_t region = 0;
  xil_axi_qos_t qos = 0;
  xil_axi_data_beat awuser = 0;
  xil_axi_data_beat aruser = 0;
  xil_axi_data_beat [255:0] wuser = '0;
  xil_axi_data_beat [255:0] ruser;
  xil_axi_resp_t bresp;
  xil_axi_resp_t [255:0] rresp;
  bit [32767:0] wdata;
  bit [32767:0] rdata;
  bit test_done = 0;

  ram_axi_vip_bd_master_0_0_mst_t axi_master;

  `BD_WRAPPER dut(.ACLK(clock), .ARESETN(resetn));

  always #4 clock = ~clock;

  always @(posedge clock) begin
    if (dut.ram_axi_vip_bd_i.master_0_M_AXI_RVALID)
      $display("[RAMVIP_AXI_R] t=%0t rdata=%08x rready=%b", $time,
          dut.ram_axi_vip_bd_i.master_0_M_AXI_RDATA,
          dut.ram_axi_vip_bd_i.master_0_M_AXI_RREADY);
    if (dut.ram_axi_vip_bd_i.bram_ctrl_BRAM_PORTA_EN) begin
      $display("[RAMVIP_TRACE] t=%0t bram_addr=%08x we=%x dout=%08x",
          $time, dut.ram_axi_vip_bd_i.bram_ctrl_BRAM_PORTA_ADDR,
          dut.ram_axi_vip_bd_i.bram_ctrl_BRAM_PORTA_WE,
          dut.ram_axi_vip_bd_i.bram_ctrl_BRAM_PORTA_DOUT);
      #1;
      $display("[RAMVIP_TRACE_POST] t=%0t bram_addr=%08x en=%b we=%x din=%08x dout=%08x",
          $time, dut.ram_axi_vip_bd_i.bram_ctrl_BRAM_PORTA_ADDR,
          dut.ram_axi_vip_bd_i.bram_ctrl_BRAM_PORTA_EN,
          dut.ram_axi_vip_bd_i.bram_ctrl_BRAM_PORTA_WE,
          dut.ram_axi_vip_bd_i.bram_ctrl_BRAM_PORTA_DIN,
          dut.ram_axi_vip_bd_i.bram_ctrl_BRAM_PORTA_DOUT);
      $display("[RAMVIP_RAM_POST] t=%0t ena=%b valid=%b word=%08x bmena=%b bma=%08x bmdout=%08x",
          $time, dut.ram_axi_vip_bd_i.shared_ram.inst.ena,
          dut.ram_axi_vip_bd_i.shared_ram.inst.bram_valid_a,
          dut.ram_axi_vip_bd_i.shared_ram.inst.bram_word_addr_a,
          dut.ram_axi_vip_bd_i.shared_ram.inst.model_bram_0.ena,
          dut.ram_axi_vip_bd_i.shared_ram.inst.model_bram_0.addra,
          dut.ram_axi_vip_bd_i.shared_ram.inst.bram_douta);
    end
  end

  task automatic read32(input xil_axi_ulong read_addr,
                        input bit [31:0] expected);
    begin
      addr = read_addr;
      length = 0;
      size = xil_axi_size_t'(2);
      axi_master.AXI4_READ_BURST(id, addr, length, size, burst, lock_type,
          cache, prot, region, qos, aruser, rdata, rresp, ruser);
      $display("[RAMVIP] READ32 addr=%08x data=%08x resp=%0d expected=%08x",
               read_addr, rdata[31:0], rresp[0], expected);
      if (rresp[0] != XIL_AXI_RESP_OKAY || rdata[31:0] !== expected) begin
        $error("READ32 mismatch at 0x%08x", read_addr);
        errors++;
      end
    end
  endtask

  task automatic write32(input xil_axi_ulong write_addr,
                         input bit [31:0] value);
    begin
      addr = write_addr;
      length = 0;
      size = xil_axi_size_t'(2);
      wdata = '0;
      wdata[31:0] = value;
      wuser = '0;
      axi_master.AXI4_WRITE_BURST(id, addr, length, size, burst, lock_type,
          cache, prot, region, qos, awuser, wdata, wuser, bresp);
      if (bresp != XIL_AXI_RESP_OKAY) begin
        $error("WRITE32 response %0d at 0x%08x", bresp, write_addr);
        errors++;
      end
    end
  endtask

  task automatic read8(input xil_axi_ulong read_addr,
                       input bit [7:0] expected);
    begin
      addr = read_addr;
      length = 0;
      size = xil_axi_size_t'(0);
      axi_master.AXI4_READ_BURST(id, addr, length, size, burst, lock_type,
          cache, prot, region, qos, aruser, rdata, rresp, ruser);
      $display("[RAMVIP] READ8 addr=%08x rdata=%08x resp=%0d expected=%02x",
               read_addr, rdata[31:0], rresp[0], expected);
      if (rresp[0] != XIL_AXI_RESP_OKAY ||
          rdata[7:0] !== expected) begin
        $error("READ8 mismatch at 0x%08x", read_addr);
        errors++;
      end
    end
  endtask

  initial begin
    axi_master = new("axi_vip_master", dut.`BD_INST_NAME.master_0.inst.IF);
    axi_master.vif_proxy.set_dummy_drive_type(XIL_AXI_VIF_DRIVE_NONE);
    axi_master.set_agent_tag("Shared RAM AXI VIP");
    axi_master.start_master();

    repeat (20) @(negedge clock);
    resetn = 1;
    repeat (10) @(negedge clock);

    // The BMG model image begins at byte offset 10 MiB in the shared RAM.
    // These are the exact initial words checked by the firmware probe.
    read32(32'h00A0_0000, 32'h0000_0020);
    read32(32'h00A0_0004, 32'h334C_4654);
    read32(32'h00A0_0020, 32'h0000_0014);
    read32(32'h00A0_003C, 32'h0000_0003);
    for (int lane = 0; lane < 4; lane++) begin
      read8(32'h00A0_0004 + lane, 8'(32'h334C_4654 >> (lane * 8)));
    end

    // Use the initialized, zero-filled arena tail for write/read and byte
    // strobe checks; do not modify the model image.
    write32(32'h00B8_AB80, 32'hA1B2_C3D4);
    read32(32'h00B8_AB80, 32'hA1B2_C3D4);

    if (errors == 0) $display("[RAMVIP] PASS");
    else $display("[RAMVIP] FAIL errors=%0d", errors);
    test_done = 1;
    #40ns;
    $finish;
  end

  initial begin
    #10us;
    if (!test_done) $fatal(1, "[RAMVIP] TIMEOUT");
  end
endmodule
