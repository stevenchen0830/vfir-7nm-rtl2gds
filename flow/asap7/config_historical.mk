include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))config.mk
export SDC_FILE := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))constraint_reported.sdc
