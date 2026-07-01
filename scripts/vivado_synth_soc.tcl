# Vivado batch synthesis for the AXI SoC top.
#
# Usage:
#   vivado -mode batch -source scripts/vivado_synth_soc.tcl
#   vivado -mode batch -source scripts/vivado_synth_soc.tcl -tclargs build/my_synth

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]

if {[llength $argv] >= 1} {
    set out_dir [file normalize [lindex $argv 0]]
} else {
    set out_dir [file join $repo_root build vivado_soc_synth_150mhz]
}
file mkdir $out_dir

set part_name xc7a200tfbg484-3
set top_name  soc_top
set clock_period_ns 6.667
set_param general.maxThreads 2
set synth_generics {CPU_MEM_DP=65536 CPU_MEM_INIT_EN=0}

set incdirs [list \
    [file join $repo_root include] \
    [file join $repo_root rtl nice_coprocessor inc] \
]

set rtl_files [list \
    [file join $repo_root picorv32 picorv32.v] \
    [file join $repo_root picorv32 picosoc simpleuart.v] \
    [file join $repo_root rtl nice_coprocessor axil_reg_if_wr.v] \
    [file join $repo_root rtl nice_coprocessor axil_reg_if_rd.v] \
    [file join $repo_root rtl nice_coprocessor axil_reg_if.v] \
    [file join $repo_root rtl nice_coprocessor csr_unit.v] \
    [file join $repo_root rtl nice_coprocessor wb_pingpong_buf.v] \
    [file join $repo_root rtl nice_coprocessor wbu.v] \
    [file join $repo_root rtl nice_coprocessor axi_top mma_axil_top.sv] \
    [file join $repo_root rtl nice_coprocessor MMA accumulator_array.sv] \
    [file join $repo_root rtl nice_coprocessor MMA axi_block_dma_arbiter.sv] \
    [file join $repo_root rtl nice_coprocessor MMA axi_dual_block_dma.sv] \
    [file join $repo_root rtl nice_coprocessor MMA bias_loader.sv] \
    [file join $repo_root rtl nice_coprocessor MMA bias_loader_buffer.sv] \
    [file join $repo_root rtl nice_coprocessor MMA bias_loader_ctrl.sv] \
    [file join $repo_root rtl nice_coprocessor MMA bias_mux.sv] \
    [file join $repo_root rtl nice_coprocessor MMA block_dma.sv] \
    [file join $repo_root rtl nice_coprocessor MMA compute_core.sv] \
    [file join $repo_root rtl nice_coprocessor MMA data_setup.sv] \
    [file join $repo_root rtl nice_coprocessor MMA de_diagonalizer.sv] \
    [file join $repo_root rtl nice_coprocessor MMA ia_buffer_wrapper.sv] \
    [file join $repo_root rtl nice_coprocessor MMA ia_loader.sv] \
    [file join $repo_root rtl nice_coprocessor MMA ia_loader_cache_mgr.sv] \
    [file join $repo_root rtl nice_coprocessor MMA ia_loader_ctrl.sv] \
    [file join $repo_root rtl nice_coprocessor MMA kernel_block_dma.sv] \
    [file join $repo_root rtl nice_coprocessor MMA kernel_loader.sv] \
    [file join $repo_root rtl nice_coprocessor MMA kernel_loader_buffer.sv] \
    [file join $repo_root rtl nice_coprocessor MMA kernel_loader_ctrl.sv] \
    [file join $repo_root rtl nice_coprocessor MMA mma_controller.sv] \
    [file join $repo_root rtl nice_coprocessor MMA mma_top.sv] \
    [file join $repo_root rtl nice_coprocessor MMA oa_writer.sv] \
    [file join $repo_root rtl nice_coprocessor MMA ps_buffer.sv] \
    [file join $repo_root rtl nice_coprocessor MMA ps_buffer_fifo.sv] \
    [file join $repo_root rtl nice_coprocessor MMA pseudo_dual_port_ram.v] \
    [file join $repo_root rtl nice_coprocessor MMA shift_accumulator.sv] \
    [file join $repo_root rtl nice_coprocessor MMA vec_requant.sv] \
    [file join $repo_root rtl nice_coprocessor MMA vec_s8_to_fifo.sv] \
    [file join $repo_root rtl nice_coprocessor MMA ws_systolic_array.sv] \
    [file join $repo_root rtl nice_coprocessor MMA ws_systolic_cell.sv] \
    [file join $repo_root rtl nice_coprocessor soc pico_native_to_axi.sv] \
    [file join $repo_root rtl nice_coprocessor soc soc_axi_interconnect.sv] \
    [file join $repo_root rtl nice_coprocessor soc soc_axi_pingpong_buffer.sv] \
    [file join $repo_root rtl nice_coprocessor soc soc_axi_ram.sv] \
    [file join $repo_root rtl nice_coprocessor soc soc_axil_ctrl.sv] \
    [file join $repo_root rtl nice_coprocessor soc soc_axil_simpleuart.sv] \
    [file join $repo_root rtl nice_coprocessor soc_top.sv] \
]

set xdc_file [file join $out_dir soc_top_150mhz.xdc]
set xdc_fh [open $xdc_file w]
puts $xdc_fh "create_clock -name clk -period $clock_period_ns \[get_ports clk\]"
close $xdc_fh

set_property include_dirs $incdirs [current_fileset]
set_property verilog_define {SYNTHESIS=1} [current_fileset]

read_verilog -sv $rtl_files
read_xdc $xdc_file

synth_design -top $top_name -part $part_name -generic $synth_generics -flatten_hierarchy rebuilt

report_utilization -file [file join $out_dir soc_top_utilization.rpt]
report_utilization -hierarchical -file [file join $out_dir soc_top_utilization_hier.rpt]
report_timing_summary -delay_type max -report_unconstrained -check_timing_verbose \
    -file [file join $out_dir soc_top_timing_summary.rpt]
report_timing -delay_type max -sort_by group -max_paths 200 -nworst 1 \
    -file [file join $out_dir soc_top_timing_paths.rpt]
report_high_fanout_nets -fanout_greater_than 100 -max_nets 200 \
    -file [file join $out_dir soc_top_high_fanout.rpt]
write_checkpoint -force [file join $out_dir soc_top_synth.dcp]
