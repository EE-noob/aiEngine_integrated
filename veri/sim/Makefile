###############################################################################
# VCS Makefile for top_ai_engine UVM environment
# Usage (from this directory):
#   make com      # compile, generate ../simv at project root
#   make sim      # run simulation (depends on com)
#   make clean    # remove compiled files and logs
###############################################################################

# Project root (this Makefile is under veri/sim/)
TOP_DIR       := ../..

# Tools
VCS           ?= vcs

# Common compile flags
VCS_FLAGS     := -full64 -sverilog -timescale=1ns/1ps \
                 -debug_access+all +vcs+lic+wait \
                 -ntb_opts uvm-1.2

# Filelist (relative to TOP_DIR)
FLIST         := veri/flist/tb1.f

# Default run arguments (can be overridden on command line: make sim RUN_ARGS=...)
RUN_ARGS      ?= +UVM_VERBOSITY=UVM_MEDIUM

###############################################################################
# Targets
###############################################################################

.PHONY: all com sim clean

all: com

com:
	@echo "=== VCS compile (top_ai_engine) ==="
	cd $(TOP_DIR) && $(VCS) $(VCS_FLAGS) -f $(FLIST) -o simv

sim: com
	@echo "=== Run simulation ==="
	cd $(TOP_DIR) && ./simv $(RUN_ARGS)

clean:
	@echo "=== Clean VCS outputs ==="
	cd $(TOP_DIR) && rm -rf simv simv.daidir csrc DVEfiles ucli.key \
		*.vpd *.vcd *.fsdb novas.rc verdiLog \
		.vcs* .inter.vpd vcs.log

