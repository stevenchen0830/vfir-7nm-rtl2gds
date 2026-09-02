# Verification

The primary release regression uses a self-checking Verilog testbench plus an
independent Python reference model.  A native SystemVerilog UVM smoke layer is
also available under `verification/uvm/`; it complements rather than replaces
the broader 54-frame regression.

## Dynamic suites

- `img_filter_tb.v`: 13-frame `+SMOKE` or full 54-frame regression.  Pass
  `+SEED=<hex>` to reproduce or vary constrained-random stimulus.  The log
  reports kernel, width-modulo-4, bank-wrap and all three rotation coverages.
  It also independently checks the v4 PREP weight-vector alignment at every
  useful `c_load`.
- `rotator_tb.v`: all shifts 0 through 48 over two directed and 64 random
  392-bit patterns.
- `reset_recovery_tb.sv`: reset injection in ordinary PREP, rotator stage A,
  rotator stage B, FILL and MAIN under output backpressure, followed by a
  checked clean-restart frame after every reset.
- `prep_boundary_tb.sv`: focused PREP-vector check at heights 24, 49, 4095
  and the 12-bit maximum height 4096.
- `prep_transition_tb.sv`: finishes one frame and checks maximum-height PREP
  on the next frame without an intervening reset.
- `gls_smoke_tb.sv`: public-interface-only pass-through smoke for a zero-delay
  synthesized netlist.
- `uvm/`: driver, sequencer, input/output monitors and an independent
  scoreboard for a 24x24 `blk_v=1` pass-through frame.  It checks all 144
  accepted beats while deterministic input starvation and output backpressure
  exercise both ready/valid directions.  See `uvm/README.md` for the tested
  open-source toolchain and run command.

The normal CI runs one seeded smoke plus rotator/reset tests.  The manually
triggered `extended-verification` workflow runs four smoke seeds in parallel
and the complete 54-frame release regression.

## Scope

These tests detect observed functional/protocol failures.  They do not by
themselves prove all legal transactions, CDC/RDC integration, timing closure,
LVS, EM or tapeout readiness.  See `docs/verification-status.md` for the
evidence boundary and `formal/` / `equiv/` for additional checks.
