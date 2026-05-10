SHELL := /bin/bash
.RECIPEPREFIX := >

TOP      ?= tb_top
SIMV     ?= simv
DUMPOPTS ?= 1
INCDIRS  ?=
DEFINES  ?=
UVM_HOME ?= $(VCS_HOME)/etc/uvm-1.2/
UVM_VER  ?= -ntb_opts uvm-1.2
NOVAS_HOME ?=
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
SOC_FIX_MODE ?= 1
SOC_SEED ?= 1
SOC_LHS_OFFSET ?= 0
SOC_RHS_OFFSET ?= 0
SOC_DST_OFFSET ?= 0
SOC_ACT_MIN ?= -128
SOC_ACT_MAX ?= 127
SOC_DST_MULT ?=
SOC_DST_SHIFT ?=
SOC_CPU_MEM_DP ?= 65536
SOC_C_SRC ?= ../soc_csrc/soc_main.c
SOC_GCC ?= $(or $(shell command -v riscv64-unknown-elf-gcc 2>/dev/null),$(abspath ../../e203_soc/deps/software-level/bin/gcc_open/bin/riscv64-unknown-elf-gcc))
SOC_OBJCOPY ?= $(or $(shell command -v riscv64-unknown-elf-objcopy 2>/dev/null),$(abspath ../../e203_soc/deps/software-level/bin/gcc_open/bin/riscv64-unknown-elf-objcopy))

OUT_DIR     ?= runs/$(case)/seed_$(seed)
FSDB        ?= $(OUT_DIR)/tb_top.fsdb
COMPILE_LOG ?= $(OUT_DIR)/compile.log
SIM_LOG     ?= $(OUT_DIR)/sim.log

ifeq ($(DUT_MODE),axi_soc)
FILELIST     ?= ../flist/tb_axi_soc.f
MODE_DEFINES += DUT_AXI_SOC
SIM_OPTS     += +DUT_SEL=axi_soc +SOC_CASE_DIR=$(SOC_CASE_DIR) +SOC_CPU_MEM=$(SOC_CASE_DIR)/cpu.mem +SOC_MMA_MEM=$(SOC_CASE_DIR)/data.mem
COMPILE_DEPS += soc_c
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

FSDB_PLI = -P $(NOVAS_HOME)/share/PLI/VCS/LINUX64/novas.tab $(NOVAS_HOME)/share/PLI/VCS/LINUX64/pli.a
VCS_OPTS = -cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed \
           -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -lca \
           $(UVM_VER) \
           $(FSDB_PLI)

SIM_OPTS   ?=
VERDI_OPTS ?=

run: com sim

soc_case:
> @mkdir -p $(SOC_CASE_DIR)
> @python ../tb/generate_axi_soc_case.py --K $(SOC_K) --N $(SOC_N) --M $(SOC_M) --lhs_dtype $(SOC_LHS_DTYPE) --quant_mode $(SOC_QUANT_MODE) $(if $(filter 1 yes true TRUE,$(SOC_FIX_MODE)),--fix_mode,) --seed $(SOC_SEED) --lhs_offset $(SOC_LHS_OFFSET) --rhs_offset $(SOC_RHS_OFFSET) --dst_offset $(SOC_DST_OFFSET) --act_min $(SOC_ACT_MIN) --act_max $(SOC_ACT_MAX) $(if $(SOC_DST_MULT),--dst_mult $(SOC_DST_MULT),) $(if $(SOC_DST_SHIFT),--dst_shift $(SOC_DST_SHIFT),) --out_dir $(SOC_CASE_DIR)
> @cp $(SOC_CASE_DIR)/data.mem ../tb/main_extram.mem

soc_c: soc_case
> @mkdir -p $(SOC_CASE_DIR)
> @echo "[SOC_C] $(SOC_C_SRC) -> $(SOC_CASE_DIR)/cpu.mem"
> $(SOC_GCC) -march=rv32im -mabi=ilp32 -O2 -ffreestanding -nostdlib -nostartfiles -I../soc_csrc -I$(SOC_CASE_DIR) -T ../soc_csrc/link.ld ../soc_csrc/start.S ../soc_csrc/dsa_accel_mmio.c $(SOC_C_SRC) -o $(SOC_CASE_DIR)/cpu.elf
> $(SOC_OBJCOPY) -O binary $(SOC_CASE_DIR)/cpu.elf $(SOC_CASE_DIR)/cpu.bin
> python ../tb/elf_to_mem.py $(SOC_CASE_DIR)/cpu.bin $(SOC_CASE_DIR)/cpu.mem --depth $(SOC_CPU_MEM_DP)

com: $(COMPILE_DEPS)
> @mkdir -p $(OUT_DIR)
> @echo "[COMPILE] VCS -> $(SIMV) (DUT_MODE=$(DUT_MODE), case=$(case), seed=$(seed))"
> vcs $(VCS_OPTS) $(INCDIRS:%=-y %) $(DEFINES:%=+define+%) $(MODE_DEFINES:%=+define+%) -f $(FILELIST) -fsdb -top $(TOP) -l $(COMPILE_LOG) -o $(SIMV) +vcs+initreg+random

sim:
> @mkdir -p $(OUT_DIR)
> @echo "[SIM] ./$(SIMV) $(SIM_OPTS) case=$(case) seed=$(seed) FSDB=$(FSDB)"
> ./$(SIMV) $(SIM_OPTS) $(DUMPFSDB) +fsdbfile+$(FSDB) +UVM_TESTNAME=$(case) +case=$(case) +ntb_random_seed=$(seed) -l $(SIM_LOG) +vcs+initreg+0

vd:
> @echo "[VERDI] case=$(case) seed=$(seed) FSDB=$(FSDB)"
> @if [ ! -f "$(FSDB)" ]; then echo "[ERROR] FSDB not found: $(FSDB)"; echo "        Please run: make run DUT_MODE=$(DUT_MODE) case=$(case) seed=$(seed)"; exit 1; fi
> verdi -sv $(INCDIRS:%=-y %) $(DEFINES:%=+define+%) $(MODE_DEFINES:%=+define+%) -f $(FILELIST) +incdir+$(UVM_HOME)/src -top $(TOP) $(VERDI_OPTS) -ssf $(FSDB) &

clean:
> rm -rf $(SIMV) csrc simv.daidir *.log *.key novas.* verdiLog runs

help:
> @echo "Targets:"
> @echo "  make run   [DUT_MODE=nice|axil] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "  make com   [DUT_MODE=nice|axil] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "  make sim   [DUT_MODE=nice|axil] [case=<UVM_TESTNAME>] [seed=<int>]"
> @echo "  make vd    [DUT_MODE=nice|axil] [case=<UVM_TESTNAME>] [seed=<int>]"
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
> @echo "  make vd DUT_MODE=axil case=ai_mem_gen_smoke_test seed=20260413"
.PHONY: run soc_case soc_c com sim vd clean help
