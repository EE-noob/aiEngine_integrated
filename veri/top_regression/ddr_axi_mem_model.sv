module ddr_axi_mem_model #(
    parameter int unsigned WIDTH  = 32,
    parameter int unsigned ADDR_W = 32,
    parameter int unsigned MW     = WIDTH / 8,
    parameter int unsigned DP     = 131072,
    parameter int unsigned RDQ_DEPTH = 8
) (
    input  logic              clk,
    input  logic              rst_n,

    input  logic              m_axi_arvalid,
    output logic              m_axi_arready,
    input  logic [ADDR_W-1:0] m_axi_araddr,
    input  logic [7:0]        m_axi_arlen,
    input  logic [2:0]        m_axi_arsize,
    input  logic [1:0]        m_axi_arburst,
    output logic              m_axi_rvalid,
    input  logic              m_axi_rready,
    output logic [WIDTH-1:0]  m_axi_rdata,
    output logic [1:0]        m_axi_rresp,
    output logic              m_axi_rlast,

    input  logic              m_axi_awvalid,
    output logic              m_axi_awready,
    input  logic [ADDR_W-1:0] m_axi_awaddr,
    input  logic [7:0]        m_axi_awlen,
    input  logic [2:0]        m_axi_awsize,
    input  logic [1:0]        m_axi_awburst,
    input  logic              m_axi_wvalid,
    output logic              m_axi_wready,
    input  logic [WIDTH-1:0]  m_axi_wdata,
    input  logic [MW-1:0]     m_axi_wstrb,
    input  logic              m_axi_wlast,
    output logic              m_axi_bvalid,
    input  logic              m_axi_bready,
    output logic [1:0]        m_axi_bresp
);

    typedef enum logic [1:0] {
        R_IDLE,
        R_DATA_WAIT,
        R_DATA
    } r_state_t;

    typedef enum logic [2:0] {
        W_IDLE,
        W_AW_WAIT,
        W_DATA_WAIT,
        W_B_WAIT,
        W_B
    } w_state_t;

    logic [WIDTH-1:0] mem_r [0:DP-1];

    int unsigned rand_enable;
    int unsigned cmd_max_lat;
    int unsigned w_max_lat;
    int unsigned rsp_max_lat;
    int fixed_lat;
    int unsigned seed;

    localparam int unsigned RDQ_DEPTH_SAFE = (RDQ_DEPTH < 1) ? 1 : RDQ_DEPTH;
    localparam int unsigned RDQ_PTR_W = (RDQ_DEPTH_SAFE < 2) ? 1 : $clog2(RDQ_DEPTH_SAFE);
    localparam int unsigned RDQ_CNT_W = (RDQ_DEPTH_SAFE < 2) ? 1 : $clog2(RDQ_DEPTH_SAFE + 1);

    r_state_t r_state;
    w_state_t w_state;
    int unsigned r_wait_cnt;
    int unsigned ar_wait_cnt;
    int unsigned w_wait_cnt;
    logic [ADDR_W-1:0] r_addr;
    logic [ADDR_W-1:0] w_addr;
    logic [8:0] r_left;
    logic [8:0] w_left;
    logic [WIDTH-1:0] r_data_r;
    logic [ADDR_W-1:0] rdq_addr [0:RDQ_DEPTH_SAFE-1];
    logic [7:0] rdq_len [0:RDQ_DEPTH_SAFE-1];
    logic [RDQ_PTR_W-1:0] rdq_wptr;
    logic [RDQ_PTR_W-1:0] rdq_rptr;
    logic [RDQ_CNT_W-1:0] rdq_count;
    wire rdq_pop = (r_state == R_IDLE) && (rdq_count != '0);

    wire ar_hs = m_axi_arvalid && m_axi_arready;
    wire r_hs  = m_axi_rvalid && m_axi_rready;
    wire aw_hs = m_axi_awvalid && m_axi_awready;
    wire w_hs  = m_axi_wvalid && m_axi_wready;
    wire b_hs  = m_axi_bvalid && m_axi_bready;

    wire unused_arburst = &m_axi_arburst;
    wire unused_awburst = &m_axi_awburst;
    wire unused_wlast = m_axi_wlast;
    wire [2:0] unused_arsize = m_axi_arsize;
    wire [2:0] unused_awsize = m_axi_awsize;

    function automatic int unsigned pick_wait(input int unsigned max_lat);
        if (fixed_lat >= 0) begin
            pick_wait = fixed_lat;
        end else if ((rand_enable == 0) || (max_lat == 0)) begin
            pick_wait = 0;
        end else begin
            pick_wait = $urandom_range(max_lat, 0);
        end
    endfunction

    function automatic logic [WIDTH-1:0] mem_word(input logic [ADDR_W-1:0] addr);
        mem_word = mem_r[addr[ADDR_W-1:2]];
    endfunction

    initial begin
        int unsigned dummy;
        rand_enable = 0;
        cmd_max_lat = 0;
        w_max_lat   = 0;
        rsp_max_lat = 0;
        fixed_lat   = -1;
        seed        = 32'hdd12_cafe;
        void'($value$plusargs("DDR_RAND_LAT=%d", rand_enable));
        void'($value$plusargs("DDR_CMD_MAX_LAT=%d", cmd_max_lat));
        void'($value$plusargs("DDR_W_MAX_LAT=%d", w_max_lat));
        void'($value$plusargs("DDR_RSP_MAX_LAT=%d", rsp_max_lat));
        void'($value$plusargs("RAM_RAND_LAT=%d", rand_enable));
        void'($value$plusargs("RAM_CMD_MAX_LAT=%d", cmd_max_lat));
        void'($value$plusargs("RAM_W_MAX_LAT=%d", w_max_lat));
        void'($value$plusargs("RAM_RSP_MAX_LAT=%d", rsp_max_lat));
        void'($value$plusargs("RAM_FIXED_LAT=%d", fixed_lat));
        void'($value$plusargs("DDR_SEED=%d", seed));
        dummy = $urandom(seed);
        if (fixed_lat >= 0) begin
            $display("[RAM_AXI_MEM] fixed response latency=%0d cycles", fixed_lat);
        end else if (rand_enable != 0) begin
            $display("[RAM_AXI_MEM] seed=%0d cmd_max=%0d w_max=%0d rsp_max=%0d",
                     seed, cmd_max_lat, w_max_lat, rsp_max_lat);
        end
    end

    assign m_axi_arready = (rdq_count < RDQ_CNT_W'(RDQ_DEPTH_SAFE)) && (ar_wait_cnt == 0);
    assign m_axi_rvalid  = (r_state == R_DATA);
    assign m_axi_rdata   = r_data_r;
    assign m_axi_rresp   = 2'b00;
    assign m_axi_rlast   = (r_left == 9'd1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state    <= R_IDLE;
            r_wait_cnt <= 0;
            ar_wait_cnt <= 0;
            r_addr     <= '0;
            r_left     <= '0;
            r_data_r   <= '0;
            rdq_wptr   <= '0;
            rdq_rptr   <= '0;
            rdq_count  <= '0;
        end else begin
            if (ar_wait_cnt != 0) begin
                ar_wait_cnt <= ar_wait_cnt - 1;
            end

            if (ar_hs) begin
                rdq_addr[rdq_wptr] <= m_axi_araddr;
                rdq_len[rdq_wptr]  <= m_axi_arlen;
                if (rdq_wptr == RDQ_PTR_W'(RDQ_DEPTH_SAFE - 1)) begin
                    rdq_wptr <= '0;
                end else begin
                    rdq_wptr <= rdq_wptr + 1'b1;
                end
                ar_wait_cnt <= pick_wait(cmd_max_lat);
            end

            if (rdq_pop) begin
                if (rdq_rptr == RDQ_PTR_W'(RDQ_DEPTH_SAFE - 1)) begin
                    rdq_rptr <= '0;
                end else begin
                    rdq_rptr <= rdq_rptr + 1'b1;
                end
            end

            unique case ({ar_hs, rdq_pop})
                2'b10: rdq_count <= rdq_count + 1'b1;
                2'b01: rdq_count <= rdq_count - 1'b1;
                default: rdq_count <= rdq_count;
            endcase

            case (r_state)
                R_IDLE: begin
                    if (rdq_pop) begin
                        r_addr     <= rdq_addr[rdq_rptr];
                        r_left     <= {1'b0, rdq_len[rdq_rptr]} + 9'd1;
                        r_data_r   <= mem_word(rdq_addr[rdq_rptr]);
                        r_wait_cnt <= pick_wait(rsp_max_lat);
                        r_state    <= R_DATA_WAIT;
                    end
                end

                R_DATA_WAIT: begin
                    if (r_wait_cnt != 0) begin
                        r_wait_cnt <= r_wait_cnt - 1;
                    end else begin
                        r_state <= R_DATA;
                    end
                end

                R_DATA: begin
                    if (r_hs) begin
                        if (r_left <= 9'd1) begin
                            r_left  <= '0;
                            r_state <= R_IDLE;
                        end else begin
                            r_left     <= r_left - 9'd1;
                            r_addr     <= r_addr + ADDR_W'(MW);
                            r_data_r   <= mem_word(r_addr + ADDR_W'(MW));
                            r_wait_cnt <= 0;
                            r_state    <= R_DATA;
                        end
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

    assign m_axi_awready = (w_state == W_AW_WAIT) && (w_wait_cnt == 0);
    assign m_axi_wready  = (w_state == W_DATA_WAIT) && (w_wait_cnt == 0);
    assign m_axi_bvalid  = (w_state == W_B);
    assign m_axi_bresp   = 2'b00;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state    <= W_IDLE;
            w_wait_cnt <= 0;
            w_addr     <= '0;
            w_left     <= '0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (m_axi_awvalid) begin
                        w_wait_cnt <= pick_wait(cmd_max_lat);
                        w_state    <= W_AW_WAIT;
                    end
                end

                W_AW_WAIT: begin
                    if (!m_axi_awvalid) begin
                        w_state <= W_IDLE;
                    end else if (w_wait_cnt != 0) begin
                        w_wait_cnt <= w_wait_cnt - 1;
                    end else if (aw_hs) begin
                        w_addr     <= m_axi_awaddr;
                        w_left     <= {1'b0, m_axi_awlen} + 9'd1;
                        w_wait_cnt <= pick_wait(w_max_lat);
                        w_state    <= W_DATA_WAIT;
                    end
                end

                W_DATA_WAIT: begin
                    if (w_wait_cnt != 0) begin
                        w_wait_cnt <= w_wait_cnt - 1;
                    end else if (w_hs) begin
                        for (int b = 0; b < MW; b++) begin
                            if (m_axi_wstrb[b]) begin
                                mem_r[w_addr[ADDR_W-1:2]][b*8+:8] <= m_axi_wdata[b*8+:8];
                            end
                        end

                        if (w_left <= 9'd1) begin
                            w_left     <= '0;
                            w_wait_cnt <= pick_wait(rsp_max_lat);
                            w_state    <= W_B_WAIT;
                        end else begin
                            w_left     <= w_left - 9'd1;
                            w_addr     <= w_addr + ADDR_W'(MW);
                            w_wait_cnt <= 0;
                        end
                    end
                end

                W_B_WAIT: begin
                    if (w_wait_cnt != 0) begin
                        w_wait_cnt <= w_wait_cnt - 1;
                    end else begin
                        w_state <= W_B;
                    end
                end

                W_B: begin
                    if (b_hs) begin
                        w_state <= W_IDLE;
                    end
                end

                default: w_state <= W_IDLE;
            endcase
        end
    end

endmodule
