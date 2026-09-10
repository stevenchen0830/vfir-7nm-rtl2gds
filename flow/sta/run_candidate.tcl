# Portable standalone OpenSTA audit; one fresh process per corner.
foreach key {ORFS_ROOT RESULT_DIR AUDIT_CORNER} {
    if {![info exists ::env($key)]} { error "Missing $key" }
}
set root $::env(ORFS_ROOT)
set result $::env(RESULT_DIR)
set corner $::env(AUDIT_CORNER)
if {$corner ni {FF TT SS}} {error "AUDIT_CORNER must be FF TT SS"}
set libdir $root/flow/platforms/asap7/lib/NLDM
set versions [dict create AO 211120.lib.gz INVBUF 220122.lib.gz OA 211120.lib.gz SIMPLE 211120.lib.gz SEQ 220123.lib]
foreach family {AO INVBUF OA SIMPLE SEQ} {
    if {[info exists ::env(LIBERTY_LIST)]} {break}
    set lib $libdir/asap7sc7p5t_${family}_RVT_${corner}_nldm_[dict get $versions $family]
    if {![file exists $lib]} {error "Missing pinned v4 Liberty: $lib"}
    lappend libs $lib
}
if {[info exists ::env(LIBERTY_LIST)]} {
    set f [open $::env(LIBERTY_LIST) r]; set libs [split [string trim [read $f]] \n]; close $f
}
foreach lib $libs {puts "LIBERTY $lib"; read_liberty $lib}
read_verilog $result/6_final.v
link_design IMG_FILTER
read_spef $result/6_final.spef
read_sdc $result/6_final.sdc
if {[info exists ::env(AUDIT_U100)] && $::env(AUDIT_U100) eq "1"} {
    source [file join [file dirname [info script]] ../asap7/audit_ff_u100.tcl]
}
set_propagated_clock [get_clocks core_clock]
puts "AUDIT_CORNER $corner; one routed SPEF; coverage audit remains separate"
report_worst_slack -max
report_tns -max
report_worst_slack -min
report_tns -min
report_checks -path_delay min_max -group_path_count 3 -format full_clock_expanded
report_check_types -max_slew -max_capacitance -max_fanout -violators
if {[info exists ::env(SDF_OUT)]} {write_sdf -no_timestamp $::env(SDF_OUT)}
puts "DONE_MARKER"
exit
