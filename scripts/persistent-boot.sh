#!/bin/bash
# -----------------------------------------------------------------------------
# File:        publish-check.sh
# Path:        scripts/publish-check.sh
#
# Project:     Hazard3-Doom
# Purpose:     load Hazard3 Doom as persistent boot on ULX3S board
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
#
# SPDX-License-Identifier: Apache-2.0
#
# This software is provided under the terms of the applicable license.
# See LICENSES/Apache-2.0.txt for the complete license terms.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------

set -euo pipefail

echo "ULX3S fpga_ulx3s_85f-25MHz-640x480.bit loader only. See also flash-ulx3s-persistent.sh (TODO merge into one script)"


printf '\n'
printf 'WARNING: This operation will permanently modify the FPGA SPI flash.\n'
printf 'The existing persistent bootloader/configuration will be overwritten.\n'
printf 'Recovery may require JTAG programming.\n\n'

while true; do
    read -r -n 1 -p "Continue? [Y/n]: " answer
    printf '\n'

    case "${answer}" in
        [Yy])
            break
            ;;
        [Nn])
            echo "Aborted. No changes made."
            exit 0
            ;;
        *)
            echo "Please press Y to continue or N to abort."
            ;;
    esac
done

# Verify this script against the recorded inventory without blocking normal execution.
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/inventory.sh" \
    --check-file "${BASH_SOURCE[0]}" || true

./bin/openFPGALoader.exe \
  --board ulx3s \
  --usb-serial-num 120001 \
  --write-flash \
  --unprotect-flash \
  --verify \
  --offset 0 \
  "$(wslpath -w "$PWD/bin/fpga_ulx3s_85f-25MHz-640x480.bit")"
