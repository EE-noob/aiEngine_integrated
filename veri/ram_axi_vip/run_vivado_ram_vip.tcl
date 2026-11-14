set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../..]]
set hw_root /home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2
set work_root [file normalize [file join $repo_root build ram_axi_vip]]
set test_ip_dir [file join $work_root model_ip_source]

create_project -force ram_axi_vip $work_root -part xcvu3p-ffvc1517-2-i
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set ram_rtl [file join $hw_root VU3P_oled.srcs/sources_1/new/dsa_npu/axi_inferred_shared_ram.sv]
add_files -norecurse $ram_rtl
# The module is Verilog-2001 compatible; Vivado module references currently
# reject a SystemVerilog file as the BD reference top.
set_property FILE_TYPE Verilog [get_files $ram_rtl]
file mkdir $test_ip_dir
set source_xci [file join $hw_root VU3P_oled.srcs/sources_1/ip/sensor_model_bram/sensor_model_bram.xci]
set source_coe [file join $hw_root ../Vitis/sensor_sw_v2/deploy/20261019_125mhz/dsa_model_bram.coe]
set test_xci [file join $test_ip_dir sensor_model_bram.xci]
set test_coe [file join $test_ip_dir dsa_model_bram.coe]
file copy -force $source_xci $test_xci
file copy -force $source_coe $test_coe
add_files -norecurse $test_xci
set_property ip_repo_paths [list [file join $hw_root ip_repo]] [current_project]
update_ip_catalog
set test_bram [get_ips sensor_model_bram]
set_property -dict [list \
    CONFIG.Coe_File $test_coe \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false}] $test_bram
generate_target all [get_ips sensor_model_bram]

create_bd_design ram_axi_vip_bd
set vip [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vip master_0]
set_property -dict [list CONFIG.PROTOCOL {AXI4} CONFIG.INTERFACE_MODE {MASTER} \
    CONFIG.DATA_WIDTH {32} CONFIG.ID_WIDTH {1} CONFIG.SUPPORTS_NARROW {1}] $vip

set ctrl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 bram_ctrl]
set_property -dict [list CONFIG.DATA_WIDTH {32} CONFIG.SINGLE_PORT_BRAM {1} \
    CONFIG.ECC_TYPE {0} CONFIG.SUPPORTS_NARROW_BURST {1} \
    CONFIG.READ_LATENCY {1}] $ctrl

set ram [create_bd_cell -type module -reference axi_inferred_shared_ram shared_ram]
connect_bd_intf_net [get_bd_intf_pins master_0/M_AXI] [get_bd_intf_pins bram_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins bram_ctrl/BRAM_PORTA] [get_bd_intf_pins shared_ram/BRAM_PORTA]

set aclk [create_bd_port -dir I -type clk -freq_hz 125000000 ACLK]
set_property -dict [list CONFIG.FREQ_HZ {125000000} CONFIG.CLK_DOMAIN {ram_axi_vip_bd_ACLK}] $aclk
set aresetn [create_bd_port -dir I -type rst ARESETN]
set_property CONFIG.POLARITY ACTIVE_LOW $aresetn
set_property CONFIG.ASSOCIATED_RESET ARESETN $aclk
connect_bd_net [get_bd_ports ACLK] [get_bd_pins master_0/ACLK] \
    [get_bd_pins bram_ctrl/s_axi_aclk] [get_bd_pins shared_ram/clka] \
    [get_bd_pins shared_ram/clkb]
connect_bd_net [get_bd_ports ARESETN] [get_bd_pins master_0/ARESETN] [get_bd_pins bram_ctrl/s_axi_aresetn]
set zero1 [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero1]
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {0}] $zero1
set zero4 [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero4]
set_property -dict [list CONFIG.CONST_WIDTH {4} CONFIG.CONST_VAL {0}] $zero4
set zero32 [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero32]
set_property -dict [list CONFIG.CONST_WIDTH {32} CONFIG.CONST_VAL {0}] $zero32
connect_bd_net [get_bd_pins zero1/dout] [get_bd_pins shared_ram/enb] [get_bd_pins shared_ram/rstb]
connect_bd_net [get_bd_pins zero4/dout] [get_bd_pins shared_ram/web]
connect_bd_net [get_bd_pins zero32/dout] [get_bd_pins shared_ram/addrb] [get_bd_pins shared_ram/dinb]

assign_bd_address
set ram_seg [get_bd_addr_segs /master_0/Master_AXI/SEG_bram_ctrl_Mem0]
set_property offset 0x00000000 $ram_seg
set_property range 16M $ram_seg
validate_bd_design
save_bd_design

set wrapper [make_wrapper -files [get_files ram_axi_vip_bd.bd] -top -force]
add_files -norecurse $wrapper
set_property top ram_axi_vip_bd_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

set tb [file join $script_dir ram_axi_vip_tb.sv]
add_files -fileset sim_1 -norecurse $tb
set include_file [file join $work_root ram_axi_vip_tb_include.svh]
set fp [open $include_file w]
puts $fp "`ifndef RAM_AXI_VIP_TB_INCLUDE_SVH"
puts $fp "`define RAM_AXI_VIP_TB_INCLUDE_SVH"
puts $fp "`define BD_NAME ram_axi_vip_bd"
puts $fp "`define BD_INST_NAME ram_axi_vip_bd_i"
puts $fp "`define BD_WRAPPER ram_axi_vip_bd_wrapper"
puts $fp "`endif"
close $fp
add_files -fileset sim_1 -norecurse $include_file
set_property top ram_axi_vip_tb [get_filesets sim_1]
set_property xsim.simulate.runtime 1us [get_filesets sim_1]
set_property xsim.simulate.log_all_signals true [get_filesets sim_1]

generate_target all [get_files ram_axi_vip_bd.bd]
export_ip_user_files -of_objects [get_files ram_axi_vip_bd.bd] -no_script -sync -force -quiet
launch_simulation -simset sim_1 -mode behavioral
close_sim
close_project
