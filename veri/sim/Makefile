###############################################################################
# Simulation Makefile for top_ai_engine UVM environment
# Usage (from this directory, veri/sim):
#   make com                # compile (default SIM_TOOL=modelsim)
#   make sim                # run simulation (depends on com)
#   make clean              # remove compiled files and logs
#
#   make com SIM_TOOL=vcs   # use VCS flow
#   make sim SIM_TOOL=vcs
###############################################################################

# Which simulator to use: modelsim or vcs
SIM_TOOL      ?= modelsim

# veri/ directory (this Makefile is under veri/sim/)
VERI_DIR      := ..

# Common settings
FLIST         := flist/tb1.f    # relative to VERI_DIR
TOP_MODULE    := tb_top

# -------- VCS settings --------
VCS           ?= vcs
VCS_FLAGS     := -full64 -sverilog -timescale=1ns/1ps \
                 -debug_access+all +vcs+lic+wait \
                 -ntb_opts uvm-1.2

# -------- ModelSim/Questa settings --------
VLIB          ?= vlib
VMAP          ?= vmap
VLOG          ?= vlog
VSIM          ?= vsim

# Default run arguments (plusargs), used for both VCS and ModelSim
RUN_ARGS      ?= +UVM_VERBOSITY=UVM_MEDIUM

###############################################################################
# Targets
###############################################################################

.PHONY: all com sim clean

all: com

###############################################################################
# VCS flow
###############################################################################
ifeq ($(SIM_TOOL),vcs)

com:
	@echo "=== VCS compile (top_ai_engine) ==="
	cd $(VERI_DIR) && $(VCS) $(VCS_FLAGS) -f $(FLIST) -o simv

sim: com
	@echo "=== Run VCS simulation ==="
	cd $(VERI_DIR) && ./simv $(RUN_ARGS)

clean:
	@echo "=== Clean VCS outputs ==="
	cd $(VERI_DIR) && rm -rf simv simv.daidir csrc DVEfiles ucli.key \
		*.vpd *.vcd *.fsdb novas.rc verdiLog \
		.vcs* .inter.vpd vcs.log

###############################################################################
# ModelSim / Questa flow
###############################################################################
else ifeq ($(SIM_TOOL),modelsim)

com:
	@echo "=== ModelSim/Questa compile (top_ai_engine) ==="
	cd $(VERI_DIR) && ($(VLIB) work || true)
	cd $(VERI_DIR) && $(VMAP) work work
	cd $(VERI_DIR) && $(VLOG) -sv -f $(FLIST)

sim: com
	@echo "=== Run ModelSim/Questa simulation ==="
	cd $(VERI_DIR) && $(VSIM) -c work.$(TOP_MODULE) $(RUN_ARGS) -do "run -all; quit"

clean:
	@echo "=== Clean ModelSim/Questa outputs ==="
	cd $(VERI_DIR) && rm -rf work transcript vsim.wlf modelsim.ini

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
