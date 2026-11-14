    .section .rodata.sensor_calibrator_20261016,"a",@progbits
    .balign 16
    .global g_sensor_calibrator_20261016_model_data
    .type g_sensor_calibrator_20261016_model_data,@object
g_sensor_calibrator_20261016_model_data:
    .incbin "sensor_calibrator_int16.tflite"
    .global g_sensor_calibrator_20261016_model_data_end
g_sensor_calibrator_20261016_model_data_end:
    .size g_sensor_calibrator_20261016_model_data, g_sensor_calibrator_20261016_model_data_end-g_sensor_calibrator_20261016_model_data

