#!/usr/bin/env python3
"""Host regression for isolated FWTN ROM, USB DFU, and readback protocol."""
import hashlib
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SOURCE = HERE / "diagnose-ulx5m-serv-dfu-hw-native.py"
SPEC = importlib.util.spec_from_file_location("native_hw", SOURCE)
HW = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HW)
BIT = ROOT / "build-ulx5m-gs" / "top_ulx5m_gs_normal_led.bit"


class Device:
    def __init__(self):
        self.memory = bytearray(b"\xff" * 0x400000)
        self.memory[:4096] = b"\x99" * 4096
        self.phase = 0
        self.received = b""
        self.writes = 0
        self.want_bytes = 0
        self.want_crc = 0
        self.bad_status = False
        self.flash_reads = 0

    def ctrl_transfer(self, typ, req, val, index, payload, timeout=None):
        if typ == 0xc0 and req == 0x5d:
            marker = b"FWT3" if self.bad_status else b"FWTN"
            return marker + struct.pack("<5I", self.phase, self.want_bytes,
                                       self.want_crc, len(self.received), 0)
        if typ == 0xc0 and req == 0x5a:
            return b"A251\x1f\x42\x16\x00"
        if typ == 0xc0 and req == 0x59:
            return b"STR1" + struct.pack("<IIHBBI", len(self.received),
                zlib.crc32(self.received) & 0xffffffff,
                (len(self.received) + 63) // 64, 2 if not self.received else 5,
                0, 0x200000)
        if typ == 0xc0 and req == 0x5b:
            self.flash_reads += 1
            address = (index << 16) | val
            return bytes(self.memory[address: address+payload])
        if typ == 0x40 and req == 0x5c:
            assert val == 1 and index == 0x2000 and payload[:4] == b"U5WN"
            self.want_bytes, self.want_crc, token = struct.unpack("<III", payload[4:])
            assert token == 0xc01d2041 and self.want_bytes == 3026
            self.phase = 1
            return len(payload)
        if typ == 0x21 and req == 1:
            assert self.phase == 1 and val == len(self.received) // 64
            if not self.writes:
                self.memory[HW.NATIVE:HW.NATIVE+HW.SECTOR] = b"\xff" * HW.SECTOR
            self.memory[HW.NATIVE+len(self.received):HW.NATIVE+len(self.received)+len(payload)] = payload
            self.received += bytes(payload)
            self.writes += 1
            return len(payload)
        if typ == 0xa1 and req == 3:
            return b"\x00\x00\x00\x00\x05\x00"
        if typ == 0x40 and req == 0x5e:
            assert len(self.received) == self.want_bytes
            assert zlib.crc32(self.received) & 0xffffffff == self.want_crc
            self.phase = 2
            return 0
        raise AssertionError("Unexpected USB command")


class Tests(unittest.TestCase):
    def test_image_pinned(self):
        self.assertEqual(len(HW.verify_app(BIT)), 3026)

    def test_fwt3_not_accepted(self):
        dev = Device()
        dev.bad_status = True
        with self.assertRaisesRegex(ValueError, "FWTN"):
            HW.device_preflight(dev, 5000, None)
        self.assertEqual(dev.writes, 0)

    def test_full_usb_transaction_only_native_sector(self):
        dev = Device()
        before = bytes(dev.memory[:HW.NATIVE])
        app = HW.verify_app(BIT)
        with tempfile.TemporaryDirectory() as d:
            report = Path(d)/"native-report.json"
            record = {"phase":"PRE_ARM"}
            HW.report_save(report, record)
            HW.program(dev, app, bytes(dev.memory), 5000, report, record)
            self.assertIn("VERIFIED_NATIVE_SECTOR_ONLY", report.read_text())
        self.assertEqual(bytes(dev.memory[:HW.NATIVE]), before)
        self.assertEqual(bytes(dev.memory[HW.NATIVE:HW.NATIVE+3026]), app)
        self.assertEqual(dev.phase, 2)
        self.assertEqual(dev.writes, 48)

    def test_refuse_non_erased_candidate(self):
        dev = Device()
        dev.memory[HW.NATIVE] = 0
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)/"report.json"
            HW.report_save(path, {})
            with self.assertRaises(RuntimeError):
                HW.program(dev, HW.verify_app(BIT), bytes(dev.memory), 5000, path, {})
        self.assertEqual(dev.writes, 0)

    def test_backup_double_copy_required(self):
        with tempfile.TemporaryDirectory() as d:
            a,b = Path(d)/"a", Path(d)/"b"
            a.write_bytes(b"\xff" * 0x400000)
            b.write_bytes(b"\xff" * 0x400000)
            with self.assertRaisesRegex(ValueError,"backup"):
                HW.verify_backups(a,b)
            b.write_bytes(b"\x00" * 0x400000)
            with self.assertRaisesRegex(ValueError,"backup"):
                HW.verify_backups(a,b)

    def test_refuse_reuse_report(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"report.json"
            HW.report_save(p,{"new":True})
            with self.assertRaises(FileExistsError):
                HW.report_save(p,{"new":False})
            self.assertIn("true",p.read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
