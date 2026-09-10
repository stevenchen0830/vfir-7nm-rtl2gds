#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${UVM_HOME:?Set UVM_HOME to the UVM source directory containing uvm_pkg.sv}"

build_dir="${UVM_BUILD_DIR:-$repo_root/work/uvm-verilator}"
mkdir -p "$build_dir"

"${VERILATOR:-verilator}" \
  --binary --timing -j "${UVM_JOBS:-4}" \
  -Wno-fatal -Wno-TIMESCALEMOD \
  --top-module tb_top \
  --Mdir "$build_dir/obj_dir" \
  +define+UVM_NO_DPI \
  +incdir+"$UVM_HOME" \
  +incdir+"$repo_root/rtl" \
  +incdir+"$repo_root/verification/uvm" \
  "$UVM_HOME/uvm_pkg.sv" \
  "$repo_root/verification/uvm/img_filter_if.sv" \
  "$repo_root/verification/uvm/sram_model.sv" \
  "$repo_root/verification/uvm/img_filter_functional_pkg.sv" \
  "$repo_root/rtl/img_filter.v" \
  "$repo_root/verification/uvm/tb_top.sv"

for kernel in ${UVM_KERNELS:-1 3 7 49}; do
 for width in ${UVM_WIDTHS:-24 25 26 27}; do
  tag="k${kernel}_w${width}"
  python3 "$repo_root/verification/uvm/generate_vectors.py" "$build_dir/$tag.txt" --kernel "$kernel" --width "$width"
  "$build_dir/obj_dir/Vtb_top" +UVM_TESTNAME=img_filter_smoke_test \
    +VECTORS="$build_dir/$tag.txt" | tee "$build_dir/$tag.log"
  grep -q 'UVM FILTER PASSED' "$build_dir/$tag.log"
 done
done
if [[ -f "$repo_root/experiments/learned_fir/results/results.json" ]]; then
  python3 "$repo_root/verification/uvm/generate_vectors.py" "$build_dir/learned.txt" --kernel 5 \
    --coefficient-json "$repo_root/experiments/learned_fir/results/results.json"
  "$build_dir/obj_dir/Vtb_top" +VECTORS="$build_dir/learned.txt" | tee "$build_dir/learned.log"
  grep -q 'UVM FILTER PASSED' "$build_dir/learned.log"
fi
if [[ "${UVM_NEGATIVE_TESTS:-1}" == 1 ]]; then
  python3 "$repo_root/verification/uvm/generate_vectors.py" "$build_dir/negative.txt" --kernel 3
  for fault in FAULT_DATA FAULT_SRAM; do
    if "$build_dir/obj_dir/Vtb_top" +VECTORS="$build_dir/negative.txt" +"$fault" > "$build_dir/$fault.log" 2>&1; then
      echo "ERROR: $fault escaped verification" >&2; exit 1
    fi
    grep -q 'MISMATCH' "$build_dir/$fault.log"
    echo "NEGATIVE CONTROL DETECTED: $fault"
  done
fi
