# Upgrade the VU3P board DSA shared memory to 10 MiB XPM URAM plus 1.875 MiB
# native BRAM Generator, implement the board, and export XSA.
# Usage:
#   vivado -mode batch -source vu3p_shared_ram_upgrade.tcl \
#     -tclargs <project-dir> <output-xsa> <model.coe>

if {[llength $argv] != 3} {
    error "Expected: <project-dir> <output-xsa> <model.coe>"
}
set project_dir [file normalize [lindex $argv 0]]
set output_xsa [file normalize [lindex $argv 1]]
set model_mem [file normalize [lindex $argv 2]]
set project_file [file join $project_dir VU3P_oled.xpr]
set bd_file [file join $project_dir VU3P_oled.srcs sources_1 bd bit_soc bit_soc.bd]
set ram_file [file join $project_dir VU3P_oled.srcs sources_1 new dsa_npu axi_inferred_shared_ram.sv]

if {![file exists $project_file] || ![file exists $bd_file] || ![file exists $ram_file] || ![file exists $model_mem]} {
    error "Project, block design, inferred RAM RTL, or model initialization file is missing"
}
set_param general.maxThreads 8
open_project $project_file
set_property ip_repo_paths [list [file join $project_dir ip_repo]] [current_project]
update_ip_catalog -rebuild

# Keep the BRAM-backed model window in one native Vivado memory IP. The
# companion RTL bank uses XPM for the 10 MiB URAM window; the two physical
# memory classes are intentionally separate IPs/regions.
set model_bram_ip [get_ips -quiet sensor_model_bram]
if {$model_bram_ip eq ""} {
    create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 \
        -module_name sensor_model_bram \
        -dir [file join $project_dir VU3P_oled.srcs sources_1 ip]
    set model_bram_ip [get_ips sensor_model_bram]
}
set_property -dict [list \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Write_Width_A {32} CONFIG.Read_Width_A {32} \
    CONFIG.Write_Depth_A {491520} \
    CONFIG.Write_Width_B {32} CONFIG.Read_Width_B {32} \
    CONFIG.Load_Init_File {true} CONFIG.Coe_File $model_mem \
    CONFIG.Fill_Remaining_Memory_Locations {true} \
    CONFIG.Use_Byte_Write_Enable {true} CONFIG.Byte_Size {8} \
    CONFIG.Enable_A {Use_ENA_Pin} CONFIG.Enable_B {Use_ENB_Pin} \
    CONFIG.Use_RSTA_Pin {true} CONFIG.Use_RSTB_Pin {true} \
    CONFIG.Reset_Type {SYNC} \
    CONFIG.READ_LATENCY_A {2} CONFIG.READ_LATENCY_B {2} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {true} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {true} \
    CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Operating_Mode_B {READ_FIRST} \
] $model_bram_ip
generate_target all $model_bram_ip

if {[get_files -quiet $ram_file] eq ""} {
    add_files -norecurse $ram_file
}
set_property file_type Verilog [get_files $ram_file]
update_compile_order -fileset sources_1

proc reconnect_bd_signal {source_pin target_pins} {
    foreach pin $target_pins {
        foreach net [get_bd_nets -quiet -of_objects $pin] {
            disconnect_bd_net $net $pin
        }
    }
    connect_bd_net $source_pin {*}$target_pins
}

open_bd_design [get_files $bd_file]
current_bd_instance .

set cpu_ctrl [get_bd_cells -quiet cpu_shared_bram_ctrl_0]
set dsa_ctrl [get_bd_cells -quiet dsa_shared_bram_ctrl_0]
set old_ram [get_bd_cells -quiet dsa_shared_bram_0]
set shared_ram [get_bd_cells -quiet inferred_shared_ram_0]
set dma_sc [get_bd_cells -quiet dsa_dma_smartconnect]
if {$cpu_ctrl eq "" || $dsa_ctrl eq "" || $dma_sc eq ""} {
    error "Expected existing DSA shared-memory controllers and DMA SmartConnect"
}
if {$shared_ram eq ""} {
    if {$old_ram eq ""} {
        error "Neither the old BMG nor the inferred shared RAM exists"
    }
    foreach endpoint [list \
        [get_bd_intf_pins cpu_shared_bram_ctrl_0/BRAM_PORTA] \
        [get_bd_intf_pins dsa_shared_bram_ctrl_0/BRAM_PORTA] \
        [get_bd_intf_pins dsa_shared_bram_0/BRAM_PORTA] \
        [get_bd_intf_pins dsa_shared_bram_0/BRAM_PORTB]] {
        set nets [get_bd_intf_nets -quiet -of_objects $endpoint]
        if {[llength $nets] == 1} {
            disconnect_bd_intf_net [lindex $nets 0] $endpoint
        }
    }
    delete_bd_objs $old_ram
    create_bd_cell -type module -reference axi_inferred_shared_ram inferred_shared_ram_0
    connect_bd_intf_net \
        [get_bd_intf_pins cpu_shared_bram_ctrl_0/BRAM_PORTA] \
        [get_bd_intf_pins inferred_shared_ram_0/BRAM_PORTA]
    connect_bd_intf_net \
        [get_bd_intf_pins dsa_shared_bram_ctrl_0/BRAM_PORTA] \
        [get_bd_intf_pins inferred_shared_ram_0/BRAM_PORTB]
}

# CPU and DSA must both access both spaces: model BRAM is read-only at runtime,
# while the TFLM arena in URAM is read/write. Route both masters through one
# 2x2 SmartConnect to the dedicated URAM and model-BRAM controllers.
set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {2}] $dma_sc
proc disconnect_bd_interface {pin_name} {
    set pin [get_bd_intf_pins -quiet $pin_name]
    if {$pin ne ""} {
        set nets [get_bd_intf_nets -quiet -of_objects $pin]
        if {[llength $nets] == 1} {
            disconnect_bd_intf_net [lindex $nets 0] $pin
        }
    }
}
foreach pin_name [list \
    microblaze_riscv_0_axi_periph/M19_AXI dsa_npu_0/M_AXI \
    dsa_dma_smartconnect/S00_AXI dsa_dma_smartconnect/S01_AXI \
    dsa_dma_smartconnect/M00_AXI dsa_dma_smartconnect/M01_AXI \
    cpu_shared_bram_ctrl_0/S_AXI dsa_shared_bram_ctrl_0/S_AXI \
    dsa_model_ram_clock_converter/S_AXI dsa_model_ram_clock_converter/M_AXI] {
    disconnect_bd_interface $pin_name
}
connect_bd_intf_net \
    [get_bd_intf_pins microblaze_riscv_0_axi_periph/M19_AXI] \
    [get_bd_intf_pins dsa_dma_smartconnect/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins dsa_npu_0/M_AXI] \
    [get_bd_intf_pins dsa_dma_smartconnect/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins dsa_dma_smartconnect/M00_AXI] \
    [get_bd_intf_pins cpu_shared_bram_ctrl_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins dsa_dma_smartconnect/M01_AXI] \
    [get_bd_intf_pins dsa_shared_bram_ctrl_0/S_AXI]
if {[get_bd_cells -quiet dsa_model_ram_clock_converter] ne ""} {
    delete_bd_objs [get_bd_cells dsa_model_ram_clock_converter]
}

set sys_clk [get_bd_pins clk_wiz_0/clk_out1]
set sys_resetn [get_bd_pins rst_clk_wiz_1/peripheral_aresetn]
set dsa_ctrl_clk_pin [get_bd_pins dsa_shared_bram_ctrl_0/s_axi_aclk]
set dsa_ctrl_clk_net [get_bd_nets -quiet -of_objects $dsa_ctrl_clk_pin]
if {[llength $dsa_ctrl_clk_net] == 1} {
    disconnect_bd_net [lindex $dsa_ctrl_clk_net 0] $dsa_ctrl_clk_pin
}
reconnect_bd_signal $sys_clk [list \
    [get_bd_pins cpu_shared_bram_ctrl_0/s_axi_aclk] \
    [get_bd_pins dsa_shared_bram_ctrl_0/s_axi_aclk] \
    [get_bd_pins dsa_npu_0/clk] \
    [get_bd_pins dsa_ctrl_clock_converter/s_axi_aclk] \
    [get_bd_pins dsa_ctrl_clock_converter/m_axi_aclk] \
    [get_bd_pins dsa_dma_smartconnect/aclk] \
    [get_bd_pins dsa_dma_smartconnect/aclk]]
reconnect_bd_signal $sys_resetn [list \
    [get_bd_pins cpu_shared_bram_ctrl_0/s_axi_aresetn] \
    [get_bd_pins dsa_shared_bram_ctrl_0/s_axi_aresetn] \
    [get_bd_pins dsa_npu_0/rst_n] \
    [get_bd_pins dsa_dma_smartconnect/aresetn] \
    [get_bd_pins dsa_ctrl_clock_converter/s_axi_aresetn] \
    [get_bd_pins dsa_ctrl_clock_converter/m_axi_aresetn] \
    [get_bd_pins dsa_dma_smartconnect/aresetn]]

# Address windows are power-of-two sized; the configured BRAM is 1.875 MiB
# inside its 2 MiB aperture. The model begins after the 10 MiB URAM arena.
set cpu_space [get_bd_addr_spaces microblaze_riscv_0/Data]
set dsa_space [get_bd_addr_spaces -of_objects [get_bd_intf_pins dsa_npu_0/M_AXI]]
set uram_seg [get_bd_addr_segs -of_objects [get_bd_intf_pins cpu_shared_bram_ctrl_0/S_AXI]]
set model_seg [get_bd_addr_segs -of_objects [get_bd_intf_pins dsa_shared_bram_ctrl_0/S_AXI]]
if {[llength $uram_seg] != 1 || [llength $model_seg] != 1 || [llength $dsa_space] != 1} {
    error "Cannot resolve CPU/DSA memory address segments"
}
# Match controller latency to the synchronous two-cycle URAM/BMG read path.
set_property CONFIG.READ_LATENCY {2} $cpu_ctrl
set_property CONFIG.READ_LATENCY {2} $dsa_ctrl
foreach target_space [list $cpu_space $dsa_space] {
    assign_bd_address -offset 0x50000000 -range 0x01000000 \
        -target_address_space $target_space $uram_seg -force
    assign_bd_address -offset 0x51000000 -range 0x00200000 \
        -target_address_space $target_space $model_seg -force
}

validate_bd_design
save_bd_design
generate_target all -force [get_files $bd_file]
set wrapper [make_wrapper -files [get_files $bd_file] -top -force]
if {[get_files -quiet $wrapper] eq ""} {
    add_files -norecurse $wrapper
}
update_compile_order -fileset sources_1

file mkdir [file dirname $output_xsa]
set ram_ooc_run [get_runs -quiet bit_soc_inferred_shared_ram_0_0_synth_1]
if {$ram_ooc_run ne ""} {
    reset_run $ram_ooc_run
}
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $impl_status"
if {![string match *Complete* $impl_status]} {
    error "Implementation did not complete successfully: $impl_status"
}
open_run impl_1
report_utilization -file [file join [file dirname $output_xsa] utilization_postroute.rpt]
report_timing_summary -file [file join [file dirname $output_xsa] timing_postroute.rpt]
set worst_setup_path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
if {[llength $worst_setup_path] == 0} {
    error "No setup timing path was reported; refusing to export an unverified platform"
}
set worst_setup_slack [get_property SLACK [lindex $worst_setup_path 0]]
puts "Post-route worst setup slack: $worst_setup_slack ns"
if {$worst_setup_slack < 0.0} {
    error "Post-route setup timing fails ($worst_setup_slack ns); refusing to export a passing platform"
}
write_hw_platform -fixed -include_bit -force -file $output_xsa
puts "Exported hardware platform with bitstream: $output_xsa"
