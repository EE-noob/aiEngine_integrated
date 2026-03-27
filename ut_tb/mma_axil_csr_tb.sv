`timescale 1ns/1ps

module mma_axil_csr_tb;

  localparam AXIL_ADDR_WIDTH = 16;
  localparam AXIL_DATA_WIDTH = 32;

  reg clk;
  reg rst_n;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
  end

  reg  [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr;
  reg  [2:0]                 s_axil_awprot;
  reg                        s_axil_awvalid;
  wire                       s_axil_awready;
  reg  [AXIL_DATA_WIDTH-1:0] s_axil_wdata;
  reg  [AXIL_DATA_WIDTH/8-1:0] s_axil_wstrb;
  reg                        s_axil_wvalid;
  wire                       s_axil_wready;
  wire [1:0]                 s_axil_bresp;
  wire                       s_axil_bvalid;
  reg                        s_axil_bready;
  reg  [AXIL_ADDR_WIDTH-1:0] s_axil_araddr;
  reg  [2:0]                 s_axil_arprot;
  reg                        s_axil_arvalid;
  wire                       s_axil_arready;
  wire [AXIL_DATA_WIDTH-1:0] s_axil_rdata;
  wire [1:0]                 s_axil_rresp;
  wire                       s_axil_rvalid;
  reg                        s_axil_rready;

  wire                       m_icb_cmd_valid;
  reg                        m_icb_cmd_ready;
  wire [31:0]                m_icb_cmd_addr;
  wire                       m_icb_cmd_read;
  wire [3:0]                 m_icb_cmd_len;
  wire [31:0]                m_icb_cmd_wdata;
  wire [3:0]                 m_icb_cmd_wmask;
  wire                       m_icb_w_valid;
  reg                        m_icb_w_ready;
  reg                        m_icb_rsp_valid;
  wire                       m_icb_rsp_ready;
  reg  [31:0]                m_icb_rsp_rdata;
  reg                        m_icb_rsp_err;
  wire                       mma_busy;

  integer err_cnt;

  mma_axil_top #(
    .AXIL_DATA_WIDTH(32),
    .AXIL_ADDR_WIDTH(16),
    .ICB_ADDR_WIDTH(32),
    .ICB_LEN_W(4)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    .m_icb_cmd_valid(m_icb_cmd_valid),
    .m_icb_cmd_ready(m_icb_cmd_ready),
    .m_icb_cmd_addr(m_icb_cmd_addr),
    .m_icb_cmd_read(m_icb_cmd_read),
    .m_icb_cmd_len(m_icb_cmd_len),
    .m_icb_cmd_wdata(m_icb_cmd_wdata),
    .m_icb_cmd_wmask(m_icb_cmd_wmask),
    .m_icb_w_valid(m_icb_w_valid),
    .m_icb_w_ready(m_icb_w_ready),
    .m_icb_rsp_valid(m_icb_rsp_valid),
    .m_icb_rsp_ready(m_icb_rsp_ready),
    .m_icb_rsp_rdata(m_icb_rsp_rdata),
    .m_icb_rsp_err(m_icb_rsp_err),
    .mma_busy(mma_busy)
  );

  task automatic axil_write(input [15:0] addr, input [31:0] data);
    integer tmo;
    reg aw_done;
    reg w_done;
    begin
      @(negedge clk);
      s_axil_awaddr  = addr;
      s_axil_awprot  = 3'b000;
      s_axil_awvalid = 1'b1;
      s_axil_wdata   = data;
      s_axil_wstrb   = 4'hF;
      s_axil_wvalid  = 1'b1;

      aw_done = 1'b0;
      w_done  = 1'b0;
      tmo = 0;
      while (!(aw_done && w_done)) begin
        @(posedge clk);
        if (!aw_done && s_axil_awvalid && s_axil_awready) begin
          aw_done = 1'b1;
          s_axil_awvalid = 1'b0;
        end
        if (!w_done && s_axil_wvalid && s_axil_wready) begin
          w_done = 1'b1;
          s_axil_wvalid = 1'b0;
        end
        tmo = tmo + 1;
        if (tmo > 200) begin
          $display("[FAIL] AXI write handshake timeout, addr=0x%04x", addr);
          $fatal(1);
        end
      end

      s_axil_bready = 1'b1;
      tmo = 0;
      while (!s_axil_bvalid) begin
        @(posedge clk);
        tmo = tmo + 1;
        if (tmo > 200) begin
          $display("[FAIL] AXI write response timeout, addr=0x%04x", addr);
          $fatal(1);
        end
      end
      @(posedge clk);
      s_axil_bready = 1'b0;
    end
  endtask

  task automatic axil_read(input [15:0] addr, output [31:0] data);
    integer tmo;
    begin
      @(negedge clk);
      s_axil_araddr  = addr;
      s_axil_arprot  = 3'b000;
      s_axil_arvalid = 1'b1;

      tmo = 0;
      while (!(s_axil_arvalid && s_axil_arready)) begin
        @(posedge clk);
        tmo = tmo + 1;
        if (tmo > 200) begin
          $display("[FAIL] AXI read address handshake timeout, addr=0x%04x", addr);
          $fatal(1);
        end
      end
      @(posedge clk);
      s_axil_arvalid = 1'b0;

      s_axil_rready = 1'b1;
      tmo = 0;
      while (!s_axil_rvalid) begin
        @(posedge clk);
        tmo = tmo + 1;
        if (tmo > 200) begin
          $display("[FAIL] AXI read data timeout, addr=0x%04x", addr);
          $fatal(1);
        end
      end
      data = s_axil_rdata;
      @(posedge clk);
      s_axil_rready = 1'b0;
    end
  endtask

  task automatic check_eq32(input [255:0] name, input [31:0] got, input [31:0] exp);
    begin
      if (got !== exp) begin
        err_cnt = err_cnt + 1;
        $display("[FAIL] %0s got=0x%08x exp=0x%08x", name, got, exp);
      end else begin
        $display("[PASS] %0s = 0x%08x", name, got);
      end
    end
  endtask

  reg [31:0] rdata;

  initial begin
    #500000;
    $display("[FAIL] TB timeout");
    $fatal(1);
  end

  initial begin
    err_cnt = 0;

    s_axil_awaddr  = '0;
    s_axil_awprot  = '0;
    s_axil_awvalid = 1'b0;
    s_axil_wdata   = '0;
    s_axil_wstrb   = 4'h0;
    s_axil_wvalid  = 1'b0;
    s_axil_bready  = 1'b0;
    s_axil_araddr  = '0;
    s_axil_arprot  = '0;
    s_axil_arvalid = 1'b0;
    s_axil_rready  = 1'b0;

    m_icb_cmd_ready = 1'b1;
    m_icb_w_ready   = 1'b1;
    m_icb_rsp_valid = 1'b0;
    m_icb_rsp_rdata = 32'h0;
    m_icb_rsp_err   = 1'b0;

    $dumpfile("mma_axil_csr_tb.vcd");
    $dumpvars(0, mma_axil_csr_tb);

    wait(rst_n == 1'b1);
    repeat (2) @(posedge clk);

    axil_read(16'h1F00, rdata);
    check_eq32("CSR MULT_LHS_PTR reset", rdata, 32'h0000_0000);

    axil_write(16'h1F00, 32'h1234_5678);
    axil_read (16'h1F00, rdata);
    check_eq32("CSR MULT_LHS_PTR rw", rdata, 32'h1234_5678);

    axil_write(16'h1F14, 32'h0000_0044);
    axil_read (16'h1F14, rdata);
    check_eq32("CSR MULT_RHS_COLS(n) rw", rdata, 32'h0000_0044);

    axil_write(16'h1F28, 32'hFFFF_FF80);
    axil_read (16'h1F28, rdata);
    check_eq32("CSR MULT_LHS_OFFSET rw", rdata, 32'hFFFF_FF80);

    axil_write(16'h1F40, 32'h0000_007F);
    axil_read (16'h1F40, rdata);
    check_eq32("CSR MULT_ACT_MAX rw", rdata, 32'h0000_007F);

    axil_write(16'h0000, 32'h0000_0006);
    axil_read (16'h0000, rdata);
    check_eq32("REG_CTRL cfg bits", (rdata & 32'h0000_0006), 32'h0000_0006);

    axil_read(16'h1F44, rdata);
    check_eq32("CSR unimplemented returns 0", rdata, 32'h0000_0000);

    if (err_cnt == 0) begin
      $display("\n==============================");
      $display(" AXI-Lite CSR TB PASS");
      $display("==============================\n");
    end else begin
      $display("\n==============================");
      $display(" AXI-Lite CSR TB FAIL, err_cnt=%0d", err_cnt);
      $display("==============================\n");
      $fatal(1);
    end

    #20;
    $finish;
  end

endmodule
