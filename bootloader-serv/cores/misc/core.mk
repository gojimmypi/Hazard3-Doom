# -----------------------------------------------------------------------------
# File:        core.mk
# Path:        bootloader/cores/misc/core.mk
#
# Project:     Hazard3-Doom
# Purpose:     Declare RTL sources and testbenches for the vendored miscellaneous utility core.
#
# Original author(s):    Sylvain Munaut (smunaut)
#
# Upstream:    HAD2019 misc utility core
# Upstream license: No file-level license notice was present in this
#                   imported upstream file; do not infer one here.
#
# This file contains third-party material and is not relicensed by
# Hazard3-Doom. Preserve its upstream history and provenance.
# See LICENSES/HAD2019-Bootloader-NOTICE.md for provenance and licensing.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

CORE := misc

RTL_SRCS_misc = $(addprefix rtl/, \
	delay.v \
	fifo_sync_ram.v \
	fifo_sync_shift.v \
	glitch_filter.v \
	ram_sdp.v \
	prims.v \
	pdm.v \
	pwm.v \
	uart_rx.v \
	uart_tx.v \
	uart_irda_rx.v \
	uart_irda_tx.v \
	uart_wb.v \
	xclk_strobe.v \
	xclk_wb.v \
)

TESTBENCHES_misc := \
	fifo_tb \
	pdm_tb \
	uart_tb \
	uart_irda_tb \
	$(NULL)

include $(ROOT)/mk/core-magic.mk
