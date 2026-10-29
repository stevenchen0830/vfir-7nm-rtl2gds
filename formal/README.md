# Formal verification

`control_bmc.sby` checks bounded control-safety properties for 40 cycles from
reset.  It covers state/counter bounds, one-hot SRAM writes, read/write bank
exclusion, reset quiescence, preservation of a stalled output valid, and
cycle-by-cycle data/enable/tag alignment through both split-rotator stages and
the `c_fut` to `c_cur` row-boundary transfer.

Run from the repository root:

```sh
sby -f -d work/formal-control formal/control_bmc.sby
```

A PASS is bounded evidence, not a proof that every FIR output equals the
mathematical reference for every legal transaction sequence.

Depth 40 covers only the start of a frame.  With W, H >= 24, no stalls and
the earliest `frm_start` (step 1), MAIN starts at step 16 + 6*hv (W = 24), and
the first IDLE after a frame (24x24, `blk_v = 1`) is step 160, which needs a
depth of at least 162.  So this run does not reach DRAIN, the frame end
(including the one-cycle `in_pix_need` tail in IDLE), the 49-row bank wrap,
read/write bank exclusion for `blk_v >= 9`, or a row-boundary `c_cur` load for
`blk_v >= 7`, and it checks reset quiescence only after the initial reset.  It
also does not catch a change of the PREP load count; `check_fold49` in
`verification/prep_boundary_tb.sv` does.
