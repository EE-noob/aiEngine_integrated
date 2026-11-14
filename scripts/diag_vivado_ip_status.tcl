if {[llength $argv] != 1} {
    error "Expected project file path"
}
open_project [file normalize [lindex $argv 0]]
open_bd_design [get_files [file join [get_property DIRECTORY [current_project]] VU3P_oled.srcs sources_1 bd bit_soc bit_soc.bd]]
report_ip_status -file [file join [get_property DIRECTORY [current_project]] ip_status_report.txt]
exit
