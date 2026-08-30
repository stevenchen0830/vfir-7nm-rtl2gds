# CDC/RDC structural audit

- Top module: `IMG_FILTER`
- Source: `work\test-results\img_filter_proc.json`
- Sequential cells: 556 ($adff=59, $dff=497)
- Sequential state bits: 21416
- Resettable state bits: 1238
- Unreset state bits: 20178
- Declared `clk` bit IDs: 2
- Distinct sequential clock nets: 1
- Declared `rst_n` bit IDs: 3
- Distinct asynchronous reset nets: 1

## Automated findings

- PASS: every sequential cell is clocked by the sole top-level `clk` net; no RTL clock-domain crossing is structurally present.
- PASS: every asynchronous-reset sequential cell uses the sole top-level `rst_n` net; no internal asynchronous reset domain was found.
- INFO: 20178 of 21416 state bits have no reset and therefore require validity/control gating before observation.

## Scope and integration condition

This is an RTL structural audit, not a commercial CDC signoff run. It can establish that the checked module contains one sequential clock domain and one asynchronous reset source. It cannot inspect the chip-level reset synchronizer because that integration logic is outside this repository. Safe reset deassertion therefore remains conditional on the documented external synchronizer, and unreset payload state remains conditional on validity/control correctness.

## Clock groups

- `2`: 556 sequential cells

## Asynchronous reset groups

- `3`: 59 sequential cells
