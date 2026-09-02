#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${UVM_HOME:?Set UVM_HOME to the UVM source directory containing uvm_pkg.sv}"

build_dir="${UVM_BUILD_DIR:-$repo_root/work/uvm-verilator}"
mkdir -p "$build_dir"

verilator \
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
  "$repo_root/verification/uvm/img_filter_uvm_pkg.sv" \
  "$repo_root/rtl/img_filter.v" \
  "$repo_root/verification/uvm/tb_top.sv"

"$build_dir/obj_dir/Vtb_top" +UVM_TESTNAME=img_filter_smoke_test
