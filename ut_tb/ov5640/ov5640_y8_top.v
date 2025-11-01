`include "ov5640_dcmi_y8_if.v"
`include "y8_crop960_down64_to_sram.v"

module ov5640_y8_top #(
    parameter WAIT_FRAME = 4'd10
) (
    input  wire        rst_n,
    input  wire        cam_pclk,
    input  wire        cam_vsync,
    input  wire        cam_href,
    input  wire [7:0]  cam_data,
    input  wire        start_capture,
    // SRAM接口
    output wire [11:0] sram_addr,
    output wire [7:0]  sram_wdata,
    output wire        sram_we,
    output wire        frame_done
);
    // 直通信号
    reg  start_sync_ff1;
    reg  start_sync_ff2;
    reg  capture_en;
    wire start_capture_cam;

    assign start_capture_cam = start_sync_ff1 & ~start_sync_ff2;

    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            start_sync_ff1 <= 1'b0;
            start_sync_ff2 <= 1'b0;
        end else begin
            start_sync_ff1 <= start_capture;
            start_sync_ff2 <= start_sync_ff1;
        end
    end

    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n)
            capture_en <= 1'b0;
        else if (start_capture_cam)
            capture_en <= 1'b1;
        else if (frame_done)
            capture_en <= 1'b0;
    end

    wire in_valid;
    wire in_sof;
    wire [7:0] in_y;

    ov5640_dcmi_y8_if #(
        .WAIT_FRAME(WAIT_FRAME)
    ) u_dcmi_y8_if (
        .rst_n     (rst_n),
        .cam_pclk  (cam_pclk),
        .cam_vsync (cam_vsync),
        .cam_href  (cam_href),
        .cam_data  (cam_data),
        .capture_en(capture_en),
        .in_valid  (in_valid),
        .in_sof    (in_sof),
        .in_y      (in_y)
    );

    y8_crop960_down64_nn u_y8_crop960_down64_nn (
        .clk        (cam_pclk),
        .rst_n      (rst_n),
        .in_valid   (in_valid),
        .in_sof     (in_sof),
        .in_y       (in_y),
        .sram_addr  (sram_addr),
        .sram_wdata (sram_wdata),
        .sram_we    (sram_we),
        .frame_done (frame_done)
    );

endmodule
