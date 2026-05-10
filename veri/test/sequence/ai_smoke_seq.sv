`ifndef AI_SMOKE_SEQ_SV
`define AI_SMOKE_SEQ_SV

// Top-level smoke sequence:
// 在一个 sequence 里统一调度对 NICE UVC 的激励。
class ai_smoke_seq extends uvm_sequence#(mma_seq_item);
    `uvm_object_utils(ai_smoke_seq)

    // 由 test 在启动前填充该句柄
    mma_sequencer nice_seqr;

    function new(string name = "ai_smoke_seq");
        super.new(name);
    endfunction

    virtual task body();
        ai_smoke_nice_seq nice_seq;

        if (nice_seqr == null) begin
            `uvm_fatal(get_type_name(),
                       "ai_smoke_seq: nice_seqr is null, please set it before start()")
        end

        `uvm_info(get_type_name(), "ai_smoke_seq body start", UVM_MEDIUM)

        nice_seq = ai_smoke_nice_seq::type_id::create("nice_seq", , get_full_name());
        // 目前场景简单，仅启动 NICE smoke sequence
        nice_seq.start(nice_seqr);

        `uvm_info(get_type_name(), "ai_smoke_seq body end", UVM_MEDIUM)
    endtask
endclass

`endif

