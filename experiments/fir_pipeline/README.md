# FIR v5 MAC pipeline candidate — functional experiment

**Not a replacement for published v4 PPA. No v5 physical run or signoff yet.**
The new MAC is intended to shorten the measured SS `c_d2 -> pair_q` cone.
It does not modify SRAM timing budgets or delete `rdata_q`.

| Stage | Registered work |
| --- | --- |
| 0 | Two independent 10×4 unsigned multiplies per 10×8 product |
| 1 | Recombine low/high partial products |
| 2–7 | One binary addition per level: 50 → 25 → 13 → 7 → 4 → 2 → 1 |
| External output stage | Round by +64, shift 7, saturate, enqueue output skid |

All pipeline state advances under the original shared `pipe_en`; valid resets
asynchronously and payload is masked until valid. Throughput remains one
4-pixel beat per enabled cycle; latency increases by **six enabled cycles**.
Legal coefficients are nonnegative and sum to 128, so every partial sum is
at most `1023*128=130944` and fits 17 bits. This bound does not apply to signed
CNN coefficients or arbitrary unnormalized FIR kernels.

The exact generator hashes the v4 source and replaces only the MAC/control
alignment segment. It refuses a changed baseline. Historical `rtl/img_filter.v`
is not edited; generated sources, generator and source hashes identify the
candidate unambiguously. Do not manually edit the generated top.

```bash
python3 experiments/fir_pipeline/build_variant.py work/fir-v5-generated
python3 experiments/fir_pipeline/run_verification.py --engine verilator \
  --verilator /path/to/verilator-5.x --suite full --output work/fir-v5-full
python3 experiments/fir_pipeline/run_verification.py --engine iverilog \
  --verilator /path/to/verilator-5.x --suite smoke --output work/fir-v5-fourstate
```

Each command has a timeout and writes exit codes, command lines, wall times,
source hashes and log hashes. MAC unit tests use four-state Icarus with random
stalls, two midstream resets, extreme values and single-weight stimuli,
and an intentionally corrupted output that must fail. Full Verilator frames
are **two-state** and must not be advertised as proving X handling.
Simulators have different `$random` streams; a 54-frame comparison count need
not equal the historical Icarus run. Compare each log with its own manifest.

Measured full compiled regression: **54 frames, 2,474,888 component checks,
0 errors**; PREP alignment 390,800 checks, all rotator shifts covered.
MAC test: 26,592 lane comparisons, 2 resets, 460 stall cycles; injected fault
detected; separate RTL lint passes. [Evidence](results/full/verification.json).
Four-state frame smoke also passed: **13 frames, 42,972 component checks,
0 errors**, including X-injected tail lanes and random backpressure; 18,350
PREP alignment checks. [Separate evidence](results/fourstate/verification.json).
It took 699 seconds of simulation locally. Its smaller configuration/shift
coverage must not be merged with the two-state full test into a claim of
full four-state coverage.

Yosys generic elaboration, `proc; opt; check -assert`, also passed with zero
latches. It counts **50,152 register bits in the MAC and 12,975 in the top**.
The substantial clock/register cost is an explicit tradeoff, not an area
improvement claim. No standard-cell mapping, clock-gate mapping, timing or
power was measured for this candidate. [Structural evidence](results/structure/structure.json).

```bash
python3 experiments/fir_pipeline/check_structure.py \
  --yosys "$ORFS_ROOT/tools/install/yosys/bin/yosys" --output work/fir-v5-structure
```

## Decision and physical gate

This trades additional register/clock load and latency for shorter arithmetic
cones. It is not yet evidence of reduced area, power, coefficient fanout or
SS 1 GHz closure. Shared coefficient nets may remain a physical hotspot.
Do not assume synthesis preserves identical replicated coefficient registers;
any future physical grouping needs netlist sink statistics and matched PPA.

Rejected for this experiment: removing SRAM capture flops (requires a new
external timing contract), unjustified multicycle exceptions, and reducing
uncertainty to obtain a green report. Original v4 remains the comparison.

**Gate:** receive and audit [real SRAM/clock budgets](../../docs/sram-interface-contract.md)
before a new final physical leg. Then synthesize under WC at 1 ns, inspect
area and worst paths before expensive routing, and ultimately reroute, extract
and check all supported PVT/RC views on the same new candidate. No final
mapped equivalence, SDF GLS, per-RC MMMC or physical signoff is claimed here.
