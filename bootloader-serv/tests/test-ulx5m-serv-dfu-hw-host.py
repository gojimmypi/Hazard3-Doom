#!/usr/bin/env python3
"""Native-host mocks for experimental one-sector USB writer and JTAG restorer."""
import importlib.util
import json
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
    def __init__(self, fail_after=None, corrupt_page=False):
        self.flash = bytearray(b"\xff" * 4096)
        self.phase = 0
        self.count = 0
        self.expected_crc = 0
        self.data = bytearray()
        self.armed = False
        self.block_count = 0
        self.finish_count = 0
        self.fail_after = fail_after
        self.corrupt_page = corrupt_page

    def ctrl_transfer(self, direction, req, value, index, data_or_length, timeout=15000):
        if direction == 0xc0 and req == 0x5d:
            return b"FWT1" + struct.pack("<5I", self.phase, self.count,
                                            self.expected_crc, len(self.data), 0)
        if direction == 0xc0 and req == 0x5a:
            return b"A251\x1f\x42\x16\x00"
        if direction == 0xc0 and req == 0x59:
            return b"STR1" + struct.pack("<IIHBBI", len(self.data),
                      zlib.crc32(self.data) & 0xffffffff, self.block_count,
                      5 if self.block_count else 2, 0, 0x200000)
        if direction == 0xc0 and req == 0x5b:
            addr = (index << 16) | value
            return self.flash[addr - host.CANDIDATE:addr - host.CANDIDATE + data_or_length]
        if direction == 0x40 and req == 0x5c:
            magic, self.count, self.expected_crc, token = struct.unpack("<4sIII", bytes(data_or_length))
            assert magic == b"U5W1" and token == 0xc01d2026
            assert self.count in (64, 512, 4096) and not self.armed
            self.armed = True
            self.phase = 1
            return 16
        if direction == 0x21 and req == 1:
            assert self.armed and self.phase == 1
            assert value == self.block_count and index == 0
            assert len(data_or_length) == 64
            if self.fail_after is not None and self.block_count == self.fail_after:
                raise RuntimeError("Injected USB transfer loss")
            self.data.extend(data_or_length)
            self.block_count += 1
            return len(data_or_length)
        if direction == 0xa1 and req == 3:
            return bytes([0, 0, 0, 0, 5, 0])
        if direction == 0x40 and req == 0x5e:
            assert len(self.data) == self.count
            assert zlib.crc32(self.data) & 0xffffffff == self.expected_crc
            self.flash[:len(self.data)] = self.data
            if self.corrupt_page:
                self.flash[256] ^= 1
            self.phase = 2
            self.finish_count += 1
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
            self.assertEqual(device.block_count, 1)
            self.assertEqual(device.finish_count, 1)
            self.assertEqual(record["phase"], "usb_candidate_verified_restore_required")
            self.assertEqual(record["payload_bytes"], 64)

    def test_complete_512_and_4096(self):
        backup = bytes(b"\xff" * 0x400000)
        for length in (512, 4096):
            with self.subTest(length=length), tempfile.TemporaryDirectory() as tmp:
                device = Device()
                report = Path(tmp) / "new.json"
                record = {"phase": "preflight_pending"}
                host.write_blocks(device, backup, 1000, length, record, report)
                self.assertEqual(device.flash[:length], host.payload(length))
                self.assertEqual(device.flash[length:], b"\xff" * (4096-length))
                self.assertEqual(device.block_count, length // 64)
                self.assertEqual(device.finish_count, 1)
                self.assertEqual(record["blocks_completed"], length // 64)
                self.assertEqual(record["payload_bytes"], length)
                self.assertEqual(record["phase"], "usb_candidate_verified_restore_required")

    def test_interrupted_transfer_is_not_retried(self):
        backup = bytes(b"\xff" * 0x400000)
        device = Device(fail_after=4)
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "new.json"
            record = {"phase": "preflight_pending"}
            with self.assertRaisesRegex(RuntimeError, "Injected USB transfer loss"):
                host.write_blocks(device, backup, 1000, 512, record, report)
            self.assertEqual(device.block_count, 4)
            self.assertEqual(device.finish_count, 0)
            self.assertEqual(record["blocks_completed"], 4)
            self.assertEqual(record["phase"], "dfu_blocks_in_progress")

    def test_independent_readback_mismatch(self):
        backup = bytes(b"\xff" * 0x400000)
        with self.assertRaisesRegex(RuntimeError, "Candidate flash verification failed"):
            host.write_blocks(Device(corrupt_page=True), backup, 1000, 512)

    def test_unapproved_size_rejected_before_arm(self):
        for length in (0, 63, 65, 4097, 0x200000):
            with self.subTest(length=length), self.assertRaises(ValueError):
                host.payload(length)

    def test_jtag_report_matches_multiblock_pattern(self):
        backup = b"\xff" * 0x400000
        for length in (512, 4096):
            with self.subTest(length=length), tempfile.TemporaryDirectory() as tmp:
                data = host.payload(length)
                record = {"format": "ULX5M-DFU-PHYSICAL-4K-V1",
                          "backup_sha256": host.FACTORY_SHA,
                          "target": restore.TARGET,
                          "phase": "usb_candidate_verified_restore_required",
                          "payload_bytes": length,
                          "payload_crc32": "{:08x}".format(zlib.crc32(data) & 0xffffffff),
                          "blocks_completed": length // 64}
                report = Path(tmp) / "write.json"
                report.write_text(json.dumps(record), encoding="ascii")
                expected = restore.expected_sector_from_report(report, host.FACTORY_SHA)
                self.assertEqual(expected, data + b"\xff" * (4096-length))
                live = bytearray(backup)
                live[restore.TARGET:restore.TARGET + 4096] = expected
                previous = (restore.qual.detect, restore.qual.read_region)
                try:
                    restore.qual.detect = lambda *_: None
                    restore.qual.read_region = lambda loader, freq, offset, size: bytes(live[offset:offset+size])
                    self.assertEqual(restore.execute(Path("ignored"), 1000, backup,
                                                     expected_sector=expected),
                                     "read_only_verified_candidate_pattern")
                    live[restore.TARGET + length // 2] ^= 1
                    with self.assertRaisesRegex(ValueError, "independent JTAG candidate"):
                        restore.execute(Path("ignored"), 1000, backup,
                                        expected_sector=expected)
                finally:
                    restore.qual.detect, restore.qual.read_region = previous

    def test_jtag_report_refuses_incomplete_or_wrong_crc(self):
        length = 512
        data = host.payload(length)
        record = {"format": "ULX5M-DFU-PHYSICAL-4K-V1",
                  "backup_sha256": host.FACTORY_SHA,
                  "target": restore.TARGET,
                  "phase": "usb_candidate_verified_restore_required",
                  "payload_bytes": length,
                  "payload_crc32": "{:08x}".format(zlib.crc32(data) & 0xffffffff),
                  "blocks_completed": length // 64}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "write.json"
            for change in ({"blocks_completed": 7},
                           {"phase": "dfu_blocks_in_progress"},
                           {"payload_crc32": "deadbeef"},
                           {"target": 0x200100},
                           {"payload_bytes": 4097}):
                with self.subTest(change=change):
                    path.write_text(json.dumps({**record, **change}), encoding="ascii")
                    with self.assertRaises(ValueError):
                        restore.expected_sector_from_report(path, host.FACTORY_SHA)

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
