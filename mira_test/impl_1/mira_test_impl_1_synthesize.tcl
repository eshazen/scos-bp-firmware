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
# synthesize top design
::radiant::runengine::run_postsyn [list -a LIFCL -p LIFCL-40 -t CABGA400 -sp 9_High-Performance_1.0V -oc Commercial -top -ipsdc ipsdclist.txt -w -o mira_test_impl_1_syn.udb mira_test_impl_1.vm] [list mira_test_impl_1.ldc]

} out]} {
   ::radiant::runengine::runtime_log $out
   exit 1
}
