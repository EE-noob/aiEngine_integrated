set project_dir /home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2
set project_file [file join $project_dir VU3P_oled.xpr]
set bd_file [file join $project_dir VU3P_oled.srcs sources_1 bd bit_soc bit_soc.bd]
set output_xsa /home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_hw_v2/hw/sensor_hw_v2_model_window_fixed.xsa
set_param general.maxThreads 2

open_project $project_file
set_property ip_repo_paths [list [file join $project_dir ip_repo]] [current_project]
update_ip_catalog -rebuild

foreach ip_name {bit_soc_axi_key_0_0 bit_soc_bak_axi_key_0_0} {
    set key_ip [get_ips -quiet $ip_name]
    if {$key_ip ne ""} {
        upgrade_ip $key_ip
    }
}

open_bd_design [get_files $bd_file]
validate_bd_design
generate_target all -force [get_files $bd_file]
save_bd_design
update_compile_order -fileset sources_1

foreach run_name {impl_1 synth_1} {
    if {[get_runs -quiet $run_name] ne ""} {
        reset_run $run_name
    }
}
launch_runs synth_1 -jobs 2
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "KEY_FIX_SYNTH_STATUS=$synth_status"
if {![string match "*Complete*" $synth_status]} {
    error "Synthesis did not complete: $synth_status"
}

launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "KEY_FIX_IMPL_STATUS=$impl_status"
if {![string match "*Complete*" $impl_status]} {
    error "Implementation did not complete: $impl_status"
}

file mkdir [file dirname $output_xsa]
write_hw_platform -fixed -include_bit -force -file $output_xsa
puts "KEY_FIX_XSA=$output_xsa"
close_project
