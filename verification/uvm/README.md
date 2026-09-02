# Native UVM smoke

This directory contains a small native SystemVerilog UVM environment for
`img_filter`.  It was tested on WSL2 Ubuntu with Verilator 5.050 and the
Verilator-compatible Accellera UVM 2020.3.1 library from
<https://github.com/verilator/uvm> at commit
`656f20d087370a7c742e00188d20bbf30fa95339`.

## Run

Clone the UVM compatibility library outside this repository, then point
`UVM_HOME` at the directory containing `uvm_pkg.sv`.  Keep the generated C++
model on the Linux filesystem when running from WSL; this avoids the slower
small-file I/O under `/mnt/c`.

```bash
git clone https://github.com/verilator/uvm.git ../uvm-verilator
git -C ../uvm-verilator checkout 656f20d087370a7c742e00188d20bbf30fa95339
UVM_HOME="$PWD/../uvm-verilator/src" \
UVM_BUILD_DIR=/tmp/vfir-uvm-build \
bash verification/uvm/run_verilator.sh
```

A pass ends with `UVM SMOKE PASSED`, 144 checked beats, and zero UVM errors or
fatals.  The two `UVM_NO_DPI` warnings are limitations of this open-source UVM
configuration rather than DUT failures.

## Checked scope

- one 24x24 frame with `blk_v=1` and the identity/pass-through coefficient;
- deterministic gaps on the input stream;
- deterministic backpressure on the output stream;
- accepted input versus accepted output data, in order, for all 144 beats.

This is an integration smoke test, not full UVM closure.  It does not cover all
FIR kernels, rotation amounts, reset injection, functional coverage, assertions
or timing/physical signoff.  The existing directed and 54-frame regressions
remain the release-level dynamic evidence for those broader cases.
