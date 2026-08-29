# Hold-closure study — reproduction scripts

These are the exact experiment drivers behind the reports in
[`../../reports/`](../../reports/) (see `reports/README.md` for the
report-by-report provenance map). All scripts read two environment
variables, defaulting to the paths used for the published runs:

```sh
export ORFS_ROOT=/path/to/OpenROAD-flow-scripts   # default /root/ORFS
export CLKGATE_MIN_NET_SIZE=2000                  # selective leg only
```

| Directory | Experiment |
| --- | --- |
| `full_icg/` | WC-corner flow with default gating (30 ICGs) + dual-corner hold repair (experiment A) |
| `selective_icg/` | `clockgate -min_net_size` synthesis hook, WC flow (2 ICGs) + hold repair with GRT recheck matrix (experiment B) |
| `hold_uncertainty/` | Empirical validation of the split-uncertainty correction (8th SDC artifact) |

Known script-robustness fixes relative to the published runs (the published
logs document both failures): `write_db` now precedes the report sections
(a report-stage error previously discarded the in-memory repaired design
twice: `DPL-0038` filler utilization, then `STA-0103` on `report_power`
under multi-corner), and `remove_fillers` runs right after `read_db` on
finished databases.
