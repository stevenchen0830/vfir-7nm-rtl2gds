# v4 host tool notes

These are host/environment observations, not design failures.

- **Yosys:** the Windows desktop sandbox intermittently left `yosys.exe`
  waiting in an LPC reply before startup. Running the same OSS CAD Suite with
  both its `bin` and `lib` directories on `PATH` outside that sandbox worked;
  synthesis, CDC/RDC extraction, formal BMC and EQY then ran normally.
- **EQY/Yosys resources:** the monolithic 7,840-bit `rdata_q` partition grew
  to about 5.2 GB and was terminated deliberately. This is reported as a
  resource ERROR, not as an equivalence mismatch.
- **Verilator:** RTL lint passed. `--binary` completed Verilator's front-end
  generation, then stopped because this Windows host has neither GNU `make`
  nor a C++ compiler. The complete functional regression therefore remains
  the Icarus run archived in `rtl_regression_v4.log`.
