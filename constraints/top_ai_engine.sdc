############################################################
# Parameterized SDC for: top_ai_engine
#
# How to use
# - Adjust the parameters in the section "User Parameters" only.
# - All time values derive from clock periods and 0.x multipliers.
############################################################

#####################
# User Parameters
#####################

# Clock frequencies (MHz)
set NICE_CLK_MHZ 150.0
set ICB_CLK_MHZ  150.0
# Camera pixel clock (MHz) — update to your OV5640 config
set CAM_PCLK_MHZ 48.0

# Duty cycle for create_clock (0.0~1.0)
set NICE_DUTY 0.50
set ICB_DUTY  0.50
set CAM_DUTY  0.50

# Clock domain relationship: 1=asynchronous groups, 0=related
set ASYNC_GROUPS 1

# Clock uncertainty as fraction of period
set UNC_SETUP_FRAC 0.02
set UNC_HOLD_FRAC  0.01
set CAM_UNC_SETUP_FRAC 0.03
set CAM_UNC_HOLD_FRAC  0.01

# I/O delays as fraction of the associated clock period
# -max is used for setup, -min is used for hold
set IO_IN_MAX_FRAC   0.60
set IO_IN_MIN_FRAC   0.05
set IO_OUT_MAX_FRAC  0.60
set IO_OUT_MIN_FRAC  0.05

# Port groups (update if top-level ports change)
set NICE_IN_PORTS  {
  nice_req_valid nice_req_inst* nice_req_rs1* nice_req_rs2* nice_rsp_ready
  nice_icb_cmd_ready nice_icb_rsp_valid nice_icb_rsp_rdata* nice_icb_rsp_err
}
set NICE_OUT_PORTS {
  nice_active nice_mem_holdup nice_req_ready nice_rsp_valid nice_rsp_rdat* nice_rsp_err
  nice_icb_cmd_valid nice_icb_cmd_addr* nice_icb_cmd_read nice_icb_cmd_wdata* nice_icb_cmd_size*
  nice_icb_rsp_ready
}
set ICB_IN_PORTS   {
  dcmi_icb_cmd_valid dcmi_icb_cmd_addr* dcmi_icb_cmd_read dcmi_icb_cmd_wdata* dcmi_icb_cmd_wmask*
  dcmi_icb_rsp_ready
}
set ICB_OUT_PORTS  {
  dcmi_icb_cmd_ready dcmi_icb_rsp_valid dcmi_icb_rsp_rdata*
}
set CAM_IN_PORTS   {
  cam_vsync cam_href cam_data*
}
set RESET_PORTS    {
  nice_rst_n icb_rst_n 
}

set RESET_OUT_PORTS {
  cam_rst_n
}

#####################
# Derived Parameters
#####################

# Periods (ns)
set NICE_CLK_PERIOD [expr {1000.0 / $NICE_CLK_MHZ}]
set ICB_CLK_PERIOD  [expr {1000.0 / $ICB_CLK_MHZ}]
set CAM_PCLK_PERIOD [expr {1000.0 / $CAM_PCLK_MHZ}]

# High times (ns) from duty cycle
set NICE_CLK_HIGH [expr {$NICE_CLK_PERIOD * $NICE_DUTY}]
set ICB_CLK_HIGH  [expr {$ICB_CLK_PERIOD  * $ICB_DUTY }]
set CAM_PCLK_HIGH [expr {$CAM_PCLK_PERIOD * $CAM_DUTY }]

# Uncertainties (ns)
set NICE_UNC_SETUP [expr {$UNC_SETUP_FRAC * $NICE_CLK_PERIOD}]
set NICE_UNC_HOLD  [expr {$UNC_HOLD_FRAC  * $NICE_CLK_PERIOD}]
set ICB_UNC_SETUP  [expr {$UNC_SETUP_FRAC * $ICB_CLK_PERIOD }]
set ICB_UNC_HOLD   [expr {$UNC_HOLD_FRAC  * $ICB_CLK_PERIOD }]
set CAM_UNC_SETUP  [expr {$CAM_UNC_SETUP_FRAC * $CAM_PCLK_PERIOD}]
set CAM_UNC_HOLD   [expr {$CAM_UNC_HOLD_FRAC  * $CAM_PCLK_PERIOD}]

# IO delays (ns) per domain
set NICE_IN_MAX   [expr {$IO_IN_MAX_FRAC  * $NICE_CLK_PERIOD}]
set NICE_IN_MIN   [expr {$IO_IN_MIN_FRAC  * $NICE_CLK_PERIOD}]
set NICE_OUT_MAX  [expr {$IO_OUT_MAX_FRAC * $NICE_CLK_PERIOD}]
set NICE_OUT_MIN  [expr {$IO_OUT_MIN_FRAC * $NICE_CLK_PERIOD}]

set ICB_IN_MAX    [expr {$IO_IN_MAX_FRAC  * $ICB_CLK_PERIOD}]
set ICB_IN_MIN    [expr {$IO_IN_MIN_FRAC  * $ICB_CLK_PERIOD}]
set ICB_OUT_MAX   [expr {$IO_OUT_MAX_FRAC * $ICB_CLK_PERIOD}]
set ICB_OUT_MIN   [expr {$IO_OUT_MIN_FRAC * $ICB_CLK_PERIOD}]

set CAM_IN_MAX    [expr {$IO_IN_MAX_FRAC  * $CAM_PCLK_PERIOD}]
set CAM_IN_MIN    [expr {$IO_IN_MIN_FRAC  * $CAM_PCLK_PERIOD}]

#####################
# Clocks
#####################

create_clock -name nice_clk -period $NICE_CLK_PERIOD -waveform {0.0 $NICE_CLK_HIGH} [get_ports nice_clk]
create_clock -name icb_clk  -period $ICB_CLK_PERIOD  -waveform {0.0 $ICB_CLK_HIGH } [get_ports icb_clk]
create_clock -name cam_pclk -period $CAM_PCLK_PERIOD -waveform {0.0 $CAM_PCLK_HIGH} [get_ports cam_pclk]

#####################
# Clock Groups (CDC)
#####################

if {$ASYNC_GROUPS} {
  set_clock_groups -asynchronous \
    -group { nice_clk } \
    -group { icb_clk } \
    -group { cam_pclk }
}

#####################
# Clock Uncertainty
#####################

set_clock_uncertainty -setup $NICE_UNC_SETUP [get_clocks nice_clk]
set_clock_uncertainty -hold  $NICE_UNC_HOLD  [get_clocks nice_clk]

set_clock_uncertainty -setup $ICB_UNC_SETUP  [get_clocks icb_clk]
set_clock_uncertainty -hold  $ICB_UNC_HOLD   [get_clocks icb_clk]

set_clock_uncertainty -setup $CAM_UNC_SETUP  [get_clocks cam_pclk]
set_clock_uncertainty -hold  $CAM_UNC_HOLD   [get_clocks cam_pclk]

#####################
# Async Resets — cut timing
#####################

set_false_path -from [get_ports $RESET_PORTS]
set_false_path -to   [get_ports $RESET_OUT_PORTS]

#####################
# IO Delays (fraction of period)
#####################

# nice_clk domain
set_input_delay  -clock [get_clocks nice_clk] -max $NICE_IN_MAX  [get_ports $NICE_IN_PORTS]
set_input_delay  -clock [get_clocks nice_clk] -min $NICE_IN_MIN  -add_delay [get_ports $NICE_IN_PORTS]
set_output_delay -clock [get_clocks nice_clk] -max $NICE_OUT_MAX [get_ports $NICE_OUT_PORTS]
set_output_delay -clock [get_clocks nice_clk] -min $NICE_OUT_MIN -add_delay [get_ports $NICE_OUT_PORTS]

# icb_clk domain
set_input_delay  -clock [get_clocks icb_clk]  -max $ICB_IN_MAX   [get_ports $ICB_IN_PORTS]
set_input_delay  -clock [get_clocks icb_clk]  -min $ICB_IN_MIN   -add_delay [get_ports $ICB_IN_PORTS]
set_output_delay -clock [get_clocks icb_clk]  -max $ICB_OUT_MAX  [get_ports $ICB_OUT_PORTS]
set_output_delay -clock [get_clocks icb_clk]  -min $ICB_OUT_MIN  -add_delay [get_ports $ICB_OUT_PORTS]

# cam_pclk domain (source-synchronous camera inputs)
set_input_delay  -clock [get_clocks cam_pclk] -max $CAM_IN_MAX   [get_ports $CAM_IN_PORTS]
set_input_delay  -clock [get_clocks cam_pclk] -min $CAM_IN_MIN   -add_delay [get_ports $CAM_IN_PORTS]

#####################
# Optional electrical assumptions (comment out if your tool warns)
#####################
# set_input_transition 0.20 [remove_from_collection [all_inputs] [get_ports {nice_clk icb_clk cam_pclk}]]
# set_load            0.10 [all_outputs]
