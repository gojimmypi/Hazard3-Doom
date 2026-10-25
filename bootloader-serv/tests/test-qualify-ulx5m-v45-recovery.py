#!/usr/bin/env python3
"""Read-only v45 qualification checks, including failure-injection cases."""

import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location(
    "ulx5m_v45_recovery", HERE / "qualify-ulx5m-v45-recovery.py")
V45 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V45)


class EvidenceTests(unittest.TestCase):
    def test_pinned_application_in_archive(self):
        bit = HERE.parent / "build-ulx5m-gs/top_ulx5m_gs_normal_led.bit"
        if not bit.exists():
            self.skipTest("archived bitstream not present in working tree")
        image = V45.read_pinned(bit, V45.APP_BYTES, V45.APP_SHA256, "app")
        sector = V45.expected_app_sector(image)
        self.assertEqual(V45.sha256(sector), V45.SECTOR_SHA256)
        self.assertEqual(sector[V45.APP_BYTES:], b"\xff" * 1070)

    def test_missing_data_is_not_qualified(self):
        report = V45.audit()
        self.assertEqual(report["evidence_status"], "INCOMPLETE")
        self.assertIn("DEPLOYMENT_BLOCKED", report["result"])
        self.assertFalse(report["protection"]["flash_write_authorized"])

    def test_rejects_unpaired_backups(self):
        report = V45.audit(factory_pass1="not-a-real-file")
        self.assertEqual(report["evidence_status"], "FAIL")
        self.assertIn("both independent", report["errors"][0])

    def test_rejects_corrupt_app_and_sector(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp) / "app.bit"
            app.write_bytes(b"\x00" * V45.APP_BYTES)
            report = V45.audit(app_bit=app, sector_dump=app)
            self.assertEqual(report["evidence_status"], "FAIL")
            self.assertEqual(report["evidence"]["app_image"], "FAIL")
            self.assertEqual(report["evidence"]["independent_sector"], "FAIL")

    def test_rejects_truncated_app(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp) / "app.bit"
            app.write_bytes(b"\xd9\x01\xed\x96")
            with self.assertRaises(ValueError):
                V45.read_pinned(app, V45.APP_BYTES, V45.APP_SHA256, "app")

    def test_rejects_non_factory_backups(self):
        with tempfile.TemporaryDirectory() as tmp:
            a = Path(tmp) / "a.bin"
            b = Path(tmp) / "b.bin"
            a.write_bytes(b"\xff" * V45.FLASH_BYTES)
            b.write_bytes(b"\xff" * V45.FLASH_BYTES)
            self.assertEqual(V45.audit(factory_pass1=a, factory_pass2=b)
                             ["evidence_status"], "FAIL")

    def test_sectors_only_allow_application_change(self):
        baseline = bytearray(b"\xff" * V45.FLASH_BYTES)
        other = bytearray(baseline)
        other[V45.APP_ADDR] = 0
        self.assertEqual(V45.differing_sectors(baseline, other), [])
        for address in (V45.PROTECTED_STAGE0_ADDR,
                        V45.PROTECTED_METADATA_ADDR,
                        V45.APP_ADDR - V45.SECTOR_BYTES,
                        V45.APP_ADDR + V45.SECTOR_BYTES,
                        V45.FLASH_BYTES - 1):
            changed = bytearray(other)
            changed[address] ^= 1
            self.assertEqual(V45.differing_sectors(baseline, changed),
                             [address // V45.SECTOR_BYTES * V45.SECTOR_BYTES])

    def test_rejects_flash_dump_geometry(self):
        with self.assertRaises(ValueError):
            V45.differing_sectors(b"", b"")
        with self.assertRaises(ValueError):
            V45.differing_sectors(b"\xff" * V45.FLASH_BYTES,
                                  b"\xff" * V45.FLASH_BYTES,
                                  allowed_start=0)

    def test_synthetic_complete_evidence_and_protected_regions(self):
        # Synthetic inputs exercise both PASS and corruption paths. They do
        # not stand in for the pinned hardware-produced factory dumps.
        image = b"D" * V45.APP_BYTES
        sector = image + b"\xff" * (V45.SECTOR_BYTES - len(image))
        factory = bytes([0xff]) * V45.FLASH_BYTES
        snapshot = bytearray(factory)
        snapshot[V45.APP_ADDR:V45.APP_ADDR + V45.SECTOR_BYTES] = sector
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, blob in (("factory1", factory), ("factory2", factory),
                               ("image", image), ("sector", sector),
                               ("snapshot", snapshot)):
                (root / name).write_bytes(blob)
            paths = dict(factory_pass1=root / "factory1",
                         factory_pass2=root / "factory2",
                         app_bit=root / "image", sector_dump=root / "sector",
                         flash_snapshot=root / "snapshot")
            with mock.patch.object(V45, "FACTORY_SHA256", V45.sha256(factory)), \
                 mock.patch.object(V45, "APP_SHA256", V45.sha256(image)), \
                 mock.patch.object(V45, "SECTOR_SHA256", V45.sha256(sector)):
                result = V45.audit(**paths)
                self.assertEqual(result["evidence_status"], "PINNED_OFFLINE_EVIDENCE_PASS")
                self.assertEqual(result["evidence"]["current_flash_snapshot"],
                                 "PASS_ONLY_EXPECTED_APP_SECTOR_DIFFERS")
                self.assertFalse(result["protection"]["flash_write_authorized"])
                self.assertIn("DEPLOYMENT_BLOCKED", result["result"])

                for address in (0, V45.PROTECTED_METADATA_ADDR, V45.APP_ADDR + V45.SECTOR_BYTES):
                    with self.subTest(protected_address=address):
                        bad = bytearray(snapshot)
                        bad[address] ^= 1
                        paths["flash_snapshot"].write_bytes(bad)
                        changed = V45.audit(**paths)
                        self.assertEqual(changed["evidence_status"], "FAIL")
                        self.assertIn("unexpected changed erase sectors",
                                      changed["errors"][0])
                paths["flash_snapshot"].write_bytes(snapshot)
                bad_tail = bytearray(snapshot)
                bad_tail[V45.APP_ADDR + V45.SECTOR_BYTES - 1] = 0
                paths["flash_snapshot"].write_bytes(bad_tail)
                self.assertEqual(V45.audit(**paths)["evidence_status"], "FAIL")
                paths["flash_snapshot"].write_bytes(snapshot)
                paths["sector_dump"].write_bytes(sector[:-1] + b"\x00")
                self.assertEqual(V45.audit(**paths)["evidence_status"], "FAIL")

    def test_cli_read_only_empty_inputs(self):
        tool = HERE / "qualify-ulx5m-v45-recovery.py"
        result = subprocess.run([sys.executable, str(tool)], capture_output=True,
                                text=True, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("DEPLOYMENT_BLOCKED", result.stdout)
        self.assertNotIn("DEPLOYMENT_READY", result.stdout)


class BootPolicyTests(unittest.TestCase):
    def setUp(self):
        self.safe_hypothetical = dict(
            btn2_latched=False,
            stage0_installed=True,
            stage0_protected=True,
            independent_recovery=True,
            image_verified=True,
            handoff_supported=True,
            failure_detection_and_rollback=True,
            attempts_remaining=True,
        )

    def test_unproven_real_board_is_blocked(self):
        real = dict(self.safe_hypothetical)
        real.update(stage0_installed=False, stage0_protected=False,
                    independent_recovery=False, handoff_supported=False,
                    failure_detection_and_rollback=False)
        self.assertEqual(V45.recovery_policy(**real), "BLOCK_NO_INDEPENDENT_RECOVERY")

    def test_fault_injection_order(self):
        cases = (
            ("independent_recovery", False, "BLOCK_NO_INDEPENDENT_RECOVERY"),
            ("stage0_installed", False, "BLOCK_NO_PROTECTED_STAGE0"),
            ("stage0_protected", False, "BLOCK_NO_PROTECTED_STAGE0"),
            ("btn2_latched", True, "STAY_DFU_BTN2"),
            ("image_verified", False, "STAY_DFU_INVALID_IMAGE"),
            ("handoff_supported", False, "STAY_DFU_UNSUPPORTED_HANDOFF"),
            ("failure_detection_and_rollback", False, "STAY_DFU_NO_ROLLBACK"),
            ("attempts_remaining", False, "STAY_DFU_ATTEMPTS_EXHAUSTED"),
        )
        for key, value, expected in cases:
            with self.subTest(fault=key):
                case = dict(self.safe_hypothetical)
                case[key] = value
                self.assertEqual(V45.recovery_policy(**case), expected)

    def test_even_fully_hypothetical_case_never_authorizes_hardware(self):
        result = V45.recovery_policy(**self.safe_hypothetical)
        self.assertEqual(result, "MODEL_ELIGIBLE_ONLY_NO_HARDWARE_AUTHORIZATION")


if __name__ == "__main__":
    unittest.main(verbosity=2)
