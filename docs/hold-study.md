# Hold study: physical skew, constraint sensitivity, and evidence limits

This is a historical experiment record, not a tapeout signoff certificate.
The current v4 result is in [README](../README.md); exact SDC assumptions
and entry points are in [constraint assumptions](constraint-assumptions.md).
Original logs and checksums are preserved in [reports](../reports/README.md)
and runnable historical experiment sources in [flow/experiments](../flow/experiments/).

## 1. WC implementation: a real 1 GHz setup failure

The `wc` implementation used SS libraries, 1000 ps, and historical
150/150 ps setup/hold uncertainty. Setup WNS was **−950.6 ps** over
10,694 endpoints; TNS was about **−4.61 microseconds**, not milliseconds
(−4,608,623 ps). Geometric routing DRC = 0 did not remove the timing failure.

With absolute IO delays fixed, the archived 1800/1900/2000/2100 ps sweep
reported setup WNS −150.6/−50.6/+49.4/+149.4 ps. The approximately
1950.6 ps / 513 MHz crossing is a **setup-only limit for that candidate
and view**. It does not establish hold, DRV, IO contract validity or safe
operation at 500 MHz. All corners need min and max checks; SS hold is meaningful.

## 2. Full versus selective ICG repair

The full-ICG repair started with FF hold WNS about −160.9 ps and TNS
about −371 ns. It inserted 25,268 buffers, then plateaued near −114.7 ps.
The trace survives in [full-ICG log](../reports/step5_holdfix_fullicg.log).
The post-repair database was not successfully preserved in that run:
detailed placement encountered filler cells (`DPL-0038`). Do not claim a
reproducible final repaired full-ICG netlist from this log alone.

Clock-expanded paths exposed different gated and ungated insertion delays.
This is evidence of a structural skew contribution, not proof that every
residual endpoint has the same cause. The reported +1672 ps setup slack
at a diagnosed `c_d1` endpoint refuted a particular **baseline** setup-guard
hypothesis; it does not establish setup headroom after every buffer insertion.

Selective gating used `clockgate -min_net_size 2000`, reducing the reported
ICG count from 30 to 2 for those historical legs. Repair inserted 26,731
buffers; TNS decreased substantially, with residual WNS around −104.5 ps.
The [selective log](../reports/step5b_holdfix_sel.log) contains a timing/area
recheck under **GRT-estimated parasitics**. Its final power query failed with
`STA-0103`; that query provides no usable published power result.

The two in-flow WC power estimates were about 44.2 and 155.1 mW. These are
vectorless, separate implementations with different clock structures. They
motivate a gating/repairability trade-off, but are **not** an activity-matched
VCD/SAIF causal measurement isolating ICG power. Likewise v1-to-v2 “44x”
comparisons also changed architecture and constraints and are not an ICG-only gain.

## 3. Uncertainty sensitivity: a changed model, not faster silicon

Blanket `set_clock_uncertainty 150` applies to setup and hold. The alternative
model explicitly sets setup 150 ps and hold 30 ps. On the archived unrepaired
candidate, [the sensitivity run](../reports/verify_hold_uncertainty.log)
changed hold slack −127.56 → −7.56 ps: a +120 ps shift for the affected paths.
That verifies the arithmetic of the model, **not the physical correctness
of a 30 ps uncertainty budget**. Jitter correlation, residual skew/variation
and the interface contract must justify a real budget. Do not call the old
violations “fiction,” nor describe 20–50 ps as a universally valid hold budget.

Applying the same sensitivity to repaired residual −104.496 ps yields
**+15.504 ps analytically**. The linear shift was empirically checked on the
unrepaired candidate, but there was no new full STA of the repaired netlist
under 30 ps. It is therefore not a measured repaired-netlist signoff pass.
The repaired selective database was not detailed-routed and re-extracted.

## 4. MCP leg and v4: separate candidates

The MCP leg completed route and extraction, with FF hold +26.6 ps / TNS 0
under its split-uncertainty view. Setup still had −51.07 ps / 112 endpoints.
Its stages 1–4 used blanket uncertainty while later stages used split
uncertainty: **mixed provenance**, not a matched from-scratch comparison.
Its cross-corner SS hold (−139.3 ps) remains a violation; it is not dismissed
because hold was optimized at FF. Its SS setup TNS of about −5.87 million ps
is approximately −5.87 microseconds, not milliseconds.

v4 instead physically pipelines the coefficient rotator and has no MCP
exception in its normal constraint entry. It retained the 7,840-bit `rdata_q`.
The original scripts used slew margin 15 in early stages and 25 in the
stage-5/6 rerun. The new consistent-margin reproduction recipe is disclosed
as a recipe, not a promise of byte-identical recreation of the historical run.

| v4 view, same routed SPEF | Setup WNS | Hold WNS | Interpretation |
| --- | ---: | ---: | --- |
| FF @ 1000 ps, 150/30 ps uncertainty | −15.69 ps | +4.88 ps | Setup not closed |
| FF @ 1000 ps, 100/30 ps override | +34.31 ps | +4.88 ps | Limited min/max timing pass |
| TT @ 1000 ps, 150/30 ps | −333.53 ps | +15.27 ps | Setup not closed |
| Archived SS @ 2000 ps, **150/150 ps** | +76.89 ps | **−303.10 ps** | Hold not closed |

The SS report sourced the archived `sweep_2000.sdc` blanket model; do not
label it 150/30. Its hold TNS is −1,570,621.12 ps. The approximately 520 MHz
setup crossing is not a safe operating-frequency claim. Reducing FF setup
uncertainty from 150 to 100 ps adds 50 ps slack without changing a transistor.

The 2026-09-10 [fresh standalone FF audit](../reports/v4_reproduced_ff_u100.rpt)
reproduced +34.31/+4.88 ps with exact input and Liberty hashes. It does not
resolve the remaining 243 max-slew violations, missing per-RC MMMC, incomplete
coverage audit, final mapped equivalence, or LVS/EM. SRAM macros remain
external interface models (`macros = 0`). This is a research RTL-to-GDS project,
not a tapeout-ready chip.
