# Regression case name == make target; recipes retain the underlying UVM class.
# Presets copied from coverage_plan.json; no coverage collection implied.

.PHONY: axil_functional_coverpoints
axil_functional_coverpoints:
	"$(MAKE)" run DUT_MODE="axil" case="ai_coverage_test" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SIM_ARGS="$(SIM_ARGS) +MEM_GEN_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),1)" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),1) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),1)

.PHONY: axil_mem_gen_smoke
axil_mem_gen_smoke:
	"$(MAKE)" run DUT_MODE="axil" case="ai_mem_gen_smoke_test" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SIM_ARGS="$(SIM_ARGS) +MEM_GEN_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260413)" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260413) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260413)

.PHONY: axil_ral_mem_gen_start
axil_ral_mem_gen_start:
	"$(MAKE)" run DUT_MODE="axil" case="ai_ral_mem_gen_on_calc_start_test" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SIM_ARGS="$(SIM_ARGS) +MEM_GEN_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260414)" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260414) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260414)

.PHONY: axil_reg_directed
axil_reg_directed:
	"$(MAKE)" run DUT_MODE="axil" case="ai_axil_reg_directed_test" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SIM_ARGS="$(SIM_ARGS) +MEM_GEN_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260415)" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260415) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260415)

.PHONY: soc_runtime_ws_int8
soc_runtime_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="16" SOC_N="16" SOC_M="16" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_TIMEOUT_CYCLES="5000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),70000) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),70000)

.PHONY: soc_reg_directed
soc_reg_directed:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="case" SOC_CASE="axi_soc_cov_reg_directed" SOC_C_SRC="../soc_csrc/soc_reg_directed_main.c" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="1" SOC_N="1" SOC_M="1" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_TIMEOUT_CYCLES="1000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260416) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),20260416)

.PHONY: soc_runtime_is_int16
soc_runtime_is_int16:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_is_int16" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="16" SOC_N="16" SOC_M="16" SOC_LHS_DTYPE="2" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="1" SOC_TIMEOUT_CYCLES="5000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),70001) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),70001)

.PHONY: soc_runtime_per_channel_int8
soc_runtime_per_channel_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_pc_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="16" SOC_N="16" SOC_M="16" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="1" SOC_DATAFLOW_MODE="0" SOC_TIMEOUT_CYCLES="5000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71000) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71000)

.PHONY: soc_reuse_ws_int8
soc_reuse_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_reuse_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="32" SOC_N="64" SOC_M="48" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_IA_REUSE_NUM="2" SOC_W_REUSE_NUM="4" SOC_TIMEOUT_CYCLES="15000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71500) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71500)

.PHONY: soc_reuse_is_int16
soc_reuse_is_int16:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_reuse_is_int16" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="32" SOC_N="64" SOC_M="48" SOC_LHS_DTYPE="2" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="1" SOC_IA_REUSE_NUM="2" SOC_W_REUSE_NUM="4" SOC_TIMEOUT_CYCLES="15000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71501) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71501)

.PHONY: soc_reuse_wide_ws_int8
soc_reuse_wide_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_reuse_wide_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="64" SOC_N="64" SOC_M="64" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_IA_REUSE_NUM="8" SOC_W_REUSE_NUM="8" SOC_TIMEOUT_CYCLES="30000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71510) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71510)

.PHONY: soc_reuse_multigroup_ws_int8
soc_reuse_multigroup_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_reuse_multigroup_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="16" SOC_N="16" SOC_M="128" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_IA_REUSE_NUM="1" SOC_W_REUSE_NUM="4" SOC_TIMEOUT_CYCLES="30000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71512) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71512)

.PHONY: soc_reuse_multigroup_deep_ws_int8
soc_reuse_multigroup_deep_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_reuse_multigroup_deep_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="16" SOC_N="16" SOC_M="256" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_IA_REUSE_NUM="1" SOC_W_REUSE_NUM="4" SOC_TIMEOUT_CYCLES="50000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71513) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71513)

.PHONY: soc_reuse_wide_is_int16
soc_reuse_wide_is_int16:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_reuse_wide_is_int16" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="64" SOC_N="64" SOC_M="64" SOC_LHS_DTYPE="2" SOC_QUANT_MODE="1" SOC_DATAFLOW_MODE="1" SOC_IA_REUSE_NUM="8" SOC_W_REUSE_NUM="8" SOC_TIMEOUT_CYCLES="30000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71511) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71511)

.PHONY: soc_saturation_clamp_ws_int8
soc_saturation_clamp_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_saturation_clamp_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="0" SOC_K="16" SOC_N="64" SOC_M="16" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_DST_MULT="1073741824" SOC_DST_SHIFT="0" SOC_ACT_MIN="-1" SOC_ACT_MAX="1" SOC_TIMEOUT_CYCLES="15000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71520) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71520)

.PHONY: soc_saturation_clamp_is_int8
soc_saturation_clamp_is_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_saturation_clamp_is_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="0" SOC_K="16" SOC_N="64" SOC_M="16" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="1" SOC_DST_MULT="1073741824" SOC_DST_SHIFT="0" SOC_ACT_MIN="-1" SOC_ACT_MAX="1" SOC_TIMEOUT_CYCLES="15000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71521) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),71521)

.PHONY: soc_per_channel_clamp_ws_int8
soc_per_channel_clamp_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_pc_clamp_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="0" SOC_K="16" SOC_N="64" SOC_M="16" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="1" SOC_DATAFLOW_MODE="0" SOC_DST_MULT="2147483647" SOC_DST_SHIFT="0" SOC_ACT_MIN="-1" SOC_ACT_MAX="1" SOC_TIMEOUT_CYCLES="15000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72000) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72000)

.PHONY: soc_requant_directed_clamp_ws_int8
soc_requant_directed_clamp_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_requant_clamp_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="0" SOC_DIRECTED_PATTERN="requant_clamp_bipolar" SOC_K="16" SOC_N="64" SOC_M="16" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="1" SOC_DATAFLOW_MODE="0" SOC_DST_MULT="2147483647" SOC_DST_SHIFT="0" SOC_ACT_MIN="-1" SOC_ACT_MAX="1" SOC_TIMEOUT_CYCLES="15000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72030) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72030)

.PHONY: soc_tail_ws_int8
soc_tail_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_tail_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="17" SOC_N="31" SOC_M="19" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_TIMEOUT_CYCLES="8000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72000) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72000)

.PHONY: soc_tail_is_int16
soc_tail_is_int16:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_tail_is_int16" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="17" SOC_N="31" SOC_M="19" SOC_LHS_DTYPE="2" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="1" SOC_TIMEOUT_CYCLES="8000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72001) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72001)

.PHONY: soc_tail_per_channel_int16
soc_tail_per_channel_int16:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_tail_pc_int16" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="33" SOC_N="17" SOC_M="23" SOC_LHS_DTYPE="2" SOC_QUANT_MODE="1" SOC_DATAFLOW_MODE="0" SOC_TIMEOUT_CYCLES="10000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72002) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72002)

.PHONY: soc_fifo_wrap_tail2_ws_int8
soc_fifo_wrap_tail2_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_fifo_wrap_tail2_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="272" SOC_N="16" SOC_M="18" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_W_REUSE_NUM="4" SOC_TIMEOUT_CYCLES="20000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72014) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72014)

.PHONY: soc_unaligned_randlat_ws_int8
soc_unaligned_randlat_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_unaligned_randlat_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="24" SOC_N="32" SOC_M="16" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_UNALIGNED_LAYOUT="1" SIM_ARGS="+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=3 +DDR_W_MAX_LAT=2 +DDR_RSP_MAX_LAT=8" SOC_TIMEOUT_CYCLES="10000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72003) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72003)

.PHONY: soc_runtime_per_channel_ws_int16
soc_runtime_per_channel_ws_int16:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_pc_ws_int16" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="16" SOC_N="16" SOC_M="16" SOC_LHS_DTYPE="2" SOC_QUANT_MODE="1" SOC_DATAFLOW_MODE="0" SOC_TIMEOUT_CYCLES="6000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72004) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72004)

.PHONY: soc_runtime_per_channel_is_int8
soc_runtime_per_channel_is_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_pc_is_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="16" SOC_N="16" SOC_M="16" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="1" SOC_DATAFLOW_MODE="1" SOC_TIMEOUT_CYCLES="6000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72005) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72005)

.PHONY: soc_min_tile_ws_int8
soc_min_tile_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_min_tile_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="1" SOC_N="1" SOC_M="1" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_TIMEOUT_CYCLES="3000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72006) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72006)

.PHONY: soc_offset_activation_ws_int8
soc_offset_activation_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_offset_activation_ws_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="0" SOC_K="16" SOC_N="32" SOC_M="32" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_LHS_OFFSET="-17" SOC_RHS_OFFSET="13" SOC_DST_OFFSET="-5" SOC_ACT_MIN="-32" SOC_ACT_MAX="63" SOC_TIMEOUT_CYCLES="10000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72007) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72007)

.PHONY: soc_randlat_is_int8
soc_randlat_is_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_randlat_is_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="19" SOC_N="17" SOC_M="31" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="1" SOC_DATAFLOW_MODE="1" SIM_ARGS="+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=5 +DDR_W_MAX_LAT=3 +DDR_RSP_MAX_LAT=10" SOC_TIMEOUT_CYCLES="12000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72009) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72009)

.PHONY: soc_min_tile_is_int16
soc_min_tile_is_int16:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_min_tile_is_int16" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="1" SOC_N="1" SOC_M="1" SOC_LHS_DTYPE="2" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="1" SOC_TIMEOUT_CYCLES="3000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72010) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72010)

.PHONY: soc_offset_activation_is_int16
soc_offset_activation_is_int16:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_offset_activation_is_int16" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="0" SOC_K="16" SOC_N="32" SOC_M="32" SOC_LHS_DTYPE="2" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="1" SOC_LHS_OFFSET="-17" SOC_RHS_OFFSET="13" SOC_DST_OFFSET="-5" SOC_ACT_MIN="-32" SOC_ACT_MAX="63" SOC_TIMEOUT_CYCLES="10000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72012) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72012)

.PHONY: soc_tail_per_channel_is_int8
soc_tail_per_channel_is_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_tail_pc_is_int8" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_RANDOM="0" SOC_FIX_MODE="1" SOC_K="33" SOC_N="17" SOC_M="23" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="1" SOC_DATAFLOW_MODE="1" SOC_TIMEOUT_CYCLES="10000000" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72013) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),72013)

.PHONY: soc_sensor_int16x8_output
soc_sensor_int16x8_output:
	"$(MAKE)" tflm_sensor_calibration_int16x8_run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="tflm_sensor_calibration_int16x8" SOC_CASE="axi_soc_cov_sensor_s16_output" SOC_CPU_MEM_DP="262144" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" TFLM_SOC_MMA_ENABLE="1" TFLM_NMSIS_NN_ENABLE="1" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),1) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),1)

.PHONY: soc_dma_4k_boundary_ws_int16
soc_dma_4k_boundary_ws_int16:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_soc_dma_4k_boundary_ws_int16" SOC_CPU_MEM_DP="65536" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_K="17" SOC_N="1041" SOC_M="19" SOC_LHS_DTYPE="2" SOC_QUANT_MODE="1" SOC_DATAFLOW_MODE="0" SOC_UNALIGNED_LAYOUT="1" SOC_TIMEOUT_CYCLES="15000000" SIM_ARGS="+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=5 +DDR_W_MAX_LAT=3 +DDR_RSP_MAX_LAT=10" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),1) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),1)

.PHONY: soc_dma_long_row_ws_int8
soc_dma_long_row_ws_int8:
	"$(MAKE)" run DUT_MODE="axi_soc" case="ai_axi_soc_c_test" SOC_APP="runtime" SOC_CASE="axi_soc_cov_soc_dma_long_row_ws_int8" SOC_CPU_MEM_DP="65536" MMA_SIZE="16" MMA_IA_CACHE_BLOCKS="4" MMA_PS_FRAME_COUNT="16" SOC_K="3" SOC_N="4097" SOC_M="5" SOC_LHS_DTYPE="1" SOC_QUANT_MODE="0" SOC_DATAFLOW_MODE="0" SOC_UNALIGNED_LAYOUT="1" SOC_TIMEOUT_CYCLES="15000000" SIM_ARGS="+DDR_RAND_LAT=1 +DDR_CMD_MAX_LAT=5 +DDR_W_MAX_LAT=3 +DDR_RSP_MAX_LAT=10" seed=$(if $(strip $(REGR_SEED)),$(REGR_SEED),1) SOC_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),1)

.PHONY: ai_axil_reg_directed_test
ai_axil_reg_directed_test:
	"$(MAKE)" run DUT_MODE=axil case=ai_axil_reg_directed_test $(if $(strip $(REGR_SEED)),seed=$(REGR_SEED) SOC_SEED=$(REGR_SEED),) SIM_ARGS="$(SIM_ARGS) +MEM_GEN_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),$(seed))"

.PHONY: ai_mem_gen_smoke_test
ai_mem_gen_smoke_test:
	"$(MAKE)" run DUT_MODE=axil case=ai_mem_gen_smoke_test $(if $(strip $(REGR_SEED)),seed=$(REGR_SEED) SOC_SEED=$(REGR_SEED),) SIM_ARGS="$(SIM_ARGS) +MEM_GEN_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),$(seed))"

.PHONY: ai_ral_mem_gen_on_calc_start_test
ai_ral_mem_gen_on_calc_start_test:
	"$(MAKE)" run DUT_MODE=axil case=ai_ral_mem_gen_on_calc_start_test $(if $(strip $(REGR_SEED)),seed=$(REGR_SEED) SOC_SEED=$(REGR_SEED),) SIM_ARGS="$(SIM_ARGS) +MEM_GEN_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),$(seed))"

.PHONY: ai_coverage_test
ai_coverage_test:
	"$(MAKE)" run DUT_MODE=axil case=ai_coverage_test $(if $(strip $(REGR_SEED)),seed=$(REGR_SEED) SOC_SEED=$(REGR_SEED),) SIM_ARGS="$(SIM_ARGS) +MEM_GEN_SEED=$(if $(strip $(REGR_SEED)),$(REGR_SEED),$(seed))"

.PHONY: ai_axi_soc_c_test
ai_axi_soc_c_test:
	"$(MAKE)" run DUT_MODE=axi_soc case=ai_axi_soc_c_test SOC_APP=runtime $(if $(strip $(REGR_SEED)),seed=$(REGR_SEED) SOC_SEED=$(REGR_SEED),)
