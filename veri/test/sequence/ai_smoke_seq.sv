`ifndef AI_SMOKE_SEQ_SV
`define AI_SMOKE_SEQ_SV

// Top-level smoke sequence:
// 在一个 sequence 里统一调度对各个 UVC 的激励，
// 通过子序列 ai_smoke_dcmi_seq / ai_smoke_cam_seq / ai_smoke_nice_seq
// 分别驱动 DCMI / CAM / NICE 三个 agent。

class ai_smoke_seq extends uvm_sequence#(uvm_sequence_item);
    `uvm_object_utils(ai_smoke_seq)

    // 由 test 在启动前填充这三个句柄
    ai_dcmi_sequencer dcmi_seqr;
    ai_cam_sequencer  cam_seqr;
    ai_nice_sequencer nice_seqr;

    function new(string name = "ai_smoke_seq");
        super.new(name);
    endfunction

    virtual task body();
        ai_smoke_dcmi_seq dcmi_seq;
        ai_smoke_cam_seq  cam_seq;
        ai_smoke_nice_seq nice_seq;

        if (dcmi_seqr == null || cam_seqr == null || nice_seqr == null) begin
            `uvm_fatal(get_type_name(),
                       "ai_smoke_seq: sequencer handles are null, please set dcmi_seqr/cam_seqr/nice_seqr before start()")
        end

        `uvm_info(get_type_name(), "ai_smoke_seq body start", UVM_MEDIUM)

        dcmi_seq = ai_smoke_dcmi_seq::type_id::create("dcmi_seq", , get_full_name());
        cam_seq  = ai_smoke_cam_seq ::type_id::create("cam_seq" , , get_full_name());
        nice_seq = ai_smoke_nice_seq::type_id::create("nice_seq", , get_full_name());

        // 在同一个 smoke seq 里并发驱动三个 UVC
        fork
            dcmi_seq.start(dcmi_seqr);
            cam_seq .start(cam_seqr);
            nice_seq.start(nice_seqr);
        join

        `uvm_info(get_type_name(), "ai_smoke_seq body end", UVM_MEDIUM)
    endtask
endclass

`endif

