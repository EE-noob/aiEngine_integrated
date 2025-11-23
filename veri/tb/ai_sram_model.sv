`ifndef AI_SRAM_MODEL_SV
`define AI_SRAM_MODEL_SV

module ai_sram_model (
    input  logic        clk,
    input  logic        rst_n,

    // ICB Command Channel
    input  logic        cmd_valid,
    output logic        cmd_ready,
    input  logic [31:0] cmd_addr,
    input  logic        cmd_read,
    input  logic [31:0] cmd_wdata,
    input  logic [1:0]  cmd_size,

    // ICB Response Channel
    output logic        rsp_valid,
    input  logic        rsp_ready,
    output logic [31:0] rsp_rdata,
    output logic        rsp_err
);

    // 使用关联数组模拟大容量稀疏存储器
    bit [31:0] mem [int];
    
    // 响应队列，用于处理流水线请求
    typedef struct {
        bit [31:0] rdata;
        bit        err;
    } rsp_item_t;
    
    rsp_item_t rsp_q[$];

    // 简化模型：总是准备好接收命令
    assign cmd_ready = 1'b1;

    // 命令处理逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem.delete();
            rsp_q.delete();
        end else begin
            if (cmd_valid && cmd_ready) begin
                if (cmd_read) begin
                    // 读操作
                    bit [31:0] rdata;
                    // 简单的字对齐
                    bit [31:0] addr_aligned;
                    addr_aligned = {cmd_addr[31:2], 2'b00}; // FIX: 分开声明和赋值
                    
                    if (mem.exists(addr_aligned)) begin
                        rdata = mem[addr_aligned];
                    end else begin
                        rdata = $urandom(); // 地址无数据时返回随机数
                    end
                    // 将读结果推入响应队列
                    rsp_q.push_back('{rdata, 1'b0});
                end else begin
                    // 写操作
                    bit [31:0] addr_aligned;
                    addr_aligned = {cmd_addr[31:2], 2'b00}; // FIX: 分开声明和赋值
                    mem[addr_aligned] = cmd_wdata;
                    // 写操作也需要返回响应（通常数据为0）
                    rsp_q.push_back('{32'h0, 1'b0});
                end
            end
        end
    end

    // 响应驱动逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_valid <= 1'b0;
            rsp_rdata <= 32'b0;
            rsp_err   <= 1'b0;
        end else begin
            // 如果当前没有有效响应，或者当前响应已被接受，则尝试发送下一个
            if (!rsp_valid || (rsp_valid && rsp_ready)) begin
                if (rsp_q.size() > 0) begin
                    rsp_valid <= 1'b1;
                    rsp_rdata <= rsp_q[0].rdata;
                    rsp_err   <= rsp_q[0].err;
                    void'(rsp_q.pop_front());
                end else begin
                    rsp_valid <= 1'b0;
                    rsp_rdata <= 32'b0;
                    rsp_err   <= 1'b0;
                end
            end
        end
    end

endmodule

`endif
