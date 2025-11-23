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
        int aw, bw, ow;

        // FIX: 检查句柄是否由 Test 传入
        if (cov == null) begin
            `uvm_fatal("COV_SEQ", "Coverage component handle 'cov' is null. It must be assigned by the test.")
        end

        tr = ai_nice_seq_item::type_id::create("tr");
        
        // 关闭默认的尺寸限制约束，以便覆盖更大范围 (原约束限制在64以内)
        tr.c_matrix_dims.constraint_mode(0);
        tr.c_matrix_weight.constraint_mode(0);
        tr.c_cfg_defaults.constraint_mode(0); // 关闭默认配置约束

        `uvm_info("COV_SEQ", "Starting Coverage Traversal Sequence...", UVM_LOW)

        // ====================================================
        // 1. 矩阵维度覆盖 (Matrix Dimensions)
        // ====================================================
        `uvm_info("COV_SEQ", "Traversing Matrix Dimensions...", UVM_LOW)
        
        // 1.1 遍历 M 维度 (Small, Medium, Large, Boundaries)
        vals_m = '{1, 64, 100, 1024, 2048, 4096};
        foreach(vals_m[i]) `DO_SAMPLE(tr, { matrix_m == vals_m[i]; matrix_n inside {[1:64]}; matrix_k inside {[1:64]}; })
        
        // 1.2 遍历 N 维度
        vals_n = '{1, 48, 100, 2048, 4096};
        foreach(vals_n[i]) `DO_SAMPLE(tr, { matrix_n == vals_n[i]; matrix_m inside {[1:64]}; matrix_k inside {[1:64]}; })

        // 1.3 遍历 K 维度
        vals_k = '{1, 64, 100, 2048};
        foreach(vals_k[i]) `DO_SAMPLE(tr, { matrix_k == vals_k[i]; matrix_m inside {[1:64]}; matrix_n inside {[1:64]}; })

        // 1.4 典型场景交叉 (Typical Scenarios)
        // Vector Mult (M=1 or N=1)
        repeat(5) `DO_SAMPLE(tr, { matrix_m == 1; matrix_k inside {[1:100]}; })
        repeat(5) `DO_SAMPLE(tr, { matrix_n == 1; matrix_k inside {[1:100]}; })
        
        // Debug Case (64x48x64)
        `DO_SAMPLE(tr, { matrix_m == 64; matrix_n == 48; matrix_k == 64; })

        // ====================================================
        // 2. 量化配置覆盖 (Quantization)
        // ====================================================
        `uvm_info("COV_SEQ", "Traversing Quantization Configs...", UVM_LOW)
        
        // 遍历 Shift: Disabled(0), Small([1:8]), Medium([9:16]), Large([17:31])
        shifts = '{0, 4, 12, 20};
        foreach(shifts[i]) `DO_SAMPLE(tr, { quant_shift == shifts[i]; })

        // 遍历 Per-Channel
        `DO_SAMPLE(tr, { per_ch == 0; })
        `DO_SAMPLE(tr, { per_ch == 1; })

        // ====================================================
        // 3. 激活函数覆盖 (Activation)
        // ====================================================
        `uvm_info("COV_SEQ", "Traversing Activation Functions...", UVM_LOW)
        
        // Disabled
        `DO_SAMPLE(tr, { act_min == -32768; act_max == 32767; })
        
        // ReLU-like (0 to Max)
        `DO_SAMPLE(tr, { act_min == 0; act_max == 32767; })
        
        // Clamp (Small range)
        `DO_SAMPLE(tr, { act_min == -10; act_max == 10; })

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
        // 5. 填充性能和异常字段 (Performance & Exceptions)
        // ====================================================
        // 手动设置这些由 Monitor 采集的字段
        
        // Latency
        tr.latency_cycles = 500;   sample_tr(tr); // Fast
        tr.latency_cycles = 5000;  sample_tr(tr); // Normal
        tr.latency_cycles = 50000; sample_tr(tr); // Slow
        
        // Throughput
        tr.throughput_ops_per_cycle = 5.0;  sample_tr(tr); // Low
        tr.throughput_ops_per_cycle = 50.0; sample_tr(tr); // Medium
        
        // Exceptions
        tr.overflow_detected = 1; sample_tr(tr);
        tr.overflow_detected = 0;
        
        tr.illegal_config_type = 1; sample_tr(tr); // Wrong order
        tr.illegal_config_type = 0;

        `uvm_info("COV_SEQ", "Coverage Traversal Completed.", UVM_LOW)
    endtask

    // 采样函数
    function void sample_tr(ai_nice_seq_item t);
        // 填充 Monitor 通常负责的分析字段 (Dummy values if not set)
        if (t.latency_cycles == 0) t.latency_cycles = 100;
        if (t.throughput_ops_per_cycle == 0) t.throughput_ops_per_cycle = 20.0;
        
        // 调用 coverage 组件的 write 函数
        cov.write(t);
    endfunction

endclass

`endif // AI_NICE_COV_SEQ_SV
