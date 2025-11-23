`ifndef AI_NICE_COVERAGE_SV
`define AI_NICE_COVERAGE_SV

class ai_nice_coverage extends uvm_subscriber#(ai_nice_seq_item);
    `uvm_component_utils(ai_nice_coverage) // FIX: 使用正确的类名

    // FIX: 将成员变量声明移到 covergroup 之前，确保 coverpoint 能识别到
    int m_rows, n_cols, k_inner;
    bit per_ch;
    int quant_shift, quant_mult;
    int lhs_offset, rhs_offset, dst_offset;
    int act_min, act_max;
    bit [1:0] a_width, b_width, bias_width;
    bit [2:0] out_width;
    int csr_access_type;
    int icb_ready_delay, icb_cmd_type;
    int bus_arbitration; // Renamed from bus_utilization
    int consecutive_task_count, task_interval_cycles;
    int csr_mma_order;
    int latency_cycles;
    real throughput_ops_per_cycle;
    bit overflow_detected, saturation_occurred;
    int illegal_config_type;
    int reset_during_operation;
    int extreme_value_test;

    // 覆盖组：矩阵维度覆盖
    covergroup cg_matrix_dimension;
        option.per_instance = 1;
        option.name = "matrix_dimension_coverage";
        
        // M维度覆盖点
        cp_m_rows: coverpoint m_rows {
            bins val_small = {[1:128]};           // 小规模
            bins val_medium = {[129:2048]};       // 中等规模
            bins val_large = {[2049:65535]};      // 大规模
        }
        
        // N维度覆盖点
        cp_n_cols: coverpoint n_cols {
            bins val_small = {[1:128]};
            bins val_medium = {[129:2048]};
            bins val_large = {[2049:65535]};
        }
        
        // K维度覆盖点
        cp_k_inner: coverpoint k_inner {
            bins val_small = {[1:128]};
            bins val_medium = {[129:2048]};
            bins val_large = {[2049:65535]};
        }
        
        // 矩阵规模交叉覆盖 - 自动交叉上述定义的 val_small, val_medium, val_large
        cross_matrix_size: cross cp_m_rows, cp_n_cols, cp_k_inner;
    endgroup

    // 覆盖组：量化配置覆盖
    covergroup cg_quantization_config;
        option.per_instance = 1;
        option.name = "quantization_config_coverage";
        
        // 量化模式
        cp_quant_mode: coverpoint per_ch {
            bins per_tensor = {0};
            bins per_channel = {1};
        }
        
        // 量化移位因子
        cp_quant_shift: coverpoint quant_shift {
            bins disabled = {0};              // 不开启量化
            bins val_small = {[1:8]};             // 小移位
            bins val_medium = {[9:16]};           // 中等量化
            bins val_large = {[17:31]};           // 最大量化
        }
        
        // 量化乘数
        cp_quant_mult: coverpoint quant_mult {
            //bins zero = {0};
            bins val_small = {[1:256]};
            bins val_medium = {[257:65535]};
            bins val_large = {[65536:$]};
        }
        
        // 零点覆盖
        cp_lhs_offset: coverpoint lhs_offset {
            bins neg_extreme = {[$:-128]};
            bins zero = {0};
            bins pos_extreme = {[127:$]};
        }
        
        cp_rhs_offset: coverpoint rhs_offset {
            bins neg_extreme = {[$:-128]};
            bins zero = {0};
            bins pos_extreme = {[127:$]};
        }
        
        cp_dst_offset: coverpoint dst_offset {
            bins neg_extreme = {[$:-128]};
            bins zero = {0};
            bins pos_extreme = {[127:$]};
        }
    endgroup

    // 覆盖组：激活函数覆盖
    covergroup cg_activation_function;
        option.per_instance = 1;
        option.name = "activation_function_coverage";
        
        cp_act_min: coverpoint act_min {
            bins neg_max = {32'h80000000};    // 最小值
            bins zero = {0};
            bins pos_values = {[1:$]};
        }
        
        cp_act_max: coverpoint act_max {
            bins zero = {0};
            bins pos_max = {32'h7FFFFFFF};    // 最大值
            bins normal = {[1:32'h7FFFFFFE]};
        }
        
        // 激活函数启用状态
        cp_act_enabled: coverpoint (act_min != 32'h80000000 || act_max != 32'h7FFFFFFF) {
            bins disabled = {0};              // 未启用
            bins enabled = {1};               // 启用
        }
        
        // 激活函数类型交叉
        cross_activation: cross cp_act_min, cp_act_max {
            bins relu_like = binsof(cp_act_min.zero) && binsof(cp_act_max.pos_max);
            bins clamp = binsof(cp_act_min) && binsof(cp_act_max.normal);
        }
    endgroup

    // 覆盖组：数据位宽覆盖
    covergroup cg_data_width;
        option.per_instance = 1;
        option.name = "data_width_coverage";
        
        cp_a_width: coverpoint a_width {
            bins s4 = {2'b00};
            bins s8 = {2'b01};
            bins s16 = {2'b10};
        }
        
        cp_b_width: coverpoint b_width {
            bins s4 = {2'b00};
            bins s8 = {2'b01};
            bins s16 = {2'b10};
        }
        
        cp_bias_width: coverpoint bias_width {
            bins s8 = {2'b00};
            bins s16 = {2'b01};
            bins s32 = {2'b10};
            bins s64 = {2'b11};
        }
        
        cp_out_width: coverpoint out_width {
            bins s4 = {3'b000};
            bins s8 = {3'b001};
            bins s16 = {3'b010};
            bins s32 = {3'b011};
            bins s64 = {3'b100};
        }
    endgroup

    // 覆盖组：参数组合交叉覆盖
    covergroup cg_parameter_cross;
        option.per_instance = 1;
        option.name = "parameter_cross_coverage";
        
        cp_matrix_scale: coverpoint m_rows {
            bins val_small = {[1:128]};
            bins val_medium = {[129:2048]};
            bins val_large = {[2049:65535]};
        }
        
        cp_quant_level: coverpoint quant_shift {
            bins off = {0};
            bins mode_a = {[1:8]};
            bins mode_b = {[9:31]};
        }
        
        cp_activation: coverpoint (act_min != 32'h80000000 || act_max != 32'h7FFFFFFF) {
            bins off = {0};
            bins on = {1};
        }
        
        cp_per_channel: coverpoint per_ch {
            bins per_tensor = {0};
            bins per_channel = {1};
        }
        
        // 关键交叉覆盖
        cross_key_params: cross cp_matrix_scale, cp_quant_level, cp_activation {
            ignore_bins illegal = binsof(cp_matrix_scale.val_large) && 
                                 binsof(cp_quant_level.mode_b) && 
                                 binsof(cp_activation.on);
        }
        
        // 完整组合覆盖
        cross_all_params: cross cp_matrix_scale, cp_quant_level, cp_activation, cp_per_channel;
    endgroup

    // 覆盖组：接口时序覆盖
    covergroup cg_interface_timing;
        option.per_instance = 1;
        option.name = "interface_timing_coverage";
        
        // CSR访问类型
        cp_csr_access: coverpoint csr_access_type {
            bins single_write = {0};
            bins continuous_write = {1};
            bins read_verify = {2};
            bins write_read = {3};
        }
        
        // ICB总线握手
        cp_icb_ready_delay: coverpoint icb_ready_delay {
            bins no_delay = {0};
            bins short_delay = {[1:5]};
            bins long_delay = {[6:20]};
        }
        
        cp_icb_cmd_type: coverpoint icb_cmd_type {
            bins read = {0};
            bins write = {1};
        }
        
        // 总线仲裁 (0-4个请求)
        cp_bus_arbitration: coverpoint bus_arbitration {
            bins req_0 = {0};
            bins req_1 = {1};
            bins req_2 = {2};
            bins req_3 = {3};
            bins req_4 = {4};
        }
    endgroup

    // 覆盖组：场景覆盖
    covergroup cg_scenario;
        option.per_instance = 1;
        option.name = "scenario_coverage";
        
        // 连续任务数量
        cp_task_count: coverpoint consecutive_task_count {
            bins single = {1};
            bins few = {[2:5]};
            bins many = {[6:20]};
        }
        
        // 任务间隔
        cp_task_interval: coverpoint task_interval_cycles {
            bins immediate = {0};
            bins short = {[1:10]};
            bins long = {[11:100]};
        }
    endgroup

    // 覆盖组：异常场景覆盖
    covergroup cg_exception;
        option.per_instance = 1;
        option.name = "exception_coverage";
        
        // 溢出场景
        cp_overflow: coverpoint overflow_detected {
            bins no_overflow = {0};
            bins overflow = {1};
        }
        
        // 非法配置
        cp_illegal_config: coverpoint illegal_config_type {
            bins none = {0};
            bins wrong_order = {1};           // 配置顺序错误
            bins out_of_range = {2};          // 参数超范围
            bins zero_dimension = {3};        // K或M或N为0
            bins invalid_combination = {4};   // 无效组合
        }
        
        // 复位场景
        cp_reset_timing: coverpoint reset_during_operation {
            bins no_reset = {0};
            bins reset_before_start = {1};
            bins reset_during_calc = {2};
            bins reset_after_done = {3};
        }
    endgroup

    function new(string name = "ai_nice_coverage", uvm_component parent = null); // FIX: 默认名字修正
        super.new(name, parent);
        cg_matrix_dimension = new();
        cg_quantization_config = new();
        cg_activation_function = new();
        cg_data_width = new();
        cg_parameter_cross = new();
        cg_interface_timing = new();
        cg_scenario = new();
        cg_exception = new();
    endfunction

    function void write(ai_nice_seq_item t); // FIX: 参数类型修正为 ai_nice_seq_item
        // 更新覆盖率变量
        m_rows = t.matrix_m;      // FIX: Name mapping
        n_cols = t.matrix_n;      // FIX: Name mapping
        k_inner = t.matrix_k;     // FIX: Name mapping
        per_ch = t.per_ch;
        quant_shift = t.quant_shift;
        quant_mult = t.quant_multiplier; // FIX: Name mapping
        lhs_offset = t.lhs_offset;
        rhs_offset = t.rhs_offset;
        dst_offset = t.dst_offset;
        act_min = t.act_min;
        act_max = t.act_max;
        a_width = t.a_w;          // FIX: Name mapping
        b_width = t.b_w;          // FIX: Name mapping
        bias_width = t.bias_w;    // FIX: Name mapping
        out_width = t.out_w;      // FIX: Name mapping
        
        // Update analysis fields
        latency_cycles = t.latency_cycles;
        throughput_ops_per_cycle = t.throughput_ops_per_cycle;
        overflow_detected = t.overflow_detected;
        saturation_occurred = t.saturation_occurred;
        illegal_config_type = t.illegal_config_type;
        reset_during_operation = t.reset_during_operation;
        extreme_value_test = t.extreme_value_test;
        csr_access_type = t.csr_access_type;
        icb_ready_delay = t.icb_ready_delay;
        icb_cmd_type = t.icb_cmd_type;
        bus_arbitration = t.bus_arbitration; // Renamed
        consecutive_task_count = t.consecutive_task_count;
        task_interval_cycles = t.task_interval_cycles;
        csr_mma_order = t.csr_mma_order;

        // 采样覆盖率
        cg_matrix_dimension.sample();
        cg_quantization_config.sample();
        cg_activation_function.sample();
        cg_data_width.sample();
        cg_parameter_cross.sample();
        cg_interface_timing.sample();
        cg_scenario.sample();
        cg_exception.sample();
    endfunction

endclass

`endif // AI_NICE_COVERAGE_SV




