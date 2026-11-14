`timescale 1ns/1ps

module axi_key_write_tb;
    reg clk = 1'b0;
    reg resetn = 1'b0;
    reg [3:0] key_in_raw = 4'hf;
    reg [3:0] awaddr = 4'h0;
    reg awvalid = 1'b0;
    wire awready;
    reg [31:0] wdata = 32'h0;
    reg [3:0] wstrb = 4'hf;
    reg wvalid = 1'b0;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg bready = 1'b0;
    reg [3:0] araddr = 4'h0;
    reg arvalid = 1'b0;
    wire arready;
    wire [31:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    reg rready = 1'b0;
    wire irq;

    always #5 clk = ~clk;

    AXI_Key_slave_lite_v1_0_S00_AXI #(
        .KEY_NUM(4),
        .CLOCK_FREQ_MHZ(1),
        .DELAY_MS(1),
        .LONG_PRESS_TIMEOUT_MS(10),
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(4)
    ) dut (
        .key_in_raw(key_in_raw), .irq(irq),
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(resetn),
        .S_AXI_AWADDR(awaddr), .S_AXI_AWPROT(3'b000),
        .S_AXI_AWVALID(awvalid), .S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata), .S_AXI_WSTRB(wstrb),
        .S_AXI_WVALID(wvalid), .S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp), .S_AXI_BVALID(bvalid), .S_AXI_BREADY(bready),
        .S_AXI_ARADDR(araddr), .S_AXI_ARPROT(3'b000),
        .S_AXI_ARVALID(arvalid), .S_AXI_ARREADY(arready),
        .S_AXI_RDATA(rdata), .S_AXI_RRESP(rresp),
        .S_AXI_RVALID(rvalid), .S_AXI_RREADY(rready)
    );

    task automatic send_aw(input [3:0] addr);
        begin
            @(negedge clk);
            awaddr = addr;
            awvalid = 1'b1;
            do @(posedge clk); while (!awready);
            @(negedge clk);
            awvalid = 1'b0;
        end
    endtask

    task automatic send_w(input [31:0] data, input [3:0] strb);
        begin
            @(negedge clk);
            wdata = data;
            wstrb = strb;
            wvalid = 1'b1;
            do @(posedge clk); while (!wready);
            @(negedge clk);
            wvalid = 1'b0;
        end
    endtask

    task automatic finish_write;
        integer timeout;
        begin
            timeout = 0;
            while (!bvalid && timeout < 20) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (!bvalid) $fatal(1, "write response timeout");
            if (bresp != 2'b00) $fatal(1, "write response error: %b", bresp);
            @(negedge clk);
            bready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            bready = 1'b0;
        end
    endtask

    task automatic axi_read(input [3:0] addr, output [31:0] data);
        integer timeout;
        begin
            @(negedge clk);
            araddr = addr;
            arvalid = 1'b1;
            do @(posedge clk); while (!arready);
            @(negedge clk);
            arvalid = 1'b0;
            timeout = 0;
            while (!rvalid && timeout < 20) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (!rvalid) $fatal(1, "read response timeout at %h", addr);
            if (rresp != 2'b00) $fatal(1, "read response error: %b", rresp);
            data = rdata;
            @(negedge clk);
            rready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            rready = 1'b0;
        end
    endtask

    reg [31:0] observed;
    initial begin
        repeat (4) @(negedge clk);
        resetn = 1'b1;

        // AW arrives before W, as can occur on an AXI-Lite master.
        send_aw(4'h0);
        send_w(32'h1122_3344, 4'hf);
        finish_write();
        axi_read(4'h0, observed);
        if (observed !== 32'h1122_3344)
            $fatal(1, "AW-first write/read mismatch: %h", observed);

        // W arrives before AW; the address and byte strobes must be retained.
        send_w(32'haabb_ccdd, 4'hf);
        send_aw(4'h4);
        finish_write();
        axi_read(4'h4, observed);
        if (observed !== 32'haabb_ccdd)
            $fatal(1, "W-first write/read mismatch: %h", observed);

        // A byte-lane update and the software event-clear word write.
        send_aw(4'h0);
        send_w(32'h0000_aa00, 4'b0010);
        finish_write();
        axi_read(4'h0, observed);
        if (observed !== 32'h1122_aa44)
            $fatal(1, "byte-strobe write mismatch: %h", observed);

        send_aw(4'h0);
        send_w(32'h0000_0000, 4'hf);
        finish_write();
        axi_read(4'h0, observed);
        if (observed !== 32'h0000_0000)
            $fatal(1, "key status clear mismatch: %h", observed);

        $display("AXI_KEY_WRITE_TB_PASS");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "testbench timeout");
    end
endmodule
