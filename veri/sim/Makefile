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

# Waveform dump format: fsdb, vpd, vcd, or none (for VCS)
DUMP          ?= vpd

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
    # Check if VERDI_HOME is set
    ifndef VERDI_HOME
        $(error VERDI_HOME is not set. Please set VERDI_HOME environment variable or use DUMP=vpd)
    endif
    # Check if novas.tab file exists
    VERDI_TAB := $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab
    VERDI_PLI := $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a
    ifeq (,$(wildcard $(VERDI_TAB)))
        $(error FSDB PLI not found: $(VERDI_TAB). Please check VERDI_HOME or use DUMP=vpd)
    endif
    VCS_FLAGS += -P $(VERDI_TAB) $(VERDI_PLI)
    # Add +dump_fsdb to enable the dump block in top_tb.sv
    DUMP_OPTS  = +dump_fsdb +fsdb+autoflush +fsdbfile+$(TOP_MODULE).fsdb
else ifeq ($(DUMP),vpd)
    DUMP_OPTS  = +vpdfile+$(TOP_MODULE).vpd
else ifeq ($(DUMP),vcd)
    DUMP_OPTS  = +vcdfile+$(TOP_MODULE).vcd
else ifeq ($(DUMP),none)
    DUMP_OPTS  =
else
    $(warning Unknown DUMP format: $(DUMP), using vpd)
    DUMP_OPTS  = +vpdfile+$(TOP_MODULE).vpd
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
.PHONY: com sim clean wave verdi gui check_verdi

# Check Verdi availability
check_verdi:
	@command -v verdi >/dev/null 2>&1 || { echo "Error: verdi not found in PATH"; exit 1; }

com:
	@echo "=== VCS compile (top_ai_engine) ==="
	@echo "=== DUMP format: $(DUMP) ==="
ifeq ($(DUMP),fsdb)
	@echo "=== Using FSDB: VERDI_HOME=$(VERDI_HOME) ==="
endif
	cd $(VERI_DIR) && $(VCS) $(VCS_FLAGS) -f $(FLIST) -o simv

sim: com
	@echo "=== Run VCS simulation (DUMP=$(DUMP)) ==="
	cd $(VERI_DIR) && ./simv $(RUN_ARGS) +UVM_TESTNAME=$(TESTNAME) $(DUMP_OPTS) -l vcs.log

# Interactive GUI simulation with Verdi (requires FSDB)
verdi: check_verdi
ifeq ($(DUMP),fsdb)
	@echo "=== Launch Verdi interactive debug (VCS+Verdi) ==="
	@if [ -f $(VERI_DIR)/$(TOP_MODULE).fsdb ]; then \
		cd $(VERI_DIR) && verdi -ssf $(TOP_MODULE).fsdb -dbdir simv.daidir -sswr $(TOP_MODULE).fsdb.log & \
	else \
		echo "Error: FSDB file not found. Please run 'make sim DUMP=fsdb' first"; \
		exit 1; \
	fi
else
	@echo "Error: verdi target requires DUMP=fsdb"
	@echo "Please run: make sim DUMP=fsdb first, then make verdi DUMP=fsdb"
	@exit 1
endif

# GUI mode: run simulation in Verdi GUI
gui: check_verdi com
	@echo "=== Run VCS simulation in Verdi GUI mode ==="
	cd $(VERI_DIR) && verdi -sx -f $(FLIST) -top $(TOP_MODULE) \
		-simflow -simv $(VERI_DIR)/simv $(RUN_ARGS) +UVM_TESTNAME=$(TESTNAME) &

# Open waveform viewer based on dump format
wave:
ifeq ($(DUMP),fsdb)
	@echo "=== Open Verdi waveform viewer (FSDB) ==="
	@if [ -f $(VERI_DIR)/$(TOP_MODULE).fsdb ]; then \
		cd $(VERI_DIR) && verdi -ssf $(TOP_MODULE).fsdb -nologo & \
	else \
		echo "Error: $(TOP_MODULE).fsdb not found"; \
		exit 1; \
	fi
else ifeq ($(DUMP),vpd)
	@echo "=== Open VCS waveform viewer (DVE/VPD) ==="
	@if [ -f $(VERI_DIR)/$(TOP_MODULE).vpd ]; then \
		cd $(VERI_DIR) && dve -vpd $(TOP_MODULE).vpd & \
	else \
		echo "Error: $(TOP_MODULE).vpd not found"; \
		exit 1; \
	fi
else ifeq ($(DUMP),vcd)
	@echo "=== Open VCS waveform viewer (DVE/VCD) ==="
	@if [ -f $(VERI_DIR)/$(TOP_MODULE).vcd ]; then \
		cd $(VERI_DIR) && dve -vpd $(TOP_MODULE).vcd & \
	else \
		echo "Error: $(TOP_MODULE).vcd not found"; \
		exit 1; \
	fi
else
	@echo "Error: No waveform file to open (DUMP=$(DUMP))"
	@exit 1
endif

clean:
	@echo "=== Clean VCS outputs ==="
	cd $(VERI_DIR) && rm -rf simv simv.daidir csrc DVEfiles ucli.key \
		*.vpd *.vcd *.fsdb *.fsdb.log novas* verdiLog \
		.vcs* .inter.vpd vcs.log *.log AN.DB \
		verdi_config_file .restart* *.key *.rc *.conf

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

###############################################################################
# Help target
###############################################################################
.PHONY: help
help:
	@echo "Usage: make [target] [options]"
	@echo ""
	@echo "Targets:"
	@echo "  com     - Compile the design"
	@echo "  sim     - Run simulation"
	@echo "  wave    - Open waveform viewer"
	@echo "  verdi   - Open Verdi (VCS only, requires FSDB)"
	@echo "  gui     - Run simulation in Verdi GUI mode (VCS only)"
	@echo "  clean   - Clean generated files"
	@echo "  help    - Show this help message"
	@echo ""
	@echo "Options:"
	@echo "  SIM_TOOL=<modelsim|vcs>   - Select simulator (default: modelsim)"
	@echo "  DUMP=<fsdb|vpd|vcd|none>  - Waveform format (default: vpd for VCS)"
	@echo "  TESTNAME=<test>           - UVM test name (default: ai_smoke_test)"
	@echo "  UVM_VERBOSITY=<level>     - UVM verbosity (default: UVM_HIGH)"
	@echo ""
	@echo "Examples:"
	@echo "  make sim SIM_TOOL=vcs DUMP=vpd          # VCS with VPD waveform"
	@echo "  make sim SIM_TOOL=vcs DUMP=fsdb         # VCS with FSDB (requires VERDI_HOME)"
	@echo "  make verdi DUMP=fsdb                    # Open Verdi with FSDB"
	@echo "  make sim SIM_TOOL=modelsim              # ModelSim simulation"
	@echo ""
	@echo "Note: FSDB format requires VERDI_HOME environment variable to be set."
