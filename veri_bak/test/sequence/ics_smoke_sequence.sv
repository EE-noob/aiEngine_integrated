`ifndef ics_SMOKE_SEQUENCE_SV
`define ics_SMOKE_SEQUENCE_SV

class ics_smoke_sequence extends ics_base_sequence;
    `uvm_object_utils(ics_smoke_sequence)

    //todo: Add control variables
    
    function new(string name = "ics_smoke_sequence");
        super.new(name);
    endfunction: new

    //todo: Add function here

    // Task: body
    extern virtual task body();

endclass: ics_smoke_sequence


task ics_smoke_sequence::body();
    //todo: send transactions with cons here
    ics_mst_tr          tr;
    @(vif.drv_cb iff(vif.rst_n === 1));
    repeat(5) @(vif.drv_cb);
    `uvm_do_with(tr, {
        ics_start   ==  1'b1;
        ics_c_init  ==  `ICS_C_INIT;
        ics_q_size  ==  `ICS_Q_SIZE;
        ics_part0_en    ==  `ICS_PART0_EN;
        ics_part0_n_size    ==  `ICS_PART0_N_SIZE;
        ics_part0_e_size    ==  `ICS_PART0_E_SIZE;
        ics_part0_l_size    ==  `ICS_PART0_L_SIZE;
        ics_part0_st_idx    ==  `ICS_PART0_ST_IDX;
        ics_part1_en    ==  `ICS_PART1_EN;
        ics_part1_n_size    ==  `ICS_PART1_N_SIZE;
        ics_part1_e_size    ==  `ICS_PART1_E_SIZE;
        ics_part1_l_size    ==  `ICS_PART1_L_SIZE;
        ics_part1_st_idx    ==  `ICS_PART1_ST_IDX;
        ics_part2_en    ==  `ICS_PART2_EN;
        ics_part2_n_size    ==  `ICS_PART2_N_SIZE;
        ics_part2_e_size    ==  `ICS_PART2_E_SIZE;
        ics_part2_l_size    ==  `ICS_PART2_L_SIZE;
        ics_part2_st_idx    ==  `ICS_PART2_ST_IDX;
    })

    `uvm_do_with(tr, {
        ics_start   ==  1'b0;
        ics_c_init  ==  `ICS_C_INIT;
        ics_q_size  ==  `ICS_Q_SIZE;
        ics_part0_en    ==  `ICS_PART0_EN;
        ics_part0_n_size    ==  `ICS_PART0_N_SIZE;
        ics_part0_e_size    ==  `ICS_PART0_E_SIZE;
        ics_part0_l_size    ==  `ICS_PART0_L_SIZE;
        ics_part0_st_idx    ==  `ICS_PART0_ST_IDX;
        ics_part1_en    ==  `ICS_PART1_EN;
        ics_part1_n_size    ==  `ICS_PART1_N_SIZE;
        ics_part1_e_size    ==  `ICS_PART1_E_SIZE;
        ics_part1_l_size    ==  `ICS_PART1_L_SIZE;
        ics_part1_st_idx    ==  `ICS_PART1_ST_IDX;
        ics_part2_en    ==  `ICS_PART2_EN;
        ics_part2_n_size    ==  `ICS_PART2_N_SIZE;
        ics_part2_e_size    ==  `ICS_PART2_E_SIZE;
        ics_part2_l_size    ==  `ICS_PART2_L_SIZE;
        ics_part2_st_idx    ==  `ICS_PART2_ST_IDX;
    })

endtask: body
`endif