module soc_top #(
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter WEIGHT_WIDTH    = 8,
    parameter DATA_WIDTH      = 16,
    parameter SIZE            = 16,
    parameter BUS_WIDTH       = 32,
    parameter REG_WIDTH       = 32,
    parameter ICB_ADDR_WIDTH  = 32,
    parameter ICB_LEN_W       = 4,
    parameter CPU_MEM_DP      = 65536,
    parameter MMA_MEM_DP      = 131072,
    parameter CPU_MEM_PATH    = "../tb/axi_soc_case/cpu.mem",
    parameter MMA_MEM_PATH    = "../tb/main_extram.mem",
    parameter [31:0] CPU_RAM_BASE  = 32'h0000_0000,
    parameter [31:0] MMA_AXIL_BASE = 32'h1000_0000,
    parameter [31:0] SOC_CTRL_BASE = 32'h2000_0000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mem_reload_req,
    output wire        mma_busy,
    output wire [31:0] mma_irq,
    output wire [31:0] mma_eoi,
    output reg         soc_finish,
    output reg  [31:0] soc_status,
    output wire        cpu_trap
);

    localparam integer CPU_ADDR_LSB  = 2;
    localparam integer CPU_ADDR_BITS = (CPU_MEM_DP <= 1) ? 1 : $clog2(CPU_MEM_DP);

    localparam [2:0] S_IDLE    = 3'd0;
    localparam [2:0] S_AXIL_WR = 3'd1;
    localparam [2:0] S_AXIL_WB = 3'd2;
    localparam [2:0] S_AXIL_RD = 3'd3;
    localparam [2:0] S_AXIL_RB = 3'd4;

    reg [2:0] state_q;

    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    reg  [31:0] mem_rdata;

    wire mem_is_write = |mem_wstrb;
    wire mem_sel_cpu  = (mem_addr[31:28] == CPU_RAM_BASE[31:28]);
    wire mem_sel_mma  = (mem_addr[31:28] == MMA_AXIL_BASE[31:28]);
    wire mem_sel_soc  = (mem_addr[31:28] == SOC_CTRL_BASE[31:28]);

    reg [31:0] cpu_mem [0:CPU_MEM_DP-1];
    wire [CPU_ADDR_BITS-1:0] cpu_mem_idx =
        mem_addr[CPU_ADDR_LSB + CPU_ADDR_BITS - 1:CPU_ADDR_LSB];

    integer i;
    string cpu_mem_path_q;
    initial begin
        cpu_mem_path_q = CPU_MEM_PATH;
        void'($value$plusargs("SOC_CPU_MEM=%s", cpu_mem_path_q));
        if (cpu_mem_path_q != "") begin
            $display("soc_top: loading PicoRV32 program memory from %s", cpu_mem_path_q);
            $readmemh(cpu_mem_path_q, cpu_mem);
        end
    end

    task automatic reload_cpu_mem_from_file(input string file_path);
        if (file_path != "") begin
            $display("soc_top: runtime reload PicoRV32 program memory from %s", file_path);
            $readmemh(file_path, cpu_mem);
        end
    endtask

    picorv32 #(
        .ENABLE_COUNTERS(1),
        .ENABLE_COUNTERS64(0),
        .ENABLE_REGS_16_31(1),
        .ENABLE_REGS_DUALPORT(1),
        .TWO_STAGE_SHIFT(1),
        .BARREL_SHIFTER(0),
        .TWO_CYCLE_COMPARE(0),
        .TWO_CYCLE_ALU(0),
        .COMPRESSED_ISA(0),
        .CATCH_MISALIGN(1),
        .CATCH_ILLINSN(1),
        .ENABLE_MUL(1),
        .ENABLE_DIV(1),
        .ENABLE_IRQ(0),
        .PROGADDR_RESET(CPU_RAM_BASE),
        .STACKADDR(CPU_RAM_BASE + (CPU_MEM_DP * 4))
    ) u_picorv32 (
        .clk(clk),
        .resetn(rst_n),
        .trap(cpu_trap),
        .mem_valid(mem_valid),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),
        .mem_la_read(),
        .mem_la_write(),
        .mem_la_addr(),
        .mem_la_wdata(),
        .mem_la_wstrb(),
        .pcpi_valid(),
        .pcpi_insn(),
        .pcpi_rs1(),
        .pcpi_rs2(),
        .pcpi_wr(1'b0),
        .pcpi_rd(32'b0),
        .pcpi_wait(1'b0),
        .pcpi_ready(1'b0),
        .irq(32'b0),
        .eoi(),
        .trace_valid(),
        .trace_data()
    );

    reg [AXIL_ADDR_WIDTH-1:0] axil_addr_q;
    reg [31:0]                axil_wdata_q;
    reg [3:0]                 axil_wstrb_q;
    reg                       axil_awvalid_q;
    reg                       axil_wvalid_q;
    reg                       axil_bready_q;
    reg                       axil_arvalid_q;
    reg                       axil_rready_q;

    wire                      axil_awready;
    wire                      axil_wready;
    wire [1:0]                axil_bresp;
    wire                      axil_bvalid;
    wire                      axil_arready;
    wire [31:0]               axil_rdata;
    wire [1:0]                axil_rresp;
    wire                      axil_rvalid;

    axil_top_with_ram #(
        .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
        .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .BUS_WIDTH(BUS_WIDTH),
        .REG_WIDTH(REG_WIDTH),
        .ICB_ADDR_WIDTH(ICB_ADDR_WIDTH),
        .ICB_LEN_W(ICB_LEN_W),
        .MEM_DP(MMA_MEM_DP),
        .MEM_PATH(MMA_MEM_PATH),
        .MEM_INIT_EN(1)
    ) u_axil_top_with_ram (
        .clk(clk),
        .rst_n(rst_n),
        .s_axil_awaddr(axil_addr_q),
        .s_axil_awprot(3'b000),
        .s_axil_awvalid(axil_awvalid_q),
        .s_axil_awready(axil_awready),
        .s_axil_wdata(axil_wdata_q),
        .s_axil_wstrb(axil_wstrb_q),
        .s_axil_wvalid(axil_wvalid_q),
        .s_axil_wready(axil_wready),
        .s_axil_bresp(axil_bresp),
        .s_axil_bvalid(axil_bvalid),
        .s_axil_bready(axil_bready_q),
        .s_axil_araddr(axil_addr_q),
        .s_axil_arprot(3'b000),
        .s_axil_arvalid(axil_arvalid_q),
        .s_axil_arready(axil_arready),
        .s_axil_rdata(axil_rdata),
        .s_axil_rresp(axil_rresp),
        .s_axil_rvalid(axil_rvalid),
        .s_axil_rready(axil_rready_q),
        .irq(mma_irq),
        .eoi(mma_eoi),
        .mem_reload_req(mem_reload_req),
        .mma_busy(mma_busy)
    );

    assign mma_eoi = 32'h0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q        <= S_IDLE;
            mem_ready      <= 1'b0;
            mem_rdata      <= 32'b0;
            axil_addr_q    <= {AXIL_ADDR_WIDTH{1'b0}};
            axil_wdata_q   <= 32'b0;
            axil_wstrb_q   <= 4'b0;
            axil_awvalid_q <= 1'b0;
            axil_wvalid_q  <= 1'b0;
            axil_bready_q  <= 1'b0;
            axil_arvalid_q <= 1'b0;
            axil_rready_q  <= 1'b0;
            soc_finish     <= 1'b0;
            soc_status     <= 32'b0;
        end else begin
            mem_ready <= 1'b0;

            if (mem_reload_req) begin
                reload_cpu_mem_from_file(cpu_mem_path_q);
            end

            case (state_q)
                S_IDLE: begin
                    if (mem_valid && !mem_ready) begin
                        if (mem_sel_cpu) begin
                            mem_rdata <= cpu_mem[cpu_mem_idx];
                            if (mem_is_write) begin
                                for (i = 0; i < 4; i = i + 1) begin
                                    if (mem_wstrb[i]) begin
                                        cpu_mem[cpu_mem_idx][8*i +: 8] <= mem_wdata[8*i +: 8];
                                    end
                                end
                            end
                            mem_ready <= 1'b1;
                        end else if (mem_sel_soc) begin
                            mem_rdata <= (mem_addr[3:2] == 2'b00) ? soc_status :
                                         (mem_addr[3:2] == 2'b01) ? {31'b0, soc_finish} :
                                         (mem_addr[3:2] == 2'b10) ? {31'b0, cpu_trap} : 32'b0;
                            if (mem_is_write && (mem_addr[3:2] == 2'b00)) begin
                                soc_finish <= 1'b1;
                                soc_status <= mem_wdata;
                            end
                            mem_ready <= 1'b1;
                        end else if (mem_sel_mma) begin
                            axil_addr_q  <= mem_addr[AXIL_ADDR_WIDTH-1:0];
                            if (mem_is_write) begin
                                axil_wdata_q   <= mem_wdata;
                                axil_wstrb_q   <= mem_wstrb;
                                axil_awvalid_q <= 1'b1;
                                axil_wvalid_q  <= 1'b1;
                                state_q        <= S_AXIL_WR;
                            end else begin
                                axil_arvalid_q <= 1'b1;
                                state_q        <= S_AXIL_RD;
                            end
                        end else begin
                            mem_rdata <= 32'hDEAD_BEEF;
                            mem_ready <= 1'b1;
                        end
                    end
                end

                S_AXIL_WR: begin
                    if (axil_awvalid_q && axil_awready) begin
                        axil_awvalid_q <= 1'b0;
                    end
                    if (axil_wvalid_q && axil_wready) begin
                        axil_wvalid_q <= 1'b0;
                    end
                    if ((!axil_awvalid_q || axil_awready) && (!axil_wvalid_q || axil_wready)) begin
                        axil_bready_q <= 1'b1;
                        state_q       <= S_AXIL_WB;
                    end
                end

                S_AXIL_WB: begin
                    if (axil_bvalid) begin
                        axil_bready_q <= 1'b0;
                        mem_rdata     <= {30'b0, axil_bresp};
                        mem_ready     <= 1'b1;
                        state_q       <= S_IDLE;
                    end
                end

                S_AXIL_RD: begin
                    if (axil_arvalid_q && axil_arready) begin
                        axil_arvalid_q <= 1'b0;
                        axil_rready_q  <= 1'b1;
                        state_q        <= S_AXIL_RB;
                    end
                end

                S_AXIL_RB: begin
                    if (axil_rvalid) begin
                        axil_rready_q <= 1'b0;
                        mem_rdata     <= axil_rdata;
                        mem_ready     <= 1'b1;
                        state_q       <= S_IDLE;
                    end
                end

                default: begin
                    state_q <= S_IDLE;
                end
            endcase
        end
    end

    wire _unused = mem_instr | |axil_rresp;

endmodule
