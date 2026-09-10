# Reproduction model: ps units in ASAP7's scaled timing view.
# These values reproduce an academic interface assumption, not characterized
# jitter/OCV/SRAM guarantees. See docs/constraint-assumptions.md.
current_design IMG_FILTER
set clk_period 1000
create_clock -name core_clock -period $clk_period [get_ports clk]
set_clock_uncertainty -setup 150 [get_clocks core_clock]
set_clock_uncertainty -hold 30 [get_clocks core_clock]
foreach name {vclk_core_clock vclk_mem} {
    create_clock -name $name -period $clk_period
    set_clock_latency 800 [get_clocks $name]
}
set stream_ins [get_ports {rst_n in_pix_rdy in_pix_data* out_pix_need frm_start img_width* img_height* blk_v* coef*}]
set stream_outs [get_ports {in_pix_need out_pix_rdy out_pix_data*}]
set mem_ins [get_ports mem_rdata*]
set mem_outs [get_ports {mem_ce* mem_we* mem_addr* mem_wdata*}]
# Absolute delays: period experiments must not silently change these.
set_input_delay -clock vclk_core_clock -max 200 $stream_ins
set_input_delay -clock vclk_core_clock -min 100 $stream_ins
set_output_delay -clock vclk_core_clock -max 200 $stream_outs
set_output_delay -clock vclk_core_clock -min 500 $stream_outs
set_input_delay -clock vclk_mem -max 100 $mem_ins
set_input_delay -clock vclk_mem -min 10 $mem_ins
set_output_delay -clock vclk_mem -max 100 $mem_outs
set_output_delay -clock vclk_mem -min 500 $mem_outs
# Integration contract only; recovery/removal is not proven by this exception.
set_false_path -from [get_ports rst_n]
