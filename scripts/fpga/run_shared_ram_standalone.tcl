set hw_project /home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2
set work_dir [file normalize /tmp/shared_ram_standalone_sim_[pid]]
set vivado_root /home/yusen/opt/Xilinx/Vivado/2024.2

file mkdir $work_dir
create_project shared_ram_standalone $work_dir -part xcvu3p-ffvc1517-2-e -force
set_property target_language Verilog [current_project]

set src_dir $hw_project/VU3P_oled.srcs/sources_1/new/dsa_npu
set ip_dir $hw_project/VU3P_oled.gen/sources_1/ip/sensor_model_bram
add_files -norecurse [list \
    $src_dir/axi_inferred_shared_ram.sv \
    $ip_dir/simulation/blk_mem_gen_v8_4.v \
    $ip_dir/sim/sensor_model_bram.v \
    [file normalize [file join [file dirname [info script]] ../../veri/ram_axi_vip/ram_latency_tb.sv]] \
    $vivado_root/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv]
set_property top ram_latency_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]

# The generated BMG simulation model opens its configured MIF from XSim's cwd.
set xsim_dir [file join $work_dir shared_ram_standalone.sim sim_1 behav xsim]
file mkdir $xsim_dir
file copy -force $ip_dir/sensor_model_bram.mif $xsim_dir/sensor_model_bram.mif
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
close_project
