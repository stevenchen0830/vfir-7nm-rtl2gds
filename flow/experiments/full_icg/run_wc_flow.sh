#!/bin/bash
# Experiment A carrier: full RTL-to-GDS at the true slow corner with default
# clock-gate inference (30 ICGs). Produces results/asap7/img_filter/wc.
set -eu
ORFS_ROOT=${ORFS_ROOT:-/root/ORFS}
cd "$ORFS_ROOT/flow"
make DESIGN_CONFIG=./designs/asap7/img_filter/config.mk \
     CORNER=WC FLOW_VARIANT=wc \
     SKIP_INCREMENTAL_REPAIR=1 TNS_END_PERCENT=5
