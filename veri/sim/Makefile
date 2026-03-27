SHELL           := /bin/bash

# Configurable knobs
TOP             ?= tb_top
FILELIST        ?= ../flist/tb1.f
SIMV            ?= simv
FSDB            ?= tb_top.fsdb
DUMPOPTS        ?=1
INCDIRS         ?=
DEFINES         ?=
UVM_HOME        ?=$(VCS_HOME)/etc/uvm-1.2/
UVM_VER         ?= -ntb_opts uvm-1.2
NOVAS_HOME      ?=
utn         ?= test_case0
ifeq ($(DUMPOPTS),1)
DUMPFSDB        += +dump_fsdb
endif

FSDB_PLI        = -P $(NOVAS_HOME)/share/PLI/VCS/LINUX64/novas.tab $(NOVAS_HOME)/share/PLI/VCS/LINUX64/pli.a
VCS_OPTS        = -cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed	\
				   -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -lca \
                   $(UVM_VER) \
                   $(FSDB_PLI)

SIM_OPTS        ?=
VERDI_OPTS      ?=

run: com sim

gv:
	gcc -v 
comp:
	vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -lca -ntb_opts uvm-1.2    -f ../flist/tb1.f -top tb_top -l compile.log -o simv
com:
	@echo "[COMPILE] VCS -> $(SIMV)"
	vcs $(VCS_OPTS) $(INCDIRS:%=-y %) $(DEFINES:%=+define+%) -f $(FILELIST) -fsdb -top $(TOP) -l compile.log -o $(SIMV)

sim: 
	@echo "[SIM] ./$(SIMV) $(SIM_OPTS)"
	./$(SIMV) $(SIM_OPTS) $(DUMPFSDB) +UVM_TESTNAME=$(utn) -l sim.log

vd:
	@echo "[VERDI] verdi on $(FSDB)"
	verdi -sv -f $(FILELIST) \
	+incdir+$(UVM_HOME)/src \
	-top $(TOP) $(VERDI_OPTS) -ssf $(FSDB) &
git:
	git add -A;git commit -m "auto commit";git push origin master;

# GEMM reference model test
gemm_ref_com:
	@echo "[COMPILE] GEMM Ref Model"
	vcs $(VCS_OPTS) -f ../flist/gemm_ref.f -top tb_gemm_ref -l gemm_ref_compile.log -o simv_gemm_ref

gemm_ref_sim:
	@echo "[SIM] GEMM Ref Model"
	./simv_gemm_ref +SEED=12345 -l gemm_ref_sim.log

gemm_ref: gemm_ref_com gemm_ref_sim

clean:
	rm -rf $(SIMV) simv_gemm_ref csrc simv.daidir *.log *.key novas.* verdiLog $(FSDB)
help:
	@echo "============================================================"
	@echo " AI Engine Verification Environment - Makefile Help"
	@echo "============================================================"
	@echo ""
	@echo "Basic flow:"
	@echo "  1) make com      - compile testbench + DUT with VCS"
	@echo "  2) make sim      - run simulation using generated executable"
	@echo "  3) make vd       - open Verdi with waveform (FSDB)"
	@echo "  4) make clean    - remove generated outputs"
	@echo ""
	@echo "Main targets:"
	@echo "  make help         - show this help message"
	@echo "  make run          - compile + simulate (same as: make com sim)"
	@echo "  make com          - compile with FILELIST/TOP/SIMV and VCS_OPTS"
	@echo "  make sim          - run ./SIMV with SIM_OPTS and DUMPOPTS control"
	@echo "  make vd           - launch Verdi using FILELIST/TOP/FSDB"
	@echo "  make gemm_ref     - run GEMM reference model compile + sim"
	@echo "  make gemm_ref_com - compile GEMM reference model only"
	@echo "  make gemm_ref_sim - run GEMM reference model only"
	@echo "  make clean        - clean generated simulation artifacts"
	@echo ""
	@echo "Frequently overridden variables:"
	@echo "  TOP=<tb_top>                  : simulation top module"
	@echo "  FILELIST=<../flist/tb1.f>     : file list for VCS/Verdi"
	@echo "  SIMV=<simv>                   : output simulator executable name"
	@echo "  FSDB=<tb_top.fsdb>            : waveform file name"
	@echo "  DUMPOPTS=<1|0>                : 1 enables +dump_fsdb; 0 disables"
	@echo "  INCDIRS=\"dir1 dir2\"          : converted to -y dir1 -y dir2"
	@echo "  DEFINES=\"MACRO1 MACRO2\"      : converted to +define+MACRO1 ..."
	@echo "  SIM_OPTS=\"+SEED=1 ...\"       : extra runtime args for simulation"
	@echo "  VERDI_OPTS=\"...\"              : extra Verdi options"
	@echo "  NOVAS_HOME=<path>             : required for FSDB PLI loading"
	@echo ""
	@echo "Example commands:"
	@echo "  make run"
	@echo "  make com TOP=tb_top FILELIST=../flist/tb1.f"
	@echo "  make sim SIM_OPTS=\"+SEED=12345 +UVM_TESTNAME=smoke_test\""
	@echo "  make run DUMPOPTS=0"
	@echo "  make vd FSDB=tb_top.fsdb VERDI_OPTS=\"-nologo\""
	@echo "  make gemm_ref"
	@echo ""
	@echo "Tips:"
	@echo "  - Ensure VCS and Verdi are in PATH before running targets."
	@echo "  - If FSDB load fails, check NOVAS_HOME and FSDB_PLI paths."
	@echo "  - Use different SIMV names to keep multiple build variants."
	@echo "============================================================"
.PHONY: all com sim vd clean gemm_ref gemm_ref_com gemm_ref_sim help
