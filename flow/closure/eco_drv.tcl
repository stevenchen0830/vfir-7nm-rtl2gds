# Bounded experimental ECO. Never writes into RESULT_DIR or labels estimated
# post-ECO parasitics as extracted signoff. Run only through run_eco.py.
set_thread_count 4
set ::env(USE_ODB) 1
source [file join [file dirname [info script]] load_candidate.tcl]
source [file join [file dirname [info script]] report_candidate.tcl]
set out $::env(ECO_OUTPUT)
puts "ECO_BEFORE extracted single-corner view"
closure_report
remove_fillers
set_dont_use {*x1p*_ASAP7* *xp*_ASAP7* SDF* ICG*}
# Initialize the incremental estimator; restore extracted RC on unchanged
# nets before repair. New/modified nets use estimates until rerouting/RCX.
estimate_parasitics -placement
read_spef $result/6_final.spef
puts "ECO_REPAIR_BEGIN [clock seconds]"
repair_design -slew_margin 5 -cap_margin 5 -max_utilization 65 -verbose
write_db $out/1_drv_fixed.odb
write_verilog $out/1_drv_fixed.v
write_sdc $out/1_drv_fixed.sdc
puts "ECO_CHECKPOINT_WRITTEN [clock seconds]"
detailed_placement
check_placement -verbose
write_db $out/2_legalized.odb
write_verilog $out/2_legalized.v
write_sdc $out/2_legalized.sdc
estimate_parasitics -placement
puts "ECO_AFTER placement-estimated parasitics, NOT post-route signoff"
closure_report
puts "ECO_DONE"
exit
