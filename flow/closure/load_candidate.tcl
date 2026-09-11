# Isolated candidate loader: exactly one pinned Liberty set per process.
foreach key {ORFS_ROOT RESULT_DIR AUDIT_CORNER} {
    if {![info exists ::env($key)]} {error "Missing $key"}
}
set root $::env(ORFS_ROOT)
set result $::env(RESULT_DIR)
set corner $::env(AUDIT_CORNER)
if {$corner ni {FF TT SS}} {error "Unsupported corner $corner"}
set versions [dict create AO 211120.lib.gz INVBUF 220122.lib.gz OA 211120.lib.gz SIMPLE 211120.lib.gz SEQ 220123.lib]
foreach family {AO INVBUF OA SIMPLE SEQ} {
    set lib $root/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_${family}_RVT_${corner}_nldm_[dict get $versions $family]
    puts "LIBERTY $lib"
    read_liberty $lib
}
if {[info exists ::env(USE_ODB)] && $::env(USE_ODB) eq "1"} {
    read_db $result/6_final.odb
    source $root/flow/platforms/asap7/setRC.tcl
} else {
    read_verilog $result/6_final.v
    link_design IMG_FILTER
}
read_sdc $result/6_final.sdc
# Fixed target and budgets. Never reduce uncertainty to obtain a pass.
foreach clk [get_clocks *] {
    if {abs([get_property $clk period] - 1000) > 0.001} {error "Expected 1000 ps clocks"}
}
set_clock_uncertainty -setup 150 [get_clocks core_clock]
set_clock_uncertainty -hold 30 [get_clocks core_clock]
set_propagated_clock [get_clocks core_clock]
read_spef $result/6_final.spef
puts "MODEL corner=$corner period_ps=1000 setup_uncertainty_ps=150 hold_uncertainty_ps=30 RC=single_v4_extraction"
