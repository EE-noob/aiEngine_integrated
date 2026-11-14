`ifndef TOP_TB__SV
`define TOP_TB__SV
`timescale 1ns/1ps

module tb_top ();
    `include "uvm_macros.svh"
    import uvm_pkg::*;

    logic                     clk;
    logic                     rst_n;

    ics_if  ics_vif(.clk(clk),.rst_n(rst_n));
    filo_env_if filo_vif(.clk(clk));
    combine_if  combine_vif(.clk(clk));

    // 连接到 ics_top
    ics_top u_ics_top (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .ics_start                  (ics_vif.ics_start),
        .ics_c_init                 (ics_vif.ics_c_init),
        .ics_q_size                 (ics_vif.ics_q_size),
        .ics_part0_en               (ics_vif.ics_part0_en),
        .ics_part0_n_size           (ics_vif.ics_part0_n_size),
        .ics_part0_e_size           (ics_vif.ics_part0_e_size),
        .ics_part0_l_size           (ics_vif.ics_part0_l_size),
        .ics_part0_st_idx           (ics_vif.ics_part0_st_idx),
        .ics_part1_en               (ics_vif.ics_part1_en),
        .ics_part1_n_size           (ics_vif.ics_part1_n_size),
        .ics_part1_e_size           (ics_vif.ics_part1_e_size),
        .ics_part1_l_size           (ics_vif.ics_part1_l_size),
        .ics_part1_st_idx           (ics_vif.ics_part1_st_idx),
        .ics_part2_en               (ics_vif.ics_part2_en),
        .ics_part2_n_size           (ics_vif.ics_part2_n_size),
        .ics_part2_e_size           (ics_vif.ics_part2_e_size),
        .ics_part2_l_size           (ics_vif.ics_part2_l_size),
        .ics_part2_st_idx           (ics_vif.ics_part2_st_idx),
        .ics_rd_en                  (ics_vif.ics_rd_en),
        .ics_rd_addr                (ics_vif.ics_rd_addr),
        .ics_rd_data                (ics_vif.ics_rd_data),
        .ics_out_sof                (ics_vif.ics_out_sof),
        .ics_out_eof                (ics_vif.ics_out_eof),
        .ics_out_vld                (ics_vif.ics_out_vld),
        .ics_out_num                (ics_vif.ics_out_num),
        .ics_out_data               (ics_vif.ics_out_data)
    );

    initial begin
        force filo_vif.part0_filoA_rdA_en   =  u_ics_top.intlv_top_inst.part0_filoA_rdA_en;
        force filo_vif.part0_filoB_rdA_en   =  u_ics_top.intlv_top_inst.part0_filoB_rdA_en;
        force filo_vif.part1_filoA_rdA_en   =  u_ics_top.intlv_top_inst.part1_filoA_rdA_en;
        force filo_vif.part1_filoB_rdA_en   =  u_ics_top.intlv_top_inst.part1_filoB_rdA_en;
        force filo_vif.part2_filoA_rdA_en   =  u_ics_top.intlv_top_inst.part2_filoA_rdA_en;
        force filo_vif.part2_filoB_rdA_en   =  u_ics_top.intlv_top_inst.part2_filoB_rdA_en;

        force filo_vif.part0_filoA_rdA_data =    u_ics_top.intlv_top_inst.part0_filoA_rdA_data;
        force filo_vif.part0_filoB_rdA_data =    u_ics_top.intlv_top_inst.part0_filoB_rdA_data;
        force filo_vif.part1_filoA_rdA_data =    u_ics_top.intlv_top_inst.part1_filoA_rdA_data;
        force filo_vif.part1_filoB_rdA_data =    u_ics_top.intlv_top_inst.part1_filoB_rdA_data;
        force filo_vif.part2_filoA_rdA_data =    u_ics_top.intlv_top_inst.part2_filoA_rdA_data;
        force filo_vif.part2_filoB_rdA_data =    u_ics_top.intlv_top_inst.part2_filoB_rdA_data;

        force filo_vif.part0_filoA_rdB_en   =    u_ics_top.intlv_top_inst.part0_filoA_rdB_en;
        force filo_vif.part0_filoB_rdB_en   =    u_ics_top.intlv_top_inst.part0_filoB_rdB_en;
        force filo_vif.part1_filoA_rdB_en   =    u_ics_top.intlv_top_inst.part1_filoA_rdB_en;
        force filo_vif.part1_filoB_rdB_en   =    u_ics_top.intlv_top_inst.part1_filoB_rdB_en;
        force filo_vif.part2_filoA_rdB_en   =    u_ics_top.intlv_top_inst.part2_filoA_rdB_en;
        force filo_vif.part2_filoB_rdB_en   =    u_ics_top.intlv_top_inst.part2_filoB_rdB_en;

        force filo_vif.part0_filoA_rdB_data =    u_ics_top.intlv_top_inst.part0_filoA_rdB_data;
        force filo_vif.part0_filoB_rdB_data =    u_ics_top.intlv_top_inst.part0_filoB_rdB_data;
        force filo_vif.part1_filoA_rdB_data =    u_ics_top.intlv_top_inst.part1_filoA_rdB_data;
        force filo_vif.part1_filoB_rdB_data =    u_ics_top.intlv_top_inst.part1_filoB_rdB_data;
        force filo_vif.part2_filoA_rdB_data =    u_ics_top.intlv_top_inst.part2_filoA_rdB_data;
        force filo_vif.part2_filoB_rdB_data =    u_ics_top.intlv_top_inst.part2_filoB_rdB_data;

        force filo_vif.part0_filoA_rdC_en   =  u_ics_top.intlv_top_inst.part0_filoA_rdC_en;
        force filo_vif.part0_filoB_rdC_en   =  u_ics_top.intlv_top_inst.part0_filoB_rdC_en;
        force filo_vif.part1_filoA_rdC_en   =  u_ics_top.intlv_top_inst.part1_filoA_rdC_en;
        force filo_vif.part1_filoB_rdC_en   =  u_ics_top.intlv_top_inst.part1_filoB_rdC_en;
        force filo_vif.part2_filoA_rdC_en   =  u_ics_top.intlv_top_inst.part2_filoA_rdC_en;
        force filo_vif.part2_filoB_rdC_en   =  u_ics_top.intlv_top_inst.part2_filoB_rdC_en;

        force filo_vif.part0_filoA_rdC_data =    u_ics_top.intlv_top_inst.part0_filoA_rdC_data;
        force filo_vif.part0_filoB_rdC_data =    u_ics_top.intlv_top_inst.part0_filoB_rdC_data;
        force filo_vif.part1_filoA_rdC_data =    u_ics_top.intlv_top_inst.part1_filoA_rdC_data;
        force filo_vif.part1_filoB_rdC_data =    u_ics_top.intlv_top_inst.part1_filoB_rdC_data;
        force filo_vif.part2_filoA_rdC_data =    u_ics_top.intlv_top_inst.part2_filoA_rdC_data;
        force filo_vif.part2_filoB_rdC_data =    u_ics_top.intlv_top_inst.part2_filoB_rdC_data;

        force filo_vif.part0_filoA_rdD_en   =    u_ics_top.intlv_top_inst.part0_filoA_rdD_en;
        force filo_vif.part0_filoB_rdD_en   =    u_ics_top.intlv_top_inst.part0_filoB_rdD_en;
        force filo_vif.part1_filoA_rdD_en   =    u_ics_top.intlv_top_inst.part1_filoA_rdD_en;
        force filo_vif.part1_filoB_rdD_en   =    u_ics_top.intlv_top_inst.part1_filoB_rdD_en;
        force filo_vif.part2_filoA_rdD_en   =    u_ics_top.intlv_top_inst.part2_filoA_rdD_en;
        force filo_vif.part2_filoB_rdD_en   =    u_ics_top.intlv_top_inst.part2_filoB_rdD_en;

        force filo_vif.part0_filoA_rdD_data =    u_ics_top.intlv_top_inst.part0_filoA_rdD_data;
        force filo_vif.part0_filoB_rdD_data =    u_ics_top.intlv_top_inst.part0_filoB_rdD_data;
        force filo_vif.part1_filoA_rdD_data =    u_ics_top.intlv_top_inst.part1_filoA_rdD_data;
        force filo_vif.part1_filoB_rdD_data =    u_ics_top.intlv_top_inst.part1_filoB_rdD_data;
        force filo_vif.part2_filoA_rdD_data =    u_ics_top.intlv_top_inst.part2_filoA_rdD_data;
        force filo_vif.part2_filoB_rdD_data =    u_ics_top.intlv_top_inst.part2_filoB_rdD_data;

        force filo_vif.part0_filoA_rd1_en   =    u_ics_top.intlv_top_inst.part0_filoA_rd1_en;
        force filo_vif.part0_filoB_rd1_en   =    u_ics_top.intlv_top_inst.part0_filoB_rd1_en;
        force filo_vif.part1_filoA_rd1_en   =    u_ics_top.intlv_top_inst.part1_filoA_rd1_en;
        force filo_vif.part1_filoB_rd1_en   =    u_ics_top.intlv_top_inst.part1_filoB_rd1_en;
        force filo_vif.part2_filoA_rd1_en   =    u_ics_top.intlv_top_inst.part2_filoA_rd1_en;
        force filo_vif.part2_filoB_rd1_en   =    u_ics_top.intlv_top_inst.part2_filoB_rd1_en;

        force filo_vif.part0_filoA_rd1_data =    u_ics_top.intlv_top_inst.part0_filoA_rd1_data;
        force filo_vif.part0_filoB_rd1_data =    u_ics_top.intlv_top_inst.part0_filoB_rd1_data;
        force filo_vif.part1_filoA_rd1_data =    u_ics_top.intlv_top_inst.part1_filoA_rd1_data;
        force filo_vif.part1_filoB_rd1_data =    u_ics_top.intlv_top_inst.part1_filoB_rd1_data;
        force filo_vif.part2_filoA_rd1_data =    u_ics_top.intlv_top_inst.part2_filoA_rd1_data;
        force filo_vif.part2_filoB_rd1_data =    u_ics_top.intlv_top_inst.part2_filoB_rd1_data;

        force filo_vif.part0_filoA_rdy4rd =  u_ics_top.intlv_top_inst.part0_filoA_rdy4rd;
        force filo_vif.part0_filoB_rdy4rd =  u_ics_top.intlv_top_inst.part0_filoB_rdy4rd;
        force filo_vif.part1_filoA_rdy4rd =  u_ics_top.intlv_top_inst.part1_filoA_rdy4rd;
        force filo_vif.part1_filoB_rdy4rd =  u_ics_top.intlv_top_inst.part1_filoB_rdy4rd;
        force filo_vif.part2_filoA_rdy4rd =  u_ics_top.intlv_top_inst.part2_filoA_rdy4rd;
        force filo_vif.part2_filoB_rdy4rd =  u_ics_top.intlv_top_inst.part2_filoB_rdy4rd;

        force filo_vif.combine_eof = u_ics_top.combine_top_inst.combine_eof;
        force filo_vif.ics_part0_e_size = u_ics_top.ics_part0_e_size;
        force filo_vif.ics_part0_l_size = u_ics_top.ics_part0_l_size;
        force filo_vif.ics_part1_e_size = u_ics_top.ics_part1_e_size;
        force filo_vif.ics_part1_l_size = u_ics_top.ics_part1_l_size;
        force filo_vif.ics_part2_e_size = u_ics_top.ics_part2_e_size;
        force filo_vif.ics_part2_l_size = u_ics_top.ics_part2_l_size;
        force filo_vif.ics_part0_st_idx = u_ics_top.ics_part0_st_idx;
        force filo_vif.ics_part1_st_idx = u_ics_top.ics_part1_st_idx;
        force filo_vif.ics_part2_st_idx = u_ics_top.ics_part2_st_idx;

        force combine_vif.combine_data = u_ics_top.combine_top_inst.combine_data;
        force combine_vif.combine_valid = u_ics_top.combine_top_inst.combine_valid;
        force combine_vif.combine_num =u_ics_top.combine_top_inst.combine_num;
    end

    initial begin
        clk     = 1;
        rst_n   = 0;
        repeat(10) @(negedge clk);
        rst_n   = 1;
    end

    always begin
        #5ns clk = ~clk;
    end

    // 推迟 run_test()，确保 reset 已经释放
    initial begin
        run_test();
    end

    initial begin
        $fsdbDumpfile("sim.fsdb");
        $fsdbDumpvars(0,tb_top);
        $fsdbDumpMDA(0,tb_top);
    end

    initial begin
        uvm_config_db#(virtual ics_if)::set(uvm_root::get(),"*","ics_vif",ics_vif);
        uvm_config_db#(virtual filo_env_if)::set(uvm_root::get(),"*","filo_vif",filo_vif);
        uvm_config_db#(virtual combine_if)::set(uvm_root::get(),"*","combine_vif",combine_vif);
    end

endmodule: tb_top

`endif
