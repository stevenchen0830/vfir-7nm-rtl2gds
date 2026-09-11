source [file join [file dirname [info script]] load_candidate.tcl]
source [file join [file dirname [info script]] report_candidate.tcl]
closure_report
puts "CLOSURE_AUDIT_DONE"
exit
