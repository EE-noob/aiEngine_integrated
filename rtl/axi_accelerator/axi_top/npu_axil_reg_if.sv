module npu_axil_reg_if #(
    parameter int unsigned AXIL_DATA_WIDTH = 32,
    parameter int unsigned AXIL_ADDR_WIDTH = 16,
    parameter int unsigned REG_WIDTH       = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_awaddr,
    input  wire [2:0]                   s_axil_awprot,
    input  wire                         s_axil_awvalid,
    output wire                         s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]   s_axil_wdata,
    input  wire [AXIL_DATA_WIDTH/8-1:0] s_axil_wstrb,
    input  wire                         s_axil_wvalid,
    output wire                         s_axil_wready,
    output wire [1:0]                   s_axil_bresp,
    output wire                         s_axil_bvalid,
    input  wire                         s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_araddr,
    input  wire [2:0]                   s_axil_arprot,
    input  wire                         s_axil_arvalid,
    output wire                         s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]   s_axil_rdata,
    output wire [1:0]                   s_axil_rresp,
    output wire                         s_axil_rvalid,
    input  wire                         s_axil_rready,

    output logic                        calc_start,
    output logic                        cfg_16bits_ia,
    output logic                        cfg_16x8,
    output logic                        cfg_dataflow_mode,
    output logic                        use_per_channel,
    output logic [REG_WIDTH-1:0]        cfg_ia_reuse_num,
    output logic [REG_WIDTH-1:0]        cfg_w_reuse_num,
    output logic [REG_WIDTH-1:0] cfg_row_groups,
    output logic [REG_WIDTH-1:0] cfg_row_tail_tiles,
    output logic [REG_WIDTH-1:0] cfg_col_groups,
    output logic [REG_WIDTH-1:0] cfg_col_tail_tiles,

    output logic [REG_WIDTH-1:0]        lhs_base,
    output logic [REG_WIDTH-1:0]        rhs_base,
    output logic [REG_WIDTH-1:0]        dst_base,
    output logic [REG_WIDTH-1:0]        bias_base,
    output logic signed [REG_WIDTH-1:0] lhs_zp,
    output logic signed [REG_WIDTH-1:0] rhs_zp,
    output logic signed [REG_WIDTH-1:0] dst_zp,
    output logic signed [REG_WIDTH-1:0] q_mult_pt,
    output logic signed [REG_WIDTH-1:0] q_shift_pt,
    output logic [REG_WIDTH-1:0]        k,
    output logic [REG_WIDTH-1:0]        n,
    output logic [REG_WIDTH-1:0]        m,
    output logic [REG_WIDTH-1:0]        lhs_row_stride_b,
    output logic [REG_WIDTH-1:0]        rhs_col_stride_b,
    output logic [REG_WIDTH-1:0]        dst_row_stride_b,
    output logic signed [REG_WIDTH-1:0] act_min,
    output logic signed [REG_WIDTH-1:0] act_max,

    input  wire                         npu_sa_ready,
    input  wire                         npu_done_valid,
    output wire                         npu_done_ready,
    input  wire [1:0]                   npu_err_code,

    output wire                         irq,
    output wire                         npu_busy,
    output wire [31:0]                  status_bits
);

    localparam int unsigned STRB_WIDTH = AXIL_DATA_WIDTH / 8;

    localparam logic [11:0] REG_CTRL         = 12'h000; // 0x000
    localparam logic [11:0] REG_STATUS       = 12'h001; // 0x004
    localparam logic [11:0] REG_WB_DATA      = 12'h002; // 0x008
    localparam logic [11:0] REG_LHS_BASE     = 12'h004; // 0x010
    localparam logic [11:0] REG_RHS_BASE     = 12'h005; // 0x014
    localparam logic [11:0] REG_DST_BASE     = 12'h006; // 0x018
    localparam logic [11:0] REG_BIAS_BASE    = 12'h007; // 0x01c
    localparam logic [11:0] REG_K            = 12'h008; // 0x020
    localparam logic [11:0] REG_N            = 12'h009; // 0x024
    localparam logic [11:0] REG_M            = 12'h00a; // 0x028
    localparam logic [11:0] REG_LHS_STRIDE_B = 12'h00b; // 0x02c
    localparam logic [11:0] REG_RHS_STRIDE_B = 12'h00c; // 0x030
    localparam logic [11:0] REG_DST_STRIDE_B = 12'h00d; // 0x034
    localparam logic [11:0] REG_LHS_ZP       = 12'h00e; // 0x038
    localparam logic [11:0] REG_RHS_ZP       = 12'h00f; // 0x03c
    localparam logic [11:0] REG_DST_ZP       = 12'h010; // 0x040
    localparam logic [11:0] REG_Q_MULT       = 12'h011; // 0x044
    localparam logic [11:0] REG_Q_SHIFT      = 12'h012; // 0x048
    localparam logic [11:0] REG_ACT_MIN      = 12'h013; // 0x04c
    localparam logic [11:0] REG_ACT_MAX      = 12'h014; // 0x050
    localparam logic [11:0] REG_IA_REUSE     = 12'h015; // 0x054
    localparam logic [11:0] REG_W_REUSE      = 12'h016; // 0x058
    localparam logic [11:0] REG_DATAFLOW     = 12'h017; // 0x05c
    localparam logic [11:0] REG_ROW_GROUPS = 12'h018; // 0x060
    localparam logic [11:0] REG_ROW_TAIL_TILES = 12'h019; // 0x064
    localparam logic [11:0] REG_COL_GROUPS = 12'h01a; // 0x068
    localparam logic [11:0] REG_COL_TAIL_TILES = 12'h01b; // 0x06c
    localparam logic [11:0] REG_CONFIG_ABI = 12'h01c; // 0x070, read-only
    localparam logic [11:0] REG_ID           = 12'h03f; // 0x0fc
    localparam logic [REG_WIDTH-1:0] NPU_ID  = 32'h4e50_5531;

    logic [AXIL_ADDR_WIDTH-1:0] awaddr_q;
    logic                       awvalid_q;
    logic [AXIL_DATA_WIDTH-1:0] wdata_q;
    logic [STRB_WIDTH-1:0]      wstrb_q;
    logic                       wvalid_q;
    logic                       bvalid_q;
    logic [AXIL_DATA_WIDTH-1:0] rdata_q;
    logic                       rvalid_q;

    logic [REG_WIDTH-1:0]       last_done_data;
    logic                       irq_enable;
    logic                       done_sticky;
    logic                       npu_busy_q;

    wire aw_accept = s_axil_awvalid && s_axil_awready;
    wire w_accept  = s_axil_wvalid  && s_axil_wready;
    wire ar_accept = s_axil_arvalid && s_axil_arready;

    wire [AXIL_ADDR_WIDTH-1:0] wr_addr = awaddr_q;
    wire [AXIL_DATA_WIDTH-1:0] wr_data = wdata_q;
    wire [STRB_WIDTH-1:0]      wr_strb = wstrb_q;
    wire write_commit = !bvalid_q && awvalid_q && wvalid_q;

    wire [11:0] wr_word_addr = wr_addr[13:2];
    wire [11:0] rd_word_addr = s_axil_araddr[13:2];
    wire ctrl_start_commit = write_commit && (wr_word_addr == REG_CTRL) && wr_strb[0] && wr_data[0];

    logic [AXIL_DATA_WIDTH-1:0] read_data_next;

    assign s_axil_awready = !awvalid_q && !bvalid_q;
    assign s_axil_wready  = !wvalid_q && !bvalid_q;
    assign s_axil_bresp   = 2'b00;
    assign s_axil_bvalid  = bvalid_q;

    assign s_axil_arready = !rvalid_q;
    assign s_axil_rdata   = rdata_q;
    assign s_axil_rresp   = 2'b00;
    assign s_axil_rvalid  = rvalid_q;

    assign npu_done_ready = 1'b1;
    assign npu_busy = npu_busy_q;
    assign irq = done_sticky && irq_enable;
    assign status_bits = {26'b0, 1'b1, npu_err_code,
                          done_sticky, npu_busy_q, npu_sa_ready};

    function automatic [REG_WIDTH-1:0] apply_wstrb(
        input [REG_WIDTH-1:0] old_data,
        input [AXIL_DATA_WIDTH-1:0] new_data,
        input [STRB_WIDTH-1:0] strb
    );
        integer byte_idx;
        begin
            apply_wstrb = old_data;
            for (byte_idx = 0; byte_idx < (REG_WIDTH / 8); byte_idx = byte_idx + 1) begin
                if (strb[byte_idx]) begin
                    apply_wstrb[byte_idx*8 +: 8] = new_data[byte_idx*8 +: 8];
                end
            end
        end
    endfunction

    always_comb begin
        read_data_next = '0;
        case (rd_word_addr)
            REG_CTRL: begin
                read_data_next[5:1] = {cfg_16x8, irq_enable, cfg_dataflow_mode,
                                       use_per_channel, cfg_16bits_ia};
            end
            REG_STATUS:       read_data_next[7:0] = status_bits[7:0];
            REG_WB_DATA:      read_data_next = last_done_data;
            REG_LHS_BASE:     read_data_next = lhs_base;
            REG_RHS_BASE:     read_data_next = rhs_base;
            REG_DST_BASE:     read_data_next = dst_base;
            REG_BIAS_BASE:    read_data_next = bias_base;
            REG_K:            read_data_next = k;
            REG_N:            read_data_next = n;
            REG_M:            read_data_next = m;
            REG_LHS_STRIDE_B: read_data_next = lhs_row_stride_b;
            REG_RHS_STRIDE_B: read_data_next = rhs_col_stride_b;
            REG_DST_STRIDE_B: read_data_next = dst_row_stride_b;
            REG_LHS_ZP:       read_data_next = lhs_zp;
            REG_RHS_ZP:       read_data_next = rhs_zp;
            REG_DST_ZP:       read_data_next = dst_zp;
            REG_Q_MULT:       read_data_next = q_mult_pt;
            REG_Q_SHIFT:      read_data_next = q_shift_pt;
            REG_ACT_MIN:      read_data_next = act_min;
            REG_ACT_MAX:      read_data_next = act_max;
            REG_IA_REUSE:     read_data_next = cfg_ia_reuse_num;
            REG_W_REUSE:      read_data_next = cfg_w_reuse_num;
            REG_DATAFLOW:     read_data_next[0] = cfg_dataflow_mode;
            REG_ROW_GROUPS: read_data_next = cfg_row_groups;
            REG_ROW_TAIL_TILES: read_data_next = cfg_row_tail_tiles;
            REG_COL_GROUPS: read_data_next = cfg_col_groups;
            REG_COL_TAIL_TILES: read_data_next = cfg_col_tail_tiles;
            REG_CONFIG_ABI: read_data_next = 32'd2;
            REG_ID:           read_data_next = NPU_ID;
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awaddr_q            <= '0;
            awvalid_q           <= 1'b0;
            wdata_q             <= '0;
            wstrb_q             <= '0;
            wvalid_q            <= 1'b0;
            bvalid_q            <= 1'b0;
            rdata_q             <= '0;
            rvalid_q            <= 1'b0;
            lhs_base            <= '0;
            rhs_base            <= '0;
            dst_base            <= '0;
            bias_base           <= '0;
            k                   <= '0;
            n                   <= '0;
            m                   <= '0;
            lhs_row_stride_b    <= '0;
            rhs_col_stride_b    <= '0;
            dst_row_stride_b    <= '0;
            lhs_zp              <= '0;
            rhs_zp              <= '0;
            dst_zp              <= '0;
            q_mult_pt           <= '0;
            q_shift_pt          <= '0;
            act_min             <= '0;
            act_max             <= '0;
            cfg_16bits_ia       <= 1'b0;
            cfg_16x8            <= 1'b0;
            cfg_dataflow_mode   <= 1'b0;
            use_per_channel     <= 1'b0;
            irq_enable          <= 1'b0;
            cfg_ia_reuse_num    <= '0;
            cfg_w_reuse_num     <= '0;
            cfg_row_groups <= '0;
            cfg_row_tail_tiles <= '0;
            cfg_col_groups <= '0;
            cfg_col_tail_tiles <= '0;
            calc_start          <= 1'b0;
            npu_busy_q          <= 1'b0;
            done_sticky         <= 1'b0;
            last_done_data      <= '0;
        end else begin
            calc_start <= 1'b0;

            if (s_axil_bready && bvalid_q) begin
                bvalid_q <= 1'b0;
            end

            if (aw_accept) begin
                awaddr_q  <= s_axil_awaddr;
                awvalid_q <= 1'b1;
            end

            if (w_accept) begin
                wdata_q  <= s_axil_wdata;
                wstrb_q  <= s_axil_wstrb;
                wvalid_q <= 1'b1;
            end

            if (write_commit) begin
                awvalid_q <= 1'b0;
                wvalid_q  <= 1'b0;
                bvalid_q  <= 1'b1;

                case (wr_word_addr)
                    REG_CTRL: begin
                        if (wr_strb[0]) begin
                            cfg_16bits_ia     <= wr_data[1];
                            use_per_channel   <= wr_data[2];
                            cfg_dataflow_mode <= wr_data[3];
                            irq_enable        <= wr_data[4];
                            cfg_16x8           <= wr_data[5];
                            if (wr_data[0]) begin
                                calc_start    <= 1'b1;
                                npu_busy_q    <= 1'b1;
                            end
                        end
                    end
                    REG_STATUS: begin
                        if (wr_strb[0]) begin
                            if (wr_data[2]) begin
                                done_sticky <= 1'b0;
                            end
                        end
                    end
                    REG_LHS_BASE:     lhs_base <= apply_wstrb(lhs_base, wr_data, wr_strb);
                    REG_RHS_BASE:     rhs_base <= apply_wstrb(rhs_base, wr_data, wr_strb);
                    REG_DST_BASE:     dst_base <= apply_wstrb(dst_base, wr_data, wr_strb);
                    REG_BIAS_BASE:    bias_base <= apply_wstrb(bias_base, wr_data, wr_strb);
                    REG_K:            k <= apply_wstrb(k, wr_data, wr_strb);
                    REG_N:            n <= apply_wstrb(n, wr_data, wr_strb);
                    REG_M:            m <= apply_wstrb(m, wr_data, wr_strb);
                    REG_LHS_STRIDE_B: lhs_row_stride_b <= apply_wstrb(lhs_row_stride_b, wr_data, wr_strb);
                    REG_RHS_STRIDE_B: rhs_col_stride_b <= apply_wstrb(rhs_col_stride_b, wr_data, wr_strb);
                    REG_DST_STRIDE_B: dst_row_stride_b <= apply_wstrb(dst_row_stride_b, wr_data, wr_strb);
                    REG_LHS_ZP:       lhs_zp <= apply_wstrb(lhs_zp, wr_data, wr_strb);
                    REG_RHS_ZP:       rhs_zp <= apply_wstrb(rhs_zp, wr_data, wr_strb);
                    REG_DST_ZP:       dst_zp <= apply_wstrb(dst_zp, wr_data, wr_strb);
                    REG_Q_MULT:       q_mult_pt <= apply_wstrb(q_mult_pt, wr_data, wr_strb);
                    REG_Q_SHIFT:      q_shift_pt <= apply_wstrb(q_shift_pt, wr_data, wr_strb);
                    REG_ACT_MIN:      act_min <= apply_wstrb(act_min, wr_data, wr_strb);
                    REG_ACT_MAX:      act_max <= apply_wstrb(act_max, wr_data, wr_strb);
                    REG_IA_REUSE:     cfg_ia_reuse_num <= apply_wstrb(cfg_ia_reuse_num, wr_data, wr_strb);
                    REG_W_REUSE:      cfg_w_reuse_num <= apply_wstrb(cfg_w_reuse_num, wr_data, wr_strb);
                    REG_ROW_GROUPS: cfg_row_groups <= apply_wstrb(cfg_row_groups, wr_data, wr_strb);
                    REG_ROW_TAIL_TILES: cfg_row_tail_tiles <= apply_wstrb(cfg_row_tail_tiles, wr_data, wr_strb);
                    REG_COL_GROUPS: cfg_col_groups <= apply_wstrb(cfg_col_groups, wr_data, wr_strb);
                    REG_COL_TAIL_TILES: cfg_col_tail_tiles <= apply_wstrb(cfg_col_tail_tiles, wr_data, wr_strb);
                    REG_DATAFLOW: begin
                        if (wr_strb[0]) begin
                            cfg_dataflow_mode <= wr_data[0];
                        end
                    end
                    default: begin
                    end
                endcase
            end

            if (rvalid_q && s_axil_rready) begin
                rvalid_q <= 1'b0;
            end

            if (ar_accept) begin
                rdata_q  <= read_data_next;
                rvalid_q <= 1'b1;
            end

            if (calc_start) begin
                npu_busy_q <= 1'b1;
            end

            if (npu_done_valid && npu_done_ready && !ctrl_start_commit) begin
                npu_busy_q    <= 1'b0;
                done_sticky   <= 1'b1;
                last_done_data <= {{(REG_WIDTH-2){1'b0}}, npu_err_code};
            end
        end
    end

    wire unused_axil_prot = ^{s_axil_awprot, s_axil_arprot};

endmodule
