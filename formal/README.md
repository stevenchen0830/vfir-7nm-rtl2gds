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
