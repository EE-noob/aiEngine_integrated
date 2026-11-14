set project_dir "/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2"
set project_file [file join $project_dir VU3P_oled.xpr]
set bd_file [file join $project_dir VU3P_oled.srcs sources_1 bd bit_soc bit_soc.bd]
set_param general.maxThreads 4
if {[llength $argv] > 1} {
    error "Usage: vivado -mode batch -source implement_sensor_bram_latency.tcl ?<model-coe>?"
}
set model_coe ""
if {[llength $argv] == 1} {
    set model_coe [file normalize [lindex $argv 0]]
    if {![file exists $model_coe]} {
        error "Model COE does not exist: $model_coe"
    }
}

open_project $project_file
set_property ip_repo_paths [list [file join $project_dir ip_repo]] [current_project]
update_ip_catalog
open_bd_design [get_files $bd_file]

set model_bram [get_ips -quiet sensor_model_bram]
set cpu_ctrl [get_bd_cells -quiet cpu_shared_bram_ctrl_0]
if {$model_bram eq "" || $cpu_ctrl eq ""} {
    error "Model BRAM or CPU AXI BRAM Controller is missing"
}
set primitive_latency [get_property CONFIG.C_READ_LATENCY_A $model_bram]
set core_output_reg [get_property CONFIG.C_HAS_MUX_OUTPUT_REGS_A $model_bram]
set effective_latency [expr {$primitive_latency + $core_output_reg}]
set controller_latency [get_property CONFIG.READ_LATENCY $cpu_ctrl]
if {$effective_latency != 2 || $controller_latency != 2} {
    error "Read latency mismatch: BMG=$effective_latency AXI=$controller_latency"
}
if {$model_coe ne ""} {
    set_property -dict [list \
        CONFIG.Write_Depth_A {471040} \
        CONFIG.Load_Init_File {true} \
        CONFIG.Coe_File $model_coe \
        CONFIG.Fill_Remaining_Memory_Locations {true}] $model_bram
    set model_tail_file [file normalize [file join $project_dir uram_init model_tail.mem]]
    if {![file exists $model_tail_file]} {
        error "Initialized model URAM tail does not exist: $model_tail_file"
    }
    if {[get_files -quiet $model_tail_file] eq ""} {
        add_files -norecurse $model_tail_file
    }
    puts "Configured model: BMG=1884160 bytes COE=$model_coe URAM tail=$model_tail_file"
}

generate_target all -force $model_bram
generate_target all -force [get_files $bd_file]
validate_bd_design
save_bd_design
update_compile_order -fileset sources_1

# These module-reference OOC runs were interrupted during the previous
# implementation attempt. Reset them explicitly so Vivado regenerates their
# run scripts before launching the top-level synthesis.
foreach run_name {bit_soc_dsa_npu_0_0_synth_1 bit_soc_inferred_shared_ram_0_1_synth_1} {
    set run_obj [get_runs -quiet $run_name]
    if {$run_obj ne ""} {
        reset_run $run_obj
    }
}
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS=$synth_status"
if {![string match "*Complete*" $synth_status]} {
    error "Synthesis did not complete: $synth_status"
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "IMPL_STATUS=$impl_status"
if {![string match "*Complete*" $impl_status]} {
    error "Implementation did not complete: $impl_status"
}

foreach artifact [glob -nocomplain \
        [file join $project_dir VU3P_oled.runs impl_1 bit_soc_wrapper.bit] \
        [file join $project_dir VU3P_oled.runs impl_1 bit_soc_wrapper.mmi]] {
    puts "ARTIFACT=$artifact"
}
