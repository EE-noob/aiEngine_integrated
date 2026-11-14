if {[llength $argv] != 1} {
    error "Usage: vivado -mode batch -source dump_vu3p_bmm_properties.tcl -tclargs <routed.dcp>"
}
open_checkpoint [file normalize [lindex $argv 0]]
set found 0
foreach cell [get_cells -hier] {
    foreach property [list_property $cell] {
        if {[string match -nocase *BMM* $property]} {
            set value [get_property $property $cell]
            if {$value ne ""} {
                puts "BMM_PROPERTY [get_property NAME $cell] $property = $value"
                incr found
            }
        }
    }
}
puts "BMM_PROPERTY_COUNT $found"
close_design
