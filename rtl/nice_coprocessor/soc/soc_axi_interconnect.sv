module soc_axi_interconnect #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned CPU_MEM_DP = 524288,
    parameter int unsigned READ_OUTSTANDING = 4,
    parameter int unsigned WRITE_OUTSTANDING = READ_OUTSTANDING,
    parameter logic [31:0] CPU_RAM_BASE  = 32'h0000_0000,
    parameter logic [31:0] MMA_AXIL_BASE = 32'h1000_0000,
    parameter logic [31:0] UART_BASE     = 32'h0200_0000,
    parameter logic [31:0] SOC_CTRL_BASE = 32'h2000_0000
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire                         s0_axi_arvalid,
    output logic                        s0_axi_arready,
    input  wire [ADDR_WIDTH-1:0]        s0_axi_araddr,
    input  wire [3:0]                   s0_axi_arcache,
    input  wire [2:0]                   s0_axi_arprot,
    input  wire [1:0]                   s0_axi_arlock,
    input  wire [1:0]                   s0_axi_arburst,
    input  wire [7:0]                   s0_axi_arlen,
    input  wire [2:0]                   s0_axi_arsize,
    output logic                        s0_axi_rvalid,
    input  wire                         s0_axi_rready,
    output logic [DATA_WIDTH-1:0]       s0_axi_rdata,
    output logic [1:0]                  s0_axi_rresp,
    output logic                        s0_axi_rlast,
    input  wire                         s0_axi_awvalid,
    output logic                        s0_axi_awready,
    input  wire [ADDR_WIDTH-1:0]        s0_axi_awaddr,
    input  wire [3:0]                   s0_axi_awcache,
    input  wire [2:0]                   s0_axi_awprot,
    input  wire [1:0]                   s0_axi_awlock,
    input  wire [1:0]                   s0_axi_awburst,
    input  wire [7:0]                   s0_axi_awlen,
    input  wire [2:0]                   s0_axi_awsize,
    input  wire                         s0_axi_wvalid,
    output logic                        s0_axi_wready,
    input  wire [DATA_WIDTH-1:0]        s0_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]      s0_axi_wstrb,
    input  wire                         s0_axi_wlast,
    output logic                        s0_axi_bvalid,
    input  wire                         s0_axi_bready,
    output logic [1:0]                  s0_axi_bresp,

    input  wire                         s1_axi_arvalid,
    output logic                        s1_axi_arready,
    input  wire [ADDR_WIDTH-1:0]        s1_axi_araddr,
    input  wire [3:0]                   s1_axi_arcache,
    input  wire [2:0]                   s1_axi_arprot,
    input  wire [1:0]                   s1_axi_arlock,
    input  wire [1:0]                   s1_axi_arburst,
    input  wire [7:0]                   s1_axi_arlen,
    input  wire [2:0]                   s1_axi_arsize,
    output logic                        s1_axi_rvalid,
    input  wire                         s1_axi_rready,
    output logic [DATA_WIDTH-1:0]       s1_axi_rdata,
    output logic [1:0]                  s1_axi_rresp,
    output logic                        s1_axi_rlast,
    input  wire                         s1_axi_awvalid,
    output logic                        s1_axi_awready,
    input  wire [ADDR_WIDTH-1:0]        s1_axi_awaddr,
    input  wire [3:0]                   s1_axi_awcache,
    input  wire [2:0]                   s1_axi_awprot,
    input  wire [1:0]                   s1_axi_awlock,
    input  wire [1:0]                   s1_axi_awburst,
    input  wire [7:0]                   s1_axi_awlen,
    input  wire [2:0]                   s1_axi_awsize,
    input  wire                         s1_axi_wvalid,
    output logic                        s1_axi_wready,
    input  wire [DATA_WIDTH-1:0]        s1_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]      s1_axi_wstrb,
    input  wire                         s1_axi_wlast,
    output logic                        s1_axi_bvalid,
    input  wire                         s1_axi_bready,
    output logic [1:0]                  s1_axi_bresp,

    output logic                        m_ram_arvalid,
    input  wire                         m_ram_arready,
    output logic [ADDR_WIDTH-1:0]       m_ram_araddr,
    output logic [3:0]                  m_ram_arcache,
    output logic [2:0]                  m_ram_arprot,
    output logic [1:0]                  m_ram_arlock,
    output logic [1:0]                  m_ram_arburst,
    output logic [7:0]                  m_ram_arlen,
    output logic [2:0]                  m_ram_arsize,
    input  wire                         m_ram_rvalid,
    output logic                        m_ram_rready,
    input  wire [DATA_WIDTH-1:0]        m_ram_rdata,
    input  wire [1:0]                   m_ram_rresp,
    input  wire                         m_ram_rlast,
    output logic                        m_ram_awvalid,
    input  wire                         m_ram_awready,
    output logic [ADDR_WIDTH-1:0]       m_ram_awaddr,
    output logic [3:0]                  m_ram_awcache,
    output logic [2:0]                  m_ram_awprot,
    output logic [1:0]                  m_ram_awlock,
    output logic [1:0]                  m_ram_awburst,
    output logic [7:0]                  m_ram_awlen,
    output logic [2:0]                  m_ram_awsize,
    output logic                        m_ram_wvalid,
    input  wire                         m_ram_wready,
    output logic [DATA_WIDTH-1:0]       m_ram_wdata,
    output logic [DATA_WIDTH/8-1:0]     m_ram_wstrb,
    output logic                        m_ram_wlast,
    input  wire                         m_ram_bvalid,
    output logic                        m_ram_bready,
    input  wire [1:0]                   m_ram_bresp,

    output wire [15:0]                  m_mma_awaddr,
    output wire [2:0]                   m_mma_awprot,
    output wire                         m_mma_awvalid,
    input  wire                         m_mma_awready,
    output wire [31:0]                  m_mma_wdata,
    output wire [3:0]                   m_mma_wstrb,
    output wire                         m_mma_wvalid,
    input  wire                         m_mma_wready,
    input  wire [1:0]                   m_mma_bresp,
    input  wire                         m_mma_bvalid,
    output wire                         m_mma_bready,
    output wire [15:0]                  m_mma_araddr,
    output wire [2:0]                   m_mma_arprot,
    output wire                         m_mma_arvalid,
    input  wire                         m_mma_arready,
    input  wire [31:0]                  m_mma_rdata,
    input  wire [1:0]                   m_mma_rresp,
    input  wire                         m_mma_rvalid,
    output wire                         m_mma_rready,

    output wire [31:0]                  m_uart_awaddr,
    output wire [2:0]                   m_uart_awprot,
    output wire                         m_uart_awvalid,
    input  wire                         m_uart_awready,
    output wire [31:0]                  m_uart_wdata,
    output wire [3:0]                   m_uart_wstrb,
    output wire                         m_uart_wvalid,
    input  wire                         m_uart_wready,
    input  wire [1:0]                   m_uart_bresp,
    input  wire                         m_uart_bvalid,
    output wire                         m_uart_bready,
    output wire [31:0]                  m_uart_araddr,
    output wire [2:0]                   m_uart_arprot,
    output wire                         m_uart_arvalid,
    input  wire                         m_uart_arready,
    input  wire [31:0]                  m_uart_rdata,
    input  wire [1:0]                   m_uart_rresp,
    input  wire                         m_uart_rvalid,
    output wire                         m_uart_rready,

    output wire [31:0]                  m_ctrl_awaddr,
    output wire [2:0]                   m_ctrl_awprot,
    output wire                         m_ctrl_awvalid,
    input  wire                         m_ctrl_awready,
    output wire [31:0]                  m_ctrl_wdata,
    output wire [3:0]                   m_ctrl_wstrb,
    output wire                         m_ctrl_wvalid,
    input  wire                         m_ctrl_wready,
    input  wire [1:0]                   m_ctrl_bresp,
    input  wire                         m_ctrl_bvalid,
    output wire                         m_ctrl_bready,
    output wire [31:0]                  m_ctrl_araddr,
    output wire [2:0]                   m_ctrl_arprot,
    output wire                         m_ctrl_arvalid,
    input  wire                         m_ctrl_arready,
    input  wire [31:0]                  m_ctrl_rdata,
    input  wire [1:0]                   m_ctrl_rresp,
    input  wire                         m_ctrl_rvalid,
    output wire                         m_ctrl_rready
);

    typedef enum logic [2:0] {
        D_RAM  = 3'd0,
        D_MMA  = 3'd1,
        D_UART = 3'd2,
        D_CTRL = 3'd3,
        D_ERR  = 3'd7
    } dest_e;

    typedef enum logic {
        OWNER_CPU = 1'b0,
        OWNER_MMA = 1'b1
    } owner_e;

    localparam int unsigned CPU_ADDR_LSB = 2;
    localparam int unsigned CPU_ADDR_BITS = (CPU_MEM_DP <= 1) ? 1 : $clog2(CPU_MEM_DP);
    localparam int unsigned RD_OUTS_DEPTH = (READ_OUTSTANDING < 1) ? 1 : READ_OUTSTANDING;
    localparam int unsigned WR_OUTS_DEPTH = (WRITE_OUTSTANDING < 1) ? 1 : WRITE_OUTSTANDING;
    localparam int unsigned RD_OUTS_W = (RD_OUTS_DEPTH < 2) ? 1 : $clog2(RD_OUTS_DEPTH + 1);
    localparam int unsigned WR_OUTS_W = (WR_OUTS_DEPTH < 2) ? 1 : $clog2(WR_OUTS_DEPTH + 1);

    owner_e ram_rd_owner_q;
    owner_e ram_wr_owner_q;
    logic ram_rd_active_q;
    logic ram_wr_active_q;
    logic [RD_OUTS_W-1:0] ram_rd_outs_q;
    logic [WR_OUTS_W-1:0] ram_wr_outs_q;
    dest_e cpu_rd_dest_q;
    dest_e cpu_wr_dest_q;
    logic cpu_rd_active_q;
    logic cpu_wr_active_q;
    logic err_rvalid_q;
    logic err_bvalid_q;

    function automatic dest_e decode_cpu_addr(input logic [ADDR_WIDTH-1:0] addr);
        logic [31:0] offset;
        begin
            offset = addr[31:0] - CPU_RAM_BASE;
            if ((addr[31:0] >= CPU_RAM_BASE) &&
                (offset[31:CPU_ADDR_LSB] < CPU_MEM_DP)) begin
                decode_cpu_addr = D_RAM;
            end else if (addr[31:28] == MMA_AXIL_BASE[31:28]) begin
                decode_cpu_addr = D_MMA;
            end else if (addr[31:12] == UART_BASE[31:12]) begin
                decode_cpu_addr = D_UART;
            end else if (addr[31:28] == SOC_CTRL_BASE[31:28]) begin
                decode_cpu_addr = D_CTRL;
            end else begin
                decode_cpu_addr = D_ERR;
            end
        end
    endfunction

    wire [31:0] s0_araddr32 = s0_axi_araddr[31:0];
    wire [31:0] s0_awaddr32 = s0_axi_awaddr[31:0];
    dest_e cpu_ar_dest;
    dest_e cpu_aw_dest;
    dest_e cpu_w_dest;

    always_comb begin
        cpu_ar_dest = decode_cpu_addr(s0_axi_araddr);
        cpu_aw_dest = decode_cpu_addr(s0_axi_awaddr);
        cpu_w_dest  = cpu_wr_active_q ? cpu_wr_dest_q : cpu_aw_dest;
    end

    wire ram_rd_owner_valid = ram_rd_owner_q == OWNER_MMA ? s1_axi_arvalid :
                                                           (s0_axi_arvalid && (cpu_ar_dest == D_RAM));
    wire ram_wr_owner_aw_valid = ram_wr_owner_q == OWNER_MMA ? s1_axi_awvalid :
                                                              (s0_axi_awvalid && (cpu_aw_dest == D_RAM));
    wire ram_rd_select_mma = !ram_rd_active_q && s1_axi_arvalid;
    wire ram_rd_select_cpu = !ram_rd_active_q && !s1_axi_arvalid &&
                              s0_axi_arvalid && (cpu_ar_dest == D_RAM);
    wire ram_wr_select_mma = !ram_wr_active_q && s1_axi_awvalid;
    wire ram_wr_select_cpu = !ram_wr_active_q && !s1_axi_awvalid &&
                              s0_axi_awvalid && (cpu_aw_dest == D_RAM);

    wire ram_ar_from_mma = ram_rd_active_q ? (ram_rd_owner_q == OWNER_MMA) : ram_rd_select_mma;
    wire ram_ar_from_cpu = ram_rd_active_q ? (ram_rd_owner_q == OWNER_CPU) : ram_rd_select_cpu;
    wire ram_aw_from_mma = ram_wr_active_q ? (ram_wr_owner_q == OWNER_MMA) : ram_wr_select_mma;
    wire ram_aw_from_cpu = ram_wr_active_q ? (ram_wr_owner_q == OWNER_CPU) : ram_wr_select_cpu;
    wire ram_w_from_mma = ram_wr_active_q && (ram_wr_owner_q == OWNER_MMA);
    wire ram_w_from_cpu = ram_wr_active_q && (ram_wr_owner_q == OWNER_CPU);

    wire ram_ar_hs = m_ram_arvalid && m_ram_arready;
    wire ram_r_last_hs = m_ram_rvalid && m_ram_rready && m_ram_rlast;
    wire ram_aw_hs = m_ram_awvalid && m_ram_awready;
    wire ram_b_hs = m_ram_bvalid && m_ram_bready;
    wire ram_rd_slot_avail = (ram_rd_outs_q != RD_OUTS_W'(RD_OUTS_DEPTH)) || ram_r_last_hs;
    wire ram_wr_slot_avail = (ram_wr_outs_q != WR_OUTS_W'(WR_OUTS_DEPTH)) || ram_b_hs;

    always_comb begin
        s0_axi_arready = 1'b0;
        s1_axi_arready = 1'b0;
        s0_axi_rvalid  = 1'b0;
        s0_axi_rdata   = '0;
        s0_axi_rresp   = 2'b00;
        s0_axi_rlast   = 1'b0;
        s1_axi_rvalid  = 1'b0;
        s1_axi_rdata   = '0;
        s1_axi_rresp   = 2'b00;
        s1_axi_rlast   = 1'b0;
        m_ram_arvalid  = 1'b0;
        m_ram_araddr   = '0;
        m_ram_arcache  = 4'b0;
        m_ram_arprot   = 3'b0;
        m_ram_arlock   = 2'b0;
        m_ram_arburst  = 2'b01;
        m_ram_arlen    = 8'd0;
        m_ram_arsize   = 3'd2;
        m_ram_rready   = 1'b0;

        if (ram_ar_from_mma) begin
            m_ram_arvalid = s1_axi_arvalid && ram_rd_slot_avail;
            m_ram_araddr  = s1_axi_araddr;
            m_ram_arcache = s1_axi_arcache;
            m_ram_arprot  = s1_axi_arprot;
            m_ram_arlock  = s1_axi_arlock;
            m_ram_arburst = s1_axi_arburst;
            m_ram_arlen   = s1_axi_arlen;
            m_ram_arsize  = s1_axi_arsize;
            s1_axi_arready = m_ram_arready && ram_rd_slot_avail;
        end else if (ram_ar_from_cpu) begin
            m_ram_arvalid = s0_axi_arvalid && (cpu_ar_dest == D_RAM) && ram_rd_slot_avail;
            m_ram_araddr  = s0_axi_araddr;
            m_ram_arcache = s0_axi_arcache;
            m_ram_arprot  = s0_axi_arprot;
            m_ram_arlock  = s0_axi_arlock;
            m_ram_arburst = s0_axi_arburst;
            m_ram_arlen   = s0_axi_arlen;
            m_ram_arsize  = s0_axi_arsize;
            s0_axi_arready = m_ram_arready && ram_rd_slot_avail;
        end

        if (ram_rd_active_q && (ram_rd_owner_q == OWNER_MMA)) begin
            s1_axi_rvalid = m_ram_rvalid;
            s1_axi_rdata  = m_ram_rdata;
            s1_axi_rresp  = m_ram_rresp;
            s1_axi_rlast  = m_ram_rlast;
            m_ram_rready  = s1_axi_rready;
        end else if (ram_rd_active_q && (ram_rd_owner_q == OWNER_CPU) &&
                     (cpu_rd_dest_q == D_RAM)) begin
            s0_axi_rvalid = m_ram_rvalid;
            s0_axi_rdata  = m_ram_rdata;
            s0_axi_rresp  = m_ram_rresp;
            s0_axi_rlast  = m_ram_rlast;
            m_ram_rready  = s0_axi_rready;
        end

        if (cpu_ar_dest == D_MMA) s0_axi_arready = m_mma_arready;
        else if (cpu_ar_dest == D_UART) s0_axi_arready = m_uart_arready;
        else if (cpu_ar_dest == D_CTRL) s0_axi_arready = m_ctrl_arready;
        else if (cpu_ar_dest == D_ERR) s0_axi_arready = !err_rvalid_q;

        if (cpu_rd_active_q) begin
            unique case (cpu_rd_dest_q)
                D_MMA: begin
                    s0_axi_rvalid = m_mma_rvalid;
                    s0_axi_rdata  = m_mma_rdata;
                    s0_axi_rresp  = m_mma_rresp;
                    s0_axi_rlast  = 1'b1;
                end
                D_UART: begin
                    s0_axi_rvalid = m_uart_rvalid;
                    s0_axi_rdata  = m_uart_rdata;
                    s0_axi_rresp  = m_uart_rresp;
                    s0_axi_rlast  = 1'b1;
                end
                D_CTRL: begin
                    s0_axi_rvalid = m_ctrl_rvalid;
                    s0_axi_rdata  = m_ctrl_rdata;
                    s0_axi_rresp  = m_ctrl_rresp;
                    s0_axi_rlast  = 1'b1;
                end
                D_ERR: begin
                    s0_axi_rvalid = err_rvalid_q;
                    s0_axi_rdata  = 32'hDEAD_BEEF;
                    s0_axi_rresp  = 2'b11;
                    s0_axi_rlast  = 1'b1;
                end
                default: begin
                end
            endcase
        end
    end

    always_comb begin
        s0_axi_awready = 1'b0;
        s0_axi_wready  = 1'b0;
        s0_axi_bvalid  = 1'b0;
        s0_axi_bresp   = 2'b00;
        s1_axi_awready = 1'b0;
        s1_axi_wready  = 1'b0;
        s1_axi_bvalid  = 1'b0;
        s1_axi_bresp   = 2'b00;
        m_ram_awvalid  = 1'b0;
        m_ram_awaddr   = '0;
        m_ram_awcache  = 4'b0;
        m_ram_awprot   = 3'b0;
        m_ram_awlock   = 2'b0;
        m_ram_awburst  = 2'b01;
        m_ram_awlen    = 8'd0;
        m_ram_awsize   = 3'd2;
        m_ram_wvalid   = 1'b0;
        m_ram_wdata    = '0;
        m_ram_wstrb    = '0;
        m_ram_wlast    = 1'b0;
        m_ram_bready   = 1'b0;

        if (ram_aw_from_mma) begin
            m_ram_awvalid = s1_axi_awvalid && ram_wr_slot_avail;
            m_ram_awaddr  = s1_axi_awaddr;
            m_ram_awcache = s1_axi_awcache;
            m_ram_awprot  = s1_axi_awprot;
            m_ram_awlock  = s1_axi_awlock;
            m_ram_awburst = s1_axi_awburst;
            m_ram_awlen   = s1_axi_awlen;
            m_ram_awsize  = s1_axi_awsize;
            s1_axi_awready = m_ram_awready && ram_wr_slot_avail;
        end else if (ram_aw_from_cpu) begin
            m_ram_awvalid = s0_axi_awvalid && (cpu_aw_dest == D_RAM) && ram_wr_slot_avail;
            m_ram_awaddr  = s0_axi_awaddr;
            m_ram_awcache = s0_axi_awcache;
            m_ram_awprot  = s0_axi_awprot;
            m_ram_awlock  = s0_axi_awlock;
            m_ram_awburst = s0_axi_awburst;
            m_ram_awlen   = s0_axi_awlen;
            m_ram_awsize  = s0_axi_awsize;
            s0_axi_awready = m_ram_awready && ram_wr_slot_avail;
        end

        if (ram_w_from_mma) begin
            m_ram_wvalid = s1_axi_wvalid;
            m_ram_wdata  = s1_axi_wdata;
            m_ram_wstrb  = s1_axi_wstrb;
            m_ram_wlast  = s1_axi_wlast;
            s1_axi_wready = m_ram_wready;
        end else if (ram_w_from_cpu) begin
            m_ram_wvalid = s0_axi_wvalid && (cpu_w_dest == D_RAM);
            m_ram_wdata  = s0_axi_wdata;
            m_ram_wstrb  = s0_axi_wstrb;
            m_ram_wlast  = s0_axi_wlast;
            s0_axi_wready = m_ram_wready;
        end

        if (ram_wr_active_q && (ram_wr_owner_q == OWNER_MMA)) begin
            s1_axi_bvalid = m_ram_bvalid;
            s1_axi_bresp  = m_ram_bresp;
            m_ram_bready  = s1_axi_bready;
        end else if (ram_wr_active_q && (ram_wr_owner_q == OWNER_CPU) &&
                     (cpu_wr_dest_q == D_RAM)) begin
            s0_axi_bvalid = m_ram_bvalid;
            s0_axi_bresp  = m_ram_bresp;
            m_ram_bready  = s0_axi_bready;
        end

        if (cpu_aw_dest == D_MMA) s0_axi_awready = m_mma_awready;
        else if (cpu_aw_dest == D_UART) s0_axi_awready = m_uart_awready;
        else if (cpu_aw_dest == D_CTRL) s0_axi_awready = m_ctrl_awready;
        else if (cpu_aw_dest == D_ERR) s0_axi_awready = !err_bvalid_q;

        unique case (cpu_w_dest)
            D_MMA:  s0_axi_wready = m_mma_wready;
            D_UART: s0_axi_wready = m_uart_wready;
            D_CTRL: s0_axi_wready = m_ctrl_wready;
            D_ERR:  s0_axi_wready = !err_bvalid_q;
            default: begin
            end
        endcase

        if (cpu_wr_active_q) begin
            unique case (cpu_wr_dest_q)
                D_MMA: begin
                    s0_axi_bvalid = m_mma_bvalid;
                    s0_axi_bresp  = m_mma_bresp;
                end
                D_UART: begin
                    s0_axi_bvalid = m_uart_bvalid;
                    s0_axi_bresp  = m_uart_bresp;
                end
                D_CTRL: begin
                    s0_axi_bvalid = m_ctrl_bvalid;
                    s0_axi_bresp  = m_ctrl_bresp;
                end
                D_ERR: begin
                    s0_axi_bvalid = err_bvalid_q;
                    s0_axi_bresp  = 2'b11;
                end
                default: begin
                end
            endcase
        end
    end

    assign m_mma_awaddr  = s0_awaddr32[15:0];
    assign m_mma_awprot  = s0_axi_awprot;
    assign m_mma_awvalid = s0_axi_awvalid && (cpu_aw_dest == D_MMA);
    assign m_mma_wdata   = s0_axi_wdata[31:0];
    assign m_mma_wstrb   = s0_axi_wstrb[3:0];
    assign m_mma_wvalid  = s0_axi_wvalid && (cpu_w_dest == D_MMA);
    assign m_mma_bready  = s0_axi_bready && cpu_wr_active_q && (cpu_wr_dest_q == D_MMA);
    assign m_mma_araddr  = s0_araddr32[15:0];
    assign m_mma_arprot  = s0_axi_arprot;
    assign m_mma_arvalid = s0_axi_arvalid && (cpu_ar_dest == D_MMA);
    assign m_mma_rready  = s0_axi_rready && cpu_rd_active_q && (cpu_rd_dest_q == D_MMA);

    assign m_uart_awaddr  = s0_awaddr32;
    assign m_uart_awprot  = s0_axi_awprot;
    assign m_uart_awvalid = s0_axi_awvalid && (cpu_aw_dest == D_UART);
    assign m_uart_wdata   = s0_axi_wdata[31:0];
    assign m_uart_wstrb   = s0_axi_wstrb[3:0];
    assign m_uart_wvalid  = s0_axi_wvalid && (cpu_w_dest == D_UART);
    assign m_uart_bready  = s0_axi_bready && cpu_wr_active_q && (cpu_wr_dest_q == D_UART);
    assign m_uart_araddr  = s0_araddr32;
    assign m_uart_arprot  = s0_axi_arprot;
    assign m_uart_arvalid = s0_axi_arvalid && (cpu_ar_dest == D_UART);
    assign m_uart_rready  = s0_axi_rready && cpu_rd_active_q && (cpu_rd_dest_q == D_UART);

    assign m_ctrl_awaddr  = s0_awaddr32;
    assign m_ctrl_awprot  = s0_axi_awprot;
    assign m_ctrl_awvalid = s0_axi_awvalid && (cpu_aw_dest == D_CTRL);
    assign m_ctrl_wdata   = s0_axi_wdata[31:0];
    assign m_ctrl_wstrb   = s0_axi_wstrb[3:0];
    assign m_ctrl_wvalid  = s0_axi_wvalid && (cpu_w_dest == D_CTRL);
    assign m_ctrl_bready  = s0_axi_bready && cpu_wr_active_q && (cpu_wr_dest_q == D_CTRL);
    assign m_ctrl_araddr  = s0_araddr32;
    assign m_ctrl_arprot  = s0_axi_arprot;
    assign m_ctrl_arvalid = s0_axi_arvalid && (cpu_ar_dest == D_CTRL);
    assign m_ctrl_rready  = s0_axi_rready && cpu_rd_active_q && (cpu_rd_dest_q == D_CTRL);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_rd_active_q <= 1'b0;
            ram_rd_owner_q  <= OWNER_CPU;
            ram_rd_outs_q   <= '0;
            ram_wr_active_q <= 1'b0;
            ram_wr_owner_q  <= OWNER_CPU;
            ram_wr_outs_q   <= '0;
            cpu_rd_dest_q   <= D_ERR;
            cpu_wr_dest_q   <= D_ERR;
            cpu_rd_active_q <= 1'b0;
            cpu_wr_active_q <= 1'b0;
            err_rvalid_q    <= 1'b0;
            err_bvalid_q    <= 1'b0;
        end else begin
            if (!ram_rd_active_q) begin
                if (ram_ar_hs) begin
                    ram_rd_active_q <= 1'b1;
                    ram_rd_owner_q  <= ram_ar_from_mma ? OWNER_MMA : OWNER_CPU;
                end
            end else if ((ram_rd_outs_q == RD_OUTS_W'(1)) && ram_r_last_hs &&
                         !ram_ar_hs && !ram_rd_owner_valid) begin
                ram_rd_active_q <= 1'b0;
            end

            unique case ({ram_ar_hs, ram_r_last_hs})
                2'b10: ram_rd_outs_q <= ram_rd_outs_q + 1'b1;
                2'b01: ram_rd_outs_q <= ram_rd_outs_q - 1'b1;
                default: ram_rd_outs_q <= ram_rd_outs_q;
            endcase

            if (!ram_wr_active_q) begin
                if (ram_aw_hs) begin
                    ram_wr_active_q <= 1'b1;
                    ram_wr_owner_q  <= ram_aw_from_mma ? OWNER_MMA : OWNER_CPU;
                end
            end else if ((ram_wr_outs_q == WR_OUTS_W'(1)) && ram_b_hs &&
                         !ram_aw_hs && !ram_wr_owner_aw_valid) begin
                ram_wr_active_q <= 1'b0;
            end

            unique case ({ram_aw_hs, ram_b_hs})
                2'b10: ram_wr_outs_q <= ram_wr_outs_q + 1'b1;
                2'b01: ram_wr_outs_q <= ram_wr_outs_q - 1'b1;
                default: ram_wr_outs_q <= ram_wr_outs_q;
            endcase

            if (s0_axi_arvalid && s0_axi_arready) begin
                cpu_rd_dest_q <= cpu_ar_dest;
                cpu_rd_active_q <= 1'b1;
                if (cpu_ar_dest == D_ERR) err_rvalid_q <= 1'b1;
            end
            if (s0_axi_rvalid && s0_axi_rready && s0_axi_rlast) begin
                cpu_rd_active_q <= 1'b0;
                if (cpu_rd_dest_q == D_ERR) err_rvalid_q <= 1'b0;
            end

            if (s0_axi_awvalid && s0_axi_awready) begin
                cpu_wr_dest_q <= cpu_aw_dest;
                cpu_wr_active_q <= 1'b1;
            end
            if ((cpu_aw_dest == D_ERR) && s0_axi_awvalid && s0_axi_awready &&
                ((cpu_w_dest == D_ERR) && s0_axi_wvalid && s0_axi_wready)) begin
                err_bvalid_q <= 1'b1;
            end
            if (s0_axi_bvalid && s0_axi_bready) begin
                cpu_wr_active_q <= 1'b0;
                if (cpu_wr_dest_q == D_ERR) err_bvalid_q <= 1'b0;
            end
        end
    end

endmodule
