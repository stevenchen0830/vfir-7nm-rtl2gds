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
         verification/img_filter_tb.v && vvp tb.vvp
```

## Physical implementation (OpenROAD-flow-scripts + ASAP7)

Flow configuration in [`flow/asap7/`](flow/asap7/): 1 GHz SDC at the SS corner
(0.63 V / 100 °C, 150 ps clock uncertainty), RVT cells, 22 % core utilization.

```sh
# inside an OpenROAD-flow-scripts checkout
cp rtl/* $ORFS/flow/designs/src/img_filter/
cp flow/asap7/* $ORFS/flow/designs/asap7/img_filter/
cd $ORFS/flow && make DESIGN_CONFIG=./designs/asap7/img_filter/config.mk
```

### Measured results

All numbers from the `6_finish` signoff report of a completed RTL-to-GDSII
run (post-route parasitics, SS corner):

| Metric | v2 (2-stage MAC) | v3 (3-stage MAC) |
| --- | --- | --- |
| Signoff fmax | 847 MHz | **952 MHz** (setup WNS −50 ps vs. 1 GHz) |
| Hold WS | −25 ps residual | −38 ps residual |
| DRC violations | 0 | **0** |
| Routing congestion overflow | 0 | **0** on all 7 metal layers |
| Synthesis area | 39,842 µm² | 42,697 µm² (+7 % for the extra pipe registers) |
| Post-route std-cell area | 47,410 µm² | 50,471 µm², 513 k instances |
| Power (vectorless, 1 GHz) | 75 mW | **72 mW** |
| Worst IR drop | 7.8 mV | 7.5 mV |

### The bottleneck hunt, in one paragraph

The first implementation closed at 830 MHz with 3.3 W of vectorless power and
every critical endpoint on the 7840-bit SRAM read-data register bank.
Stage-by-stage WNS/TNS analysis separated the overlapping causes: a genuine
architectural wall (the backpressure enable fanning out to 7840 data muxes —
fixed in RTL with elastic skid buffers and inferred ICG clock gates), and
several layers of constraint fiction (generic IO budgets on same-clock SRAM
pins, ideal-launch vs. propagated-capture skew, silently failing SDC
collection arithmetic — each diagnosed from repair-log behavior and fixed
with explicit, insertion-tracking pin constraints).  The clean rerun closed at 847 MHz / 75 mW with the MAC compressor tree as the
one honest limiter, and a third MAC pipeline stage then took signoff to
**952 MHz / 72 mW** — the remaining 50 ps is the RVT-cell floor at 0.63 V,
with SLVT cells as the obvious next lever. Layout gallery in [`docs/img/`](docs/img/).

| | |
|---|---|
| ![Clock tree](docs/img/final_clocks.webp) | ![IR drop](docs/img/final_ir_drop.webp) |

## Repository layout

```
rtl/            synthesizable Verilog (top: IMG_FILTER)
verification/   golden model + self-checking testbench
flow/asap7/     OpenROAD-flow-scripts design config + SDC
reports/        raw signoff evidence from the v3 run (see below)
docs/img/       renders from the routed database
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
