set project_file /home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.xpr
if {$argc > 0} {
    set output_xsa [file normalize [lindex $argv 0]]
} else {
    set output_xsa /home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_hw_v2/hw/sensor_hw_v2_20261110_latest_bit.xsa
}
open_project $project_file
set_property ip_repo_paths [list /home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/ip_repo] [current_project]
update_ip_catalog -rebuild
update_compile_order -fileset sources_1

reset_run impl_1
reset_run synth_1
launch_runs synth_1 -jobs 1
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ni {"synth_design Complete!" "synth_design Complete"}} {
    error "Synthesis did not complete: [get_property STATUS [get_runs synth_1]]"
}

launch_runs impl_1 -to_step write_bitstream -jobs 1
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
if {![string match "*Complete!*" $impl_status]} {
    error "Implementation/bitstream did not complete: $impl_status"
}

file mkdir [file dirname $output_xsa]
write_hw_platform -fixed -include_bit -force -file $output_xsa
puts "Latest implemented hardware platform with bitstream: $output_xsa"
close_project
