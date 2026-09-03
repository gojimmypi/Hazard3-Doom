# -----------------------------------------------------------------------------
# File:        core.mk
# Path:        bootloader/cores/usb/core.mk
#
# Project:     Hazard3-Doom
# Purpose:     Declare USB core RTL, dependencies, tests, and generated inputs.
#
# Original author(s):    Sylvain Munaut (smunaut)
#
# Upstream:    HAD2019 USB device core
# Upstream license: No file-level license notice was present in this
#                   imported upstream file; do not infer one here.
#
# This file contains third-party material and is not relicensed by
# Hazard3-Doom. Preserve its upstream history and provenance.
# See LICENSES/HAD2019-Bootloader-NOTICE.md for provenance and licensing.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

CORE := usb

DEPS_usb := misc

RTL_SRCS_usb := $(addprefix rtl/, \
	usb.v \
	usb_crc.v \
	usb_ep_buf.v \
	usb_ep_status.v \
	usb_phy.v \
	usb_rx_ll.v \
	usb_rx_pkt.v \
	usb_trans.v \
	usb_tx_ll.v \
	usb_tx_pkt.v \
)

PREREQ_usb := \
	$(ROOT)/cores/usb/rtl/usb_defs.vh \
	$(BUILD_TMP)/usb_trans_mc.hex \
	$(BUILD_TMP)/usb_ep_status.hex

TESTBENCHES_usb := \
	usb_ep_buf_tb \
	usb_tb \
	usb_tx_tb

$(BUILD_TMP)/usb_trans_mc.hex: $(ROOT)/cores/usb/utils/microcode.py
	$(ROOT)/cores/usb/utils/microcode.py > $@

$(BUILD_TMP)/usb_ep_status.hex: $(ROOT)/cores/usb/data/usb_ep_status.hex
	cp -a $< $@

include $(ROOT)/mk/core-magic.mk
