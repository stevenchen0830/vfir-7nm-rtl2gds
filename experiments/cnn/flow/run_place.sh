#!/usr/bin/env bash
set -euo pipefail
: "${ORFS_ROOT:?Set the pinned ORFS checkout}"
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PATH="$ORFS_ROOT/tools/install/OpenROAD/bin:$ORFS_ROOT/tools/install/yosys/bin:$PATH"
make -C "$ORFS_ROOT/flow" DESIGN_CONFIG="$here/config.mk" \
  FLOW_VARIANT="${FLOW_VARIANT:-cnn_pilot}" NUM_CORES=2 place
