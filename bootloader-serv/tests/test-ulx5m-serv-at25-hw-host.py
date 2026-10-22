#!/usr/bin/env python3
"""Host-only PyUSB mock tests for the read-only A251/MMIO comparison."""
import importlib.util
import unittest
from pathlib import Path

PATH = Path(__file__).with_name("diagnose-ulx5m-serv-at25-hw.py")
spec = importlib.util.spec_from_file_location("at25_hardware_diagnostic", PATH)
diag = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diag)


class FakeUSB:
    def __init__(self, bad_address=None, bad_id=False, busy=False):
        self.calls = []
        self.bad_address = bad_address
        self.bad_id = bad_id
        self.busy = busy

    def ctrl_transfer(self, direction, request, value, index, payload, timeout):
        self.calls.append((direction, request, value, index, payload))
        if request == diag.STATUS_REQ:
            return b"A251" + (b"\x00\x00\x00" if self.bad_id else
                              diag.EXPECTED_ID) + (b"\x01" if self.busy else b"\x1c")
        address = value | (index << 16)
        data = bytes((address + i) & 0xff for i in range(payload))
        if request == diag.NEW_READ_REQ and address == self.bad_address:
            data = bytes([data[0] ^ 0xff]) + data[1:]
        return data


class HardwareReadTests(unittest.TestCase):
    def test_matching_reads_only(self):
        dev = FakeUSB()
        diag.compare(dev, report=lambda _: None)
        self.assertEqual(len(dev.calls), 1 + len(diag.SAMPLES) * 2)
        self.assertEqual({c[0] for c in dev.calls}, {0xc0})
        self.assertEqual({c[1] for c in dev.calls}, {0x52, 0x5a, 0x5b})

    def test_bad_flash_id_rejected_before_reads(self):
        dev = FakeUSB(bad_id=True)
        with self.assertRaises(ValueError):
            diag.compare(dev, report=lambda _: None)
        self.assertEqual(len(dev.calls), 1)

    def test_busy_rejected_before_reads(self):
        dev = FakeUSB(busy=True)
        with self.assertRaises(RuntimeError):
            diag.compare(dev, report=lambda _: None)
        self.assertEqual(len(dev.calls), 1)

    def test_read_mismatch_located(self):
        dev = FakeUSB(bad_address=0x13b000)
        with self.assertRaisesRegex(RuntimeError, "0x13b000"):
            diag.compare(dev, report=lambda _: None)

    def test_backup_matches_and_corruption_fails(self):
        image = bytes(i & 0xff for i in range(diag.FLASH_BYTES))
        diag.compare(FakeUSB(), backup=image, report=lambda _: None)
        broken = bytearray(image)
        broken[0x100] ^= 1
        with self.assertRaisesRegex(RuntimeError, "0x000100"):
            diag.compare(FakeUSB(), backup=broken, report=lambda _: None)

    def test_range_guard(self):
        dev = FakeUSB()
        with self.assertRaises(ValueError):
            diag.read(dev, 0x5b, 0x3fffff, 32, 1000)
        self.assertEqual(dev.calls, [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
