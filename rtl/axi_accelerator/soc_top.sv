module soc_top #(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter WEIGHT_WIDTH    = 16,
    parameter DATA_WIDTH      = 16,
    parameter SIZE            = 16,
    parameter BUS_WIDTH       = 32,
    parameter REG_WIDTH       = 32,
    parameter AXI_ADDR_WIDTH  = 32,
    parameter NPU_ADDR_WIDTH  = AXI_ADDR_WIDTH,
    parameter IA_CACHE_BLOCKS = 4,
    parameter PS_FRAME_COUNT  = SIZE,
    parameter AXI_READ_OUTSTANDING  = 4,
    parameter AXI_WRITE_OUTSTANDING = AXI_READ_OUTSTANDING,
    parameter NPU_ENABLE_IS_MODE = 1,
    parameter NPU_ENABLE_PER_CHANNEL = 1,
    parameter NPU_ENABLE_CLOCK_GATING = 1,
    parameter CPU_MEM_DP      = 524288,
    parameter CPU_MEM_PATH    = "../tb/axi_soc_case/cpu.mem",
    parameter CPU_MEM_INIT_EN = 1,
    parameter CPU_ENABLE_ICACHE = 0,
    parameter CPU_AXI_READ_TIMING_BUFFER = 1,
    parameter NPU_AXI_TIMING_BUFFER = 1,
    parameter CPU_AXI_WRITE_TIMING_BUFFER = 1,
    parameter BYPASS_RAM_PINGPONG = 1,
    parameter RAM_WRITE_TIMING_BUFFER = 1,
    parameter [31:0] CPU_RAM_BASE   = 32'h0000_0000,
    parameter [31:0] NPU_AXIL_BASE  = 32'h1000_0000,
    parameter [31:0] UART_BASE      = 32'h0200_0000,
    parameter [31:0] SOC_CTRL_BASE  = 32'h2000_0000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mem_reload_req,
    output wire        npu_busy,
    output wire        npu_irq,
    output wire        uart_tx,
    input  wire        uart_rx,
    output wire        soc_finish,
    output wire [31:0] soc_status,
    output wire        cpu_trap
);

    wire        pico_mem_valid;
    wire        pico_mem_instr;
    wire        pico_mem_ready;
    wire [31:0] pico_mem_addr;
    wire [31:0] pico_mem_wdata;
    wire [3:0]  pico_mem_wstrb;
    wire [31:0] pico_mem_rdata;

    wire        cpu_axi_arvalid;
    wire        cpu_axi_arready;
    wire [REG_WIDTH-1:0] cpu_axi_araddr;
    wire [3:0]  cpu_axi_arcache;
    wire [2:0]  cpu_axi_arprot;
    wire [1:0]  cpu_axi_arlock;
    wire [1:0]  cpu_axi_arburst;
    wire [7:0]  cpu_axi_arlen;
    wire [2:0]  cpu_axi_arsize;
    wire        cpu_axi_rvalid;
    wire        cpu_axi_rready;
    wire [BUS_WIDTH-1:0] cpu_axi_rdata;
    wire [1:0]  cpu_axi_rresp;
    wire        cpu_axi_rlast;
    wire        cpu_axi_awvalid;
    wire        cpu_axi_awready;
    wire [REG_WIDTH-1:0] cpu_axi_awaddr;
    wire [3:0]  cpu_axi_awcache;
    wire [2:0]  cpu_axi_awprot;
    wire [1:0]  cpu_axi_awlock;
    wire [1:0]  cpu_axi_awburst;
    wire [7:0]  cpu_axi_awlen;
    wire [2:0]  cpu_axi_awsize;
    wire        cpu_axi_wvalid;
    wire        cpu_axi_wready;
    wire [BUS_WIDTH-1:0] cpu_axi_wdata;
    wire [BUS_WIDTH/8-1:0] cpu_axi_wstrb;
    wire        cpu_axi_wlast;
    wire        cpu_axi_bvalid;
    wire        cpu_axi_bready;
    wire [1:0]  cpu_axi_bresp;

    wire        cpu_bus_axi_arvalid;
    wire        cpu_bus_axi_arready;
    wire [REG_WIDTH-1:0] cpu_bus_axi_araddr;
    wire [3:0]  cpu_bus_axi_arcache;
    wire [2:0]  cpu_bus_axi_arprot;
    wire [1:0]  cpu_bus_axi_arlock;
    wire [1:0]  cpu_bus_axi_arburst;
    wire [7:0]  cpu_bus_axi_arlen;
    wire [2:0]  cpu_bus_axi_arsize;
    wire        cpu_bus_axi_rvalid;
    wire        cpu_bus_axi_rready;
    wire [BUS_WIDTH-1:0] cpu_bus_axi_rdata;
    wire [1:0]  cpu_bus_axi_rresp;
    wire        cpu_bus_axi_rlast;
    wire        cpu_bus_axi_awvalid;
    wire        cpu_bus_axi_awready;
    wire [REG_WIDTH-1:0] cpu_bus_axi_awaddr;
    wire [3:0]  cpu_bus_axi_awcache;
    wire [2:0]  cpu_bus_axi_awprot;
    wire [1:0]  cpu_bus_axi_awlock;
    wire [1:0]  cpu_bus_axi_awburst;
    wire [7:0]  cpu_bus_axi_awlen;
    wire [2:0]  cpu_bus_axi_awsize;
    wire        cpu_bus_axi_wvalid;
    wire        cpu_bus_axi_wready;
    wire [BUS_WIDTH-1:0] cpu_bus_axi_wdata;
    wire [BUS_WIDTH/8-1:0] cpu_bus_axi_wstrb;
    wire        cpu_bus_axi_wlast;
    wire        cpu_bus_axi_bvalid;
    wire        cpu_bus_axi_bready;
    wire [1:0]  cpu_bus_axi_bresp;

    wire        npu_axi_arvalid;
    wire        npu_axi_arready;
    wire [AXI_ADDR_WIDTH-1:0] npu_axi_araddr;
    wire [3:0]  npu_axi_arcache;
    wire [2:0]  npu_axi_arprot;
    wire [1:0]  npu_axi_arlock;
    wire [1:0]  npu_axi_arburst;
    wire [7:0]  npu_axi_arlen;
    wire [2:0]  npu_axi_arsize;
    wire        npu_axi_rvalid;
    wire        npu_axi_rready;
    wire [BUS_WIDTH-1:0] npu_axi_rdata;
    wire [1:0]  npu_axi_rresp;
    wire        npu_axi_rlast;
    wire        npu_axi_awvalid;
    wire        npu_axi_awready;
    wire [AXI_ADDR_WIDTH-1:0] npu_axi_awaddr;
    wire [3:0]  npu_axi_awcache;
    wire [2:0]  npu_axi_awprot;
    wire [1:0]  npu_axi_awlock;
    wire [1:0]  npu_axi_awburst;
    wire [7:0]  npu_axi_awlen;
    wire [2:0]  npu_axi_awsize;
    wire        npu_axi_wvalid;
    wire        npu_axi_wready;
    wire [BUS_WIDTH-1:0] npu_axi_wdata;
    wire [BUS_WIDTH/8-1:0] npu_axi_wstrb;
    wire        npu_axi_wlast;
    wire        npu_axi_bvalid;
    wire        npu_axi_bready;
    wire [1:0]  npu_axi_bresp;

    wire        npu_core_axi_arvalid;
    wire        npu_core_axi_arready;
    wire [AXI_ADDR_WIDTH-1:0] npu_core_axi_araddr;
    wire [3:0]  npu_core_axi_arcache;
    wire [2:0]  npu_core_axi_arprot;
    wire [1:0]  npu_core_axi_arlock;
    wire [1:0]  npu_core_axi_arburst;
    wire [7:0]  npu_core_axi_arlen;
    wire [2:0]  npu_core_axi_arsize;
    wire        npu_core_axi_rvalid;
    wire        npu_core_axi_rready;
    wire [BUS_WIDTH-1:0] npu_core_axi_rdata;
    wire [1:0]  npu_core_axi_rresp;
    wire        npu_core_axi_rlast;
    wire        npu_core_axi_awvalid;
    wire        npu_core_axi_awready;
    wire [AXI_ADDR_WIDTH-1:0] npu_core_axi_awaddr;
    wire [3:0]  npu_core_axi_awcache;
    wire [2:0]  npu_core_axi_awprot;
    wire [1:0]  npu_core_axi_awlock;
    wire [1:0]  npu_core_axi_awburst;
    wire [7:0]  npu_core_axi_awlen;
    wire [2:0]  npu_core_axi_awsize;
    wire        npu_core_axi_wvalid;
    wire        npu_core_axi_wready;
    wire [BUS_WIDTH-1:0] npu_core_axi_wdata;
    wire [BUS_WIDTH/8-1:0] npu_core_axi_wstrb;
    wire        npu_core_axi_wlast;
    wire        npu_core_axi_bvalid;
    wire        npu_core_axi_bready;
    wire [1:0]  npu_core_axi_bresp;

    wire        ram_axi_arvalid;
    wire        ram_axi_arready;
    wire [REG_WIDTH-1:0] ram_axi_araddr;
    wire [3:0]  ram_axi_arcache;
    wire [2:0]  ram_axi_arprot;
    wire [1:0]  ram_axi_arlock;
    wire [1:0]  ram_axi_arburst;
    wire [7:0]  ram_axi_arlen;
    wire [2:0]  ram_axi_arsize;
    wire        ram_axi_rvalid;
    wire        ram_axi_rready;
    wire [BUS_WIDTH-1:0] ram_axi_rdata;
    wire [1:0]  ram_axi_rresp;
    wire        ram_axi_rlast;
    wire        ram_axi_awvalid;
    wire        ram_axi_awready;
    wire [REG_WIDTH-1:0] ram_axi_awaddr;
    wire [3:0]  ram_axi_awcache;
    wire [2:0]  ram_axi_awprot;
    wire [1:0]  ram_axi_awlock;
    wire [1:0]  ram_axi_awburst;
    wire [7:0]  ram_axi_awlen;
    wire [2:0]  ram_axi_awsize;
    wire        ram_axi_wvalid;
    wire        ram_axi_wready;
    wire [BUS_WIDTH-1:0] ram_axi_wdata;
    wire [BUS_WIDTH/8-1:0] ram_axi_wstrb;
    wire        ram_axi_wlast;
    wire        ram_axi_bvalid;
    wire        ram_axi_bready;
    wire [1:0]  ram_axi_bresp;

    wire        ram_buf_axi_arvalid;
    wire        ram_buf_axi_arready;
    wire [REG_WIDTH-1:0] ram_buf_axi_araddr;
    wire [3:0]  ram_buf_axi_arcache;
    wire [2:0]  ram_buf_axi_arprot;
    wire [1:0]  ram_buf_axi_arlock;
    wire [1:0]  ram_buf_axi_arburst;
    wire [7:0]  ram_buf_axi_arlen;
    wire [2:0]  ram_buf_axi_arsize;
    wire        ram_buf_axi_rvalid;
    wire        ram_buf_axi_rready;
    wire [BUS_WIDTH-1:0] ram_buf_axi_rdata;
    wire [1:0]  ram_buf_axi_rresp;
    wire        ram_buf_axi_rlast;
    wire        ram_buf_axi_awvalid;
    wire        ram_buf_axi_awready;
    wire [REG_WIDTH-1:0] ram_buf_axi_awaddr;
    wire [3:0]  ram_buf_axi_awcache;
    wire [2:0]  ram_buf_axi_awprot;
    wire [1:0]  ram_buf_axi_awlock;
    wire [1:0]  ram_buf_axi_awburst;
    wire [7:0]  ram_buf_axi_awlen;
    wire [2:0]  ram_buf_axi_awsize;
    wire        ram_buf_axi_wvalid;
    wire        ram_buf_axi_wready;
    wire [BUS_WIDTH-1:0] ram_buf_axi_wdata;
    wire [BUS_WIDTH/8-1:0] ram_buf_axi_wstrb;
    wire        ram_buf_axi_wlast;
    wire        ram_buf_axi_bvalid;
    wire        ram_buf_axi_bready;
    wire [1:0]  ram_buf_axi_bresp;

    wire [AXIL_ADDR_WIDTH-1:0] npu_axil_awaddr;
    wire [2:0]  npu_axil_awprot;
    wire        npu_axil_awvalid;
    wire        npu_axil_awready;
    wire [31:0] npu_axil_wdata;
    wire [3:0]  npu_axil_wstrb;
    wire        npu_axil_wvalid;
    wire        npu_axil_wready;
    wire [1:0]  npu_axil_bresp;
    wire        npu_axil_bvalid;
    wire        npu_axil_bready;
    wire [AXIL_ADDR_WIDTH-1:0] npu_axil_araddr;
    wire [2:0]  npu_axil_arprot;
    wire        npu_axil_arvalid;
    wire        npu_axil_arready;
    wire [31:0] npu_axil_rdata;
    wire [1:0]  npu_axil_rresp;
    wire        npu_axil_rvalid;
    wire        npu_axil_rready;

    wire [AXIL_ADDR_WIDTH-1:0] npu_core_axil_awaddr;
    wire [2:0]  npu_core_axil_awprot;
    wire        npu_core_axil_awvalid;
    wire        npu_core_axil_awready;
    wire [31:0] npu_core_axil_wdata;
    wire [3:0]  npu_core_axil_wstrb;
    wire        npu_core_axil_wvalid;
    wire        npu_core_axil_wready;
    wire [1:0]  npu_core_axil_bresp;
    wire        npu_core_axil_bvalid;
    wire        npu_core_axil_bready;
    wire [AXIL_ADDR_WIDTH-1:0] npu_core_axil_araddr;
    wire [2:0]  npu_core_axil_arprot;
    wire        npu_core_axil_arvalid;
    wire        npu_core_axil_arready;
    wire [31:0] npu_core_axil_rdata;
    wire [1:0]  npu_core_axil_rresp;
    wire        npu_core_axil_rvalid;
    wire        npu_core_axil_rready;

    wire [31:0] uart_axil_awaddr;
    wire [2:0]  uart_axil_awprot;
    wire        uart_axil_awvalid;
    wire        uart_axil_awready;
    wire [31:0] uart_axil_wdata;
    wire [3:0]  uart_axil_wstrb;
    wire        uart_axil_wvalid;
    wire        uart_axil_wready;
    wire [1:0]  uart_axil_bresp;
    wire        uart_axil_bvalid;
    wire        uart_axil_bready;
    wire [31:0] uart_axil_araddr;
    wire [2:0]  uart_axil_arprot;
    wire        uart_axil_arvalid;
    wire        uart_axil_arready;
    wire [31:0] uart_axil_rdata;
    wire [1:0]  uart_axil_rresp;
    wire        uart_axil_rvalid;
    wire        uart_axil_rready;
    wire [31:0] uart_cfg_divider;
    wire [31:0] uart_core_axil_awaddr;
    wire [2:0]  uart_core_axil_awprot;
    wire        uart_core_axil_awvalid;
    wire        uart_core_axil_awready;
    wire [31:0] uart_core_axil_wdata;
    wire [3:0]  uart_core_axil_wstrb;
    wire        uart_core_axil_wvalid;
    wire        uart_core_axil_wready;
    wire [1:0]  uart_core_axil_bresp;
    wire        uart_core_axil_bvalid;
    wire        uart_core_axil_bready;
    wire [31:0] uart_core_axil_araddr;
    wire [2:0]  uart_core_axil_arprot;
    wire        uart_core_axil_arvalid;
    wire        uart_core_axil_arready;
    wire [31:0] uart_core_axil_rdata;
    wire [1:0]  uart_core_axil_rresp;
    wire        uart_core_axil_rvalid;
    wire        uart_core_axil_rready;

    wire [31:0] ctrl_axil_awaddr;
    wire [2:0]  ctrl_axil_awprot;
    wire        ctrl_axil_awvalid;
    wire        ctrl_axil_awready;
    wire [31:0] ctrl_axil_wdata;
    wire [3:0]  ctrl_axil_wstrb;
    wire        ctrl_axil_wvalid;
    wire        ctrl_axil_wready;
    wire [1:0]  ctrl_axil_bresp;
    wire        ctrl_axil_bvalid;
    wire        ctrl_axil_bready;
    wire [31:0] ctrl_axil_araddr;
    wire [2:0]  ctrl_axil_arprot;
    wire        ctrl_axil_arvalid;
    wire        ctrl_axil_arready;
    wire [31:0] ctrl_axil_rdata;
    wire [1:0]  ctrl_axil_rresp;
    wire        ctrl_axil_rvalid;
    wire        ctrl_axil_rready;
    wire [31:0] soc_progress;

    picorv32 #(
        .ENABLE_COUNTERS(1),
        .ENABLE_COUNTERS64(0),
        .ENABLE_REGS_16_31(1),
        .ENABLE_REGS_DUALPORT(1),
        .TWO_STAGE_SHIFT(1),
        .BARREL_SHIFTER(0),
        .TWO_CYCLE_COMPARE(0),
        .TWO_CYCLE_ALU(0),
        .COMPRESSED_ISA(0),
        .CATCH_MISALIGN(1),
        .CATCH_ILLINSN(1),
        .ENABLE_MUL(1),
        .ENABLE_DIV(1),
        .ENABLE_IRQ(0),
        .PROGADDR_RESET(CPU_RAM_BASE),
        .STACKADDR(CPU_RAM_BASE + (CPU_MEM_DP * 4))
    ) u_picorv32 (
        .clk(clk),
        .resetn(rst_n),
        .trap(cpu_trap),
        .mem_valid(pico_mem_valid),
        .mem_addr(pico_mem_addr),
        .mem_wdata(pico_mem_wdata),
        .mem_wstrb(pico_mem_wstrb),
        .mem_instr(pico_mem_instr),
        .mem_ready(pico_mem_ready),
        .mem_rdata(pico_mem_rdata),
        .mem_la_read(),
        .mem_la_write(),
        .mem_la_addr(),
        .mem_la_wdata(),
        .mem_la_wstrb(),
        .pcpi_valid(),
        .pcpi_insn(),
        .pcpi_rs1(),
        .pcpi_rs2(),
        .pcpi_wr(1'b0),
        .pcpi_rd(32'b0),
        .pcpi_wait(1'b0),
        .pcpi_ready(1'b0),
        .irq(32'b0),
        .eoi(),
        .trace_valid(),
        .trace_data()
    );

    pico_native_to_axi #(
        .ADDR_WIDTH(REG_WIDTH),
        .DATA_WIDTH(BUS_WIDTH),
        .ENABLE_ICACHE(CPU_ENABLE_ICACHE)
    ) u_pico_axi_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .mem_valid(pico_mem_valid),
        .mem_instr(pico_mem_instr),
        .mem_addr(pico_mem_addr),
        .mem_wdata(pico_mem_wdata),
        .mem_wstrb(pico_mem_wstrb),
        .mem_ready(pico_mem_ready),
        .mem_rdata(pico_mem_rdata),
        .m_axi_arvalid(cpu_axi_arvalid),
        .m_axi_arready(cpu_axi_arready),
        .m_axi_araddr(cpu_axi_araddr),
        .m_axi_arcache(cpu_axi_arcache),
        .m_axi_arprot(cpu_axi_arprot),
        .m_axi_arlock(cpu_axi_arlock),
        .m_axi_arburst(cpu_axi_arburst),
        .m_axi_arlen(cpu_axi_arlen),
        .m_axi_arsize(cpu_axi_arsize),
        .m_axi_awvalid(cpu_axi_awvalid),
        .m_axi_awready(cpu_axi_awready),
        .m_axi_awaddr(cpu_axi_awaddr),
        .m_axi_awcache(cpu_axi_awcache),
        .m_axi_awprot(cpu_axi_awprot),
        .m_axi_awlock(cpu_axi_awlock),
        .m_axi_awburst(cpu_axi_awburst),
        .m_axi_awlen(cpu_axi_awlen),
        .m_axi_awsize(cpu_axi_awsize),
        .m_axi_rvalid(cpu_axi_rvalid),
        .m_axi_rready(cpu_axi_rready),
        .m_axi_rdata(cpu_axi_rdata),
        .m_axi_rresp(cpu_axi_rresp),
        .m_axi_rlast(cpu_axi_rlast),
        .m_axi_wvalid(cpu_axi_wvalid),
        .m_axi_wready(cpu_axi_wready),
        .m_axi_wdata(cpu_axi_wdata),
        .m_axi_wstrb(cpu_axi_wstrb),
        .m_axi_wlast(cpu_axi_wlast),
        .m_axi_bvalid(cpu_axi_bvalid),
        .m_axi_bready(cpu_axi_bready),
        .m_axi_bresp(cpu_axi_bresp)
    );

    generate
        if (CPU_AXI_READ_TIMING_BUFFER) begin : g_cpu_axi_read_timing_buffer
            soc_axi_read_pingpong_buffer #(
                .ADDR_WIDTH(REG_WIDTH),
                .DATA_WIDTH(BUS_WIDTH)
            ) u_cpu_axi_read_pingpong (
                .clk(clk),
                .rst_n(rst_n),
                .s_axi_arvalid(cpu_axi_arvalid),
                .s_axi_arready(cpu_axi_arready),
                .s_axi_araddr(cpu_axi_araddr),
                .s_axi_arcache(cpu_axi_arcache),
                .s_axi_arprot(cpu_axi_arprot),
                .s_axi_arlock(cpu_axi_arlock),
                .s_axi_arburst(cpu_axi_arburst),
                .s_axi_arlen(cpu_axi_arlen),
                .s_axi_arsize(cpu_axi_arsize),
                .s_axi_rvalid(cpu_axi_rvalid),
                .s_axi_rready(cpu_axi_rready),
                .s_axi_rdata(cpu_axi_rdata),
                .s_axi_rresp(cpu_axi_rresp),
                .s_axi_rlast(cpu_axi_rlast),
                .m_axi_arvalid(cpu_bus_axi_arvalid),
                .m_axi_arready(cpu_bus_axi_arready),
                .m_axi_araddr(cpu_bus_axi_araddr),
                .m_axi_arcache(cpu_bus_axi_arcache),
                .m_axi_arprot(cpu_bus_axi_arprot),
                .m_axi_arlock(cpu_bus_axi_arlock),
                .m_axi_arburst(cpu_bus_axi_arburst),
                .m_axi_arlen(cpu_bus_axi_arlen),
                .m_axi_arsize(cpu_bus_axi_arsize),
                .m_axi_rvalid(cpu_bus_axi_rvalid),
                .m_axi_rready(cpu_bus_axi_rready),
                .m_axi_rdata(cpu_bus_axi_rdata),
                .m_axi_rresp(cpu_bus_axi_rresp),
                .m_axi_rlast(cpu_bus_axi_rlast)
            );
        end else begin : g_bypass_cpu_axi_read_timing_buffer
            assign cpu_bus_axi_arvalid = cpu_axi_arvalid;
            assign cpu_axi_arready     = cpu_bus_axi_arready;
            assign cpu_bus_axi_araddr  = cpu_axi_araddr;
            assign cpu_bus_axi_arcache = cpu_axi_arcache;
            assign cpu_bus_axi_arprot  = cpu_axi_arprot;
            assign cpu_bus_axi_arlock  = cpu_axi_arlock;
            assign cpu_bus_axi_arburst = cpu_axi_arburst;
            assign cpu_bus_axi_arlen   = cpu_axi_arlen;
            assign cpu_bus_axi_arsize  = cpu_axi_arsize;
            assign cpu_axi_rvalid      = cpu_bus_axi_rvalid;
            assign cpu_bus_axi_rready  = cpu_axi_rready;
            assign cpu_axi_rdata       = cpu_bus_axi_rdata;
            assign cpu_axi_rresp       = cpu_bus_axi_rresp;
            assign cpu_axi_rlast       = cpu_bus_axi_rlast;
        end
    endgenerate

    generate
        if (CPU_AXI_WRITE_TIMING_BUFFER) begin : g_cpu_axi_write_timing_buffer
            soc_axi_write_pingpong_buffer #(
                .ADDR_WIDTH(REG_WIDTH),
                .DATA_WIDTH(BUS_WIDTH)
            ) u_cpu_axi_write_pingpong (
                .clk(clk),
                .rst_n(rst_n),
                .s_axi_awvalid(cpu_axi_awvalid),
                .s_axi_awready(cpu_axi_awready),
                .s_axi_awaddr(cpu_axi_awaddr),
                .s_axi_awcache(cpu_axi_awcache),
                .s_axi_awprot(cpu_axi_awprot),
                .s_axi_awlock(cpu_axi_awlock),
                .s_axi_awburst(cpu_axi_awburst),
                .s_axi_awlen(cpu_axi_awlen),
                .s_axi_awsize(cpu_axi_awsize),
                .s_axi_wvalid(cpu_axi_wvalid),
                .s_axi_wready(cpu_axi_wready),
                .s_axi_wdata(cpu_axi_wdata),
                .s_axi_wstrb(cpu_axi_wstrb),
                .s_axi_wlast(cpu_axi_wlast),
                .s_axi_bvalid(cpu_axi_bvalid),
                .s_axi_bready(cpu_axi_bready),
                .s_axi_bresp(cpu_axi_bresp),
                .m_axi_awvalid(cpu_bus_axi_awvalid),
                .m_axi_awready(cpu_bus_axi_awready),
                .m_axi_awaddr(cpu_bus_axi_awaddr),
                .m_axi_awcache(cpu_bus_axi_awcache),
                .m_axi_awprot(cpu_bus_axi_awprot),
                .m_axi_awlock(cpu_bus_axi_awlock),
                .m_axi_awburst(cpu_bus_axi_awburst),
                .m_axi_awlen(cpu_bus_axi_awlen),
                .m_axi_awsize(cpu_bus_axi_awsize),
                .m_axi_wvalid(cpu_bus_axi_wvalid),
                .m_axi_wready(cpu_bus_axi_wready),
                .m_axi_wdata(cpu_bus_axi_wdata),
                .m_axi_wstrb(cpu_bus_axi_wstrb),
                .m_axi_wlast(cpu_bus_axi_wlast),
                .m_axi_bvalid(cpu_bus_axi_bvalid),
                .m_axi_bready(cpu_bus_axi_bready),
                .m_axi_bresp(cpu_bus_axi_bresp)
            );
        end else begin : g_bypass_cpu_axi_write_timing_buffer
            assign cpu_bus_axi_awvalid = cpu_axi_awvalid;
            assign cpu_axi_awready     = cpu_bus_axi_awready;
            assign cpu_bus_axi_awaddr  = cpu_axi_awaddr;
            assign cpu_bus_axi_awcache = cpu_axi_awcache;
            assign cpu_bus_axi_awprot  = cpu_axi_awprot;
            assign cpu_bus_axi_awlock  = cpu_axi_awlock;
            assign cpu_bus_axi_awburst = cpu_axi_awburst;
            assign cpu_bus_axi_awlen   = cpu_axi_awlen;
            assign cpu_bus_axi_awsize  = cpu_axi_awsize;
            assign cpu_bus_axi_wvalid  = cpu_axi_wvalid;
            assign cpu_axi_wready      = cpu_bus_axi_wready;
            assign cpu_bus_axi_wdata   = cpu_axi_wdata;
            assign cpu_bus_axi_wstrb   = cpu_axi_wstrb;
            assign cpu_bus_axi_wlast   = cpu_axi_wlast;
            assign cpu_axi_bvalid      = cpu_bus_axi_bvalid;
            assign cpu_bus_axi_bready  = cpu_axi_bready;
            assign cpu_axi_bresp       = cpu_bus_axi_bresp;
        end
    endgenerate

    soc_axi_interconnect #(
        .ADDR_WIDTH(REG_WIDTH),
        .DATA_WIDTH(BUS_WIDTH),
        .CPU_MEM_DP(CPU_MEM_DP),
        .READ_OUTSTANDING(AXI_READ_OUTSTANDING),
        .WRITE_OUTSTANDING(AXI_WRITE_OUTSTANDING),
        .CPU_RAM_BASE(CPU_RAM_BASE),
        .NPU_AXIL_BASE(NPU_AXIL_BASE),
        .UART_BASE(UART_BASE),
        .SOC_CTRL_BASE(SOC_CTRL_BASE)
    ) u_axi_interconnect (
        .clk(clk),
        .rst_n(rst_n),
        .npu_bus_lock(npu_busy),
        .s0_axi_arvalid(cpu_bus_axi_arvalid),
        .s0_axi_arready(cpu_bus_axi_arready),
        .s0_axi_araddr(cpu_bus_axi_araddr),
        .s0_axi_arcache(cpu_bus_axi_arcache),
        .s0_axi_arprot(cpu_bus_axi_arprot),
        .s0_axi_arlock(cpu_bus_axi_arlock),
        .s0_axi_arburst(cpu_bus_axi_arburst),
        .s0_axi_arlen(cpu_bus_axi_arlen),
        .s0_axi_arsize(cpu_bus_axi_arsize),
        .s0_axi_rvalid(cpu_bus_axi_rvalid),
        .s0_axi_rready(cpu_bus_axi_rready),
        .s0_axi_rdata(cpu_bus_axi_rdata),
        .s0_axi_rresp(cpu_bus_axi_rresp),
        .s0_axi_rlast(cpu_bus_axi_rlast),
        .s0_axi_awvalid(cpu_bus_axi_awvalid),
        .s0_axi_awready(cpu_bus_axi_awready),
        .s0_axi_awaddr(cpu_bus_axi_awaddr),
        .s0_axi_awcache(cpu_bus_axi_awcache),
        .s0_axi_awprot(cpu_bus_axi_awprot),
        .s0_axi_awlock(cpu_bus_axi_awlock),
        .s0_axi_awburst(cpu_bus_axi_awburst),
        .s0_axi_awlen(cpu_bus_axi_awlen),
        .s0_axi_awsize(cpu_bus_axi_awsize),
        .s0_axi_wvalid(cpu_bus_axi_wvalid),
        .s0_axi_wready(cpu_bus_axi_wready),
        .s0_axi_wdata(cpu_bus_axi_wdata),
        .s0_axi_wstrb(cpu_bus_axi_wstrb),
        .s0_axi_wlast(cpu_bus_axi_wlast),
        .s0_axi_bvalid(cpu_bus_axi_bvalid),
        .s0_axi_bready(cpu_bus_axi_bready),
        .s0_axi_bresp(cpu_bus_axi_bresp),
        .s1_axi_arvalid(npu_axi_arvalid),
        .s1_axi_arready(npu_axi_arready),
        .s1_axi_araddr(npu_axi_araddr),
        .s1_axi_arcache(npu_axi_arcache),
        .s1_axi_arprot(npu_axi_arprot),
        .s1_axi_arlock(npu_axi_arlock),
        .s1_axi_arburst(npu_axi_arburst),
        .s1_axi_arlen(npu_axi_arlen),
        .s1_axi_arsize(npu_axi_arsize),
        .s1_axi_rvalid(npu_axi_rvalid),
        .s1_axi_rready(npu_axi_rready),
        .s1_axi_rdata(npu_axi_rdata),
        .s1_axi_rresp(npu_axi_rresp),
        .s1_axi_rlast(npu_axi_rlast),
        .s1_axi_awvalid(npu_axi_awvalid),
        .s1_axi_awready(npu_axi_awready),
        .s1_axi_awaddr(npu_axi_awaddr),
        .s1_axi_awcache(npu_axi_awcache),
        .s1_axi_awprot(npu_axi_awprot),
        .s1_axi_awlock(npu_axi_awlock),
        .s1_axi_awburst(npu_axi_awburst),
        .s1_axi_awlen(npu_axi_awlen),
        .s1_axi_awsize(npu_axi_awsize),
        .s1_axi_wvalid(npu_axi_wvalid),
        .s1_axi_wready(npu_axi_wready),
        .s1_axi_wdata(npu_axi_wdata),
        .s1_axi_wstrb(npu_axi_wstrb),
        .s1_axi_wlast(npu_axi_wlast),
        .s1_axi_bvalid(npu_axi_bvalid),
        .s1_axi_bready(npu_axi_bready),
        .s1_axi_bresp(npu_axi_bresp),
        .m_ram_arvalid(ram_axi_arvalid),
        .m_ram_arready(ram_axi_arready),
        .m_ram_araddr(ram_axi_araddr),
        .m_ram_arcache(ram_axi_arcache),
        .m_ram_arprot(ram_axi_arprot),
        .m_ram_arlock(ram_axi_arlock),
        .m_ram_arburst(ram_axi_arburst),
        .m_ram_arlen(ram_axi_arlen),
        .m_ram_arsize(ram_axi_arsize),
        .m_ram_rvalid(ram_axi_rvalid),
        .m_ram_rready(ram_axi_rready),
        .m_ram_rdata(ram_axi_rdata),
        .m_ram_rresp(ram_axi_rresp),
        .m_ram_rlast(ram_axi_rlast),
        .m_ram_awvalid(ram_axi_awvalid),
        .m_ram_awready(ram_axi_awready),
        .m_ram_awaddr(ram_axi_awaddr),
        .m_ram_awcache(ram_axi_awcache),
        .m_ram_awprot(ram_axi_awprot),
        .m_ram_awlock(ram_axi_awlock),
        .m_ram_awburst(ram_axi_awburst),
        .m_ram_awlen(ram_axi_awlen),
        .m_ram_awsize(ram_axi_awsize),
        .m_ram_wvalid(ram_axi_wvalid),
        .m_ram_wready(ram_axi_wready),
        .m_ram_wdata(ram_axi_wdata),
        .m_ram_wstrb(ram_axi_wstrb),
        .m_ram_wlast(ram_axi_wlast),
        .m_ram_bvalid(ram_axi_bvalid),
        .m_ram_bready(ram_axi_bready),
        .m_ram_bresp(ram_axi_bresp),
        .m_npu_awaddr(npu_axil_awaddr),
        .m_npu_awprot(npu_axil_awprot),
        .m_npu_awvalid(npu_axil_awvalid),
        .m_npu_awready(npu_axil_awready),
        .m_npu_wdata(npu_axil_wdata),
        .m_npu_wstrb(npu_axil_wstrb),
        .m_npu_wvalid(npu_axil_wvalid),
        .m_npu_wready(npu_axil_wready),
        .m_npu_bresp(npu_axil_bresp),
        .m_npu_bvalid(npu_axil_bvalid),
        .m_npu_bready(npu_axil_bready),
        .m_npu_araddr(npu_axil_araddr),
        .m_npu_arprot(npu_axil_arprot),
        .m_npu_arvalid(npu_axil_arvalid),
        .m_npu_arready(npu_axil_arready),
        .m_npu_rdata(npu_axil_rdata),
        .m_npu_rresp(npu_axil_rresp),
        .m_npu_rvalid(npu_axil_rvalid),
        .m_npu_rready(npu_axil_rready),
        .m_uart_awaddr(uart_axil_awaddr),
        .m_uart_awprot(uart_axil_awprot),
        .m_uart_awvalid(uart_axil_awvalid),
        .m_uart_awready(uart_axil_awready),
        .m_uart_wdata(uart_axil_wdata),
        .m_uart_wstrb(uart_axil_wstrb),
        .m_uart_wvalid(uart_axil_wvalid),
        .m_uart_wready(uart_axil_wready),
        .m_uart_bresp(uart_axil_bresp),
        .m_uart_bvalid(uart_axil_bvalid),
        .m_uart_bready(uart_axil_bready),
        .m_uart_araddr(uart_axil_araddr),
        .m_uart_arprot(uart_axil_arprot),
        .m_uart_arvalid(uart_axil_arvalid),
        .m_uart_arready(uart_axil_arready),
        .m_uart_rdata(uart_axil_rdata),
        .m_uart_rresp(uart_axil_rresp),
        .m_uart_rvalid(uart_axil_rvalid),
        .m_uart_rready(uart_axil_rready),
        .m_ctrl_awaddr(ctrl_axil_awaddr),
        .m_ctrl_awprot(ctrl_axil_awprot),
        .m_ctrl_awvalid(ctrl_axil_awvalid),
        .m_ctrl_awready(ctrl_axil_awready),
        .m_ctrl_wdata(ctrl_axil_wdata),
        .m_ctrl_wstrb(ctrl_axil_wstrb),
        .m_ctrl_wvalid(ctrl_axil_wvalid),
        .m_ctrl_wready(ctrl_axil_wready),
        .m_ctrl_bresp(ctrl_axil_bresp),
        .m_ctrl_bvalid(ctrl_axil_bvalid),
        .m_ctrl_bready(ctrl_axil_bready),
        .m_ctrl_araddr(ctrl_axil_araddr),
        .m_ctrl_arprot(ctrl_axil_arprot),
        .m_ctrl_arvalid(ctrl_axil_arvalid),
        .m_ctrl_arready(ctrl_axil_arready),
        .m_ctrl_rdata(ctrl_axil_rdata),
        .m_ctrl_rresp(ctrl_axil_rresp),
        .m_ctrl_rvalid(ctrl_axil_rvalid),
        .m_ctrl_rready(ctrl_axil_rready)
    );

    soc_axil_pingpong_buffer #(
        .ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .DATA_WIDTH(AXIL_DATA_WIDTH)
    ) u_npu_axil_pingpong (
        .clk(clk),
        .rst_n(rst_n),
        .s_axil_awaddr(npu_axil_awaddr),
        .s_axil_awprot(npu_axil_awprot),
        .s_axil_awvalid(npu_axil_awvalid),
        .s_axil_awready(npu_axil_awready),
        .s_axil_wdata(npu_axil_wdata),
        .s_axil_wstrb(npu_axil_wstrb),
        .s_axil_wvalid(npu_axil_wvalid),
        .s_axil_wready(npu_axil_wready),
        .s_axil_bresp(npu_axil_bresp),
        .s_axil_bvalid(npu_axil_bvalid),
        .s_axil_bready(npu_axil_bready),
        .s_axil_araddr(npu_axil_araddr),
        .s_axil_arprot(npu_axil_arprot),
        .s_axil_arvalid(npu_axil_arvalid),
        .s_axil_arready(npu_axil_arready),
        .s_axil_rdata(npu_axil_rdata),
        .s_axil_rresp(npu_axil_rresp),
        .s_axil_rvalid(npu_axil_rvalid),
        .s_axil_rready(npu_axil_rready),
        .m_axil_awaddr(npu_core_axil_awaddr),
        .m_axil_awprot(npu_core_axil_awprot),
        .m_axil_awvalid(npu_core_axil_awvalid),
        .m_axil_awready(npu_core_axil_awready),
        .m_axil_wdata(npu_core_axil_wdata),
        .m_axil_wstrb(npu_core_axil_wstrb),
        .m_axil_wvalid(npu_core_axil_wvalid),
        .m_axil_wready(npu_core_axil_wready),
        .m_axil_bresp(npu_core_axil_bresp),
        .m_axil_bvalid(npu_core_axil_bvalid),
        .m_axil_bready(npu_core_axil_bready),
        .m_axil_araddr(npu_core_axil_araddr),
        .m_axil_arprot(npu_core_axil_arprot),
        .m_axil_arvalid(npu_core_axil_arvalid),
        .m_axil_arready(npu_core_axil_arready),
        .m_axil_rdata(npu_core_axil_rdata),
        .m_axil_rresp(npu_core_axil_rresp),
        .m_axil_rvalid(npu_core_axil_rvalid),
        .m_axil_rready(npu_core_axil_rready)
    );

    npu_axil_top #(
        .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .BUS_WIDTH(BUS_WIDTH),
        .REG_WIDTH(REG_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .NPU_ADDR_WIDTH(NPU_ADDR_WIDTH),
        .IA_CACHE_BLOCKS(IA_CACHE_BLOCKS),
        .PS_FRAME_COUNT(PS_FRAME_COUNT),
        .AXI_READ_OUTSTANDING(AXI_READ_OUTSTANDING),
        .AXI_WRITE_OUTSTANDING(AXI_WRITE_OUTSTANDING),
        .ENABLE_IS_MODE(NPU_ENABLE_IS_MODE),
        .ENABLE_PER_CHANNEL(NPU_ENABLE_PER_CHANNEL),
        .ENABLE_CLOCK_GATING(NPU_ENABLE_CLOCK_GATING)
    ) u_npu_axil_top (
        .clk(clk),
        .rst_n(rst_n),
        .s_axil_awaddr(npu_core_axil_awaddr),
        .s_axil_awprot(npu_core_axil_awprot),
        .s_axil_awvalid(npu_core_axil_awvalid),
        .s_axil_awready(npu_core_axil_awready),
        .s_axil_wdata(npu_core_axil_wdata),
        .s_axil_wstrb(npu_core_axil_wstrb),
        .s_axil_wvalid(npu_core_axil_wvalid),
        .s_axil_wready(npu_core_axil_wready),
        .s_axil_bresp(npu_core_axil_bresp),
        .s_axil_bvalid(npu_core_axil_bvalid),
        .s_axil_bready(npu_core_axil_bready),
        .s_axil_araddr(npu_core_axil_araddr),
        .s_axil_arprot(npu_core_axil_arprot),
        .s_axil_arvalid(npu_core_axil_arvalid),
        .s_axil_arready(npu_core_axil_arready),
        .s_axil_rdata(npu_core_axil_rdata),
        .s_axil_rresp(npu_core_axil_rresp),
        .s_axil_rvalid(npu_core_axil_rvalid),
        .s_axil_rready(npu_core_axil_rready),
        .m_axi_arvalid(npu_core_axi_arvalid),
        .m_axi_arready(npu_core_axi_arready),
        .m_axi_araddr(npu_core_axi_araddr),
        .m_axi_arcache(npu_core_axi_arcache),
        .m_axi_arprot(npu_core_axi_arprot),
        .m_axi_arlock(npu_core_axi_arlock),
        .m_axi_arburst(npu_core_axi_arburst),
        .m_axi_arlen(npu_core_axi_arlen),
        .m_axi_arsize(npu_core_axi_arsize),
        .m_axi_awvalid(npu_core_axi_awvalid),
        .m_axi_awready(npu_core_axi_awready),
        .m_axi_awaddr(npu_core_axi_awaddr),
        .m_axi_awcache(npu_core_axi_awcache),
        .m_axi_awprot(npu_core_axi_awprot),
        .m_axi_awlock(npu_core_axi_awlock),
        .m_axi_awburst(npu_core_axi_awburst),
        .m_axi_awlen(npu_core_axi_awlen),
        .m_axi_awsize(npu_core_axi_awsize),
        .m_axi_rvalid(npu_core_axi_rvalid),
        .m_axi_rready(npu_core_axi_rready),
        .m_axi_rdata(npu_core_axi_rdata),
        .m_axi_rresp(npu_core_axi_rresp),
        .m_axi_rlast(npu_core_axi_rlast),
        .m_axi_wvalid(npu_core_axi_wvalid),
        .m_axi_wready(npu_core_axi_wready),
        .m_axi_wdata(npu_core_axi_wdata),
        .m_axi_wstrb(npu_core_axi_wstrb),
        .m_axi_wlast(npu_core_axi_wlast),
        .m_axi_bvalid(npu_core_axi_bvalid),
        .m_axi_bready(npu_core_axi_bready),
        .m_axi_bresp(npu_core_axi_bresp),
        .irq(npu_irq),
        .npu_busy(npu_busy)
    );

    generate
        if (NPU_AXI_TIMING_BUFFER) begin : g_npu_axi_timing_buffer
            soc_axi_pingpong_buffer #(
                .ADDR_WIDTH(AXI_ADDR_WIDTH),
                .DATA_WIDTH(BUS_WIDTH)
            ) u_npu_axi_pingpong (
                .clk(clk),
                .rst_n(rst_n),
                .s_axi_arvalid(npu_core_axi_arvalid),
                .s_axi_arready(npu_core_axi_arready),
                .s_axi_araddr(npu_core_axi_araddr),
                .s_axi_arcache(npu_core_axi_arcache),
                .s_axi_arprot(npu_core_axi_arprot),
                .s_axi_arlock(npu_core_axi_arlock),
                .s_axi_arburst(npu_core_axi_arburst),
                .s_axi_arlen(npu_core_axi_arlen),
                .s_axi_arsize(npu_core_axi_arsize),
                .s_axi_rvalid(npu_core_axi_rvalid),
                .s_axi_rready(npu_core_axi_rready),
                .s_axi_rdata(npu_core_axi_rdata),
                .s_axi_rresp(npu_core_axi_rresp),
                .s_axi_rlast(npu_core_axi_rlast),
                .s_axi_awvalid(npu_core_axi_awvalid),
                .s_axi_awready(npu_core_axi_awready),
                .s_axi_awaddr(npu_core_axi_awaddr),
                .s_axi_awcache(npu_core_axi_awcache),
                .s_axi_awprot(npu_core_axi_awprot),
                .s_axi_awlock(npu_core_axi_awlock),
                .s_axi_awburst(npu_core_axi_awburst),
                .s_axi_awlen(npu_core_axi_awlen),
                .s_axi_awsize(npu_core_axi_awsize),
                .s_axi_wvalid(npu_core_axi_wvalid),
                .s_axi_wready(npu_core_axi_wready),
                .s_axi_wdata(npu_core_axi_wdata),
                .s_axi_wstrb(npu_core_axi_wstrb),
                .s_axi_wlast(npu_core_axi_wlast),
                .s_axi_bvalid(npu_core_axi_bvalid),
                .s_axi_bready(npu_core_axi_bready),
                .s_axi_bresp(npu_core_axi_bresp),
                .m_axi_arvalid(npu_axi_arvalid),
                .m_axi_arready(npu_axi_arready),
                .m_axi_araddr(npu_axi_araddr),
                .m_axi_arcache(npu_axi_arcache),
                .m_axi_arprot(npu_axi_arprot),
                .m_axi_arlock(npu_axi_arlock),
                .m_axi_arburst(npu_axi_arburst),
                .m_axi_arlen(npu_axi_arlen),
                .m_axi_arsize(npu_axi_arsize),
                .m_axi_rvalid(npu_axi_rvalid),
                .m_axi_rready(npu_axi_rready),
                .m_axi_rdata(npu_axi_rdata),
                .m_axi_rresp(npu_axi_rresp),
                .m_axi_rlast(npu_axi_rlast),
                .m_axi_awvalid(npu_axi_awvalid),
                .m_axi_awready(npu_axi_awready),
                .m_axi_awaddr(npu_axi_awaddr),
                .m_axi_awcache(npu_axi_awcache),
                .m_axi_awprot(npu_axi_awprot),
                .m_axi_awlock(npu_axi_awlock),
                .m_axi_awburst(npu_axi_awburst),
                .m_axi_awlen(npu_axi_awlen),
                .m_axi_awsize(npu_axi_awsize),
                .m_axi_wvalid(npu_axi_wvalid),
                .m_axi_wready(npu_axi_wready),
                .m_axi_wdata(npu_axi_wdata),
                .m_axi_wstrb(npu_axi_wstrb),
                .m_axi_wlast(npu_axi_wlast),
                .m_axi_bvalid(npu_axi_bvalid),
                .m_axi_bready(npu_axi_bready),
                .m_axi_bresp(npu_axi_bresp)
            );
        end else begin : g_bypass_npu_axi_timing_buffer
            assign npu_axi_arvalid      = npu_core_axi_arvalid;
            assign npu_core_axi_arready = npu_axi_arready;
            assign npu_axi_araddr       = npu_core_axi_araddr;
            assign npu_axi_arcache      = npu_core_axi_arcache;
            assign npu_axi_arprot       = npu_core_axi_arprot;
            assign npu_axi_arlock       = npu_core_axi_arlock;
            assign npu_axi_arburst      = npu_core_axi_arburst;
            assign npu_axi_arlen        = npu_core_axi_arlen;
            assign npu_axi_arsize       = npu_core_axi_arsize;
            assign npu_core_axi_rvalid  = npu_axi_rvalid;
            assign npu_axi_rready       = npu_core_axi_rready;
            assign npu_core_axi_rdata   = npu_axi_rdata;
            assign npu_core_axi_rresp   = npu_axi_rresp;
            assign npu_core_axi_rlast   = npu_axi_rlast;

            assign npu_axi_awvalid      = npu_core_axi_awvalid;
            assign npu_core_axi_awready = npu_axi_awready;
            assign npu_axi_awaddr       = npu_core_axi_awaddr;
            assign npu_axi_awcache      = npu_core_axi_awcache;
            assign npu_axi_awprot       = npu_core_axi_awprot;
            assign npu_axi_awlock       = npu_core_axi_awlock;
            assign npu_axi_awburst      = npu_core_axi_awburst;
            assign npu_axi_awlen        = npu_core_axi_awlen;
            assign npu_axi_awsize       = npu_core_axi_awsize;
            assign npu_axi_wvalid       = npu_core_axi_wvalid;
            assign npu_core_axi_wready  = npu_axi_wready;
            assign npu_axi_wdata        = npu_core_axi_wdata;
            assign npu_axi_wstrb        = npu_core_axi_wstrb;
            assign npu_axi_wlast        = npu_core_axi_wlast;
            assign npu_core_axi_bvalid  = npu_axi_bvalid;
            assign npu_axi_bready       = npu_core_axi_bready;
            assign npu_core_axi_bresp   = npu_axi_bresp;
        end
    endgenerate

    generate
        if (BYPASS_RAM_PINGPONG) begin : g_bypass_ram_pingpong
            assign ram_buf_axi_arvalid = ram_axi_arvalid;
            assign ram_axi_arready     = ram_buf_axi_arready;
            assign ram_buf_axi_araddr  = ram_axi_araddr;
            assign ram_buf_axi_arcache = ram_axi_arcache;
            assign ram_buf_axi_arprot  = ram_axi_arprot;
            assign ram_buf_axi_arlock  = ram_axi_arlock;
            assign ram_buf_axi_arburst = ram_axi_arburst;
            assign ram_buf_axi_arlen   = ram_axi_arlen;
            assign ram_buf_axi_arsize  = ram_axi_arsize;
            assign ram_axi_rvalid      = ram_buf_axi_rvalid;
            assign ram_buf_axi_rready  = ram_axi_rready;
            assign ram_axi_rdata       = ram_buf_axi_rdata;
            assign ram_axi_rresp       = ram_buf_axi_rresp;
            assign ram_axi_rlast       = ram_buf_axi_rlast;

            if (RAM_WRITE_TIMING_BUFFER) begin : g_ram_write_timing_buffer
                soc_axi_write_pingpong_buffer #(
                    .ADDR_WIDTH(REG_WIDTH),
                    .DATA_WIDTH(BUS_WIDTH)
                ) u_ram_axi_write_pingpong (
                    .clk(clk),
                    .rst_n(rst_n),
                    .s_axi_awvalid(ram_axi_awvalid),
                    .s_axi_awready(ram_axi_awready),
                    .s_axi_awaddr(ram_axi_awaddr),
                    .s_axi_awcache(ram_axi_awcache),
                    .s_axi_awprot(ram_axi_awprot),
                    .s_axi_awlock(ram_axi_awlock),
                    .s_axi_awburst(ram_axi_awburst),
                    .s_axi_awlen(ram_axi_awlen),
                    .s_axi_awsize(ram_axi_awsize),
                    .s_axi_wvalid(ram_axi_wvalid),
                    .s_axi_wready(ram_axi_wready),
                    .s_axi_wdata(ram_axi_wdata),
                    .s_axi_wstrb(ram_axi_wstrb),
                    .s_axi_wlast(ram_axi_wlast),
                    .s_axi_bvalid(ram_axi_bvalid),
                    .s_axi_bready(ram_axi_bready),
                    .s_axi_bresp(ram_axi_bresp),
                    .m_axi_awvalid(ram_buf_axi_awvalid),
                    .m_axi_awready(ram_buf_axi_awready),
                    .m_axi_awaddr(ram_buf_axi_awaddr),
                    .m_axi_awcache(ram_buf_axi_awcache),
                    .m_axi_awprot(ram_buf_axi_awprot),
                    .m_axi_awlock(ram_buf_axi_awlock),
                    .m_axi_awburst(ram_buf_axi_awburst),
                    .m_axi_awlen(ram_buf_axi_awlen),
                    .m_axi_awsize(ram_buf_axi_awsize),
                    .m_axi_wvalid(ram_buf_axi_wvalid),
                    .m_axi_wready(ram_buf_axi_wready),
                    .m_axi_wdata(ram_buf_axi_wdata),
                    .m_axi_wstrb(ram_buf_axi_wstrb),
                    .m_axi_wlast(ram_buf_axi_wlast),
                    .m_axi_bvalid(ram_buf_axi_bvalid),
                    .m_axi_bready(ram_buf_axi_bready),
                    .m_axi_bresp(ram_buf_axi_bresp)
                );
            end else begin : g_bypass_ram_write
                assign ram_buf_axi_awvalid = ram_axi_awvalid;
                assign ram_axi_awready     = ram_buf_axi_awready;
                assign ram_buf_axi_awaddr  = ram_axi_awaddr;
                assign ram_buf_axi_awcache = ram_axi_awcache;
                assign ram_buf_axi_awprot  = ram_axi_awprot;
                assign ram_buf_axi_awlock  = ram_axi_awlock;
                assign ram_buf_axi_awburst = ram_axi_awburst;
                assign ram_buf_axi_awlen   = ram_axi_awlen;
                assign ram_buf_axi_awsize  = ram_axi_awsize;
                assign ram_buf_axi_wvalid  = ram_axi_wvalid;
                assign ram_axi_wready      = ram_buf_axi_wready;
                assign ram_buf_axi_wdata   = ram_axi_wdata;
                assign ram_buf_axi_wstrb   = ram_axi_wstrb;
                assign ram_buf_axi_wlast   = ram_axi_wlast;
                assign ram_axi_bvalid      = ram_buf_axi_bvalid;
                assign ram_buf_axi_bready  = ram_axi_bready;
                assign ram_axi_bresp       = ram_buf_axi_bresp;
            end
        end else begin : g_ram_pingpong
            soc_axi_pingpong_buffer #(
                .ADDR_WIDTH(REG_WIDTH),
                .DATA_WIDTH(BUS_WIDTH)
            ) u_ram_axi_pingpong (
                .clk(clk),
                .rst_n(rst_n),
                .s_axi_arvalid(ram_axi_arvalid),
                .s_axi_arready(ram_axi_arready),
                .s_axi_araddr(ram_axi_araddr),
                .s_axi_arcache(ram_axi_arcache),
                .s_axi_arprot(ram_axi_arprot),
                .s_axi_arlock(ram_axi_arlock),
                .s_axi_arburst(ram_axi_arburst),
                .s_axi_arlen(ram_axi_arlen),
                .s_axi_arsize(ram_axi_arsize),
                .s_axi_rvalid(ram_axi_rvalid),
                .s_axi_rready(ram_axi_rready),
                .s_axi_rdata(ram_axi_rdata),
                .s_axi_rresp(ram_axi_rresp),
                .s_axi_rlast(ram_axi_rlast),
                .s_axi_awvalid(ram_axi_awvalid),
                .s_axi_awready(ram_axi_awready),
                .s_axi_awaddr(ram_axi_awaddr),
                .s_axi_awcache(ram_axi_awcache),
                .s_axi_awprot(ram_axi_awprot),
                .s_axi_awlock(ram_axi_awlock),
                .s_axi_awburst(ram_axi_awburst),
                .s_axi_awlen(ram_axi_awlen),
                .s_axi_awsize(ram_axi_awsize),
                .s_axi_wvalid(ram_axi_wvalid),
                .s_axi_wready(ram_axi_wready),
                .s_axi_wdata(ram_axi_wdata),
                .s_axi_wstrb(ram_axi_wstrb),
                .s_axi_wlast(ram_axi_wlast),
                .s_axi_bvalid(ram_axi_bvalid),
                .s_axi_bready(ram_axi_bready),
                .s_axi_bresp(ram_axi_bresp),
                .m_axi_arvalid(ram_buf_axi_arvalid),
                .m_axi_arready(ram_buf_axi_arready),
                .m_axi_araddr(ram_buf_axi_araddr),
                .m_axi_arcache(ram_buf_axi_arcache),
                .m_axi_arprot(ram_buf_axi_arprot),
                .m_axi_arlock(ram_buf_axi_arlock),
                .m_axi_arburst(ram_buf_axi_arburst),
                .m_axi_arlen(ram_buf_axi_arlen),
                .m_axi_arsize(ram_buf_axi_arsize),
                .m_axi_rvalid(ram_buf_axi_rvalid),
                .m_axi_rready(ram_buf_axi_rready),
                .m_axi_rdata(ram_buf_axi_rdata),
                .m_axi_rresp(ram_buf_axi_rresp),
                .m_axi_rlast(ram_buf_axi_rlast),
                .m_axi_awvalid(ram_buf_axi_awvalid),
                .m_axi_awready(ram_buf_axi_awready),
                .m_axi_awaddr(ram_buf_axi_awaddr),
                .m_axi_awcache(ram_buf_axi_awcache),
                .m_axi_awprot(ram_buf_axi_awprot),
                .m_axi_awlock(ram_buf_axi_awlock),
                .m_axi_awburst(ram_buf_axi_awburst),
                .m_axi_awlen(ram_buf_axi_awlen),
                .m_axi_awsize(ram_buf_axi_awsize),
                .m_axi_wvalid(ram_buf_axi_wvalid),
                .m_axi_wready(ram_buf_axi_wready),
                .m_axi_wdata(ram_buf_axi_wdata),
                .m_axi_wstrb(ram_buf_axi_wstrb),
                .m_axi_wlast(ram_buf_axi_wlast),
                .m_axi_bvalid(ram_buf_axi_bvalid),
                .m_axi_bready(ram_buf_axi_bready),
                .m_axi_bresp(ram_buf_axi_bresp)
            );
        end
    endgenerate

    soc_axi_ram #(
        .DP(CPU_MEM_DP),
        .DW(BUS_WIDTH),
        .AW(REG_WIDTH),
        .MEM_PATH(CPU_MEM_PATH),
        .INIT_EN(CPU_MEM_INIT_EN),
        .READ_OUTSTANDING(AXI_READ_OUTSTANDING),
        .WRITE_OUTSTANDING(AXI_WRITE_OUTSTANDING)
    ) u_axi_sim_ram (
        .clk(clk),
        .rst_n(rst_n),
        .s_axi_awvalid(ram_buf_axi_awvalid),
        .s_axi_awready(ram_buf_axi_awready),
        .s_axi_awaddr(ram_buf_axi_awaddr),
        .s_axi_awcache(ram_buf_axi_awcache),
        .s_axi_awprot(ram_buf_axi_awprot),
        .s_axi_awlock(ram_buf_axi_awlock),
        .s_axi_awburst(ram_buf_axi_awburst),
        .s_axi_awlen(ram_buf_axi_awlen),
        .s_axi_awsize(ram_buf_axi_awsize),
        .s_axi_wvalid(ram_buf_axi_wvalid),
        .s_axi_wready(ram_buf_axi_wready),
        .s_axi_wdata(ram_buf_axi_wdata),
        .s_axi_wstrb(ram_buf_axi_wstrb),
        .s_axi_wlast(ram_buf_axi_wlast),
        .s_axi_bvalid(ram_buf_axi_bvalid),
        .s_axi_bready(ram_buf_axi_bready),
        .s_axi_bresp(ram_buf_axi_bresp),
        .s_axi_arvalid(ram_buf_axi_arvalid),
        .s_axi_arready(ram_buf_axi_arready),
        .s_axi_araddr(ram_buf_axi_araddr),
        .s_axi_arcache(ram_buf_axi_arcache),
        .s_axi_arprot(ram_buf_axi_arprot),
        .s_axi_arlock(ram_buf_axi_arlock),
        .s_axi_arburst(ram_buf_axi_arburst),
        .s_axi_arlen(ram_buf_axi_arlen),
        .s_axi_arsize(ram_buf_axi_arsize),
        .s_axi_rvalid(ram_buf_axi_rvalid),
        .s_axi_rready(ram_buf_axi_rready),
        .s_axi_rdata(ram_buf_axi_rdata),
        .s_axi_rresp(ram_buf_axi_rresp),
        .s_axi_rlast(ram_buf_axi_rlast),
        .mem_reload_req(mem_reload_req)
    );

    soc_axil_pingpong_buffer #(
        .ADDR_WIDTH(REG_WIDTH),
        .DATA_WIDTH(BUS_WIDTH)
    ) u_uart_axil_pingpong (
        .clk(clk),
        .rst_n(rst_n),
        .s_axil_awaddr(uart_axil_awaddr),
        .s_axil_awprot(uart_axil_awprot),
        .s_axil_awvalid(uart_axil_awvalid),
        .s_axil_awready(uart_axil_awready),
        .s_axil_wdata(uart_axil_wdata),
        .s_axil_wstrb(uart_axil_wstrb),
        .s_axil_wvalid(uart_axil_wvalid),
        .s_axil_wready(uart_axil_wready),
        .s_axil_bresp(uart_axil_bresp),
        .s_axil_bvalid(uart_axil_bvalid),
        .s_axil_bready(uart_axil_bready),
        .s_axil_araddr(uart_axil_araddr),
        .s_axil_arprot(uart_axil_arprot),
        .s_axil_arvalid(uart_axil_arvalid),
        .s_axil_arready(uart_axil_arready),
        .s_axil_rdata(uart_axil_rdata),
        .s_axil_rresp(uart_axil_rresp),
        .s_axil_rvalid(uart_axil_rvalid),
        .s_axil_rready(uart_axil_rready),
        .m_axil_awaddr(uart_core_axil_awaddr),
        .m_axil_awprot(uart_core_axil_awprot),
        .m_axil_awvalid(uart_core_axil_awvalid),
        .m_axil_awready(uart_core_axil_awready),
        .m_axil_wdata(uart_core_axil_wdata),
        .m_axil_wstrb(uart_core_axil_wstrb),
        .m_axil_wvalid(uart_core_axil_wvalid),
        .m_axil_wready(uart_core_axil_wready),
        .m_axil_bresp(uart_core_axil_bresp),
        .m_axil_bvalid(uart_core_axil_bvalid),
        .m_axil_bready(uart_core_axil_bready),
        .m_axil_araddr(uart_core_axil_araddr),
        .m_axil_arprot(uart_core_axil_arprot),
        .m_axil_arvalid(uart_core_axil_arvalid),
        .m_axil_arready(uart_core_axil_arready),
        .m_axil_rdata(uart_core_axil_rdata),
        .m_axil_rresp(uart_core_axil_rresp),
        .m_axil_rvalid(uart_core_axil_rvalid),
        .m_axil_rready(uart_core_axil_rready)
    );

    soc_axil_simpleuart #(
        .AXIL_ADDR_WIDTH(REG_WIDTH),
        .AXIL_DATA_WIDTH(BUS_WIDTH)
    ) u_soc_uart (
        .clk(clk),
        .rst_n(rst_n),
        .s_axil_awaddr(uart_core_axil_awaddr),
        .s_axil_awprot(uart_core_axil_awprot),
        .s_axil_awvalid(uart_core_axil_awvalid),
        .s_axil_awready(uart_core_axil_awready),
        .s_axil_wdata(uart_core_axil_wdata),
        .s_axil_wstrb(uart_core_axil_wstrb),
        .s_axil_wvalid(uart_core_axil_wvalid),
        .s_axil_wready(uart_core_axil_wready),
        .s_axil_bresp(uart_core_axil_bresp),
        .s_axil_bvalid(uart_core_axil_bvalid),
        .s_axil_bready(uart_core_axil_bready),
        .s_axil_araddr(uart_core_axil_araddr),
        .s_axil_arprot(uart_core_axil_arprot),
        .s_axil_arvalid(uart_core_axil_arvalid),
        .s_axil_arready(uart_core_axil_arready),
        .s_axil_rdata(uart_core_axil_rdata),
        .s_axil_rresp(uart_core_axil_rresp),
        .s_axil_rvalid(uart_core_axil_rvalid),
        .s_axil_rready(uart_core_axil_rready),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .cfg_divider(uart_cfg_divider)
    );

    soc_axil_ctrl #(
        .AXIL_ADDR_WIDTH(REG_WIDTH),
        .AXIL_DATA_WIDTH(BUS_WIDTH)
    ) u_soc_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .s_axil_awaddr(ctrl_axil_awaddr),
        .s_axil_awprot(ctrl_axil_awprot),
        .s_axil_awvalid(ctrl_axil_awvalid),
        .s_axil_awready(ctrl_axil_awready),
        .s_axil_wdata(ctrl_axil_wdata),
        .s_axil_wstrb(ctrl_axil_wstrb),
        .s_axil_wvalid(ctrl_axil_wvalid),
        .s_axil_wready(ctrl_axil_wready),
        .s_axil_bresp(ctrl_axil_bresp),
        .s_axil_bvalid(ctrl_axil_bvalid),
        .s_axil_bready(ctrl_axil_bready),
        .s_axil_araddr(ctrl_axil_araddr),
        .s_axil_arprot(ctrl_axil_arprot),
        .s_axil_arvalid(ctrl_axil_arvalid),
        .s_axil_arready(ctrl_axil_arready),
        .s_axil_rdata(ctrl_axil_rdata),
        .s_axil_rresp(ctrl_axil_rresp),
        .s_axil_rvalid(ctrl_axil_rvalid),
        .s_axil_rready(ctrl_axil_rready),
        .cpu_trap(cpu_trap),
        .soc_finish(soc_finish),
        .soc_status(soc_status),
        .soc_progress(soc_progress)
    );

    wire _unused_uart_divider = |uart_cfg_divider;

endmodule
