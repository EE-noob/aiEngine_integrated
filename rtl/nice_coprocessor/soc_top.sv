module soc_top #(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter WEIGHT_WIDTH    = 16,
    parameter DATA_WIDTH      = 16,
    parameter SIZE            = 16,
    parameter BUS_WIDTH       = 32,
    parameter REG_WIDTH       = 32,
    parameter ICB_ADDR_WIDTH  = 32,
    parameter ICB_LEN_W       = 4,
    parameter IA_CACHE_BLOCKS = 4,
    parameter PS_FRAME_COUNT  = SIZE,
    parameter CPU_MEM_DP      = 524288,
    parameter CPU_MEM_PATH    = "../tb/axi_soc_case/cpu.mem",
    parameter [31:0] CPU_RAM_BASE   = 32'h0000_0000,
    parameter [31:0] MMA_AXIL_BASE  = 32'h1000_0000,
    parameter [31:0] SOC_CTRL_BASE  = 32'h2000_0000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mem_reload_req,
    output wire        mma_busy,
    output wire [31:0] mma_irq,
    output wire [31:0] mma_eoi,
    output wire        uart_tx,
    input  wire        uart_rx,
    output reg         soc_finish,
    output reg  [31:0] soc_status,
    output wire        cpu_trap
);

    localparam integer CPU_ADDR_LSB  = 2;
    localparam integer CPU_ADDR_BITS = (CPU_MEM_DP <= 1) ? 1 : $clog2(CPU_MEM_DP);
    localparam [31:0] PICOSOC_UART_CLKDIV_ADDR = 32'h0200_0004;
    localparam [31:0] PICOSOC_UART_DATA_ADDR   = 32'h0200_0008;

    localparam [2:0] S_IDLE    = 3'd0;
    localparam [2:0] S_AXIL_WR = 3'd1;
    localparam [2:0] S_AXIL_WB = 3'd2;
    localparam [2:0] S_AXIL_RD = 3'd3;
    localparam [2:0] S_AXIL_RB = 3'd4;

    reg [2:0] state_q;
    reg [31:0] soc_progress;

    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    reg  [31:0] mem_rdata;

    wire mem_is_write = |mem_wstrb;
    wire [31:0] cpu_mem_offset = mem_addr[31:0] - CPU_RAM_BASE;
    wire mem_sel_cpu = (mem_addr[31:0] >= CPU_RAM_BASE) &&
                       (cpu_mem_offset[31:CPU_ADDR_LSB] < CPU_MEM_DP);
    wire mem_sel_mma = (mem_addr[31:28] == MMA_AXIL_BASE[31:28]);
    wire mem_sel_soc = (mem_addr[31:28] == SOC_CTRL_BASE[31:28]);
    wire mem_sel_uart_div  = (mem_addr[31:0] == PICOSOC_UART_CLKDIV_ADDR);
    wire mem_sel_uart_data = (mem_addr[31:0] == PICOSOC_UART_DATA_ADDR);

    reg [31:0] cpu_mem [0:CPU_MEM_DP-1];
    wire [CPU_ADDR_BITS-1:0] cpu_mem_idx =
        cpu_mem_offset[CPU_ADDR_LSB + CPU_ADDR_BITS - 1:CPU_ADDR_LSB];

    integer i;
    string cpu_mem_path_q;
    string data_mem_path_q;
    integer data_mem_base_word_q;
    initial begin
        cpu_mem_path_q = CPU_MEM_PATH;
        data_mem_path_q = "";
        data_mem_base_word_q = 0;
        void'($value$plusargs("SOC_CPU_MEM=%s", cpu_mem_path_q));
        void'($value$plusargs("SOC_DATA_MEM=%s", data_mem_path_q));
        void'($value$plusargs("SOC_DATA_MEM_BASE_WORD=%d", data_mem_base_word_q));
        if (cpu_mem_path_q != "") begin
            $display("soc_top: loading PicoRV32 program memory from %s", cpu_mem_path_q);
            $readmemh(cpu_mem_path_q, cpu_mem);
        end
        if (data_mem_path_q != "") begin
            $display("soc_top: overlay runtime case memory from %s at word %0d",
                     data_mem_path_q, data_mem_base_word_q);
            $readmemh(data_mem_path_q, cpu_mem, data_mem_base_word_q);
        end
    end

    task automatic reload_cpu_mem_from_file(input string file_path);
        if (file_path != "") begin
            $display("soc_top: runtime reload PicoRV32 program memory from %s", file_path);
            $readmemh(file_path, cpu_mem);
        end
    endtask

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
        .mem_valid(mem_valid),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),
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

    reg [AXIL_ADDR_WIDTH-1:0] axil_addr_q;
    reg [31:0]                axil_wdata_q;
    reg [3:0]                 axil_wstrb_q;
    reg                       axil_awvalid_q;
    reg                       axil_wvalid_q;
    reg                       axil_bready_q;
    reg                       axil_arvalid_q;
    reg                       axil_rready_q;

    wire                      axil_awready;
    wire                      axil_wready;
    wire [1:0]                axil_bresp;
    wire                      axil_bvalid;
    wire                      axil_arready;
    wire [31:0]               axil_rdata;
    wire [1:0]                axil_rresp;
    wire                      axil_rvalid;

    wire [31:0]               uart_div_rdata;
    wire [31:0]               uart_data_rdata;
    wire                      uart_data_wait;
    wire                      uart_access = mem_sel_uart_div || mem_sel_uart_data;
    wire                      uart_access_ready = mem_sel_uart_div ||
                                                  (mem_sel_uart_data && !uart_data_wait);
    wire                      uart_issue = (state_q == S_IDLE) && mem_valid && uart_access;
    wire [3:0]                uart_div_we = (uart_issue && mem_sel_uart_div &&
                                             mem_is_write) ? mem_wstrb : 4'b0000;
    wire                      uart_data_we = (uart_issue && mem_sel_uart_data &&
                                              mem_is_write) ? mem_wstrb[0] : 1'b0;
    wire                      uart_data_re = uart_issue && mem_sel_uart_data && !mem_is_write;

    wire                          m_axi_arvalid;
    wire                          m_axi_arready;
    wire [ICB_ADDR_WIDTH-1:0]     m_axi_araddr;
    wire [3:0]                    m_axi_arcache;
    wire [2:0]                    m_axi_arprot;
    wire [1:0]                    m_axi_arlock;
    wire [1:0]                    m_axi_arburst;
    wire [7:0]                    m_axi_arlen;
    wire [2:0]                    m_axi_arsize;

    wire                          m_axi_awvalid;
    wire                          m_axi_awready;
    wire [ICB_ADDR_WIDTH-1:0]     m_axi_awaddr;
    wire [3:0]                    m_axi_awcache;
    wire [2:0]                    m_axi_awprot;
    wire [1:0]                    m_axi_awlock;
    wire [1:0]                    m_axi_awburst;
    wire [7:0]                    m_axi_awlen;
    wire [2:0]                    m_axi_awsize;

    wire                          m_axi_rvalid;
    wire                          m_axi_rready;
    wire [BUS_WIDTH-1:0]          m_axi_rdata;
    wire [1:0]                    m_axi_rresp;
    wire                          m_axi_rlast;

    wire                          m_axi_wvalid;
    wire                          m_axi_wready;
    wire [BUS_WIDTH-1:0]          m_axi_wdata;
    wire [BUS_WIDTH/8-1:0]        m_axi_wstrb;
    wire                          m_axi_wlast;

    wire                          m_axi_bvalid;
    wire                          m_axi_bready;
    wire [1:0]                    m_axi_bresp;

    reg                           mma_aw_pending;
    reg [ICB_ADDR_WIDTH-1:0]      mma_aw_addr_q;
    reg [7:0]                     mma_aw_len_q;
    reg [7:0]                     mma_w_beat_cnt;
    reg                           mma_wr_error_q;
    reg                           mma_rd_active;
    reg [ICB_ADDR_WIDTH-1:0]      mma_rd_addr_q;
    reg [7:0]                     mma_rd_len_q;
    reg [7:0]                     mma_rd_beat_cnt;
    reg                           mma_rd_error_q;
    reg [7:0]                     mma_aw_ready_delay;
    reg [7:0]                     mma_w_ready_delay;
    reg [7:0]                     mma_ar_ready_delay;
    reg                           mma_wr_rsp_pending;
    reg [7:0]                     mma_wr_rsp_delay;
    reg                           mma_rd_rsp_pending;
    reg [7:0]                     mma_rd_rsp_delay;
    reg                           m_axi_bvalid_q;
    reg [1:0]                     m_axi_bresp_q;
    reg                           m_axi_rvalid_q;
    reg [BUS_WIDTH-1:0]           m_axi_rdata_q;
    reg [1:0]                     m_axi_rresp_q;
    reg                           m_axi_rlast_q;

    integer                       ddr_rand_lat_en;
    integer                       ddr_cmd_max_lat;
    integer                       ddr_w_max_lat;
    integer                       ddr_rsp_max_lat;

    wire mma_aw_fire = m_axi_awvalid & m_axi_awready;
    wire mma_w_fire  = m_axi_wvalid  & m_axi_wready;
    wire mma_ar_fire = m_axi_arvalid & m_axi_arready;

    wire [31:0] mma_wr_cur_addr = mma_aw_addr_q[31:0] +
                                  ((32'(mma_w_beat_cnt)) << CPU_ADDR_LSB);
    wire [31:0] mma_rd_cur_addr = mma_rd_addr_q[31:0] +
                                  ((32'(mma_rd_beat_cnt)) << CPU_ADDR_LSB);
    wire [31:0] mma_aw_offset = mma_wr_cur_addr - CPU_RAM_BASE;
    wire [31:0] mma_ar_offset = mma_rd_cur_addr - CPU_RAM_BASE;
    wire [CPU_ADDR_BITS-1:0] mma_wr_idx =
        mma_aw_offset[CPU_ADDR_LSB + CPU_ADDR_BITS - 1:CPU_ADDR_LSB];
    wire [CPU_ADDR_BITS-1:0] mma_rd_idx =
        mma_ar_offset[CPU_ADDR_LSB + CPU_ADDR_BITS - 1:CPU_ADDR_LSB];
    wire mma_wr_addr_oob = (mma_wr_cur_addr < CPU_RAM_BASE) ||
                           (mma_aw_offset[31:CPU_ADDR_LSB] >= CPU_MEM_DP);
    wire mma_rd_addr_oob = (mma_rd_cur_addr < CPU_RAM_BASE) ||
                           (mma_ar_offset[31:CPU_ADDR_LSB] >= CPU_MEM_DP);

    assign m_axi_awready = (!mma_aw_pending) && (!m_axi_bvalid_q) &&
                           (!mma_wr_rsp_pending) && (mma_aw_ready_delay == 8'd0);
    assign m_axi_wready  = mma_aw_pending && (!m_axi_bvalid_q) &&
                           (!mma_wr_rsp_pending) && (mma_w_ready_delay == 8'd0);
    assign m_axi_arready = (!mma_rd_active) && (!m_axi_rvalid_q) && (!mma_rd_rsp_pending) &&
                           (mma_ar_ready_delay == 8'd0);
    assign m_axi_bvalid  = m_axi_bvalid_q;
    assign m_axi_bresp   = m_axi_bresp_q;
    assign m_axi_rvalid  = m_axi_rvalid_q;
    assign m_axi_rdata   = m_axi_rdata_q;
    assign m_axi_rresp   = m_axi_rresp_q;
    assign m_axi_rlast   = m_axi_rlast_q;

    function automatic [7:0] random_ddr_delay(input integer max_lat);
        integer value;
        begin
            if ((ddr_rand_lat_en == 0) || (max_lat <= 0)) begin
                random_ddr_delay = 8'd0;
            end else begin
                value = $urandom_range(max_lat, 0);
                random_ddr_delay = (value > 255) ? 8'hff : value[7:0];
            end
        end
    endfunction

    initial begin
        ddr_rand_lat_en = 0;
        ddr_cmd_max_lat = 0;
        ddr_w_max_lat   = 0;
        ddr_rsp_max_lat = 0;
        void'($value$plusargs("DDR_RAND_LAT=%d", ddr_rand_lat_en));
        void'($value$plusargs("DDR_CMD_MAX_LAT=%d", ddr_cmd_max_lat));
        void'($value$plusargs("DDR_W_MAX_LAT=%d", ddr_w_max_lat));
        void'($value$plusargs("DDR_RSP_MAX_LAT=%d", ddr_rsp_max_lat));
        if (ddr_rand_lat_en != 0) begin
            $display("soc_top: DDR random latency enabled cmd_max=%0d w_max=%0d rsp_max=%0d",
                     ddr_cmd_max_lat, ddr_w_max_lat, ddr_rsp_max_lat);
        end
    end

    mma_axil_top #(
        .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .BUS_WIDTH(BUS_WIDTH),
        .REG_WIDTH(REG_WIDTH),
        .ICB_ADDR_WIDTH(ICB_ADDR_WIDTH),
        .ICB_LEN_W(ICB_LEN_W),
        .IA_CACHE_BLOCKS(IA_CACHE_BLOCKS),
        .PS_FRAME_COUNT(PS_FRAME_COUNT)
    ) u_mma_axil_top (
        .clk(clk),
        .rst_n(rst_n),
        .s_axil_awaddr(axil_addr_q),
        .s_axil_awprot(3'b000),
        .s_axil_awvalid(axil_awvalid_q),
        .s_axil_awready(axil_awready),
        .s_axil_wdata(axil_wdata_q),
        .s_axil_wstrb(axil_wstrb_q),
        .s_axil_wvalid(axil_wvalid_q),
        .s_axil_wready(axil_wready),
        .s_axil_bresp(axil_bresp),
        .s_axil_bvalid(axil_bvalid),
        .s_axil_bready(axil_bready_q),
        .s_axil_araddr(axil_addr_q),
        .s_axil_arprot(3'b000),
        .s_axil_arvalid(axil_arvalid_q),
        .s_axil_arready(axil_arready),
        .s_axil_rdata(axil_rdata),
        .s_axil_rresp(axil_rresp),
        .s_axil_rvalid(axil_rvalid),
        .s_axil_rready(axil_rready_q),

        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),

        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),

        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),

        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),

        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),

        .irq(mma_irq),
        .eoi(mma_eoi),
        .mma_busy(mma_busy)
    );

    assign mma_eoi = 32'h0;

    simpleuart u_simpleuart (
        .clk          (clk),
        .resetn       (rst_n),
        .ser_tx       (uart_tx),
        .ser_rx       (uart_rx),
        .reg_div_we   (uart_div_we),
        .reg_div_di   (mem_wdata),
        .reg_div_do   (uart_div_rdata),
        .reg_dat_we   (uart_data_we),
        .reg_dat_re   (uart_data_re),
        .reg_dat_di   (mem_wdata),
        .reg_dat_do   (uart_data_rdata),
        .reg_dat_wait (uart_data_wait)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q        <= S_IDLE;
            mem_ready      <= 1'b0;
            mem_rdata      <= 32'b0;
            axil_addr_q    <= {AXIL_ADDR_WIDTH{1'b0}};
            axil_wdata_q   <= 32'b0;
            axil_wstrb_q   <= 4'b0;
            axil_awvalid_q <= 1'b0;
            axil_wvalid_q  <= 1'b0;
            axil_bready_q  <= 1'b0;
            axil_arvalid_q <= 1'b0;
            axil_rready_q  <= 1'b0;
            mma_aw_pending <= 1'b0;
            mma_aw_addr_q  <= {ICB_ADDR_WIDTH{1'b0}};
            mma_aw_len_q   <= 8'b0;
            mma_w_beat_cnt <= 8'b0;
            mma_wr_error_q <= 1'b0;
            mma_rd_active  <= 1'b0;
            mma_rd_addr_q  <= {ICB_ADDR_WIDTH{1'b0}};
            mma_rd_len_q   <= 8'b0;
            mma_rd_beat_cnt <= 8'b0;
            mma_rd_error_q <= 1'b0;
            mma_aw_ready_delay <= 8'd0;
            mma_w_ready_delay  <= 8'd0;
            mma_ar_ready_delay <= 8'd0;
            mma_wr_rsp_pending <= 1'b0;
            mma_wr_rsp_delay   <= 8'd0;
            mma_rd_rsp_pending <= 1'b0;
            mma_rd_rsp_delay   <= 8'd0;
            m_axi_bvalid_q <= 1'b0;
            m_axi_bresp_q  <= 2'b00;
            m_axi_rvalid_q <= 1'b0;
            m_axi_rdata_q  <= {BUS_WIDTH{1'b0}};
            m_axi_rresp_q  <= 2'b00;
            m_axi_rlast_q  <= 1'b0;
            soc_finish     <= 1'b0;
            soc_status     <= 32'b0;
            soc_progress   <= 32'b0;
        end else begin
            mem_ready <= 1'b0;

            if (mem_reload_req) begin
                reload_cpu_mem_from_file(cpu_mem_path_q);
            end

            if (mma_aw_fire) begin
                mma_aw_pending <= 1'b1;
                mma_aw_addr_q  <= m_axi_awaddr;
                mma_aw_len_q   <= m_axi_awlen;
                mma_w_beat_cnt <= 8'd0;
                mma_wr_error_q <= 1'b0;
                mma_aw_ready_delay <= random_ddr_delay(ddr_cmd_max_lat);
            end else if (mma_aw_ready_delay != 8'd0) begin
                mma_aw_ready_delay <= mma_aw_ready_delay - 8'd1;
            end

            if (mma_w_fire) begin
                if (mma_wr_addr_oob) begin
                    mma_wr_error_q <= 1'b1;
                end else begin
                    for (i = 0; i < BUS_WIDTH/8; i = i + 1) begin
                        if (m_axi_wstrb[i]) begin
                            cpu_mem[mma_wr_idx][8*i +: 8] <= m_axi_wdata[8*i +: 8];
                        end
                    end
                end
                if (m_axi_wlast != (mma_w_beat_cnt == mma_aw_len_q)) begin
                    mma_wr_error_q <= 1'b1;
                end
                if (m_axi_wlast || (mma_w_beat_cnt == mma_aw_len_q)) begin
                    mma_aw_pending <= 1'b0;
                    mma_wr_rsp_pending <= 1'b1;
                    mma_wr_rsp_delay <= random_ddr_delay(ddr_rsp_max_lat);
                end else begin
                    mma_w_beat_cnt <= mma_w_beat_cnt + 8'd1;
                end
                mma_w_ready_delay <= random_ddr_delay(ddr_w_max_lat);
            end else if (mma_w_ready_delay != 8'd0) begin
                mma_w_ready_delay <= mma_w_ready_delay - 8'd1;
            end

            if (mma_wr_rsp_pending && (!m_axi_bvalid_q)) begin
                if (mma_wr_rsp_delay == 8'd0) begin
                    m_axi_bvalid_q <= 1'b1;
                    m_axi_bresp_q <= mma_wr_error_q ? 2'b10 : 2'b00;
                    mma_wr_rsp_pending <= 1'b0;
                end else begin
                    mma_wr_rsp_delay <= mma_wr_rsp_delay - 8'd1;
                end
            end

            if (m_axi_bvalid_q && m_axi_bready) begin
                m_axi_bvalid_q <= 1'b0;
            end

            if (mma_ar_fire) begin
                mma_rd_active <= 1'b1;
                mma_rd_addr_q <= m_axi_araddr;
                mma_rd_len_q <= m_axi_arlen;
                mma_rd_beat_cnt <= 8'd0;
                mma_rd_error_q <= 1'b0;
                mma_rd_rsp_pending <= 1'b1;
                mma_ar_ready_delay <= random_ddr_delay(ddr_cmd_max_lat);
                mma_rd_rsp_delay <= random_ddr_delay(ddr_rsp_max_lat);
            end else if (mma_ar_ready_delay != 8'd0) begin
                mma_ar_ready_delay <= mma_ar_ready_delay - 8'd1;
            end

            if (mma_rd_rsp_pending && (!m_axi_rvalid_q)) begin
                if (mma_rd_rsp_delay == 8'd0) begin
                    m_axi_rvalid_q <= 1'b1;
                    m_axi_rlast_q <= (mma_rd_beat_cnt == mma_rd_len_q);
                    if (mma_rd_addr_oob) begin
                        m_axi_rresp_q <= 2'b10;
                        m_axi_rdata_q <= {BUS_WIDTH{1'b0}};
                        mma_rd_error_q <= 1'b1;
                    end else begin
                        m_axi_rresp_q <= mma_rd_error_q ? 2'b10 : 2'b00;
                        m_axi_rdata_q <= cpu_mem[mma_rd_idx];
                    end
                    mma_rd_rsp_pending <= 1'b0;
                end else begin
                    mma_rd_rsp_delay <= mma_rd_rsp_delay - 8'd1;
                end
            end

            if (m_axi_rvalid_q && m_axi_rready) begin
                m_axi_rvalid_q <= 1'b0;
                m_axi_rlast_q  <= 1'b0;
                if (mma_rd_beat_cnt == mma_rd_len_q) begin
                    mma_rd_active <= 1'b0;
                end else begin
                    mma_rd_beat_cnt <= mma_rd_beat_cnt + 8'd1;
                    mma_rd_rsp_pending <= 1'b1;
                    mma_rd_rsp_delay <= random_ddr_delay(ddr_rsp_max_lat);
                end
            end

            case (state_q)
                S_IDLE: begin
                    if (mem_valid && !mem_ready) begin
                        if (mem_sel_cpu) begin
                            mem_rdata <= cpu_mem[cpu_mem_idx];
                            if (mem_is_write) begin
                                for (i = 0; i < 4; i = i + 1) begin
                                    if (mem_wstrb[i]) begin
                                        cpu_mem[cpu_mem_idx][8*i +: 8] <= mem_wdata[8*i +: 8];
                                    end
                                end
                            end
                            mem_ready <= 1'b1;
                        end else if (uart_access) begin
                            if (uart_access_ready) begin
                                mem_rdata <= mem_sel_uart_div ? uart_div_rdata : uart_data_rdata;
                                mem_ready <= 1'b1;
                            end
                        end else if (mem_sel_soc) begin
                            mem_rdata <= (mem_addr[3:2] == 2'b00) ? soc_status :
                                         (mem_addr[3:2] == 2'b01) ? {31'b0, soc_finish} :
                                         (mem_addr[3:2] == 2'b10) ? {31'b0, cpu_trap} :
                                         (mem_addr[3:2] == 2'b11) ? soc_progress : 32'b0;
                            if (mem_is_write && (mem_addr[3:2] == 2'b00)) begin
                                soc_finish <= 1'b1;
                                soc_status <= mem_wdata;
                            end else if (mem_is_write && (mem_addr[3:2] == 2'b11)) begin
                                soc_progress <= mem_wdata;
                            end
                            mem_ready <= 1'b1;
                        end else if (mem_sel_mma) begin
                            axil_addr_q  <= mem_addr[AXIL_ADDR_WIDTH-1:0];
                            if (mem_is_write) begin
                                axil_wdata_q   <= mem_wdata;
                                axil_wstrb_q   <= mem_wstrb;
                                axil_awvalid_q <= 1'b1;
                                axil_wvalid_q  <= 1'b1;
                                state_q        <= S_AXIL_WR;
                            end else begin
                                axil_arvalid_q <= 1'b1;
                                state_q        <= S_AXIL_RD;
                            end
                        end else begin
                            mem_rdata <= 32'hDEAD_BEEF;
                            mem_ready <= 1'b1;
                        end
                    end
                end

                S_AXIL_WR: begin
                    if (axil_awvalid_q && axil_awready) begin
                        axil_awvalid_q <= 1'b0;
                    end
                    if (axil_wvalid_q && axil_wready) begin
                        axil_wvalid_q <= 1'b0;
                    end
                    if ((!axil_awvalid_q || axil_awready) && (!axil_wvalid_q || axil_wready)) begin
                        axil_bready_q <= 1'b1;
                        state_q       <= S_AXIL_WB;
                    end
                end

                S_AXIL_WB: begin
                    if (axil_bvalid) begin
                        axil_bready_q <= 1'b0;
                        mem_rdata     <= {30'b0, axil_bresp};
                        mem_ready     <= 1'b1;
                        state_q       <= S_IDLE;
                    end
                end

                S_AXIL_RD: begin
                    if (axil_arvalid_q && axil_arready) begin
                        axil_arvalid_q <= 1'b0;
                        axil_rready_q  <= 1'b1;
                        state_q        <= S_AXIL_RB;
                    end
                end

                S_AXIL_RB: begin
                    if (axil_rvalid) begin
                        axil_rready_q <= 1'b0;
                        mem_rdata     <= axil_rdata;
                        mem_ready     <= 1'b1;
                        state_q       <= S_IDLE;
                    end
                end

                default: begin
                    state_q <= S_IDLE;
                end
            endcase
        end
    end

    wire _unused = mem_instr | |axil_rresp | |m_axi_arcache | |m_axi_arprot |
                   |m_axi_arlock | |m_axi_arburst | |m_axi_arsize |
                   |m_axi_awcache | |m_axi_awprot | |m_axi_awlock |
                   |m_axi_awburst | |m_axi_awsize;

endmodule
