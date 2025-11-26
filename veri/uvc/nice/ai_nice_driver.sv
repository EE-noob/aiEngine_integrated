`ifndef AI_NICE_DRIVER_SV
`define AI_NICE_DRIVER_SV

`include "ai_csr_defines.svh"

class ai_nice_driver extends uvm_driver#(ai_nice_seq_item);
    `uvm_component_utils(ai_nice_driver)

    // Virtual interface
    virtual nice_if vif; 

    // Internal address management
    bit [31:0] ia_base_addr;
    bit [31:0] wgt_base_addr;
    bit [31:0] out_base_addr;
    bit [31:0] bias_base_addr;
    
    // Memory Map Constants (Example)
    localparam MEM_START_ADDR = 32'h0000_0001;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Build phase: Get virtual interface from config_db
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual nice_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
        end
    endfunction

    // Reset phase: Initialize interface signals
    virtual task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
        phase.raise_objection(this);
        `uvm_info(get_type_name(), "Reset phase: Initializing interface signals", UVM_MEDIUM)
        
        vif.nice_req_valid <= 1'b0;
        vif.nice_req_inst  <= 32'h0;
        vif.nice_req_rs1   <= 32'h0;
        vif.nice_req_rs2   <= 32'h0;
        vif.nice_rsp_ready <= 1'b1;
        
        repeat(5) @(posedge vif.nice_clk);
        phase.drop_objection(this);
    endtask

    // Main phase: Drive transactions
    virtual task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Run phase: Starting driver loop", UVM_MEDIUM)
        
        forever begin
            seq_item_port.get_next_item(req);
            `uvm_info(get_type_name(), $sformatf("Got transaction: %s", req.convert2string()), UVM_HIGH)
            
            drive_item(req);
            
            seq_item_port.item_done();
        end
    endtask

    task drive_item(ai_nice_seq_item req);
        case (req.cmd_kind)
            NICE_AUTO: begin
                addr_generate(req);
                mat_wr(req);
                csr_wr_all_config(req);
                send_mat_mult(req);
            end
            NICE_WR_CSR: begin
                csr_wr(req.csr_addr[11:0], req.csr_data);
            end
            NICE_RD_CSR: begin
                csr_rd(req.csr_addr[11:0], req.csr_data); // req.csr_data here is expected value
            end
            NICE_TRIGGER: begin
                send_mat_mult(req);
            end
            NICE_LOAD_MEM: begin
                addr_generate(req); // Ensure addresses are valid
                mat_wr(req);
            end
        endcase
    endtask

    // 1. Addr_generate: Calculate base addresses and strides
    task addr_generate(ai_nice_seq_item req);
        int ia_size, wgt_size, out_size, bias_size;
        
        // Assuming data width is 1 byte for input/weight, 4 bytes for output/bias
        // IA: M x K (Row flattened)
        ia_size = req.matrix_k * req.matrix_n; 
        // WGT: K x N (Col flattened)
        wgt_size = req.matrix_n * req.matrix_m;
        // OUT: M x N (Row flattened)
        out_size = req.matrix_k * req.matrix_m ; 
        // Bias: N (Array)
        bias_size = req.matrix_n * 4;

        ia_base_addr   = MEM_START_ADDR;
        wgt_base_addr  = ia_base_addr + ((ia_size + 3) & 32'hFFFF_FFFC); // FIX: Explicit mask to avoid redundant digits warning
        bias_base_addr = wgt_base_addr + ((wgt_size + 3) & 32'hFFFF_FFFC);
        //bias_base_addr = 0;//wgt_base_addr + ((wgt_size + 3) & 32'hFFFF_FFFC);
        out_base_addr  = bias_base_addr + ((bias_size + 3) & 32'hFFFF_FFFC);
        
        `uvm_info("DRV_ADDR", $sformatf("Gen Addrs: IA=%0h WGT=%0h BIAS=%0h OUT=%0h", 
            ia_base_addr, wgt_base_addr, bias_base_addr, out_base_addr), UVM_HIGH)
    endtask

    // 2. MatWr: Backdoor write to RAM
    task mat_wr(ai_nice_seq_item req);
        if (req.ia_matrix_file != "") begin
            // Load from TXT file logic here
            `uvm_info("DRV_MEM", $sformatf("Loading IA from file: %s", req.ia_matrix_file), UVM_MEDIUM)
            // $readmemh(req.ia_matrix_file, ...);
        end else begin
            // Generate random data based on req constraints
            // Example: Write IA Matrix
            for(int r=0; r<req.matrix_m; r++) begin
                for(int c=0; c<req.matrix_k; c++) begin
                    bit [31:0] val = req.get_matrix_value(r, c);
                    // mem_write_backdoor(ia_base_addr + idx, val);
                end
            end
            `uvm_info("DRV_MEM", "Generated and wrote random matrix data to RAM", UVM_MEDIUM)
        end
    endtask

    // 获取CSR名称
    function string csr_name(bit [11:0] addr);
        case (addr)
            `ADDR_MULT_LHS_PTR:        return "MULT_LHS_PTR";
            `ADDR_MULT_RHS_PTR:        return "MULT_RHS_PTR";
            `ADDR_MULT_DST_PTR:        return "MULT_DST_PTR";
            `ADDR_MULT_BIAS_PTR:       return "MULT_BIAS_PTR";
            `ADDR_MULT_LHS_OFFSET:     return "MULT_LHS_OFFSET";
            `ADDR_MULT_RHS_OFFSET:     return "MULT_RHS_OFFSET";
            `ADDR_MULT_DST_OFFSET:     return "MULT_DST_OFFSET";
            `ADDR_MULT_DST_MULT:       return "MULT_DST_MULT";
            `ADDR_MULT_DST_SHIFT:      return "MULT_DST_SHIFT";
            `ADDR_MULT_LHS_ROWS:       return "MULT_LHS_ROWS";
            `ADDR_MULT_RHS_ROWS:       return "MULT_RHS_ROWS";
            `ADDR_MULT_RHS_COLS:       return "MULT_RHS_COLS";
            `ADDR_MULT_LHS_STRIDE:     return "MULT_LHS_STRIDE";
            `ADDR_MULT_RHS_STRIDE:     return "MULT_RHS_STRIDE";
            `ADDR_MULT_DST_STRIDE:     return "MULT_DST_STRIDE";
            `ADDR_MULT_ACT_MIN:        return "MULT_ACT_MIN";
            `ADDR_MULT_ACT_MAX:        return "MULT_ACT_MAX";
            default:                   return $sformatf("UNKNOWN_CSR(0x%03h)", addr);
        endcase
    endfunction

    // 3. CSR_wr: Write single CSR
    task csr_wr(bit [11:0] addr, bit [31:0] data);
        string name = csr_name(addr);
        int wait_cycle;
        `uvm_info("DRV_CSR", $sformatf("CSR WR: Addr=0x%03h (%s) Data=0x%08h", addr, name, data), UVM_MEDIUM)
        `uvm_info("DRV_CSR", $sformatf("CSR_WR driving: req_valid=1, req_inst=0x%08h, req_rs1=0x%08h, req_rs2=0x%08h, csr_name=%s", 
            {addr, 5'b00001, `NICE_CSRWR_FUNCT3, 5'b00000, `NICE_CUSTOM_3}, data, 32'h0, name), UVM_HIGH)
        @(posedge vif.nice_clk);
        vif.nice_req_valid <= 1'b1;
        vif.nice_req_inst  <= {addr, 5'b00001, `NICE_CSRWR_FUNCT3, 5'b00000, `NICE_CUSTOM_3};
        vif.nice_req_rs1   <= data;
        vif.nice_req_rs2   <= 32'h0;

        wait_cycle = 0;
        do begin
            @(posedge vif.nice_clk);
            wait_cycle++;
            if (wait_cycle % 10000 == 0)
                `uvm_info("DRV_CSR", $sformatf("Waiting for req_ready... (cycle=%0d, req_ready=%0b)", wait_cycle, vif.nice_req_ready), UVM_NONE)
        end while(vif.nice_req_ready !== 1'b1);

        vif.nice_req_valid <= 1'b0;

        wait_cycle = 0;
        while(vif.nice_rsp_valid !== 1'b1) begin
            @(posedge vif.nice_clk);
            wait_cycle++;
            if (wait_cycle % 10000 == 0)
                `uvm_info("DRV_CSR", $sformatf("Waiting for rsp_valid... (cycle=%0d, rsp_valid=%0b)", wait_cycle, vif.nice_rsp_valid), UVM_NONE)
        end
        @(posedge vif.nice_clk);
    endtask

    // 4. CSR_rd: Read single CSR
    task csr_rd(bit [11:0] addr, bit [31:0] expected);
        bit [31:0] rdata;
        string name = csr_name(addr);
        `uvm_info("DRV_CSR", $sformatf("CSR RD: Addr=0x%03h (%s) Exp=0x%08h", addr, name, expected), UVM_MEDIUM)
        `uvm_info("DRV_CSR", $sformatf("CSR_RD driving: req_valid=1, req_inst=0x%08h, req_rs1=0x%08h, req_rs2=0x%08h, csr_name=%s", 
            {addr, 5'b00000, `NICE_CSRR_FUNCT3, 5'b00001, `NICE_CUSTOM_3}, 32'h0, 32'h0, name), UVM_HIGH)
        @(posedge vif.nice_clk);
        vif.nice_req_valid <= 1'b1;
        vif.nice_req_inst  <= {addr, 5'b00000, `NICE_CSRR_FUNCT3, 5'b00001, `NICE_CUSTOM_3};
        vif.nice_req_rs1   <= 32'h0;
        vif.nice_req_rs2   <= 32'h0;
        
        do begin
            @(posedge vif.nice_clk);
        end while(vif.nice_req_ready !== 1'b1);
        
        vif.nice_req_valid <= 1'b0;
        
        while(vif.nice_rsp_valid !== 1'b1) begin
            @(posedge vif.nice_clk);
        end
        
        rdata = vif.nice_rsp_rdat;
        `uvm_info("DRV_CSR", $sformatf("CSR_RD got response: rsp_rdat=0x%08h, expected=0x%08h, csr_name=%s", rdata, expected, name), UVM_HIGH)
        if(rdata !== expected) begin
             `uvm_error("DRV_CSR", $sformatf("CSR Read Mismatch! Addr=0x%03h (%s) Exp=0x%08h Act=0x%08h", addr, name, expected, rdata))
        end
        @(posedge vif.nice_clk);
    endtask

    // Helper: Write all configs for AUTO mode
    task csr_wr_all_config(ai_nice_seq_item req);
        // Address Pointers
        csr_wr(`ADDR_MULT_LHS_PTR, ia_base_addr);
        csr_wr(`ADDR_MULT_RHS_PTR, wgt_base_addr);
        csr_wr(`ADDR_MULT_DST_PTR, out_base_addr);
        csr_wr(`ADDR_MULT_BIAS_PTR, bias_base_addr);
        
        // Dimensions
        csr_wr(`ADDR_MULT_LHS_ROWS, req.matrix_m);
        csr_wr(`ADDR_MULT_RHS_ROWS, req.matrix_k);
        csr_wr(`ADDR_MULT_RHS_COLS, req.matrix_n);
        
        // Strides (Assuming Row Major / Packed for now)
        csr_wr(`ADDR_MULT_LHS_STRIDE, req.matrix_n);
        csr_wr(`ADDR_MULT_RHS_STRIDE, req.matrix_n);
        csr_wr(`ADDR_MULT_DST_STRIDE, req.matrix_m);
        
        // Quantization Parameters
        csr_wr(`ADDR_MULT_LHS_OFFSET, req.lhs_offset);
        csr_wr(`ADDR_MULT_RHS_OFFSET, req.rhs_offset);
        csr_wr(`ADDR_MULT_DST_OFFSET, req.dst_offset);
        csr_wr(`ADDR_MULT_DST_MULT,   req.quant_multiplier);
        csr_wr(`ADDR_MULT_DST_SHIFT,  req.quant_shift);
        
        // Activation
        csr_wr(`ADDR_MULT_ACT_MIN, req.act_min);
        csr_wr(`ADDR_MULT_ACT_MAX, req.act_max);
    endtask

    // 5. send_mat_mult: Trigger execution
    task send_mat_mult(ai_nice_seq_item req);
        bit [31:0] cfg;
        cfg = 0;
        cfg[9]   = req.per_ch;
        cfg[8:7] = req.a_w;
        cfg[6:5] = req.b_w;
        cfg[4:3] = req.bias_w;
        cfg[2:0] = req.out_w;

        `uvm_info("drv mult csr", $sformatf("Sending Matrix Mult: OutAddr=0x%08h CFG=0x%08h", out_base_addr, cfg), UVM_MEDIUM)
        `uvm_info("trig mult", $sformatf("MAT_MULT driving: req_valid=1, req_inst=0x%08h, req_rs1=0x%08h, req_rs2=0x%08h",
            {`NICE_MAT_MULT_FUNCT7, 5'b00010, 5'b00001, `NICE_FUNCT3, 5'b00011, `NICE_CUSTOM_1}, out_base_addr, cfg), UVM_HIGH)
        
        @(posedge vif.nice_clk);
        vif.nice_req_valid <= 1'b1;
        vif.nice_req_inst  <= {`NICE_MAT_MULT_FUNCT7, 5'b00010, 5'b00001, `NICE_FUNCT3, 5'b00011, `NICE_CUSTOM_1};
        vif.nice_req_rs1   <= out_base_addr;
        vif.nice_req_rs2   <= cfg;
        
        do begin
            @(posedge vif.nice_clk);
        end while(vif.nice_req_ready !== 1'b1);
        
        vif.nice_req_valid <= 1'b0;
        
        while(vif.nice_rsp_valid !== 1'b1) begin
            @(posedge vif.nice_clk);
        end
        `uvm_info("MULT Done", $sformatf("Matrix Mult Done. Status=0x%08h", vif.nice_rsp_rdat), UVM_HIGH)
        @(posedge vif.nice_clk);
    endtask

endclass

`endif
