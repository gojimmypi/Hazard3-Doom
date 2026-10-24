#!/usr/bin/env python3
"""Unit tests for the read-only stage-zero candidate image planner."""
import importlib.util
import pathlib
import unittest
from unittest.mock import patch

SCRIPT = pathlib.Path(__file__).with_name("plan-ulx5m-dfu-stage0.py")
spec = importlib.util.spec_from_file_location("stage0_plan", SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class Stage0PlanTests(unittest.TestCase):
    def setUp(self):
        self.dfu = mod.SYNC + bytes(range(16)) + b"\x12" * 4500
        self.factory = b"\xff" * mod.FLASH_SIZE
        self.expected = mod.digest(self.dfu)
        self.override = patch.multiple(mod, DFU_LENGTH=len(self.dfu), DFU_HASH=self.expected)
        self.override.start()
        self.addCleanup(self.override.stop)

    def test_valid_erased_snapshot(self):
        out = mod.plan_stage0(self.factory, self.dfu)
        self.assertTrue(out["candidate_metadata_and_native_sectors_unchanged"])
        self.assertFalse(out["write_authorized"])
        self.assertEqual(out["first_stage_sectors_spanned"], 2)
        self.assertEqual(out["changed_sectors"], 2)
        self.assertEqual(out["sectors_requiring_erase"], 0)
        self.assertEqual(out["last_sector_suffix_bytes_preserved"], 8192 - len(self.dfu))

    def test_nor_erase_detection(self):
        flash = bytearray(self.factory)
        flash[0] = 0
        flash[1] = 0
        out = mod.plan_stage0(bytes(flash), self.dfu)
        self.assertEqual(out["sectors_requiring_erase"], 1)

    def test_preserves_last_sector_tail(self):
        flash = bytearray(self.factory)
        end = ((len(self.dfu) + mod.SECTOR - 1) // mod.SECTOR) * mod.SECTOR
        flash[len(self.dfu):end] = b"\x5a" * (end - len(self.dfu))
        out = mod.plan_stage0(bytes(flash), self.dfu)
        self.assertTrue(out["all_bytes_after_dfu_payload_unchanged"])

    def test_wrong_image_rejected(self):
        bad = self.dfu[:-1] + b"\0"
        with self.assertRaises(ValueError):
            mod.plan_stage0(self.factory, bad)

    def test_invalid_sync_rejected(self):
        bad = b"abcd" + self.dfu[4:]
        with patch.object(mod, "DFU_HASH", mod.digest(bad)):
            with self.assertRaises(ValueError):
                mod.plan_stage0(self.factory, bad)

    def test_wrong_flash_size_rejected(self):
        with self.assertRaises(ValueError):
            mod.plan_stage0(self.factory[:-1], self.dfu)

    def test_occupied_metadata_rejected(self):
        flash = bytearray(self.factory)
        flash[mod.APP_META] = 0x00
        with self.assertRaises(ValueError):
            mod.plan_stage0(bytes(flash), self.dfu)

    def test_occupied_native_rejected(self):
        flash = bytearray(self.factory)
        flash[mod.APP_NATIVE] = 0x00
        with self.assertRaises(ValueError):
            mod.plan_stage0(bytes(flash), self.dfu)

    def test_no_hardware_or_programming_dependencies(self):
        source = SCRIPT.read_text("ascii")
        for forbidden in ("subprocess", "serial", "usb.core", "write_flash(", "erase_flash("):
            self.assertNotIn(forbidden, source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
