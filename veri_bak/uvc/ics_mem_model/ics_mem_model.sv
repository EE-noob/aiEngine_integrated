`ifndef ics_MEM_MODEL_SV
`define ics_MEM_MODEL_SV

class ics_mem_model extends uvm_component;
   `uvm_component_utils(ics_mem_model)

   virtual ics_if vif;
   bit [127:0] mem[int];  // 用 int（十进制）作为地址，数据为最大128位

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual ics_if)::get(this, "", "ics_vif", vif)) begin
         `uvm_fatal("MEM", "Cannot get vif from config DB");
      end
      load_data_file(`ICS_INPUT_DATA);
   endfunction

function void load_data_file(string filename);
   int fd;
   string line;
   string addr_str, data_str;
   bit [127:0] data;
   int addr;
   int n;

   fd = $fopen(filename, "r");
   if (!fd) `uvm_fatal("FILE", $sformatf("Failed to open %s", filename));

   while (!$feof(fd)) begin
      line = "";
      void'($fgets(line, fd));
      if ($sscanf(line, "%d %s", addr, data_str) == 2) begin
         n = $sscanf(data_str, "%h", data);
         if (n != 1) begin
            `uvm_warning("FILE", $sformatf("Failed to parse data %s", data_str));
            data = '0;
         end
         mem[addr] = data;
      end
   end
   $fclose(fd);
endfunction

   task run_phase(uvm_phase phase);
      bit [127:0] data;
      phase.raise_objection(this);
      forever begin
         @(vif.drv_cb iff(vif.mon_cb.ics_rd_en | vif.mon_cb.ics_out_eof));

         if (vif.mon_cb.ics_out_eof == 1'b1) begin
            `uvm_info(get_type_name(), "ics_out_eof detected, exiting loop.", UVM_MEDIUM);
            break;
         end

         if (mem.exists(vif.mon_cb.ics_rd_addr)) begin
            data = mem[vif.mon_cb.ics_rd_addr];
         end else begin
            `uvm_info("MEM", $sformatf("Address %0d not found. Returning 0.", vif.mon_cb.ics_rd_addr), UVM_MEDIUM);
            data = '0;
         end

         vif.drv_cb.ics_rd_data <= data;
      end


      `uvm_info(get_full_name(), "Drop objection", UVM_LOW);
      phase.drop_objection(this);
   endtask
endclass

`endif