`ifndef NPU_REG_MODEL_SV
`define NPU_REG_MODEL_SV

`include "npu_reg_defines.svh"

class npu_reg extends uvm_reg;
    `uvm_object_utils(npu_reg)

    rand uvm_reg_field data;

    function new(string name = "npu_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build(string access = "RW");
        data = uvm_reg_field::type_id::create("data");
        data.configure(this, 32, 0, access, 0, 32'h0, 1, 1, 0);
    endfunction
endclass

class npu_reg_block extends uvm_reg_block;
    `uvm_object_utils(npu_reg_block)

    rand npu_reg npu_lhs_base;
    rand npu_reg npu_rhs_base;
    rand npu_reg npu_dst_base;
    rand npu_reg npu_bias_base;
    rand npu_reg npu_k;
    rand npu_reg npu_n;
    rand npu_reg npu_m;
    rand npu_reg npu_dst_stride_b;
    rand npu_reg npu_lhs_stride_b;
    rand npu_reg npu_rhs_stride_b;
    rand npu_reg npu_lhs_zp;
    rand npu_reg npu_rhs_zp;
    rand npu_reg npu_dst_zp;
    rand npu_reg npu_q_mult;
    rand npu_reg npu_q_shift;
    rand npu_reg npu_act_min;
    rand npu_reg npu_act_max;
`ifdef DUT_AXIL
    rand npu_reg axil_ctrl;
    rand npu_reg axil_ia_reuse;
    rand npu_reg axil_w_reuse;
    rand npu_reg axil_dataflow;
    rand npu_reg axil_row_groups;
    rand npu_reg axil_row_tail_tiles;
    rand npu_reg axil_col_groups;
    rand npu_reg axil_col_tail_tiles;
`endif

    function new(string name = "npu_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN, 0);

`ifdef DUT_AXI_SOC
        set_hdl_path_root("tb_top.u_soc_top.u_npu_axil_top");
`else
        set_hdl_path_root("tb_top.u_axil_top_with_ram.u_npu_axil_top");
`endif

        npu_lhs_base = npu_reg::type_id::create("npu_lhs_base",,get_full_name());
        npu_lhs_base.build();
        npu_lhs_base.configure(this, null, "");
        npu_lhs_base.add_hdl_path_slice("lhs_base_reg", 0, 32);
        default_map.add_reg(npu_lhs_base, `ADDR_NPU_LHS_BASE, "RW");

        npu_rhs_base = npu_reg::type_id::create("npu_rhs_base",,get_full_name());
        npu_rhs_base.build();
        npu_rhs_base.configure(this, null, "");
        npu_rhs_base.add_hdl_path_slice("rhs_base_reg", 0, 32);
        default_map.add_reg(npu_rhs_base, `ADDR_NPU_RHS_BASE, "RW");

        npu_dst_base = npu_reg::type_id::create("npu_dst_base",,get_full_name());
        npu_dst_base.build();
        npu_dst_base.configure(this, null, "");
        npu_dst_base.add_hdl_path_slice("dst_base_reg", 0, 32);
        default_map.add_reg(npu_dst_base, `ADDR_NPU_DST_BASE, "RW");

        npu_bias_base = npu_reg::type_id::create("npu_bias_base",,get_full_name());
        npu_bias_base.build();
        npu_bias_base.configure(this, null, "");
        npu_bias_base.add_hdl_path_slice("bias_base_reg", 0, 32);
        default_map.add_reg(npu_bias_base, `ADDR_NPU_BIAS_BASE, "RW");

        npu_k = npu_reg::type_id::create("npu_k",,get_full_name());
        npu_k.build();
        npu_k.configure(this, null, "");
        npu_k.add_hdl_path_slice("k_reg", 0, 32);
        default_map.add_reg(npu_k, `ADDR_NPU_K, "RW");

        npu_n = npu_reg::type_id::create("npu_n",,get_full_name());
        npu_n.build();
        npu_n.configure(this, null, "");
        npu_n.add_hdl_path_slice("n_reg", 0, 32);
        default_map.add_reg(npu_n, `ADDR_NPU_N, "RW");

        npu_m = npu_reg::type_id::create("npu_m",,get_full_name());
        npu_m.build();
        npu_m.configure(this, null, "");
        npu_m.add_hdl_path_slice("m_reg", 0, 32);
        default_map.add_reg(npu_m, `ADDR_NPU_M, "RW");

        npu_dst_stride_b = npu_reg::type_id::create("npu_dst_stride_b",,get_full_name());
        npu_dst_stride_b.build();
        npu_dst_stride_b.configure(this, null, "");
        npu_dst_stride_b.add_hdl_path_slice("dst_row_stride_b_reg", 0, 32);
        default_map.add_reg(npu_dst_stride_b, `ADDR_NPU_DST_STRIDE_B, "RW");

        npu_lhs_stride_b = npu_reg::type_id::create("npu_lhs_stride_b",,get_full_name());
        npu_lhs_stride_b.build();
        npu_lhs_stride_b.configure(this, null, "");
        npu_lhs_stride_b.add_hdl_path_slice("lhs_row_stride_b_reg", 0, 32);
        default_map.add_reg(npu_lhs_stride_b, `ADDR_NPU_LHS_STRIDE_B, "RW");

        npu_rhs_stride_b = npu_reg::type_id::create("npu_rhs_stride_b",,get_full_name());
        npu_rhs_stride_b.build();
        npu_rhs_stride_b.configure(this, null, "");
        npu_rhs_stride_b.add_hdl_path_slice("rhs_col_stride_b_reg", 0, 32);
        default_map.add_reg(npu_rhs_stride_b, `ADDR_NPU_RHS_STRIDE_B, "RW");

        npu_lhs_zp = npu_reg::type_id::create("npu_lhs_zp",,get_full_name());
        npu_lhs_zp.build();
        npu_lhs_zp.configure(this, null, "");
        npu_lhs_zp.add_hdl_path_slice("lhs_zp_reg", 0, 32);
        default_map.add_reg(npu_lhs_zp, `ADDR_NPU_LHS_ZP, "RW");

        npu_rhs_zp = npu_reg::type_id::create("npu_rhs_zp",,get_full_name());
        npu_rhs_zp.build();
        npu_rhs_zp.configure(this, null, "");
        npu_rhs_zp.add_hdl_path_slice("rhs_zp_reg", 0, 32);
        default_map.add_reg(npu_rhs_zp, `ADDR_NPU_RHS_ZP, "RW");

        npu_dst_zp = npu_reg::type_id::create("npu_dst_zp",,get_full_name());
        npu_dst_zp.build();
        npu_dst_zp.configure(this, null, "");
        npu_dst_zp.add_hdl_path_slice("dst_zp_reg", 0, 32);
        default_map.add_reg(npu_dst_zp, `ADDR_NPU_DST_ZP, "RW");

        npu_q_mult = npu_reg::type_id::create("npu_q_mult",,get_full_name());
        npu_q_mult.build();
        npu_q_mult.configure(this, null, "");
        npu_q_mult.add_hdl_path_slice("q_mult_pt_reg", 0, 32);
        default_map.add_reg(npu_q_mult, `ADDR_NPU_Q_MULT, "RW");

        npu_q_shift = npu_reg::type_id::create("npu_q_shift",,get_full_name());
        npu_q_shift.build();
        npu_q_shift.configure(this, null, "");
        npu_q_shift.add_hdl_path_slice("q_shift_pt_reg", 0, 32);
        default_map.add_reg(npu_q_shift, `ADDR_NPU_Q_SHIFT, "RW");

        npu_act_min = npu_reg::type_id::create("npu_act_min",,get_full_name());
        npu_act_min.build();
        npu_act_min.configure(this, null, "");
        npu_act_min.add_hdl_path_slice("act_min_reg", 0, 32);
        default_map.add_reg(npu_act_min, `ADDR_NPU_ACT_MIN, "RW");

        npu_act_max = npu_reg::type_id::create("npu_act_max",,get_full_name());
        npu_act_max.build();
        npu_act_max.configure(this, null, "");
        npu_act_max.add_hdl_path_slice("act_max_reg", 0, 32);
        default_map.add_reg(npu_act_max, `ADDR_NPU_ACT_MAX, "RW");

`ifdef DUT_AXIL
        // AXI-Lite special control register at 0x000 (bit0=start pulse).
        axil_ctrl = npu_reg::type_id::create("axil_ctrl",,get_full_name());
        axil_ctrl.build();
        axil_ctrl.configure(this, null, "");
        default_map.add_reg(axil_ctrl, `ADDR_NPU_CTRL, "RW");

        axil_ia_reuse = npu_reg::type_id::create("axil_ia_reuse",,get_full_name());
        axil_ia_reuse.build();
        axil_ia_reuse.configure(this, null, "");
        default_map.add_reg(axil_ia_reuse, `ADDR_NPU_IA_REUSE, "RW");

        axil_w_reuse = npu_reg::type_id::create("axil_w_reuse",,get_full_name());
        axil_w_reuse.build();
        axil_w_reuse.configure(this, null, "");
        default_map.add_reg(axil_w_reuse, `ADDR_NPU_W_REUSE, "RW");

        axil_row_groups = npu_reg::type_id::create("axil_row_groups",,get_full_name());
        axil_row_groups.build();
        axil_row_groups.configure(this, null, "");
        default_map.add_reg(axil_row_groups, `ADDR_NPU_ROW_GROUPS, "RW");

        axil_row_tail_tiles = npu_reg::type_id::create("axil_row_tail_tiles",,get_full_name());
        axil_row_tail_tiles.build();
        axil_row_tail_tiles.configure(this, null, "");
        default_map.add_reg(axil_row_tail_tiles, `ADDR_NPU_ROW_TAIL_TILES, "RW");

        axil_col_groups = npu_reg::type_id::create("axil_col_groups",,get_full_name());
        axil_col_groups.build();
        axil_col_groups.configure(this, null, "");
        default_map.add_reg(axil_col_groups, `ADDR_NPU_COL_GROUPS, "RW");

        axil_col_tail_tiles = npu_reg::type_id::create("axil_col_tail_tiles",,get_full_name());
        axil_col_tail_tiles.build();
        axil_col_tail_tiles.configure(this, null, "");
        default_map.add_reg(axil_col_tail_tiles, `ADDR_NPU_COL_TAIL_TILES, "RW");

        axil_dataflow = npu_reg::type_id::create("axil_dataflow",,get_full_name());
        axil_dataflow.build();
        axil_dataflow.configure(this, null, "");
        default_map.add_reg(axil_dataflow, `ADDR_NPU_DATAFLOW, "RW");

`endif
        lock_model();
    endfunction

endclass

`endif
