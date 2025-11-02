`include "ov5640_icb_top.v"


module tb_ov5640_icb_top;
    // =========================================
    // 参数定义
    // =========================================
    parameter IN_W = 1280;
    parameter IN_H = 960;
    parameter OUT_W = 64;
    parameter OUT_H = 64;
    parameter OUT_PIXELS = 4096;  // OUT_W * OUT_H
    
    parameter ICB_CLK_PERIOD = 10;  // 100MHz ICB 时钟
    parameter CAM_CLK_PERIOD = 20;  // 50MHz 摄像头时钟
    
    // ICB 寄存器地址
    parameter ADDR_CTRL   = 32'h0000_0000;
    parameter ADDR_STATUS = 32'h0000_0004;
    parameter ADDR_DATA   = 32'h0000_0008;
    
    // =========================================
    // 信号定义
    // =========================================
    // 时钟和复位
    reg icb_clk, icb_rst_n;
    reg cam_pclk, cam_rst_n;
    
    // ICB 接口
    reg         dcmi_icb_cmd_valid;
    wire        dcmi_icb_cmd_ready;
    reg  [31:0] dcmi_icb_cmd_addr;
    reg         dcmi_icb_cmd_read;
    reg  [31:0] dcmi_icb_cmd_wdata;
    reg  [3:0]  dcmi_icb_cmd_wmask;
    wire        dcmi_icb_rsp_valid;
    reg         dcmi_icb_rsp_ready;
    wire [31:0] dcmi_icb_rsp_rdata;
    
    // 摄像头接口
    reg        cam_vsync;
    reg        cam_href;
    reg [7:0]  cam_data;
    
    // =========================================
    // DUT 实例化
    // =========================================
    ov5640_icb_top #(
        .ADDR_WIDTH(12),
        .IMAGE_SIZE(4096),
        .WAIT_FRAME(4'd2)
    ) dut (
        .icb_clk            (icb_clk),
        .icb_rst_n          (icb_rst_n),
        .cam_pclk           (cam_pclk),
        .cam_rst_n          (cam_rst_n),
        .dcmi_icb_cmd_valid (dcmi_icb_cmd_valid),
        .dcmi_icb_cmd_ready (dcmi_icb_cmd_ready),
        .dcmi_icb_cmd_addr  (dcmi_icb_cmd_addr),
        .dcmi_icb_cmd_read  (dcmi_icb_cmd_read),
        .dcmi_icb_cmd_wdata (dcmi_icb_cmd_wdata),
        .dcmi_icb_cmd_wmask (dcmi_icb_cmd_wmask),
        .dcmi_icb_rsp_valid (dcmi_icb_rsp_valid),
        .dcmi_icb_rsp_ready (dcmi_icb_rsp_ready),
        .dcmi_icb_rsp_rdata (dcmi_icb_rsp_rdata),
        .cam_vsync          (cam_vsync),
        .cam_href           (cam_href),
        .cam_data           (cam_data)
    );
    
    // =========================================
    // 时钟生成
    // =========================================
    initial icb_clk = 0;
    always #(ICB_CLK_PERIOD/2) icb_clk = ~icb_clk;
    
    initial cam_pclk = 0;
    always #(CAM_CLK_PERIOD/2) cam_pclk = ~cam_pclk;
    
    // =========================================
    // 复位生成
    // =========================================
    initial begin
        icb_rst_n = 0;
        cam_rst_n = 0;
        #100;
        icb_rst_n = 1;
        cam_rst_n = 1;
    end
    
    // =========================================
    // 测试数据：输入图像
    // =========================================
    reg [7:0] img_mem [0:1228799];  // IN_W*IN_H-1 = 1280*960-1
    integer load_status;
    
    initial begin
        load_status = $fopen("in_image.mem", "r");
        if (load_status == 0) begin
            $display("[%0t] ERROR: Cannot open in_image.mem", $time);
            $finish;
        end else begin
            $display("[%0t] Loading in_image.mem...", $time);
            $readmemh("in_image.mem", img_mem);
            $fclose(load_status);
            $display("[%0t] Loaded %0d pixels from in_image.mem", $time, IN_W*IN_H);
        end
    end
    
    // =========================================
    // ICB 总线操作任务
    // =========================================
    
    // ICB 写操作
    task icb_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  wmask;
        begin
            @(posedge icb_clk);
            dcmi_icb_cmd_valid = 1'b1;
            dcmi_icb_cmd_read  = 1'b0;
            dcmi_icb_cmd_addr  = addr;
            dcmi_icb_cmd_wdata = data;
            dcmi_icb_cmd_wmask = wmask;
            dcmi_icb_rsp_ready = 1'b1;
            
            // 等待命令握手
            while (!dcmi_icb_cmd_ready) @(posedge icb_clk);
            @(posedge icb_clk);
            dcmi_icb_cmd_valid = 1'b0;
            
            // 等待响应握手
            while (!dcmi_icb_rsp_valid) @(posedge icb_clk);
            @(posedge icb_clk);
            dcmi_icb_rsp_ready = 1'b0;
            
            $display("[%0t] ICB Write: addr=0x%08x, data=0x%08x", $time, addr, data);
        end
    endtask
    
    // ICB 读操作
    task icb_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge icb_clk);
            dcmi_icb_cmd_valid = 1'b1;
            dcmi_icb_cmd_read  = 1'b1;
            dcmi_icb_cmd_addr  = addr;
            dcmi_icb_rsp_ready = 1'b1;
            
            // 等待命令握手
            while (!dcmi_icb_cmd_ready) @(posedge icb_clk);
            @(posedge icb_clk);
            dcmi_icb_cmd_valid = 1'b0;
            
            // 等待响应握手
            while (!dcmi_icb_rsp_valid) @(posedge icb_clk);
            data = dcmi_icb_rsp_rdata;
            @(posedge icb_clk);
            dcmi_icb_rsp_ready = 1'b0;
            
             //$display("[%0t] ICB Read: addr=0x%08x, data=0x%08x", $time, addr, data);
        end
    endtask
    
    // 轮询状态寄存器等待完成
    task wait_frame_done;
        reg [31:0] status;
        integer poll_count;
        begin
            $display("[%0t] Polling STATUS register...", $time);
            status = 32'h0;
            poll_count = 0;
            while (status[0] == 1'b0) begin
                repeat(100) @(posedge icb_clk);
                icb_read(ADDR_STATUS, status);
                poll_count = poll_count + 1;
                if (poll_count % 10 == 0) begin
                    //$display("[%0t]   Polling... status=0x%08x", $time, status);
                end
            end
            $display("[%0t] Frame capture done! status=0x%08x", $time, status);
        end
    endtask
    
    // =========================================
    // 摄像头数据发送任务
    // =========================================
    task send_camera_frame;
        integer row, col, pix_ptr;
        begin
            $display("[%0t] Sending camera frame...", $time);
            
            // 帧间隔（VSYNC 高）
            cam_vsync = 1;
            cam_href  = 0;
            cam_data  = 0;
            repeat(20) @(negedge cam_pclk);
            cam_vsync = 0;
            
            // 发送一帧数据
            pix_ptr = 0;
            for (row = 0; row < IN_H; row = row + 1) begin
                // 行有效
                cam_href = 1;
                for (col = 0; col < IN_W; col = col + 1) begin
                    cam_data = img_mem[pix_ptr];
                    pix_ptr = pix_ptr + 1;
                    @(negedge cam_pclk);
                end
                // 行间隔
                cam_href = 0;
                cam_data = 0;
                @(negedge cam_pclk);
            end
            
            // 帧结束（VSYNC 高）
            cam_vsync = 1;
            repeat(20) @(negedge cam_pclk);
            cam_vsync = 0;
            
            $display("[%0t] Camera frame sent (%0d pixels)", $time, IN_W*IN_H);
        end
    endtask
    
    // =========================================
    // 主测试流程
    // =========================================
    reg [31:0] read_data;
    reg [7:0]  captured_image [0:4095];  // OUT_PIXELS-1
    integer i, out_file;
    integer cam_done;
    
    initial begin
        // 初始化信号
        dcmi_icb_cmd_valid = 0;
        dcmi_icb_cmd_read  = 0;
        dcmi_icb_cmd_addr  = 0;
        dcmi_icb_cmd_wdata = 0;
        dcmi_icb_cmd_wmask = 0;
        dcmi_icb_rsp_ready = 0;
        
        cam_vsync = 0;
        cam_href  = 0;
        cam_data  = 0;
        cam_done  = 0;
        
        // 等待复位释放
        while (!icb_rst_n || !cam_rst_n) @(posedge icb_clk);
        repeat(10) @(posedge icb_clk);
        
        $display("\n========================================");
        $display("  Test: OV5640 ICB Top");
        $display("========================================\n");
        
        // =====================================
        // 步骤 1: CPU 发送启动采集命令
        // =====================================
        $display("[%0t] Step 1: CPU triggers capture", $time);
        icb_write(ADDR_CTRL, 32'h0000_0001, 4'hF);
        
        repeat(10) @(posedge icb_clk);
        
        // =====================================
        // 步骤 2: 并行发送摄像头数据
        // =====================================
        $display("[%0t] Step 2: Camera will send data in parallel", $time);
        
        // =====================================
        // 步骤 3: CPU 轮询等待采集完成
        // =====================================
        $display("[%0t] Step 3: Waiting for frame done", $time);
        wait_frame_done();
        
        // 等待一些时钟周期确保数据稳定
        repeat(50) @(posedge icb_clk);
        
        // =====================================
        // 步骤 3.5: 保存 OV5640 写入 SRAM 后的图像
        // =====================================
        $display("[%0t] Step 3.5: Saving SRAM content after OV5640 write", $time);
        out_file = $fopen("sram_after_write.raw", "wb");
        if (out_file == 0) begin
            $display("ERROR: Cannot create sram_after_write.raw");
        end else begin
            for (i = 0; i < OUT_PIXELS; i = i + 1) begin
                $fwrite(out_file, "%c", dut.u_sram.mem_r[i]);
            end
            $fclose(out_file);
            $display("[%0t] SRAM content after write saved to sram_after_write.raw", $time);
        end
        
        // 清除完成标志
        $display("[%0t] Clearing done flag", $time);
        icb_write(ADDR_STATUS, 32'h0000_0001, 4'hF);
        
        // =====================================
        // 步骤 4: CPU 读取 SRAM 数据
        // =====================================
        $display("[%0t] Step 4: Reading SRAM data (%0d pixels)", $time, OUT_PIXELS);
        for (i = 0; i < OUT_PIXELS; i = i + 1) begin
            icb_read(ADDR_DATA, read_data);
            captured_image[i] = read_data[7:0];
            
            // 每 512 个像素打印一次进度
            if ((i % 512) == 0) begin
                $display("[%0t]   Progress: %0d/%0d pixels read", $time, i, OUT_PIXELS);
            end
        end
        $display("[%0t] All %0d pixels read from SRAM", $time, OUT_PIXELS);
        
        // =====================================
        // 步骤 5: 保存 CPU 读取后的图像
        // =====================================
        $display("[%0t] Step 5: Writing CPU read output file", $time);
        out_file = $fopen("cpu_read_image.raw", "wb");
        if (out_file == 0) begin
            $display("ERROR: Cannot create cpu_read_image.raw");
        end else begin
            for (i = 0; i < OUT_PIXELS; i = i + 1) begin
                $fwrite(out_file, "%c", captured_image[i]);
            end
            $fclose(out_file);
            $display("[%0t] CPU read image saved to cpu_read_image.raw", $time);
        end
        
        // =====================================
        // 步骤 6: 比较两个图像
        // =====================================
        $display("[%0t] Step 6: Comparing images", $time);
        begin : compare_block
            integer mismatch_count;
            mismatch_count = 0;
            for (i = 0; i < OUT_PIXELS; i = i + 1) begin
                if (captured_image[i] !== dut.u_sram.mem_r[i]) begin
                    if (mismatch_count < 10) begin
                        $display("  Mismatch at addr %0d: CPU_read=0x%02x, SRAM=0x%02x", 
                                 i, captured_image[i], dut.u_sram.mem_r[i]);
                    end
                    mismatch_count = mismatch_count + 1;
                end
            end
            
            if (mismatch_count == 0) begin
                $display("  PASS: CPU read data matches SRAM content exactly!");
            end else begin
                $display("  WARNING: %0d mismatches found between CPU read and SRAM", mismatch_count);
            end
        end
        
        // =====================================
        // 测试完成
        // =====================================
        repeat(20) @(posedge icb_clk);
        
        $display("\n========================================");
        $display("  Test COMPLETED!");
        $display("  - Captured %0d pixels", OUT_PIXELS);
        $display("  - Output files:");
        $display("    1. sram_after_write.raw (OV5640 -> SRAM)");
        $display("    2. cpu_read_image.raw (CPU read from SRAM)");
        $display("  - Run: python generate_and_reconstruct.py");
        $display("========================================\n");
        
        $finish;
    end
    
    // =========================================
    // 并行：摄像头数据发送进程
    // =========================================
    initial begin
        // 等待复位和启动信号
        while (!cam_rst_n) @(posedge cam_pclk);
        while (!dut.u_ov5640_y8_top.capture_en) @(posedge cam_pclk);
        
        $display("[%0t] [CAM] capture_en detected, starting to send frames", $time);
        
        // 等待 WAIT_FRAME 个帧
        repeat(5) begin
            send_camera_frame();
        end
        
        $display("[%0t] [CAM] Frames sent", $time);
    end
    
    // =========================================
    // 超时保护
    // =========================================
    initial begin
        #(ICB_CLK_PERIOD * 5000000);  // 50ms 超时
        $display("\n========================================");
        $display("  ERROR: Test timeout!");
        $display("========================================\n");
        $finish;
    end
    
    // =========================================
    // 波形输出（优化版本）
    // =========================================
    initial begin
        $dumpfile("tb_ov5640_icb_top.vcd");
        
        // 方案1：输出所有信号（文件较大）容（可选，避免文件过大）
        $dumpvars(0, tb_ov5640_icb_top);
        
        // 方案2：只输出关键信号（推荐，文件较小）
        // $dumpvars(1, tb_ov5640_icb_top);          // testbench 顶层信号
        // $dumpvars(1, dut);                         // DUT 顶层端口
        // $dumpvars(2, dut.u_icb2dcmi);             // ICB 接口模块
        // $dumpvars(2, dut.u_ov5640_y8_top);        // OV5640 模块
        // // SRAM 内容（可选，会增加很多文件大小）
        // $dumpvars(1, dut.sram_mem);
    end
    
    // =========================================
    // 监控关键信号
    // =========================================
    always @(posedge cam_pclk) begin
        if (cam_rst_n && dut.frame_done_cam) begin
            $display("[%0t] [CAM_DOMAIN] frame_done_cam asserted", $time);
        end
    end
    
    always @(posedge icb_clk) begin
        if (icb_rst_n && dut.frame_done_icb) begin
            $display("[%0t] [ICB_DOMAIN] frame_done_icb pulse detected", $time);
        end
    end
    
    // 监控 SRAM 写操作
    integer sram_write_count;
    initial sram_write_count = 0;
    
    always @(posedge cam_pclk) begin
        if (cam_rst_n && dut.sram_we) begin
            sram_write_count = sram_write_count + 1;
            if (sram_write_count % 512 == 0) begin
                $display("[%0t] [SRAM] %0d pixels written", $time, sram_write_count);
            end
        end
    end

endmodule
