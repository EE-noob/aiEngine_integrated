###############################################################################
# Simulation Makefile for top_ai_engine UVM environment
# Usage (from this directory, veri/sim):
#   make com                # compile (default SIM_TOOL=modelsim)
#   make sim                # run simulation (depends on com)
#   make clean              # remove compiled files and logs
#   make wave               # open waveform viewer
#   make verdi              # open Verdi for VCS (GUI mode)
#
#   make com SIM_TOOL=vcs   # use VCS flow
#   make sim SIM_TOOL=vcs
#   make sim SIM_TOOL=vcs DUMP=fsdb  # dump FSDB waveform
#   make verdi SIM_TOOL=vcs          # Verdi interactive debug
###############################################################################

# Which simulator to use: modelsim or vcs
SIM_TOOL      ?= modelsim

# Waveform dump format: fsdb, vpd, or vcd (for VCS)
DUMP          ?= fsdb

# veri/ directory (this Makefile is under veri/sim/)
VERI_DIR      := ..

# Common settings
FLIST         := flist/tb1.f    # relative to VERI_DIR
TOP_MODULE    := tb_top

# -------- VCS settings --------
VCS           ?= vcs
VCS_FLAGS     := -full64 -sverilog -timescale=1ns/1ps \
                 -debug_access+all +vcs+lic+wait \
                 -ntb_opts uvm-1.2 \
                 -lca -kdb

# FSDB dump settings (requires Verdi/Novas)
ifeq ($(DUMP),fsdb)
    VCS_FLAGS += -P $(NOVAS_HOME)/share/PLI/VCS/LINUX64/novas.tab \
                 $(NOVAS_HOME)/share/PLI/VCS/LINUX64/pli.a
    DUMP_OPTS  = +fsdb+autoflush +fsdbfile+$(TOP_MODULE).fsdb
else ifeq ($(DUMP),vpd)
    DUMP_OPTS  = +vcs+dumpvars+$(TOP_MODULE).vpd
else ifeq ($(DUMP),vcd)
    DUMP_OPTS  = +vcd+vcdfile+$(TOP_MODULE).vcd
else
    DUMP_OPTS  =
endif

# -------- ModelSim/Questa settings --------
VLIB          ?= vlib
VMAP          ?= vmap
VLOG          ?= vlog
VSIM          ?= vsim

# Default run arguments (plusargs), used for both VCS and ModelSim
UVM_VERBOSITY ?= UVM_HIGH
RUN_ARGS      ?= +UVM_VERBOSITY=$(UVM_VERBOSITY)
TESTNAME      ?= ai_smoke_test

.PHONY: git
git:
	git add -A; git commit -m "auto commit"; git push origin master;

###############################################################################
# VCS flow
###############################################################################
ifeq ($(SIM_TOOL),vcs)
.PHONY: com sim clean wave verdi gui

com:
	@echo "=== VCS compile (top_ai_engine) ==="
	cd $(VERI_DIR) && $(VCS) $(VCS_FLAGS) -f $(FLIST) -o simv

sim: com
	@echo "=== Run VCS simulation (DUMP=$(DUMP)) ==="
	cd $(VERI_DIR) && ./simv $(RUN_ARGS) +UVM_TESTNAME=$(TESTNAME) $(DUMP_OPTS) -l vcs.log

# Interactive GUI simulation with Verdi
verdi: com
	@echo "=== Launch Verdi interactive debug (VCS+Verdi) ==="
	cd $(VERI_DIR) && verdi -ssf $(TOP_MODULE).fsdb -dbdir simv.daidir -sswr $(TOP_MODULE).fsdb.log &

# GUI mode: run simulation in Verdi GUI
gui: com
	@echo "=== Run VCS simulation in Verdi GUI mode ==="
	cd $(VERI_DIR) && verdi -sx -ssf $(TOP_MODULE).fsdb -f $(FLIST) \
		-top $(TOP_MODULE) -dbdir simv.daidir &

# Open waveform viewer based on dump format
wave:
ifeq ($(DUMP),fsdb)
	@echo "=== Open Verdi waveform viewer (FSDB) ==="
	cd $(VERI_DIR) && verdi -ssf $(TOP_MODULE).fsdb -nologo &
else ifeq ($(DUMP),vpd)
	@echo "=== Open VCS waveform viewer (DVE/VPD) ==="
	cd $(VERI_DIR) && dve -vpd $(TOP_MODULE).vpd &
else
	@echo "=== Open VCS waveform viewer (DVE/VCD) ==="
	cd $(VERI_DIR) && dve -vpd vcs.vpd &
endif

clean:
	@echo "=== Clean VCS outputs ==="
	cd $(VERI_DIR) && rm -rf simv simv.daidir csrc DVEfiles ucli.key \
		*.vpd *.vcd *.fsdb *.fsdb.log novas* verdiLog \
		.vcs* .inter.vpd vcs.log *.log AN.DB \
		verdi_config_file .restart* *.key *.rc

###############################################################################
# ModelSim / Questa flow
###############################################################################
else ifeq ($(SIM_TOOL),modelsim)

com:
	@echo "=== ModelSim/Questa compile (top_ai_engine) ==="
	cd $(VERI_DIR) && ($(VLIB) work || true)
	cd $(VERI_DIR) && $(VMAP) work work
	cd $(VERI_DIR) && $(VLOG) -sv -mfcu -f $(FLIST) +UVM_TESTNAME=$(TESTNAME) -l msim.log

sim: com
	@echo "=== Run ModelSim/Questa simulation ==="
	cd $(VERI_DIR) && $(VSIM) -c -wlf vsim.wlf work.$(TOP_MODULE) $(RUN_ARGS) +UVM_TESTNAME=$(TESTNAME) -l msim.log -do "log -r /*; run -all; quit"

clean:
	@echo "=== Clean ModelSim/Questa outputs ==="
	cd $(VERI_DIR) && rm -rf work transcript vsim.wlf modelsim.ini sim/ai_engine.wlf *.log

# Open saved waveform (GUI)
wave:
	@echo "=== Open ModelSim waveform viewer ==="
	cd $(VERI_DIR) && $(VSIM) -view vsim.wlf

###############################################################################
# Unknown SIM_TOOL
###############################################################################
else

com:
	@echo "ERROR: Unknown SIM_TOOL='$(SIM_TOOL)'; use 'modelsim' or 'vcs'"
	@exit 1

sim: com

clean:
	@echo "Nothing to clean for unknown SIM_TOOL"

endif
