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
VERDI ?= verdi
SIM_LAUNCHER ?= ./run_simv_lxc.sh
SIM_RUNNER ?= $(SIM_LAUNCHER) ./$(SIMV)
SIM_ARGS ?=
VCS_CC ?= gcc
VCS_CXX ?= g++
case     ?= test_case0
seed     ?= 1
DUT_MODE ?= nice
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
SIMV     ?= simv_$(DUT_MODE)_S$(MMA_SIZE)_C$(MMA_IA_CACHE_BLOCKS)_P$(MMA_PS_FRAME_COUNT)
SOC_RANDOM ?= 0
SOC_FIX_MODE ?= 1
SOC_SEED ?= 1
SOC_RANDOM_LHS_DTYPE ?=
SOC_RANDOM_QUANT_MODE ?=
SOC_UNALIGNED_LAYOUT ?= 0
SOC_MIN_DIM ?=
SOC_MAX_DIM ?=
SOC_DIM_MULTIPLE ?= 16
SOC_LHS_OFFSET ?= 0
SOC_RHS_OFFSET ?= 0
SOC_DST_OFFSET ?= 0
SOC_ACT_MIN ?= -128
SOC_ACT_MAX ?= 127
SOC_DST_MULT ?=
SOC_DST_SHIFT ?=
SOC_CPU_MEM_DP ?= 524288
SOC_AXI_READ_OUTSTANDING ?= 4
SOC_AXI_WRITE_OUTSTANDING ?= $(SOC_AXI_READ_OUTSTANDING)
SOC_TIMEOUT_CYCLES ?=
SOC_C_SRC ?= ../soc_csrc/soc_main.c
SOC_RUNTIME_C_SRC ?= ../soc_csrc/soc_runtime_main.c
SOC_APP ?= runtime
SOC_UART_CLKDIV ?= 8
E203_SIM_ROOT ?= /home/etc/FPGA/e203_simulator
SOC_TOOLCHAIN_DIR ?= $(E203_SIM_ROOT)/deps/software-level/bin/gcc_open/bin
SOC_GCC_FROM_PATH := $(shell command -v riscv64-unknown-elf-gcc 2>/dev/null)
SOC_GXX_FROM_PATH := $(shell command -v riscv64-unknown-elf-g++ 2>/dev/null)
SOC_AR_FROM_PATH := $(shell command -v riscv64-unknown-elf-ar 2>/dev/null)
SOC_OBJCOPY_FROM_PATH := $(shell command -v riscv64-unknown-elf-objcopy 2>/dev/null)
SOC_GCC ?= $(if $(SOC_GCC_FROM_PATH),$(SOC_GCC_FROM_PATH),$(SOC_TOOLCHAIN_DIR)/riscv64-unknown-elf-gcc)
SOC_GXX ?= $(if $(SOC_GXX_FROM_PATH),$(SOC_GXX_FROM_PATH),$(SOC_TOOLCHAIN_DIR)/riscv64-unknown-elf-g++)
SOC_AR ?= $(if $(SOC_AR_FROM_PATH),$(SOC_AR_FROM_PATH),$(SOC_TOOLCHAIN_DIR)/riscv64-unknown-elf-ar)
SOC_OBJCOPY ?= $(if $(SOC_OBJCOPY_FROM_PATH),$(SOC_OBJCOPY_FROM_PATH),$(SOC_TOOLCHAIN_DIR)/riscv64-unknown-elf-objcopy)
SOC_OPT_LEVEL ?= -O3
HOST_OPT_LEVEL ?= -O3
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
SOC_RUNTIME_BASE_ADDR ?= 0x00080000
SOC_RUNTIME_BASE_WORD ?= 131072
SOC_RUNTIME_BUILD_DIR ?= ../tb/axi_soc_runtime_build_S$(MMA_SIZE)_C$(MMA_IA_CACHE_BLOCKS)_P$(MMA_PS_FRAME_COUNT)
SOC_RUNTIME_CPU_MEM ?= $(SOC_RUNTIME_BUILD_DIR)/cpu.mem
TFLM_DIR ?= ../../drivers/tflm/my_tflm
TFLM_ROOT ?= $(TFLM_DIR)/tflite-micro
TFLM_BUILD_DIR ?= build-rv32im-S$(MMA_SIZE)-C$(MMA_IA_CACHE_BLOCKS)-P$(MMA_PS_FRAME_COUNT)
TFLM_LIB ?= $(TFLM_DIR)/$(TFLM_BUILD_DIR)/libtflite-micro.a
TFLM_GENFILES ?= $(TFLM_ROOT)/gen/linux_x86_64_default/genfiles
TFLM_HOST_BUILD_DIR ?= build-host
TFLM_HOST_LIB ?= $(TFLM_DIR)/$(TFLM_HOST_BUILD_DIR)/libtflite-micro.a
TFLM_MICRO_SPEECH_FEATURES_CC ?= ../soc_csrc/tflm_micro_speech_features.cc
TFLM_MICRO_SPEECH_FEATURE_DUMP ?= $(TFLM_DIR)/$(TFLM_HOST_BUILD_DIR)/dump_micro_speech_features
TFLM_MY_MODEL_TIMEOUT_CYCLES ?= 120000000
TFLM_MICRO_SPEECH_TIMEOUT_CYCLES ?= 50000000
TFLM_HELLO_WORLD_TIMEOUT_CYCLES ?= 5000000
TFLM_PERSON_DETECTION_TIMEOUT_CYCLES ?= 320000000
SOC_HW_DEFINES := -DDSA_TILE_SIZE=$(MMA_SIZE) -DDSA_IA_CACHE_BLOCKS=$(MMA_IA_CACHE_BLOCKS) -DDSA_PS_FRAME_COUNT=$(MMA_PS_FRAME_COUNT)
TFLM_RV32_REBUILD_DEPS := \
                $(TFLM_ROOT)/tensorflow/lite/micro/kernels/conv.cc \
                $(TFLM_ROOT)/tensorflow/lite/micro/kernels/depthwise_conv.cc \
                $(TFLM_ROOT)/my_model/my_model.cc

TFLM_INCLUDES = -I$(TFLM_ROOT) \
                -I$(TFLM_ROOT)/gen \
                -I$(TFLM_GENFILES) \
                -I$(TFLM_ROOT)/my_model \
                -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads \
                -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/gemmlowp \
                -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/flatbuffers/include \
                -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/kissfft \
                -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/ruy
TFLM_CXXFLAGS = -march=rv32im -mabi=ilp32 $(SOC_OPT_LEVEL) $(SOC_HW_DEFINES) \
                -std=c++17 -fno-rtti -fno-exceptions -fno-threadsafe-statics \
                -fno-unwind-tables -ffunction-sections -fdata-sections \
                -fmessage-length=0 -DNDEBUG -DTF_LITE_STRIP_ERROR_STRINGS \
                -DTF_LITE_DISABLE_X86_NEON -DPICOSOC_UART_CLKDIV=$(SOC_UART_CLKDIV) \
                -DTFLM_SOC_PROGRESS -DTFLM_SOC_MMA $(TFLM_INCLUDES)
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
FILELIST     ?= ../flist/tb1.f
SIM_OPTS     += +DUT_SEL=nice
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
           $(UVM_VER) \
           $(FSDB_PLI)
MMA_PARAM_OPTS = -pvalue+tb_top.DUT_SIZE=$(MMA_SIZE) \
                 -pvalue+tb_top.DUT_IA_CACHE_BLOCKS=$(MMA_IA_CACHE_BLOCKS) \
                 -pvalue+tb_top.DUT_PS_FRAME_COUNT=$(MMA_PS_FRAME_COUNT) \
                 -pvalue+tb_top.DUT_CPU_MEM_DP=$(SOC_CPU_MEM_DP) \
                 -pvalue+tb_top.DUT_AXI_READ_OUTSTANDING=$(SOC_AXI_READ_OUTSTANDING) \
                 -pvalue+tb_top.DUT_AXI_WRITE_OUTSTANDING=$(SOC_AXI_WRITE_OUTSTANDING)

SIM_OPTS   ?=
VERDI_OPTS ?=

VCS_FILELISTS_L1 := $(shell awk '$$1 == "-f" { print $$2 }' $(FILELIST) 2>/dev/null)
VCS_FILELISTS_L2 := $(shell awk '$$1 == "-f" { print $$2 }' $(VCS_FILELISTS_L1) 2>/dev/null)
VCS_FILELISTS_L3 := $(shell awk '$$1 == "-f" { print $$2 }' $(VCS_FILELISTS_L2) 2>/dev/null)
VCS_FILELISTS := $(sort $(FILELIST) $(VCS_FILELISTS_L1) $(VCS_FILELISTS_L2) $(VCS_FILELISTS_L3))
VCS_SRC_DEPS := $(shell awk '{ sub(/\/\/.*/, ""); if ($$1 != "" && $$1 != "-f" && $$1 !~ /^\+/) print $$1 }' $(VCS_FILELISTS) 2>/dev/null)

run: sim

soc_case:
> @mkdir -p $(SOC_CASE_DIR)
> @python3 ../tb/generate_axi_soc_case.py $(SOC_GEN_ARGS) --out_dir $(SOC_CASE_DIR)

soc_c: soc_case
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[SOC_C] $(SOC_C_SRC) -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GCC) -march=rv32im -mabi=ilp32 $(SOC_OPT_LEVEL) $(SOC_HW_DEFINES) -ffreestanding -nostdlib -nostartfiles -DPICOSOC_UART_CLKDIV=$(SOC_UART_CLKDIV) -I../soc_csrc -I$(SOC_CASE_DIR) -T ../soc_csrc/link.ld ../soc_csrc/start.S ../soc_csrc/picosoc_bsp.c ../soc_csrc/dsa_accel_mmio.c $(SOC_CASE_DIR)/soc_case.c $(SOC_C_SRC) -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

$(SOC_RUNTIME_CPU_MEM): $(SOC_RUNTIME_C_SRC) ../soc_csrc/start.S ../soc_csrc/picosoc_bsp.c ../soc_csrc/picosoc_bsp.h ../soc_csrc/dsa_accel_mmio.c ../soc_csrc/dsa_accel_mmio.h ../soc_csrc/link.ld Makefile
> @mkdir -p $(@D)
> @echo "[SOC_RUNTIME_C] $(SOC_RUNTIME_C_SRC) -> $@"
> $(SOC_GCC) -march=rv32im -mabi=ilp32 $(SOC_OPT_LEVEL) $(SOC_HW_DEFINES) -DSOC_RUNTIME_CASE_BASE=$(SOC_RUNTIME_BASE_ADDR) -ffreestanding -nostdlib -nostartfiles -DPICOSOC_UART_CLKDIV=$(SOC_UART_CLKDIV) -I../soc_csrc -T ../soc_csrc/link.ld ../soc_csrc/start.S ../soc_csrc/picosoc_bsp.c ../soc_csrc/dsa_accel_mmio.c $(SOC_RUNTIME_C_SRC) -o $(@D)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(@D)/cpu.elf $(@D)/cpu.bin
> python3 ../tb/elf_to_mem.py $(@D)/cpu.bin $@ --depth $(SOC_CPU_MEM_DP)

soc_runtime_c: $(SOC_RUNTIME_CPU_MEM)

$(TFLM_LIB): $(TFLM_RV32_REBUILD_DEPS)
> $(MAKE) -C $(TFLM_DIR) BUILD_DIR=$(TFLM_BUILD_DIR) CC=$(SOC_GCC) CXX=$(SOC_GXX) AR=$(SOC_AR) TARGET_FLAGS="-march=rv32im -mabi=ilp32 $(SOC_OPT_LEVEL) $(SOC_HW_DEFINES) -DTFLM_SOC_PROGRESS -DTFLM_SOC_MMA" BUILD_TYPE=Release $(TFLM_BUILD_DIR)/libtflite-micro.a

$(TFLM_HOST_LIB):
> $(MAKE) -C $(TFLM_DIR) BUILD_DIR=$(TFLM_HOST_BUILD_DIR) TARGET_FLAGS="$(HOST_OPT_LEVEL)" BUILD_TYPE=Release $(TFLM_HOST_BUILD_DIR)/libtflite-micro.a

$(TFLM_MICRO_SPEECH_FEATURE_DUMP): ../tools/dump_micro_speech_features.cc $(TFLM_HOST_LIB) $(TFLM_MICRO_SPEECH_MODEL_DATA_CC) $(TFLM_MICRO_SPEECH_AUDIO_DATA_SRCS)
> $(CXX) -std=c++17 $(HOST_OPT_LEVEL) -fno-rtti -fno-exceptions -fno-threadsafe-statics -DTF_LITE_DISABLE_X86_NEON -DTF_LITE_STRIP_ERROR_STRINGS -I$(TFLM_ROOT) -I$(TFLM_GENFILES) -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/gemmlowp -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/flatbuffers/include -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/kissfft -I$(TFLM_ROOT)/tensorflow/lite/micro/tools/make/downloads/ruy ../tools/dump_micro_speech_features.cc $(TFLM_MICRO_SPEECH_MODEL_DATA_CC) $(TFLM_MICRO_SPEECH_AUDIO_DATA_SRCS) $(TFLM_HOST_LIB) -lm -o $@

$(TFLM_MICRO_SPEECH_FEATURES_CC): $(TFLM_MICRO_SPEECH_FEATURE_DUMP)
> $< > $@

tflm_soc_c: $(TFLM_LIB)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] my_model -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles -T ../soc_csrc/link.ld $(TFLM_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_micro_speech_soc_c: $(TFLM_LIB) $(TFLM_MICRO_SPEECH_FEATURES_CC)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] micro_speech -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles -T ../soc_csrc/link.ld $(TFLM_MICRO_SPEECH_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_hello_world_soc_c: $(TFLM_LIB)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] hello_world -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles -T ../soc_csrc/link.ld $(TFLM_HELLO_WORLD_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

tflm_person_detection_soc_c: $(TFLM_LIB)
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[TFLM_SOC_C] person_detection -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GXX) $(TFLM_CXXFLAGS) -nostartfiles -T ../soc_csrc/link.ld $(TFLM_PERSON_DETECTION_APP_SRCS) $(TFLM_LIB) -Wl,--gc-sections -Wl,-Map=$(SOC_CASE_DIR)/cpu.map -lm -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python3 ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

$(SIMV): $(VCS_FILELISTS) $(VCS_SRC_DEPS) Makefile
> @mkdir -p $(OUT_DIR)
> @echo "[COMPILE] VCS -> $(SIMV) (DUT_MODE=$(DUT_MODE), case=$(case), seed=$(seed))"
> $(VCS) $(VCS_OPTS) $(MMA_PARAM_OPTS) $(INCDIRS:%=-y %) $(DEFINES:%=+define+%) $(MODE_DEFINES:%=+define+%) -f $(FILELIST) -top $(TOP) -l $(COMPILE_LOG) -o $(SIMV) +vcs+initreg+random

com: $(SIMV)

force_com:
> @rm -f $(SIMV)
> $(MAKE) --no-print-directory com

sim: $(SIMV) $(RUN_DEPS)
> @mkdir -p $(OUT_DIR)
> @echo "[SIM] $(SIM_RUNNER) $(SIM_OPTS) case=$(case) seed=$(seed) FSDB=$(FSDB)"
> $(SIM_RUNNER) $(SIM_OPTS) $(SIM_ARGS) $(DUMPFSDB) +fsdbfile+$(FSDB) +UVM_TESTNAME=$(case) +case=$(case) +ntb_random_seed=$(seed) -l $(SIM_LOG) +vcs+initreg+0

soc_regress:
> @python3 ./run_axi_soc_c_regression.py --iterations $(SOC_REGRESS_ITERS) --start-seed $(SOC_REGRESS_START_SEED) --timeout $(SOC_REGRESS_TIMEOUT) --log-root $(SOC_REGRESS_LOG_ROOT) --sizes "$(SOC_SIZE_LIST)" --cache-blocks "$(SOC_CACHE_BLOCKS_LIST)" --ps-frame-counts "$(SOC_PS_FRAME_COUNT_LIST)" --dataflow-modes "$(SOC_DATAFLOW_MODE_LIST)" --lhs-dtypes "$(SOC_REGRESS_LHS_DTYPE_LIST)" --quant-modes "$(SOC_REGRESS_QUANT_MODE_LIST)" --dim-multiple $(SOC_REGRESS_DIM_MULTIPLE) --sim-args "$(SOC_REGRESS_SIM_ARGS)" --ddr-cmd-max-lat $(SOC_REGRESS_DDR_CMD_MAX_LAT) --ddr-w-max-lat $(SOC_REGRESS_DDR_W_MAX_LAT) --ddr-rsp-max-lat $(SOC_REGRESS_DDR_RSP_MAX_LAT) $(if $(SOC_REGRESS_SOC_TIMEOUT_CYCLES),--soc-timeout-cycles $(SOC_REGRESS_SOC_TIMEOUT_CYCLES),) $(if $(filter 1 yes true TRUE,$(SOC_REGRESS_DDR_RAND_LAT)),--ddr-rand-lat,) $(if $(filter 1 yes true TRUE,$(SOC_REGRESS_UNALIGNED_LAYOUT)),--unaligned-layout,) $(if $(SOC_MIN_DIM),--min-dim $(SOC_MIN_DIM),) $(if $(SOC_MAX_DIM),--max-dim $(SOC_MAX_DIM),)

soc_perf_sweep:
> @python3 ./run_axi_soc_perf_sweep.py --seed $(SOC_PERF_SEED) --log-root $(SOC_PERF_LOG_ROOT) --dims "$(SOC_PERF_DIMS)" --sizes "$(SOC_PERF_SIZE_LIST)" --cache-blocks "$(SOC_PERF_CACHE_BLOCKS_LIST)" --ps-frame-counts "$(SOC_PERF_PS_FRAME_COUNT_LIST)" --dataflow-modes "$(SOC_PERF_DATAFLOW_MODE_LIST)" --lhs-dtypes "$(SOC_PERF_LHS_DTYPE_LIST)" --quant-modes "$(SOC_PERF_QUANT_MODE_LIST)" --ia-reuse-list "$(SOC_PERF_IA_REUSE_LIST)" --w-reuse-list "$(SOC_PERF_W_REUSE_LIST)" --jobs $(SOC_PERF_JOBS) --sim-args "$(SOC_PERF_SIM_ARGS)" --ddr-cmd-max-lat $(SOC_PERF_DDR_CMD_MAX_LAT) --ddr-w-max-lat $(SOC_PERF_DDR_W_MAX_LAT) --ddr-rsp-max-lat $(SOC_PERF_DDR_RSP_MAX_LAT) $(if $(filter 1 yes true TRUE,$(SOC_PERF_INCLUDE_AUTO)),--include-auto,) $(if $(filter 1 yes true TRUE,$(SOC_PERF_KEEP_GOING)),--keep-going,) $(if $(filter 1 yes true TRUE,$(SOC_PERF_FORCE_COMPILE)),--force-compile,) $(if $(filter 1 yes true TRUE,$(SOC_PERF_DDR_RAND_LAT)),--ddr-rand-lat,)

tflm_my_model_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm SOC_CASE=axi_soc_tflm case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_MY_MODEL_TIMEOUT_CYCLES))

tflm_micro_speech_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_micro_speech SOC_CASE=axi_soc_tflm_micro_speech case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_MICRO_SPEECH_TIMEOUT_CYCLES))

tflm_hello_world_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_hello_world SOC_CASE=axi_soc_tflm_hello_world case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_HELLO_WORLD_TIMEOUT_CYCLES))

tflm_person_detection_run: DUMPOPTS = 0
tflm_person_detection_run:
> $(MAKE) run DUT_MODE=axi_soc SOC_APP=tflm_person_detection SOC_CASE=axi_soc_tflm_person_detection case=ai_axi_soc_c_test SOC_CPU_MEM_DP=$(SOC_CPU_MEM_DP) SOC_TIMEOUT_CYCLES=$(if $(SOC_TIMEOUT_CYCLES),$(SOC_TIMEOUT_CYCLES),$(TFLM_PERSON_DETECTION_TIMEOUT_CYCLES)) DUMPOPTS=$(DUMPOPTS)

tflm_run: tflm_hello_world_run

vd:
> @echo "[VERDI] case=$(case) seed=$(seed) FSDB=$(FSDB)"
> @if [ ! -f "$(FSDB)" ]; then echo "[ERROR] FSDB not found: $(FSDB)"; echo "        Please run: make run DUT_MODE=$(DUT_MODE) case=$(case) seed=$(seed)"; exit 1; fi
> $(VERDI) -sv $(INCDIRS:%=-y %) $(DEFINES:%=+define+%) $(MODE_DEFINES:%=+define+%) -f $(FILELIST) +incdir+$(UVM_HOME)/src -top $(TOP) $(VERDI_OPTS) -ssf $(FSDB) &

clean:
> rm -rf $(SIMV) simv_* csrc *.csrc simv.daidir simv_*.daidir *.log *.key novas.* verdiLog runs

help:
> @echo "Targets:"
> @echo "  make run   [DUT_MODE=nice|axil|axi_soc] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "             [MMA_SIZE=16] [MMA_IA_CACHE_BLOCKS=4] [MMA_PS_FRAME_COUNT=<MMA_SIZE>]"
> @echo "             [SOC_APP=runtime|case|tflm]  # runtime reuses one O3 CPU app and reads runtime_data.mem"
> @echo "  make com   [DUT_MODE=nice|axil|axi_soc] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "  make force_com [DUT_MODE=nice|axil|axi_soc]  # rebuild simv"
> @echo "  make sim   [DUT_MODE=nice|axil|axi_soc] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "  make soc_regress [SOC_REGRESS_ITERS=<n>] [SOC_REGRESS_START_SEED=<int>] [SOC_MIN_DIM=<n>] [SOC_MAX_DIM=<n>] [SOC_REGRESS_DIM_MULTIPLE=<n>]"
> @echo "                   [SOC_SIZE_LIST='8 16'] [SOC_CACHE_BLOCKS_LIST='2 4'] [SOC_REGRESS_DDR_RAND_LAT=1] [SOC_REGRESS_UNALIGNED_LAYOUT=1]"
> @echo "  make soc_perf_sweep [SOC_PERF_DIMS='32x32x32'] [SOC_PERF_SIZE_LIST='8 16'] [SOC_PERF_CACHE_BLOCKS_LIST='2 4']"
> @echo "                      [SOC_PERF_INCLUDE_AUTO=1] [SOC_PERF_FORCE_COMPILE=1] [SOC_PERF_JOBS=4] [SOC_PERF_DDR_RAND_LAT=1]"
> @echo "  make tflm_run"
> @echo "  make tflm_hello_world_run"
> @echo "  make tflm_micro_speech_run"
> @echo "  make tflm_person_detection_run"
> @echo "  make tflm_my_model_run"
> @echo "  make vd    [DUT_MODE=nice|axil|axi_soc] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "  make clean"
> @echo "  make help"
> @echo ""
> @echo "Output layout:"
> @echo "  runs/<case>/seed_<seed>/compile.log"
> @echo "  runs/<case>/seed_<seed>/sim.log"
> @echo "  runs/<case>/seed_<seed>/tb_top.fsdb"
> @echo ""
> @echo "case(also UVM_TESTNAME) -> sequence mapping (from veri/test/ai_test_pkg.sv):"
> @echo "  smoke_test                    -> ai_smoke_nice_seq"
> @echo "  ai_smoke_test                 -> ai_smoke_seq"
> @echo "  ai_coverage_test              -> ai_nice_cov_seq"
> @echo "  ai_nice_ral_csr_wr_check_test -> ai_nice_ral_csr_wr_check_seq"
> @echo "  ai_mem_gen_smoke_test         -> ai_mem_gen_smoke_seq"
> @echo "  ai_ral_mem_gen_on_calc_start_test -> ai_ral_mem_gen_on_calc_start_seq"
> @echo ""
> @echo "Common examples:"
> @echo "  make run DUT_MODE=nice case=ai_mem_gen_smoke_test seed=1"
> @echo "  make run DUT_MODE=nice case=ai_ral_mem_gen_on_calc_start_test seed=1"
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
> @echo "  make tflm_my_model_run"
> @echo "  make run DUT_MODE=axi_soc case=ai_axi_soc_c_test VCS_CC=gcc-4.8 VCS_CXX=g++-4.8"
> @echo "  make vd DUT_MODE=axil case=ai_mem_gen_smoke_test seed=20260413"
.PHONY: run soc_case soc_c soc_runtime_c tflm_soc_c tflm_micro_speech_soc_c tflm_hello_world_soc_c tflm_person_detection_soc_c tflm_run tflm_micro_speech_run tflm_hello_world_run tflm_person_detection_run tflm_my_model_run com force_com sim soc_regress vd clean help
