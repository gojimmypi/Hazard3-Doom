#!/usr/bin/env python3
"""Offline mock-device regression for the read-only 4 MiB backup utility."""
import contextlib
import importlib.util
import io
from pathlib import Path
import struct
import tempfile
import unittest

SOURCE = Path(__file__).with_name("backup-ulx5m-serv-flash.py")
spec = importlib.util.spec_from_file_location("ulx5m_flash_backup", SOURCE)
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)


class FakeDevice:
    """Model 0x51/0x52/0x57/0x58; fail if any USB OUT is sent."""

    def __init__(self, corrupt_second=False, fail_first_read=False):
        self.calls = []
        self.corrupt_second = corrupt_second
        self.fail_first_read = fail_first_read
        self.short_once = False
        self.reads = 0
        self.phase = 0
        self.jedec = backup.EXPECTED_JEDEC
        self.layout = backup.EXPECTED_LAYOUT
        self.stage = backup.EXPECTED_STAGE

    @staticmethod
    def value(address):
        # Contains erased, non-erased, and all-zero sectors.
        sector = address // backup.SECTOR_BYTES
        if sector % 8 == 0:
            return 0xff
        if sector % 8 == 1:
            return 0
        return (address * 17 + (address >> 8) * 23) & 0xff

    def ctrl_transfer(self, bm, request, value, index, length, timeout=0):
        assert bm == 0xc0, "must send vendor control IN only"
        assert request in (0x51, 0x52, 0x57, 0x58)
        assert timeout > 0
        self.calls.append((bm, request, value, index, length))
        if request == 0x51:
            assert (value, index, length) == (0, 0, 3)
            return self.jedec
        if request == 0x58:
            assert (value, index, length) == (0, 0, 32)
            return b"FLM1" + struct.pack("<7I", *self.layout)
        if request == 0x57:
            assert (value, index, length) == (0, 0, 16)
            self.phase += 1
            return b"STG1" + struct.pack("<IIHBB", *self.stage)
        address = (index << 16) | value
        assert 1 <= length <= 32
        assert 0 <= address < backup.FLASH_BYTES
        assert address + length <= backup.FLASH_BYTES
        self.reads += 1
        if self.fail_first_read:
            self.fail_first_read = False
            raise OSError("transient USB error")
        data = bytearray(self.value(address + i) for i in range(length))
        if self.corrupt_second and self.phase >= 2 and address == 0x2000:
            data[4] ^= 1
        if self.short_once:
            self.short_once = False
            return data[:-1]
        return data


class BackupTests(unittest.TestCase):
    def test_preflight_and_rejection(self):
        dev = FakeDevice()
        self.assertEqual(backup.query_preflight(dev, 5000), backup.EXPECTED_JEDEC)
        self.assertEqual([call[1] for call in dev.calls], [0x51, 0x58, 0x57])
        dev.jedec = b"\x00\x00\x00"
        with self.assertRaisesRegex(RuntimeError, "JEDEC"):
            backup.query_preflight(dev, 5000)
        dev.jedec = backup.EXPECTED_JEDEC
        dev.layout = (backup.FLASH_BYTES, 4096, 256, 0, 0x400000, 1, 3)
        with self.assertRaisesRegex(RuntimeError, "policy"):
            backup.query_preflight(dev, 5000)
        dev.layout = backup.EXPECTED_LAYOUT
        dev.stage = (9, 0, 1, 5, 0)
        with self.assertRaisesRegex(RuntimeError, "not empty"):
            backup.query_preflight(dev, 5000)

    def test_read_retries_are_idempotent(self):
        dev = FakeDevice(fail_first_read=True)
        data = backup.read_at(dev, 0x123456, 32, 5000, 2, sleep=lambda _: None)
        self.assertEqual(data, bytes(dev.value(0x123456 + i) for i in range(32)))
        self.assertEqual(dev.reads, 2)
        dev.short_once = True
        self.assertEqual(backup.read_at(dev, 0xffff, 1, 5000, 1,
                                        sleep=lambda _: None), bytes((dev.value(0xffff),)))
        with self.assertRaises(ValueError):
            backup.read_at(dev, 0, 33, 5000, 2)
        with self.assertRaises(ValueError):
            backup.read_at(dev, backup.FLASH_BYTES - 1, 2, 5000, 2)

    def test_full_double_read_and_report(self):
        dev = FakeDevice()
        with tempfile.TemporaryDirectory() as d:
            directory = Path(d)
            with contextlib.redirect_stdout(io.StringIO()):
                report = backup.backup(dev, directory)
            self.assertTrue(report["byte_for_byte_match"])
            self.assertEqual(report["passes"][0]["sha256"],
                             report["passes"][1]["sha256"])
            self.assertEqual((directory / "flash-pass1.bin").stat().st_size,
                             backup.FLASH_BYTES)
            self.assertEqual((directory / "flash-pass2.bin").stat().st_size,
                             backup.FLASH_BYTES)
            self.assertTrue((directory / "flash-backup-report.json").is_file())
            self.assertEqual(dev.reads, 2 * backup.FLASH_BYTES // 32)
            self.assertEqual(report["analysis"]["all_ff_sectors"], 128)
            self.assertEqual(report["analysis"]["all_00_sectors"], 128)
            self.assertEqual(report["analysis"]["other_sectors"], 768)
            with self.assertRaises(FileExistsError):
                backup.backup(dev, directory)

    def test_different_second_pass_rejected_and_preserved(self):
        dev = FakeDevice(corrupt_second=True)
        with tempfile.TemporaryDirectory() as d:
            directory = Path(d)
            with contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError, "0x002004"):
                    backup.backup(dev, directory)
            self.assertTrue((directory / "flash-pass1.bin").exists())
            self.assertTrue((directory / "flash-pass2.bin").exists())
            self.assertFalse((directory / "flash-backup-report.json").exists())
            self.assertFalse(any(x.name.endswith("partial") for x in directory.iterdir()))

    def test_failure_retains_partial_and_does_not_overwrite(self):
        class PersistentFailure(FakeDevice):
            def ctrl_transfer(self, bm, request, value, index, length, timeout=0):
                if request == 0x52 and value == 32 and index == 0:
                    raise OSError("USB lost")
                return super().ctrl_transfer(bm, request, value, index,
                                             length, timeout=timeout)

        with tempfile.TemporaryDirectory() as d:
            directory = Path(d)
            with contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(IOError, "0x000020"):
                    backup.backup(PersistentFailure(), directory)
            self.assertEqual((directory / "flash-pass1.bin.partial").stat().st_size, 32)
            self.assertFalse((directory / "flash-pass1.bin").exists())
            self.assertFalse((directory / "flash-backup-report.json").exists())
            with self.assertRaises(FileExistsError):
                backup.backup(FakeDevice(), directory)


if __name__ == "__main__":
    unittest.main(verbosity=2)
