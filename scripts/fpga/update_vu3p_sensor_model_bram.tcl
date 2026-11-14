if {$argc != 2} {
    error "usage: vivado -mode batch -source update_vu3p_sensor_model_bram.tcl -tclargs <project.xpr> <model.coe>"
}
set project_file [file normalize [lindex $argv 0]]
set coe_file [file normalize [lindex $argv 1]]
open_project $project_file
set model_ip [get_ips -quiet sensor_model_bram]
if {[llength $model_ip] != 1} {
    error "Expected exactly one sensor_model_bram IP, found [llength $model_ip]"
}
set_property -dict [list \
    CONFIG.Load_Init_File {true} \
    CONFIG.Coe_File $coe_file \
    CONFIG.Fill_Remaining_Memory_Locations {true}] $model_ip
generate_target all $model_ip
export_ip_user_files -of_objects $model_ip -no_script -sync -force -quiet
puts "Updated sensor_model_bram initialization: $coe_file"
close_project
