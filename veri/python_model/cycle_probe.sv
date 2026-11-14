// Passive observer: the original DUT, RAM and testbench are unmodified.
module python_cycle_probe #(parameter int SIZE = 16) (
    input logic clk
);
    timeunit 1ns;
    timeprecision 1ps;
    import "DPI-C" function void py_capture(
        input int unsigned lane_count,
        input int unsigned scalar_values[32],
        input int unsigned ia_values[SIZE],
        input int unsigned weight_values[SIZE],
        input int unsigned acc_values[SIZE],
        input int unsigned requant_values[SIZE]
    );
    int unsigned scalars[32];
    int unsigned ia[SIZE], weight_data[SIZE], acc[SIZE], requant[SIZE];

    // Observe settled state 1 ps after the edge; the observer never drives RTL.
    always @(posedge clk) begin
        #1ps;
        scalars[0] = $root.tb_npu_top.rst_n;
        scalars[1] = $root.tb_npu_top.calc_start;
        scalars[2] = $root.tb_npu_top.sa_ready;
        scalars[3] = $root.tb_npu_top.done_valid;
        scalars[4] = $root.tb_npu_top.err_code;
        scalars[5] = $root.tb_npu_top.u_dut.ia_row_valid;
        scalars[6] = $root.tb_npu_top.u_dut.store_weight_req;
        scalars[7] = $root.tb_npu_top.u_dut.acc_data_valid;
        scalars[8] = $root.tb_npu_top.u_dut.requant_out_valid;
        scalars[9] = $root.tb_npu_top.u_dut.fifo_full_flag;
        scalars[10] = $root.tb_npu_top.u_dut.tile_calc_over;
        scalars[11] = {
            20'b0,
            $root.tb_npu_top.m_axi_bready, $root.tb_npu_top.m_axi_bvalid,
            $root.tb_npu_top.m_axi_wlast, $root.tb_npu_top.m_axi_wready,
            $root.tb_npu_top.m_axi_wvalid, $root.tb_npu_top.m_axi_awready,
            $root.tb_npu_top.m_axi_awvalid, $root.tb_npu_top.m_axi_rlast,
            $root.tb_npu_top.m_axi_rready, $root.tb_npu_top.m_axi_rvalid,
            $root.tb_npu_top.m_axi_arready, $root.tb_npu_top.m_axi_arvalid
        };
        scalars[12] = $root.tb_npu_top.m_axi_araddr;
        scalars[13] = $root.tb_npu_top.m_axi_arlen;
        scalars[14] = $root.tb_npu_top.m_axi_rdata;
        scalars[15] = $root.tb_npu_top.m_axi_awaddr;
        scalars[16] = $root.tb_npu_top.m_axi_awlen;
        scalars[17] = $root.tb_npu_top.m_axi_wdata;
        scalars[18] = $root.tb_npu_top.m_axi_wstrb;
        scalars[19] = int'($root.tb_npu_top.u_dut.u_npu_controller.current_state);
        scalars[20] = $root.tb_npu_top.u_dut.ia_l1_switch;
        scalars[21] = $root.tb_npu_top.u_dut.ia_tile_start;
        scalars[22] = $root.tb_npu_top.u_dut.ia_calc_done;
        scalars[23] = $root.tb_npu_top.u_dut.weight_data_valid;
        scalars[24] = $root.tb_npu_top.u_dut.fifo_output_valid;
        scalars[25] = $root.tb_npu_top.u_dut.fifo_output_ready;
        scalars[26] = $root.tb_npu_top.u_dut.ia_dma_done;
        scalars[27] = $root.tb_npu_top.u_dut.kernel_dma_done;
        scalars[28] = $root.tb_npu_top.u_dut.oa_dma_done;
        scalars[29] = $root.tb_npu_top.cfg_dataflow_mode;
        scalars[30] = $root.tb_npu_top.cfg_16x8;
        scalars[31] = $root.tb_npu_top.cfg_16bits_ia;
        for (int i = 0; i < SIZE; i++) begin
            ia[i] = int'($signed($root.tb_npu_top.u_dut.ia_out[i]));
            weight_data[i] = int'($signed($root.tb_npu_top.u_dut.weight_out[i]));
            acc[i] = int'($signed($root.tb_npu_top.u_dut.acc_data_out[i]));
            requant[i] = $root.tb_npu_top.cfg_16x8
                ? int'($signed($root.tb_npu_top.u_dut.requant_out_s16[i]))
                : int'($signed($root.tb_npu_top.u_dut.requant_out[i]));
        end
        py_capture(SIZE, scalars, ia, weight_data, acc, requant);
    end
endmodule

bind tb_npu_top python_cycle_probe #(.SIZE(SIZE)) u_python_probe (.clk(clk));
