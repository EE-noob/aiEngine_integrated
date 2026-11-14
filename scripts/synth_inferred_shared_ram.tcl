if {[llength $argv] != 2} {
    error "Expected <rtl-file> <report-dir>"
}
set rtl_file [file normalize [lindex $argv 0]]
set report_dir [file normalize [lindex $argv 1]]
file mkdir $report_dir
set_param general.maxThreads 4
read_verilog $rtl_file
synth_design -top axi_inferred_shared_ram -part xcvu3p-ffvc1517-2-i -mode out_of_context
report_utilization -file [file join $report_dir utilization.rpt]
write_checkpoint -force [file join $report_dir shared_ram_ooc.dcp]
