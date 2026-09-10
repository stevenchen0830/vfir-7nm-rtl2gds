# Native UVM functional regression

The current runner is **not** the original identity-only smoke test. It uses
`img_filter_functional_pkg.sv` plus a synchronous 49-bank SRAM model. The old
`img_filter_uvm_pkg.sv` is retained as historical source and is not compiled
by the current runner; do not compile both package definitions together.

## Run

Validated with Verilator **5.050**, g++/make, Python 3 and the
[Verilator-compatible UVM 2020.3.1 library](https://github.com/verilator/uvm)
at `656f20d087370a7c742e00188d20bbf30fa95339`. Older distribution Verilator
packages may not support the required UVM features. No commercial UVM
simulator was used for the committed run.

```bash
git clone https://github.com/verilator/uvm.git ../uvm-verilator
git -C ../uvm-verilator checkout 656f20d087370a7c742e00188d20bbf30fa95339
export UVM_HOME="$PWD/../uvm-verilator/src"
export UVM_BUILD_DIR="$HOME/vfir-uvm-build"
export VERILATOR=/path/to/verilator-5.050/bin/verilator
bash verification/uvm/run_verilator.sh
```

Use a Linux-filesystem build directory under WSL to avoid `/mnt/c` C++
small-file overhead. The script builds once, then runs each frame separately.
Limit a quick rerun with `UVM_KERNELS='3' UVM_WIDTHS='25'`; the defaults are
the complete matrix below. This is not a substitute for the older 54-frame
Icarus suite.

## Verification data flow

```text
Python random input + independent FIR golden
  -> UVM sequence/driver -> DUT + synchronous SRAM model
                 |
                 +-> accepted-input monitor -> direct FIR predictor
                                                   |
Python golden <----- predictor cross-check          v
                  DUT output monitor ----------> scoreboard
```

The predictor uses **observed accepted input pixels** and the latched frame
configuration, performs direct per-tap mirror convolution, rounding and
saturation, and compares its expected result with Python before checking
the DUT. It does not reuse the RTL coefficient-rotation implementation.
The SRAM model checks read-before-write, address range, and single-port
read/write behavior. Returned data is real previously written data, not zero.

## Measured matrix (2026-09-10)

| Dimension | Exercised values |
| --- | --- |
| Kernel | 1, 3, 7, 49; nontrivial symmetric coefficients for K > 1 |
| Width | 24, 25, 26, 27: all four width modulo-4 classes |
| Height | 56: crosses the 49-bank wrap boundary |
| Stream behavior | deterministic input gaps and output stalls |
| Extra learned filter | K=5, W=25, H=56, half-coefficients `[26,25,26]` |
| Negative controls | corrupt DUT output; corrupt SRAM read data |

**17 frames, 6,440 checked output beats passed**, plus both deliberately
corrupted runs were detected and returned nonzero. Each log includes top,
bottom, interior, partial-beat, starvation, stall, SRAM read/write and
bank-written counters. K=1 legitimately uses the bypass and has no SRAM
traffic. The 49-bank-written count is exercised for nontrivial kernels.

Evidence: [raw logs and summary](../../docs/audit/uvm_functional/summary.json).
Expected normal marker: `UVM FILTER PASSED`, `UVM_ERROR : 0`,
`UVM_FATAL : 0`. Expected negative marker: `MISMATCH` and
`NEGATIVE CONTROL DETECTED`. The runner checks both the negative process
exit status and mismatch marker; a printed failure followed by exit 0 does
not pass. A final severity-count guard handles simulator/UVM `$finish`
behavior. The two `UVM_NO_DPI` warnings remain disclosed.

## Coverage limits

These are explicit functional hit counters, **not** UCIS code/toggle coverage
or exhaustive cross coverage. This matrix has one frame per simulator process;
consecutive-frame and mid-frame reset tests remain in the separate directed
suite. Verilator is predominantly two-state, so this run does not establish
X-propagation, metastability, timing simulation, complete UVM closure, or
formal equivalence. The full FIR RTL itself has not been changed by this update.
