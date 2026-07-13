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
set WRAPPER_INST "lscc_fifo_dc_inst"
set WADDR_DEPTH 128
set WDATA_WIDTH 34
set RADDR_DEPTH 128
set RDATA_WIDTH 34
set FIFO_CONTROLLER "HARD_IP"
set FWFT 0
set FORCE_FAST_CONTROLLER 1
set IMPLEMENTATION "EBR"
set WADDR_WIDTH 7
set RADDR_WIDTH 7
set REGMODE "reg"
set OREG_IMPLEMENTATION "LUT"
set RESETMODE "async"
set ENABLE_ALMOST_FULL_FLAG "FALSE"
set ALMOST_FULL_ASSERTION "static-single"
set ALMOST_FULL_ASSERT_LVL 127
set ALMOST_FULL_DEASSERT_LVL 126
set ENABLE_ALMOST_EMPTY_FLAG "FALSE"
set ALMOST_EMPTY_ASSERTION "static-single"
set ALMOST_EMPTY_ASSERT_LVL 1
set ALMOST_EMPTY_DEASSERT_LVL 2
set ENABLE_DATA_COUNT_WR "FALSE"
set ENABLE_DATA_COUNT_RD "FALSE"
set FAMILY "LIFCL"



if { $radiant(stage) == "premap" } {

    if {$FAMILY == "LIFCL" | $FAMILY == "LFCPNX" | $FAMILY == "LFD2NX" | $FAMILY == "LFMXO5"} {
        set WR_CLK_PERIOD 8
        set RD_CLK_PERIOD 8
        
        if {$FIFO_CONTROLLER == "HARD_IP"} {
            set WR_MAXDLY [expr {$WR_CLK_PERIOD*0.8}]
            set RD_MAXDLY [expr {$RD_CLK_PERIOD*0.8}]
            
            set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.full_r*.*_inst] $WR_MAXDLY
            set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.afull_r*.*_inst] $WR_MAXDLY
            set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.empty_r*.*_inst] $RD_MAXDLY
            set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.aempty_r*.*_inst] $RD_MAXDLY
            set_false_path -from [get_pins -hierarchical */*.FIFO16K_MODE_inst/EMPTY] -to [get_pins -hierarchical */*.FIFO16K_MODE_inst/EMPTYI]
            set_false_path -from [get_pins -hierarchical */*.FIFO16K_MODE_inst/FULL] -to [get_pins -hierarchical */*.FIFO16K_MODE_inst/FULLI] 
            
            if {$REGMODE == "reg"} {
                set_max_delay -datapath_only -from [get_cells -hierarchical */*.empty_r*.*_inst] -to [get_cells -hierarchical */*.empty_sync_r*.*_inst] $RD_MAXDLY
                set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.empty_sync_r*.*_inst] $RD_MAXDLY
                set_max_delay -datapath_only -from [get_cells -hierarchical */*.aempty_r*.*_inst] -to [get_cells -hierarchical */*.aempty_sync_r*.*_inst] $RD_MAXDLY
                set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.aempty_sync_r*.*_inst] $RD_MAXDLY
            }
        }
        
        if {$FIFO_CONTROLLER == "FABRIC" & $IMPLEMENTATION == "LUT" & $radiant(synthesis) == "synpro"} {
            set_false_path -from [get_pins -hierarchical */_FABRIC.u_fifo/*distmem*.*/DO*] -to [get_pins -hierarchical */_FABRIC.u_fifo/DIST.out_raw*.ff_inst/DF]
        }
    
        if {$FIFO_CONTROLLER == "FABRIC" & $IMPLEMENTATION == "LUT" & $radiant(synthesis) == "lse"} {
            set_false_path -from [get_pins -hierarchical */_FABRIC.u_fifo/DIST.distmem*.dpram*/DO*] -to [get_pins -hierarchical */_FABRIC.u_fifo/DIST.out_raw*.ff_inst/DF]
        }
        
    }

}
