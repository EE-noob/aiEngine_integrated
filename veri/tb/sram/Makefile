.PHONY: check clean

# Verilator lint check for dependency validation
check:
	verilator --lint-only --no-timing -I. \
		e203_defines.v \
		sirv_gnrl_dffs.v \
		sirv_sim_ram.v \
		sram_icb.v \
		sram_icb_ctrl.v \
		sirv_gnrl_ram.v \
		sirv_gnrl_bufs.v \
		sirv_1cyc_sram_ctrl.v \
		e203_clkgate.v

# Clean generated files
clean:
	rm -rf obj_dir
