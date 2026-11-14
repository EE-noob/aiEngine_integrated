`ifndef ics_mon_AGENT_CFG_BASE__SV
`define ics_mon_AGENT_CFG_BASE__SV
class ics_mon_agent_cfg_base extends uvm_object;
    string                      protocol;
    uvm_active_passive_enum     is_active = UVM_ACTIVE;
    bit                         rm_en   =1;
    bit                         lat_en  =0;
    bit                         cov_en  =1;
    bit                         scb_en  =1;
    bit                         bus_scb_en  =0;
    bit                         drv_timeout_check_en;
    int                         drv_timeout_ns = 10000000;
    string                      env_name;
    string                      user_str[string];
    int                         user_var[string];
    int                         addr_width  =0;
    int                         addr_lsb    =0;
    int                         addr_msb    =32;
    bit                         compsate_en =1;
    bit[63:0]                   compsate_addr;
    bit                         resp_check_en=1;
    bit                         force_rdata_en=1;

    `uvm_object_utils_begin(ics_mon_agent_cfg_base)
    `uvm_object_utils_end

    function new(string name="ics_mon_agent_cfg_base");
        super.new(name);
    endfunction

    //extern virtual function string  get(string key);
    //extern virtual function void    add(string key, string item);

endclass: ics_mon_agent_cfg_base

`endif
