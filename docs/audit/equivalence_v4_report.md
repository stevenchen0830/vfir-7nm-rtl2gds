# v4 RTL-to-generic-synthesis equivalence

## Result: PARTIAL / INCONCLUSIVE

Yosys generic synthesis completed and `check -assert` reported no structural
errors. The corrected grouped EQY run generated 680 state/output partitions.
The resource-bounded run closed 532 with SAT induction, left 147 UNKNOWN after
the short SBY fallback, and exhausted host resources on only the monolithic
7,840-bit `rdata_q` partition (about 5.2 GB before termination). No partition
ended in FAIL.

The first partitioning also reported one `c_fut` FAIL. Inspection of its
base-case model showed that EQY had exposed only part of the unreset
split-rotator pipeline: `cvlo3_q` initial state could be chosen independently
in gold and gate while `c_fut` was compared. This is a partition-cut artifact,
not a demonstrated RTL/netlist output mismatch. The checked-in EQY config now
collects `cvlo*_q`, `shi*_q`, `cbp_mid_q`, `c_fut`, `ce_fut` and `cbp_fut`
into one partition so those arbitrary initial values cannot be separated. In
the corrected run that grouped partition is UNKNOWN rather than FAIL; this
removes the false counterexample but does not constitute a proof.

This evidence must not be labelled LEC PASS. Stronger closure requires
slicing/abstracting `rdata_q`, adding reachability assumptions for unreset
state, allowing the UNKNOWN partitions more proof depth, and comparing the
RTL with the actual v4 ORFS mapped/final netlist when that artifact is
published.
