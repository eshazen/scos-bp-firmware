#-- Lattice Semiconductor Corporation Ltd.
#-- Synplify OEM project file

#device options
set_option -technology LIFCL
set_option -part LIFCL_40
set_option -package CABGA400C
set_option -speed_grade -9
#compilation/mapping options
set_option -symbolic_fsm_compiler true
set_option -resource_sharing true

#use verilog standard option
set_option -vlog_std v2001

#map options
set_option -frequency 200
set_option -maxfan 1000
set_option -auto_constrain_io 0
set_option -retiming false; set_option -pipe true
set_option -force_gsr false
set_option -compiler_compatible 0


set_option -default_enum_encoding default

#timing analysis options



#automatic place and route (vendor) options
set_option -write_apr_constraint 1

#synplifyPro options
set_option -fix_gated_and_generated_clocks 0
set_option -update_models_cp 0
set_option -resolve_multiple_driver 0
set_option -vhdl2008 1

set_option -rw_check_on_ram 0
set_option -seqshift_no_replicate 0
set_option -automatic_compile_point 0

#-- set any command lines input by customer

set_option -dup false
set_option -disable_io_insertion false
add_file -constraint {C:/lscc/radiant/2025.2/scripts/tcl/flow/radiant_synplify_vars.tcl}
add_file -constraint {mira_test_impl_1_cpe.ldc}
add_file -verilog {C:/lscc/radiant/2025.2/ip/pmi/pmi_lifcl.v}
add_file -vhdl -lib pmi {C:/lscc/radiant/2025.2/ip/pmi/pmi_lifcl.vhd}
add_file -vhdl -lib "work" {C:/Users/Bernhard/my_designs/mira_test/source/impl_1/mira_test_top.vhd}
add_file -verilog -vlog_std v2001 {C:/Users/Bernhard/my_designs/mira_test/mipi_dphy_rx/rtl/mipi_dphy_rx.v}
add_file -vhdl -lib "work" {C:/Users/Bernhard/my_designs/mira_test/source/impl_1/mipi_rx.vhd}
add_file -verilog -vlog_std v2001 {C:/Users/Bernhard/my_designs/mira_test/mipi_cross_clk_fifo/rtl/mipi_cross_clk_fifo.v}
add_file -vhdl -lib "work" {C:/Users/Bernhard/my_designs/mira_test/source/impl_1/uart_tx.vhd}
add_file -vhdl -lib "work" {C:/Users/Bernhard/my_designs/mira_test/source/impl_1/frame_buf.vhd}
add_file -vhdl -lib "work" {C:/Users/Bernhard/my_designs/mira_test/source/impl_1/uart_rx.vhd}
add_file -verilog -vlog_std v2001 {C:/Users/Bernhard/my_designs/mira_test/main_pll/rtl/main_pll.v}
add_file -vhdl -lib "work" {C:/Users/Bernhard/my_designs/mira_test/source/impl_1/process_image.vhd}
add_file -verilog -vlog_std v2001 {C:/Users/Bernhard/my_designs/mira_test/process_image_out_fifo/rtl/process_image_out_fifo.v}
add_file -vhdl -lib "work" {C:/Users/Bernhard/my_designs/mira_test/source/impl_1/img_mean_std.vhd}
#-- top module name
set_option -top_module mira_test_top
set_option -include_path {C:/Users/Bernhard/my_designs/mira_test}
set_option -include_path {C:/Users/Bernhard/my_designs/mira_test/main_pll}
set_option -include_path {C:/Users/Bernhard/my_designs/mira_test/mipi_cross_clk_fifo}
set_option -include_path {C:/Users/Bernhard/my_designs/mira_test/mipi_dphy_rx}
set_option -include_path {C:/Users/Bernhard/my_designs/mira_test/process_image_out_fifo}

#-- set result format/file last
project -result_format "vm"
project -result_file "./mira_test_impl_1.vm"

#-- error message log file
project -log_file {mira_test_impl_1.srf}

#-- run Synplify with 'arrange HDL file'
catch {project -run hdl_info_gen -fileorder}

project -run -clean
