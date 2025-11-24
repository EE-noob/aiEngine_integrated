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
      bit [31:0] rsp_cnt;
    bit [31:0] addr_aligned;
    // ============================================================
    // M Interface Responder (Memory Model)
    // ============================================================

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mem.delete(); 
        end
        else begin
            if (cmd_valid && cmd_ready) begin
                // Command accepted
                if (!cmd_read) begin
                    // Write operation
                    bit [31:0] addr_aligned;
                    addr_aligned = {cmd_addr[31:2], 2'b00}; // FIX: Separate declaration and assignment
                    mem[addr_aligned] = cmd_wdata;
                    $display("[M_MEM] Write: addr=0x%08h, data=0x%08h", 
                             cmd_addr, cmd_wdata);
                end
            end
        end
    end
    // always @(posedge clk or negedge rst_n) begin // rsp
    //     if(!rst_n) begin
    //         cmd_ready <= 1'b1; // TODO: add random ready
    //         rsp_valid <= 1'b0;
    //         rsp_rdata <= '0;
    //         rsp_err   <= 1'b0;
    //     end
    //     else begin
    //         // Command accepted
    //         if (cmd_read) begin
    //             if (cmd_valid && cmd_ready) begin
                    
    //                 rsp_valid <= 1'b1; // todo:多拍后返回数据，使用queue/fifo暂存，待够四拍可以往外发
    //                 begin
    //                     addr_aligned = {cmd_addr[31:2], 2'b00}; // FIX: Separate declaration and assignment
    //                     if (mem.exists(addr_aligned))
    //                         rsp_rdata <= mem[addr_aligned];
    //                     else
    //                         rsp_rdata <= $urandom();
    //                 end
    //                 rsp_err <= 1'b0;
    //             end
    //             else if(rsp_valid && rsp_ready) begin
    //                 rsp_valid <= 1'b0;
    //                 rsp_rdata <= '0;
    //                 rsp_err <= 1'b0;
    //             end
    //         end else begin     // write rsp operation
    //             if (cmd_valid && cmd_ready) begin
    //                 rsp_valid <= 1'b1;
    //                 rsp_err <= 1'b0; // TODO: 注入错误
    //             end
    //             else if(rsp_valid && rsp_ready) begin
    //                 rsp_valid <= 1'b0;
    //                 rsp_err <= 1'b0;
    //             end
    //         end
    //     end
    // end
    always @(posedge clk or negedge rst_n) begin // rsp
        if(!rst_n) begin
            cmd_ready <= 1'b1; // TODO: add random ready
            rsp_valid <= 1'b0;
            rsp_rdata <= '0;
            rsp_err   <= 1'b0;
            rsp_cnt<=0;
        end
        else begin
            // Command accepted
            if (cmd_read) begin
                if (cmd_valid && cmd_ready) begin
                    if((rsp_valid && rsp_ready))
                        rsp_cnt<=rsp_cnt;
                    else
                        rsp_cnt<=rsp_cnt+1;
                end else begin
                      if((rsp_valid && rsp_ready))
                        rsp_cnt<=rsp_cnt-1;
                    else
                        rsp_cnt<=rsp_cnt;
                end
                if( rsp_cnt>0 )
                   // todo:多拍后返回数据，使用queue/fifo暂存，待够四拍可以往外发
                    begin
                        rsp_valid <= 1'b1;
                        addr_aligned = {cmd_addr[31:2], 2'b00}; // FIX: Separate declaration and assignment
                        if (mem.exists(addr_aligned))
                            rsp_rdata <= mem[addr_aligned];
                        else
                            rsp_rdata <= $urandom();
                    end
                else if(rsp_valid && rsp_ready) begin
                    rsp_valid <= 1'b0;
                    rsp_rdata <= '0;
                    rsp_err <= 1'b0;
                end
            end else begin     // write rsp operation
                if (cmd_valid && cmd_ready) begin
                    rsp_valid <= 1'b1;
                    rsp_err <= 1'b0; // TODO: 注入错误
                end
                else if(rsp_valid && rsp_ready) begin
                    rsp_valid <= 1'b0;
                    rsp_err <= 1'b0;
                end
            end
        end
    end

endmodule

`endif

