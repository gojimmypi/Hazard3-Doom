VERILOG = \
rtl/top-$(MODEL)-passthru.v \
rtl/esp32_passthru.v \
rtl/i2c_bridge.v \

PASSTHRU_TOP_MOD ?= top_passthru

PASSTHRU_PIN_DEF ?= data/$(PASSTHRU_TOP_MOD)-$(BOARD).lpf

PROJ_PASSTHRU ?= passthru

DEVICE ?= 12k

BUILDDIR = build-tmp

$(BUILDDIR)/$(PROJ_PASSTHRU).json: $(VERILOG)
	mkdir -p $(BUILDDIR)
	yosys -p "synth_ecp5 -top top -json $@" $^

$(BUILDDIR)/$(PROJ_PASSTHRU).config: $(PASSTHRU_PIN_DEF) $(BUILDDIR)/$(PROJ_PASSTHRU).json
	nextpnr-ecp5 --${DEVICE} --package CABGA381 --timing-allow-fail --freq 25 --textcfg  $@ --json $(filter-out $<,$^) --lpf $(PASSTHRU_PIN_DEF)

$(BUILDDIR)/$(PROJ_PASSTHRU).bit: $(BUILDDIR)/$(PROJ_PASSTHRU).config
	ecppack --compress $^ $@

$(BUILDDIR)/$(PROJ_PASSTHRU).bit.gz: $(BUILDDIR)/$(PROJ_PASSTHRU).bit
	./gzip4k.py $< $@
