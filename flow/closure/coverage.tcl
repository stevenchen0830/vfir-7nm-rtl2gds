# Separate process: an expensive/misbehaving coverage check cannot invalidate
# or prevent generation of the timing matrix. No exceptions are added here.
source [file join [file dirname [info script]] load_candidate.tcl]
puts "COVERAGE_BEGIN"
set ok [check_setup -verbose]
puts "COVERAGE_TOOL_PASS $ok"
puts "COVERAGE_DONE"
exit
