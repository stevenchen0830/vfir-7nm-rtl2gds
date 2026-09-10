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
large bias, saturation and stalls. Four configurations currently have measured
bit-exact simulation evidence: [2-channel](cnn/results/c2/results.json),
[4-channel ReLU](cnn/results/c4_relu/results.json), [1x1/no shift](cnn/results/edge_1x1/results.json),
and [3-channel/QSHIFT31](cnn/results/edge_q31/results.json). Each runs two
consecutive frames and checks ten drain cycles for unexpected extra output.
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

An actual small ORFS placement pilot was also run:

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
with v4 FIR power. No CTS/DRT/RCX was run for this operator. The C=4 test also
changes ReLU and stimulus, so the two simulation rows are not a controlled
causal power/area comparison.

This first operator is not a full trained classifier, a 3×3 implementation,
or a completed MobileNet. Horizontal spatial filtering and 1×1 cross-channel
mixing remain extensions. An arbitrary 3×3 kernel is not exactly a rank-1
3×1/1×3 factorization. Task accuracy, routed PPA and workload energy have not
been measured for this new IP. Buffer bits and MAC counts are structural
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
