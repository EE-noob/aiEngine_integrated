`ifndef AI_NICE_TR_SV
`define AI_NICE_TR_SV

// Define command types for driver interaction
typedef enum bit [2:0] {
    NICE_AUTO      = 0, // Auto: Calc Addr -> Load Mem -> Config CSR -> Trigger
    NICE_WR_CSR    = 1, // Single CSR Write
    NICE_RD_CSR    = 2, // Single CSR Read
    NICE_TRIGGER   = 3, // Just trigger the engine
    NICE_LOAD_MEM  = 4  // Just load memory
} nice_cmd_t;

class ai_nice_seq_item extends uvm_sequence_item;
    // Low level fields
    rand bit [15:0]  matrix_k; // Increased width from [5:0] to [15:0]
    rand bit [15:0]  matrix_n; // Increased width from [5:0] to [15:0]
    rand bit [15:0]  matrix_m; // Increased width from [5:0] to [15:0]
    rand bit        random_matrix_data;

    // Configuration bits
    rand bit        per_ch;
    rand bit [1:0]  a_w;
    rand bit [1:0]  b_w;
    rand bit [1:0]  bias_w;
    rand bit [2:0]  out_w;

    // Quantization & Activation
    rand bit signed [31:0] act_min;    // Widened to 32-bit
    rand bit signed [31:0] act_max;    // Widened to 32-bit
    rand bit signed [31:0] lhs_offset; // Widened to 32-bit
    rand bit signed [31:0] rhs_offset; // Widened to 32-bit
    rand bit signed [31:0] dst_offset; // Widened to 32-bit
    rand bit [31:0]        quant_multiplier;
    rand bit signed [5:0]  quant_shift;
    rand nice_cmd_t cmd_kind;

    // CSR Direct Access Fields
    rand bit [31:0] csr_addr;
    rand bit [31:0] csr_data;

    // File based loading (optional)
    string ia_matrix_file = "";
    string wgt_matrix_file = "";

    // Analysis / Coverage fields (populated by monitor)
    int latency_cycles;
    real throughput_ops_per_cycle;
    bit overflow_detected;
    bit saturation_occurred;
    int illegal_config_type;
    int reset_during_operation;
    int extreme_value_test;
    int csr_access_type;
    int icb_ready_delay;
    int icb_cmd_type;
    int bus_arbitration; // Renamed from bus_utilization
    int bus_utilization;
    int consecutive_task_count;
    int task_interval_cycles;
    int csr_mma_order;

    `uvm_object_utils_begin(ai_nice_seq_item)
        `uvm_field_enum(nice_cmd_t, cmd_kind, UVM_ALL_ON)
        `uvm_field_int(csr_addr, UVM_ALL_ON)
        `uvm_field_int(csr_data, UVM_ALL_ON)
        `uvm_field_string(ia_matrix_file, UVM_ALL_ON)
        `uvm_field_string(wgt_matrix_file, UVM_ALL_ON)
        
        // Analysis fields
        `uvm_field_int(latency_cycles, UVM_ALL_ON)
        `uvm_field_real(throughput_ops_per_cycle, UVM_ALL_ON)
        `uvm_field_int(overflow_detected, UVM_ALL_ON)
        `uvm_field_int(saturation_occurred, UVM_ALL_ON)
        `uvm_field_int(illegal_config_type, UVM_ALL_ON)
        `uvm_field_int(reset_during_operation, UVM_ALL_ON)
        `uvm_field_int(extreme_value_test, UVM_ALL_ON)
        `uvm_field_int(csr_access_type, UVM_ALL_ON)
        `uvm_field_int(icb_ready_delay, UVM_ALL_ON)
        `uvm_field_int(icb_cmd_type, UVM_ALL_ON)
        `uvm_field_int(bus_arbitration, UVM_ALL_ON) // Renamed
        `uvm_field_int(consecutive_task_count, UVM_ALL_ON)
        `uvm_field_int(task_interval_cycles, UVM_ALL_ON)
        `uvm_field_int(csr_mma_order, UVM_ALL_ON)

        `uvm_field_int(matrix_k        , UVM_ALL_ON)
        `uvm_field_int(matrix_n        , UVM_ALL_ON)
        `uvm_field_int(matrix_m        , UVM_ALL_ON)
        `uvm_field_int(random_matrix_data, UVM_ALL_ON)
        
        `uvm_field_int(per_ch          , UVM_ALL_ON)
        `uvm_field_int(a_w             , UVM_ALL_ON)
        `uvm_field_int(b_w             , UVM_ALL_ON)
        `uvm_field_int(bias_w          , UVM_ALL_ON)
        `uvm_field_int(out_w           , UVM_ALL_ON)

        `uvm_field_int(act_min         , UVM_ALL_ON)
        `uvm_field_int(act_max         , UVM_ALL_ON)
        `uvm_field_int(lhs_offset      , UVM_ALL_ON)
        `uvm_field_int(rhs_offset      , UVM_ALL_ON)
        `uvm_field_int(dst_offset      , UVM_ALL_ON)
        `uvm_field_int(quant_multiplier, UVM_ALL_ON)
        `uvm_field_int(quant_shift     , UVM_ALL_ON)
    `uvm_object_utils_end

    // // Matrix dimension coverage & weighting
    // constraint c_matrix_dims {
    //     matrix_k inside {[1:64]};
    //     matrix_n inside {[1:64]};
    //     matrix_m inside {[1:64]};
    // }
    // constraint c_matrix_weight {
    //     matrix_k dist { [1:4] := 1, [5:16] := 3, [17:64] := 2 ,[64:1024]:=3};
    //     matrix_n dist { [1:4] := 1, [5:32] := 4, [33:64] := 1 ,[64:1024]:=3};
    //     matrix_m dist { [1:8] := 2, [9:32] := 3, [33:64] := 2 ,[64:1024]:=3};
    // }
    
    constraint c_matrix_weight {
        matrix_k dist { [1:4] := 1, [5:16] := 3, [17:64] := 2 };
        matrix_n dist { [1:4] := 1, [5:32] := 4, [33:64] := 1 };
        matrix_m dist { [1:8] := 2, [9:32] := 3, [33:64] := 2 };
    }
    // Default command is AUTO for simple sequences
    constraint c_default_cmd {
        soft cmd_kind == NICE_AUTO;
    }

    // Activation & zero-point coherence
    constraint c_activation_bounds {
        //act_min inside {[-32768:-1]};
        act_min >0;
        act_max inside {[0:32767]};
        act_min < act_max;
    }
    constraint c_zero_points {
        lhs_offset     inside {[-512:512]};
        rhs_offset     inside {[-512:512]};
        dst_offset     inside {[-1024:1024]};
        lhs_offset     inside {[act_min:act_max]};
        dst_offset     inside {[act_min:act_max]};
    }

    // Quantization parameters
    constraint c_quant_params {
        quant_multiplier inside {[1:32'h0000_FFFF]};
        quant_shift      inside {[-16:16]};
        (per_ch == 0) -> (quant_multiplier <= 32'h0000_1FFF);
    }
    
    // Config constraints (defaults)
    constraint c_cfg_defaults {
        soft per_ch == 0;
        soft a_w == 1; // s8
        soft b_w == 1; // s8
        soft bias_w == 2; // s32
        soft out_w == 1; // s8
    }

    function new(string name = "ai_nice_seq_item");
        super.new(name);
    endfunction

    function bit [31:0] encode_matrix_coord(bit [15:0] row_idx, bit [15:0] col_idx);
        return {row_idx, col_idx};
    endfunction

    function bit [31:0] get_matrix_value(bit [15:0] row_idx, bit [15:0] col_idx);
        if (random_matrix_data) begin
            return $urandom();
        end
        return encode_matrix_coord(row_idx, col_idx);
    endfunction
endclass

`endif

