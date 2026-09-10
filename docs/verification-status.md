# Verification status — v4

This scorecard describes the v4 split-rotator RTL and the v4 physical reports
on `main`. Verification was re-run on 2026-09-01 with Icarus
Verilog 14, Verilator 5.051, Yosys/SBY/EQY 0.68 and Boolector 3.2.4. Historical
audit files for commit `cc60e8a` remain in [`audit/`](audit/) but do not define
the current v4 status. Nothing on this page is a tapeout-signoff claim.
A native UVM pass-through smoke was additionally run on 2026-09-02 with
Verilator 5.050 and the Verilator-compatible Accellera UVM 2020.3.1 library.

| Check | Status | Current v4 evidence |
| --- | --- | --- |
| RTL dynamic verification | **PASS** | Complete 54-frame self-checking regression, four independent 13-frame seeds, 0..48 split-rotator test, PREP boundary/consecutive-frame checks and five runtime-reset injection sites. Independent Python model: 117 shape-by-kernel checks. Native UVM smoke: 144 accepted beats with input starvation/output backpressure, 0 errors/fatals. See [`audit/dynamic_verification_v4.md`](audit/dynamic_verification_v4.md) and [`audit/uvm_smoke_v4.log`](audit/uvm_smoke_v4.log). |
| Functional coverage | **PARTIAL** | The testbench records legal kernel values, width modulo 4, bank wrap and all three rotation-shift masks. These are targeted functional counters, not code/toggle/branch coverage and not proof of every legal input sequence. |
| Formal functional completeness | **PARTIAL** | Forty-cycle BMC passes the control-safety and split-rotator pipeline/tag assertions. It does not prove every output transaction against the mathematical FIR reference and is not an unbounded proof. |
| CDC | **PASS (module level)** | 562 sequential cells / 22,577 state bits all use the sole top-level `clk`; no internal clock crossing exists. |
| RDC | **CONDITIONAL** | All 1,206 resettable state bits use `rst_n`; 21,371 datapath bits are deliberately unreset. Reset-injection and bounded-formal checks support payload isolation, but safe deassertion still depends on the external reset synchronizer required by the integration contract. |
| Synthesis equivalence | **PARTIAL / INCONCLUSIVE** | Generic Yosys synthesis passes structural `check -assert`. With the split-rotator pipeline grouped correctly, EQY proves 532/680 partitions; 147 remain UNKNOWN after the bounded fallback and only the 7,840-bit `rdata_q` partition ends in a resource ERROR. The earlier isolated `c_fut` false counterexample is gone (the grouped partition is UNKNOWN, not FAIL). This is not final LEC against an ORFS mapped netlist. |
| Zero-delay GLS | **PASS (generic netlist)** | Public-interface pass-through smoke: 144 beats, zero errors. Original v4 final inputs and new derived SDF are now packaged separately; mapped-netlist and timing GLS remain unrun. [Asset scope](physical-assets.md). |
| 1 GHz FF/BC operating view | **PASS, limited view** | With the documented 100 ps setup / 30 ps hold uncertainty: setup WNS +34.31 ps, TNS 0; hold WNS +4.88 ps, TNS 0. This uses the routed v4 SPEF and FF Liberty view. |
| Implementation 150 ps setup-uncertainty view | **NOT CLOSED** | Setup WNS -15.69 ps, TNS -117.37 ps, 19 endpoints; hold remains +4.88 ps / TNS 0. This is the implementation budget; 100/30 is a separate assumed sensitivity view, not a physically established operating guarantee. |
| MMMC / electrical / physical signoff | **NOT CLOSED** | 243 max-slew violations remain (max-cap and max-fanout are 0). TT at 1 GHz and SS at 2 ns are diagnostics that reuse one SPEF, not per-corner extracted MMMC. Full `check_timing`, final-netlist LEC, LVS, EM/IR and SRAM-macro signoff are absent. |

## Timing evidence boundary

The current timing source set is pinned by
[`reports/manifest_v4.sha256`](../reports/manifest_v4.sha256). The TT 1 GHz
diagnostic reports setup WNS -333.53 ps. The SS 2 ns diagnostic reports setup
WNS +76.89 ps and hold WNS **-303.10 ps**, hold TNS **-1,570,621.12 ps**.
The archived SS script used the **blanket 150/150 ps sweep SDC**, previously
mislabeled 150/30. SS hold cannot be ignored because it is a slow corner.
These cross-corner reports reuse route parasitics rather than
extracting an RC view for every corner.

## What remains for stronger closure

1. Prove transaction-level FIR equivalence with a bounded-memory or
   assume-guarantee formal harness, and slice `rdata_q` by bank for LEC.
2. Use the packaged v4 final inputs and derived SDF to run final-netlist
   LEC, mapped zero-delay GLS and an annotation-checked SDF smoke; these tests
   are not automatically passed by publishing assets.
3. Repair the 243 max-slew violations, incrementally route, re-extract SPEF,
   and run setup/hold/DRV plus constraint coverage across real extracted
   corners.
4. Add integration-level reset synchronization, SRAM models/macros, LVS and
   EM/IR checks if the project target changes from academic flow evidence to
   tapeout readiness.

## September 2026 reproducibility and UVM extension

The default flow now has a named v4 150/30 entry and a separate FF 100/30
audit override; historical SDC/report bytes remain unchanged. Both budgets
are modeling assumptions, not measured clock-jitter guarantees. See
[constraint assumptions](constraint-assumptions.md).

The functional UVM runner now includes a synchronous 49-bank SRAM model,
an observed-input direct-convolution predictor, Python golden cross-check,
kernel 1/3/7/49 tests, width-modulo-4 cases and two negative controls.
The completed run contains 17 frames (including learned K=5), 6,440 checked
output beats and both injected faults detected. [Raw summary](audit/uvm_functional/summary.json).
Coverage is explicit functional counters, not full code/toggle or unbounded
verification. The old UVM package and log remain historical smoke evidence;
the runner compiles `img_filter_functional_pkg.sv` for the new suite.
See [UVM run guide](../verification/uvm/README.md).

The saved original v4 physical inputs were located for export. Asset
publication and newly derived SDF do not change the historical GLS/LEC
verdict. Consult [physical assets](physical-assets.md) for current availability
and [walkthrough](rtl-to-gds-walkthrough.md) for fresh-clone reproduction.
