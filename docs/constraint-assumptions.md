# Timing views and assumptions

The timing numbers describe a netlist **under a stated model**. They are not
measurements of fabricated silicon. ASAP7 is a predictive research PDK.

| Entry | Purpose | Core setup / hold uncertainty |
| --- | --- | --- |
| `flow/asap7/config_historical.mk` | Explicit historical blanket model, retained unchanged | 150 / 150 ps |
| `flow/asap7/config_v4.mk` (default config uses the same SDC) | New v4 reproduction run, BC, fixed absolute IO assumptions | 150 / 30 ps |
| `flow/asap7/audit_ff_u100.tcl` | Override **after reading final SDC**, on the same routed FF candidate | 100 / 30 ps |

`constraint.sdc`, `constraint_reported.sdc`, `constraint_recommended.sdc`,
`constraint_mcp.sdc` and historical sweeps are preserved for provenance.
Their old explanatory comments are not evidence of physical validity. The
default configuration now selects the separately named `constraint_v4.sdc`.

## Budget provenance

| Quantity | Value in reproduction model | Source / missing evidence |
| --- | --- | --- |
| Period | 1000 ps | Chosen design target |
| Core setup uncertainty | 150 ps implementation; 100 ps sensitivity view | Project assumptions; no PLL jitter characterization or approved OCV budget |
| Core hold uncertainty | 30 ps | Project assumption; not a measured same-edge jitter/skew bound |
| Virtual-clock latency | 800 ps | Historical interface model; not measured min/max external clock insertion |
| Stream input max/min | 200 / 100 ps | Assumed upstream timing; no producer Liberty |
| Stream output max/min | 200 / +500 ps | Historical model; +500 is **not** a 500 ps receiver hold requirement |
| SRAM input max/min | 100 / 10 ps | Assumed read tCQ; no matching integrated macro characterization |
| SRAM output max/min | 100 / +500 ps | Historical model, not a real macro's setup/hold contract |
| Reset exception | false path from `rst_n` | External synchronized-deassertion contract; recovery/removal remains unverified here |

Jitter, residual skew, variation/OCV and any extra guardband need separate
physical sources before these values can become signoff budgets. A common
clock source does not eliminate differential clock-tree delay. Post-CTS STA
uses propagated clocks; do not add the same skew again to uncertainty without
an explicit model. The +500 ps output delay and 800 ps latency must be derived
together from a launch/capture diagram if a real interface is integrated.

Changing setup uncertainty from 150 to 100 ps increases affected setup slack
by 50 ps **without changing any cell, route or transistor**. This is a
sensitivity/operating-assumption result, not a physical timing improvement.
The same caveat applies to the historical hold-uncertainty experiment.

## SS report correction

`reports/v4_ss_2000.rpt` reports setup +76.89 ps and hold **-303.10 ps**, hold
TNS **-1,570,621.12 ps**. The archived `/root/sta_suite/v4_ss_2000.tcl`
actually loaded `sweep_2000.sdc` with **blanket 150/150 ps**, not 150/30.
The provenance table previously mislabeled this report. Keep its original
bytes and hash; this document corrects the interpretation.

SS hold is a valid diagnostic under that model and cannot be discarded merely
because FF is commonly the dominant hold corner. A matched SS 150/30 rerun
would be a new report. Do not silently substitute an arithmetic adjustment
for an executed analysis. All intended corners require both min and max
checks, with their actual clock and parasitic models.

The ~520 MHz value inferred from `2000 - 76.89` is a **setup-limited estimate**
from one SS diagnostic point, not a measured safe operating frequency or a
complete v4 period sweep. 500 MHz is not certified: hold, slew and coverage
gaps remain. Slowing the period generally does not fix same-edge hold.

## Reproduction boundaries

Historical v4 used SLEW_MARGIN=15 through CTS and reran stages 5/6 with
SETUP_SLACK_MARGIN=30, HOLD_SLACK_MARGIN=20, SLEW_MARGIN=25. The new
`config_v4.mk` consistently uses 30/20/25 for a fresh run. It is an explicit
reproduction configuration, not a claim of byte-identical historical replay.
For the exact published candidate, use archived final inputs and standalone
STA. Different tools, hooks, seeds, stage histories or libraries may change PPA.

Every new period sweep must keep IO delays, uncertainty and latency fixed
unless the interface specification itself defines frequency-dependent values.
