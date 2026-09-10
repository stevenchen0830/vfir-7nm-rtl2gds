include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))config.mk
export SETUP_SLACK_MARGIN = 30
export HOLD_SLACK_MARGIN = 20
export SLEW_MARGIN = 25
export TNS_END_PERCENT = 5
