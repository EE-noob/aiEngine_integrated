    .section .dsa_model,"a",@progbits
    .balign 16
    .global g_sensor_calibration_20261019_model_data
    .type g_sensor_calibration_20261019_model_data,@object
g_sensor_calibration_20261019_model_data:
    .incbin "sensor_calibrator_complete_int16.tflite"
    .global g_sensor_calibration_20261019_model_data_end
g_sensor_calibration_20261019_model_data_end:
    .size g_sensor_calibration_20261019_model_data, g_sensor_calibration_20261019_model_data_end-g_sensor_calibration_20261019_model_data
