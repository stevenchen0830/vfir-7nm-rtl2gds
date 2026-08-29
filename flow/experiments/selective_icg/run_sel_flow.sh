#!/bin/bash
# Experiment B carrier: apply the clockgate -min_net_size hook (see
# synth_hook.patch, a 3-line addition to ORFS flow/scripts/synth.tcl), then
# run the WC flow with gating restricted to register groups of >= 2000 FFs
# (keeps rdata_q + the MAC pipe; ICG count 30 -> 2).
set -eu
ORFS_ROOT=${ORFS_ROOT:-/root/ORFS}
export CLKGATE_MIN_NET_SIZE=${CLKGATE_MIN_NET_SIZE:-2000}
grep -q CLKGATE_MIN_NET_SIZE "$ORFS_ROOT/flow/scripts/synth.tcl" || {
  echo "synth.tcl hook missing - apply synth_hook.patch first"; exit 1; }
cd "$ORFS_ROOT/flow"
make DESIGN_CONFIG=./designs/asap7/img_filter/config.mk \
     CORNER=WC FLOW_VARIANT=sel \
     SKIP_INCREMENTAL_REPAIR=1 TNS_END_PERCENT=5
