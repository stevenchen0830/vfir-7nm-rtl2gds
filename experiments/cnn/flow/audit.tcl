set versions [dict create AO 211120.lib.gz INVBUF 220122.lib.gz OA 211120.lib.gz SIMPLE 211120.lib.gz SEQ 220123.lib]
set root $::env(ORFS_ROOT)
set result $::env(RESULT_DIR)
set corner $::env(AUDIT_CORNER)
foreach family {AO INVBUF OA SIMPLE SEQ} {
    set lib $root/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_${family}_RVT_${corner}_nldm_[dict get $versions $family]
    puts "LIBERTY $lib"; read_liberty $lib
}
read_verilog $result/6_final.v
link_design int8_dw3x1
read_sdc $result/6_final.sdc
set_propagated_clock [get_clocks core_clock]
read_spef $result/6_final.spef
puts "MODEL $corner original final SDC, 1000ps 100/30ps, single routed SPEF"
foreach {name mode} {setup max hold min} {
    puts "METRIC ${name}_ws_ps [sta::time_sta_ui [sta::worst_slack_cmd $mode]]"
    puts "METRIC ${name}_tns_ps [sta::time_sta_ui [sta::total_negative_slack_cmd $mode]]"
    puts "METRIC ${name}_endpoints [sta::endpoint_violation_count $mode]"
}
puts "METRIC slew_violations [sta::max_slew_violation_count]"
puts "METRIC cap_violations [sta::max_capacitance_violation_count]"
# report initializes the fanout checker before the internal count API.
report_check_types -max_fanout -violators
puts "METRIC fanout_violations [sta::max_fanout_violation_count]"
report_checks -path_delay min_max -group_path_count 3 -format full_clock_expanded
report_check_types -max_slew -max_capacitance -violators
puts "CLOCK_CHECK_BEGIN"
report_check_types -recovery -removal -min_pulse_width -min_period -clock_gating_setup -clock_gating_hold -violators
puts "CLOCK_CHECK_END"
puts "CONSTRAINT_CHECK_BEGIN"
set complete [check_setup -verbose]
puts "CONSTRAINT_CHECK_PASS $complete"
puts "CONSTRAINT_CHECK_END"
puts "CLOSURE_AUDIT_DONE"
exit
