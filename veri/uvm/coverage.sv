`ifndef COVERAGE_SV
`define COVERAGE_SV

class coverage extends uvm_subscriber #(nice_transaction);
    `uvm_component_utils(coverage)

    // 覆盖组：矩阵维度覆盖
    covergroup cg_matrix_dimension;
        option.per_instance = 1;
        option.name = "matrix_dimension_coverage";
        
        // M维度覆盖点
        cp_m_rows: coverpoint m_rows {
            bins small = {[1:128]};           // 小规模
            bins medium = {[129:2048]};       // 中等规模
            bins large = {[2049:4096]};       // 大规模
            bins boundary_min = {1};          // 最小边界
            bins boundary_64 = {64};          // 调试值
            bins boundary_1024 = {1024};      // 典型边界
            bins boundary_max = {[4097:65535]}; // 最大边界
        }
        
        // N维度覆盖点
        cp_n_cols: coverpoint n_cols {
            bins small = {[1:128]};
            bins medium = {[129:2048]};
            bins large = {[2049:4096]};
            bins boundary_min = {1};
            bins boundary_48 = {48};          // 调试值
            bins boundary_2048 = {2048};
            bins boundary_max = {[4097:65535]};
        }
        
        // K维度覆盖点
        cp_k_inner: coverpoint k_inner {
            bins zero = {0};                  // K=0边界
            bins one = {1};                   // K=1边界
            bins small = {[2:128]};
            bins medium = {[129:2048]};
            bins boundary_64 = {64};
            bins boundary_max = {[2049:65535]};
        }
        
        // 矩阵规模交叉覆盖
        cross_matrix_size: cross cp_m_rows, cp_n_cols, cp_k_inner {
            bins debug_case = binsof(cp_m_rows.boundary_64) && 
                             binsof(cp_n_cols.boundary_48) && 
                             binsof(cp_k_inner.boundary_64);
            bins typical_medium = binsof(cp_m_rows.medium) && 
                                 binsof(cp_n_cols.medium) && 
                                 binsof(cp_k_inner.boundary_64);
            bins vector_mult = (binsof(cp_m_rows.boundary_min) || 
                               binsof(cp_n_cols.boundary_min)) && 
                              binsof(cp_k_inner);
            bins max_scenario = binsof(cp_m_rows.boundary_1024) && 
                               binsof(cp_n_cols.boundary_max) && 
                               binsof(cp_k_inner.boundary_max);
        }
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
            bins small = {[1:8]};             // 小移位
            bins medium = {[9:16]};           // 中等量化
            bins large = {[17:31]};           // 最大量化
        }
        
        // 量化乘数
        cp_quant_mult: coverpoint quant_mult {
            bins zero = {0};
            bins small = {[1:256]};
            bins medium = {[257:65535]};
            bins large = {[65536:$]};
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
            bins small = {[1:128]};
            bins medium = {[129:2048]};
            bins large = {[2049:65535]};
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
            ignore_bins illegal = binsof(cp_matrix_scale.large) && 
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
        
        // 总线利用率
        cp_bus_utilization: coverpoint bus_utilization {
            bins low = {[0:33]};
            bins medium = {[34:66]};
            bins high = {[67:100]};
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
        
        // CSR与MMA操作顺序
        cp_csr_mma_order: coverpoint csr_mma_order {
            bins normal = {0};                // 先CSR后MMA
            bins abnormal = {1};              // 先MMA后CSR
            bins interleaved = {2};           // 交错
        }
    endgroup

    // 覆盖组：性能覆盖
    covergroup cg_performance;
        option.per_instance = 1;
        option.name = "performance_coverage";
        
        cp_latency_cycles: coverpoint latency_cycles {
            bins fast = {[0:1000]};
            bins normal = {[1001:10000]};
            bins slow = {[10001:100000]};
            bins very_slow = {[100001:$]};
        }
        
        cp_throughput: coverpoint throughput_ops_per_cycle {
            bins low = {[0:10]};
            bins medium = {[11:100]};
            bins high = {[101:1000]};
            bins very_high = {[1001:$]};
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
        
        cp_saturation: coverpoint saturation_occurred {
            bins no_saturation = {0};
            bins saturation = {1};
        }
        
        // 非法配置
        cp_illegal_config: coverpoint illegal_config_type {
            bins none = {0};
            bins wrong_order = {1};           // 配置顺序错误
            bins out_of_range = {2};          // 参数超范围
            bins zero_dimension = {3};        // M或N为0
            bins invalid_combination = {4};   // 无效组合
        }
        
        // 复位场景
        cp_reset_timing: coverpoint reset_during_operation {
            bins no_reset = {0};
            bins reset_before_start = {1};
            bins reset_during_calc = {2};
            bins reset_after_done = {3};
        }
        
        // 极端值测试
        cp_extreme_values: coverpoint extreme_value_test {
            bins normal_range = {0};
            bins max_positive = {1};          // 0x7F/0xFF
            bins max_negative = {2};          // 0x80/0x00
            bins mixed_extreme = {3};
        }
    endgroup

    // 成员变量
    int m_rows, n_cols, k_inner;
    bit per_ch;
    int quant_shift, quant_mult;
    int lhs_offset, rhs_offset, dst_offset;
    int act_min, act_max;
    bit [1:0] a_width, b_width, bias_width;
    bit [2:0] out_width;
    int csr_access_type;
    int icb_ready_delay, icb_cmd_type;
    int bus_utilization;
    int consecutive_task_count, task_interval_cycles;
    int csr_mma_order;
    int latency_cycles;
    real throughput_ops_per_cycle;
    bit overflow_detected, saturation_occurred;
    int illegal_config_type;
    int reset_during_operation;
    int extreme_value_test;

    function new(string name = "coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_matrix_dimension = new();
        cg_quantization_config = new();
        cg_activation_function = new();
        cg_data_width = new();
        cg_parameter_cross = new();
        cg_interface_timing = new();
        cg_scenario = new();
        cg_performance = new();
        cg_exception = new();
    endfunction

    function void write(nice_transaction t);
        // 更新覆盖率变量
        m_rows = t.m_rows;
        n_cols = t.n_cols;
        k_inner = t.k_inner;
        per_ch = t.per_ch;
        quant_shift = t.quant_shift;
        quant_mult = t.quant_mult;
        lhs_offset = t.lhs_offset;
        rhs_offset = t.rhs_offset;
        dst_offset = t.dst_offset;
        act_min = t.act_min;
        act_max = t.act_max;
        a_width = t.a_width;
        b_width = t.b_width;
        bias_width = t.bias_width;
        out_width = t.out_width;
        
        // 采样覆盖率
        cg_matrix_dimension.sample();
        cg_quantization_config.sample();
        cg_activation_function.sample();
        cg_data_width.sample();
        cg_parameter_cross.sample();
        cg_interface_timing.sample();
        cg_scenario.sample();
        cg_performance.sample();
        cg_exception.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Matrix Dimension Coverage: %.2f%%", 
            cg_matrix_dimension.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Quantization Config Coverage: %.2f%%", 
            cg_quantization_config.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Activation Function Coverage: %.2f%%", 
            cg_activation_function.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Data Width Coverage: %.2f%%", 
            cg_data_width.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Parameter Cross Coverage: %.2f%%", 
            cg_parameter_cross.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Interface Timing Coverage: %.2f%%", 
            cg_interface_timing.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Scenario Coverage: %.2f%%", 
            cg_scenario.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Performance Coverage: %.2f%%", 
            cg_performance.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Exception Coverage: %.2f%%", 
            cg_exception.get_coverage()), UVM_LOW)
    endfunction

endclass

`endif // COVERAGE_SV
