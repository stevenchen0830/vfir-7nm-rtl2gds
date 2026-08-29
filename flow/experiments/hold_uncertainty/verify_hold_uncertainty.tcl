# 8th-SDC-artifact validation: the blanket set_clock_uncertainty 150 charges
# every hold check with the full setup margin. This script re-reports the
# UNREPAIRED selective-gating netlist with the recommended -hold 30 override;
# hold slack must shift by exactly +120 ps (uncertainty enters hold slack as
# an exact linear term; CRPR unchanged). Published run: baseline WNS
# -127.56 -> -7.56 ps (reports/verify_hold_uncertainty.log), from which the
# repaired netlist's -104.496 ps is analytically adjusted to +15.5 ps.
if {![info exists ::env(ORFS_ROOT)]} { set ::env(ORFS_ROOT) /root/ORFS }
set ORFS $::env(ORFS_ROOT)
if {![info exists ::env(RESULT_DIR)]} {
  set ::env(RESULT_DIR) $ORFS/flow/results/asap7/img_filter/sel
}
set RD $::env(RESULT_DIR)
set NLDM $ORFS/flow/platforms/asap7/lib/NLDM
foreach f [list AO_RVT_FF_nldm_211120.lib.gz INVBUF_RVT_FF_nldm_220122.lib.gz \
                OA_RVT_FF_nldm_211120.lib.gz SIMPLE_RVT_FF_nldm_211120.lib.gz \
                SEQ_RVT_FF_nldm_220123.lib] {
  read_liberty $NLDM/asap7sc7p5t_$f }
read_verilog $RD/6_final.v
link_design IMG_FILTER
read_spef $RD/6_final.spef
read_sdc [file dirname [info script]]/../../asap7/sweep_2000.sdc
set_propagated_clock [get_clocks core_clock]
set_clock_uncertainty -hold 30 [get_clocks core_clock]
puts "==== clock_skew_hold ====";  report_clock_skew -hold
puts "==== worst_min_full ===="
report_checks -path_delay min -group_path_count 2 -format full_clock_expanded \
  -fields {slew capacitance net input_pins}
puts "==== DONE_MARKER ===="
exit
