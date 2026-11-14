if {[llength $argv] != 2} {
    error "Usage: report_vu3p_cross_clock_paths.tcl <routed.dcp> <output-dir>"
}
set dcp [file normalize [lindex $argv 0]]
set outdir [file normalize [lindex $argv 1]]
file mkdir $outdir
open_checkpoint $dcp
set c125 [get_clocks -quiet clk_out1_bit_soc_clk_wiz_0_0]
set c100 [get_clocks -quiet clk_out2_bit_soc_clk_wiz_0_0]
if {[llength $c125] != 1 || [llength $c100] != 1} {
    error "Expected clk_out1 (125 MHz) and clk_out2 (100 MHz) clocks in checkpoint"
}
report_timing -from $c125 -to $c100 -delay_type max -max_paths 30 \
    -path_type full_clock_expanded -input_pins -nets \
    -file [file join $outdir clk125_to_clk100.rpt]
report_timing -from $c100 -to $c125 -delay_type max -max_paths 30 \
    -path_type full_clock_expanded -input_pins -nets \
    -file [file join $outdir clk100_to_clk125.rpt]
report_clock_interaction -file [file join $outdir clock_interaction.rpt]
report_exceptions -coverage -file [file join $outdir timing_exceptions.rpt]
close_design
