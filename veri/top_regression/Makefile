PROJECT_ROOT := ../..
RTL_ROOT := $(PROJECT_ROOT)/rtl/axi_accelerator
NPU_RTL_DIR := $(RTL_ROOT)/npu

TB := tb_npu_top.sv
VEXE := sim_npu_top
SIZE ?= 4
IA_CACHE_BLOCKS ?= 4
PS_FRAME_COUNT ?= 8
AXI_READ_OUTSTANDING ?= 4
BUILD_ROOT ?= obj_dir
TRACE ?= 0
TRACE_ENABLED := $(filter 1 yes true TRUE,$(TRACE))
TRACE_TAG := $(if $(TRACE_ENABLED),trace,notrace)
TRACE_FLAGS := $(if $(TRACE_ENABLED),--trace,)
BUILD_DIR := $(BUILD_ROOT)/s$(SIZE)_c$(IA_CACHE_BLOCKS)_ps$(PS_FRAME_COUNT)_ro$(AXI_READ_OUTSTANDING)_$(TRACE_TAG)
SIM_BIN := $(BUILD_DIR)/$(VEXE)
VERILATOR ?= verilator
VERILATOR_OPT_FLAGS ?= -O3 -CFLAGS -O3 -LDFLAGS -O3
VERILATOR_BUILD_JOBS ?= 8

VERILATOR_FLAGS := -sv -Wall $(TRACE_FLAGS) --timing --top-module tb_npu_top \
	--build-jobs $(VERILATOR_BUILD_JOBS) \
	$(VERILATOR_OPT_FLAGS) \
	-Wno-GENUNNAMED -Wno-VARHIDDEN -Wno-WIDTHEXPAND -Wno-UNUSEDSIGNAL \
	-Wno-UNUSED -Wno-UNUSEDGENVAR -Wno-UNDRIVEN -Wno-PINMISSING \
	-Wno-STMTDLY -Wno-DECLFILENAME -Wno-CASEINCOMPLETE -Wno-EOFNEWLINE \
	-Wno-PROCASSINIT -Wno-SYNCASYNCNET -Wno-COMBDLY -Wno-PINCONNECTEMPTY \
	-Wno-WIDTHTRUNC -Wno-ASCRANGE -Wno-INITIALDLY -Wno-BLKSEQ -Wno-MULTIDRIVEN \
	-Wno-LATCH \
	-DTB_SIZE=$(SIZE) -DTB_IA_CACHE_BLOCKS=$(IA_CACHE_BLOCKS) -DTB_PS_FRAME_COUNT=$(PS_FRAME_COUNT) \
	-DTB_AXI_READ_OUTSTANDING=$(AXI_READ_OUTSTANDING)

NPU_TOP_SRC ?= $(NPU_RTL_DIR)/npu_top.sv
NPU_SV := $(shell find $(NPU_RTL_DIR) -maxdepth 1 -type f \( -name "*.sv" -o -name "*.v" \) ! -name "npu_top.sv" | sort)
SRCS := $(TB) ddr_axi_mem_model.sv $(NPU_TOP_SRC) $(NPU_SV)

OUT_DIR := out
MEM_INIT := $(OUT_DIR)/init.mem
MEM_GOLDEN := $(OUT_DIR)/golden.mem
MEM_CASE := $(OUT_DIR)/config.mem
GEN_ARGS ?=
RANDOM_GEN_ARGS ?= --random --random_quant --lhs_dtype 0 --min_dim 1 --max_dim 32
COUNT ?= 20
SEED ?= 1000
SIZES ?= 4 8 16
CACHE_BLOCKS_LIST ?= 2 4 8
SIM_ARGS ?= +DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8

INCLUDES = -I.

all: run

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

gen: $(OUT_DIR)
	python3 gen_mem.py --out_dir $(OUT_DIR) --size $(SIZE) --ia_cache_blocks $(IA_CACHE_BLOCKS) $(GEN_ARGS) --ps_frame_count $(PS_FRAME_COUNT)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(SIM_BIN): $(SRCS) Makefile | $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) $(INCLUDES) --Mdir $(BUILD_DIR) --binary $(SRCS) -o $(VEXE)

build_only: $(SIM_BIN)

build: gen build_only

run_only:
	$(SIM_BIN) +INIT_MEM=$(MEM_INIT) +GOLDEN_MEM=$(MEM_GOLDEN) +CASE_MEM=$(MEM_CASE) $(SIM_ARGS)

run: build run_only

run_random: $(OUT_DIR) build_only
	@pass=0; fail=0; summary_prefix="$(OUT_DIR)/random_summary"; \
	python3 summarize_regression.py init --prefix "$${summary_prefix}" --title "NPU top random regression"; \
	for i in $$(seq 0 $$(( $(COUNT) - 1 ))); do \
		seed=$$(( $(SEED) + $$i )); \
		log="$(OUT_DIR)/random_$${seed}.log"; \
		cfg="$(OUT_DIR)/random_$${seed}.json"; \
		echo "[run_random] size=$(SIZE) cache=$(IA_CACHE_BLOCKS) seed=$${seed}"; \
		python3 gen_mem.py --out_dir $(OUT_DIR) --size $(SIZE) --ia_cache_blocks $(IA_CACHE_BLOCKS) --seed $${seed} $(RANDOM_GEN_ARGS) --ps_frame_count $(PS_FRAME_COUNT) || exit 1; \
		cp "$(OUT_DIR)/config.json" "$${cfg}"; \
		$(SIM_BIN) +INIT_MEM=$(MEM_INIT) +GOLDEN_MEM=$(MEM_GOLDEN) +CASE_MEM=$(MEM_CASE) $(SIM_ARGS) +DDR_SEED=$${seed} | tee "$${log}"; \
		python3 summarize_regression.py append --prefix "$${summary_prefix}" --case random --config "$${cfg}" --log "$${log}"; \
		if grep -q "\\[TB\\] PASS" "$${log}"; then pass=$$((pass + 1)); else fail=$$((fail + 1)); fi; \
	done; \
	python3 summarize_regression.py finish --prefix "$${summary_prefix}"; \
	echo "[run_random] PASS=$${pass} FAIL=$${fail}"; \
	test "$${fail}" -eq 0

run_param_random: $(OUT_DIR)
	@pass=0; fail=0; idx=0; summary_prefix="$(OUT_DIR)/param_summary"; \
	python3 summarize_regression.py init --prefix "$${summary_prefix}" --title "NPU top parameterized random regression"; \
	for size in $(SIZES); do \
		for cache in $(CACHE_BLOCKS_LIST); do \
			build_log="$(OUT_DIR)/build_s$${size}_c$${cache}.log"; \
			$(MAKE) --no-print-directory build_only SIZE=$${size} IA_CACHE_BLOCKS=$${cache} PS_FRAME_COUNT=$(PS_FRAME_COUNT) AXI_READ_OUTSTANDING=$(AXI_READ_OUTSTANDING) BUILD_ROOT=$(BUILD_ROOT) TRACE=$(TRACE) > "$${build_log}" 2>&1 || { \
				cat "$${build_log}"; \
				python3 summarize_regression.py append --prefix "$${summary_prefix}" --case param_build --log "$${build_log}" --seed "$${idx}" --size "$${size}" --cache "$${cache}" --ps-frame-count "$(PS_FRAME_COUNT)" --status FAIL --reason build_failed; \
				fail=$$((fail + $(COUNT))); idx=$$((idx + $(COUNT))); continue; }; \
			bin="$(BUILD_ROOT)/s$${size}_c$${cache}_ps$(PS_FRAME_COUNT)_ro$(AXI_READ_OUTSTANDING)_$(TRACE_TAG)/$(VEXE)"; \
			for i in $$(seq 0 $$(( $(COUNT) - 1 ))); do \
				seed=$$(( $(SEED) + $$idx )); idx=$$((idx + 1)); \
				log="$(OUT_DIR)/param_s$${size}_c$${cache}_$${seed}.log"; \
				cfg="$(OUT_DIR)/param_s$${size}_c$${cache}_$${seed}.json"; \
				echo "[run_param_random] size=$${size} cache=$${cache} seed=$${seed}"; \
				python3 gen_mem.py --out_dir $(OUT_DIR) --size $${size} --ia_cache_blocks $${cache} --seed $${seed} $(RANDOM_GEN_ARGS) --ps_frame_count $(PS_FRAME_COUNT) || exit 1; \
				cp "$(OUT_DIR)/config.json" "$${cfg}"; \
				"$${bin}" +INIT_MEM=$(MEM_INIT) +GOLDEN_MEM=$(MEM_GOLDEN) +CASE_MEM=$(MEM_CASE) $(SIM_ARGS) +DDR_SEED=$${seed} | tee "$${log}"; \
				python3 summarize_regression.py append --prefix "$${summary_prefix}" --case param --config "$${cfg}" --log "$${log}"; \
				if grep -q "\\[TB\\] PASS" "$${log}"; then pass=$$((pass + 1)); else fail=$$((fail + 1)); fi; \
			done; \
		done; \
	done; \
	python3 summarize_regression.py finish --prefix "$${summary_prefix}"; \
	echo "[run_param_random] PASS=$${pass} FAIL=$${fail}"; \
	test "$${fail}" -eq 0

wave: TRACE=1
wave: run
	gtkwave wave.vcd

clean:
	rm -rf $(VEXE) *.vcd obj_dir out

.PHONY: all build build_only run run_only run_random run_param_random clean wave gen
