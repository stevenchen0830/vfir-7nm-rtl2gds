# Stage 2: bounded timing cleanup on the saved DRV ECO checkpoint.
# Single-corner placement estimate only. Final acceptance still requires RCX.
set_thread_count 4
set root $::env(ORFS_ROOT)
set result $::env(ECO_INPUT)
set out $::env(ECO_OUTPUT)
set versions [dict create AO 211120.lib.gz INVBUF 220122.lib.gz OA 211120.lib.gz SIMPLE 211120.lib.gz SEQ 220123.lib]
foreach family {AO INVBUF OA SIMPLE SEQ} {
    set lib $root/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_${family}_RVT_FF_nldm_[dict get $versions $family]
    puts "LIBERTY $lib"; read_liberty $lib
}
read_db $result/2_legalized.odb
read_sdc $result/2_legalized.sdc
source $root/flow/platforms/asap7/setRC.tcl
set_propagated_clock [get_clocks core_clock]
set_dont_use {*x1p*_ASAP7* *xp*_ASAP7* SDF* ICG*}
estimate_parasitics -placement
source [file join [file dirname [info script]] report_candidate.tcl]
puts "ECO_TIMING_BEFORE placement estimates"
closure_report
repair_timing -setup -setup_margin 10 -repair_tns 100 -max_passes 10 -max_iterations 200 -max_repairs_per_pass 2 -skip_last_gasp
write_db $out/3_setup.odb
write_verilog $out/3_setup.v
write_sdc $out/3_setup.sdc
puts "ECO_SETUP_CHECKPOINT_WRITTEN"
repair_timing -hold -hold_margin 5 -max_passes 10 -max_iterations 200 -max_buffer_percent 1
write_db $out/4_hold.odb
write_verilog $out/4_hold.v
write_sdc $out/4_hold.sdc
puts "ECO_HOLD_CHECKPOINT_WRITTEN"
detailed_placement
check_placement -verbose
estimate_parasitics -placement
write_db $out/5_timing_legalized.odb
write_verilog $out/5_timing_legalized.v
write_sdc $out/5_timing_legalized.sdc
puts "ECO_TIMING_AFTER placement estimates, NOT signoff"
closure_report
puts "ECO_DONE"
exit
