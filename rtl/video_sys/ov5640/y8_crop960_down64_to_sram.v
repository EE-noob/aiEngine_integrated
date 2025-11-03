module y8_crop960_down64_nn #(
    // 固定尺寸（可改为参数化，但本题固定如下）
    parameter IN_W  = 1280,
    parameter IN_H  = 960,
    parameter CROP_W = 960,
    parameter CROP_H = 960,
    parameter OUT_W = 64,
    parameter OUT_H = 64,
    // 最近邻缩放（960→64，缩放比=15），选择中心采样偏移=7
    parameter SCALE_X = CROP_W/OUT_W,      // =15
    parameter SCALE_Y = CROP_H/OUT_H,      // =15
    parameter SAMPLE_OFFS_X = (SCALE_X-1)/2, // =7
    parameter SAMPLE_OFFS_Y = (SCALE_Y-1)/2, // =7
    // 输出地址基址（如 SRAM 仅用于本模块可设 0）
    parameter ADDR_BASE = 0,
    // 计算地址位宽：64*64=4096 → 12bit
    parameter ADDR_WIDTH = 12
) (
    input  wire                 clk,
    input  wire                 rst_n,

    // 流式像素输入（Y8）
    input  wire                 in_valid,  // 像素有效，每拍一个像素
    input  wire                 in_sof,    // 帧首像素脉冲（和 in_valid 同拍）
    input  wire [7:0]           in_y,      // Y8 像素

    // 单端口 SRAM 写接口（同步写）
    output reg [ADDR_WIDTH-1:0] sram_addr,
    output reg [7:0]            sram_wdata,
    output reg                  sram_we,     // 写使能（命中采样时拉高 1 拍）

    // 可选：本帧 4096 次写已完成的脉冲
    output reg                  frame_done
);
    // ====== 静态检查 ======
    // synopsys translate_off
    initial begin
        if (CROP_W != 960 || CROP_H != 960 || IN_W != 1280 || IN_H != 960) begin
            $display("[%m] INFO: parameters changed from default 1280x960 -> crop 960x960.");
        end
        if ((CROP_W % OUT_W) != 0 || (CROP_H % OUT_H) != 0) begin
            $display("[%m] CROP/OUT must be integer scale.");
        end
        if ((SCALE_X % 2) == 0 || (SCALE_Y % 2) == 0) begin
            $display("[%m] SCALE must be odd for center sampling.");
        end
    end
    // synopsys translate_on

    // ====== 常量与寄存器 ======
    localparam LEFT_TRIM = (IN_W - CROP_W)/2; // =160
    localparam RIGHT_EDGE = LEFT_TRIM + CROP_W; // 160..1119 有效（<1120）
    localparam OUT_PIXELS = OUT_W * OUT_H;   // =4096

    // 行列计数（输入分辨率）
    reg [$clog2(IN_W )-1:0] col;
    reg [$clog2(IN_H )-1:0] row;

    // 行/列内 mod-15 计数，分别在“进入裁剪窗口的第一个像素”和“新行开始”时归零或自增
    reg [$clog2(SCALE_X)-1:0] col_mod; // 0..14
    reg [$clog2(SCALE_Y)-1:0] row_mod; // 0..14

    // 写地址与结束检测
    reg [ADDR_WIDTH-1:0] wr_addr;

    // 组合命中判断（基于“当前像素”的行/列状态）
    wire within_crop = (col >= LEFT_TRIM) && (col < RIGHT_EDGE); // 是否在 960 宽裁剪窗
    wire hit_row = (row_mod == SAMPLE_OFFS_Y);
    wire hit_col = within_crop && (col_mod == SAMPLE_OFFS_X);
    wire sample_hit = in_valid && hit_row && hit_col; // 只有命中才写 SRAM

    // ====== 时序逻辑 ======
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col        <= 0;
            row        <= 0;
            col_mod    <= 0;
            row_mod    <= 0;
            wr_addr    <= ADDR_BASE;
            sram_we    <= 1'b0;
            sram_wdata <= 8'h00;
            sram_addr  <= ADDR_BASE;
            frame_done <= 1'b0;
        end else begin
            // 默认不写
            sram_we    <= 1'b0;
            frame_done <= 1'b0;

            // 帧首对齐：清零计数/地址
            if (in_sof) begin
                col     <= 0;
                row     <= 0;
                col_mod <= 0;
                row_mod <= 0;
                wr_addr <= ADDR_BASE;
                sram_addr <= ADDR_BASE;
            end

            // 写操作：仅在命中采样点时发生
            if (sample_hit) begin
                sram_we    <= 1'b1;
                sram_wdata <= in_y;
                sram_addr  <= wr_addr;
                // 地址自增（线性 0..4095）
                // Cast constant expression to unsigned to avoid VER-318 in DC
                if (wr_addr == $unsigned(ADDR_BASE + OUT_PIXELS - 1)) begin
                    wr_addr    <= ADDR_BASE;
                    frame_done <= 1'b1;
                end else begin
                    wr_addr    <= wr_addr + 1'b1;
                end
            end

            // 行列与 mod-15 的推进（仅在输入有效时推进）
            if (in_valid) begin
                // 列内 mod-15：在每行的 col==LEFT_TRIM 处置零，其后窗口内每拍自增（0..14 循环）
                if (col == $unsigned(LEFT_TRIM)) begin
                    col_mod <= 0;
                end else if (within_crop) begin
                    if (col_mod == $unsigned(SCALE_X-1))
                        col_mod <= 0;
                    else
                        col_mod <= col_mod + 1'b1;
                end
                // 列计数推进
                if (col == $unsigned(IN_W - 1)) begin
                    col <= 0;
                    // 行末推进 row 与 row_mod
                    if (row == $unsigned(IN_H - 1)) begin
                        row    <= 0;
                    end else begin
                        row    <= row + 1'b1;
                    end
                    if (row_mod == $unsigned(SCALE_Y-1))
                        row_mod <= 0;
                    else
                        row_mod <= row_mod + 1'b1;
                end else begin
                    col <= col + 1'b1;
                end
            end
        end
    end

endmodule
