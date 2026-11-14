if {[llength $argv] != 2} {
    error "Usage: vivado -mode batch -source export_sensor_hw_platform.tcl -tclargs <project.xpr> <output.xsa>"
}
set project_file [file normalize [lindex $argv 0]]
set output_xsa [file normalize [lindex $argv 1]]
open_project $project_file
open_run impl_1
write_hw_platform -fixed -include_bit -force -file $output_xsa
puts "EXPORTED_XSA=$output_xsa"
close_project
