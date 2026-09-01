# Report provenance

Every file below maps to one run. "SDC" names the constraint file content in
force during that run — `constraint.sdc` at the time of all these runs was
the **blanket-uncertainty (reported)** version, preserved verbatim as
[`../flow/asap7/constraint_reported.sdc`](../flow/asap7/constraint_reported.sdc);
the split-uncertainty correction lives in `constraint_recommended.sdc` and
was applied only where noted. Sweep SDCs (`sweep_*.sdc`) are the reported
SDC with the period changed and the IO budget frozen at 200 ps absolute.
Integrity: `manifest.sha256` (v3/BC round), `manifest_planv3.sha256`
(slow-corner/hold round), and **`manifest_v4.sha256` (current v4 signoff
round)**. CI checks the v4 manifest. Checksums are computed over LF content —
see `.gitattributes`.

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
| `v4_6_finish.rpt`, `v4_6_metrics.json` | v4 split-rotator implementation, in-flow finish | FF/BC flow default | route SPEF | 1000 ps, setup/hold uncertainty 150/30 ps | yes; setup −15.69 ps / hold +4.88 ps, 243 slew violations |
| `v4_ff_u100.rpt` | v4 final netlist, documented 1 GHz operating view | FF/BC | route SPEF | 1000 ps, setup/hold uncertainty 100/30 ps | yes; setup +34.31 ps / hold +4.88 ps, both TNS 0 |
| `v4_ff_u150.rpt` | v4 final netlist, legacy conservative setup-uncertainty view | FF/BC | route SPEF | 1000 ps, setup/hold uncertainty 150/30 ps | yes; setup −15.69 ps / hold +4.88 ps |
| `v4_tt_u150.rpt` | v4 cross-corner diagnostic | TT | reused route SPEF | 1000 ps, setup/hold uncertainty 150/30 ps | yes; diagnostic only, not per-corner extracted signoff |
| `v4_ss_2000.rpt` | v4 slow-corner 500 MHz operating check | SS | reused route SPEF | 2000 ps, setup/hold uncertainty 150/30 ps | yes; setup +76.89 ps; hold number is not the valid hold corner |
| `manifest_v4.sha256` | SHA-256 pins for the six current v4 reports above | — | — | — | yes; checked by CI |

The gzipped **GitHub release assets** (with `assets.sha256`) contain the
earlier v3/hold-study physical netlists and SPEF parasitics.  The repository's
current v4 evidence is the six-report set pinned by `manifest_v4.sha256`;
the v4 final mapped netlist, per-corner SPEFs and SDF are not currently
published, so final-netlist LEC and SDF GLS cannot yet be reproduced from a
fresh clone.

Reproduction drivers: [`../flow/experiments/`](../flow/experiments/).
Independent audit reports: [`../docs/audit/`](../docs/audit/).
