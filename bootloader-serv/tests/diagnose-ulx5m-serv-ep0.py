#!/usr/bin/env python3
"""Windows-only, read-only ULX5M SERV EP0 stress test (EPS1, 16-byte pages).

No WSL device access, DFU, flash programming or device reset commands.
"""
import argparse
import struct
import sys
import time
from pathlib import Path

SHORT_REQ = 0x54
MAGIC = 0x31535045  # EPS1
STATES = ("IDLE", "DATA_IN", "DATA_OUT", "STATUS_DONE_OUT",
          "STATUS_DONE_IN", "STALL")
BD_STATE = {0x0000: "NONE", 0x4000: "RDY_DATA", 0x6000: "RDY_STALL",
            0x8000: "DONE_OK", 0xa000: "DONE_ERR"}
FIELDS = ("setup_ok", "in_ok", "status_out_ok", "setup_err", "in_err",
          "out_err", "stalls", "setup_busy", "unexpected_in",
          "unexpected_out", "bad_status_len")
TRACE_FIELDS = ("trace_signature", "ep0_in_tokens", "ep0_data_start",
                "ep0_data_done", "ep0_host_ack", "ep0_nak_sent",
                "ep0_stall_sent", "rx_errors_context", "last_data_len",
                "last_tx_pid", "ack_window_sync",
                "ack_pid_valid", "ack_window_eop", "ack_rx_error",
                "ack_timeout", "ack_bd_done", "last_ack_result",
                "ack_line_changes")
TRACE_MAGIC = 0xe017


def decode_page(data):
    if len(data) != 16:
        raise ValueError("EPS1 response was {} bytes (expected 16)".format(len(data)))
    words = struct.unpack("<4I", data)
    if words[0] != MAGIC:
        raise ValueError("Unknown diagnostic magic: " + data[:4].hex())
    return words


def decode_snapshot(pages):
    if 0 not in pages:
        raise ValueError("Missing pre-SETUP state page")
    meta, inn, out = pages[0][1:4]
    result = {
        "version": meta & 0xff,
        "before_state": (meta >> 8) & 0xff,
        "before_request": (meta >> 16) & 0xff,
        "bus_resets": (meta >> 24) & 0xff,
        "before_in_bd": inn,
        "before_out_bd": out,
    }
    values = []
    for page in (1, 2, 3, 4):
        if page in pages:
            values.extend(pages[page][1:4])
        else:
            values.extend([None, None, None])
    result.update(zip(FIELDS, values[:len(FIELDS)]))
    trace_values = []
    for page in range(5, 11):
        if page in pages:
            trace_values.extend(pages[page][1:4])
        else:
            trace_values.extend([None, None, None])
    result.update(zip(TRACE_FIELDS, trace_values[:len(TRACE_FIELDS)]))
    return result


def describe_bd(value):
    return "0x{:08x} {} len={}{}".format(
        value, BD_STATE.get(value & 0xe000, "unknown"), value & 0x3ff,
        " SETUP" if value & 0x1000 else "")


def show_snapshot(label, snap, baseline=None):
    state = snap["before_state"]
    name = STATES[state] if state < len(STATES) else "UNKNOWN"
    print("[{}] latched prior state={} ({}) previous bRequest=0x{:02x} resets={}".format(
        label, state, name, snap["before_request"], snap["bus_resets"]))
    print("[{}] IN BD:  {}".format(label, describe_bd(snap["before_in_bd"])))
    print("[{}] OUT BD: {}".format(label, describe_bd(snap["before_out_bd"])))
    for field in FIELDS:
        value = snap[field]
        if value is None:
            continue
        delta = ""
        if baseline and baseline[field] is not None:
            delta = " (delta {:+d})".format(value - baseline[field])
        print("  {:<19} {:>8}{}".format(field, value, delta))
    if snap.get("trace_signature") != TRACE_MAGIC:
        print("  [WARNING] Missing v16f ACK trace signature (0xe017); "
              "verify v16f RTL and firmware are loaded")
        return
    print("  -- EP0 hardware trace, latched before diagnostic response --")
    for field in TRACE_FIELDS[1:]:
        value = snap[field]
        if value is None:
            continue
        delta = ""
        if baseline and baseline.get("trace_signature") == TRACE_MAGIC:
            before = baseline.get(field)
            if before is not None and field not in (
                    "last_data_len", "last_tx_pid", "last_ack_result"):
                delta = " (delta +{})".format((value - before) & 0xffff)
        if field == "last_ack_result":
            flags = ("sync", "ack_pid", "eop", "rx_error", "ack_ok",
                     "timeout", "superseded", "other_packet", "line_change")
            labels = [name for bit, name in enumerate(flags) if value & (1 << bit)]
            print("  {:<19} 0x{:04x} [{}]".format(field, value,
                                                    ", ".join(labels) or "none"))
        else:
            print("  {:<19} {:>8}{}".format(field, value, delta))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rounds", type=int, default=256)
    parser.add_argument("--delay-ms", type=float, default=100)
    parser.add_argument("--timeout-ms", type=int, default=5000)
    parser.add_argument("--stats-only", action="store_true")
    args = parser.parse_args()
    if args.rounds <= 0 or args.delay_ms < 0 or args.timeout_ms <= 0:
        parser.error("rounds and timeout must be positive; delay must be nonnegative")
    if sys.platform != "win32":
        parser.error("Run in native Windows PowerShell; WSL cannot access the ULX5M USB device")

    try:
        import usb.core
        import usb.backend.libusb1
    except ImportError as exc:
        parser.error("PyUSB missing: " + str(exc))

    dll = Path(__file__).resolve().parents[2] / "bin" / "libusb-1.0.dll"
    if not dll.is_file():
        parser.error("Missing libusb DLL: " + str(dll))
    backend = usb.backend.libusb1.get_backend(find_library=lambda _: str(dll))
    if backend is None:
        parser.error("Unable to load Windows libusb backend")
    dev = usb.core.find(idVendor=0x1d50, idProduct=0x614b, backend=backend)
    if dev is None:
        parser.error("ULX5M USB device 1D50:614B not found")

    def get_page(page):
        data = bytes(dev.ctrl_transfer(0xc0, SHORT_REQ, page, 0, 16,
                                       timeout=args.timeout_ms))
        return decode_page(data)

    def read_snapshot():
        pages = {}
        # Capture page 0 first; repeats preserve the original non-diag snapshot.
        for attempt in range(1, 4):
            try:
                pages[0] = get_page(0)
                break
            except Exception as exc:
                print("[DIAG] page=0 attempt={} failed: {}".format(attempt, exc), flush=True)
                time.sleep(0.5)
        if 0 not in pages:
            return None
        # Other pages contain monotonic counters; optional if the bus is unstable.
        for page in range(1, 11):
            try:
                pages[page] = get_page(page)
            except Exception as exc:
                print("[DIAG] page={} unavailable: {}".format(page, exc), flush=True)
            time.sleep(0.1)
        return decode_snapshot(pages)

    baseline = read_snapshot()
    if baseline is None:
        print("[ERROR] no EPS1 diagnostic page; ensure v16f is loaded")
        return 2
    show_snapshot("BASELINE", baseline)
    if baseline.get("trace_signature") != TRACE_MAGIC:
        print("[ERROR] v16f ACK trace not available; load the v16f bitstream")
        return 2
    if args.stats_only:
        return 0

    completed = 0
    for round_no in range(1, args.rounds + 1):
        for length in (18, 8, 16):
            try:
                data = bytes(dev.ctrl_transfer(0x80, 0x06, 0x0100, 0,
                                               length, timeout=args.timeout_ms))
                if len(data) != length or data[:2] != b"\x12\x01":
                    raise RuntimeError("Invalid descriptor: " + data.hex())
                completed += 1
            except Exception as exc:
                print("[FAIL] round={} length={} completed={}: {}".format(
                    round_no, length, completed, exc), flush=True)
                snap = read_snapshot()
                if snap is None:
                    print("[WARNING] diagnostic EP0 queries also failed")
                else:
                    show_snapshot("AFTER FAILURE", snap, baseline)
                return 1
            time.sleep(args.delay_ms / 1000.0)
        if round_no % 32 == 0:
            print("[OK] {} rounds, {} requests".format(round_no, completed), flush=True)

    print("[PASS] {} descriptor requests".format(completed))
    snap = read_snapshot()
    if snap:
        show_snapshot("END", snap, baseline)
    return 0


if __name__ == "__main__":
    sys.exit(main())
