if {[llength $argv] != 2} {
    error "Usage: vivado -mode batch -source check_vu3p_bram_locations.tcl -tclargs <routed.dcp> <processor.mmi>"
}
open_checkpoint [file normalize [lindex $argv 0]]
set mmi_file [open [file normalize [lindex $argv 1]] r]
set mmi_text [read $mmi_file]
close $mmi_file
if {![regexp {<Processor[^>]*>(.*?)</Processor>} $mmi_text -> processor_block]} {
    error "No Processor mapping in supplied MMI"
}
set placements {}
foreach item [regexp -all -inline {Placement="[^"]+"} $processor_block] {
    lappend placements [string range $item 11 end-1]
}
set placements [lsort -unique $placements]
foreach site $placements {
    set device_site [get_sites -quiet "RAMB36_$site"]
    if {[llength $device_site] != 1} {
        error "MMI local BRAM site $site is not a unique RAMB36 site"
    }
    set cells [get_cells -quiet -of_objects $device_site]
    if {[llength $cells] != 1} {
        error "MMI local BRAM site $site maps to [llength $cells] placed cells"
    }
    set cell_name [get_property NAME [lindex $cells 0]]
    if {![string match *lmb_bram* $cell_name]} {
        error "MMI local BRAM site $site is occupied by unexpected cell $cell_name"
    }
    puts "LOCAL_BRAM_OK $site $cell_name"
}
puts "Validated [llength $placements] local BRAM placements against the new routed design"
close_design
