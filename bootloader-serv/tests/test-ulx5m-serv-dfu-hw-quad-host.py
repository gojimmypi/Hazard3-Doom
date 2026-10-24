#!/usr/bin/env python3
"""Host-only tests for opt-in four-sector DFU and JTAG recovery."""
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

host = load("dfu_hw_usb_probe", HERE / "diagnose-ulx5m-serv-dfu-hw-quad.py")
restore = load("dfu_hw_restore", HERE / "restore-ulx5m-serv-candidate-quad.py")

class Device:
    def __init__(self, fail_after=None, corrupt_page=False):
        self.flash = bytearray(b"\xff" * 16384)
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
            return b"FWT3" + struct.pack("<5I", self.phase, self.count,
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
            assert magic == b"U5W3" and token == 0xc01d2028
            assert self.count == 16384 and not self.armed
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
    def test_usb_fwt3_four_sectors(self):
        backup = b"\xff" * 0x400000
        device = Device()
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "new.json"
            record = {"phase": "preflight_pending"}
            host.write_blocks(device, backup, 1000, 16384, record, output)
            self.assertEqual(device.flash, host.payload(16384))
            self.assertEqual(device.block_count, 256)
            self.assertEqual(device.finish_count, 1)
            self.assertEqual(record["payload_bytes"], 16384)
            self.assertEqual(record["blocks_completed"], 256)
            self.assertEqual(record["phase"], "usb_candidate_verified_restore_required")

    def test_interrupted_usb_fails_closed(self):
        device = Device(fail_after=64)
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(RuntimeError, "Injected USB transfer loss"):
                host.write_blocks(device, b"\xff" * 0x400000, 1000, 16384,
                                  {"phase": "initial"}, Path(tmp) / "new.json")
            self.assertEqual(device.block_count, 64)
            self.assertEqual(device.finish_count, 0)

    def test_wrong_firmware_rejected(self):
        device = Device()
        device.phase = 1
        with self.assertRaisesRegex(RuntimeError, "not disarmed"):
            host.write_blocks(device, b"\xff" * 0x400000, 1000)
        self.assertNotEqual(host.ACK, "I_ACCEPT_200000_USB_FLASH_WRITE_RISK")
        with self.assertRaises(ValueError):
            host.payload(4096)

    def test_expected_jtag_pattern_and_reject_crc_mismatch(self):
        backup = b"\xff" * 0x400000
        image = host.payload(16384)
        record = {"format": "ULX5M-DFU-PHYSICAL-16K-V1",
                  "backup_sha256": host.FACTORY_SHA, "target": restore.TARGET,
                  "phase": "usb_candidate_verified_restore_required",
                  "payload_bytes": 16384, "blocks_completed": 256,
                  "payload_crc32": "{:08x}".format(zlib.crc32(image) & 0xffffffff)}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "write.json"
            path.write_text(json.dumps(record), encoding="ascii")
            self.assertEqual(restore.expected_sector_from_report(path, host.FACTORY_SHA), image)
            path.write_text(json.dumps({**record, "blocks_completed": 127}), encoding="ascii")
            with self.assertRaises(ValueError):
                restore.expected_sector_from_report(path, host.FACTORY_SHA)
            path.write_text(json.dumps({**record, "payload_crc32": "00000000"}), encoding="ascii")
            with self.assertRaises(ValueError):
                restore.expected_sector_from_report(path, host.FACTORY_SHA)

    def test_full_image_restore_four_sectors(self):
        backup = b"\xff" * 0x400000
        live = bytearray(backup)
        live[restore.TARGET:restore.TARGET + 16384] = host.payload(16384)
        previous = (restore.qual.detect, restore.qual.read_region, restore.qual.call)
        commands = []
        try:
            restore.qual.detect = lambda *_: None
            restore.qual.read_region = lambda _l, _f, offset, size: bytes(live[offset:offset+size])
            def fake_call(cmd, timeout=180):
                offset = int(cmd[-2]); blob = Path(cmd[-1]).read_bytes()
                self.assertEqual(len(blob), 4096)
                live[offset:offset+4096] = blob
                commands.append(offset)
            restore.qual.call = fake_call
            with tempfile.TemporaryDirectory() as tmp:
                original = Path(tmp) / "original-200000-16k.bin"
                original.write_bytes(backup[restore.TARGET:restore.TARGET+16384])
                for i in range(4):
                    (Path(tmp) / "original-{:06x}.bin".format(restore.TARGET+i*4096)).write_bytes(b"\xff"*4096)
                self.assertEqual(restore.execute(Path("ignored"), 1000, backup,
                                                   original), "restored_and_verified")
                self.assertEqual(bytes(live), backup)
                self.assertEqual(commands, [restore.TARGET + 4096*i for i in range(4)])
        finally:
            restore.qual.detect, restore.qual.read_region, restore.qual.call = previous

    def test_jtag_restore_command_rejects_outside_sector(self):
        with tempfile.TemporaryDirectory() as tmp:
            original = Path(tmp) / "original-200000.bin"
            original.write_bytes(b"\xff" * 4096)
            for offset in (0, restore.TARGET - 4096, restore.TARGET + restore.SECTOR,
                           restore.qual.FLASH_BYTES - 4096):
                with self.assertRaisesRegex(ValueError, "Restore offset"):
                    restore.write_cmd(Path("ignored"), 1000, original, offset)
            for offset in (restore.TARGET + restore.ERASE * i for i in range(4)):
                cmd = restore.write_cmd(Path("ignored"), 1000, original, offset)
                self.assertEqual(cmd[-2], str(offset))

    def test_read_only_header_obeys_real_jtag_read_limits(self):
        # The shared JTAG helper can dump 4 KiB or 16 KiB at a time, but
        # must issue a supported 16 KiB dump. Verify this restriction is respected.
        backup = b"\xff" * restore.qual.FLASH_BYTES
        live = bytearray(backup)
        live[restore.TARGET:restore.TARGET + restore.SECTOR] = host.payload(16384)
        previous = (restore.qual.detect, restore.qual.read_region, restore.qual.call)
        read_sizes = []
        try:
            restore.qual.detect = lambda *_: None

            def checked_read(loader, freq, offset, size):
                if size != restore.qual.FLASH_BYTES:
                    restore.qual.read_cmd(loader, freq, offset, size, Path("unused.bin"))
                read_sizes.append(size)
                return bytes(live[offset:offset + size])

            restore.qual.read_region = checked_read
            restore.qual.call = lambda *_a, **_kw: self.fail("Read-only verification must not write")
            self.assertEqual(
                restore.execute(Path("ignored"), 1000, backup,
                                expected_sector=host.payload(16384)),
                "read_only_verified_candidate_pattern")
            self.assertEqual(read_sizes, [restore.qual.CHUNK, restore.qual.FLASH_BYTES])
        finally:
            restore.qual.detect, restore.qual.read_region, restore.qual.call = previous

    def test_unexpected_region_change_forbids_restore(self):
        backup = b"\xff" * 0x400000
        live = bytearray(backup)
        live[0x1fffff] = 0
        previous = (restore.qual.detect, restore.qual.read_region, restore.qual.call)
        try:
            restore.qual.detect = lambda *_: None
            restore.qual.read_region = lambda _l,_f,offset,size: bytes(live[offset:offset+size])
            restore.qual.call = lambda *_a,**_kw: self.fail("No mutation allowed")
            with self.assertRaisesRegex(ValueError,"Unexpected changes outside"):
                restore.execute(Path("ignored"),1000,backup)
        finally:
            restore.qual.detect, restore.qual.read_region, restore.qual.call = previous

if __name__ == "__main__":
    unittest.main(verbosity=2)
