#!/usr/bin/env bash
set -euo pipefail
: "${ORFS_ROOT:?Set the pinned ORFS checkout}"
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
python3 "$here/run_flow.py" --orfs-root "$ORFS_ROOT" \
  --variant "${FLOW_VARIANT:-cnn_pilot}" --stage place
