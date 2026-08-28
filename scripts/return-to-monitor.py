#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File:        return-to-monitor.py
# Path:        scripts/return-to-monitor.py
#
# Project:     Hazard3-Doom
# Purpose:     Send Ctrl-X over UART to stop Doom and return control to the
#              resident monitor.
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

"""Send Ctrl-X to a running Hazard3-Doom instance and release the UART."""

from __future__ import annotations

import argparse
import time

import serial


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Return running Hazard3-Doom to the monitor with Ctrl-X."
    )
    parser.add_argument("--port", default="/dev/ttyS7")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument(
        "--wait",
        type=float,
        default=0.35,
        help="seconds to wait for monitor output after Ctrl-X (default: 0.35)",
    )
    args = parser.parse_args()

    print(f"Opening {args.port} at {args.baud}")
    with serial.Serial(args.port, args.baud, timeout=0.15) as uart:
        print("Sending Ctrl-X (0x18)...")
        uart.write(b"\x18")
        uart.flush()
        deadline = time.monotonic() + max(args.wait, 0.0)
        chunks: list[bytes] = []
        while time.monotonic() < deadline:
            data = uart.read(4096)
            if data:
                chunks.append(data)
            else:
                time.sleep(0.02)

    if chunks:
        print("--- UART response ---")
        print(b"".join(chunks).decode("ascii", errors="replace"), end="")
        print("--- end response ---")
    else:
        print("No UART response received; Ctrl-X was still transmitted.")
    print("UART released.")


if __name__ == "__main__":
    main()
