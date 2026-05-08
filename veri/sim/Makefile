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

OUT_DIR     ?= runs/$(case)/seed_$(seed)
FSDB        ?= $(OUT_DIR)/tb_top.fsdb
COMPILE_LOG ?= $(OUT_DIR)/compile.log
SIM_LOG     ?= $(OUT_DIR)/sim.log

ifeq ($(DUT_MODE),axil)
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

com:
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
> @echo "  make vd DUT_MODE=axil case=ai_mem_gen_smoke_test seed=20260413"
.PHONY: run com sim vd clean help
