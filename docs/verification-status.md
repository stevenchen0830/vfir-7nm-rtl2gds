# Verification status

An independent third-party audit (2026-08-30, of commit `cc60e8a`; tools:
Icarus Verilog 14, Yosys 0.68, SBY/EQY v0.68, Boolector 3.2.4) assessed
this project beyond its own dynamic verification. Their full reports are
archived unedited in [`audit/`](audit/). This page is the honest scorecard;
nothing below is a signoff claim.

| Check | Status | Evidence |
| --- | --- | --- |
| RTL dynamic verification | **PASS** | 54 frames / 2,821,840 component checks / 0 errors (re-run independently); reference model 117 shape×kernel equivalence combinations |
| Formal functional completeness | **PARTIAL** | control-safety BMC to 40 cycles PASSES (FSM/counter bounds, `mem_we ⊆ mem_ce` one-hot, no same-bank read/write, post-reset quiescence, no valid loss under backpressure); **no unbounded proof** connecting the golden FIR math to every output transaction |
| CDC | **PASS (module level)** | 556 sequential cells / 21,416 state bits all on the single `clk`; no generated or data clocks — no internal crossings exist |
| RDC | **CONDITIONAL** | single `rst_n` domain, but 20,178 of 21,416 state bits are deliberately unreset (datapath); correctness relies on the 1,238 reset control bits isolating unknown payload — evidenced by the bounded BMC, not proven unbounded — and on an **external reset synchronizer that is not part of this repo** (declared SDC contract, `set_false_path -from rst_n`) |
| Synthesis equivalence (LEC) | **PARTIAL** | RTL vs generic-synthesis netlist, 682 EQY partitions: **532 proven, 149 UNKNOWN** (induction did not close), the monolithic `rdata_q[7839:0]` partition exhausted solver resources, **0 counterexamples**. "No evidence of miscompile" — not "LEC PASS". The ORFS physical netlists needed for final LEC are published as release assets (below) |
| MMMC / final timing at 1 GHz | **FAIL / NOT CLOSED** | BC: setup −50.35 ps (140 endpoints), hold −37.77 ps (1,601), 881 slew + 1 cap DRVs. WC: setup −950.61 ps (10,694 endpoints). Feasible WC period 1950.6 ps ≈ 513 MHz. Single-SPEF views, post-repair netlist not re-routed/re-extracted — see [hold-study.md](hold-study.md) |

## What "closed" would require (not attempted here)

Transaction-level formal harness proving every output handshake against the
golden model (assume-guarantee over banks/lanes); reset-synchronizer RTL +
unbounded no-payload-leak-before-valid property; final-netlist LEC with
`rdata_q` sliced per bank and reset-reachability invariants; per-corner RC
extraction, complete `check_timing`, LVS/EM, SRAM macro signoff. That is a
signoff workflow, deliberately out of scope for this academic project.

## Third-party reproduction assets

Final physical netlists and SPEF parasitics for all three implementations
(BC base / WC full-ICG / WC selective-gating) are published as gzipped
GitHub release assets with SHA-256 sums, so final-netlist LEC and STA can
be reproduced without re-running the flow. The exact Liberty inputs are
pinned by `reports/liberty_manifest.sha256` against the ORFS ASAP7
platform files named in `reports/TOOL_VERSIONS.txt`.
