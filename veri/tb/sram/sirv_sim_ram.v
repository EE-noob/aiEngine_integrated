/*
 Copyright 2018-2020 Nuclei System Technology, Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

//=====================================================================
//
// Designer   : Bob Hu
//
// Description:
//  The simulation model of SRAM
//
// ====================================================================
`include "uvm_macros.svh"
import uvm_pkg::*;

module sirv_sim_ram
#(parameter DP = 512,
  parameter FORCE_X2ZERO = 0,
  parameter DW = 32,
  parameter MW = 4,
  parameter AW = 32,
  parameter MEM_PATH = "",
  parameter INIT_EN = 0
)
(
  input             clk,
  input  [DW-1  :0] din,
  (*mark_debug = "true"*)input  [AW-1  :0] addr,
  input             cs,
  input             we,
  input  [MW-1:0]   wem,
  (*mark_debug = "true"*)output [DW-1:0]   dout,
  input             mem_reload_req
);

    wire [MW-1:0] wen;
    wire ren;

    assign ren = cs & (~we);
    assign wen = ({MW{cs & we}} & wem);

    // Unified data-out path for synthesis/simulation branches.
    wire [DW-1:0] dout_pre;

    localparam ADDR_BITS = (DP <= 1) ? 1 : $clog2(DP);
    localparam integer BYTEW = (DW/MW);
    localparam integer MEM_BITS = DP*DW;
    wire [ADDR_BITS-1:0] addra = addr[ADDR_BITS-1:0];

    genvar i;

`ifdef SYNTHESIS
  `ifdef USE_XPM
    xpm_memory_spram #(
      .ADDR_WIDTH_A        (ADDR_BITS),
      .AUTO_SLEEP_TIME     (0),
      .BYTE_WRITE_WIDTH_A  (BYTEW),
      .ECC_MODE            ("no_ecc"),
      .MEMORY_INIT_FILE    (MEM_PATH),
      .MEMORY_INIT_PARAM   ("0"),
      .MEMORY_OPTIMIZATION ("true"),
      .MEMORY_PRIMITIVE    ("block"),
      .MEMORY_SIZE         (MEM_BITS),
      .MESSAGE_CONTROL     (0),
      .READ_DATA_WIDTH_A   (DW),
      .READ_LATENCY_A      (1),
      .READ_RESET_VALUE_A  ("0"),
      .RST_MODE_A          ("SYNC"),
      .SIM_ASSERT_CHK      (0),
      .USE_MEM_INIT        (INIT_EN),
      .WRITE_DATA_WIDTH_A  (DW),
      .WRITE_MODE_A        ("read_first")
    ) u_xpm_spram (
      .douta               (dout_pre),
      .addra               (addra),
      .clka                (clk),
      .ena                 (1'b1),
      .rsta                (1'b0),
      .regcea              (ren),
      .sleep               (1'b0),
      .wea                 (wen),
      .dina                (din),
      .injectdbiterra      (1'b0),
      .injectsbiterra      (1'b0)
    );
  `else
    initial begin
      if (DW % 8 != 0) begin
        $error("sirv_sim_ram: DW must be a multiple of 8 in non-xpm synthesis mode!");
      end
    end

    reg [DW-1:0] mem_r [0:DP-1];
    reg [AW-1:0] addr_r;
    reg [DW-1:0] dout_reg;

    initial begin
      if (INIT_EN && MEM_PATH != "") begin
        $display("sirv_sim_ram: loading memory from %s", MEM_PATH);
        $readmemh(MEM_PATH, mem_r);
      end
    end

    genvar k;
    generate
      for (k = 0; k < MW; k = k + 1) begin : ram_write
        always @(posedge clk) begin
          if (cs && we && wem[k]) begin
            mem_r[addr][8*k+7:8*k] <= din[8*k+7:8*k];
          end
        end
      end
    endgenerate

    always @(posedge clk) begin
      if (cs && !we) begin
        addr_r <= addr;
        dout_reg <= mem_r[addr];
      end
    end

    assign dout_pre = dout_reg;
  `endif
`else
    (* ram_style="block" *) reg [DW-1:0] mem_r [0:DP-1];
    reg [AW-1:0] addr_r;

    initial begin
        if (INIT_EN && MEM_PATH != "") begin
            $display("sirv_sim_ram: loading memory from %s", MEM_PATH);
            $readmemh(MEM_PATH, mem_r);
        end
    end

    task automatic reload_mem_from_file();
        if (MEM_PATH != "") begin
            `uvm_info("RAM_RELOAD", $sformatf("sirv_sim_ram runtime reload from %s", MEM_PATH), UVM_LOW)
            $readmemh(MEM_PATH, mem_r);
        end
    endtask

    task automatic check_mem_file(
        input string file_path,
        input integer start_word,
        input integer end_word,
        output integer mismatch_cnt
    );
        integer fd;
        integer ret;
        integer idx;
        reg [DW-1:0] exp_word;

        mismatch_cnt = 0;

        if ((start_word < 0) || (end_word < start_word)) begin
            `uvm_error("RAM_CHK", $sformatf("Invalid check range start=%0d end=%0d", start_word, end_word))
            mismatch_cnt = -1;
            return;
        end

        fd = $fopen(file_path, "r");
        if (fd == 0) begin
            `uvm_error("RAM_CHK", $sformatf("Cannot open %s for check", file_path))
            mismatch_cnt = -1;
            return;
        end

        idx = 0;
        while ((idx <= end_word) && !$feof(fd)) begin
            ret = $fscanf(fd, "%h\n", exp_word);
            if (ret != 1) begin
                if (idx >= start_word) begin
                    mismatch_cnt = mismatch_cnt + 1;
                    `uvm_error("RAM_CHK", $sformatf("Parse failure at word[%0d] from %s", idx, file_path))
                end
            end else if (idx >= start_word) begin
                if (mem_r[idx] !== exp_word) begin
                    mismatch_cnt = mismatch_cnt + 1;
                    `uvm_error("RAM_CHK", $sformatf("Mismatch word[%0d]: exp=0x%08h act=0x%08h", idx, exp_word, mem_r[idx]))
                end
            end
            idx = idx + 1;
        end

        if (idx <= end_word) begin
            mismatch_cnt = mismatch_cnt + 1;
            `uvm_error("RAM_CHK", $sformatf("File %s ended early at word[%0d], expected up to word[%0d]", file_path, idx, end_word))
        end

        $fclose(fd);

        if (mismatch_cnt == 0) begin
            `uvm_info("RAM_CHK", $sformatf("\033[1;32mPASS\033[0m RAM check matched %s in range [%0d:%0d]", file_path, start_word, end_word), UVM_LOW)
        end
    endtask

    always @(posedge clk) begin
        if (mem_reload_req) begin
            reload_mem_from_file();
        end
    end

    always @(posedge clk) begin
        if (ren) begin
            addr_r <= addr;
        end
    end

    generate
      for (i = 0; i < MW; i = i+1) begin : mem
        if((8*i+8) > DW ) begin: last
          always @(posedge clk) begin
            if (wen[i]) begin
               mem_r[addr][DW-1:8*i] <= din[DW-1:8*i];
            end
          end
        end
        else begin: non_last
          always @(posedge clk) begin
            if (wen[i]) begin
               mem_r[addr][8*i+7:8*i] <= din[8*i+7:8*i];
            end
          end
        end
      end
    endgenerate

    assign dout_pre = mem_r[addr_r];
`endif

    generate
     if(FORCE_X2ZERO == 1) begin: force_x_to_zero
        for (i = 0; i < DW; i = i+1) begin:force_x_gen 
            `ifndef SYNTHESIS//{
            assign dout[i] = (dout_pre[i] === 1'bx) ? 1'b0 : dout_pre[i];
            `else//}{
            assign dout[i] = dout_pre[i];
            `endif//}
        end
     end
     else begin:no_force_x_to_zero
       assign dout = dout_pre;
     end
    endgenerate

endmodule
