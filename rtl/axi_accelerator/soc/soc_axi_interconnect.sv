module soc_axi_interconnect #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned CPU_MEM_DP = 524288,
    parameter int unsigned READ_OUTSTANDING = 4,
    parameter int unsigned WRITE_OUTSTANDING = READ_OUTSTANDING,
    parameter logic [31:0] CPU_RAM_BASE  = 32'h0000_0000,
    parameter logic [31:0] NPU_AXIL_BASE = 32'h1000_0000,
    parameter logic [31:0] UART_BASE     = 32'h0200_0000,
    parameter logic [31:0] SOC_CTRL_BASE = 32'h2000_0000
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         npu_bus_lock,

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

    output wire [15:0]                  m_npu_awaddr,
    output wire [2:0]                   m_npu_awprot,
    output wire                         m_npu_awvalid,
    input  wire                         m_npu_awready,
    output wire [31:0]                  m_npu_wdata,
    output wire [3:0]                   m_npu_wstrb,
    output wire                         m_npu_wvalid,
    input  wire                         m_npu_wready,
    input  wire [1:0]                   m_npu_bresp,
    input  wire                         m_npu_bvalid,
    output wire                         m_npu_bready,
    output wire [15:0]                  m_npu_araddr,
    output wire [2:0]                   m_npu_arprot,
    output wire                         m_npu_arvalid,
    input  wire                         m_npu_arready,
    input  wire [31:0]                  m_npu_rdata,
    input  wire [1:0]                   m_npu_rresp,
    input  wire                         m_npu_rvalid,
    output wire                         m_npu_rready,

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
        D_NPU  = 3'd1,
        D_UART = 3'd2,
        D_CTRL = 3'd3,
        D_ERR  = 3'd7
    } dest_e;

    typedef enum logic {
        OWNER_CPU = 1'b0,
        OWNER_NPU = 1'b1
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
    logic [ADDR_WIDTH-1:0] cpu_arq_addr_q [2];
    logic [3:0]            cpu_arq_cache_q [2];
    logic [2:0]            cpu_arq_prot_q [2];
    logic [1:0]            cpu_arq_lock_q [2];
    logic [1:0]            cpu_arq_burst_q [2];
    logic [7:0]            cpu_arq_len_q [2];
    logic [2:0]            cpu_arq_size_q [2];
    dest_e                 cpu_arq_dest_q [2];
    logic                  cpu_arq_rd_sel_q;
    logic                  cpu_arq_wr_sel_q;
    logic [1:0]            cpu_arq_count_q;

    function automatic dest_e decode_cpu_addr(input logic [ADDR_WIDTH-1:0] addr);
        logic [31:0] offset;
        begin
            offset = addr[31:0] - CPU_RAM_BASE;
            if (((CPU_RAM_BASE == 32'h0) || (addr[31:0] >= CPU_RAM_BASE)) &&
                (32'(offset[31:CPU_ADDR_LSB]) < 32'(CPU_MEM_DP))) begin
                decode_cpu_addr = D_RAM;
            end else if (addr[31:28] == NPU_AXIL_BASE[31:28]) begin
                decode_cpu_addr = D_NPU;
            end else if (addr[31:12] == UART_BASE[31:12]) begin
                decode_cpu_addr = D_UART;
            end else if (addr[31:28] == SOC_CTRL_BASE[31:28]) begin
                decode_cpu_addr = D_CTRL;
            end else begin
                decode_cpu_addr = D_ERR;
            end
        end
    endfunction

    wire [31:0] s0_awaddr32 = s0_axi_awaddr[31:0];
    dest_e cpu_ar_dest;
    dest_e cpu_aw_dest;
    dest_e cpu_w_dest;

    always_comb begin
        cpu_ar_dest = decode_cpu_addr(s0_axi_araddr);
        cpu_aw_dest = decode_cpu_addr(s0_axi_awaddr);
        cpu_w_dest  = cpu_wr_active_q ? cpu_wr_dest_q : cpu_aw_dest;
    end

    wire cpu_block_new_req = npu_bus_lock;
    wire cpu_arq_full  = cpu_arq_count_q == 2'd2;
    wire cpu_arq_valid = cpu_arq_count_q != 2'd0;
    wire cpu_arq_push  = s0_axi_arvalid && s0_axi_arready;
    wire [ADDR_WIDTH-1:0] cpu_arq_addr = cpu_arq_rd_sel_q ? cpu_arq_addr_q[1] :
                                                             cpu_arq_addr_q[0];
    wire [3:0] cpu_arq_cache = cpu_arq_rd_sel_q ? cpu_arq_cache_q[1] :
                                                   cpu_arq_cache_q[0];
    wire [2:0] cpu_arq_prot = cpu_arq_rd_sel_q ? cpu_arq_prot_q[1] :
                                                  cpu_arq_prot_q[0];
    wire [1:0] cpu_arq_lock = cpu_arq_rd_sel_q ? cpu_arq_lock_q[1] :
                                                  cpu_arq_lock_q[0];
    wire [1:0] cpu_arq_burst = cpu_arq_rd_sel_q ? cpu_arq_burst_q[1] :
                                                   cpu_arq_burst_q[0];
    wire [7:0] cpu_arq_len = cpu_arq_rd_sel_q ? cpu_arq_len_q[1] :
                                                cpu_arq_len_q[0];
    wire [2:0] cpu_arq_size = cpu_arq_rd_sel_q ? cpu_arq_size_q[1] :
                                                  cpu_arq_size_q[0];
    dest_e cpu_arq_dest;
    assign cpu_arq_dest = cpu_arq_rd_sel_q ? cpu_arq_dest_q[1] :
                                             cpu_arq_dest_q[0];
    wire [31:0] cpu_arq_addr32 = cpu_arq_addr[31:0];

    wire cpu_r_last_hs = s0_axi_rvalid && s0_axi_rready && s0_axi_rlast;
    wire cpu_rd_issue_avail = !cpu_rd_active_q || cpu_r_last_hs;
    wire cpu_issue_ar_allowed = !cpu_block_new_req;
    wire cpu_ram_ar_req = cpu_issue_ar_allowed && cpu_arq_valid && cpu_rd_issue_avail &&
                          (cpu_arq_dest == D_RAM);
    wire cpu_npu_ar_req = cpu_issue_ar_allowed && cpu_arq_valid && cpu_rd_issue_avail &&
                          (cpu_arq_dest == D_NPU);
    wire cpu_uart_ar_req = cpu_issue_ar_allowed && cpu_arq_valid && cpu_rd_issue_avail &&
                           (cpu_arq_dest == D_UART);
    wire cpu_ctrl_ar_req = cpu_issue_ar_allowed && cpu_arq_valid && cpu_rd_issue_avail &&
                           (cpu_arq_dest == D_CTRL);
    wire cpu_err_ar_req = cpu_issue_ar_allowed && cpu_arq_valid && cpu_rd_issue_avail &&
                          (cpu_arq_dest == D_ERR) &&
                          !err_rvalid_q;
    wire npu_ram_ar_req = s1_axi_arvalid;
    wire cpu_issue_aw_allowed = !cpu_block_new_req;
    wire cpu_issue_w_allowed = !cpu_block_new_req || cpu_wr_active_q;
    wire cpu_ram_aw_req = cpu_issue_aw_allowed && s0_axi_awvalid &&
                          (cpu_aw_dest == D_RAM);
    wire npu_ram_aw_req = s1_axi_awvalid;

    wire ram_rd_owner_valid = ram_rd_owner_q == OWNER_NPU ? npu_ram_ar_req :
                                                           cpu_ram_ar_req;
    wire ram_wr_owner_aw_valid = ram_wr_owner_q == OWNER_NPU ? npu_ram_aw_req :
                                                              cpu_ram_aw_req;
    wire ram_rd_other_waiting = ram_rd_active_q &&
                                (ram_rd_owner_q == OWNER_NPU ? cpu_ram_ar_req :
                                                               npu_ram_ar_req);
    wire ram_wr_other_waiting = ram_wr_active_q &&
                                (ram_wr_owner_q == OWNER_NPU ? cpu_ram_aw_req :
                                                               npu_ram_aw_req);
    wire ram_rd_select_cpu = !ram_rd_active_q && cpu_ram_ar_req &&
                             (!npu_ram_ar_req || (ram_rd_owner_q == OWNER_NPU));
    wire ram_rd_select_npu = !ram_rd_active_q && npu_ram_ar_req &&
                             (!cpu_ram_ar_req || (ram_rd_owner_q == OWNER_CPU));
    wire ram_wr_select_cpu = !ram_wr_active_q && cpu_ram_aw_req &&
                             (!npu_ram_aw_req || (ram_wr_owner_q == OWNER_NPU));
    wire ram_wr_select_npu = !ram_wr_active_q && npu_ram_aw_req &&
                             (!cpu_ram_aw_req || (ram_wr_owner_q == OWNER_CPU));

    wire ram_ar_from_npu = ram_rd_active_q ? (ram_rd_owner_q == OWNER_NPU) : ram_rd_select_npu;
    wire ram_ar_from_cpu = ram_rd_active_q ? (ram_rd_owner_q == OWNER_CPU) : ram_rd_select_cpu;
    wire ram_aw_from_npu = ram_wr_active_q ? (ram_wr_owner_q == OWNER_NPU) : ram_wr_select_npu;
    wire ram_aw_from_cpu = ram_wr_active_q ? (ram_wr_owner_q == OWNER_CPU) : ram_wr_select_cpu;
    wire ram_w_from_npu = (ram_wr_active_q && (ram_wr_owner_q == OWNER_NPU)) ||
                          (!ram_wr_active_q && ram_wr_select_npu);
    wire ram_w_from_cpu = (ram_wr_active_q && (ram_wr_owner_q == OWNER_CPU)) ||
                          (!ram_wr_active_q && ram_wr_select_cpu);
    wire ram_rd_yield = ram_rd_active_q && (ram_rd_owner_q == OWNER_CPU) && npu_ram_ar_req;
    wire ram_wr_yield = ram_wr_active_q && (ram_wr_owner_q == OWNER_CPU) && npu_ram_aw_req;

    wire ram_ar_hs = m_ram_arvalid && m_ram_arready;
    wire ram_r_last_hs = m_ram_rvalid && m_ram_rready && m_ram_rlast;
    wire ram_aw_hs = m_ram_awvalid && m_ram_awready;
    wire ram_b_hs = m_ram_bvalid && m_ram_bready;
    wire ram_rd_slot_avail = (ram_rd_outs_q != RD_OUTS_W'(RD_OUTS_DEPTH)) || ram_r_last_hs;
    wire ram_wr_slot_avail = (ram_wr_outs_q != WR_OUTS_W'(WR_OUTS_DEPTH)) || ram_b_hs;
    wire cpu_ram_ar_hs = ram_ar_hs && ram_ar_from_cpu;
    wire cpu_npu_ar_hs = cpu_npu_ar_req && m_npu_arready;
    wire cpu_uart_ar_hs = cpu_uart_ar_req && m_uart_arready;
    wire cpu_ctrl_ar_hs = cpu_ctrl_ar_req && m_ctrl_arready;
    wire cpu_err_ar_hs = cpu_err_ar_req;
    wire cpu_ar_hs = cpu_ram_ar_hs || cpu_npu_ar_hs || cpu_uart_ar_hs ||
                     cpu_ctrl_ar_hs || cpu_err_ar_hs;
    wire cpu_arq_pop = cpu_ar_hs;
    wire cpu_aw_hs = s0_axi_awvalid && s0_axi_awready;
    wire cpu_w_hs = s0_axi_wvalid && s0_axi_wready;
    wire cpu_b_hs = s0_axi_bvalid && s0_axi_bready;
    wire cpu_err_write_hs = cpu_aw_hs && (cpu_aw_dest == D_ERR) &&
                            cpu_w_hs && (cpu_w_dest == D_ERR);

    always_comb begin
        s0_axi_arready = !cpu_block_new_req && !cpu_arq_full;
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

        if (ram_ar_from_npu) begin
            m_ram_arvalid = npu_ram_ar_req && ram_rd_slot_avail && !ram_rd_yield;
            m_ram_araddr  = s1_axi_araddr;
            m_ram_arcache = s1_axi_arcache;
            m_ram_arprot  = s1_axi_arprot;
            m_ram_arlock  = s1_axi_arlock;
            m_ram_arburst = s1_axi_arburst;
            m_ram_arlen   = s1_axi_arlen;
            m_ram_arsize  = s1_axi_arsize;
            s1_axi_arready = m_ram_arready && ram_rd_slot_avail && !ram_rd_yield;
        end else if (ram_ar_from_cpu) begin
            m_ram_arvalid = cpu_ram_ar_req && ram_rd_slot_avail && !ram_rd_yield;
            m_ram_araddr  = cpu_arq_addr;
            m_ram_arcache = cpu_arq_cache;
            m_ram_arprot  = cpu_arq_prot;
            m_ram_arlock  = cpu_arq_lock;
            m_ram_arburst = cpu_arq_burst;
            m_ram_arlen   = cpu_arq_len;
            m_ram_arsize  = cpu_arq_size;
        end

        if (ram_rd_active_q && (ram_rd_owner_q == OWNER_NPU)) begin
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

        if (cpu_rd_active_q) begin
            unique case (cpu_rd_dest_q)
                D_NPU: begin
                    s0_axi_rvalid = m_npu_rvalid;
                    s0_axi_rdata  = m_npu_rdata;
                    s0_axi_rresp  = m_npu_rresp;
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

        if (ram_aw_from_npu) begin
            m_ram_awvalid = npu_ram_aw_req && ram_wr_slot_avail && !ram_wr_yield;
            m_ram_awaddr  = s1_axi_awaddr;
            m_ram_awcache = s1_axi_awcache;
            m_ram_awprot  = s1_axi_awprot;
            m_ram_awlock  = s1_axi_awlock;
            m_ram_awburst = s1_axi_awburst;
            m_ram_awlen   = s1_axi_awlen;
            m_ram_awsize  = s1_axi_awsize;
            s1_axi_awready = m_ram_awready && ram_wr_slot_avail && !ram_wr_yield;
        end else if (ram_aw_from_cpu) begin
            m_ram_awvalid = cpu_ram_aw_req && ram_wr_slot_avail && !ram_wr_yield;
            m_ram_awaddr  = s0_axi_awaddr;
            m_ram_awcache = s0_axi_awcache;
            m_ram_awprot  = s0_axi_awprot;
            m_ram_awlock  = s0_axi_awlock;
            m_ram_awburst = s0_axi_awburst;
            m_ram_awlen   = s0_axi_awlen;
            m_ram_awsize  = s0_axi_awsize;
            s0_axi_awready = cpu_ram_aw_req && m_ram_awready &&
                              ram_wr_slot_avail && !ram_wr_yield;
        end

        if (ram_w_from_npu) begin
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

        if (ram_wr_active_q && (ram_wr_owner_q == OWNER_NPU)) begin
            s1_axi_bvalid = m_ram_bvalid;
            s1_axi_bresp  = m_ram_bresp;
            m_ram_bready  = s1_axi_bready;
        end else if (ram_wr_active_q && (ram_wr_owner_q == OWNER_CPU) &&
                     (cpu_wr_dest_q == D_RAM)) begin
            s0_axi_bvalid = m_ram_bvalid;
            s0_axi_bresp  = m_ram_bresp;
            m_ram_bready  = s0_axi_bready;
        end

        if (cpu_issue_aw_allowed) begin
            if (cpu_aw_dest == D_NPU) s0_axi_awready = m_npu_awready;
            else if (cpu_aw_dest == D_UART) s0_axi_awready = m_uart_awready;
            else if (cpu_aw_dest == D_CTRL) s0_axi_awready = m_ctrl_awready;
            else if (cpu_aw_dest == D_ERR) s0_axi_awready = !err_bvalid_q;
        end

        if (cpu_issue_w_allowed) begin
            unique case (cpu_w_dest)
                D_NPU:  s0_axi_wready = m_npu_wready;
                D_UART: s0_axi_wready = m_uart_wready;
                D_CTRL: s0_axi_wready = m_ctrl_wready;
                D_ERR:  s0_axi_wready = !err_bvalid_q;
                default: begin
                end
            endcase
        end

        if (cpu_wr_active_q) begin
            unique case (cpu_wr_dest_q)
                D_NPU: begin
                    s0_axi_bvalid = m_npu_bvalid;
                    s0_axi_bresp  = m_npu_bresp;
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

    assign m_npu_awaddr  = s0_awaddr32[15:0];
    assign m_npu_awprot  = s0_axi_awprot;
    assign m_npu_awvalid = cpu_issue_aw_allowed && s0_axi_awvalid && (cpu_aw_dest == D_NPU);
    assign m_npu_wdata   = s0_axi_wdata[31:0];
    assign m_npu_wstrb   = s0_axi_wstrb[3:0];
    assign m_npu_wvalid  = cpu_issue_w_allowed && s0_axi_wvalid && (cpu_w_dest == D_NPU);
    assign m_npu_bready  = s0_axi_bready && cpu_wr_active_q && (cpu_wr_dest_q == D_NPU);
    assign m_npu_araddr  = cpu_arq_addr32[15:0];
    assign m_npu_arprot  = cpu_arq_prot;
    assign m_npu_arvalid = cpu_npu_ar_req;
    assign m_npu_rready  = s0_axi_rready && cpu_rd_active_q && (cpu_rd_dest_q == D_NPU);

    assign m_uart_awaddr  = s0_awaddr32;
    assign m_uart_awprot  = s0_axi_awprot;
    assign m_uart_awvalid = cpu_issue_aw_allowed && s0_axi_awvalid && (cpu_aw_dest == D_UART);
    assign m_uart_wdata   = s0_axi_wdata[31:0];
    assign m_uart_wstrb   = s0_axi_wstrb[3:0];
    assign m_uart_wvalid  = cpu_issue_w_allowed && s0_axi_wvalid && (cpu_w_dest == D_UART);
    assign m_uart_bready  = s0_axi_bready && cpu_wr_active_q && (cpu_wr_dest_q == D_UART);
    assign m_uart_araddr  = cpu_arq_addr32;
    assign m_uart_arprot  = cpu_arq_prot;
    assign m_uart_arvalid = cpu_uart_ar_req;
    assign m_uart_rready  = s0_axi_rready && cpu_rd_active_q && (cpu_rd_dest_q == D_UART);

    assign m_ctrl_awaddr  = s0_awaddr32;
    assign m_ctrl_awprot  = s0_axi_awprot;
    assign m_ctrl_awvalid = cpu_issue_aw_allowed && s0_axi_awvalid && (cpu_aw_dest == D_CTRL);
    assign m_ctrl_wdata   = s0_axi_wdata[31:0];
    assign m_ctrl_wstrb   = s0_axi_wstrb[3:0];
    assign m_ctrl_wvalid  = cpu_issue_w_allowed && s0_axi_wvalid && (cpu_w_dest == D_CTRL);
    assign m_ctrl_bready  = s0_axi_bready && cpu_wr_active_q && (cpu_wr_dest_q == D_CTRL);
    assign m_ctrl_araddr  = cpu_arq_addr32;
    assign m_ctrl_arprot  = cpu_arq_prot;
    assign m_ctrl_arvalid = cpu_ctrl_ar_req;
    assign m_ctrl_rready  = s0_axi_rready && cpu_rd_active_q && (cpu_rd_dest_q == D_CTRL);

`ifndef SYNTHESIS
    bit axi_stats_en;
    longint unsigned cpu_ram_ar_wait_cycles;
    longint unsigned npu_ram_ar_wait_cycles;
    longint unsigned cpu_ram_aw_wait_cycles;
    longint unsigned npu_ram_aw_wait_cycles;
    longint unsigned rd_yield_cycles;
    longint unsigned wr_yield_cycles;
    longint unsigned npu_lock_cycles;
    longint unsigned cpu_lock_ar_block_cycles;
    longint unsigned cpu_lock_aw_block_cycles;
    longint unsigned cpu_lock_w_block_cycles;

    initial begin
        axi_stats_en = $test$plusargs("SOC_AXI_STATS");
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_ram_ar_wait_cycles <= 0;
            npu_ram_ar_wait_cycles <= 0;
            cpu_ram_aw_wait_cycles <= 0;
            npu_ram_aw_wait_cycles <= 0;
            rd_yield_cycles        <= 0;
            wr_yield_cycles        <= 0;
            npu_lock_cycles        <= 0;
            cpu_lock_ar_block_cycles <= 0;
            cpu_lock_aw_block_cycles <= 0;
            cpu_lock_w_block_cycles  <= 0;
        end else if (axi_stats_en) begin
            if (cpu_ram_ar_req && !cpu_ram_ar_hs) begin
                cpu_ram_ar_wait_cycles <= cpu_ram_ar_wait_cycles + 1;
            end
            if (npu_ram_ar_req && !s1_axi_arready) begin
                npu_ram_ar_wait_cycles <= npu_ram_ar_wait_cycles + 1;
            end
            if (cpu_ram_aw_req && !s0_axi_awready) begin
                cpu_ram_aw_wait_cycles <= cpu_ram_aw_wait_cycles + 1;
            end
            if (npu_ram_aw_req && !s1_axi_awready) begin
                npu_ram_aw_wait_cycles <= npu_ram_aw_wait_cycles + 1;
            end
            if (ram_rd_yield) begin
                rd_yield_cycles <= rd_yield_cycles + 1;
            end
            if (ram_wr_yield) begin
                wr_yield_cycles <= wr_yield_cycles + 1;
            end
            if (npu_bus_lock) begin
                npu_lock_cycles <= npu_lock_cycles + 1;
            end
            if (npu_bus_lock && s0_axi_arvalid && !s0_axi_arready) begin
                cpu_lock_ar_block_cycles <= cpu_lock_ar_block_cycles + 1;
            end
            if (npu_bus_lock && s0_axi_awvalid && !s0_axi_awready) begin
                cpu_lock_aw_block_cycles <= cpu_lock_aw_block_cycles + 1;
            end
            if (npu_bus_lock && s0_axi_wvalid && !s0_axi_wready) begin
                cpu_lock_w_block_cycles <= cpu_lock_w_block_cycles + 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n && npu_bus_lock) begin
            if (s0_axi_arvalid && s0_axi_arready) begin
                $error("CPU AR accepted while NPU bus lock is active");
            end
            if (s0_axi_awvalid && s0_axi_awready) begin
                $error("CPU AW accepted while NPU bus lock is active");
            end
        end
    end

    final begin
        if (axi_stats_en) begin
            $display("[SOC_AXI_STATS] cpu_ar_wait=%0d npu_ar_wait=%0d cpu_aw_wait=%0d npu_aw_wait=%0d rd_yield=%0d wr_yield=%0d npu_lock=%0d cpu_lock_ar_block=%0d cpu_lock_aw_block=%0d cpu_lock_w_block=%0d",
                     cpu_ram_ar_wait_cycles, npu_ram_ar_wait_cycles,
                     cpu_ram_aw_wait_cycles, npu_ram_aw_wait_cycles,
                     rd_yield_cycles, wr_yield_cycles, npu_lock_cycles,
                     cpu_lock_ar_block_cycles, cpu_lock_aw_block_cycles,
                     cpu_lock_w_block_cycles);
        end
    end
`endif

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
            cpu_arq_rd_sel_q <= 1'b0;
            cpu_arq_wr_sel_q <= 1'b0;
            cpu_arq_count_q  <= 2'd0;
            for (int i = 0; i < 2; i++) begin
                cpu_arq_addr_q[i]  <= '0;
                cpu_arq_cache_q[i] <= '0;
                cpu_arq_prot_q[i]  <= '0;
                cpu_arq_lock_q[i]  <= '0;
                cpu_arq_burst_q[i] <= '0;
                cpu_arq_len_q[i]   <= '0;
                cpu_arq_size_q[i]  <= '0;
                cpu_arq_dest_q[i]  <= D_ERR;
            end
        end else begin
            if (cpu_arq_push) begin
                cpu_arq_addr_q[cpu_arq_wr_sel_q]  <= s0_axi_araddr;
                cpu_arq_cache_q[cpu_arq_wr_sel_q] <= s0_axi_arcache;
                cpu_arq_prot_q[cpu_arq_wr_sel_q]  <= s0_axi_arprot;
                cpu_arq_lock_q[cpu_arq_wr_sel_q]  <= s0_axi_arlock;
                cpu_arq_burst_q[cpu_arq_wr_sel_q] <= s0_axi_arburst;
                cpu_arq_len_q[cpu_arq_wr_sel_q]   <= s0_axi_arlen;
                cpu_arq_size_q[cpu_arq_wr_sel_q]  <= s0_axi_arsize;
                cpu_arq_dest_q[cpu_arq_wr_sel_q]  <= cpu_ar_dest;
                cpu_arq_wr_sel_q <= ~cpu_arq_wr_sel_q;
            end
            if (cpu_arq_pop) begin
                cpu_arq_rd_sel_q <= ~cpu_arq_rd_sel_q;
            end
            unique case ({cpu_arq_push, cpu_arq_pop})
                2'b10: cpu_arq_count_q <= cpu_arq_count_q + 2'd1;
                2'b01: cpu_arq_count_q <= cpu_arq_count_q - 2'd1;
                default: cpu_arq_count_q <= cpu_arq_count_q;
            endcase

            if (!ram_rd_active_q) begin
                if (ram_ar_hs) begin
                    ram_rd_active_q <= 1'b1;
                    ram_rd_owner_q  <= ram_ar_from_npu ? OWNER_NPU : OWNER_CPU;
                end
            end else if ((ram_rd_outs_q == RD_OUTS_W'(1)) && ram_r_last_hs &&
                         !ram_ar_hs &&
                         (!ram_rd_owner_valid || ram_rd_other_waiting)) begin
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
                    ram_wr_owner_q  <= ram_aw_from_npu ? OWNER_NPU : OWNER_CPU;
                end
            end else if ((ram_wr_outs_q == WR_OUTS_W'(1)) && ram_b_hs &&
                         !ram_aw_hs &&
                         (!ram_wr_owner_aw_valid || ram_wr_other_waiting)) begin
                ram_wr_active_q <= 1'b0;
            end

            unique case ({ram_aw_hs, ram_b_hs})
                2'b10: ram_wr_outs_q <= ram_wr_outs_q + 1'b1;
                2'b01: ram_wr_outs_q <= ram_wr_outs_q - 1'b1;
                default: ram_wr_outs_q <= ram_wr_outs_q;
            endcase

            if (cpu_r_last_hs && (cpu_rd_dest_q == D_ERR)) begin
                err_rvalid_q <= 1'b0;
            end
            if (cpu_ar_hs) begin
                cpu_rd_dest_q <= cpu_arq_dest;
                if (cpu_arq_dest == D_ERR) err_rvalid_q <= 1'b1;
            end

            unique case ({cpu_ar_hs, cpu_r_last_hs})
                2'b10: cpu_rd_active_q <= 1'b1;
                2'b01: cpu_rd_active_q <= 1'b0;
                2'b11: cpu_rd_active_q <= 1'b1;
                default: cpu_rd_active_q <= cpu_rd_active_q;
            endcase

            if (cpu_b_hs && (cpu_wr_dest_q == D_ERR)) begin
                err_bvalid_q <= 1'b0;
            end
            if (cpu_aw_hs) begin
                cpu_wr_dest_q <= cpu_aw_dest;
            end
            if (cpu_err_write_hs) begin
                err_bvalid_q <= 1'b1;
            end

            unique case ({cpu_aw_hs, cpu_b_hs})
                2'b10: cpu_wr_active_q <= 1'b1;
                2'b01: cpu_wr_active_q <= 1'b0;
                2'b11: cpu_wr_active_q <= 1'b1;
                default: cpu_wr_active_q <= cpu_wr_active_q;
            endcase
        end
    end

endmodule
