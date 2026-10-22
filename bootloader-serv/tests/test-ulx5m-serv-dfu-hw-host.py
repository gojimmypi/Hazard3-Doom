#!/usr/bin/env python3
"""Native-host mocks for experimental one-sector USB writer and JTAG restorer."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

HERE = Path(__file__).resolve().parent

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

host = load("dfu_hw_usb_probe", HERE / "diagnose-ulx5m-serv-dfu-hw-test.py")
restore = load("dfu_hw_restore", HERE / "restore-ulx5m-serv-candidate-sector.py")

class Device:
    def __init__(self):
        self.flash = bytearray(b"\xff" * 4096)
        self.phase = 0
        self.count = 0
        self.expected_crc = 0
        self.data = bytearray()
        self.armed = False

    def ctrl_transfer(self, direction, req, value, index, data_or_length, timeout=15000):
        if direction == 0xc0 and req == 0x5d:
            return b"FWT1" + struct.pack("<5I", self.phase, self.count,
                                           self.expected_crc, len(self.data), 0)
        if direction == 0xc0 and req == 0x5a:
            return b"A251\x1f\x42\x16\x00"
        if direction == 0xc0 and req == 0x59:
            return b"STR1" + bytes(10) + b"\x02\x00" + struct.pack("<I", 0x200000)
        if direction == 0xc0 and req == 0x5b:
            addr = (index << 16) | value
            return self.flash[addr - host.CANDIDATE:addr - host.CANDIDATE + data_or_length]
        if direction == 0x40 and req == 0x5c:
            magic, self.count, self.expected_crc, token = struct.unpack("<4sIII", bytes(data_or_length))
            assert magic == b"U5W1" and token == 0xc01d2026
            self.armed = True
            self.phase = 1
            return 16
        if direction == 0x21 and req == 1:
            assert self.armed and not self.data
            self.data.extend(data_or_length)
            return len(data_or_length)
        if direction == 0xa1 and req == 3:
            return bytes([0, 0, 0, 0, 5, 0])
        if direction == 0x40 and req == 0x5e:
            assert zlib.crc32(self.data) & 0xffffffff == self.expected_crc
            self.flash[:len(self.data)] = self.data
            self.phase = 2
            return 0
        raise AssertionError((direction, req))

class Tests(unittest.TestCase):
    def test_read_only_status(self):
        self.assertEqual(host.read_status(Device(), 1000), (0, 0, 0, 0, 0))

    def test_host_first_page(self):
        backup = bytes(b"\xff" * 0x400000)
        device = Device()
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "new.json"
            record = {"phase": "preflight_pending"}
            host.write_first_block(device, backup, 1000, record, report)
            self.assertEqual(device.flash[:64], host.payload())
            self.assertTrue(all(x == 255 for x in device.flash[64:]))
            self.assertEqual(device.phase, 2)
            self.assertEqual(record["phase"], "usb_candidate_verified_restore_required")

    def test_missing_explicit_ack(self):
        self.assertNotEqual(host.ACK, "")
        self.assertNotEqual(host.ACK, restore.ACK)

    def test_candidate_restore_mock(self):
        backup = b"\x55" * restore.TARGET + b"\xff" * 4096 + b"\x99" * (0x400000-restore.TARGET-4096)
        live = bytearray(backup)
        live[restore.TARGET:restore.TARGET+64] = host.payload()
        previous = (restore.qual.detect, restore.qual.read_region, restore.qual.call)
        calls = []
        try:
            restore.qual.detect = lambda loader, freq: None
            restore.qual.read_region = lambda loader, freq, offset, size: bytes(live[offset:offset+size])
            def mock_call(cmd, timeout=180):
                self.assertEqual(cmd[-2], str(restore.TARGET))
                live[restore.TARGET:restore.TARGET+4096] = Path(cmd[-1]).read_bytes()
                calls.append(cmd)
                return "ok"
            restore.qual.call = mock_call
            with tempfile.TemporaryDirectory() as tmp:
                blob = Path(tmp) / "original-200000.bin"
                blob.write_bytes(backup[restore.TARGET:restore.TARGET+4096])
                self.assertEqual(restore.execute(Path("ignored"), 1000, backup, blob),
                                 "restored_and_verified")
                self.assertEqual(bytes(live), backup)
                self.assertEqual(len(calls), 1)
        finally:
            restore.qual.detect, restore.qual.read_region, restore.qual.call = previous

    def test_restore_refuses_unexpected_region_changes(self):
        backup = b"\xff" * 0x400000
        live = bytearray(backup)
        live[0x180000] = 0x00
        previous = (restore.qual.detect, restore.qual.read_region, restore.qual.call)
        try:
            restore.qual.detect = lambda *_: None
            restore.qual.read_region = lambda loader, freq, offset, size: bytes(live[offset:offset+size])
            restore.qual.call = lambda *_a, **_kw: self.fail("No restore write allowed")
            with tempfile.TemporaryDirectory() as tmp:
                blob = Path(tmp) / "original-200000.bin"
                blob.write_bytes(b"\xff" * 4096)
                with self.assertRaisesRegex(ValueError, "Unexpected changes outside"):
                    restore.execute(Path("ignored"), 1000, backup, blob)
        finally:
            restore.qual.detect, restore.qual.read_region, restore.qual.call = previous

if __name__ == "__main__":
    unittest.main(verbosity=2)
