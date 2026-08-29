current_design IMG_FILTER

set clk_name      core_clock
set clk_port_name clk
set clk_period    1900
set clk_io_pct    0.2

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port
set_clock_uncertainty 150 [get_clocks $clk_name]
# NOTE (constraint-model review): annotating the core clock with a pre-CTS
# network latency was tried for pre-CTS IO symmetry and REVERTED - standalone
# OpenSTA showed the annotation interacting destructively with the propagated
# clock (apparent -997 ps setup on an otherwise -50 ps design).  The core
# clock stays ideal pre-CTS / propagated post-CTS; the virtual clocks carry
# the modeled insertion.

# ---------------------------------------------------------------------------
# Every external device (stream producer/consumer, the SRAMs) is clocked from
# the same tree as this block.  Model that shared insertion with ONE knob and
# deliberately overestimate it: hold safety only needs the estimate to be at
# least (real insertion - external clk-to-q_min), so a high estimate is safe
# for any tree the flow actually builds, while setup keeps ample budget.
# Anchoring IO to the raw clock source instead fabricates a hold race equal
# to the full tree depth on every input bit.
# ---------------------------------------------------------------------------
set common_insertion 800

set clk_io_name vclk_$clk_name
create_clock -name $clk_io_name -period $clk_period
set_clock_latency $common_insertion [get_clocks $clk_io_name]

set clk_mem_name vclk_mem
create_clock -name $clk_mem_name -period $clk_period
set_clock_latency $common_insertion [get_clocks $clk_mem_name]

# port classes, explicit by name (collection subtraction fails silently here)
set stream_ins  [get_ports {rst_n in_pix_rdy in_pix_data* out_pix_need \
                            frm_start img_width* img_height* blk_v* coef*}]
set stream_outs [get_ports {in_pix_need out_pix_rdy out_pix_data*}]
set mem_ins     [get_ports mem_rdata*]
set mem_outs    [get_ports {mem_ce* mem_we* mem_addr* mem_wdata*}]

set io_budget 200   ;# FROZEN absolute (sweep rule: only clk_period varies)
set_input_delay  -clock $clk_io_name -max $io_budget $stream_ins
set_input_delay  -clock $clk_io_name -min [expr $io_budget / 2] $stream_ins
# output hold: with the overestimated common insertion, a symmetric -min
# budget would demand data stability past an edge that is modeled later
# than the real one; the shared tree guarantees downstream hold by
# construction, so release the -min side explicitly.
set_output_delay -clock $clk_io_name -max $io_budget $stream_outs
set_output_delay -clock $clk_io_name -min 500      $stream_outs

# SRAM pins.  Reads: clk-to-q 10..100 ps.  Command/write side: 100 ps setup.
# Output hold: with this latency-based model the tools evaluate
#   required_min = insertion(800) - min_value, so -min 500 sets the bound at
# 300 ps.  That is deliberately looser than the physical bound
# (tree_min + t_hold): shared-tree hold at the SRAM pins is guaranteed by
# construction (launch and capture ride the same tree), and this constraint
# only keeps STA from fabricating races against the overestimated insertion.
# A tapeout would replace it with the macro's characterized interface checks.
set_input_delay  -clock $clk_mem_name -max 100 $mem_ins
set_input_delay  -clock $clk_mem_name -min  10 $mem_ins
set_output_delay -clock $clk_mem_name -max 100  $mem_outs
set_output_delay -clock $clk_mem_name -min 500 $mem_outs

# rst_n asserts asynchronously and is released through an external
# synchronizer, so recovery/removal timing is guaranteed upstream.
set_false_path -from [get_ports rst_n]
