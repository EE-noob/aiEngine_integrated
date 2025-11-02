module ov5640_dcmi_y8_if #(
    parameter WAIT_FRAME = 4'd10
)(
    input  wire        rst_n,
    input  wire        cam_pclk,
    input  wire        cam_vsync,
    input  wire        cam_href,
    input  wire [7:0]  cam_data,
    input  wire        capture_en,
    output reg         in_valid,
    output reg         in_sof,
    output reg [7:0]   in_y
);
    reg cam_vsync_d0, cam_vsync_d1, cam_vsync_d2;
    reg frame_active;
    reg first_pixel_flag;

    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            cam_vsync_d0 <= 1'b0;
            cam_vsync_d1 <= 1'b0;
            cam_vsync_d2 <= 1'b0;
        end else begin
            cam_vsync_d0 <= cam_vsync;
            cam_vsync_d1 <= cam_vsync_d0;
            cam_vsync_d2 <= cam_vsync_d1;
        end
    end

    wire frame_start = (cam_vsync_d2 == 1'b1) && (cam_vsync_d1 == 1'b0);

    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n)
            frame_active <= 1'b0;
        else if (!capture_en)
            frame_active <= 1'b0;
        else if (frame_start)
            frame_active <= 1'b1;
    end

    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n)
            first_pixel_flag <= 1'b0;
        else if (!capture_en)
            first_pixel_flag <= 1'b0;
        else if (frame_start)
            first_pixel_flag <= 1'b1;
        else if (first_pixel_flag && frame_active && cam_href)
            first_pixel_flag <= 1'b0;
    end

    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n)
            in_sof <= 1'b0;
        else if (!frame_active)
            in_sof <= 1'b0;
        else if (first_pixel_flag && cam_href)
            in_sof <= 1'b1;
        else
            in_sof <= 1'b0;
    end

    // 输出信号
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            in_valid <= 1'b0;
            in_y     <= 8'd0;
        end else begin
            in_valid <= frame_active ? cam_href : 1'b0;
            in_y     <= cam_data;
        end
    end
endmodule