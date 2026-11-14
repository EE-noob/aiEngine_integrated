open_project /home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.xpr
set model_ip [get_ips sensor_model_bram]
if {[llength $model_ip] != 1} {
    error "Expected exactly one sensor_model_bram IP"
}
synth_ip -force $model_ip
report_ip_status -file /tmp/sensor_model_bram_ip_status_after_synth.txt
close_project
