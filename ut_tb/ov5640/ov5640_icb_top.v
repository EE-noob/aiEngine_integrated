module ov5640_icb_top #(
    parameter ADDR_WIDTH = 12,
    parameter IMAGE_SIZE = 1 << ADDR_WIDTH,
    parameter WAIT_FRAME = 4'd10
)(
    // ICB 时钟域
    input  wire             icb_clk,
    input  wire             icb_rst_n,
    
    // 摄像头时钟域
    input  wire             cam_pclk,
    input  wire             cam_rst_n,
    
    // ICB 接口
    input  wire             dcmi_icb_cmd_valid,
    output wire             dcmi_icb_cmd_ready,
    input  wire [31:0]      dcmi_icb_cmd_addr,
    input  wire             dcmi_icb_cmd_read,
    input  wire [31:0]      dcmi_icb_cmd_wdata,
    input  wire [3:0]       dcmi_icb_cmd_wmask,
    output wire             dcmi_icb_rsp_valid,
    input  wire             dcmi_icb_rsp_ready,
    output wire [31:0]      dcmi_icb_rsp_rdata,
    
    // 摄像头接口
    input  wire             cam_vsync,
    input  wire             cam_href,
    input  wire [7:0]       cam_data
);

    // =========================================
    // 内部信号定义
    // =========================================
    
    // 控制信号（跨时钟域同步）
    wire start_capture_icb;
    wire start_capture_cam;
    wire frame_done_cam;
    wire frame_done_icb;
    
    // SRAM 写端口（来自 ov5640_y8_top，在 cam_pclk 域）
    wire [ADDR_WIDTH-1:0] sram_wr_addr_cam;
    wire [7:0]            sram_wr_data_cam;
    wire                  sram_wr_en_cam;
    
    // SRAM 写端口（同步到 icb_clk 域后）
    wire [ADDR_WIDTH-1:0] sram_wr_addr_icb;
    wire [7:0]            sram_wr_data_icb;
    wire                  sram_wr_en_icb;
    
    // SRAM 读端口（来自 icb2dcmi，在 icb_clk 域）
    wire [ADDR_WIDTH-1:0] icb_rd_addr;
    wire                  icb_rd_en;
    wire [7:0]            sram_rd_data_out;
    
    // SRAM 仲裁后的实际控制信号（icb_clk 域）
    reg  [ADDR_WIDTH-1:0] sram_addr;
    reg  [7:0]            sram_wdata;
    reg                   sram_we;

    wire [7:0]  sram_rdata;
    wire [11:0] sram_rd_addr;
    wire        sram_rd_en;

    // =========================================
    // 跨时钟域同步：start_capture (icb_clk -> cam_pclk)
    // 使用电平同步 + 握手协议，避免快到慢时钟域的脉冲丢失
    // =========================================
    
    // ICB时钟域：将脉冲转换为电平
    reg start_req_icb;
    reg start_ack_sync_ff1, start_ack_sync_ff2;
    
    always @(posedge icb_clk or negedge icb_rst_n) begin
        if (!icb_rst_n) begin
            start_req_icb <= 1'b0;
            start_ack_sync_ff1 <= 1'b0;
            start_ack_sync_ff2 <= 1'b0;
        end else begin
            // 同步ack信号回来
            start_ack_sync_ff1 <= start_ack_cam;
            start_ack_sync_ff2 <= start_ack_sync_ff1;
            
            // 收到start_capture脉冲时拉高req
            if (start_capture_icb) begin
                start_req_icb <= 1'b1;
            end
            // 收到ack后清除req
            else if (start_ack_sync_ff2) begin
                start_req_icb <= 1'b0;
            end
        end
    end
    
    // CAM时钟域：同步req信号并产生脉冲
    reg start_req_sync_ff1, start_req_sync_ff2, start_req_sync_ff3;
    reg start_ack_cam;
    
    always @(posedge cam_pclk or negedge cam_rst_n) begin
        if (!cam_rst_n) begin
            start_req_sync_ff1 <= 1'b0;
            start_req_sync_ff2 <= 1'b0;
            start_req_sync_ff3 <= 1'b0;
            start_ack_cam <= 1'b0;
        end else begin
            // 三级同步器同步req信号
            start_req_sync_ff1 <= start_req_icb;
            start_req_sync_ff2 <= start_req_sync_ff1;
            start_req_sync_ff3 <= start_req_sync_ff2;
            
            // 检测到req上升沿时发送ack
            if (start_req_sync_ff2 && !start_req_sync_ff3) begin
                start_ack_cam <= 1'b1;
            end
            // req下降后清除ack
            else if (!start_req_sync_ff2) begin
                start_ack_cam <= 1'b0;
            end
        end
    end
    
    // 产生单周期脉冲给下游模块
    assign start_capture_cam = start_req_sync_ff2 & ~start_req_sync_ff3;
    
    // =========================================
    // 跨时钟域同步：frame_done (cam_pclk -> icb_clk)
    // =========================================
    reg frame_done_sync_ff1, frame_done_sync_ff2, frame_done_sync_ff3;
    
    always @(posedge icb_clk or negedge icb_rst_n) begin
        if (!icb_rst_n) begin
            frame_done_sync_ff1 <= 1'b0;
            frame_done_sync_ff2 <= 1'b0;
            frame_done_sync_ff3 <= 1'b0;
        end else begin
            frame_done_sync_ff1 <= frame_done_cam;
            frame_done_sync_ff2 <= frame_done_sync_ff1;
            frame_done_sync_ff3 <= frame_done_sync_ff2;
        end
    end
    
    assign frame_done_icb = frame_done_sync_ff2 & ~frame_done_sync_ff3;
    
    // =========================================
    // 跨时钟域同步：写请求 (cam_pclk -> icb_clk)
    // 使用三级同步器 + 边沿检测，防止慢到快时钟域的多拍问题
    // =========================================
    reg sram_wr_en_sync_ff1, sram_wr_en_sync_ff2, sram_wr_en_sync_ff3;
    reg [ADDR_WIDTH-1:0] sram_wr_addr_sync_ff1, sram_wr_addr_sync_ff2;
    reg [7:0] sram_wr_data_sync_ff1, sram_wr_data_sync_ff2;
    
    always @(posedge icb_clk or negedge icb_rst_n) begin
        if (!icb_rst_n) begin
            sram_wr_en_sync_ff1   <= 1'b0;
            sram_wr_en_sync_ff2   <= 1'b0;
            sram_wr_en_sync_ff3   <= 1'b0;
            sram_wr_addr_sync_ff1 <= {ADDR_WIDTH{1'b0}};
            sram_wr_addr_sync_ff2 <= {ADDR_WIDTH{1'b0}};
            sram_wr_data_sync_ff1 <= 8'h00;
            sram_wr_data_sync_ff2 <= 8'h00;
        end else begin
            // 三级同步器同步使能信号
            sram_wr_en_sync_ff1   <= sram_wr_en_cam;
            sram_wr_en_sync_ff2   <= sram_wr_en_sync_ff1;
            sram_wr_en_sync_ff3   <= sram_wr_en_sync_ff2;
            
            // 数据和地址只需两级同步（配合使能的边沿检测）
            sram_wr_addr_sync_ff1 <= sram_wr_addr_cam;
            sram_wr_addr_sync_ff2 <= sram_wr_addr_sync_ff1;
            sram_wr_data_sync_ff1 <= sram_wr_data_cam;
            sram_wr_data_sync_ff2 <= sram_wr_data_sync_ff1;
        end
    end
    
    // 边沿检测：只在上升沿时产生单周期脉冲
    assign sram_wr_en_icb   = sram_wr_en_sync_ff2 & ~sram_wr_en_sync_ff3;
    assign sram_wr_addr_icb = sram_wr_addr_sync_ff2;
    assign sram_wr_data_icb = sram_wr_data_sync_ff2;
    
    // =========================================
    // SRAM 仲裁状态机（icb_clk 域）
    // =========================================
    localparam IDLE  = 2'b00;
    localparam WRITE = 2'b01;
    localparam READ  = 2'b10;
    
    reg [1:0] state;
    reg writing;  // 标记正在写入过程中
    reg frame_done_flag;  // 锁存 frame_done_icb，避免重复触发
    
    always @(posedge icb_clk or negedge icb_rst_n) begin
        if (!icb_rst_n) begin
            state <= IDLE;
            writing <= 1'b0;
            frame_done_flag <= 1'b0;
        end else begin
            // 锁存 frame_done_icb，直到写操作完全结束
            if (frame_done_icb) begin
                frame_done_flag <= 1'b1;
            end
            
            // 检测写开始（排除已经完成的情况）
            if (sram_wr_en_icb && !writing && !frame_done_flag) begin
                writing <= 1'b1;
            end
            
            // 检测写结束：frame_done 且没有新的写请求
            if (frame_done_flag && !sram_wr_en_icb) begin
                writing <= 1'b0;
                frame_done_flag <= 1'b0;  // 清除标志，允许下一帧
            end
            
            case (state)
                IDLE: begin
                    if (sram_wr_en_icb && !frame_done_flag) begin
                        state <= WRITE;
                    end else if (icb_rd_en && !writing) begin
                        state <= READ;
                    end
                end
                
                WRITE: begin
                    // 写优先，直到 frame_done 且写使能清零
                    if (frame_done_flag && !sram_wr_en_icb) begin
                        state <= IDLE;
                    end
                end
                
                READ: begin
                    // 读操作完成后立即返回 IDLE
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // =========================================
    // SRAM 控制逻辑（时序逻辑，锁存地址和控制信号）
    // =========================================
    always @(posedge icb_clk or negedge icb_rst_n) begin
        if (!icb_rst_n) begin
            sram_addr  <= {ADDR_WIDTH{1'b0}};
            sram_wdata <= 8'h00;
            sram_we    <= 1'b0;
        end else begin
            // 默认不写
            sram_we <= 1'b0;
            
            if (sram_wr_en_icb) begin
                // 写优先
                sram_addr  <= sram_wr_addr_icb;
                sram_wdata <= sram_wr_data_icb;
                sram_we    <= 1'b1;
            end else if (icb_rd_en && !writing) begin
                // 读操作（只在非写入期间）
                sram_addr  <= icb_rd_addr;
                sram_wdata <= 8'h00;
                sram_we    <= 1'b0;
            end else begin
                // 保持当前地址（避免不必要的变化）
                sram_addr  <= sram_addr;
                sram_wdata <= 8'h00;
                sram_we    <= 1'b0;
            end
        end
    end
    
    // =========================================
    // SRAM例化（8位宽，12位地址，单端口）
    // =========================================
    sram #(
        .DP(4096),
        .DW(8),
        .MW(1),
        .AW(12)
    ) u_sram (
        .clk   (icb_clk),
        .din   (sram_wdata),
        .addr  (sram_addr),
        .cs    (1'b1),
        .we    (sram_we),
        .wem   (1'b1),
        .dout  (sram_rdata)
    );

    assign sram_rd_data_out = sram_rdata;
    
    // =========================================
    // 实例化 icb2dcmi 模块
    // =========================================
    icb2dcmi #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .IMAGE_SIZE(IMAGE_SIZE)
    ) u_icb2dcmi (
        .clk              (icb_clk),
        .rst_n            (icb_rst_n),
        .dcmi_icb_cmd_valid (dcmi_icb_cmd_valid),
        .dcmi_icb_cmd_ready (dcmi_icb_cmd_ready),
        .dcmi_icb_cmd_addr  (dcmi_icb_cmd_addr),
        .dcmi_icb_cmd_read  (dcmi_icb_cmd_read),
        .dcmi_icb_cmd_wdata (dcmi_icb_cmd_wdata),
        .dcmi_icb_cmd_wmask (dcmi_icb_cmd_wmask),
        .dcmi_icb_rsp_valid (dcmi_icb_rsp_valid),
        .dcmi_icb_rsp_ready (dcmi_icb_rsp_ready),
        .dcmi_icb_rsp_rdata (dcmi_icb_rsp_rdata),
        .start_capture      (start_capture_icb),
        .frame_done_i       (frame_done_icb),
        .sram_rd_addr       (icb_rd_addr),
        .sram_rd_en         (icb_rd_en),
        .sram_rd_data       (sram_rd_data_out)
    );
    
    // =========================================
    // 实例化 ov5640_y8_top 模块
    // =========================================
    ov5640_y8_top #(
        .WAIT_FRAME(WAIT_FRAME)
    ) u_ov5640_y8_top (
        .rst_n          (cam_rst_n),
        .cam_pclk       (cam_pclk),
        .cam_vsync      (cam_vsync),
        .cam_href       (cam_href),
        .cam_data       (cam_data),
        .start_capture  (start_capture_cam),
        .sram_addr      (sram_wr_addr_cam),
        .sram_wdata     (sram_wr_data_cam),
        .sram_we        (sram_wr_en_cam),
        .frame_done     (frame_done_cam)
    );

endmodule
