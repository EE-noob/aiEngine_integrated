# Align initialized model BRAM read latency with the AXI BRAM Controller.
# The CPU controller is configured for READ_LATENCY=2 in bit_soc.bd.

set project_dir "/home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2"
set project_file [file join $project_dir VU3P_oled.xpr]
set bd_file [file join $project_dir VU3P_oled.srcs sources_1 bd bit_soc bit_soc.bd]

set_param general.maxThreads 4
open_project $project_file
set_property ip_repo_paths [list [file join $project_dir ip_repo]] [current_project]
update_ip_catalog

set model_bram [get_ips -quiet sensor_model_bram]
if {$model_bram eq ""} {
    error "sensor_model_bram IP was not found"
}
set_property -dict [list \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortA_Output_of_Memory_Core {true} \
    CONFIG.Register_PortB_Output_of_Memory_Core {true}] $model_bram
generate_target all -force $model_bram

set primitive_latency [get_property CONFIG.C_READ_LATENCY_A $model_bram]
set core_output_reg [get_property CONFIG.C_HAS_MUX_OUTPUT_REGS_A $model_bram]
set effective_latency [expr {$primitive_latency + $core_output_reg}]
if {$effective_latency != 2} {
    error "Expected two-cycle BMG output path, got $primitive_latency + $core_output_reg"
}

open_bd_design [get_files $bd_file]
set cpu_ctrl [get_bd_cells -quiet cpu_shared_bram_ctrl_0]
if {$cpu_ctrl eq ""} {
    error "cpu_shared_bram_ctrl_0 was not found in bit_soc"
}
set_property CONFIG.READ_LATENCY {2} $cpu_ctrl
validate_bd_design
save_bd_design
update_compile_order -fileset sources_1

puts "MODEL_BRAM_PRIMITIVE_LATENCY=$primitive_latency"
puts "MODEL_BRAM_CORE_OUTPUT_REG=[get_property CONFIG.Register_PortA_Output_of_Memory_Core $model_bram]"
puts "MODEL_BRAM_EFFECTIVE_LATENCY=$effective_latency"
puts "CPU_AXI_BRAM_READ_LATENCY=[get_property CONFIG.READ_LATENCY $cpu_ctrl]"
