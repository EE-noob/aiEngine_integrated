`timescale 1ps / 1ps
`include "a7_sim_config.vh"

module a7_smoke_tb;
    localparam integer MAX_CYCLES = `A7_TIMEOUT_CYCLES;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    wire soc_finish;
    wire [31:0] soc_status;
    wire cpu_trap;

    always #(`A7_HALF_PERIOD_PS) clk = ~clk;

    a7_soc dut (
        .clk(clk), .rst_n(rst_n), .uart_rx(1'b1), .uart_tx(),
        .npu_busy(), .npu_irq(), .soc_finish(soc_finish),
        .soc_status(soc_status), .cpu_trap(cpu_trap)
    );

    initial begin
        // The 7-series glbl model asserts GSR for the first 100 ns.
        #150000;
        repeat (8) @(negedge clk);
        rst_n = 1'b1;

        for (int cycle = 1; cycle <= MAX_CYCLES; cycle++) begin
            @(negedge clk);
            if (cpu_trap === 1'b1) $fatal(1, "CPU trap at cycle %0d", cycle);
            if (soc_finish === 1'b1) begin
                if (soc_status !== 32'h0000_0001 || cpu_trap !== 1'b0)
                    $fatal(1, "Firmware failed at cycle %0d: status=%08h trap=%b",
                           cycle, soc_status, cpu_trap);
                $display("A7_SOC_PASS cycle=%0d status=%08h", cycle, soc_status);
                $finish;
            end
        end
        $fatal(1, "Timeout after %0d cycles: status=%08h trap=%b",
               MAX_CYCLES, soc_status, cpu_trap);
    end
endmodule
