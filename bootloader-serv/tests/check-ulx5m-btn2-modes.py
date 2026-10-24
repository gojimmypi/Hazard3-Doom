#!/usr/bin/env python3
"""Read-only two-startup-mode hardware check for the ULX5M-GS BTN2 DFU image.

Run using native Windows Python, once per FPGA configuration. This tool
never invokes USB control OUT, JTAG, or flash erase/program commands.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import struct
import sys

VID, PID = 0x1d50, 0x614b
LED_ORDER = ("d7", "d6", "d5", "d4", "d3")


def verify_leds(mode, value):
    """Require explicit LED observations, not an unverified yes/no flag."""
    entries = value.lower().split(",")
    if len(entries) != len(LED_ORDER):
        raise ValueError("Expected D7,D6,D5,D4,D3 LED observations")
    observations = {}
    for entry in entries:
        if entry.count("=") != 1:
            raise ValueError("Malformed LED observation: {}".format(entry))
        led, state = (part.strip() for part in entry.split("="))
        if led not in LED_ORDER or led in observations:
            raise ValueError("Unknown or repeated LED: {}".format(led))
        observations[led] = state
    expected = {"d7": "blink", "d6": "on", "d5": "on",
                "d4": "on" if mode == "dfu" else "off",
                "d3": "off" if mode == "dfu" else "on"}
    if observations != expected:
        raise ValueError("LED state inconsistent with {} mode: {}. "
                         "Expected {}".format(mode, observations, expected))
    return observations


def bitstream_sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_fwt3_status(device, timeout_ms):
    # Vendor IN only. Do not send arm, DNLOAD, or DFU finish requests.
    raw = bytes(device.ctrl_transfer(0xc0, 0x5d, 0, 0, 24,
                                     timeout=timeout_ms))
    if len(raw) != 24 or raw[:4] != b"FWT3":
        raise ValueError("Unexpected FWT3 status signature or length")
    return struct.unpack("<5I", raw[4:])


def verify_mode(mode, device, timeout_ms):
    """Return status detail; never accept a partial or armed DFU as idle."""
    if mode == "normal":
        if device is not None:
            # Windows may retain a USB device after an unsuccessful FPGA
            # reconfiguration. A listed device is never a normal-mode PASS.
            try:
                status = read_fwt3_status(device, timeout_ms)
            except (OSError, ValueError) as exc:
                raise ValueError("1D50:614B is still listed, but the read-only "
                                 "FWT3 probe failed. USB host state is "
                                 "inconclusive; check FPGA heartbeat and "
                                 "re-enumeration before repeating") from exc
            raise ValueError("Live FWT3 still responds in normal mode: "
                             "{}".format(status))
        return {"usb": "absent"}
    if device is None:
        raise ValueError("1D50:614B is absent in DFU mode")
    status = read_fwt3_status(device, timeout_ms)
    if status != (0, 0, 0, 0, 0):
        raise ValueError("FWT3 not idle and disarmed: {}".format(status))
    return {"usb": "FWT3", "fwt3": list(status)}


def load_dfureport(path, expected_digest):
    with path.open("r", encoding="ascii") as source:
        report = json.load(source)
    if (report.get("format") != "ULX5M-BTN2-HARDWARE-V1" or
        report.get("mode") != "dfu" or report.get("result") != "PASS" or
        report.get("bitstream_sha256") != expected_digest or
        report.get("detail") != {"usb": "FWT3", "fwt3": [0, 0, 0, 0, 0]} or
        report.get("leds_confirmed") is not True):
        raise ValueError("Reference DFU report is not a matching passing run")


def make_report(mode, digest, detail, observed_leds):
    return {
        "format": "ULX5M-BTN2-HARDWARE-V1",
        "mode": mode,
        "bitstream_sha256": digest,
        "result": "PASS",
        "leds_confirmed": True,
        "observed_leds": observed_leds,
        "detail": detail,
        "utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }


def save_new_report(path, record):
    # O_EXCL prevents clobbering a previous hardware test or backup report.
    fd = os.open(str(path), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    with os.fdopen(fd, "w", encoding="ascii", newline="\n") as out:
        json.dump(record, out, indent=2, sort_keys=True)
        out.write("\n")
        out.flush()
        os.fsync(out.fileno())


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mode", choices=("dfu", "normal"), required=True)
    p.add_argument("--bitstream", required=True, type=Path)
    p.add_argument("--report", required=True, type=Path,
                   help="New, non-existing report filename")
    p.add_argument("--expected-sha256", required=True,
                   help="Expected SHA-256 of the SRAM bitstream")
    p.add_argument("--reference-report", type=Path,
                   help="Required in normal mode: earlier passing DFU report")
    p.add_argument("--leds", required=True,
                   help="Explicit observations: D7=blink,D6=on,D5=on,"
                        "D4=on,D3=off for DFU, or D4=off,D3=on for normal")
    p.add_argument("--timeout-ms", type=int, default=5000)
    args = p.parse_args(argv)
    if sys.platform != "win32":
        p.error("Hardware USB requires native Windows Python (not WSL)")
    try:
        observed_leds = verify_leds(args.mode, args.leds)
    except ValueError as exc:
        p.error(str(exc))
    if args.timeout_ms < 500:
        p.error("--timeout-ms must be at least 500")
    if (args.mode == "normal") != (args.reference_report is not None):
        p.error("--reference-report is required only for normal mode")
    if args.report.exists():
        p.error("Report already exists; refusing to overwrite")
    if len(args.expected_sha256) != 64 or any(
            ch not in "0123456789abcdef" for ch in args.expected_sha256):
        p.error("--expected-sha256 must be 64 lowercase hex digits")
    try:
        digest = bitstream_sha256(args.bitstream)
        if digest != args.expected_sha256:
            p.error("Bitstream SHA-256 does not match --expected-sha256")
        if args.reference_report is not None:
            load_dfureport(args.reference_report, digest)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        p.error(str(exc))

    # Require a working WinUSB backend before interpreting device absence.
    import usb.backend.libusb1
    import usb.core
    dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
    if not dll.is_file():
        p.error("libusb DLL missing: {}".format(dll))
    backend = usb.backend.libusb1.get_backend(find_library=lambda _: str(dll))
    if backend is None:
        p.error("libusb backend unavailable; cannot verify mode")
    device = usb.core.find(idVendor=VID, idProduct=PID, backend=backend)
    detail = verify_mode(args.mode, device, args.timeout_ms)
    record = make_report(args.mode, digest, detail, observed_leds)
    save_new_report(args.report, record)
    print("[PASS] BTN2 {} startup: {}; read-only check".format(
        args.mode, detail["usb"]))
    print("[REPORT] {}".format(args.report))
    if args.mode == "normal":
        print("[NOTE] Absence also depends on USB host/cable; keep the LED "
              "observation and prior DFU report with this result.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("[FAIL] {}: {}".format(type(exc).__name__, exc), file=sys.stderr)
        sys.exit(1)
