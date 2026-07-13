if {[catch {

# define run engine funtion
source [file join {C:/lscc/radiant/2025.2} scripts tcl flow run_engine.tcl]
# define global variables
global para
set para(gui_mode) "1"
set para(prj_dir) "C:/Users/Bernhard/my_designs/mira_test"
if {![file exists {C:/Users/Bernhard/my_designs/mira_test/impl_1}]} {
  file mkdir {C:/Users/Bernhard/my_designs/mira_test/impl_1}
}
cd {C:/Users/Bernhard/my_designs/mira_test/impl_1}
# synthesize IPs
# synthesize VMs
# propgate constraints
file delete -force -- mira_test_impl_1_cpe.ldc
::radiant::runengine::run_engine_newmsg cpe -syn synpro -f "mira_test_impl_1.cprj" "mipi_dphy_rx.cprj" "mipi_cross_clk_fifo.cprj" "main_pll.cprj" "process_image_out_fifo.cprj" -a "LIFCL"  -o mira_test_impl_1_cpe.ldc
# synthesize top design
file delete -force -- mira_test_impl_1.vm mira_test_impl_1.ldc
if {[file normalize "C:/Users/Bernhard/my_designs/mira_test/impl_1/mira_test_impl_1_synplify.tcl"] != [file normalize "./mira_test_impl_1_synplify.tcl"]} {
  file copy -force "C:/Users/Bernhard/my_designs/mira_test/impl_1/mira_test_impl_1_synplify.tcl" "./mira_test_impl_1_synplify.tcl"
}
if {[ catch {::radiant::runengine::run_engine synpwrap -prj "mira_test_impl_1_synplify.tcl" -log "mira_test_impl_1.srf"} result options ]} {
    file delete -force -- mira_test_impl_1.vm mira_test_impl_1.ldc
    return -options $options $result
}
::radiant::runengine::run_postsyn [list -a LIFCL -p LIFCL-40 -t CABGA400 -sp 9_High-Performance_1.0V -oc Commercial -top -ipsdc ipsdclist.txt -w -o mira_test_impl_1_syn.udb mira_test_impl_1.vm] [list mira_test_impl_1.ldc]

} out]} {
   ::radiant::runengine::runtime_log $out
   exit 1
}
