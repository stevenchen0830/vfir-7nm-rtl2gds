# Experiment B: dual-corner hold repair + GRT-view recheck matrix on the
# selective-gating netlist. Produced reports/step5b_holdfix_sel.log.
# Same robustness fixes as full_icg/holdfix_dualcorner.tcl; the recheck
# matrix reports per path group (core / stream-IO / SRAM-IO), both delays.
if {![info exists ::env(ORFS_ROOT)]} { set ::env(ORFS_ROOT) /root/ORFS }
set ORFS $::env(ORFS_ROOT)
if {![info exists ::env(RESULT_DIR)]} {
  set ::env(RESULT_DIR) $ORFS/flow/results/asap7/img_filter/sel
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
puts "==== POST-REPAIR MATRIX (GRT-estimated parasitics) ===="
foreach {tag args} {
  post_hold_ws {report_worst_slack -min}  post_hold_tns {report_tns -min}
  post_setup_ws {report_worst_slack -max} post_setup_tns {report_tns -max}
} { puts "==== $tag ===="; eval $args }
set g_stream_ins  [get_ports {in_pix_rdy in_pix_data* out_pix_need}]
set g_stream_outs [get_ports {in_pix_need out_pix_rdy out_pix_data*}]
set g_mem_ins     [get_ports mem_rdata*]
set g_mem_outs    [get_ports {mem_ce* mem_we* mem_addr* mem_wdata*}]
foreach d {min max} {
  foreach {nm sel} [list stream_in "-from \$g_stream_ins" stream_out "-to \$g_stream_outs" \
                         mem_in "-from \$g_mem_ins" mem_out "-to \$g_mem_outs"] {
    puts "==== post_${d}_${nm} ===="
    eval report_checks -path_delay $d [subst $sel] -group_path_count 1 -format end
  }
}
puts "==== post_drv ====";  report_check_types -max_slew -max_capacitance -max_fanout -violators
puts "==== post_area ====";  report_design_area
puts "==== post_power_ss ===="
if {[catch {report_power -corner ss} msg]} { puts "POWER_QUERY_FAILED: $msg" }
puts "==== DONE_MARKER ===="
exit
