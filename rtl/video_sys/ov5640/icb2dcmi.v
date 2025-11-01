module icb2dcmi #(
    parameter ADDR_WIDTH = 12,
    parameter IMAGE_SIZE = 1 << ADDR_WIDTH
)(
    input  wire             clk,
    input  wire             rst_n,

    // ICB 接口
    input  wire             dcmi_icb_cmd_valid,
    output reg              dcmi_icb_cmd_ready,
    input  wire [31:0]      dcmi_icb_cmd_addr,
    input  wire             dcmi_icb_cmd_read,
    input  wire [31:0]      dcmi_icb_cmd_wdata,
    input  wire [3:0]       dcmi_icb_cmd_wmask,
    output reg              dcmi_icb_rsp_valid,
    input  wire             dcmi_icb_rsp_ready,
    output reg  [31:0]      dcmi_icb_rsp_rdata,

    // 与顶层交互
    output reg              start_capture,
    input  wire             frame_done_i,

    // SRAM 读端口（同时钟域）
    output reg  [ADDR_WIDTH-1:0] sram_rd_addr,
    output reg              sram_rd_en,
    input  wire [7:0]       sram_rd_data
);

    // 寄存器地址偏移（字对齐）
    localparam CTRL_ADDR   = 2'b00;
    localparam STATUS_ADDR = 2'b01;
    localparam DATA_ADDR   = 2'b10;

    // 状态寄存器
    reg busy;
    reg done_latched;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg sram_rd_en_d1, sram_rd_en_d2;
    
    // 读数据流水线（2周期：发起读 + 等待SRAM）
    reg rd_pending;

    wire bus_fire = dcmi_icb_cmd_valid && dcmi_icb_cmd_ready;
    wire [1:0] addr_sel = dcmi_icb_cmd_addr[3:2];

    // =========================================
    // 命令通道握手控制
    // =========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dcmi_icb_cmd_ready <= 1'b1;
        end else begin
            // 读 DATA 时，在等待期间阻塞新命令
            if (rd_pending) begin
                dcmi_icb_cmd_ready <= 1'b0;
            end else if (dcmi_icb_rsp_valid && !dcmi_icb_rsp_ready) begin
                dcmi_icb_cmd_ready <= 1'b0;
            end else begin
                dcmi_icb_cmd_ready <= 1'b1;
            end
        end
    end

    // =========================================
    // 控制寄存器逻辑
    // =========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_capture <= 1'b0;
            busy          <= 1'b0;
            done_latched  <= 1'b0;
            rd_ptr        <= {ADDR_WIDTH{1'b0}};
        end else begin
            start_capture <= 1'b0;

            // 写 CTRL 寄存器触发采集
            if (bus_fire && !dcmi_icb_cmd_read && addr_sel == CTRL_ADDR && 
                dcmi_icb_cmd_wmask[0] && dcmi_icb_cmd_wdata[0]) begin
                start_capture <= 1'b1;
                busy          <= 1'b1;
                done_latched  <= 1'b0;
                rd_ptr        <= {ADDR_WIDTH{1'b0}};
            end

            // 接收 frame_done 脉冲
            if (frame_done_i) begin
                busy         <= 1'b0;
                done_latched <= 1'b1;
            end

            // 写 STATUS 寄存器清除完成标志
            if (bus_fire && !dcmi_icb_cmd_read && addr_sel == STATUS_ADDR && 
                dcmi_icb_cmd_wmask[0] && dcmi_icb_cmd_wdata[0]) begin
                done_latched <= 1'b0;
            end

            // 读 DATA 完成后才递增指针
            if (rd_pending && !dcmi_icb_cmd_ready) begin
                // 等到响应握手完成
                if (dcmi_icb_rsp_valid && dcmi_icb_rsp_ready) begin
                    if (rd_ptr == IMAGE_SIZE-1)
                        rd_ptr <= {ADDR_WIDTH{1'b0}};
                    else
                        rd_ptr <= rd_ptr + 1'b1;
                end
            end
        end
    end

    // =========================================
    // SRAM 读流水线（2周期：请求 + 等待）
    // =========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_pending   <= 1'b0;
            sram_rd_en   <= 1'b0;
            sram_rd_addr <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (!rd_pending) begin
                sram_rd_en <= 1'b0;
                // 发起读请求
                if (bus_fire && dcmi_icb_cmd_read && addr_sel == DATA_ADDR) begin
                    sram_rd_en   <= 1'b1;
                    sram_rd_addr <= rd_ptr;
                    rd_pending   <= 1'b1;
                end
            end else begin
                // 等待 SRAM 读数据（同时钟域，下一个周期就有效）
                sram_rd_en <= 1'b0;
                // 等待响应握手
                if (dcmi_icb_rsp_valid && dcmi_icb_rsp_ready) begin
                    rd_pending <= 1'b0;
                end
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_rd_en_d1 <= 1'b0;
            sram_rd_en_d2 <= 1'b0;
        end else begin
            sram_rd_en_d1 <= sram_rd_en;
            sram_rd_en_d2 <= sram_rd_en_d1;
        end
    end

    // =========================================
    // ICB 响应通道
    // =========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dcmi_icb_rsp_valid <= 1'b0;
            dcmi_icb_rsp_rdata <= 32'h0;
        end else begin
            // 响应握手完成后清除 valid
            if (dcmi_icb_rsp_valid && dcmi_icb_rsp_ready) begin
                dcmi_icb_rsp_valid <= 1'b0;
                dcmi_icb_rsp_rdata <= 32'h0;
            end 
            // 读寄存器立即响应（非 DATA）
            else if (bus_fire && dcmi_icb_cmd_read && addr_sel != DATA_ADDR) begin
                dcmi_icb_rsp_valid <= 1'b1;
                case (addr_sel)
                    CTRL_ADDR:   dcmi_icb_rsp_rdata <= {30'b0, busy, 1'b0};
                    STATUS_ADDR: dcmi_icb_rsp_rdata <= {31'b0, done_latched};
                    default:     dcmi_icb_rsp_rdata <= 32'h0;
                endcase
            end 
            // 写操作立即响应
            else if (bus_fire && !dcmi_icb_cmd_read) begin
                dcmi_icb_rsp_valid <= 1'b1;
                dcmi_icb_rsp_rdata <= 32'h0;
            end
            // 读 DATA 在读完成后响应
            else if (rd_pending && sram_rd_en_d2 && !dcmi_icb_rsp_valid) begin
                dcmi_icb_rsp_valid <= 1'b1;
                dcmi_icb_rsp_rdata <= {24'h0, sram_rd_data};
            end
        end
    end

endmodule