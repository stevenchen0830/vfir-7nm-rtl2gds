set libs [list   /root/ORFS/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_AO_RVT_SS_nldm_211120.lib.gz   /root/ORFS/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_INVBUF_RVT_SS_nldm_220122.lib.gz   /root/ORFS/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_OA_RVT_SS_nldm_211120.lib.gz   /root/ORFS/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_SIMPLE_RVT_SS_nldm_211120.lib.gz   /root/ORFS/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_SEQ_RVT_SS_nldm_220123.lib]
foreach f $libs { puts "LOADED_LIB $f"; read_liberty $f }
read_verilog /root/ORFS/flow/results/asap7/img_filter/base/6_final.v
link_design IMG_FILTER
read_spef /root/ORFS/flow/results/asap7/img_filter/base/6_final.spef
read_sdc /root/ORFS/flow/designs/asap7/img_filter/constraint.sdc
set_propagated_clock [get_clocks core_clock]
puts "==== worst_slack_max ===="
report_worst_slack -max
puts "==== worst_slack_min ===="
report_worst_slack -min
puts "==== tns_max ===="
report_tns -max
puts "==== tns_min ===="
report_tns -min
puts "==== paths_by_group_setup ===="
report_checks -path_delay max -group_path_count 1 -format end
puts "==== paths_by_group_hold ===="
report_checks -path_delay min -group_path_count 1 -format end
puts "==== check_types ===="
report_check_types -max_slew -max_capacitance -max_fanout -violators
puts "==== unconstrained ===="
report_checks -unconstrained -group_path_count 3 -format end
puts "==== ct_unconstrained ===="
check_timing -unconstrained_endpoints
puts "==== ct_no_input_delay ===="
check_timing -no_input_delay
puts "==== ct_no_output_delay ===="
check_timing -no_output_delay
puts "==== ct_no_clock ===="
check_timing -no_clock
puts "==== ct_loops ===="
check_timing -loops
puts "==== DONE_MARKER ===="
exit
