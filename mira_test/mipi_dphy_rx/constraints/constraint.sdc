set device "LIFCL-40"
set device_int "je5d30"
set package "CABGA400"
set package_int "CABGA400"
set speed "9_High-Performance_1.0V"
set speed_int "12"
set operation "Commercial"
set family "LIFCL"
set architecture "je5d00"
set partnumber "LIFCL-40-9BG400C"
set WRAPPER_INST "lscc_mipi_dphy_inst"
set INT_TYPE "RX"
set FAMILY "LIFCL"
set INTF "CSI2_APP"
set DPHY_IP "HARD_IP"
set CIL_BYPASS "CIL_ENABLED"
set PLL_MODE "EXTERNAL"
set CLK_MODE "ENABLED"
set INT_DATA_RATE 1500.000000
set GEAR 16
set NUM_LANE 2
set SYNC_CLOCK_FREQ 96
set HSEL "DISABLED"
set CN "11000"
set CO "000"
set CM "11011110"
set REF_CLOCK_FROM_IO_PIN 0
set REF_CLK_INPUT_BUF_TYPE "MIPI_DPHY"
set START_UP_SYNCH_LOGIC 0
set T_DATA_SETTLE "1111"
set T_CLK_SETTLE "1011"
set DPHY_TEST_PATTERN "0b10000000001000000000000000000000"
set INTFBKDEL_SEL "DISABLED"
set PMU_WAITFORLOCK "ENABLED"
set REF_OSC_CTRL "3P2"
set REF_COUNTS "0000"
set EN_REFCLK_MON 0
set FVCO 800.000000
set CLKI_FREQ 100.000000
set CLKI_DIVIDER_ACTUAL_STR "1"
set FRAC_N_EN 0
set FBK_MODE "CLKOP"
set FBCLK_DIVIDER_ACTUAL_STR "1"
set SSC_N_CODE_STR "0b000000001"
set SSC_F_CODE_STR "0b000000000000000"
set SS_EN 0
set SSC_PROFILE "DOWN"
set SSC_TBASE_STR "0b000000000000"
set SSC_STEP_IN_STR "0b0000000"
set SSC_REG_WEIGHTING_SEL_STR "0b000"
set CLKOP_BYPASS 1
set ENCLKOP_EN 0
set CLKOP_FREQ_ACTUAL 100.000000
set CLKOP_PHASE_ACTUAL 0.000000
set DIVOP_ACTUAL_STR "7"
set DELA "7"
set PHIA "0"
set TRIM_EN_P 0
set CLKOP_TRIM_MODE "Falling"
set CLKOP_TRIM "0b0000"
set CLKOS_EN 1
set CLKOS_BYPASS 0
set ENCLKOS_EN 0
set CLKOS_FREQ_ACTUAL 100.000000
set CLKOS_PHASE_ACTUAL 0.000000
set DIVOS_ACTUAL_STR "7"
set DELB "7"
set PHIB "0"
set TRIM_EN_S 0
set CLKOS_TRIM_MODE "Falling"
set CLKOS_TRIM "0b0000"
set CLKOS2_EN 0
set CLKOS2_BYPASS 0
set ENCLKOS2_EN 0
set CLKOS2_FREQ_ACTUAL 100.000000
set CLKOS2_PHASE_ACTUAL 0.000000
set DIVOS2_ACTUAL_STR "7"
set DELC "7"
set PHIC "0"
set CLKOS3_EN 0
set CLKOS3_BYPASS 0
set ENCLKOS3_EN 0
set CLKOS3_FREQ_ACTUAL 100.000000
set CLKOS3_PHASE_ACTUAL 0.000000
set DIVOS3_ACTUAL_STR "7"
set DELD "7"
set PHID "0"
set CLKOS4_EN 0
set CLKOS4_BYPASS 0
set ENCLKOS4_EN 0
set CLKOS4_FREQ_ACTUAL 100.000000
set CLKOS4_PHASE_ACTUAL 0.000000
set DIVOS4_ACTUAL_STR "7"
set DELE "7"
set PHIE "0"
set CLKOS5_EN 0
set CLKOS5_BYPASS 0
set ENCLKOS5_EN 0
set CLKOS5_FREQ_ACTUAL 100.000000
set CLKOS5_PHASE_ACTUAL 0.000000
set DIVOS5_ACTUAL_STR "7"
set DELF "7"
set PHIF "0"
set PLL_REFCLK_FROM_PIN 0
set IO_TYPE "LVDS"
set DYN_PORTS_EN 0
set PLL_RST 1
set LOCK_EN 1
set PLL_LOCK_STICKY 0
set LMMI_EN 0
set APB_EN 0
set LEGACY_EN 0
set POWERDOWN_EN 0
set IPI_CMP "0b0100"
set CSET "24P"
set CRIPPLE "3P"
set IPP_CTRL "0b0100"
set IPP_SEL "0b1111"
set BW_CTL_BIAS "0b1111"
set V2I_PP_RES "9K"
set KP_VCO "0b00011"
set V2I_KVCO_SEL "60"
set V2I_1V_EN "ENABLED"


# Clock period calculations for different clock domains
set SYNC_CLK_PERIOD [expr {double(round(1000000/$SYNC_CLOCK_FREQ ))/1000}]
set PLL_CLK_PERIOD [expr {double(round(1000000/$CLKOP_FREQ_ACTUAL ))/1000}]
set CLKOP_FREQ_VAL  [expr {round($CLKOP_FREQ_ACTUAL)}]


if { $radiant(stage) == "presyn" } {
	if {$INT_TYPE == "TX" & $PLL_MODE == "EXTERNAL"} {
		# sync_clk_i is the PLL reference clock at SYNC_CLOCK_FREQ
		create_clock -name {sync_clk_i} -period $SYNC_CLK_PERIOD [get_ports sync_clk_i]
		# PLL output clocks run at CLKOP_FREQ_ACTUAL
		create_clock -name {pll_clkop_i} -period $PLL_CLK_PERIOD [get_ports pll_clkop_i]
		create_clock -name {pll_clkos_i} -period $PLL_CLK_PERIOD [get_ports pll_clkos_i]
	} elseif {$INT_TYPE == "TX" & $PLL_MODE == "INTERNAL"} {
		# sync_clk_i is the PLL reference clock at SYNC_CLOCK_FREQ
		create_clock -name {sync_clk_i} -period $SYNC_CLK_PERIOD [get_ports sync_clk_i]
	} else {
		# For RX mode, sync_clk_i is the reference clock at SYNC_CLOCK_FREQ
		create_clock -name {sync_clk_i} -period $SYNC_CLK_PERIOD [get_ports sync_clk_i]
		#create_clock -name {clk_p_io} -period $CLK_PERIOD [get_ports clk_p_io]
	}
} elseif { $radiant(stage) == "premap" } {
	set_false_path -to [get_pins -hierarchical u_eclkdiv.ECLKDIV_inst/DIVRST]
}


### Old SDC Content
#set CLK_PERIOD [expr {double(round(1000000/$SYNC_CLOCK_FREQ ))/1000}]
#set CLKOP_FREQ_VAL  [expr {round($CLKOP_FREQ_ACTUAL)}]
#
#
#if { $radiant(stage) == "presyn" } {
#	if {$INT_TYPE == "TX" & $PLL_MODE == "EXTERNAL"} {
#		create_clock -name {sync_clk_i} -period $CLK_PERIOD [get_ports sync_clk_i]
#		create_clock -name {pll_clkop_i} -period $CLK_PERIOD [get_ports pll_clkop_i]
#		create_clock -name {pll_clkos_i} -period $CLK_PERIOD [get_ports pll_clkos_i]
#	} elseif {$INT_TYPE == "TX" & $PLL_MODE == "INTERNAL"} {
#		create_clock -name {sync_clk_i} -period $CLK_PERIOD [get_ports sync_clk_i]
#	} else {
#		create_clock -name {sync_clk_i} -period $CLK_PERIOD [get_ports sync_clk_i]
#		#create_clock -name {clk_p_io} -period $CLK_PERIOD [get_ports clk_p_io]
#	}
#} elseif { $radiant(stage) == "premap" } {
#	set_false_path -to [get_pins -hierarchical u_eclkdiv.ECLKDIV_inst/DIVRST]
#}