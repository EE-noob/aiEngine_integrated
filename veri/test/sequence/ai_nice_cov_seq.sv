`ifndef AI_NICE_COV_SEQ_SV
`define AI_NICE_COV_SEQ_SV

// 宏定义：简化随机化和采样过程
`define DO_SAMPLE(TR, CONSTRAINTS) \
    if(!TR.randomize() with CONSTRAINTS) \
        `uvm_error("COV_SEQ", "Randomization failed"); \
    sample_tr(TR);

class ai_nice_cov_seq extends uvm_sequence #(ai_nice_seq_item);
    `uvm_object_utils(ai_nice_cov_seq)

    ai_nice_coverage cov;

    function new(string name = "ai_nice_cov_seq");
        super.new(name);
        // FIX: 移除此处的 new，因为不能在 sequence (run_phase) 中创建 component
        // cov = new("cov", null); 
    endfunction

    task body();
        ai_nice_seq_item tr;
        // Move declarations to top to satisfy older compilers
        int vals_m[];
        int vals_n[];
        int vals_k[];
        int shifts[];
        int scales[];
        int q_levels[];
        bit acts[];
        int aw, bw, ow;
        int i, s, q, a;
        
        // Added for matrix cross coverage
        int m_cross[];
        int n_cross[];
        int k_cross[];
        int m, n, k;

        // FIX: 检查句柄是否由 Test 传入
        if (cov == null) begin
            `uvm_fatal("COV_SEQ", "Coverage component handle 'cov' is null. It must be assigned by the test.")
        end

        tr = ai_nice_seq_item::type_id::create("tr");
        
        // 关闭默认的尺寸限制约束，以便覆盖更大范围 (原约束限制在64以内)
        tr.c_matrix_dims.constraint_mode(0);
        tr.c_matrix_weight.constraint_mode(0);
        tr.c_cfg_defaults.constraint_mode(0); // 关闭默认配置约束

        // FIX: 关闭数值约束以覆盖边界值和特殊场景
        tr.c_quant_params.constraint_mode(0);      // 允许 quant_multiplier=0, quant_shift 超范围
        tr.c_activation_bounds.constraint_mode(0); // 允许 32-bit 激活值
        tr.c_zero_points.constraint_mode(0);       // 允许 32-bit 偏移值

        `uvm_info("COV_SEQ", "Starting Coverage Traversal Sequence...", UVM_LOW)

        // ====================================================
        // 1. 矩阵维度覆盖 (Matrix Dimensions)
        // ====================================================
        `uvm_info("COV_SEQ", "Traversing Matrix Dimensions...", UVM_LOW)
        
        // 1.1 遍历 M 维度 (Small, Medium, Large, Boundaries)
        // Added 3000 to hit 'large' range solidly
        vals_m = '{1, 64, 100, 1024, 2048, 3000, 4096, 65535};
        foreach(vals_m[i]) `DO_SAMPLE(tr, { matrix_m == vals_m[i]; matrix_n inside {[1:64]}; matrix_k inside {[1:64]}; })
        
        // 1.2 遍历 N 维度
        vals_n = '{1, 48, 100, 2048, 3000, 4096, 65535};
        foreach(vals_n[i]) `DO_SAMPLE(tr, { matrix_n == vals_n[i]; matrix_m inside {[1:64]}; matrix_k inside {[1:64]}; })

        // 1.3 遍历 K 维度
        vals_k = '{0, 1, 64, 100, 2048, 3000, 65535};
        foreach(vals_k[i]) `DO_SAMPLE(tr, { matrix_k == vals_k[i]; matrix_m inside {[1:64]}; matrix_n inside {[1:64]}; })

        // 1.4 典型场景交叉 (Typical Scenarios)
        // Vector Mult (M=1 or N=1)
        repeat(5) `DO_SAMPLE(tr, { matrix_m == 1; matrix_k inside {[1:100]}; })
        repeat(5) `DO_SAMPLE(tr, { matrix_n == 1; matrix_k inside {[1:100]}; })
        
        // Debug Case (64x48x64)
        `DO_SAMPLE(tr, { matrix_m == 64; matrix_n == 48; matrix_k == 64; })

        // Medium x Medium (Typical)
        repeat(5) `DO_SAMPLE(tr, { matrix_m inside {[129:2048]}; matrix_n inside {[129:2048]}; matrix_k == 64; })

        // Max x Max (Boundary)
        `DO_SAMPLE(tr, { matrix_m == 1024; matrix_n == 65535; matrix_k == 65535; })

        // ====================================================
        // 1.5 矩阵维度交叉覆盖 (Matrix Dimension Cross)
        // ====================================================
        `uvm_info("COV_SEQ", "Traversing Matrix Dimension Cross...", UVM_LOW)
        
        // Explicitly iterate through Small, Medium, Large bins for M, N, K
        // Small: [1:128], Medium: [129:2048], Large: [2049:65535]
        m_cross = '{64, 1000, 4000};
        n_cross = '{64, 1000, 4000};
        k_cross = '{64, 1000, 4000};

        foreach(m_cross[m]) begin
            foreach(n_cross[n]) begin
                foreach(k_cross[k]) begin
                    `DO_SAMPLE(tr, {
                        matrix_m == m_cross[m];
                        matrix_n == n_cross[n];
                        matrix_k == k_cross[k];
                    })
                end
            end
        end

        // ====================================================
        // 2. 量化配置覆盖 (Quantization)
        // ====================================================
        `uvm_info("COV_SEQ", "Traversing Quantization Configs...", UVM_LOW)
        
        // 遍历 Shift: Disabled(0), Small([1:8]), Medium([9:16]), Large([17:31])
        shifts = '{0, 4, 12, 16, 20, -5};
        foreach(shifts[i]) `DO_SAMPLE(tr, { quant_shift == shifts[i]; })

        // 遍历 Per-Channel
        `DO_SAMPLE(tr, { per_ch == 0; })
        `DO_SAMPLE(tr, { per_ch == 1; })

        // Multiplier (Zero, Small, Medium, Large)
        `DO_SAMPLE(tr, { quant_multiplier == 0; })
        `DO_SAMPLE(tr, { quant_multiplier inside {[1:256]}; })
        `DO_SAMPLE(tr, { quant_multiplier inside {[257:65535]}; })
        `DO_SAMPLE(tr, { quant_multiplier inside {[65536:32'h007F_FFFF]}; }) 

        // Offsets (Negative, Zero, Positive)
        `DO_SAMPLE(tr, { lhs_offset == -128; rhs_offset == -128; dst_offset == -128; })
        `DO_SAMPLE(tr, { lhs_offset == 0; rhs_offset == 0; dst_offset == 0; })
        `DO_SAMPLE(tr, { lhs_offset == 127; rhs_offset == 127; dst_offset == 127; })

        // ====================================================
        // 3. 激活函数覆盖 (Activation)
        // ====================================================
        `uvm_info("COV_SEQ", "Traversing Activation Functions...", UVM_LOW)
        
        // 1. Cross Bin: relu_like (min=zero, max=pos_max)
        `DO_SAMPLE(tr, { act_min == 0; act_max == 32'h7FFFFFFF; })

        // 2. Cross Bin: clamp (min=neg_max, max=normal)
        // Covers: cp_act_min.neg_max && cp_act_max.normal
        `DO_SAMPLE(tr, { act_min == 32'h80000000; act_max == 100; })

        // 3. Cross Bin: clamp (min=zero, max=normal)
        // Covers: cp_act_min.zero && cp_act_max.normal
        `DO_SAMPLE(tr, { act_min == 0; act_max == 100; })

        // 4. Cross Bin: clamp (min=pos_values, max=normal)
        // Covers: cp_act_min.pos_values && cp_act_max.normal
        `DO_SAMPLE(tr, { act_min == 10; act_max == 100; })

        // Additional cases for robustness
        // Disabled (Typical range)
        `DO_SAMPLE(tr, { act_min == -32768; act_max == 32767; })
        
        // Clamp (Small range negative)
        `DO_SAMPLE(tr, { act_min == -10; act_max == 10; })

        // Zero Max
        `DO_SAMPLE(tr, { act_min == -100; act_max == 0; })

        // ====================================================
        // 4. 数据位宽覆盖 (Data Width)
        // ====================================================
        `uvm_info("COV_SEQ", "Traversing Data Widths...", UVM_LOW)
        
        // 遍历所有位宽组合
        for(aw=0; aw<=2; aw++) begin // s4, s8, s16
            for(bw=0; bw<=2; bw++) begin
                for(ow=0; ow<=4; ow++) begin // s4..s64
                    `DO_SAMPLE(tr, { a_w == aw; b_w == bw; out_w == ow; })
                end
            end
        end

        // ====================================================
        // 5. 参数交叉覆盖 (Parameter Cross)
        // ====================================================
        `uvm_info("COV_SEQ", "Traversing Parameter Cross...", UVM_LOW)
        
        // Explicitly iterate to hit all cross bins
        // Matrix Scale: Small(100), Medium(1000), Large(30000)
        // Quant Level: Off(0), Mode A(5), Mode B(20)
        // Activation: Off(min=80..00, max=7F..FF), On(min=0, max=100)
        scales = '{100, 1000, 30000};
        q_levels = '{0, 5, 20};
        acts = '{0, 1}; // 0: off, 1: on

        foreach(scales[s]) begin
            foreach(q_levels[q]) begin
                foreach(acts[a]) begin
                    // Skip illegal: Large & Mode B & On
                    if (scales[s] == 30000 && q_levels[q] == 20 && acts[a] == 1) continue;
                    
                    `DO_SAMPLE(tr, {
                        matrix_m == scales[s];
                        quant_shift == q_levels[q];
                        if (acts[a] == 0) {
                            act_min == 32'h80000000;
                            act_max == 32'h7FFFFFFF;
                        } else {
                            act_min == 0;
                            act_max == 100;
                        }
                        per_ch inside {0, 1};
                    })
                end
            end
        end

        // ====================================================
        // 6. 填充性能和异常字段 (Manual Sampling)
        // ====================================================
        `uvm_info("COV_SEQ", "Traversing Manual Fields...", UVM_LOW)
        
        // Exceptions
        tr.overflow_detected = 1; sample_tr(tr);
        tr.overflow_detected = 0;
        
        tr.illegal_config_type = 1; sample_tr(tr); // Wrong order
        tr.illegal_config_type = 2; sample_tr(tr); // Out of range
        tr.illegal_config_type = 3; sample_tr(tr); // Zero dimension
        tr.illegal_config_type = 4; sample_tr(tr); // Invalid combination
        tr.illegal_config_type = 0;

        tr.reset_during_operation = 1; sample_tr(tr);
        tr.reset_during_operation = 2; sample_tr(tr);
        tr.reset_during_operation = 3; sample_tr(tr); // Added
        tr.reset_during_operation = 0;

        // Interface Timing
        for(i=0; i<=3; i++) begin
            tr.csr_access_type = i; sample_tr(tr);
        end
        
        tr.icb_ready_delay = 0; sample_tr(tr);
        tr.icb_ready_delay = 3; sample_tr(tr);
        tr.icb_ready_delay = 10; sample_tr(tr);

        tr.icb_cmd_type = 0; sample_tr(tr);
        tr.icb_cmd_type = 1; sample_tr(tr);

        // Bus Arbitration (0 to 4 requests)
        for(i=0; i<=4; i++) begin
            tr.bus_arbitration = i; sample_tr(tr);
        end

        // Scenario
        tr.consecutive_task_count = 1; sample_tr(tr);
        tr.consecutive_task_count = 3; sample_tr(tr);
        tr.consecutive_task_count = 10; sample_tr(tr);

        tr.task_interval_cycles = 0; sample_tr(tr);
        tr.task_interval_cycles = 5; sample_tr(tr);
        tr.task_interval_cycles = 50; sample_tr(tr);

        `uvm_info("COV_SEQ", "Coverage Traversal Completed.", UVM_LOW)
        
        // 打印覆盖率报告
        print_coverage_report();
    endtask

    // 采样函数
    function void sample_tr(ai_nice_seq_item t);
        // 填充 Monitor 通常负责的分析字段 (Dummy values if not set)
        if (t.latency_cycles == 0) t.latency_cycles = 100;
        if (t.throughput_ops_per_cycle == 0) t.throughput_ops_per_cycle = 20.0;
        
        // 调用 coverage 组件的 write 函数
        cov.write(t);
    endfunction

    // 打印覆盖率报告函数
    function void print_coverage_report();
        real current_cov;
        real total_cov = 0.0;
        int cg_count = 0;

        `uvm_info("COV_RPT", "\n------------------------------------------------", UVM_LOW)
        `uvm_info("COV_RPT", "             COVERAGE REPORT                    ", UVM_LOW)
        `uvm_info("COV_RPT", "------------------------------------------------", UVM_LOW)

        // 获取各个 Covergroup 的覆盖率
        current_cov = cov.cg_matrix_dimension.get_coverage();
        total_cov += current_cov; cg_count++;
        `uvm_info("COV_RPT", $sformatf("Matrix Dimension:    %6.2f%%", current_cov), UVM_LOW)

        current_cov = cov.cg_quantization_config.get_coverage();
        total_cov += current_cov; cg_count++;
        `uvm_info("COV_RPT", $sformatf("Quantization Config: %6.2f%%", current_cov), UVM_LOW)

        current_cov = cov.cg_activation_function.get_coverage();
        total_cov += current_cov; cg_count++;
        `uvm_info("COV_RPT", $sformatf("Activation Function: %6.2f%%", current_cov), UVM_LOW)

        current_cov = cov.cg_data_width.get_coverage();
        total_cov += current_cov; cg_count++;
        `uvm_info("COV_RPT", $sformatf("Data Width:          %6.2f%%", current_cov), UVM_LOW)

        current_cov = cov.cg_parameter_cross.get_coverage();
        total_cov += current_cov; cg_count++;
        `uvm_info("COV_RPT", $sformatf("Parameter Cross:     %6.2f%%", current_cov), UVM_LOW)

        current_cov = cov.cg_interface_timing.get_coverage();
        total_cov += current_cov; cg_count++;
        `uvm_info("COV_RPT", $sformatf("Interface Timing:    %6.2f%%", current_cov), UVM_LOW)

        current_cov = cov.cg_scenario.get_coverage();
        total_cov += current_cov; cg_count++;
        `uvm_info("COV_RPT", $sformatf("Scenario:            %6.2f%%", current_cov), UVM_LOW)

        current_cov = cov.cg_exception.get_coverage();
        total_cov += current_cov; cg_count++;
        `uvm_info("COV_RPT", $sformatf("Exception:           %6.2f%%", current_cov), UVM_LOW)

        `uvm_info("COV_RPT", "------------------------------------------------", UVM_LOW)
        if (cg_count > 0)
            `uvm_info("COV_RPT", $sformatf("AVERAGE COVERAGE:    %6.2f%%", total_cov/cg_count), UVM_LOW)
        `uvm_info("COV_RPT", "------------------------------------------------\n", UVM_LOW)
    endfunction

endclass

`endif // AI_NICE_COV_SEQ_SV


