`ifndef AI_SMOKE_NICE_SEQ_SV
`define AI_SMOKE_NICE_SEQ_SV

// Smoke sequence for nice-core request/response interface.
// Sends a few random instructions through ai_nice_agent.
class ai_smoke_nice_seq extends uvm_sequence#(ai_nice_seq_item);
    `uvm_object_utils(ai_smoke_nice_seq)

    function new(string name = "ai_smoke_nice_seq");
        super.new(name);
    endfunction

    virtual task body();
        ai_nice_seq_item tr;

        `uvm_info(get_type_name(), "Starting smoke nice sequence...", UVM_MEDIUM)

        // 1. CSR Write Test
        `uvm_do_with(tr, {
            cmd_kind == NICE_WR_CSR;
            csr_addr == 32'h7C6; // MULT_LHS_ROWS
            csr_data == 32'd16;
        })

        // 2. CSR Read Test
        `uvm_do_with(tr, {
            cmd_kind == NICE_RD_CSR;
            csr_addr == 32'h7C6;
            csr_data == 32'd16; // Expected value
        })

        // 3. Auto Matrix Multiplication Test
        `uvm_do_with(tr, {
            cmd_kind == NICE_AUTO;
            matrix_m == 56;
            matrix_k == 16;
            matrix_n == 49;
            random_matrix_data == 1;
            // Default config
            per_ch == 0;
            a_w == 1;
            b_w == 1;
            bias_w == 0;
            out_w == 1;

            quant_shift == 3;
            quant_multiplier == 5;
            //bias_base_addr == 32'h0000_0000;
        })
repeat(20)
begin
        // 3. Auto Matrix Multiplication Test
        `uvm_do_with(tr, {
            cmd_kind == NICE_AUTO;
            // matrix_m == 6;
            // matrix_k == 16;
            // matrix_n == 49;
            random_matrix_data == 1;
            // Default config
            per_ch == 0;
            a_w == 1;
            b_w == 1;
            bias_w == 0;
            out_w == 1;

            quant_shift == 3;
            quant_multiplier == 5;
            //bias_base_addr == 32'h0000_0000;
        })
    end

//     repeat(200)
// begin
//         // 3. Auto Matrix Multiplication Test
//         `uvm_do_with(tr, {
//             cmd_kind == NICE_AUTO;
//             // matrix_m == 6;
//             // matrix_k == 16;
//             // matrix_n == 49;
//             random_matrix_data == 1;
//             // // Default config
//             // per_ch == 0;
//             // a_w == 1;
//             // b_w == 1;
//             // bias_w == 0;
//             // out_w == 1;

//             // quant_shift == 3;
//             // quant_multiplier == 5;
//             //bias_base_addr == 32'h0000_0000;
//         })
//     end
        `uvm_info(get_type_name(), "Smoke nice sequence finished - Recompile Triggered", UVM_MEDIUM)
    endtask
endclass

`endif

