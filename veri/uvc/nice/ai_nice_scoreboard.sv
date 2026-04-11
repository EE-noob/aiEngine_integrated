`ifndef AI_NICE_SCOREBOARD_SV
`define AI_NICE_SCOREBOARD_SV

class ai_nice_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ai_nice_scoreboard)

    // 接收来自 Driver 的完成信号
    uvm_analysis_imp #(ai_nice_seq_item, ai_nice_scoreboard) analysis_imp;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_imp = new("analysis_imp", this);
    endfunction

    // 实现 write 函数以处理接收到的事务
    virtual function void write(ai_nice_seq_item tr);
        // 检查是否为矩阵乘法或触发命令
        if (tr.cmd_kind == NICE_AUTO || tr.cmd_kind == NICE_TRIGGER) begin
            // 打印绿色信息: \033[32m (绿色), \033[0m (重置)
            //`uvm_info("SCB", $sformatf("\033[32m matrix mult pass \033[0m"), UVM_LOW)
        end
    endfunction

endclass

`endif
