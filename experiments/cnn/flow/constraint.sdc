# Research model for this NEW IP, not the original FIR's physical constraints.
create_clock -name core_clock -period 1000 [get_ports clk]
set_clock_uncertainty -setup 100 [get_clocks core_clock]
set_clock_uncertainty -hold 30 [get_clocks core_clock]
set_input_delay -clock core_clock -max 200 [get_ports {rst_n in_valid in_data* out_ready weights* biases*}]
set_input_delay -clock core_clock -min 20 [get_ports {rst_n in_valid in_data* out_ready weights* biases*}]
set_output_delay -clock core_clock -max 200 [all_outputs]
set_output_delay -clock core_clock -min -20 [all_outputs]
set_false_path -from [get_ports rst_n]
