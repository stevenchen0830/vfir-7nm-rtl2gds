# Source AFTER the final candidate's SDC in an FF STA session.
# This changes the analysis assumption, not the netlist or clock hardware.
set_clock_uncertainty -setup 100 [get_clocks core_clock]
set_clock_uncertainty -hold 30 [get_clocks core_clock]
