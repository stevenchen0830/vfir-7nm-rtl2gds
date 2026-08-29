# The slow-corner implementation and the hold-closure study

A second full RTL-to-GDS run at the true slow corner (`CORNER=WC`,
SS 0.63 V/100 °C libraries, 1 GHz SDC, bounded repair) put honest numbers on
the 1 GHz gap, and turned hold repair into a controlled experiment. Raw
evidence for every claim: [`../reports/`](../reports/) — see
[`reports/README.md`](../reports/README.md) for the per-report provenance
map (run, corner, parasitic view, SDC, completion status) and
`manifest_planv3.sha256` for integrity. Reproduction drivers:
[`../flow/experiments/`](../flow/experiments/).

## WC @ 1000 ps — the violation report

Never a "1 GHz closure": setup WNS **−950.6 ps** / TNS −4.61 ms over 10,694
endpoints, geometric routing DRC 0, 44.2 mW, 518 k instances. A period sweep
with IO delays **frozen as absolutes** (sweeping %-of-period IO budgets
widens them and fakes fmax) walks in exact 100 ps steps — −150.6 / −50.6 /
**+49.4** / +149.4 ps at 1800/1900/2000/2100 ps — so the feasible period is
1950.6 ps ≈ **513 MHz**, matching the signoff WNS to 0.01 ps. At every sweep
point the sole limiter is the `c_fut` weight-rotator cone; all four IO
groups clear by ≥ 270 ps.

## Hold, experiment A — full-ICG netlist

Checked at the fast corner, as hold must be: baseline −160.9 ps WNS /
−371 ns TNS, all core-internal. Dual-corner `repair_timing -hold` (FF hold
target + SS setup guard) inserted 25,268 buffers (+5.0 % area), cut TNS
98 %, then **plateaued at −114.7 ps** and gave up (`RSZ-0064`). The obvious
hypothesis — the setup guard blocks the fixes — was tested and **refuted**:
the pinned endpoint has +1672 ps of setup slack. The real cause is ~200 ps
of structural skew between the ungated flat clock subtree and the ICG-gated
subtrees (CTS balances them with 15-deep `delaybuf` chains and still
loses). The post-repair database of this run was lost to a script defect
(`DPL-0038`: detailed placement attempted with filler cells present); the
repair trajectory and result summary survive in
`reports/step5_holdfix_fullicg.log`, and the published experiment scripts
fix the defect (`remove_fillers` first, `write_db` before reporting).

## Hold, experiment B — selective gating

Re-synthesized with yosys `clockgate -min_net_size 2000` (a 3-line ORFS
hook, `flow/experiments/selective_icg/synth_hook.patch`), keeping ICGs only
on the two ≥2000-flop data register groups (`rdata_q`, MAC pipe): ICG count
**30 → 2**. Full WC flow, geometric routing DRC 0. Repair dynamics
transformed — no rejection-spinning, TNS 468 → 28.7 ns (94 %) at a steady
~40 ns per 500 iterations, 26,731 buffers — with residual WNS −104.5 ps on
the `c_cur` cluster. The timing/area recheck matrix completed; the final
post-repair power query terminated with `STA-0103` (missing multi-corner
scene argument) and **is not used for any published power claim** — power
numbers below come from the in-flow single-corner reports.

## Root cause of the residual — an 8th SDC artifact class

`report_clock_skew -hold` decomposes the worst path's "skew" as ~95 ps
genuine subtree latency offset **+ 150 ps of clock uncertainty charged to
hold**. The SDC's blanket `set_clock_uncertainty 150` (no `-setup`/`-hold`
split) silently taxes every hold check with the full setup margin;
same-edge hold checks see almost no jitter, and practice keeps hold
uncertainty at ~20–50 ps. Under the corrected constraint
(`flow/asap7/constraint_recommended.sdc`, `-setup 150 -hold 30`) the
repaired netlist's residual is **analytically adjusted** from −104.5 ps to
**+15.5 ps — hold closed** (uncertainty enters hold slack as an exact
linear term; CRPR unchanged), and the 120 ps linear shift was **empirically
validated** on the unrepaired netlist: −127.56 → −7.56 ps, exact to
0.01 ps (`reports/verify_hold_uncertainty.log`). No new full STA of the
repaired netlist was run — the historical reports were all produced with
the blanket-uncertainty SDC, preserved verbatim as
`constraint_reported.sdc` so the report ↔ constraint correspondence stays
intact.

## Controlled ICG ablation

Matched stage, corner and config — the two WC legs differ *only* in the
gating threshold: 30 ICGs → **44.2 mW**; 2 ICGs → **155.1 mW**. Gating the
small metadata registers is worth 3.5× total power on this design, and buys
exactly the hold-repairability problem above — a quantified
power-vs-closure trade. (The earlier "44× vs v1" stays a cross-spin
observation: v1 also lacked the elastic skid buffers.)

## View discipline and scope

Repair-trajectory numbers are from the SPEF-annotated view; the post-repair
recheck matrix in `step5b_holdfix_sel.log` uses GRT-estimated parasitics
(labeled — cross-view hold TNS moves by >100 ns on this design, which is
itself the lesson). The repaired database was not re-routed or
re-extracted: academic flow, no LVS/EM, no post-repair route re-signoff —
**not tapeout-ready**. "DRC 0" throughout means *geometric routing DRC*
(TritonRoute spacing/via/antenna, `reports/drc_summary.txt`); electrical
checks (max slew/cap) and timing residuals are reported separately. The 49
external SRAMs are modeled by interface timing models only; the layout
contains zero macros (`instance__count__macros = 0`), so nothing here signs
off the SRAMs themselves.
