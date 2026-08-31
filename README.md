# vfir-7nm-rtl2gds

A 49-tap streaming vertical FIR video-filter ASIC block, taken from Verilog RTL
through a complete open-source RTL-to-GDSII flow (OpenROAD + Yosys) on the
ASAP7 7 nm predictive PDK — with measured area, timing, congestion, and the
timing-bottleneck hunt documented along the way.

![Routed die](docs/img/final_all.webp)

## The design

`IMG_FILTER` filters an RGBA video stream (10 bit/component, 4 pixels/clock)
with a configurable vertical FIR kernel:

- **Kernel**: 1×`blk_v`, `blk_v` = 1…49 (odd), symmetric 8-bit coefficients
  summing to 128; mirror boundary handling at the top/bottom image edges.
- **Throughput**: 4 pixels/cycle sustained for every legal kernel size.
- **Streaming**: elastic ready/valid handshake on both ports, arbitrary
  backpressure and starvation tolerated.
- **Line storage**: 49 external single-port SRAM banks (160 bit × 1440),
  scheduled so that 48 reads and 1 write land in the same cycle.

### The architectural trick: rotate coefficients, not data

A naive implementation muxes 49 SRAM banks onto 49 filter taps and evaluates
the mirror mapping per tap, per beat — a 7840-bit barrel rotation plus
per-beat index arithmetic that closes neither timing nor area.

This design inverts the problem. Image row `m` lives in bank `m mod 49` at an
address equal to the beat index, so **pixel data never moves and all banks
share one broadcast address**. For each output row a 392-bit *effective weight
vector* `C[j] = Σ{coef_k | mirror(y+k, H) mod 49 == j}` is built from three
rotations of the symmetric coefficient array (interior / top-folded /
bottom-folded taps). Mirror logic vanishes from the datapath entirely; what
remains is a uniform 50-tap × 16-lane MAC array (the 50th tap forwards the row
currently streaming in, freeing its bank for that cycle's write). Bank read
enables derive from `C`, so external-memory traffic scales with `blk_v`, not
with the bank count — a `blk_v = 1` frame performs zero SRAM accesses.

### Micro-architecture notes that came from measurement, not intuition

- **MAC pipelining**: two balanced MAC stages measured ~35 logic levels each
  (1.18 ns at the SS corner), so the array is cut three ways — 25 multiply-add
  pairs, 5 partial sums, and a final round/saturate stage — buying +105 MHz of
  signoff fmax for +7 % area and one cycle of latency.
- **Elastic interfaces**: both stream ports terminate in two-slot register
  FIFOs so the pipeline enable is a function of registers only. The first
  physical-design iteration proved why: a combinational
  `ready → pipe_en → 7840 register enables` path was the walk-away timing
  wall of the whole design (repair gained 6 ps per 1000 iterations on it).
- **Clock gating**: register-enable muxes are inferred into ICG cells
  (29 gates), removing 7840 feedback muxes and cutting idle clock power.
- **SRAM interface constraints**: the `mem_*` pins are constrained as
  same-clock synchronous pins with the common tree insertion modeled
  explicitly — three progressively subtler SDC bugs (generic IO budget,
  cross-clock constraint coexistence, ideal-launch vs propagated-capture
  skew) each fabricated thousands of unfixable violations before being
  diagnosed from the repair logs.

## Verification

- **Golden model** (`verification/reference_model.py`): an executable
  specification plus an *architectural equivalence proof* — the weight-vector
  formulation is shown identical to the per-tap mirrored expansion across 117
  (shape × kernel) combinations, along with the storage invariants (a read
  bank always holds a written row; read and write banks never collide).
- **Self-checking testbench** (`verification/img_filter_tb.v`): behavioural
  single-port SRAM model with X-initialized contents, randomized
  ready/valid pressure on both ports, X injection on unused lanes, latency
  and dead-cycle checks. **54 frames, 2,821,840 component comparisons, 0
  errors** on the current RTL.

```sh
python3 verification/reference_model.py     # ALL REFERENCE CHECKS PASSED
iverilog -g2005 -o tb.vvp rtl/img_filter_def.v rtl/img_filter.v \
         verification/img_filter_tb.v && vvp tb.vvp   # +SMOKE for 13-frame CI subset
```

**Verification scorecard** (independent third-party audit, tools incl.
SBY/EQY/Boolector — full reports in [`docs/audit/`](docs/audit/), scorecard
detail in [`docs/verification-status.md`](docs/verification-status.md)):

| Check | Status |
| --- | --- |
| RTL dynamic (54-frame regression + golden model) | **PASS** |
| Formal functional completeness | **PARTIAL** — 40-cycle control-safety BMC passes; no unbounded end-to-end proof |
| CDC | **PASS** (single clock domain, no internal crossings) |
| RDC | **CONDITIONAL** — 20,178/21,416 state bits deliberately unreset; relies on declared external reset-synchronizer contract |
| Synthesis equivalence | **PARTIAL** — 532/682 EQY partitions proven, 149 unknown, 0 counterexamples |
| Timing at 1 GHz | **FAIL / NOT CLOSED** (see results below) |

## Physical implementation (OpenROAD-flow-scripts + ASAP7)

Flow configuration in [`flow/asap7/`](flow/asap7/): 1 GHz SDC, 150 ps clock
uncertainty, RVT cells, 22 % core utilization. **Timing corner**: the flow
signs off at the ORFS ASAP7 default `CORNER=BC` (FF libraries, 0.77 V / 25 °C)
— see the corner note below the results.

```sh
# inside an OpenROAD-flow-scripts checkout
cp rtl/* $ORFS/flow/designs/src/img_filter/
cp flow/asap7/* $ORFS/flow/designs/asap7/img_filter/
cd $ORFS/flow && make DESIGN_CONFIG=./designs/asap7/img_filter/config.mk
```

### Measured results

All numbers from the `6_finish` signoff report of a completed RTL-to-GDSII
run (post-route parasitics, BC corner = ORFS ASAP7 default):

| Metric | v2 (2-stage MAC) | v3 (3-stage MAC) |
| --- | --- | --- |
| Signoff fmax | 847 MHz | **952 MHz** (setup WNS −50.35 ps / TNS −2.05 ns over 140 endpoints vs. 1 GHz) |
| Hold WS (pre-hold-fix, blanket-uncertainty SDC¹) | −25 ps residual | −37.8 ps / TNS −8.68 ns over 1601 endpoints |
| Electrical DRVs at signoff | — | 881 max-slew, 1 max-cap, 0 max-fanout endpoints |
| Routing DRC (geometric²) | 0 | **0** |
| Routing congestion overflow | 0 | **0** on all 7 metal layers |
| Synthesis area | 39,842 µm² | 42,697 µm² (+7 % for the extra pipe registers) |
| Post-route std-cell area | 47,410 µm² | 50,471 µm², 513 k instances |
| Power (vectorless, 1 GHz) | 75 mW | **72 mW** |
| Worst IR drop | 7.8 mV | 7.5 mV |
| True slow-corner setup (SS 0.63 V/100 °C, standalone STA) | — | −998 ps → **≈ 500 MHz** |
| Hold at the fast corner (proper hold corner) | — | −38 ps residual |
| WC implementation @ 1 GHz SDC | — | setup WNS −950.6 ps over 10,694 endpoints → feasible ≈ **513 MHz** |
| **1 GHz timing status (both corners)** | — | **FAIL / NOT CLOSED** — 952 MHz (BC) and 513 MHz (WC) are the honest achieved numbers |

¹ All historical reports were produced with a blanket
`set_clock_uncertainty 150` that also taxes every hold check with the full
setup margin — later root-caused as the 8th constraint artifact (see the
[hold-closure study](docs/hold-study.md)). That SDC is preserved verbatim as
[`flow/asap7/constraint_reported.sdc`](flow/asap7/constraint_reported.sdc);
the corrected split-uncertainty version is
[`constraint_recommended.sdc`](flow/asap7/constraint_recommended.sdc).
² "DRC 0" means geometric routing DRC (TritonRoute spacing/via/antenna —
[`reports/drc_summary.txt`](reports/drc_summary.txt)), not the electrical
and timing checks, which are disclosed in the rows above.

Repository reports directly back the **v3 and hold-study** results
([`reports/README.md`](reports/README.md) maps every file to its run); the
v1/v2 values in this table are historical cross-spin observations retained
for the narrative.

**Corner honesty note.** An external constraint review prompted a standalone
OpenSTA audit of the shipped netlist + SPEF ([`reports/`](reports/)), which
surfaced that ORFS's ASAP7 platform defaults to `CORNER=BC` — every in-flow
signoff above is therefore at the *fast* corner, where this document
originally claimed SS. The true SS picture was then measured directly:
≈ 500 MHz setup-limited (a typical fast/slow ratio for RVT at 0.63 V), with
hold checked at the fast corner as it should be (−38 ps WNS, −8.7 ns hold
TNS — an earlier revision of this note mislabeled the setup TNS as hold).
The SPEF comes from a single RC extraction, so the standalone numbers are a
close approximation rather than a multi-corner extraction signoff.

**Audit addenda (plan-v3 round).** (1) The BC final-netlist worst setup
endpoints are the `c_fut[*]` weight-vector look-ahead registers — the 392-bit
triple-rotation cone — not the MAC array; since that vector is consumed once
per output row, it is a clean multicycle-path candidate (future work). 
(2) `check_timing` (any flag combination) does not terminate on this
500k-instance netlist in standalone OpenSTA, and `report_checks
-unconstrained` re-prints constrained groups in this version — so the
unconstrained-endpoint count is **tool-limited, unverified**; the assertion
harness marks those checks UNKNOWN rather than PASS.
STA scripts, reports and SHA-256 manifests live in [`reports/`](reports/).

### The slow-corner implementation and the hold-closure study

A second full RTL-to-GDS run at the true slow corner turned the 1 GHz gap
and the hold-repair problem into a controlled, fully evidenced study —
summarized here, with the complete investigation in
[**docs/hold-study.md**](docs/hold-study.md):

- **WC @ 1000 ps violation report**: setup WNS −950.6 ps; a frozen-IO
  period sweep pins the feasible period at 1950.6 ps ≈ **513 MHz**,
  matching signoff to 0.01 ps; the `c_fut` weight-rotator cone is the sole
  limiter at every point.
- **Two hold-repair experiments**: full gating (30 ICGs) plateaus at
  −114.7 ps on ~200 ps of gated-subtree clock skew; selective gating
  (`clockgate -min_net_size 2000`, ICGs 30 → 2) removes the
  rejection-spinning and cuts hold TNS 94 %.
- **The 8th SDC artifact class**: a blanket `set_clock_uncertainty 150`
  taxes every hold check with the full setup margin. Under the corrected
  `-setup 150 / -hold 30` split the repaired netlist is analytically
  adjusted to **+15.5 ps — hold closed** — and the 120 ps linear shift is
  empirically validated to 0.01 ps.
- **Controlled ICG ablation** (only the gating threshold differs):
  44.2 mW ↔ 155.1 mW — a quantified 3.5× power-vs-hold-closure trade.
- **The closed loop (mcp leg)**: a fourth implementation with the
  corrected hold uncertainty and the evidence-backed multicycle exception
  completed repair → detailed route → RCX extraction → final STA in one
  flow: **hold WNS +26.6 ps / TNS 0 / 0 endpoints at the fast corner —
  the first fully hold-clean post-route signoff** (clean at TT too;
  routed SPEF; `reports/mcp_6_finish.rpt` + three-corner matrix in
  `reports/matrix_mcp_*.rpt`). Setup at 1 GHz remains open at −51 ps on
  the `mod_x` rotation-amount cone; its structural fix (pipelined
  rotator) is regression-tested on the `v4-cfut-pipe` branch.
- **Current accurate statement**: at 1 GHz, SS 0.63 V/100 °C, setup does
  not close; the measured WC setup limit is ≈ 513 MHz and the recommended
  operating point with guardband is **≤ 500 MHz**. With the corrected
  hold uncertainty, hold closes through the full route-and-extract loop
  at the proper corners (FF/TT). Not yet done: 1 GHz setup closure (v4
  branch), a from-scratch corrected-SDC run (the mcp leg is
  mixed-provenance), per-corner RC extraction (single RCX model), LVS/EM,
  and a tool-complete unconstrained-endpoint audit (`check_timing` is
  tool-limited; the enumeration evidence — 23,399 register data pins on
  the single clock + explicit port-list constraints — stands in).
- Scope: academic flow — geometric routing DRC 0 on all four
  implementations, no LVS/EM, SRAMs as interface timing models only.
  Reproduction drivers: [`flow/experiments/`](flow/experiments/);
  provenance: [`reports/README.md`](reports/README.md).


### The bottleneck hunt, in one paragraph

The first implementation closed at 830 MHz with 3.3 W of vectorless power and
every critical endpoint on the 7840-bit SRAM read-data register bank.
Stage-by-stage WNS/TNS analysis separated the overlapping causes: a genuine
architectural wall (the backpressure enable fanning out to 7840 data muxes —
fixed in RTL with elastic skid buffers and inferred ICG clock gates), and
several layers of constraint fiction (generic IO budgets on same-clock SRAM
pins, ideal-launch vs. propagated-capture skew, silently failing SDC
collection arithmetic — each diagnosed from repair-log behavior and fixed
with explicit, insertion-tracking pin constraints).  The clean rerun closed at 847 MHz / 75 mW with the MAC compressor tree as
the one honest limiter, and a third MAC pipeline stage then took signoff to
**952 MHz / 72 mW** (BC corner) — the remaining 50 ps is the RVT MAC floor,
with SLVT cells as the obvious next lever. At the true SS corner the same
netlist runs at ≈ 500 MHz, which is the number a worst-case product spec
would quote. Layout gallery in [`docs/img/`](docs/img/).

| | |
|---|---|
| ![Clock tree](docs/img/final_clocks.webp) | ![IR drop](docs/img/final_ir_drop.webp) |

## Repository layout

```
rtl/               synthesizable Verilog (top: IMG_FILTER)
verification/      golden model + self-checking testbench (CI-fatal on fail)
flow/asap7/        design config + SDCs (reported / recommended / sweep set)
flow/experiments/  reproduction drivers for the hold-closure study
reports/           raw evidence + provenance map (reports/README.md)
docs/              hold-study.md, verification-status.md, third-party
                   audit reports (docs/audit/), routed-database renders
```

The [`reports/`](reports/) directory carries the unedited tool output backing
every number in the results table: `6_finish_sta.rpt` (post-route OpenSTA
signoff — WNS/TNS, fmax, clock skew, worst paths), `4_cts_sta.rpt` and
`5_groute_sta.rpt` (stage-by-stage timing trajectory), `5_route_drc.rpt`
(zero bytes — the DRC proof), `1_synth_area.txt`, and `6_metrics.json`
(machine-readable power/area/IR metrics).

## Toolchain

Icarus Verilog · Verilator (lint) · Yosys 0.68 · OpenROAD 26Q3 · OpenSTA ·
ASAP7 7 nm predictive PDK · WSL2 Ubuntu 22.04

## License

MIT — see [LICENSE](LICENSE). ASAP7 and OpenROAD-flow-scripts carry their own
licenses.
