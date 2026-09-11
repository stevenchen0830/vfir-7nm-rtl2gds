#!/usr/bin/env bash
set -euo pipefail
: "${ORFS_ROOT:?Set ORFS_ROOT to the pinned ORFS checkout}"
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PATH="$ORFS_ROOT/tools/install/OpenROAD/bin:$ORFS_ROOT/tools/install/yosys/bin:$PATH"
view=${1:-v4}; stage=${2:-synth}
case "$view" in v4) config=config_v4.mk;; historical) config=config_historical.mk;; *) echo 'view: v4 | historical' >&2; exit 2;; esac
case "$stage" in synth|floorplan|place|cts|route|finish) ;; *) echo 'stage: synth floorplan place cts route finish' >&2; exit 2;; esac
: "${FLOW_VARIANT:=reproduce_${view}}"
variant_root="$ORFS_ROOT/flow/results/asap7/img_filter/$FLOW_VARIANT"
if [[ ! "$FLOW_VARIANT" =~ ^[A-Za-z0-9_-]+$ ]]; then echo 'Invalid variant' >&2; exit 2; fi
stamp=$(mktemp)
trap 'rm -f "$stamp"' EXIT
VFIR_VIEW="$view" python3 "$repo/tools/flow_fingerprint.py" > "$stamp"
python3 "$repo/tools/checkpoint_guard.py" --stamp "$stamp" "$variant_root" \
  "$ORFS_ROOT/flow/logs/asap7/img_filter/$FLOW_VARIANT" \
  "$ORFS_ROOT/flow/reports/asap7/img_filter/$FLOW_VARIANT"
cd "$ORFS_ROOT/flow"
make DESIGN_CONFIG="$repo/flow/asap7/$config" \
     VERILOG_FILES="$repo/rtl/img_filter_def.v $repo/rtl/img_filter.v" \
     FLOW_VARIANT="$FLOW_VARIANT" CORNER="${CORNER:-BC}" NUM_CORES="${NUM_CORES:-4}" "$stage"
