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
	vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -lca -ntb_opts uvm-1.2    -f ../flist/tb1.f -top tb_top -l compile.log -o simv"
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
clean:
	rm -rf $(SIMV) csrc simv.daidir *.log *.key novas.* verdiLog $(FSDB)

.PHONY: all com sim vd clean
