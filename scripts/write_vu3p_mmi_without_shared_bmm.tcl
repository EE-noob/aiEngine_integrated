if {[llength $argv] != 2} {
    error "Usage: vivado -mode batch -source write_vu3p_mmi_without_shared_bmm.tcl -tclargs <routed.dcp> <output.mmi>"
}
open_checkpoint [file normalize [lindex $argv 0]]
set shared_ctrl [get_cells -quiet bit_soc_i/cpu_shared_bram_ctrl_0]
if {[llength $shared_ctrl] != 1} {
    error "CPU shared BRAM controller not found in routed checkpoint"
}
reset_property BMM_INFO_ADDRESS_SPACE $shared_ctrl
write_mem_info -force -no_partial_mmi [file normalize [lindex $argv 1]]
close_design
