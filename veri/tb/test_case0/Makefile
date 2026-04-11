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
TESTCASE         ?= 
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
	./$(SIMV) $(SIM_OPTS) $(DUMPFSDB) -l sim.log

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

.PHONY: all com sim vd clean gemm_ref gemm_ref_com gemm_ref_sim
