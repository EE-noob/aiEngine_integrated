module pseudo_dual_port_ram #(
    parameter DATA_WIDTH = 8,    // 数据宽度
    parameter ADDR_WIDTH = 6     // 地址宽度
) (
    input wire clk,              // 时钟信号
    input wire ena,              // 端口A使能信号
    input wire enb,              // 端口B使能信号
    input wire wea,              // 端口A写使能信号
    input wire [ADDR_WIDTH-1:0] addra, // 端口A地址
    input wire [DATA_WIDTH-1:0] dia,   // 端口A数据输入
    input wire [ADDR_WIDTH-1:0] addrb, // 端口B地址
    output reg [DATA_WIDTH-1:0] dob    // 端口B数据输出
);

    // 定义 RAM 存储器
    reg [DATA_WIDTH-1:0] ram [(1<<ADDR_WIDTH)-1:0];

    // 初始化RAM（用于仿真）
    integer init_i;
    initial begin
        for (init_i = 0; init_i < (1<<ADDR_WIDTH); init_i = init_i + 1) begin
            ram[init_i] = {DATA_WIDTH{1'b0}};
        end
    end

    // 使用一个 always 块来处理两个端口的读写操作
    always @(posedge clk) begin
        // 端口A写操作：如果 ena 和 wea 为高，则写数据
        if (ena && wea) begin
            ram[addra] <= dia; // 端口A写数据到 RAM
        end

        // 端口B读操作：如果 enb 为高，则从 RAM 读取数据
        if (enb) begin
            dob <= ram[addrb]; // 端口B读取数据
        end
    end

endmodule
