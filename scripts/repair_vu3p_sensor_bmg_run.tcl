open_project /home/etc/FPGA/BIT_PROJ_S1/VU3P_sensor_v2/VU3P_oled.xpr
set model_ip [get_ips sensor_model_bram]
create_ip_run -force $model_ip
puts "BRAM synthesis run: [get_runs sensor_model_bram_synth_1]"
close_project
