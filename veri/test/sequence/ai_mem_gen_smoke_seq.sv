`ifndef AI_MEM_GEN_SMOKE_SEQ_SV
`define AI_MEM_GEN_SMOKE_SEQ_SV

class ai_mem_gen_smoke_seq extends uvm_sequence#(ai_nice_seq_item);
    `uvm_object_utils(ai_mem_gen_smoke_seq)

    function new(string name = "ai_mem_gen_smoke_seq");
        super.new(name);
    endfunction

    virtual task body();
        ai_nice_seq_item tr;

        `uvm_info(get_type_name(), "Start ai_mem_gen_smoke_seq", UVM_MEDIUM)

        // One AUTO transaction is enough to exercise:
        // CSR configure -> gen_mem_info(py) -> mem reload -> mat_mult trigger.
        `uvm_do_with(tr, {
            cmd_kind == NICE_AUTO;
            matrix_k == 16;
            matrix_n == 32;
            matrix_m == 24;
            fix_mode == 1;
            random_matrix_data == 1;
            per_ch == 0;
            a_w == 1;
            b_w == 1;
            bias_w == 2;
            out_w == 1;
            quant_shift == 3;
            quant_multiplier == 32'd1024;
            act_min == 32'sd1;
            act_max == 32'sd127;
            lhs_offset == 1;
            rhs_offset == 0;
            dst_offset == 1;
        })

        `uvm_info(get_type_name(), "End ai_mem_gen_smoke_seq", UVM_MEDIUM)
    endtask
endclass

`endif
