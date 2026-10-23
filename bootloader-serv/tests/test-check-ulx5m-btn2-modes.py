#!/usr/bin/env python3
"""Offline unit tests for the read-only ULX5M BTN2 hardware acceptance tool."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("check-ulx5m-btn2-modes.py")
spec = importlib.util.spec_from_file_location("btn2_mode_check", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DummyUSB:
    def __init__(self, payload):
        self.payload = payload
        self.calls = []

    def ctrl_transfer(self, request_type, request, value, index, length, timeout):
        self.calls.append((request_type, request, value, index, length))
        return self.payload


class Btn2ModeTests(unittest.TestCase):
    def test_read_only_dfu_pass(self):
        device = DummyUSB(b"FWT3" + b"\x00" * 20)
        self.assertEqual(module.verify_mode("dfu", device, 5000),
                         {"usb": "FWT3", "fwt3": [0] * 5})
        self.assertEqual(device.calls, [(0xc0, 0x5d, 0, 0, 24)])

    def test_non_idle_and_malformed_fail(self):
        for raw in (b"BAD!" + b"\x00" * 20,
                    b"FWT3" + b"\x00" * 19,
                    b"FWT3" + (1).to_bytes(4, "little") + b"\x00" * 16):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                module.verify_mode("dfu", DummyUSB(raw), 5000)

    def test_normal_must_have_no_usb(self):
        self.assertEqual(module.verify_mode("normal", None, 5000),
                         {"usb": "absent"})
        with self.assertRaisesRegex(ValueError, "Live FWT3"):
            module.verify_mode("normal", DummyUSB(b"FWT3" + b"\x00" * 20), 5000)
        with self.assertRaisesRegex(ValueError, "inconclusive"):
            module.verify_mode("normal", DummyUSB(b""), 5000)

    def test_normal_stale_usb_device_is_inconclusive(self):
        class StaleDevice:
            def ctrl_transfer(self, *args, **kwargs):
                raise OSError("No such device")

        with self.assertRaisesRegex(ValueError, "inconclusive"):
            module.verify_mode("normal", StaleDevice(), 5000)

    def test_led_observations_require_running_fpga(self):
        dfu = module.verify_leds("dfu", "D7=blink,D6=on,D5=on,D4=on,D3=off")
        normal = module.verify_leds("normal", "D7=blink,D6=on,D5=on,D4=off,D3=on")
        self.assertEqual(dfu["d4"], "on")
        self.assertEqual(normal["d3"], "on")
        for mode, leds in (("normal", "D7=off,D6=off,D5=off,D4=off,D3=off"),
                           ("normal", "D7=blink,D6=on,D5=on,D4=on,D3=off"),
                           ("dfu", "D7=blink,D6=on,D5=on,D4=off,D3=on"),
                           ("normal", "D7=blink,D6=on,D5=on,D4=off,D4=on")):
            with self.subTest(mode=mode, leds=leds), self.assertRaises(ValueError):
                module.verify_leds(mode, leds)

    def test_report_must_match_bitstream_and_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            d = Path(directory)
            image = d / "image.bit"
            image.write_bytes(b"gateware test")
            digest = module.bitstream_sha256(image)
            report = d / "dfu.json"
            record = module.make_report("dfu", digest,
                                        {"usb": "FWT3", "fwt3": [0] * 5},
                                        module.verify_leds("dfu", "D7=blink,D6=on,D5=on,D4=on,D3=off"))
            module.save_new_report(report, record)
            module.load_dfureport(report, digest)
            with self.assertRaises(FileExistsError):
                module.save_new_report(report, record)
            with self.assertRaises(ValueError):
                module.load_dfureport(report, "0" * 64)
            record["result"] = "FAIL"
            report.write_text(json.dumps(record), encoding="ascii")
            with self.assertRaises(ValueError):
                module.load_dfureport(report, digest)


if __name__ == "__main__":
    unittest.main(verbosity=2)
