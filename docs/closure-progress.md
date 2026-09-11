# 2026-09-11 repair and acceptance ledger

**Overall: NOT CLOSED.** This is an execution/evidence ledger, not a declaration
that every issue has been resolved. Historical failing experiments remain
available; they must not be deleted or relabeled to manufacture zero violations.
The frozen course deliverable and published v4 final database are unchanged.

## Acceptance contract

- FIR: fixed 1000 ps clocks, 150 ps setup / 30 ps hold uncertainty, same
  original interface delays, no new false paths or multicycle exceptions.
- CNN: its separate original 1000 ps, 100/30 ps model. These budgets are
  still research assumptions, not characterized clock/interface guarantees.
- Candidate timing acceptance requires setup/hold WS >= 0, TNS = 0, zero
  violating endpoints and zero applicable slew/cap/fanout checks.
- All intended PVTs must be reported. A BC-only pass is not an all-corner pass.
- Final physical acceptance additionally requires rerouting after ECO,
  newly extracted parasitics, geometry/antenna checks, justified constraint
  coverage and the physical verification views currently missing from ASAP7
  project integration. Neither missing evidence nor a tool crash is PASS.

## Engineering fixes

| Issue | Implemented fix | Regression evidence |
| --- | --- | --- |
| EDA metrics checksum did not match published JSON bytes | Restore six exact raw ORFS files, retain the original measured driver in `experiments/eda_search/history/`; new runs preserve raw bytes | `tools/check_reproduction.py` checks raw/cache/summary values and hashes |
| Tampered cache accepted | Validate hash and scalar values before cache reuse | `tests/test_reproduction_guards.py` rejects content and numeric corruption |
| Unstamped checkpoints silently adopted | Reject nonempty unstamped results, logs **or reports**; exclusive stamp creation | New/matching/changed/stale variants tested |
| Document-only push starts long RTL smoke | Path-filter RTL CI; per-branch concurrency and bounded job duration | Workflow source; no claim of a new hosted CI run |
| UVM scorecard still highlighted old 144-beat identity test | Main verification row now links 17-frame / 6,440-beat functional evidence | Existing measured logs preserved |
| CNN repeats the same frame | Different images, weights and biases each frame; reload only after previous output is accepted | New dynamic suite also covers midframe reset/restart and INT32 bias extremes |
| Missing/partial timing reports could look clean | Completion marker, finite metrics, required counts and nonzero failure status | Missing marker, duplicate counts, NaN and single-violation negative controls |

Run fast checks:

```bash
python3 -m unittest discover -s tests -v
python3 tools/check_reproduction.py
python3 tools/check_flow_views.py
bash experiments/cnn/run_tests.sh work/cnn-current
```

## Fresh FIR multi-PVT diagnostic

Same original v4 final netlist and routed SPEF, fixed 1 ns / 150/30 ps.
This is a matched **cross-PVT, single-RC audit**, not a new WC implementation.

| Library | Setup WS (ps) | Setup endpoints | Hold WS (ps) | Hold endpoints | Slew violations |
| --- | ---: | ---: | ---: | ---: | ---: |
| FF | -15.69 | 19 | +4.88 | 0 | 243 |
| TT | -333.53 | 6,135 | +15.27 | 0 | 379 |
| SS | -923.11 | 14,111 | -183.10 | 8,378 | 5,639 |

[Machine-readable matrix and hashes](../reports/closure_20260911/matrix/matrix.json).
The SS worst setup path is `c_d2 -> pair_q` (coefficient distribution and
multiply/add); the worst hold path is `mem_rdata -> rdata_q`, where the fixed
800 ps virtual clock and slow-corner propagated capture tree differ materially.
Neither is fixed by merely lowering the clock frequency or hiding the endpoint.

Standalone STA initially crashed with exit -11 in
`sta::max_fanout_violation_count`. Source inspection found the direct API
does not initialize the fanout checker; `report_check_types -max_fanout`
does. The main audit uses the report interface, and the CNN audit initializes
the report before the count API. The failing report is retained in
`reports/closure_20260911/baseline/FF.rpt`. No PDK warning was suppressed.

The reported fanout count covers applicable library/SDC checks; it does not
establish a physically approved global fanout specification. Reset remains
an external synchronization contract. A `No paths found` clock-check section
does not independently validate reset recovery/removal.

The separately bounded `check_setup -verbose` now completed with
`COVERAGE_TOOL_PASS 1`, without adding any exception. This closes the previous
**tool-execution gap** in checking unconstrained endpoints, missing delays,
unclocked/multiple-clock pins, loops and generated-clock consistency under
the existing SDC. It does not validate the physical justification of that
SDC. [Coverage report](../reports/closure_20260911/coverage.rpt).

## FIR bounded ECO (not promoted to final)

1. Load original routed v4 into an isolated directory; insert **41 buffers
   across 80 nets** to address electrical violations. Save before/after
   legalization. First experiment: **311.17 s**.
2. On that saved candidate, run bounded setup and hold cleanup, saving each
   stage. With **placement-estimated** parasitics, the final result is:
   setup WS **-58.05 ps**, 462 setup endpoints; hold WS **+5.25 ps**,
   hold TNS/count 0; slew/cap 0.

Do not compare that setup value directly with the original extracted-RC
-15.69 ps as an ECO regression: the RC models differ. This candidate has
**not** been rerouted or re-extracted, and has **not** passed dual-corner
checks. It is not an acceptable replacement for the published v4 result.

[DRV experiment](../reports/closure_20260911/eco_drv/manifest.json) ·
[timing cleanup](../reports/closure_20260911/eco_timing/manifest.json).
Both manifests identify all persisted checkpoints by SHA256. Runtime and
iteration bounds stop repeated unproductive work; a bound is not a pass.

Reproduce into fresh directories:

```bash
python3 tools/run_closure_matrix.py --orfs-root "$ORFS_ROOT" \
  --result-dir "$V4_RESULTS" --output work/fir-matrix
# Exit 2 is expected while any requested timing/DRV view fails.
python3 tools/run_eco.py --orfs-root "$ORFS_ROOT" --result-dir "$V4_RESULTS" \
  --output /path/to/new/eco1
python3 tools/run_eco.py --orfs-root "$ORFS_ROOT" --result-dir "$V4_RESULTS" \
  --script eco_timing.tcl --eco-input /path/to/new/eco1 --output /path/to/new/eco2
```

## CNN physical optimization

The original single-cycle 64-bit arithmetic cone is archived unchanged.
The first new candidate uses products -> accumulation -> requantization,
33-bit proven accumulator/rounding bounds, and no abs/negate chain. Under the
same BC constraint model it completed synthesis through GDS/RCX:

| First pipeline candidate, extracted BC | Value |
| --- | ---: |
| Setup WS / TNS | +131.06 ps / 0 |
| Hold WS / TNS | +1.53 ps / 0 |
| Setup / hold / slew / cap / fanout / routing DRC counts | All 0 |
| Standard-cell area | 718.021 um² |
| Vectorless power | 8.84061 mW; not inference energy |

[Physical evidence](../experiments/cnn/results/pipeline_20260911/physical/summary.json)
and [same-candidate PVT audit](../experiments/cnn/results/pipeline_20260911/audit/matrix.json).
TT and SS still fail; a large signed row-counter comparator was found on the
SS critical path. The current follow-up narrows x/y counters to parameter
widths. Its own measured results must be used, not inherited from this table.
The first pipeline RTL is preserved under `experiments/cnn/history/`.

The final lint-clean narrow-counter source completed a separate full run
(`cnn_final_20260911`, about 3 minutes of reported stage time). Its BC result
is setup **+170.86 ps**, hold **+0.149 ps**, both TNS 0 and zero
setup/hold/slew/cap/fanout/geometric routing violations. Area is **673.071 um²**;
raw vectorless power is **26.216 mW**, not workload energy. The very small
hold margin is a reason not to call this a robust signoff guarantee.

| Final CNN, same routed candidate and original 100/30 ps model | Setup WS | Hold WS | Setup endpoints | Slew violations |
| --- | ---: | ---: | ---: | ---: |
| FF | +170.86 ps | +0.149 ps | 0 | 0 |
| TT | -111.67 ps | +17.51 ps | 21 | 176 |
| SS | -629.96 ps | +38.37 ps | 273 | 453 |

All three tool-level constraint checks completed and returned true. No
all-corner zero-violation claim is made. The narrower counter improves
critical-path timing and area but does **not** remove all slow-corner
violations, and its vectorless power is higher than the first pipeline
candidate. Both observations are retained rather than cherry-picking one.

[Final CNN physical evidence](../experiments/cnn/results/final_20260911/physical/summary.json) ·
[PVT matrix](../experiments/cnn/results/final_20260911/audit/matrix.json) ·
[15-frame test manifest](../experiments/cnn/results/final_20260911/suite_manifest.json).

Promotion gates (currently both return a nonzero status):

```bash
python3 tools/check_closure.py reports/closure_20260911/matrix/matrix.json
python3 tools/check_closure.py experiments/cnn/results/final_20260911/audit/matrix.json
```

Checking a gate does not launch a flow. Missing corners, altered reports,
summary/report mismatches and any nonzero timing/DRV count fail the gate.

## Remaining hard gates

- FIR WC 1 GHz requires structural MAC/coefficient-distribution optimization;
  a small BC ECO cannot remove ~923 ps of SS setup deficit.
- SRAM hold needs a justified external clock/SRAM timing contract and/or a
  properly optimized capture tree, not another arbitrary delay value.
- Every promoted ECO needs route, RCX and the full min/max/DRV matrix again.
- A predictive ASAP7 study cannot become foundry tapeout signoff merely by
  changing README labels: real macro views, clock/variation budgets, physical
  verification decks and integration constraints are prerequisites.
- Complete final mapped-netlist equivalence/SDF simulation and full functional
  coverage remain separate from these timing and engineering fixes.
