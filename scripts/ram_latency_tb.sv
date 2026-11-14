`timescale 1ns/1ps

module ram_latency_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg en = 1'b0;
    reg [3:0] we = 4'b0;
    reg [31:0] addr = 32'b0;
    reg [31:0] din = 32'b0;
    wire [31:0] dout;
    integer cycle = 0;

    always #5 clk = ~clk;
    always @(posedge clk) cycle <= cycle + 1;

    axi_inferred_shared_ram dut (
        .clka(clk), .rsta(rst), .ena(en), .wea(we),
        .addra(addr), .dina(din), .douta(dout),
        .clkb(clk), .rstb(rst), .enb(1'b0), .web(4'b0),
        .addrb(32'b0), .dinb(32'b0), .doutb()
    );

    task automatic check_after_two_edges(input [31:0] request_addr,
                                          input [31:0] expected,
                                          input [255:0] label_text);
        integer request_cycle;
        begin
            @(negedge clk);
            addr = request_addr;
            en = 1'b1;
            request_cycle = cycle;
            @(posedge clk); #1;
            $display("RAM_LATENCY_TRACE label=%0s edge=1 cycle=%0d addr=%08x data=%08x",
                     label_text, cycle, request_addr, dout);
            @(posedge clk); #1;
            $display("RAM_LATENCY_TRACE label=%0s edge=2 cycle=%0d addr=%08x data=%08x",
                     label_text, cycle, request_addr, dout);
            if (dout !== expected) begin
                $display("RAM_LATENCY_FAIL label=%0s request_cycle=%0d expected=%08x got=%08x",
                         label_text, request_cycle, expected, dout);
                $fatal(1, "shared RAM data/latency mismatch");
            end
            @(negedge clk);
            en = 1'b0;
            addr = 32'b0;
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // FlatBuffer bytes 0..7: root offset 0x20, then "TFL3".
        check_after_two_edges(32'h0100_0000, 32'h0000_0020, "MODEL_ROOT");
        check_after_two_edges(32'h0100_0004, 32'h334c_4654, "MODEL_MAGIC");

        // Exercise the shared URAM path's lower/upper 32-bit lane selection.
        @(negedge clk);
        addr = 32'h0000_0000;
        din = 32'h1234_abcd;
        we = 4'hf;
        en = 1'b1;
        @(posedge clk);
        @(negedge clk);
        addr = 32'h0000_0004;
        din = 32'h9876_5432;
        @(posedge clk);
        @(negedge clk);
        we = 4'b0;
        addr = 32'h0000_0000;
        @(posedge clk); #1;
        @(posedge clk); #1;
        if (dout !== 32'h1234_abcd) $fatal(1, "URAM lower lane mismatch: %08x", dout);
        @(negedge clk);
        addr = 32'h0000_0004;
        @(posedge clk); #1;
        @(posedge clk); #1;
        if (dout !== 32'h9876_5432) $fatal(1, "URAM upper lane mismatch: %08x", dout);

        $display("SHARED_RAM_STANDALONE_RESULT=PASS");
        $finish;
    end
endmodule
