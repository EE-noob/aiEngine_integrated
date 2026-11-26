# Run from the build directory prepared by run_a7_flow.py.
lassign $argv stage part threads
set_param general.maxThreads $threads

proc write_reports {stage} {
    report_utilization -file ${stage}_utilization.rpt
    report_utilization -hierarchical -file ${stage}_utilization_hier.rpt
    report_timing_summary -report_unconstrained -file ${stage}_timing_summary.rpt
}

switch -- $stage {
    synth {
        set manifest [open rtl_sources.txt r]
        set sources [split [string trim [read $manifest]] \n]
        close $manifest
        set incdirs [list [lindex $sources 0]]
        set_property include_dirs $incdirs [current_fileset]
        set_property verilog_define {SYNTHESIS=1 XILINX_FPGA=1} [current_fileset]
        read_verilog -sv [lrange $sources 1 end]
        read_xdc clock.xdc
        synth_design -top a7_soc -part $part -flatten_hierarchy rebuilt
        write_reports synth
        write_checkpoint -force a7_synth.dcp
        write_verilog -force -mode funcsim a7_synth_func.v
    }
    route {
        open_checkpoint a7_synth.dcp
        opt_design
        place_design
        phys_opt_design
        route_design
        write_reports route
        report_route_status -file route_status.rpt
        report_drc -file route_drc.rpt
        write_checkpoint -force a7_route.dcp
        write_verilog -force -mode funcsim a7_route_func.v
    }
    default { error "Unknown stage '$stage'" }
}
