open_project /home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.xpr
set ip [get_ips sensor_model_bram]
puts "IP=[get_property IP_FILE $ip]"
puts "RUN=[get_runs sensor_model_bram_synth_1]"
report_property $ip
report_property [get_runs sensor_model_bram_synth_1]
report_ip_status -file /tmp/sensor_model_bram_ip_status.txt
close_project
