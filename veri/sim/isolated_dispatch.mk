# Only public simulation goals dispatch here. Private child makes use the full Makefile.
_ISO_CASE_TARGETS := $(shell awk '/^\.PHONY:/ {print $$2}' regr_cases.mk)
_ISO_TARGETS := run sim npu_top_regress soc_regress soc_perf_sweep tflm_run \
 tflm_my_model_run tflm_hello_world_run tflm_micro_speech_run tflm_person_detection_run \
 tflm_mnist_mlp_run tflm_mnist_mlp_int16x8_run tflm_mnist_cnn_run \
 tflm_sensor_calibration_int16x8_run tflm_sensor_calibration_release_20261015_run \
 tflm_sensor_calibrator_20261016_run tflm_sensor_calibration_20261019_run \
 tflm_mnist_accuracy_run tflm_sensor_calibration_release_20261015_host_run $(_ISO_CASE_TARGETS)
_ISO_GOALS := $(filter $(_ISO_TARGETS),$(if $(MAKECMDGOALS),$(MAKECMDGOALS),run))
ifneq ($(_ISO_GOALS),)
ISOLATED_DISPATCH := 1
HOST_WINDOWS := $(if $(filter Windows_NT,$(OS)),1,$(if $(filter MINGW% MSYS% CYGWIN%,$(shell uname -s 2>/dev/null)),1,))
ifneq ($(HOST_WINDOWS),)
-include windows.local.mk
endif
ifeq ($(origin SHELL),default)
SHELL := /bin/bash
endif
PYTHON ?= $(if $(HOST_WINDOWS),python,python3)
simtool ?= $(if $(HOST_WINDOWS),modelsim,vcs)
DUMPOPTS ?= 0
case ?= ai_mem_gen_smoke_test
single_out ?= runs/cases
regr_timeout ?= 3600
regr_interval ?= 5
regr_keywords ?= regr_keywords.json
single_timeout ?= $(regr_timeout)
single_keywords ?= $(regr_keywords)
regr_color ?= always
# Command-line variables are exported by GNU make; pass names, not shell-expanded values.
_ISO_INPUT_NAMES := $(strip $(foreach v,$(.VARIABLES),$(if $(filter command line,$(origin $(v))),$(v),)))
_ISO_MAKE := $(MAKE)
ifneq ($(HOST_WINDOWS),)
_ISO_LAUNCH = $(PYTHON) -c 'import sys; from sim_run_common import launch_windows_make; sys.exit(launch_windows_make(*sys.argv[1:]))' "$$CASE_WORK" "$$CASE_TIMEOUT" "$(_ISO_MAKE)" --no-print-directory -j1
else
_ISO_LAUNCH = /usr/bin/timeout --kill-after=5s "$$CASE_TIMEOUT" "$(_ISO_MAKE)" --no-print-directory -j1 -C "$$CASE_WORK"
endif
.PHONY: $(_ISO_GOALS)
$(_ISO_GOALS):
	@set -e; \
	case_plan=$$(AI_CASE_TARGET="$@" AI_CASE_NAME="$(if $(filter run sim,$@),$(case),$@)" \
	  AI_CASE_TOOL="$(simtool)" AI_CASE_OUT="$(single_out)" AI_CASE_DUMP="$(DUMPOPTS)" \
	  AI_CASE_TIMEOUT="$(single_timeout)" AI_CASE_KEYWORDS="$(single_keywords)" \
	  AI_CASE_OVERRIDES="$(_ISO_INPUT_NAMES)" AI_CASE_SNAPSHOT="$(single_snapshot)" \
	  $(PYTHON) -c 'from sim_run_common import prepare_make_case; print(prepare_make_case())'); \
	. "$$case_plan"; \
	echo "[SIM] $$CASE_NAME seed=$$CASE_SEED"; \
	echo "[SIM] directory: $$CASE_ROOT"; \
	set +e; \
	env -u MAKEFLAGS -u MFLAGS -u MAKEOVERRIDES MODELSIM_BUILD_ROOT="$$CASE_ROOT/libs" \
	  $(_ISO_LAUNCH) "$$CASE_TARGET" "$${CASE_ARGS[@]}" 2>&1 | tee -a "$$CASE_LOG"; \
	case_rc=$${PIPESTATUS[0]}; \
	$(PYTHON) -c 'import sys; from sim_run_common import finish_make_case; sys.exit(finish_make_case(sys.argv[1],int(sys.argv[2])))' "$$CASE_ROOT" "$$case_rc"
endif
