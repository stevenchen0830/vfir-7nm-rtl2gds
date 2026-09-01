# v4 CDC/RDC structural audit

- Top module: `IMG_FILTER`
- Sequential cells: 562 (`$adff` 58, `$dff` 504)
- Sequential state bits: 22,577
- Resettable state bits: 1,206
- Deliberately unreset datapath state bits: 21,371
- Distinct sequential clock nets: 1
- Distinct asynchronous reset nets: 1

Automated Yosys-JSON inspection found that every sequential cell uses the
sole top-level `clk`, and every asynchronously reset cell uses the sole
top-level `rst_n`.  There are therefore no internal RTL clock-domain
crossings in this module.

This is a structural audit, not commercial CDC/RDC signoff.  Safe reset
deassertion remains conditional on the external synchronizer required by the
integration contract.  The unreset payload state must remain isolated by
reset control/valid state; bounded formal and reset-injection tests provide
evidence for that isolation but not an unbounded proof.
