#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo"
out=${1:-work/cnn-suite}
python3 experiments/cnn/test_cnn.py --channels 2 --output "$out/c2"
python3 experiments/cnn/test_cnn.py --channels 4 --relu 1 --seed 42 --output "$out/c4_relu"
python3 experiments/cnn/test_cnn.py --channels 1 --width 1 --height 1 --qshift 0 --seed 5 --output "$out/edge_1x1"
python3 experiments/cnn/test_cnn.py --channels 3 --width 3 --height 2 --qshift 31 --seed 100 --output "$out/edge_q31"
python3 experiments/cnn/test_cnn.py --channels 2 --frames 3 --reset-midframe --seed 11 --output "$out/reset_restart"
python3 experiments/cnn/test_cnn.py --channels 2 --width 3 --height 3 --qshift 31 --bias-extremes --output "$out/bias_extremes_q31"
python3 experiments/cnn/test_cnn.py --channels 2 --width 3 --height 3 --qshift 0 --bias-extremes --output "$out/bias_extremes_q0"
