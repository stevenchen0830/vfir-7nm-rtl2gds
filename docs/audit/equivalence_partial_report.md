# RTL → generic synthesis equivalence audit

- Repository commit: `cc60e8a`
- Gold design: repository RTL (`IMG_FILTER`)
- Gate design: locally generated Yosys generic synthesized netlist
- Tool: EQY v0.68, Yosys 0.68+136
- Partitions generated: 682

## Result

- SAT-proven equivalent partitions: **532**
- SAT inconclusive partitions: **149**
- Resource/tool error partitions: **1** (`IMG_FILTER.rdata_q[7839:0]`)
- Explicit inequivalence (`FAIL`) partitions: **0**

The 149 inconclusive partitions passed the two-step reset-reachable base case in the SBY fallback, but temporal induction did not close from arbitrary states. This is an `UNKNOWN` result, not an inequivalence counterexample. The 7,840-bit `rdata_q` partition exhausted the practical monolithic proof path: SAT resource use grew to about 5 GB and the SMT2 generation fallback ended with a Windows stack-overflow return code.

## Conclusion

The local generic synthesis run has substantial partial equivalence evidence but **full equivalence is not proved**. More importantly, this is not equivalence against the physical-flow final netlist: the public repository does not contain `6_final.v`, so ORFS/ASAP7 post-synthesis or post-route LEC cannot be performed from the published artifacts.

To close this item, export the actual final netlist and use hierarchical/state-matched equivalence. Split `rdata_q` by bank or bit slices and add reset-reachable invariants for the unreset datapath partitions.
