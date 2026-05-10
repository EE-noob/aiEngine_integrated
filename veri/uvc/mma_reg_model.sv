`ifndef MMA_REG_MODEL_SV
`define MMA_REG_MODEL_SV

`include "mma_csr_defines.svh"

class mma_csr_reg extends uvm_reg;
    `uvm_object_utils(mma_csr_reg)

    rand uvm_reg_field data;

    function new(string name = "mma_csr_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build(string access = "RW");
        data = uvm_reg_field::type_id::create("data");
        data.configure(this, 32, 0, access, 0, 32'h0, 1, 1, 0);
    endfunction
endclass

class mma_reg_block extends uvm_reg_block;
    `uvm_object_utils(mma_reg_block)

    rand mma_csr_reg mult_lhs_ptr;
    rand mma_csr_reg mult_rhs_ptr;
    rand mma_csr_reg mult_dst_ptr;
    rand mma_csr_reg mult_bias_ptr;
    rand mma_csr_reg mult_lhs_rows;
    rand mma_csr_reg mult_rhs_cols;
    rand mma_csr_reg mult_rhs_rows;
    rand mma_csr_reg mult_dst_stride;
    rand mma_csr_reg mult_lhs_stride;
    rand mma_csr_reg mult_rhs_stride;
    rand mma_csr_reg mult_lhs_offset;
    rand mma_csr_reg mult_rhs_offset;
    rand mma_csr_reg mult_dst_offset;
    rand mma_csr_reg mult_dst_mult;
    rand mma_csr_reg mult_dst_shift;
    rand mma_csr_reg mult_act_min;
    rand mma_csr_reg mult_act_max;
`ifdef DUT_AXIL
    rand mma_csr_reg axil_ctrl;
`endif

    function new(string name = "mma_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN, 0);

`ifdef DUT_AXI_SOC
        set_hdl_path_root("tb_top.u_soc_top.u_axil_top_with_ram.u_mma_axil_top.u_csr_unit");
`elsif DUT_AXIL
        set_hdl_path_root("tb_top.u_axil_top_with_ram.u_mma_axil_top.u_csr_unit");
`else
        set_hdl_path_root("tb_top.u_top_ai_engine.e203_subsys_nice_core_inst.u_csr_unit");
`endif

        mult_lhs_ptr = mma_csr_reg::type_id::create("mult_lhs_ptr",,get_full_name());
        mult_lhs_ptr.build();
        mult_lhs_ptr.configure(this, null, "");
        mult_lhs_ptr.add_hdl_path_slice("csr_lhs_base", 0, 32);
        default_map.add_reg(mult_lhs_ptr, `ADDR_MULT_LHS_PTR, "RW");

        mult_rhs_ptr = mma_csr_reg::type_id::create("mult_rhs_ptr",,get_full_name());
        mult_rhs_ptr.build();
        mult_rhs_ptr.configure(this, null, "");
        mult_rhs_ptr.add_hdl_path_slice("csr_rhs_base", 0, 32);
        default_map.add_reg(mult_rhs_ptr, `ADDR_MULT_RHS_PTR, "RW");

        mult_dst_ptr = mma_csr_reg::type_id::create("mult_dst_ptr",,get_full_name());
        mult_dst_ptr.build();
        mult_dst_ptr.configure(this, null, "");
        mult_dst_ptr.add_hdl_path_slice("csr_dst_base", 0, 32);
        default_map.add_reg(mult_dst_ptr, `ADDR_MULT_DST_PTR, "RW");

        mult_bias_ptr = mma_csr_reg::type_id::create("mult_bias_ptr",,get_full_name());
        mult_bias_ptr.build();
        mult_bias_ptr.configure(this, null, "");
        mult_bias_ptr.add_hdl_path_slice("csr_bias_base", 0, 32);
        default_map.add_reg(mult_bias_ptr, `ADDR_MULT_BIAS_PTR, "RW");

        mult_lhs_rows = mma_csr_reg::type_id::create("mult_lhs_rows",,get_full_name());
        mult_lhs_rows.build();
        mult_lhs_rows.configure(this, null, "");
        mult_lhs_rows.add_hdl_path_slice("csr_k", 0, 32);
        default_map.add_reg(mult_lhs_rows, `ADDR_MULT_LHS_ROWS, "RW");

        mult_rhs_cols = mma_csr_reg::type_id::create("mult_rhs_cols",,get_full_name());
        mult_rhs_cols.build();
        mult_rhs_cols.configure(this, null, "");
        mult_rhs_cols.add_hdl_path_slice("csr_n", 0, 32);
        default_map.add_reg(mult_rhs_cols, `ADDR_MULT_RHS_COLS, "RW");

        mult_rhs_rows = mma_csr_reg::type_id::create("mult_rhs_rows",,get_full_name());
        mult_rhs_rows.build();
        mult_rhs_rows.configure(this, null, "");
        mult_rhs_rows.add_hdl_path_slice("csr_m", 0, 32);
        default_map.add_reg(mult_rhs_rows, `ADDR_MULT_RHS_ROWS, "RW");

        mult_dst_stride = mma_csr_reg::type_id::create("mult_dst_stride",,get_full_name());
        mult_dst_stride.build();
        mult_dst_stride.configure(this, null, "");
        mult_dst_stride.add_hdl_path_slice("csr_dst_row_stride_b", 0, 32);
        default_map.add_reg(mult_dst_stride, `ADDR_MULT_DST_STRIDE, "RW");

        mult_lhs_stride = mma_csr_reg::type_id::create("mult_lhs_stride",,get_full_name());
        mult_lhs_stride.build();
        mult_lhs_stride.configure(this, null, "");
        mult_lhs_stride.add_hdl_path_slice("csr_lhs_row_stride_b", 0, 32);
        default_map.add_reg(mult_lhs_stride, `ADDR_MULT_LHS_STRIDE, "RW");

        mult_rhs_stride = mma_csr_reg::type_id::create("mult_rhs_stride",,get_full_name());
        mult_rhs_stride.build();
        mult_rhs_stride.configure(this, null, "");
        mult_rhs_stride.add_hdl_path_slice("csr_rhs_col_stride_b", 0, 32);
        default_map.add_reg(mult_rhs_stride, `ADDR_MULT_RHS_STRIDE, "RW");

        mult_lhs_offset = mma_csr_reg::type_id::create("mult_lhs_offset",,get_full_name());
        mult_lhs_offset.build();
        mult_lhs_offset.configure(this, null, "");
        mult_lhs_offset.add_hdl_path_slice("csr_lhs_zp", 0, 32);
        default_map.add_reg(mult_lhs_offset, `ADDR_MULT_LHS_OFFSET, "RW");

        mult_rhs_offset = mma_csr_reg::type_id::create("mult_rhs_offset",,get_full_name());
        mult_rhs_offset.build();
        mult_rhs_offset.configure(this, null, "");
        mult_rhs_offset.add_hdl_path_slice("csr_rhs_zp", 0, 32);
        default_map.add_reg(mult_rhs_offset, `ADDR_MULT_RHS_OFFSET, "RW");

        mult_dst_offset = mma_csr_reg::type_id::create("mult_dst_offset",,get_full_name());
        mult_dst_offset.build();
        mult_dst_offset.configure(this, null, "");
        mult_dst_offset.add_hdl_path_slice("csr_dst_zp", 0, 32);
        default_map.add_reg(mult_dst_offset, `ADDR_MULT_DST_OFFSET, "RW");

        mult_dst_mult = mma_csr_reg::type_id::create("mult_dst_mult",,get_full_name());
        mult_dst_mult.build();
        mult_dst_mult.configure(this, null, "");
        mult_dst_mult.add_hdl_path_slice("csr_q_mult_pt", 0, 32);
        default_map.add_reg(mult_dst_mult, `ADDR_MULT_DST_MULT, "RW");

        mult_dst_shift = mma_csr_reg::type_id::create("mult_dst_shift",,get_full_name());
        mult_dst_shift.build();
        mult_dst_shift.configure(this, null, "");
        mult_dst_shift.add_hdl_path_slice("csr_q_shift_pt", 0, 32);
        default_map.add_reg(mult_dst_shift, `ADDR_MULT_DST_SHIFT, "RW");

        mult_act_min = mma_csr_reg::type_id::create("mult_act_min",,get_full_name());
        mult_act_min.build();
        mult_act_min.configure(this, null, "");
        mult_act_min.add_hdl_path_slice("csr_act_min", 0, 32);
        default_map.add_reg(mult_act_min, `ADDR_MULT_ACT_MIN, "RW");

        mult_act_max = mma_csr_reg::type_id::create("mult_act_max",,get_full_name());
        mult_act_max.build();
        mult_act_max.configure(this, null, "");
        mult_act_max.add_hdl_path_slice("csr_act_max", 0, 32);
        default_map.add_reg(mult_act_max, `ADDR_MULT_ACT_MAX, "RW");

`ifdef DUT_AXIL
        // AXI-Lite special control register at 0x000 (bit0=start pulse).
        axil_ctrl = mma_csr_reg::type_id::create("axil_ctrl",,get_full_name());
        axil_ctrl.build();
        axil_ctrl.configure(this, null, "");
        default_map.add_reg(axil_ctrl, `ADDR_AXIL_REG_CTRL, "RW");

`endif
        lock_model();
    endfunction

endclass

`endif
