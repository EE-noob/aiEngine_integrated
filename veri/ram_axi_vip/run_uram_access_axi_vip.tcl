set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../..]]
set project_file [file join $repo_root build ram_axi_vip ram_axi_vip.xpr]
set tb_file [file join $script_dir uram_access_axi_vip_tb.sv]

open_project $project_file
open_bd_design [get_files ram_axi_vip_bd.bd]
set_property CONFIG.READ_LATENCY 2 [get_bd_cells bram_ctrl]
validate_bd_design
save_bd_design
generate_target all [get_files ram_axi_vip_bd.bd]
add_files -fileset sim_1 -norecurse $tb_file
set_property top uram_access_axi_vip_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property xsim.simulate.runtime 100us [get_filesets sim_1]
set_property xsim.simulate.log_all_signals false [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
close_sim
close_project
