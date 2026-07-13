import os

def load_parameter(param_name):
    f_params = open('eval/dut_params.v', 'r')
    while f_params:
        line = f_params.readline()
        if (param_name in line):
            str_spl = line.split('=')
            val = str_spl[1]
            f_val = val.replace(";\n",'')
            f_val2 = f_val.replace("\"",'')
            f_val3 = f_val2.replace(" ",'')
            break
    f_params.close()
    return (f_val3)

def write_constraint():
    f_constraint = open('eval/constraint.pdc', 'w')
    
    family_param    = load_parameter("FAMILY")
    fifo_controller = load_parameter("FIFO_CONTROLLER")
    mem_controller  = load_parameter("IMPLEMENTATION")
    reg_param       = load_parameter("REGMODE")
    
    f_constraint.write("## Set clock period per design requirements \n")
    if (family_param == "LAV-AT"):
            f_constraint.write("set WR_CLK_PERIOD 5\n")
            f_constraint.write("set RD_CLK_PERIOD 5\n")
            f_constraint.write("\n")
    elif (family_param == "LFCPNX"):
            f_constraint.write("set WR_CLK_PERIOD 8\n")
            f_constraint.write("set RD_CLK_PERIOD 8\n")
            f_constraint.write("\n")
    else:
        f_constraint.write("set WR_CLK_PERIOD 10\n")
        f_constraint.write("set RD_CLK_PERIOD 10\n")
        f_constraint.write("\n")
    
    f_constraint.write("create_clock -name {wr_clk_i} -period $WR_CLK_PERIOD [get_ports wr_clk_i]\n")
    f_constraint.write("create_clock -name {rd_clk_i} -period $RD_CLK_PERIOD [get_ports rd_clk_i]\n")
    f_constraint.write("\n")
    
    if (family_param != "LAV-AT" and fifo_controller == "FABRIC" and mem_controller == "LUT"):
        f_constraint.write("## When FIFO Memory used is LUT-Based, set constraint from distributed memory to output data \n")
        f_constraint.write("set RD_MAXDLY [expr {$RD_CLK_PERIOD*0.8}]\n")
        f_constraint.write("set_false_path -from [get_pins -hierarchical */_FABRIC.u_fifo/*distmem*.*/DO*] -to [get_pins -hierarchical */_FABRIC.u_fifo/DIST.out_raw*.ff_inst/DF]\n")
        f_constraint.write("\n")
    
    if (family_param != "LAV-AT" and fifo_controller == "HARD_IP"):
        f_constraint.write("## Constraints when Nexus HARD_IP is used \n")
        f_constraint.write("set WR_MAXDLY [expr {$WR_CLK_PERIOD*0.8}]\n")
        f_constraint.write("set RD_MAXDLY [expr {$RD_CLK_PERIOD*0.8}]\n")
        f_constraint.write("set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.full_r*.*_inst]   $WR_MAXDLY \n")
        f_constraint.write("set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.afull_r*.*_inst]  $WR_MAXDLY \n")
        f_constraint.write("set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.empty_r*.*_inst]  $RD_MAXDLY \n")
        f_constraint.write("set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.aempty_r*.*_inst] $RD_MAXDLY \n")
        f_constraint.write("set_false_path -from [get_pins -hierarchical */*.FIFO16K_MODE_inst/EMPTY] -to [get_pins -hierarchical */*.FIFO16K_MODE_inst/EMPTYI] \n")
        f_constraint.write("set_false_path -from [get_pins -hierarchical */*.FIFO16K_MODE_inst/FULL] -to [get_pins -hierarchical */*.FIFO16K_MODE_inst/FULLI] \n")
        f_constraint.write("\n")
        
        if (reg_param == "reg"):
            f_constraint.write("## Additional constraints when Output Register is Enabled \n")
            f_constraint.write("set_max_delay -datapath_only -from [get_cells -hierarchical */*.empty_r*.*_inst] -to [get_cells -hierarchical */*.empty_sync_r*.*_inst]    $RD_MAXDLY \n")
            f_constraint.write("set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.empty_sync_r*.*_inst]  $RD_MAXDLY \n")
            f_constraint.write("set_max_delay -datapath_only -from [get_cells -hierarchical */*.aempty_r*.*_inst] -to [get_cells -hierarchical */*.aempty_sync_r*.*_inst]  $RD_MAXDLY \n")
            f_constraint.write("set_max_delay -datapath_only -from [get_cells -hierarchical */*.FIFO16K_MODE_inst] -to [get_cells -hierarchical */*.aempty_sync_r*.*_inst] $RD_MAXDLY \n")

    f_constraint.close()


write_constraint()
