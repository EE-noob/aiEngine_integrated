SHELL := /bin/bash
.RECIPEPREFIX := >

TOP      ?= tb_top
DUMPOPTS ?= 1
INCDIRS  ?=
DEFINES  ?=
UVM_HOME ?= $(VCS_HOME)/etc/uvm-1.2/
UVM_VER  ?= -ntb_opts uvm-1.2
NOVAS_HOME ?=
VCS ?= vcs
URG ?= urg
VERDI ?= verdi
SIM_LAUNCHER ?= ./run_simv_lxc.sh
SIM_RUNNER ?= $(SIM_LAUNCHER) ./$(SIMV)
SIM_ARGS ?=
VCS_CC ?= gcc
VCS_CXX ?= g++
case     ?= ai_mem_gen_smoke_test
seed     ?= 1
DUT_MODE ?= axil
SOC_CASE ?= axi_soc_case
SOC_CASE_DIR ?= ../tb/$(SOC_CASE)
SOC_K ?= 24
SOC_N ?= 32
SOC_M ?= 16
SOC_LHS_DTYPE ?= 1
SOC_QUANT_MODE ?= 0
SOC_DATAFLOW_MODE ?= 0
SOC_IA_REUSE_NUM ?= 0
SOC_W_REUSE_NUM ?= 0
MMA_SIZE ?= 16
MMA_IA_CACHE_BLOCKS ?= 4
MMA_PS_FRAME_COUNT ?= $(MMA_SIZE)
SOC_RANDOM ?= 0
SOC_FIX_MODE ?= 1
SOC_SEED ?= 1
SOC_RANDOM_LHS_DTYPE ?=
SOC_RANDOM_QUANT_MODE ?=
SOC_UNALIGNED_LAYOUT ?= 0
SOC_MIN_DIM ?=
SOC_MAX_DIM ?=
SOC_DIM_MULTIPLE ?= 16
SOC_DIRECTED_PATTERN ?=
SOC_LHS_OFFSET ?= 0
SOC_RHS_OFFSET ?= 0
SOC_DST_OFFSET ?= 0
SOC_ACT_MIN ?= -128
SOC_ACT_MAX ?= 127
SOC_DST_MULT ?=
SOC_DST_SHIFT ?=
SOC_CPU_MEM_DP ?= 65536
SOC_AXI_READ_OUTSTANDING ?= 4
SOC_AXI_WRITE_OUTSTANDING ?= $(SOC_AXI_READ_OUTSTANDING)
SOC_CPU_ENABLE_ICACHE ?= 0
SOC_BYPASS_RAM_PINGPONG ?= 1
SOC_RAM_WRITE_TIMING_BUFFER ?= 1
SIMV     ?= simv_$(DUT_MODE)_S$(MMA_SIZE)_C$(MMA_IA_CACHE_BLOCKS)_P$(MMA_PS_FRAME_COUNT)_D$(SOC_CPU_MEM_DP)_RO$(SOC_AXI_READ_OUTSTANDING)_WO$(SOC_AXI_WRITE_OUTSTANDING)_IC$(SOC_CPU_ENABLE_ICACHE)_BP$(SOC_BYPASS_RAM_PINGPONG)_WT$(SOC_RAM_WRITE_TIMING_BUFFER)
SOC_TIMEOUT_CYCLES ?=
SOC_C_SRC ?= ../soc_csrc/soc_main.c
SOC_RUNTIME_C_SRC ?= ../soc_csrc/soc_runtime_main.c
SOC_APP ?= runtime
SOC_UART_CLKDIV ?= 8
SOC_TOOLCHAIN_DIR ?= /media/proj_tmp/alioth_simulator/deps/software-level/bin/gcc_open/bin
SOC_GCC_FROM_PATH := $(shell command -v riscv64-unknown-elf-gcc 2>/dev/null)
SOC_GXX_FROM_PATH := $(shell command -v riscv64-unknown-elf-g++ 2>/dev/null)
SOC_AR_FROM_PATH := $(shell command -v riscv64-unknown-elf-ar 2>/dev/null)
SOC_OBJCOPY_FROM_PATH := $(shell command -v riscv64-unknown-elf-objcopy 2>/dev/null)
SOC_GCC ?= $(if $(SOC_GCC_FROM_PATH),$(SOC_GCC_FROM_PATH),$(SOC_TOOLCHAIN_DIR)/riscv64-unknown-elf-gcc)
SOC_GXX ?= $(if $(SOC_GXX_FROM_PATH),$(SOC_GXX_FROM_PATH),$(SOC_TOOLCHAIN_DIR)/riscv64-unknown-elf-g++)
SOC_AR ?= $(if $(SOC_AR_FROM_PATH),$(SOC_AR_FROM_PATH),$(SOC_TOOLCHAIN_DIR)/riscv64-unknown-elf-ar)
SOC_OBJCOPY ?= $(if $(SOC_OBJCOPY_FROM_PATH),$(SOC_OBJCOPY_FROM_PATH),$(SOC_TOOLCHAIN_DIR)/riscv64-unknown-elf-objcopy)
SOC_ARCH_FLAGS ?= -march=rv32im -mabi=ilp32
SOC_ARCH_TAG ?= rv32im
SOC_BARE_LIBS ?= -lgcc
SOC_OPT_LEVEL ?= -O3
HOST_OPT_LEVEL ?= -O3
SOC_RAM_BYTES ?= $(shell python3 -c 'print(int("$(SOC_CPU_MEM_DP)", 0) * 4)')
SOC_LINK_FLAGS ?= -T ../soc_csrc/link.ld -Wl,--build-id=none -Wl,--defsym=__ram_length=$(SOC_RAM_BYTES)
SOC_REGRESS_ITERS ?= 10
SOC_REGRESS_START_SEED ?= 1
SOC_REGRESS_TIMEOUT ?= 300
SOC_REGRESS_SOC_TIMEOUT_CYCLES ?= $(SOC_TIMEOUT_CYCLES)
SOC_REGRESS_LOG_ROOT ?= runs/axi_soc_c_regression
SOC_REGRESS_DIM_MULTIPLE ?= 0
SOC_SIZE_LIST ?= $(MMA_SIZE)
SOC_CACHE_BLOCKS_LIST ?= $(MMA_IA_CACHE_BLOCKS)
SOC_PS_FRAME_COUNT_LIST ?=
SOC_DATAFLOW_MODE_LIST ?= $(SOC_DATAFLOW_MODE)
SOC_REGRESS_LHS_DTYPE_LIST ?=
SOC_REGRESS_QUANT_MODE_LIST ?=
SOC_REGRESS_SIM_ARGS ?= $(SIM_ARGS)
SOC_REGRESS_DDR_RAND_LAT ?= 0
SOC_REGRESS_DDR_CMD_MAX_LAT ?= 3
SOC_REGRESS_DDR_W_MAX_LAT ?= 2
SOC_REGRESS_DDR_RSP_MAX_LAT ?= 8
SOC_REGRESS_UNALIGNED_LAYOUT ?= 0
SOC_PERF_LOG_ROOT ?= runs/axi_soc_perf_sweep
SOC_PERF_SEED ?= 80000
SOC_PERF_TIMEOUT ?= 900
SOC_PERF_SOC_TIMEOUT_CYCLES ?=
SOC_PERF_DIMS ?= 32x32x32
SOC_PERF_SIZE_LIST ?= $(MMA_SIZE)
SOC_PERF_CACHE_BLOCKS_LIST ?= $(MMA_IA_CACHE_BLOCKS)
SOC_PERF_PS_FRAME_COUNT_LIST ?=
SOC_PERF_DATAFLOW_MODE_LIST ?= 0 1
SOC_PERF_LHS_DTYPE_LIST ?= 1
SOC_PERF_QUANT_MODE_LIST ?= 0
SOC_PERF_IA_REUSE_LIST ?=
SOC_PERF_W_REUSE_LIST ?=
SOC_PERF_SIM_ARGS ?= $(SIM_ARGS)
SOC_PERF_INCLUDE_AUTO ?= 0
SOC_PERF_KEEP_GOING ?= 0
SOC_PERF_FORCE_COMPILE ?= 0
SOC_PERF_JOBS ?= 1
SOC_PERF_DDR_RAND_LAT ?= 0
SOC_PERF_DDR_CMD_MAX_LAT ?= 3
SOC_PERF_DDR_W_MAX_LAT ?= 2
SOC_PERF_DDR_RSP_MAX_LAT ?= 8
SOC_PERF_RAM_FIXED_LAT ?=
TOP_REGRESS_SIZE ?= 4
TOP_REGRESS_IA_CACHE_BLOCKS ?= 4
TOP_REGRESS_PS_FRAME_COUNT ?= 8
TOP_REGRESS_AXI_READ_OUTSTANDING ?= 4
TOP_REGRESS_COUNT ?= 20
TOP_REGRESS_SEED ?= 1000
TOP_REGRESS_RANDOM_GEN_ARGS ?= --random --random_quant --lhs_dtype 0 --min_dim 1 --max_dim 32
TOP_REGRESS_SIM_ARGS ?= +DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8
TOP_REGRESS_TRACE ?= 0
SOC_RUNTIME_BASE_WORD ?= $(shell python3 -c 'print(int("$(SOC_CPU_MEM_DP)", 0) // 2)')
SOC_RUNTIME_BASE_ADDR ?= $(shell python3 -c 'print(hex((int("$(SOC_CPU_MEM_DP)", 0) // 2) * 4))')
# Runtime firmware embeds SOC_RUNTIME_CASE_BASE, which is derived from
# SOC_CPU_MEM_DP. Keep the memory depth in the build directory name so cached
# cpu.mem images cannot be reused with a stale runtime data base address.
SOC_RUNTIME_BUILD_DIR ?= ../tb/axi_soc_runtime_build_S$(MMA_SIZE)_C$(MMA_IA_CACHE_BLOCKS)_P$(MMA_PS_FRAME_COUNT)_D$(SOC_CPU_MEM_DP)
SOC_RUNTIME_CPU_MEM ?= $(SOC_RUNTIME_BUILD_DIR)/cpu.mem
TFLM_DIR ?= ../../drivers/tflm/my_tflm
TFLM_ROOT ?= $(TFLM_DIR)/tflite-micro
TFLM_SOC_MMA_ENABLE ?= 1
TFLM_NMSIS_NN_ENABLE ?= $(TFLM_SOC_MMA_ENABLE)
TFLM_NMSIS_NN_DEFINE := $(if $(filter 1 yes true TRUE,$(TFLM_NMSIS_NN_ENABLE)),-DNMSIS_NN,)
TFLM_SOC_MMA_DEFINE := $(if $(filter 1 yes true TRUE,$(TFLM_NMSIS_NN_ENABLE)),$(if $(filter 1 yes true TRUE,$(TFLM_SOC_MMA_ENABLE)),-DTFLM_SOC_MMA,),)
TFLM_ACCEL_TAG := $(if $(filter 1 yes true TRUE,$(TFLM_NMSIS_NN_ENABLE)),$(if $(filter 1 yes true TRUE,$(TFLM_SOC_MMA_ENABLE)),hw,nmsis),sw)
TFLM_BUILD_DIR ?= build-$(SOC_ARCH_TAG)-$(TFLM_ACCEL_TAG)-S$(MMA_SIZE)-C$(MMA_IA_CACHE_BLOCKS)-P$(MMA_PS_FRAME_COUNT)
TFLM_LIB ?= $(TFLM_DIR)/$(TFLM_BUILD_DIR)/libtflite-micro.a
TFLM_GENFILES ?= $(TFLM_ROOT)/gen/linux_x86_64_default/genfiles
TFLM_HOST_BUILD_DIR ?= build-host
TFLM_HOST_LIB ?= $(TFLM_DIR)/$(TFLM_HOST_BUILD_DIR)/libtflite-micro.a
TFLM_MNIST_ACCURACY_BIN ?= $(TFLM_DIR)/$(TFLM_HOST_BUILD_DIR)/tflm_mnist_accuracy
TFLM_MNIST_ACCURACY_OUT ?= runs/tflm_mnist_accuracy
TFLM_MNIST_ACCURACY_COUNT ?= 10000
TFLM_MNIST_MLP_SOC_CASE ?= axi_soc_tflm_mnist_mlp_$(TFLM_ACCEL_TAG)
TFLM_MNIST_MLP_INT16X8_SOC_CASE ?= axi_soc_tflm_mnist_mlp_int16x8_$(TFLM_ACCEL_TAG)
TFLM_SENSOR_CALIBRATION_SOC_CASE ?= axi_soc_tflm_sensor_calibration_int16x8_$(TFLM_ACCEL_TAG)
TFLM_SENSOR_CALIBRATION_RELEASE_SOC_CASE ?= axi_soc_tflm_sensor_calibration_release_20261015_$(TFLM_ACCEL_TAG)
TFLM_SENSOR_CALIBRATION_20261019_SOC_CASE ?= axi_soc_tflm_sensor_calibration_20261019_$(TFLM_ACCEL_TAG)
TFLM_SENSOR_CALIBRATOR_20261016_SOC_CASE ?= axi_soc_tflm_sensor_calibrator_20261016_$(TFLM_ACCEL_TAG)
TFLM_SENSOR_CALIBRATOR_20261016_MODEL ?= /home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/calibration/sim_20261016/sensor_calibrator_int16.tflite
TFLM_SENSOR_CALIBRATOR_20261016_TIMEOUT_CYCLES ?= 2000000000
TFLM_SENSOR_CALIBRATOR_20261016_MEM_DP ?= 3112960
TFLM_SENSOR_CALIBRATION_20261019_MODEL ?= /home/etc/FPGA/BIT_PROJ_S1/Vitis/sensor_sw_v2/src/calibration/sim_20261019/sensor_calibrator_complete_int16.tflite
TFLM_SENSOR_CALIBRATION_20261019_TIMEOUT_CYCLES ?= 2000000000
TFLM_SENSOR_CALIBRATION_20261019_ARENA_SIZE ?= 262144
TFLM_MNIST_CNN_SOC_CASE ?= axi_soc_tflm_mnist_cnn_$(TFLM_ACCEL_TAG)
TFLM_MICRO_SPEECH_FEATURES_CC ?= ../soc_csrc/tflm_micro_speech_features.cc
TFLM_MICRO_SPEECH_FEATURE_DUMP ?= $(TFLM_DIR)/$(TFLM_HOST_BUILD_DIR)/dump_micro_speech_features
TFLM_MY_MODEL_TIMEOUT_CYCLES ?= 120000000
TFLM_MNIST_MLP_TIMEOUT_CYCLES ?= 320000000
TFLM_MNIST_MLP_INT16X8_ARENA_SIZE ?= 12288
TFLM_SENSOR_CALIBRATION_TIMEOUT_CYCLES ?= 320000000
TFLM_SENSOR_CALIBRATION_ARENA_SIZE ?= 16384
TFLM_SENSOR_CALIBRATION_RELEASE_TIMEOUT_CYCLES ?= 640000000
TFLM_SENSOR_CALIBRATION_RELEASE_HOST_BIN ?= $(TFLM_DIR)/$(TFLM_HOST_BUILD_DIR)/tflm_sensor_calibration_release_host
TFLM_MNIST_CNN_TIMEOUT_CYCLES ?= 320000000
TFLM_MICRO_SPEECH_TIMEOUT_CYCLES ?= 50000000
TFLM_HELLO_WORLD_TIMEOUT_CYCLES ?= 5000000
TFLM_PERSON_DETECTION_TIMEOUT_CYCLES ?= 320000000
SOC_HW_DEFINES := -DDSA_TILE_SIZE=$(MMA_SIZE) -DDSA_IA_CACHE_BLOCKS=$(MMA_IA_CACHE_BLOCKS) -DDSA_PS_FRAME_COUNT=$(MMA_PS_FRAME_COUNT)
TFLM_EXTRA_DEFINES ?=
TFLM_NMSIS_NN_SOURCE_DIR := $(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/nuclei_sdk/NMSIS/NN/Source
TFLM_NMSIS_SRCS := $(wildcard $(TFLM_NMSIS_NN_SOURCE_DIR)/*/*.c)
TFLM_RV32_REBUILD_DEPS := \
                $(TFLM_DIR)/Makefile \
                $(TFLM_ROOT)/tensorflow/lite/micro/kernels/shape.cc \
                $(TFLM_ROOT)/tensorflow/lite/micro/kernels/fill.cc \
                $(TFLM_ROOT)/tensorflow/lite/micro/micro_interpreter_graph.cc \
                $(TFLM_ROOT)/tensorflow/lite/micro/kernels/conv.cc \
                $(TFLM_ROOT)/tensorflow/lite/micro/kernels/depthwise_conv.cc \
                $(TFLM_ROOT)/tensorflow/lite/micro/kernels/fully_connected.cc \
                $(TFLM_ROOT)/tensorflow/lite/micro/kernels/nmsis_nn/conv.cc \
                $(TFLM_ROOT)/tensorflow/lite/micro/kernels/nmsis_nn/depthwise_conv.cc \
                $(TFLM_ROOT)/tensorflow/lite/micro/kernels/nmsis_nn/fully_connected.cc \
                $(TFLM_ROOT)/my_model/my_model.cc \
                $(TFLM_ROOT)/my_model/model_interface.cc \
                $(TFLM_NMSIS_SRCS)

TFLM_INCLUDES = -I$(TFLM_ROOT) \
                -I$(TFLM_ROOT)/gen \
                -I$(TFLM_GENFILES) \
                -I$(TFLM_ROOT)/my_model \
                -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads \
                -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/gemmlowp \
                -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/flatbuffers/include \
                -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/kissfft \
                -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/ruy
TFLM_CXXFLAGS = $(SOC_ARCH_FLAGS) $(SOC_OPT_LEVEL) $(SOC_HW_DEFINES) $(TFLM_EXTRA_DEFINES) \
                -std=c++17 -fno-rtti -fno-exceptions -fno-threadsafe-statics \
                -fno-unwind-tables -ffunction-sections -fdata-sections \
                -fmessage-length=0 -DNDEBUG -DTF_LITE_STRIP_ERROR_STRINGS \
                -DTF_LITE_DISABLE_X86_NEON -DPICOSOC_UART_CLKDIV=$(SOC_UART_CLKDIV) \
                -DTFLM_SOC_PROGRESS $(TFLM_NMSIS_NN_DEFINE) $(TFLM_SOC_MMA_DEFINE) $(TFLM_INCLUDES)
TFLM_APP_SRCS = ../soc_csrc/start.S \
                ../soc_csrc/tflm_soc_runtime.cc \
                ../soc_csrc/tflm_soc_main.cc \
                $(TFLM_ROOT)/my_model/my_model.cc \
                $(TFLM_ROOT)/my_model/model_interface.cc \
                $(TFLM_ROOT)/my_model/model_settings.cc \
                $(TFLM_ROOT)/gen/my_model/models/justure_detect_model_data.cc \
                $(TFLM_ROOT)/gen/my_model/testdata/Z_test_image_data.cc \
                $(TFLM_ROOT)/gen/my_model/testdata/W_test_image_data.cc
TFLM_MICRO_SPEECH_MODEL_DATA_CC = $(TFLM_GENFILES)/tensorflow/lite/micro/examples/micro_speech/models/micro_speech_quantized_model_data.cc
TFLM_MICRO_SPEECH_AUDIO_DATA_SRCS = $(TFLM_GENFILES)/tensorflow/lite/micro/examples/micro_speech/models/audio_preprocessor_int8_model_data.cc \
                                    $(TFLM_GENFILES)/tensorflow/lite/micro/examples/micro_speech/testdata/yes_1000ms_audio_data.cc \
                                    $(TFLM_GENFILES)/tensorflow/lite/micro/examples/micro_speech/testdata/no_1000ms_audio_data.cc
TFLM_MICRO_SPEECH_APP_SRCS = ../soc_csrc/start.S \
                             ../soc_csrc/tflm_soc_runtime.cc \
                             ../soc_csrc/tflm_micro_speech_soc_main.cc \
                             $(TFLM_MICRO_SPEECH_FEATURES_CC) \
                             $(TFLM_MICRO_SPEECH_MODEL_DATA_CC)
TFLM_HELLO_WORLD_MODEL_DATA_CC = $(TFLM_GENFILES)/tensorflow/lite/micro/examples/hello_world/models/hello_world_int8_model_data.cc
TFLM_HELLO_WORLD_APP_SRCS = ../soc_csrc/start.S \
                            ../soc_csrc/tflm_soc_runtime.cc \
                            ../soc_csrc/tflm_hello_world_soc_main.cc \
                            $(TFLM_HELLO_WORLD_MODEL_DATA_CC)
TFLM_PERSON_DETECTION_MODEL_DATA_CC = $(TFLM_GENFILES)/tensorflow/lite/micro/models/person_detect_model_data.cc
TFLM_PERSON_DETECTION_TESTDATA_SRCS = $(TFLM_GENFILES)/tensorflow/lite/micro/examples/person_detection/testdata/person_image_data.cc \
                                      $(TFLM_GENFILES)/tensorflow/lite/micro/examples/person_detection/testdata/no_person_image_data.cc
TFLM_PERSON_DETECTION_APP_SRCS = ../soc_csrc/start.S \
                                 ../soc_csrc/tflm_soc_runtime.cc \
                                 ../soc_csrc/tflm_person_detection_soc_main.cc \
                                 $(TFLM_ROOT)/tensorflow/lite/micro/examples/person_detection/model_settings.cc \
                                 $(TFLM_PERSON_DETECTION_MODEL_DATA_CC) \
                                 $(TFLM_PERSON_DETECTION_TESTDATA_SRCS)
TFLM_MNIST_MLP_MODEL_DIR = $(TFLM_ROOT)/mnist_mlp
TFLM_MNIST_MLP_APP_SRCS = ../soc_csrc/start.S \
                          ../soc_csrc/tflm_soc_runtime.cc \
                          ../soc_csrc/tflm_mnist_mlp_soc_main.cc \
                          $(TFLM_MNIST_MLP_MODEL_DIR)/mnist_mlp_model_data.cc \
                          $(TFLM_MNIST_MLP_MODEL_DIR)/mnist_mlp_test_data.cc
TFLM_MNIST_MLP_INT16X8_APP_SRCS = ../soc_csrc/start.S \
                                  ../soc_csrc/tflm_soc_runtime.cc \
                                  ../soc_csrc/tflm_mnist_mlp_soc_main.cc \
                                  $(TFLM_MNIST_MLP_MODEL_DIR)/mnist_mlp_int16x8_model_data.cc \
                                  $(TFLM_MNIST_MLP_MODEL_DIR)/mnist_mlp_int16x8_golden_data.cc \
                                  $(TFLM_MNIST_MLP_MODEL_DIR)/mnist_mlp_test_data.cc
TFLM_SENSOR_CALIBRATION_MODEL_DIR = $(TFLM_ROOT)/sensor_calibration
TFLM_SENSOR_CALIBRATION_APP_SRCS = ../soc_csrc/start.S \
                                   ../soc_csrc/tflm_soc_runtime.cc \
                                   ../soc_csrc/tflm_sensor_calibration_soc_main.cc \
                                   $(TFLM_SENSOR_CALIBRATION_MODEL_DIR)/sensor_calibration_model_data.cc \
                                   $(TFLM_SENSOR_CALIBRATION_MODEL_DIR)/sensor_calibration_test_data.cc
TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR = $(TFLM_ROOT)/sensor_calibration_20261015
TFLM_SENSOR_CALIBRATION_RELEASE_SOC_APP_SRCS = ../soc_csrc/start.S \
                                               ../soc_csrc/tflm_soc_runtime.cc \
                                               ../soc_csrc/tflm_sensor_calibration_release_soc_main.cc \
                                               $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_data.cc \
                                               $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_model_data.cc \
                                               $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_soc_test_data.cc
TFLM_SENSOR_CALIBRATOR_20261016_SOC_APP_SRCS = ../soc_csrc/start.S \
                                                ../soc_csrc/tflm_soc_runtime.cc \
                                                ../soc_csrc/tflm_sensor_calibrator_20261016_soc_main.cc \
                                                ../soc_csrc/tflm_sensor_calibrator_20261016_model_data.S
TFLM_SENSOR_CALIBRATION_20261019_MODEL_DATA = ../soc_csrc/tflm_sensor_calibration_20261019_model_data.S
TFLM_SENSOR_CALIBRATION_20261019_GOLDEN = ../soc_csrc/tflm_sensor_calibration_20261019_golden_data.cc
TFLM_SENSOR_CALIBRATION_20261019_SOC_APP_SRCS = ../soc_csrc/start.S \
                                                  ../soc_csrc/tflm_soc_runtime.cc \
                                                  ../soc_csrc/tflm_sensor_calibration_20261019_soc_main.cc \
                                                  $(TFLM_SENSOR_CALIBRATION_20261019_MODEL_DATA) \
                                                  $(TFLM_SENSOR_CALIBRATION_20261019_GOLDEN)
TFLM_SENSOR_CALIBRATION_RELEASE_HOST_SRCS = ../tools/tflm_sensor_calibration_release_host.cc \
                                            ../soc_csrc/sensor_calibration_release_inference.h \
                                            $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_data.cc \
                                            $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_model_data.cc \
                                            $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_host_test_data.cc \
                                            $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_soc_test_data.cc
TFLM_MNIST_CNN_MODEL_DIR = $(TFLM_ROOT)/mnist_cnn
TFLM_MNIST_CNN_APP_SRCS = ../soc_csrc/start.S \
                          ../soc_csrc/tflm_soc_runtime.cc \
                          ../soc_csrc/tflm_mnist_cnn_soc_main.cc \
                          $(TFLM_MNIST_CNN_MODEL_DIR)/mnist_cnn_model_data.cc \
                          $(TFLM_MNIST_CNN_MODEL_DIR)/mnist_cnn_test_data.cc

SOC_GEN_ARGS = --seed $(SOC_SEED) \
               $(if $(filter 1 yes true TRUE,$(SOC_FIX_MODE)),--fix_mode,) \
               --lhs_offset $(SOC_LHS_OFFSET) \
               --rhs_offset $(SOC_RHS_OFFSET) \
               --dst_offset $(SOC_DST_OFFSET) \
               --act_min $(SOC_ACT_MIN) \
               --act_max $(SOC_ACT_MAX) \
               --dataflow_mode $(SOC_DATAFLOW_MODE) \
               --ia_reuse_num $(SOC_IA_REUSE_NUM) \
               --w_reuse_num $(SOC_W_REUSE_NUM) \
               $(if $(SOC_DST_MULT),--dst_mult $(SOC_DST_MULT),) \
               $(if $(SOC_DST_SHIFT),--dst_shift $(SOC_DST_SHIFT),) \
               $(if $(SOC_RANDOM_LHS_DTYPE),--lhs_dtype $(SOC_RANDOM_LHS_DTYPE),) \
               $(if $(SOC_RANDOM_QUANT_MODE),--quant_mode $(SOC_RANDOM_QUANT_MODE),) \
               $(if $(SOC_DIRECTED_PATTERN),--directed_pattern $(SOC_DIRECTED_PATTERN),) \
               --runtime_base_addr $(SOC_RUNTIME_BASE_ADDR) \
               $(if $(filter 1 yes true TRUE,$(SOC_UNALIGNED_LAYOUT)),--unaligned_layout,) \
               $(if $(SOC_MIN_DIM),--min_dim $(SOC_MIN_DIM),) \
               $(if $(SOC_MAX_DIM),--max_dim $(SOC_MAX_DIM),) \
               --dim_multiple $(SOC_DIM_MULTIPLE)
ifneq ($(filter 1 yes true TRUE,$(SOC_RANDOM)),)
SOC_GEN_ARGS += --random
else
SOC_GEN_ARGS += --K $(SOC_K) --N $(SOC_N) --M $(SOC_M) --lhs_dtype $(SOC_LHS_DTYPE) --quant_mode $(SOC_QUANT_MODE)
endif

OUT_DIR     ?= runs/$(case)/seed_$(seed)
FSDB        ?= $(OUT_DIR)/tb_top.fsdb
COMPILE_LOG ?= $(OUT_DIR)/compile.log
SIM_LOG     ?= $(OUT_DIR)/sim.log
SIM_OPTS    += $(if $(SOC_TIMEOUT_CYCLES),+SOC_TIMEOUT_CYCLES=$(SOC_TIMEOUT_CYCLES),)
COV ?= 0
COV_TYPES ?= line+cond+tgl+branch+fsm
COV_ROOT ?= runs/coverage
COV_VDB_ROOT ?= $(COV_ROOT)/vdb
COV_REPORT_DIR ?= $(COV_ROOT)/urg_report
COV_NAME ?= $(DUT_MODE)_$(case)_seed_$(seed)_S$(MMA_SIZE)_C$(MMA_IA_CACHE_BLOCKS)_P$(MMA_PS_FRAME_COUNT)
COV_COMPILE_DB ?= $(COV_VDB_ROOT)/$(SIMV).vdb
COV_DB ?= $(COV_COMPILE_DB)
COV_ACCEL_SCOPE ?= 1
ifeq ($(filter 1 yes true TRUE,$(COV_ACCEL_SCOPE)),)
COV_HIER_FILE ?=
else ifeq ($(DUT_MODE),axi_soc)
COV_HIER_FILE ?= ./coverage_accel_axi_soc.hier
else ifeq ($(DUT_MODE),axil)
COV_HIER_FILE ?= ./coverage_accel_axil.hier
else
COV_HIER_FILE ?= ./coverage_accel_axil.hier
endif
COVERAGE_GOAL ?= 95
URG_METRICS ?= group
COVERAGE_SIGNOFF_METRICS ?= functional,group
COV_ALLOW_URG_FAIL ?= 1
COV_REPORT_TARGET ?= cov_report
COV_PLAN_ARGS ?=
COV_CODE_URG_METRICS ?= line+cond+tgl+branch+fsm
COV_CODE_SIGNOFF_METRICS ?= line
COV_VDB_MERGE_MODE ?= instance
COV_LINE_EXCLUDE_FILE ?= ./coverage_line_exclude.json
COV_CODE_REPORT_ROOT ?= $(COV_ROOT)/urg_code_by_design
COV_MODULE_ROOT ?= runs/coverage_module
COV_MODULE_PLAN_ARGS ?= --only axil_mem_gen_smoke --only axil_ral_mem_gen_start --only axil_reg_directed \
	--only soc_runtime_ws_int8 --only soc_reg_directed --only soc_runtime_is_int16 --only soc_runtime_per_channel_int8 \
	--only soc_reuse_ws_int8 --only soc_reuse_is_int16 --only soc_reuse_wide_ws_int8 --only soc_reuse_multigroup_ws_int8 --only soc_reuse_multigroup_deep_ws_int8 --only soc_reuse_wide_is_int16 \
	--only soc_saturation_clamp_ws_int8 --only soc_saturation_clamp_is_int8 --only soc_per_channel_clamp_ws_int8 --only soc_requant_directed_clamp_ws_int8 --only soc_tail_ws_int8 --only soc_tail_is_int16 \
	--only soc_tail_per_channel_int16 --only soc_fifo_wrap_tail2_ws_int8 --only soc_unaligned_randlat_ws_int8 --only soc_runtime_per_channel_ws_int16 \
	--only soc_runtime_per_channel_is_int8 --only soc_min_tile_ws_int8 --only soc_offset_activation_ws_int8 \
	--only soc_randlat_is_int8 --only soc_min_tile_is_int16 --only soc_offset_activation_is_int16 --only soc_tail_per_channel_is_int8
COV_SOC_ROOT ?= runs/coverage_soc
COV_SOC_HIER_FILE ?= ./coverage_accel_axi_soc.hier
COV_SOC_PLAN_ARGS ?= --only soc_runtime_ws_int8 --only soc_reg_directed --only soc_runtime_is_int16 --only soc_runtime_per_channel_int8 \
	--only soc_reuse_ws_int8 --only soc_reuse_is_int16 --only soc_reuse_wide_ws_int8 --only soc_reuse_multigroup_ws_int8 --only soc_reuse_multigroup_deep_ws_int8 --only soc_reuse_wide_is_int16 \
	--only soc_saturation_clamp_ws_int8 --only soc_saturation_clamp_is_int8 --only soc_per_channel_clamp_ws_int8 --only soc_requant_directed_clamp_ws_int8 --only soc_tail_ws_int8 --only soc_tail_is_int16 \
	--only soc_tail_per_channel_int16 --only soc_fifo_wrap_tail2_ws_int8 --only soc_unaligned_randlat_ws_int8 --only soc_runtime_per_channel_ws_int16 \
	--only soc_runtime_per_channel_is_int8 --only soc_min_tile_ws_int8 --only soc_offset_activation_ws_int8 \
	--only soc_randlat_is_int8 --only soc_min_tile_is_int16 --only soc_offset_activation_is_int16 --only soc_tail_per_channel_is_int8
COV_COMPILE_OPTS = $(if $(filter 1 yes true TRUE,$(COV)),-cm $(COV_TYPES) -cm_dir $(COV_COMPILE_DB) $(if $(strip $(COV_HIER_FILE)),-cm_hier $(COV_HIER_FILE),),)
COV_SIM_OPTS = $(if $(filter 1 yes true TRUE,$(COV)),-cm $(COV_TYPES) -cm_dir $(COV_DB) -cm_name $(COV_NAME),)

ifeq ($(DUT_MODE),axi_soc)
FILELIST     ?= ../flist/tb_axi_soc.f
MODE_DEFINES += DUT_AXI_SOC
ifeq ($(SOC_APP),runtime)
SIM_OPTS     += +DUT_SEL=axi_soc +SOC_CASE_DIR=$(SOC_CASE_DIR) +SOC_CPU_MEM=$(SOC_RUNTIME_CPU_MEM) +SOC_DATA_MEM=$(SOC_CASE_DIR)/runtime_data.mem +SOC_DATA_MEM_BASE_WORD=$(SOC_RUNTIME_BASE_WORD)
else
SIM_OPTS     += +DUT_SEL=axi_soc +SOC_CASE_DIR=$(SOC_CASE_DIR) +SOC_CPU_MEM=$(SOC_CASE_DIR)/cpu.mem
endif
ifeq ($(SOC_APP),tflm)
RUN_DEPS += tflm_soc_c
else ifeq ($(SOC_APP),tflm_micro_speech)
RUN_DEPS += tflm_micro_speech_soc_c
else ifeq ($(SOC_APP),tflm_hello_world)
RUN_DEPS += tflm_hello_world_soc_c
else ifeq ($(SOC_APP),tflm_person_detection)
RUN_DEPS += tflm_person_detection_soc_c
else ifeq ($(SOC_APP),tflm_mnist_mlp)
RUN_DEPS += tflm_mnist_mlp_soc_c
else ifeq ($(SOC_APP),tflm_mnist_mlp_int16x8)
RUN_DEPS += tflm_mnist_mlp_int16x8_soc_c
else ifeq ($(SOC_APP),tflm_sensor_calibration_int16x8)
RUN_DEPS += tflm_sensor_calibration_int16x8_soc_c
else ifeq ($(SOC_APP),tflm_sensor_calibration_release_20261015)
RUN_DEPS += tflm_sensor_calibration_release_20261015_soc_c
else ifeq ($(SOC_APP),tflm_sensor_calibrator_20261016)
RUN_DEPS += tflm_sensor_calibrator_20261016_soc_c
else ifeq ($(SOC_APP),tflm_sensor_calibration_20261019)
RUN_DEPS += tflm_sensor_calibration_20261019_soc_c
else ifeq ($(SOC_APP),tflm_mnist_cnn)
RUN_DEPS += tflm_mnist_cnn_soc_c
else ifeq ($(SOC_APP),runtime)
RUN_DEPS += soc_case soc_runtime_c
else
RUN_DEPS += soc_c
endif
else ifeq ($(DUT_MODE),axil)
FILELIST     ?= ../flist/tb_axil.f
MODE_DEFINES += DUT_AXIL
SIM_OPTS     += +DUT_SEL=axil
else
$(error Unsupported DUT_MODE=$(DUT_MODE). Supported modes are axil and axi_soc)
endif

ifeq ($(DUMPOPTS),1)
DUMPFSDB += +dump_fsdb
endif

ifneq ($(strip $(NOVAS_HOME)),)
FSDB_PLI = -P $(NOVAS_HOME)/share/PLI/VCS/LINUX64/novas.tab $(NOVAS_HOME)/share/PLI/VCS/LINUX64/pli.a
endif
VCS_OPTS = -cpp $(VCS_CXX) -cc $(VCS_CC) -LDFLAGS -Wl,--no-as-needed \
           -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -lca \
           -Mdir=$(SIMV).csrc \
           $(COV_COMPILE_OPTS) \
           $(UVM_VER) \
           $(FSDB_PLI)
MMA_PARAM_OPTS = -pvalue+tb_top.DUT_SIZE=$(MMA_SIZE) \
                 -pvalue+tb_top.DUT_IA_CACHE_BLOCKS=$(MMA_IA_CACHE_BLOCKS) \
                 -pvalue+tb_top.DUT_PS_FRAME_COUNT=$(MMA_PS_FRAME_COUNT) \
	                 -pvalue+tb_top.DUT_CPU_MEM_DP=$(SOC_CPU_MEM_DP) \
	                 -pvalue+tb_top.DUT_AXI_READ_OUTSTANDING=$(SOC_AXI_READ_OUTSTANDING) \
	                 -pvalue+tb_top.DUT_AXI_WRITE_OUTSTANDING=$(SOC_AXI_WRITE_OUTSTANDING) \
	                 -pvalue+tb_top.DUT_CPU_ENABLE_ICACHE=$(SOC_CPU_ENABLE_ICACHE) \
	                 -pvalue+tb_top.DUT_BYPASS_RAM_PINGPONG=$(SOC_BYPASS_RAM_PINGPONG) \
	                 -pvalue+tb_top.DUT_RAM_WRITE_TIMING_BUFFER=$(SOC_RAM_WRITE_TIMING_BUFFER)

SIM_OPTS   ?=
VERDI_OPTS ?=

VCS_FILELISTS_L1 := $(shell awk '$$1 == "-f" { print $$2 }' $(if $(FILELIST),$(FILELIST),/dev/null) 2>/dev/null)
VCS_FILELISTS_L2 := $(shell awk '$$1 == "-f" { print $$2 }' $(if $(VCS_FILELISTS_L1),$(VCS_FILELISTS_L1),/dev/null) 2>/dev/null)
VCS_FILELISTS_L3 := $(shell awk '$$1 == "-f" { print $$2 }' $(if $(VCS_FILELISTS_L2),$(VCS_FILELISTS_L2),/dev/null) 2>/dev/null)
VCS_FILELISTS := $(sort $(FILELIST) $(VCS_FILELISTS_L1) $(VCS_FILELISTS_L2) $(VCS_FILELISTS_L3))
VCS_SRC_DEPS := $(shell awk '{ sub(/\/\/.*/, ""); if ($$1 != "" && $$1 != "-f" && $$1 !~ /^\+/) print $$1 }' $(if $(VCS_FILELISTS),$(VCS_FILELISTS),/dev/null) 2>/dev/null)

run: sim

soc_case:
> @mkdir -p $(SOC_CASE_DIR)
> @python3 ../tb/generate_axi_soc_case.py $(SOC_GEN_ARGS) --out_dir $(SOC_CASE_DIR)

soc_c: soc_case
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[SOC_C] $(SOC_C_SRC) -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GCC) $(SOC_ARCH_FLAGS) $(SOC_OPT_LEVEL) $(SOC_HW_DEFINES) -ffreestanding -nostdlib -nostartfiles -DPICOSOC_UART_CLKDIV=$(SOC_UART_CLKDIV) -I../soc_csrc -I$(SOC_CASE_DIR) $(SOC_LINK_FLAGS) ../soc_csrc/start.S ../soc_csrc/picosoc_bsp.c ../soc_csrc/dsa_accel_mmio.c $(SOC_CASE_DIR)/soc_case.c $(SOC_C_SRC) $(SOC_BARE_LIBS) -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

$(SOC_RUNTIME_CPU_MEM): $(SOC_RUNTIME_C_SRC) ../soc_csrc/start.S ../soc_csrc/picosoc_bsp.c ../soc_csrc/picosoc_bsp.h ../soc_csrc/dsa_accel_mmio.c ../soc_csrc/dsa_accel_mmio.h ../soc_csrc/link.ld Makefile
> @mkdir -p $(@D)
> @echo "[SOC_RUNTIME_C] $(SOC_RUNTIME_C_SRC) -> $@"
> $(SOC_GCC) $(SOC_ARCH_FLAGS) $(SOC_OPT_LEVEL) $(SOC_HW_DEFINES) -DSOC_RUNTIME_CASE_BASE=$(SOC_RUNTIME_BASE_ADDR) -ffreestanding -nostdlib -nostartfiles -DPICOSOC_UART_CLKDIV=$(SOC_UART_CLKDIV) -I../soc_csrc $(SOC_LINK_FLAGS) ../soc_csrc/start.S ../soc_csrc/picosoc_bsp.c ../soc_csrc/dsa_accel_mmio.c $(SOC_RUNTIME_C_SRC) $(SOC_BARE_LIBS) -o $(@D)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(@D)/cpu.elf $(@D)/cpu.bin
> python3 ../tb/elf_to_mem.py $(@D)/cpu.bin $@ --depth $(SOC_CPU_MEM_DP)

soc_runtime_c: $(SOC_RUNTIME_CPU_MEM)

$(TFLM_LIB): $(TFLM_RV32_REBUILD_DEPS)
> $(MAKE) -C $(TFLM_DIR) BUILD_DIR=$(TFLM_BUILD_DIR) USE_NMSIS_NN=$(TFLM_NMSIS_NN_ENABLE) CC=$(SOC_GCC) CXX=$(SOC_GXX) AR=$(SOC_AR) TARGET_FLAGS="$(SOC_ARCH_FLAGS) $(SOC_OPT_LEVEL) $(SOC_HW_DEFINES) $(TFLM_EXTRA_DEFINES) -DTFLM_SOC_PROGRESS $(TFLM_SOC_MMA_DEFINE)" BUILD_TYPE=Release $(TFLM_BUILD_DIR)/libtflite-micro.a

$(TFLM_HOST_LIB):
> $(MAKE) -C $(TFLM_DIR) BUILD_DIR=$(TFLM_HOST_BUILD_DIR) TARGET_FLAGS="$(HOST_OPT_LEVEL)" BUILD_TYPE=Release $(TFLM_HOST_BUILD_DIR)/libtflite-micro.a

$(TFLM_MNIST_ACCURACY_BIN): ../tools/tflm_mnist_accuracy.cc $(TFLM_HOST_LIB)
> $(CXX) -std=c++17 $(HOST_OPT_LEVEL) -fno-rtti -fno-exceptions -fno-threadsafe-statics -DTF_LITE_DISABLE_X86_NEON -DTF_LITE_STRIP_ERROR_STRINGS -I$(TFLM_ROOT) -I$(TFLM_GENFILES) -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/gemmlowp -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/flatbuffers/include -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/kissfft -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/ruy $< $(TFLM_HOST_LIB) -lm -o $@

tflm_mnist_accuracy: $(TFLM_MNIST_ACCURACY_BIN)

tflm_mnist_accuracy_run: $(TFLM_MNIST_ACCURACY_BIN)
> python3 ../tools/analyze_mnist_quant_accuracy.py --runner $(TFLM_MNIST_ACCURACY_BIN) --model_dir $(TFLM_MNIST_MLP_MODEL_DIR) --count $(TFLM_MNIST_ACCURACY_COUNT) --out_dir $(TFLM_MNIST_ACCURACY_OUT)

$(TFLM_MICRO_SPEECH_FEATURE_DUMP): ../tools/dump_micro_speech_features.cc $(TFLM_HOST_LIB) $(TFLM_MICRO_SPEECH_MODEL_DATA_CC) $(TFLM_MICRO_SPEECH_AUDIO_DATA_SRCS)
> $(CXX) -std=c++17 $(HOST_OPT_LEVEL) -fno-rtti -fno-exceptions -fno-threadsafe-statics -DTF_LITE_DISABLE_X86_NEON -DTF_LITE_STRIP_ERROR_STRINGS -I$(TFLM_ROOT) -I$(TFLM_GENFILES) -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/gemmlowp -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/flatbuffers/include -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/kissfft -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/ruy ../tools/dump_micro_speech_features.cc $(TFLM_MICRO_SPEECH_MODEL_DATA_CC) $(TFLM_MICRO_SPEECH_AUDIO_DATA_SRCS) $(TFLM_HOST_LIB) -lm -o $@

$(TFLM_MICRO_SPEECH_FEATURES_CC): $(TFLM_MICRO_SPEECH_FEATURE_DUMP)
> $< > $@

tflm_soc_c: $(TFLM_LIB)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] my_model -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles $(SOC_LINK_FLAGS) $(TFLM_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_micro_speech_soc_c: $(TFLM_LIB) $(TFLM_MICRO_SPEECH_FEATURES_CC)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] micro_speech -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles $(SOC_LINK_FLAGS) $(TFLM_MICRO_SPEECH_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_hello_world_soc_c: $(TFLM_LIB)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] hello_world -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles $(SOC_LINK_FLAGS) $(TFLM_HELLO_WORLD_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_person_detection_soc_c: $(TFLM_LIB)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] person_detection -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles $(SOC_LINK_FLAGS) $(TFLM_PERSON_DETECTION_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_mnist_mlp_soc_c: $(TFLM_LIB) $(TFLM_MNIST_MLP_APP_SRCS)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] mnist_mlp -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles $(SOC_LINK_FLAGS) $(TFLM_MNIST_MLP_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_mnist_mlp_int16x8_soc_c: $(TFLM_LIB) $(TFLM_MNIST_MLP_INT16X8_APP_SRCS)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] mnist_mlp_int16x8 -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -DTFLM_MNIST_MLP_INT16X8=1 -DTFLM_MNIST_MLP_ARENA_SIZE=$(TFLM_MNIST_MLP_INT16X8_ARENA_SIZE) -nostartfiles $(SOC_LINK_FLAGS) $(TFLM_MNIST_MLP_INT16X8_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_sensor_calibration_int16x8_soc_c: $(TFLM_LIB) $(TFLM_SENSOR_CALIBRATION_APP_SRCS)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] sensor_calibration_int16x8 -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -DTFLM_SENSOR_CALIBRATION_ARENA_SIZE=$(TFLM_SENSOR_CALIBRATION_ARENA_SIZE) -nostartfiles $(SOC_LINK_FLAGS) $(TFLM_SENSOR_CALIBRATION_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_sensor_calibration_release_20261015_soc_c: $(TFLM_LIB) $(TFLM_SENSOR_CALIBRATION_RELEASE_SOC_APP_SRCS)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] sensor_calibration_release_20261015 -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -I$(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR) -nostartfiles $(SOC_LINK_FLAGS) $(TFLM_SENSOR_CALIBRATION_RELEASE_SOC_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_sensor_calibrator_20261016_soc_c: $(TFLM_LIB) $(TFLM_SENSOR_CALIBRATOR_20261016_SOC_APP_SRCS) $(TFLM_SENSOR_CALIBRATOR_20261016_MODEL)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] sensor_calibrator_20261016 -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles $(SOC_LINK_FLAGS) -Wa,-I$(dir $(TFLM_SENSOR_CALIBRATOR_20261016_MODEL)) $(TFLM_SENSOR_CALIBRATOR_20261016_SOC_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_sensor_calibration_20261019_soc_c: $(TFLM_LIB) $(TFLM_SENSOR_CALIBRATION_20261019_SOC_APP_SRCS) $(TFLM_SENSOR_CALIBRATION_20261019_MODEL)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] sensor_calibration_20261019 -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -DTFLM_SENSOR_CALIBRATION_20261019_ARENA_SIZE=$(TFLM_SENSOR_CALIBRATION_20261019_ARENA_SIZE) -nostartfiles $(SOC_LINK_FLAGS) -Wa,-I$(dir $(TFLM_SENSOR_CALIBRATION_20261019_MODEL)) $(TFLM_SENSOR_CALIBRATION_20261019_SOC_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_mnist_cnn_soc_c: $(TFLM_LIB) $(TFLM_MNIST_CNN_APP_SRCS)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] mnist_cnn -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles $(SOC_LINK_FLAGS) $(TFLM_MNIST_CNN_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

$(SIMV): $(VCS_FILELISTS) $(VCS_SRC_DEPS) Makefile
> @mkdir -p $(OUT_DIR)
> @echo "[COMPILE] VCS -> $(SIMV) (DUT_MODE=$(DUT_MODE), case=$(case), seed=$(seed))"
> $(VCS) $(VCS_OPTS) $(MMA_PARAM_OPTS) $(INCDIRS:%=-y %) $(DEFINES:%=+define+%) $(MODE_DEFINES:%=+define+%) -f $(FILELIST) -top $(TOP) -l $(COMPILE_LOG) -o $(SIMV) +vcs+initreg+random

com: $(SIMV)

force_com:
> @rm -f $(SIMV)
> @rm -f $(SIMV).daidir/.vcs.timestamp
> @if [ "$(COV)" = "1" ] || [ "$(COV)" = "yes" ] || [ "$(COV)" = "true" ] || [ "$(COV)" = "TRUE" ]; then rm -rf "$(SIMV).daidir" "$(SIMV).csrc" "$(COV_COMPILE_DB)"; fi
> $(MAKE) --no-print-directory com

sim: $(SIMV) $(RUN_DEPS)
> @mkdir -p $(OUT_DIR)
> @if [ "$(COV)" = "1" ] || [ "$(COV)" = "yes" ] || [ "$(COV)" = "true" ] || [ "$(COV)" = "TRUE" ]; then mkdir -p "$(COV_VDB_ROOT)"; fi
> @echo "[SIM] $(SIM_RUNNER) $(SIM_OPTS) case=$(case) seed=$(seed) FSDB=$(FSDB)"
> $(SIM_RUNNER) $(COV_SIM_OPTS) $(SIM_OPTS) $(SIM_ARGS) $(DUMPFSDB) +fsdbfile+$(FSDB) +UVM_TESTNAME=$(case) +case=$(case) +ntb_random_seed=$(seed) -l $(SIM_LOG) +vcs+initreg+0

cov_report:
> @mkdir -p $(COV_ROOT)
> @dbs=$$(find "$(COV_VDB_ROOT)" -maxdepth 1 -type d -name '*.vdb' 2>/dev/null | sort); \
> if [ -z "$$dbs" ]; then echo "[COV] no VDB found under $(COV_VDB_ROOT)"; exit 1; fi; \
> echo "[COV] merging VDBs:"; printf '  %s\n' $$dbs; \
> tmp_report="$(COV_REPORT_DIR).tmp"; \
> rm -rf "$$tmp_report" merged.vdb; \
> if $(URG) -full64 -metric "$(URG_METRICS)" -dir $$dbs -report "$$tmp_report" -format both -dbname merged.vdb -log "$(COV_ROOT)/urg.log"; then \
>     rm -rf "$(COV_REPORT_DIR)"; \
>     mv "$$tmp_report" "$(COV_REPORT_DIR)"; \
> else \
>     rc=$$?; \
>     rm -rf "$$tmp_report"; \
>     if [ "$(COV_ALLOW_URG_FAIL)" = "1" ] || [ "$(COV_ALLOW_URG_FAIL)" = "yes" ] || [ "$(COV_ALLOW_URG_FAIL)" = "true" ] || [ "$(COV_ALLOW_URG_FAIL)" = "TRUE" ]; then \
>         echo "[COV] URG failed with rc=$$rc; using simulation-log functional coverage for sign-off"; \
>         rm -rf "$(COV_REPORT_DIR)"; \
>         mkdir -p "$(COV_REPORT_DIR)"; \
>         printf 'URG failed with rc=%s. Sign-off summary uses simulation-log functional coverage fallback.\n' "$$rc" > "$(COV_REPORT_DIR)/urg_fallback.txt"; \
>     else \
>         exit $$rc; \
>     fi; \
> fi
> @python3 ./coverage_summary.py --urg-report "$(COV_REPORT_DIR)" --sim-root . --cov-root "$(COV_ROOT)" --goal "$(COVERAGE_GOAL)" --signoff-metrics "$(COVERAGE_SIGNOFF_METRICS)" --out-md "$(COV_ROOT)/coverage_report_summary.md" --out-json "$(COV_ROOT)/coverage_report_summary.json"

cov_plan:
> @python3 ./run_coverage_plan.py --plan ./coverage_plan.json --goal "$(COVERAGE_GOAL)" --report-target "$(COV_REPORT_TARGET)" $(COV_PLAN_ARGS)

cov_code_report:
> @mkdir -p "$(COV_ROOT)" "$(COV_CODE_REPORT_ROOT)"
> @dbs=$$(find "$(COV_VDB_ROOT)" -maxdepth 1 -type d -name '*.vdb' 2>/dev/null | sort); \
> if [ -z "$$dbs" ]; then echo "[COV] no VDB found under $(COV_VDB_ROOT)"; exit 1; fi; \
> report_args=""; \
> urg_failed=0; \
> for db in $$dbs; do \
>     name=$$(basename "$$db" .vdb); \
>     report_dir="$(COV_CODE_REPORT_ROOT)/$$name"; \
>     rm -rf "$$report_dir" "$(COV_CODE_REPORT_ROOT)/$$name.vdb"; \
>     echo "[COV_CODE] report $$name from $$db"; \
>     if $(URG) -full64 -metric "$(COV_CODE_URG_METRICS)" -dir "$$db" -report "$$report_dir" -format both -dbname "$(COV_CODE_REPORT_ROOT)/$$name.vdb" -log "$(COV_CODE_REPORT_ROOT)/$$name.urg.log"; then \
>         report_args="$$report_args --urg-report $$report_dir"; \
>     else \
>         rc=$$?; \
>         urg_failed=1; \
>         rm -rf "$$report_dir"; \
>         if [ "$(COV_ALLOW_URG_FAIL)" = "1" ] || [ "$(COV_ALLOW_URG_FAIL)" = "yes" ] || [ "$(COV_ALLOW_URG_FAIL)" = "true" ] || [ "$(COV_ALLOW_URG_FAIL)" = "TRUE" ]; then \
>             echo "[COV_CODE] URG failed for $$name with rc=$$rc; coverage_summary.py will use VCS VDB direct fallback"; \
>         else \
>             exit $$rc; \
>         fi; \
>     fi; \
> done; \
> if [ $$urg_failed -ne 0 ]; then echo "[COV_CODE] one or more URG reports failed; keeping VDB fallback evidence"; fi; \
> python3 ./coverage_summary.py $$report_args --sim-root . --cov-root "$(COV_ROOT)" --goal "$(COVERAGE_GOAL)" --signoff-metrics "$(COV_CODE_SIGNOFF_METRICS)" --vdb-merge-mode "$(COV_VDB_MERGE_MODE)" $(if $(strip $(COV_LINE_EXCLUDE_FILE)),--line-exclude-file "$(COV_LINE_EXCLUDE_FILE)",) --out-md "$(COV_ROOT)/coverage_code_report_summary.md" --out-json "$(COV_ROOT)/coverage_code_report_summary.json"

coverage_module:
> $(MAKE) cov_clean COV_ROOT=$(COV_MODULE_ROOT)
> $(MAKE) cov_plan COVERAGE_GOAL=$(COVERAGE_GOAL) COV_REPORT_TARGET=cov_code_report COV_PLAN_ARGS='$(COV_MODULE_PLAN_ARGS) --make-var COV_ROOT=$(COV_MODULE_ROOT) --make-var COV_ACCEL_SCOPE=1 --make-var COV_VDB_MERGE_MODE=definition'

coverage_soc:
> $(MAKE) cov_clean COV_ROOT=$(COV_SOC_ROOT)
> $(MAKE) cov_plan COVERAGE_GOAL=$(COVERAGE_GOAL) COV_REPORT_TARGET=cov_code_report COV_PLAN_ARGS='$(COV_SOC_PLAN_ARGS) --make-var COV_ROOT=$(COV_SOC_ROOT) --make-var COV_ACCEL_SCOPE=1 --make-var COV_HIER_FILE=$(COV_SOC_HIER_FILE) --make-var COV_VDB_MERGE_MODE=definition'

coverage: coverage_module

cov_clean:
> rm -rf "$(COV_ROOT)"

soc_regress:
> @python3 ./run_axi_soc_c_regression.py --iterations $(SOC_REGRESS_ITERS) --start-seed $(SOC_REGRESS_START_SEED) --timeout $(SOC_REGRESS_TIMEOUT) --log-root $(SOC_REGRESS_LOG_ROOT) --sizes "$(SOC_SIZE_LIST)" --cache-blocks "$(SOC_CACHE_BLOCKS_LIST)" --ps-frame-counts "$(SOC_PS_FRAME_COUNT_LIST)" --dataflow-modes "$(SOC_DATAFLOW_MODE_LIST)" --lhs-dtypes "$(SOC_REGRESS_LHS_DTYPE_LIST)" --quant-modes "$(SOC_REGRESS_QUANT_MODE_LIST)" --dim-multiple $(SOC_REGRESS_DIM_MULTIPLE) --sim-args "$(SOC_REGRESS_SIM_ARGS)" --ddr-cmd-max-lat $(SOC_REGRESS_DDR_CMD_MAX_LAT) --ddr-w-max-lat $(SOC_REGRESS_DDR_W_MAX_LAT) --ddr-rsp-max-lat $(SOC_REGRESS_DDR_RSP_MAX_LAT) $(if $(SOC_REGRESS_SOC_TIMEOUT_CYCLES),--soc-timeout-cycles $(SOC_REGRESS_SOC_TIMEOUT_CYCLES),) $(if $(filter 1 yes true TRUE,$(SOC_REGRESS_DDR_RAND_LAT)),--ddr-rand-lat,) $(if $(filter 1 yes true TRUE,$(SOC_REGRESS_UNALIGNED_LAYOUT)),--unaligned-layout,) $(if $(SOC_MIN_DIM),--min-dim $(SOC_MIN_DIM),) $(if $(SOC_MAX_DIM),--max-dim $(SOC_MAX_DIM),)

soc_perf_sweep:
> @python3 ./run_axi_soc_perf_sweep.py --seed $(SOC_PERF_SEED) --timeout $(SOC_PERF_TIMEOUT) --log-root $(SOC_PERF_LOG_ROOT) --dims "$(SOC_PERF_DIMS)" --sizes "$(SOC_PERF_SIZE_LIST)" --cache-blocks "$(SOC_PERF_CACHE_BLOCKS_LIST)" --ps-frame-counts "$(SOC_PERF_PS_FRAME_COUNT_LIST)" --dataflow-modes "$(SOC_PERF_DATAFLOW_MODE_LIST)" --lhs-dtypes "$(SOC_PERF_LHS_DTYPE_LIST)" --quant-modes "$(SOC_PERF_QUANT_MODE_LIST)" --ia-reuse-list "$(SOC_PERF_IA_REUSE_LIST)" --w-reuse-list "$(SOC_PERF_W_REUSE_LIST)" --jobs $(SOC_PERF_JOBS) --sim-args "$(SOC_PERF_SIM_ARGS)" --ddr-cmd-max-lat $(SOC_PERF_DDR_CMD_MAX_LAT) --ddr-w-max-lat $(SOC_PERF_DDR_W_MAX_LAT) --ddr-rsp-max-lat $(SOC_PERF_DDR_RSP_MAX_LAT) $(if $(SOC_PERF_SOC_TIMEOUT_CYCLES),--soc-timeout-cycles $(SOC_PERF_SOC_TIMEOUT_CYCLES),) $(if $(SOC_PERF_RAM_FIXED_LAT),--ram-fixed-lat $(SOC_PERF_RAM_FIXED_LAT),) $(if $(filter 1 yes true TRUE,$(SOC_PERF_INCLUDE_AUTO)),--include-auto,) $(if $(filter 1 yes true TRUE,$(SOC_PERF_KEEP_GOING)),--keep-going,) $(if $(filter 1 yes true TRUE,$(SOC_PERF_FORCE_COMPILE)),--force-compile,) $(if $(filter 1 yes true TRUE,$(SOC_PERF_DDR_RAND_LAT)),--ddr-rand-lat,)

npu_top_regress:
> $(MAKE) -C ../top_regression run_random SIZE=$(TOP_REGRESS_SIZE) IA_CACHE_BLOCKS=$(TOP_REGRESS_IA_CACHE_BLOCKS) PS_FRAME_COUNT=$(TOP_REGRESS_PS_FRAME_COUNT) AXI_READ_OUTSTANDING=$(TOP_REGRESS_AXI_READ_OUTSTANDING) COUNT=$(TOP_REGRESS_COUNT) SEED=$(TOP_REGRESS_SEED) TRACE=$(TOP_REGRESS_TRACE) RANDOM_GEN_ARGS='$(TOP_REGRESS_RANDOM_GEN_ARGS)' SIM_ARGS='$(TOP_REGRESS_SIM_ARGS)'

tflm_my_model_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm SOC_CASE=axi_soc_tflm case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_MY_MODEL_TIMEOUT_CYCLES))

tflm_micro_speech_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_micro_speech SOC_CASE=axi_soc_tflm_micro_speech case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_MICRO_SPEECH_TIMEOUT_CYCLES))

tflm_hello_world_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_hello_world SOC_CASE=axi_soc_tflm_hello_world case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_HELLO_WORLD_TIMEOUT_CYCLES))

tflm_person_detection_run: DUMPOPTS = 0
tflm_person_detection_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_person_detection SOC_CASE=axi_soc_tflm_person_detection case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_PERSON_DETECTION_TIMEOUT_CYCLES)) DUMPOPTS=$(DUMPOPTS)

tflm_mnist_mlp_run: DUMPOPTS = 0
tflm_mnist_mlp_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_mnist_mlp SOC_CASE=$(TFLM_MNIST_MLP_SOC_CASE) case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_MNIST_MLP_TIMEOUT_CYCLES)) DUMPOPTS=$(DUMPOPTS)

tflm_mnist_mlp_int16x8_run: DUMPOPTS = 0
tflm_mnist_mlp_int16x8_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_mnist_mlp_int16x8 SOC_CASE=$(TFLM_MNIST_MLP_INT16X8_SOC_CASE) case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_MNIST_MLP_TIMEOUT_CYCLES)) DUMPOPTS=$(DUMPOPTS)

tflm_sensor_calibration_int16x8_run: DUMPOPTS = 0
tflm_sensor_calibration_int16x8_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_sensor_calibration_int16x8 SOC_CASE=$(TFLM_SENSOR_CALIBRATION_SOC_CASE) case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_SENSOR_CALIBRATION_TIMEOUT_CYCLES)) DUMPOPTS=$(DUMPOPTS)

tflm_sensor_calibration_release_20261015_host: $(TFLM_SENSOR_CALIBRATION_RELEASE_HOST_SRCS) $(TFLM_HOST_LIB)
> $(CXX) -std=c++17 $(HOST_OPT_LEVEL) -fno-rtti -fno-exceptions -fno-threadsafe-statics -DTF_LITE_DISABLE_X86_NEON -DTF_LITE_STRIP_ERROR_STRINGS -I$(TFLM_ROOT) -I$(TFLM_GENFILES) -I../soc_csrc -I$(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR) -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/gemmlowp -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/flatbuffers/include -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/kissfft -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/ruy ../tools/tflm_sensor_calibration_release_host.cc $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_data.cc $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_model_data.cc $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_host_test_data.cc $(TFLM_SENSOR_CALIBRATION_RELEASE_MODEL_DIR)/sensor_calibration_release_soc_test_data.cc $(TFLM_HOST_LIB) -lm -o $(TFLM_SENSOR_CALIBRATION_RELEASE_HOST_BIN)

tflm_sensor_calibration_release_20261015_host_run: tflm_sensor_calibration_release_20261015_host
> $(TFLM_SENSOR_CALIBRATION_RELEASE_HOST_BIN)

tflm_sensor_calibration_release_20261015_run: DUMPOPTS = 0
tflm_sensor_calibration_release_20261015_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_sensor_calibration_release_20261015 SOC_CASE=$(TFLM_SENSOR_CALIBRATION_RELEASE_SOC_CASE) case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_SENSOR_CALIBRATION_RELEASE_TIMEOUT_CYCLES)) DUMPOPTS=$(DUMPOPTS)

tflm_sensor_calibrator_20261016_run: DUMPOPTS = 0
tflm_sensor_calibrator_20261016_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_sensor_calibrator_20261016 SOC_CASE=$(TFLM_SENSOR_CALIBRATOR_20261016_SOC_CASE) case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(TFLM_SENSOR_CALIBRATOR_20261016_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_SENSOR_CALIBRATOR_20261016_TIMEOUT_CYCLES)) DUMPOPTS=$(DUMPOPTS)

tflm_sensor_calibration_20261019_run: DUMPOPTS = 0
tflm_sensor_calibration_20261019_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_sensor_calibration_20261019 SOC_CASE=$(TFLM_SENSOR_CALIBRATION_20261019_SOC_CASE) case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_SENSOR_CALIBRATION_20261019_TIMEOUT_CYCLES)) DUMPOPTS=$(DUMPOPTS)

tflm_mnist_cnn_run: DUMPOPTS = 0
tflm_mnist_cnn_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_mnist_cnn SOC_CASE=$(TFLM_MNIST_CNN_SOC_CASE) case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_MNIST_CNN_TIMEOUT_CYCLES)) DUMPOPTS=$(DUMPOPTS)

tflm_run: tflm_hello_world_run

vd:
> @echo "[VERDI] case=$(case) seed=$(seed) FSDB=$(FSDB)"
> @if [ ! -f "$(FSDB)" ]; then echo "[ERROR] FSDB not found: $(FSDB)"; echo "        Please run: make run DUT_MODE=$(DUT_MODE) case=$(case) seed=$(seed)"; exit 1; fi
> @echo "[VERDI] DUT_MODE=$(DUT_MODE) FILELIST=$(FILELIST)"
> $(VERDI) -sv $(INCDIRS:%=-y %) $(DEFINES:%=+define+%) $(MODE_DEFINES:%=+define+%) -f $(FILELIST) +incdir+$(UVM_HOME)/src -top $(TOP) $(VERDI_OPTS) -ssf $(FSDB) &

clean:
> rm -rf $(SIMV) simv_* csrc *.csrc simv.daidir simv_*.daidir *.log *.key novas.* verdiLog runs

help:
> @echo "Targets:"
> @echo "  make run   [DUT_MODE=axil|axi_soc] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "             [MMA_SIZE=16] [MMA_IA_CACHE_BLOCKS=4] [MMA_PS_FRAME_COUNT=<MMA_SIZE>]"
> @echo "             [SOC_APP=runtime|case|tflm]  # runtime reuses one O3 CPU app and reads runtime_data.mem"
> @echo "  make com   [DUT_MODE=axil|axi_soc] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "  make force_com [DUT_MODE=axil|axi_soc]  # rebuild simv"
> @echo "  make sim   [DUT_MODE=axil|axi_soc] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "  make soc_regress [SOC_REGRESS_ITERS=<n>] [SOC_REGRESS_START_SEED=<int>] [SOC_MIN_DIM=<n>] [SOC_MAX_DIM=<n>] [SOC_REGRESS_DIM_MULTIPLE=<n>]"
> @echo "                   [SOC_SIZE_LIST='8 16'] [SOC_CACHE_BLOCKS_LIST='2 4'] [SOC_REGRESS_DDR_RAND_LAT=1] [SOC_REGRESS_UNALIGNED_LAYOUT=1]"
> @echo "  make soc_perf_sweep [SOC_PERF_DIMS='32x32x32'] [SOC_PERF_SIZE_LIST='8 16'] [SOC_PERF_CACHE_BLOCKS_LIST='2 4']"
> @echo "                      [SOC_PERF_INCLUDE_AUTO=1] [SOC_PERF_FORCE_COMPILE=1] [SOC_PERF_JOBS=4] [SOC_PERF_DDR_RAND_LAT=1]"
> @echo "  make npu_top_regress [TOP_REGRESS_SIZE=4] [TOP_REGRESS_IA_CACHE_BLOCKS=4] [TOP_REGRESS_COUNT=20]"
> @echo "  make run COV=1 DUT_MODE=axil case=ai_mem_gen_smoke_test seed=1  # collect VCS code coverage"
> @echo "  make coverage COVERAGE_GOAL=95                                 # clean, run curated suite, and sign off VCS code coverage"
> @echo "             [COV_ACCEL_SCOPE=1] limits coverage to the accelerator hierarchy"
> @echo "  make coverage_module COVERAGE_GOAL=95                          # accelerator-module scoped coverage"
> @echo "  make coverage_soc COVERAGE_GOAL=95                             # soc_top scoped integration coverage"
> @echo "  make cov_plan COVERAGE_GOAL=95                                 # run curated coverage suite"
> @echo "  make cov_report COVERAGE_GOAL=95 [URG_METRICS=group|line+branch+group]"
> @echo "             [COVERAGE_SIGNOFF_METRICS=functional,group]         # merge VDBs and check threshold"
> @echo "  make cov_code_report COVERAGE_GOAL=95                          # report code coverage per compile design"
> @echo "  make cov_clean                                                  # remove runs/coverage only"
> @echo "  make tflm_run"
> @echo "  make tflm_hello_world_run"
> @echo "  make tflm_micro_speech_run"
> @echo "  make tflm_person_detection_run"
> @echo "  make tflm_mnist_mlp_run"
> @echo "  make tflm_mnist_mlp_int16x8_run"
> @echo "  make tflm_sensor_calibration_int16x8_run"
> @echo "  make tflm_sensor_calibration_release_20261015_host_run"
> @echo "  make tflm_sensor_calibration_release_20261015_run SOC_CPU_MEM_DP=131072"
> @echo "  make tflm_mnist_cnn_run"
> @echo "  make tflm_my_model_run"
> @echo "  make vd    [DUT_MODE=axil|axi_soc] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "  make clean"
> @echo "  make help"
> @echo ""
> @echo "Output layout:"
> @echo "  runs/<case>/seed_<seed>/compile.log"
> @echo "  runs/<case>/seed_<seed>/sim.log"
> @echo "  runs/<case>/seed_<seed>/tb_top.fsdb"
> @echo ""
> @echo "case(also UVM_TESTNAME) -> sequence mapping (from veri/test/ai_test_pkg.sv):"
> @echo "  ai_mem_gen_smoke_test         -> ai_mem_gen_smoke_seq"
> @echo "  ai_ral_mem_gen_on_calc_start_test -> ai_ral_mem_gen_on_calc_start_seq"
> @echo ""
> @echo "Common examples:"
> @echo "  make run DUT_MODE=axil case=ai_mem_gen_smoke_test seed=20260413"
> @echo "  make run DUT_MODE=axil case=ai_ral_mem_gen_on_calc_start_test seed=20260413"
> @echo "  make run DUT_MODE=axi_soc case=ai_axi_soc_c_test SOC_K=24 SOC_N=32 SOC_M=16 SOC_LHS_DTYPE=1 SOC_QUANT_MODE=0 SOC_LHS_OFFSET=0 SOC_RHS_OFFSET=0 SOC_DST_OFFSET=0"
> @echo "  make run DUT_MODE=axi_soc case=ai_axi_soc_c_test SOC_RANDOM=1 SOC_FIX_MODE=0 SOC_SEED=20260629"
> @echo "  make run DUT_MODE=axi_soc case=ai_axi_soc_c_test SOC_UART_CLKDIV=8"
> @echo "  make soc_regress SOC_REGRESS_ITERS=20 SOC_MIN_DIM=16 SOC_MAX_DIM=32"
> @echo "  make tflm_run"
> @echo "  make tflm_hello_world_run"
> @echo "  make tflm_micro_speech_run"
> @echo "  make tflm_person_detection_run"
> @echo "  make tflm_mnist_mlp_run"
> @echo "  make tflm_mnist_mlp_int16x8_run"
> @echo "  make tflm_sensor_calibration_int16x8_run"
> @echo "  make tflm_mnist_cnn_run"
> @echo "  make tflm_my_model_run"
> @echo "  make run DUT_MODE=axi_soc case=ai_axi_soc_c_test VCS_CC=gcc-4.8 VCS_CXX=g++-4.8"
> @echo "  make vd DUT_MODE=axil case=ai_mem_gen_smoke_test seed=20260413"
.PHONY: run soc_case soc_c soc_runtime_c tflm_soc_c tflm_micro_speech_soc_c tflm_hello_world_soc_c tflm_person_detection_soc_c tflm_mnist_mlp_soc_c tflm_mnist_mlp_int16x8_soc_c tflm_sensor_calibration_int16x8_soc_c tflm_sensor_calibration_release_20261015_soc_c tflm_sensor_calibrator_20261016_soc_c tflm_sensor_calibration_20261019_soc_c tflm_sensor_calibration_20261019_run tflm_sensor_calibration_release_20261015_host tflm_sensor_calibration_release_20261015_host_run tflm_sensor_calibration_release_20261015_run tflm_sensor_calibrator_20261016_run tflm_mnist_cnn_soc_c tflm_mnist_accuracy tflm_mnist_accuracy_run tflm_run tflm_micro_speech_run tflm_hello_world_run tflm_person_detection_run tflm_mnist_mlp_run tflm_mnist_mlp_int16x8_run tflm_sensor_calibration_int16x8_run tflm_sensor_calibrator_20261016_run tflm_mnist_cnn_run tflm_my_model_run com force_com sim cov_report cov_code_report cov_plan coverage_module coverage_soc cov_clean soc_regress vd clean help
