`ifndef ics_case1_sequence_SV
`define ics_case1_sequence_SV

class ics_case1_sequence extends ics_base_sequence;
    `uvm_object_utils(ics_case1_sequence)

    //todo: Add control variables
    
    function new(string name = "ics_case1_sequence");
        super.new(name);
    endfunction: new

    //todo: Add function here

    // Task: body
    extern virtual task body();

endclass: ics_case1_sequence


task ics_case1_sequence::body();
    //todo: send transactions with cons here
    ics_mst_tr          tr;
    @(vif.drv_cb iff(vif.rst_n === 1));
    repeat(5) @(vif.drv_cb);
    `uvm_do_with(tr, {
        ics_start   ==  1'b1;
        ics_c_init  ==  31'h0;
        ics_q_size  ==  4'd2;
        ics_part0_en    ==  1'b1;
        ics_part0_n_size    ==  11'd32;
        ics_part0_e_size    ==  14'd80;
        ics_part0_l_size    ==  14'd80;
        ics_part0_st_idx    ==  14'd1;
        ics_part1_en    ==  1'b1;
        ics_part1_n_size    ==  11'd32;
        ics_part1_e_size    ==  14'd80;
        ics_part1_l_size    ==  14'd80;
        ics_part1_st_idx    ==  14'd1;
        ics_part2_en    ==  1'b1;
        ics_part2_n_size    ==  11'd32;
        ics_part2_e_size    ==  14'd80;
        ics_part2_l_size    ==  14'd80;
        ics_part2_st_idx    ==  14'd1;
    })

    `uvm_do_with(tr, {
        ics_start   ==  1'b0;
        ics_c_init  ==  31'h0;
        ics_q_size  ==  4'd2;
        ics_part0_en    ==  1'b1;
        ics_part0_n_size    ==  11'd32;
        ics_part0_e_size    ==  14'd80;
        ics_part0_l_size    ==  14'd80;
        ics_part0_st_idx    ==  14'd1;
        ics_part1_en    ==  1'b1;
        ics_part1_n_size    ==  11'd32;
        ics_part1_e_size    ==  14'd80;
        ics_part1_l_size    ==  14'd80;
        ics_part1_st_idx    ==  14'd1;
        ics_part2_en    ==  1'b1;
        ics_part2_n_size    ==  11'd32;
        ics_part2_e_size    ==  14'd80;
        ics_part2_l_size    ==  14'd80;
        ics_part2_st_idx    ==  14'd1;
    })

endtask: body
`endif