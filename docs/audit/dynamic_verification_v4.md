# v4 dynamic verification summary

Tool: Icarus Verilog 14.0 portable.

## Passed checks

- 13-frame smoke at seeds `12345678`, `0badc0de`, `49a517c3` and
  `deadbeef`: 42,972 component checks and 18,350 PREP-alignment checks per
  seed, zero errors.
- Split rotator: every shift 0 through 48, 66 patterns, 3,234 comparisons,
  zero errors.
- Runtime reset injection: ordinary PREP, rotator stages A/B, FILL and MAIN
  under backpressure; clean restart after all five injections.
- PREP boundaries: H=24, 49, 4095 and 4096.
- Consecutive-frame PREP: a 1439x24 pass-through frame followed by H=4096
  without reset.
- Independent Python reference model: 117 shape-by-kernel checks.
- Generic Yosys zero-delay GLS: 144 pass-through beats, zero errors.

The complete 54-frame log is stored separately as `rtl_regression_v4.log`.
The regression reports kernel, width-modulo-4, bank-wrap and all three
split-rotator shift masks; these are functional coverage counters rather than
code/toggle coverage.
