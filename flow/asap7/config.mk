export PLATFORM               = asap7
export DESIGN_NAME            = IMG_FILTER
export DESIGN_NICKNAME        = img_filter

# order matters: the macro definitions must be read first
export VERILOG_FILES          = $(DESIGN_HOME)/src/img_filter/img_filter_def.v \
                                $(DESIGN_HOME)/src/img_filter/img_filter.v
export SDC_FILE               = $(DESIGN_HOME)/$(PLATFORM)/img_filter/constraint.sdc

# 16873 top level port bits: leave room for pin placement
export CORE_UTILIZATION       = 22
export CORE_ASPECT_RATIO      = 1
export CORE_MARGIN            = 2
export PLACE_DENSITY          = 0.45

export SKIP_LAST_GASP  = 1
# v2: skid-buffered handshake removed the enable-fanout wall; let the flow
# run its normal repair, and infer ICG clock gates from the liberty
export INFER_CLKGATES = 1
