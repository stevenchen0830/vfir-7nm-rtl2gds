# RTL-to-generic-synthesis equivalence

This harness compares the checked-in v4 RTL with a generic Yosys synthesis of
the same RTL.  It does not replace LEC against the ORFS mapped/final netlist.

```sh
mkdir -p work/equiv
yosys -ql work/equiv/synthesis.log equiv/synth_generic.ys
eqy -f -m -d work/equiv/rtl_to_generic equiv/rtl_to_generic.eqy
python3 equiv/run_eqy_strategies_without_make.py work/equiv/rtl_to_generic
```

The helper runs EQY's generated SAT jobs and uses a short SBY fallback for
partitions that do not close under SAT induction.  Any `UNKNOWN` or tool error
must remain explicitly reported; it is not an equivalence PASS.

The split-rotator pipeline registers are collected into one partition so that
EQY does not compare independently chosen arbitrary initial values across an
unreset partition boundary.  The 7,840-bit `rdata_q` state is still expected
to require a bank/slice-specific proof on memory-constrained hosts.
