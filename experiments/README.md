# AI-related extensions

These experiments extend the FIR project; they do not inherit v4's frequency,
area or power. Each has runnable source, a bounded experiment and explicit
limits. Upstream CNN concepts and optimization techniques are acknowledged;
the project contribution is their implementation, verification and comparison.

## 1. Learned legal FIR coefficients

```bash
python3 -m pip install numpy
python3 experiments/learned_fir/train.py
```

Training learns a nonnegative symmetric 5-tap denoising filter by projected
gradient descent on a simplex. Pair weights and the center are quantized in
64 units so the expanded integer coefficients sum exactly to 128. Seeds for
12 training, 4 validation and 4 test frames are separate. Validation selects
the float parameters; test frames are not used for fitting or selection.

The synthetic benchmark compares identity, fixed binomial, fixed near-uniform, learned float and
learned integer filters using MSE/PSNR. The generated `coefficient_half` can be
fed directly into the original IMG_FILTER without changing RTL. Native UVM
also runs these coefficients through real bank traffic and compares against
the mathematical golden. This is a learned **linear filter**, not a CNN or
a natural-image quality claim. Results: [learned FIR JSON](learned_fir/results/results.json).

| Held-out synthetic data, seed 20260910 | PSNR (dB) |
| --- | ---: |
| Identity | 27.2310 |
| Fixed binomial `[8,32,48,32,8]` | 32.6524 |
| Fixed near-uniform `[26,25,26,25,26]` | 33.8568 |
| Learned floating-point | 33.8605 |
| Learned integer `[26,25,26,25,26]` | 33.8568 |

Quantization plus integer input/output rounding costs about 0.0036 dB here.
The learned integer result gains 1.2045 dB over binomial but **ties the
near-uniform baseline**; that baseline was added for comparison, not tuned
on the held-out images. No learning superiority over all fixed filters is
established. The coefficients also passed one 392-beat original-FIR UVM
frame; this verifies hardware compatibility, not image-task generalization.

## 2. Signed INT8 CNN convolution IP

**2026-09-11 update:** active RTL has three valid-aligned stages (products,
33-bit bias/accumulate, requantize) and bounded-width x/y counters. The exact
single-cycle baseline is retained in
[`cnn/history/int8_dw3x1_20260910.sv`](cnn/history/int8_dw3x1_20260910.sv).
The added pipeline changes latency, not the mathematical operator or
steady-state one-pixel/beat interface. Backpressure freezes all stages.

The strengthened suite uses different consecutive images, per-frame
weights/biases, midframe reset/restart and INT32 bias extrema:
**15 completed frames, 498 beats, 1,262 channel comparisons**. A Python test
also compares the narrowed rounding formula with the independent absolute-value
reference in 64,576 cases over QSHIFT=0..31. This is finite evidence, not
exhaustive 33-bit formal equivalence.

The first pipeline candidate completed CTS, DRT and RCX: BC setup +131.06 ps,
hold +1.53 ps, both TNS/counts 0, slew/cap/fanout/routing DRC 0; area
718.021 um². **TT/SS do not pass.** See the
[repair ledger](../docs/closure-progress.md),
[physical evidence](cnn/results/pipeline_20260911/physical/summary.json) and
[multi-PVT audit](cnn/results/pipeline_20260911/audit/matrix.json).
The narrow-counter follow-up must use its own measured results, not inherit
this PPA. Current regression output: [`cnn/results/final_20260911/`](cnn/results/final_20260911/).

The final lint-clean narrow-counter version now also completed the full flow:
BC setup **+170.86 ps**, hold **+0.149 ps**, setup/hold TNS and all applicable
timing/DRV/geometric DRC counts zero; area **673.071 um²**, vectorless power
**26.216 mW**. Hold margin is very small. TT setup is **-111.67 ps**, SS setup
**-629.96 ps** with 176/453 slew violations respectively: **not all-corner
closure**. [Final physical report](cnn/results/final_20260911/physical/summary.json)
and [PVT matrix](cnn/results/final_20260911/audit/matrix.json). No new SRAM,
LVS/EM or measured inference-energy claim is implied.

```bash
bash experiments/cnn/run_tests.sh
```

`cnn/rtl/int8_dw3x1.sv` implements a real synthesizable 3×1 **depthwise**
operator: independent signed INT8 weights per channel, INT32 bias, two rolling
line buffers, zero top/bottom padding, stride 1, saturating INT8 output and
optional ReLU. The ready/valid output remains stable under backpressure;
the final row is generated using a virtual zero row. Keep weights/biases
stable until the final output of a frame is accepted. Parameters require
WIDTH/HEIGHT/CHANNELS >=1, QSHIFT=0..31. Channels are parallel in this MVP;
there is no time-multiplexed channel scheduler yet.

Quantization uses zero_point=0 and a power-of-two scale; rounding is nearest
with ties away from zero. This differs from the original unsigned FIR's
`+64 >>7` rule. The reference and testbench exercise mixed signs, -128 weights,
large bias, saturation and stalls. The historical single-cycle baseline had four measured
bit-exact simulation evidence: [2-channel](cnn/results/c2/results.json),
[4-channel ReLU](cnn/results/c4_relu/results.json), [1x1/no shift](cnn/results/edge_1x1/results.json),
and [3-channel/QSHIFT31](cnn/results/edge_q31/results.json). Each ran two
identical consecutive frames and checked ten drain cycles for extra output;
the new suite above fixes that weak multi-frame stimulus.
Total: **8 frames, 270 pixel beats, 806 channel comparisons**, zero mismatches.

| Configuration | Buffer bits (structural) | MACs/output pixel | Measured simulation |
| --- | ---: | ---: | --- |
| C=2, W=8, H=8 | 256 | 6 | 128 beats, 236 cycles including stalls and drain |
| C=4, W=8, H=8, ReLU | 512 | 12 | 128 beats, 236 cycles including stalls and drain |

All channels of a pixel travel in one beat. With no stalls, after the first
row fill, the operator can produce one pixel per cycle; each frame also
needs W virtual-row flush cycles before the next frame is accepted. Logical
rolling-buffer traffic per ordinary interior pixel is 2C byte reads + 2C byte
writes. These counts do not imply inferred SRAMs or measured energy.

The historical single-cycle ORFS placement pilot was:

```bash
ORFS_ROOT=/path/to/ORFS FLOW_VARIANT=cnn_pilot_new bash experiments/cnn/flow/run_place.sh
```

| C=2 placement pilot, ASAP7 BC, 1 ns, 100/30 ps uncertainty | Result |
| --- | ---: |
| Standard-cell area | 782.713 µm² |
| Setup WS | **−268.924 ps — FAIL** |
| Hold WS, ideal-clock placement view | +5.53226 ps |
| Vectorless power (raw default activity) | 174.282 mW |

[Raw metrics, source hash and stage cost](cnn/results/placement/summary.json).
This is an unoptimized baseline, not a fast/low-power claim. Default activity
does not model frame-static weights/biases or a real workload; the raw power
estimate must **not** be advertised as CNN inference energy or compared directly
with v4 FIR power. No CTS/DRT/RCX was run for that baseline; the pipelined
successor above has routed evidence. The historical C=4 test also
changes ReLU and stimulus, so the two simulation rows are not a controlled
causal power/area comparison.

This first operator is not a full trained classifier, a 3×3 implementation,
or a completed MobileNet. Horizontal spatial filtering and 1×1 cross-channel
mixing remain extensions. An arbitrary 3×3 kernel is not exactly a rank-1
3×1/1×3 factorization. Task accuracy and workload energy have not been
measured; routed PPA is available only for the named pipeline candidates.
Buffer bits and MAC counts are structural
counts, not power estimates. For context: [MobileNet](https://arxiv.org/abs/1704.04861)
and [integer quantization](https://arxiv.org/abs/1712.05877).

## 3. ML-assisted EDA search

```bash
python3 experiments/eda_search/search.py --orfs-root "$ORFS_ROOT" \
  --design gcd --budget 4 --output experiments/eda_search/results_matched
```

This runs **real ORFS placement trials** on the small upstream ASAP7 `gcd`
smoke benchmark. It compares random selection with an online radial-basis
kernel-regression surrogate and distance-based exploration. Both get the
same first two trials and the same evaluation count. Core utilization and
placement density vary; corner and SDC do not. The objective combines
normalized area and setup penalty; vectorless power is also recorded.

The content cache includes design files, configuration, ORFS revision,
platform views, flow scripts/utilities, driver hash and OpenROAD/Yosys binaries
and versions. Cached evaluations charge the original trial runtime to
both algorithms. Equal evaluation count is **not** equal wall-clock budget;
the report records both. A four-trial seed is an integration pilot, not a
statistical demonstration that ML beats random search. Report ties or worse
results honestly. No best configuration is automatically applied to FIR.

The 2026-09-11 integrity fix restores exact original raw metrics bytes
(including no terminal newline); historical numerical observations are
unchanged. The measured driver is archived as
`eda_search/history/search_20260910.py`. New `search.py` writes raw bytes and
validates cache hashes and values before reuse. Offline
`tools/check_reproduction.py` now checks raw/cache/summary agreement.

Only placement is used here: hold/DRV/routing feasibility must gate later
stages. This pilot does not claim a measured FIR PPA improvement or GPU routing
acceleration. Before applying to expensive IMG_FILTER trials, add multiple
seeds, measured stage correlations and matched input/clock models.
| Published pilot, seed 42 | Evaluations | Best objective | Charged trial wall time |
| --- | ---: | ---: | ---: |
| Random | 4 | 0.0805971 | 61.10 s |
| RBF surrogate | 4 | 0.0805971 | 63.45 s |

They **tie**. The best point was already one of the common initial trials:
utilization 40%, density 0.45, area 44.6877 µm², setup WS −35.9094 ps,
vectorless power 1.27043 mW. It still **fails setup**; the ranking score is
not a feasibility certificate. Six unique physical trials were needed because
the two methods share initial points. This does not establish a speedup;
the slightly higher surrogate wall time is not statistically meaningful at
one seed. Content hashing/setup overhead is outside the reported trial time.
Timeout (300 s/trial by default) terminates only the owned trial process group,
preserving completed disk checkpoints and stopping the search for diagnosis.

ORFS [AutoTuner](https://openroad-flow-scripts.readthedocs.io/en/latest/user/InstructionsForAutoTuner.html)
is the upstream reference for a larger Ray-based implementation; the local
pilot deliberately has no Ray dependency. Results:
[comparison.json](eda_search/results_matched/comparison.json).

## What these experiments do not finish

The three routes now have executable initial experiments, not three completed
research programmes. Natural-image evaluation, a trained full CNN with
channel scheduling/accuracy measurement, and multi-seed, multi-fidelity FIR
EDA optimization remain future work. No new long FIR routing run or silent
SDC relaxation was used to manufacture an improvement.
