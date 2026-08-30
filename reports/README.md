# Report provenance

Every file below maps to one run. "SDC" names the constraint file content in
force during that run — `constraint.sdc` at the time of all these runs was
the **blanket-uncertainty (reported)** version, preserved verbatim as
[`../flow/asap7/constraint_reported.sdc`](../flow/asap7/constraint_reported.sdc);
the split-uncertainty correction lives in `constraint_recommended.sdc` and
was applied only where noted. Sweep SDCs (`sweep_*.sdc`) are the reported
SDC with the period changed and the IO budget frozen at 200 ps absolute.
Integrity: `manifest.sha256` (v3/BC round), `manifest_planv3.sha256`
(slow-corner/hold round). Checksums are computed over LF content — see
`.gitattributes`.

| File | Netlist / run | Corner(s) | Parasitics | SDC | Completed? |
| --- | --- | --- | --- | --- | --- |
| `6_finish_sta.rpt`, `4_cts_sta.rpt`, `5_groute_sta.rpt`, `5_route_drc.rpt`, `1_synth_area.txt`, `6_metrics.json` | v3 BC in-flow signoff (`FLOW_VARIANT=base`) | BC (flow default) | route SPEF | reported @1000 | yes |
| `sta_bc_full.rpt` / `.tcl` | v3 BC final netlist, standalone OpenSTA | FF | route SPEF | reported @1000 | yes (check_timing sections tool-limited) |
| `sta_wc_audit.rpt` / `.tcl` | v3 BC final netlist, cross-corner audit | SS | route SPEF (BC extraction) | reported @1000 | yes (same caveat) |
| `wc_6_finish.rpt` | WC full-ICG implementation (`FLOW_VARIANT=wc`) | SS in-flow | route SPEF | reported @1000 | yes |
| `step3_bc_hold_wc.rpt` | WC netlist, hold at proper (fast) corner | FF | route SPEF | sweep @1000 | yes |
| `step4_sweep_{1800..2100}.rpt` | WC netlist, frozen-IO period sweep | SS | route SPEF | sweep @period | yes |
| `step5_holdfix_fullicg.log` | WC netlist, dual-corner hold repair (experiment A), trimmed trajectory | FF+SS | route SPEF (baseline/trajectory) | sweep @2000 | repair converged (`RSZ-0064` residual); post-repair DB lost to `DPL-0038` (fillers), documented |
| `sel_6_finish.rpt` | selective-gating implementation (`FLOW_VARIANT=sel`, ICGs 30→2) | SS in-flow | route SPEF | reported @1000 | yes |
| `step5b_holdfix_sel.log` | sel netlist, hold repair + recheck matrix (experiment B) | FF+SS | SPEF (baseline/trajectory), **GRT-estimated (post-repair matrix)** | sweep @2000 | timing/area matrix complete; final `report_power` aborted with `STA-0103` (multi-corner scene) — no power claim uses it; repaired DB not saved |
| `diag_ccur_holdroot.log` | sel netlist (unrepaired), residual root-cause diagnosis | FF | route SPEF | sweep @2000 | yes |
| `verify_hold_uncertainty.log` | sel netlist (unrepaired), `-hold 30` override validation | FF | route SPEF | sweep @2000 + `-hold 30` | yes |
| `drc_summary.txt` | routing-DRC summary across all three implementations | — | — | — | yes |
| `liberty_manifest.sha256` | SHA-256 pins of the exact NLDM Liberty files used (paths relative to the ORFS checkout in `TOOL_VERSIONS.txt`) | — | — | — | yes |

Final physical netlists and SPEF parasitics for all three implementations
are published as gzipped **GitHub release assets** (with `assets.sha256`),
enabling third-party final-netlist LEC and STA without re-running the flow.

Reproduction drivers: [`../flow/experiments/`](../flow/experiments/).
Independent audit reports: [`../docs/audit/`](../docs/audit/).
