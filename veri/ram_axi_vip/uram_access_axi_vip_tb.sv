`timescale 1ns/1ps

`include "ram_axi_vip_tb_include.svh"

import axi_vip_pkg::*;
import ram_axi_vip_bd_master_0_0_pkg::*;

module uram_access_axi_vip_tb;
  bit clock = 0;
  bit resetn = 0;
  int errors = 0;
  bit test_done = 0;

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

  localparam int BANK_BYTES = 128 * 1024;
  localparam int BANK_COUNT = 16; // 2 MiB tensor arena
  localparam int WORDS_PER_BANK = BANK_BYTES / 4;
  localparam int PROBE_COUNT = 3;
  int probe_offsets[PROBE_COUNT] = '{0, WORDS_PER_BANK/2,
                                      WORDS_PER_BANK-1};

  ram_axi_vip_bd_master_0_0_mst_t axi_master;
  `BD_WRAPPER dut(.ACLK(clock), .ARESETN(resetn));

  always #4 clock = ~clock;

  function automatic bit [31:0] pattern(input int word_index);
    pattern = 32'ha53c9e17 ^ (word_index * 32'h9e3779b9);
  endfunction

  task automatic write_transfer(input xil_axi_ulong write_addr,
                                input bit [31:0] value,
                                input xil_axi_size_t transfer_size);
    begin
      addr = write_addr;
      length = 0;
      size = transfer_size;
      wdata = '0;
      wdata[31:0] = value;
      wuser = '0;
      axi_master.AXI4_WRITE_BURST(id, addr, length, size, burst, lock_type,
          cache, prot, region, qos, awuser, wdata, wuser, bresp);
      if (bresp != XIL_AXI_RESP_OKAY) begin
        $error("AXI write response %0d at 0x%08x", bresp, write_addr);
        errors++;
      end
    end
  endtask

  task automatic read32(input xil_axi_ulong read_addr,
                        input bit [31:0] expected);
    begin
      addr = read_addr;
      length = 0;
      size = xil_axi_size_t'(2);
      axi_master.AXI4_READ_BURST(id, addr, length, size, burst, lock_type,
          cache, prot, region, qos, aruser, rdata, rresp, ruser);
      if (rresp[0] != XIL_AXI_RESP_OKAY || rdata[31:0] !== expected) begin
        $error("URAM read mismatch addr=0x%08x got=0x%08x expected=0x%08x resp=%0d",
               read_addr, rdata[31:0], expected, rresp[0]);
        errors++;
      end
    end
  endtask

  initial begin : run_test
    int word_index;
    int byte_value;
    bit [31:0] expected;
    axi_master = new("axi_vip_master", dut.`BD_INST_NAME.master_0.inst.IF);
    axi_master.vif_proxy.set_dummy_drive_type(XIL_AXI_VIF_DRIVE_NONE);
    axi_master.set_agent_tag("URAM AXI access test");
    axi_master.start_master();

    repeat (20) @(negedge clock);
    resetn = 1;
    repeat (10) @(negedge clock);

    // Write distinct values at the first, middle, and last word of every
    // arena bank, then read them back through the AXI BRAM Controller.
    for (int bank = 0; bank < BANK_COUNT; bank++) begin
      for (int probe = 0; probe < PROBE_COUNT; probe++) begin
        word_index = bank * WORDS_PER_BANK + probe_offsets[probe];
        write_transfer(4 * word_index, pattern(word_index), xil_axi_size_t'(2));
      end
    end
    for (int bank = 0; bank < BANK_COUNT; bank++) begin
      for (int probe = 0; probe < PROBE_COUNT; probe++) begin
        word_index = bank * WORDS_PER_BANK + probe_offsets[probe];
        read32(4 * word_index, pattern(word_index));
      end
    end

    // Check all four byte strobes at the middle word of each bank.
    for (int bank = 0; bank < BANK_COUNT; bank++) begin
      word_index = bank * WORDS_PER_BANK + WORDS_PER_BANK/2;
      expected = pattern(word_index);
      for (int lane = 0; lane < 4; lane++) begin
        byte_value = (8'h5a ^ (bank * 13) ^ (lane * 37)) & 8'hff;
        write_transfer(4 * word_index + lane, byte_value, xil_axi_size_t'(0));
        expected[lane*8 +: 8] = byte_value[7:0];
      end
      read32(4 * word_index, expected);
    end

    if (errors == 0)
      $display("[URAM_AXI_VIP] PASS banks=%0d probe_words=%0d byte_lanes=%0d",
               BANK_COUNT, BANK_COUNT*PROBE_COUNT, BANK_COUNT*4);
    else
      $fatal(1, "[URAM_AXI_VIP] FAIL errors=%0d", errors);
    test_done = 1;
    #40ns;
    $finish;
  end

  initial begin
    #100us;
    if (!test_done) $fatal(1, "[URAM_AXI_VIP] TIMEOUT");
  end
endmodule
