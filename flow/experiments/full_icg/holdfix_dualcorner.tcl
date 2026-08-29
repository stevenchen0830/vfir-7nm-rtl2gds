# Experiment A: dual-corner hold repair on the routed WC candidate.
# FF corner drives the hold target; the simultaneously loaded SS corner
# guards setup at 2000 ps. Produced reports/step5_holdfix_fullicg.log.
# Robustness fixes vs the published run: remove_fillers after read_db,
# write_db BEFORE the report sections, report_power pinned to one corner.
if {![info exists ::env(ORFS_ROOT)]} { set ::env(ORFS_ROOT) /root/ORFS }
set ORFS $::env(ORFS_ROOT)
if {![info exists ::env(RESULT_DIR)]} {
  set ::env(RESULT_DIR) $ORFS/flow/results/asap7/img_filter/wc
}
set RD $::env(RESULT_DIR)
set NLDM $ORFS/flow/platforms/asap7/lib/NLDM
define_corners ff ss
foreach f [list AO_RVT_FF_nldm_211120.lib.gz INVBUF_RVT_FF_nldm_220122.lib.gz \
                OA_RVT_FF_nldm_211120.lib.gz SIMPLE_RVT_FF_nldm_211120.lib.gz \
                SEQ_RVT_FF_nldm_220123.lib] {
  read_liberty -corner ff $NLDM/asap7sc7p5t_$f }
foreach f [list AO_RVT_SS_nldm_211120.lib.gz INVBUF_RVT_SS_nldm_220122.lib.gz \
                OA_RVT_SS_nldm_211120.lib.gz SIMPLE_RVT_SS_nldm_211120.lib.gz \
                SEQ_RVT_SS_nldm_220123.lib] {
  read_liberty -corner ss $NLDM/asap7sc7p5t_$f }
read_db $RD/6_final.odb
remove_fillers
read_sdc [file dirname [info script]]/../../asap7/sweep_2000.sdc
set_propagated_clock [get_clocks core_clock]
if {[catch {read_spef -corner ff $RD/6_final.spef} msg]} {
  puts "SPEF_PER_CORNER_FAILED: $msg"; read_spef $RD/6_final.spef
} else { read_spef -corner ss $RD/6_final.spef }
puts "==== base_hold_ws ====";  report_worst_slack -min
puts "==== base_setup_ws ====";  report_worst_slack -max
puts "==== base_hold_tns ====";  report_tns -min
repair_timing -hold -hold_margin 10 -verbose
detailed_placement
check_placement -verbose
write_db  $RD/6_final_holdfix.odb
write_def $RD/6_final_holdfix.def
write_verilog $RD/6_final_holdfix.v
global_route -congestion_iterations 30 -verbose
estimate_parasitics -global_routing
puts "==== POST-REPAIR (GRT-estimated parasitics) ===="
puts "==== post_hold_ws ====";  report_worst_slack -min
puts "==== post_hold_tns ====";  report_tns -min
puts "==== post_setup_ws ====";  report_worst_slack -max
puts "==== post_drv ====";  report_check_types -max_slew -max_capacitance -max_fanout -violators
puts "==== post_area ====";  report_design_area
puts "==== DONE_MARKER ===="
exit
