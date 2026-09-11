proc closure_report {} {
    foreach {name delay} {setup max hold min} {
        puts "METRIC ${name}_ws_ps [sta::time_sta_ui [sta::worst_slack_cmd $delay]]"
        puts "METRIC ${name}_tns_ps [sta::time_sta_ui [sta::total_negative_slack_cmd $delay]]"
        puts "METRIC ${name}_endpoints [sta::endpoint_violation_count $delay]"
    }
    foreach {name command} {slew sta::max_slew_violation_count cap sta::max_capacitance_violation_count} {
        puts "METRIC ${name}_violations [$command]"
    }
    # The pinned standalone STA segfaults in max_fanout_violation_count
    # without explicit limits (upstream search_timing_model_deep.tcl notes
    # this bug). Use the report implementation, not that crashing API.
    puts "FANOUT_CHECK_BEGIN"
    report_check_types -max_fanout -violators
    puts "FANOUT_CHECK_END"
    report_checks -path_delay min_max -group_path_count 3 -format full_clock_expanded
    report_check_types -max_slew -max_capacitance -max_fanout -violators
    # These diagnostic checks do not override the documented reset exception.
    puts "CLOCK_CHECK_BEGIN"
    report_check_types -recovery -removal -min_pulse_width -min_period -clock_gating_setup -clock_gating_hold -violators
    puts "CLOCK_CHECK_END"
}
