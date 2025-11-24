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
    int outstanding_cnt; // 待传输计数器

    // ============================================================
    // M Interface Responder (Memory Model with Outstanding Support)
    // ============================================================

    always @(posedge clk or negedge rst_n) begin
        bit [31:0] addr_aligned;
        bit [31:0] rdata;
        bit cmd_handshake;
        bit rsp_handshake;

        if(!rst_n) begin
            mem.delete();
            rsp_q.delete();
            outstanding_cnt <= 0;
            cmd_ready <= 1'b1;
            rsp_valid <= 1'b0;
            rsp_rdata <= '0;
            rsp_err   <= 1'b0;
        end
        else begin
            cmd_handshake = cmd_valid && cmd_ready;
            rsp_handshake = rsp_valid && rsp_ready;

            // 1. Handle Command (Push to Queue)
            if (cmd_handshake) begin
                addr_aligned = {cmd_addr[31:2], 2'b00};
                if (!cmd_read) begin
                    // Write operation
                    mem[addr_aligned] = cmd_wdata;
                    $display("[M_MEM] Write: addr=0x%08h, data=0x%08h", cmd_addr, cmd_wdata);
                    // Write response (usually just ack)
                    rsp_q.push_back('{32'h0, 1'b0});
                end else begin
                    // Read operation
                    if (mem.exists(addr_aligned))
                        rdata = mem[addr_aligned];
                    else
                        rdata = $urandom();
                    // Read response
                    rsp_q.push_back('{rdata, 1'b0});
                end
            end

            // 2. Handle Response (Pop from Queue)
            if (rsp_handshake) begin
                void'(rsp_q.pop_front());
            end

            // 3. Update Outstanding Count
            if (cmd_handshake && !rsp_handshake)
                outstanding_cnt <= outstanding_cnt + 1;
            else if (!cmd_handshake && rsp_handshake)
                outstanding_cnt <= outstanding_cnt - 1;
            
            // 4. Drive Outputs for NEXT cycle
            // If queue has data (after current cycle's push/pop effects), drive valid
            if (rsp_q.size() > 0) begin
                rsp_valid <= 1'b1;
                rsp_rdata <= rsp_q[0].rdata;
                rsp_err   <= rsp_q[0].err;
            end else begin
                rsp_valid <= 1'b0;
                rsp_rdata <= 32'b0;
                rsp_err   <= 1'b0;
            end
            
            cmd_ready <= 1'b1; // Always ready in this simple model
        end
    end

endmodule

`endif

