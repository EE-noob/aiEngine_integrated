if {[llength $argv] != 1} { error "Expected routed DCP path" }
open_checkpoint [lindex $argv 0]
set cells [get_cells -hier -filter {REF_NAME =~ RAMB36*}]
puts "TOTAL_RAMB36=[llength $cells]"
foreach c [lrange $cells 0 19] {
    puts "RAMB name=$c loc=[get_property LOC $c] init00=[get_property INIT_00 $c]"
}
set shared_cells [get_cells -hier -filter {NAME =~ *inferred_shared_ram*}]
puts "SHARED_CELLS=[llength $shared_cells]"
set shared_bram [get_cells -hier -filter {REF_NAME =~ RAMB36* && NAME =~ *inferred_shared_ram*}]
puts "SHARED_RAMB36=[llength $shared_bram]"
if {[catch {set_property BMM_INFO_ADDRESS_SPACE {sensor_model_shared} $shared_bram} err]} {
    puts "BMM_PROPERTY_ERROR=$err"
} else {
    puts "BMM_PROPERTY_SET=1"
    write_mem_info -force /tmp/sensor_model_shared_test.mmi
}
array set ram_by_index {}
foreach c $shared_bram {
    if {[regexp {ramloop\[([0-9]+)\]} $c -> idx]} { set ram_by_index($idx) $c }
}
for {set i 0} {$i < 32} {incr i} {
    set c $ram_by_index($i)
    puts "MODEL_BRAM idx=$i loc=[get_property LOC $c] wra=[get_property WRITE_WIDTH_A $c] init00=[get_property INIT_00 $c]"
}
close_design
