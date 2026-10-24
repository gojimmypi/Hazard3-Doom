#!/usr/bin/env python3
"""Offline-only regression tests for conditional GateMate SPI jump audit."""
import importlib.util
from pathlib import Path
import subprocess
import types
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).with_name("audit-ulx5m-conditional-spi-jump.py")
SPEC = importlib.util.spec_from_file_location("ulx5m_v36_audit", SOURCE)
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


def command(opcode, data):
    head = bytes((opcode, len(data)))
    prefix = head + AUDIT.V34.crc16_x25(head).to_bytes(2, "little") + data
    return prefix + AUDIT.V34.crc16_x25(prefix).to_bytes(2, "little")


def make_packed(target=AUDIT.TARGET, reset=None, jump=None, gap=b"", trailer=b"\x00\x00"):
    if reset is None:
        reset = command(0xc3, b"\x00")
    if jump is None:
        jump = command(0xda, target.to_bytes(4, "little"))
    return b"\x00" * 30 + reset + gap + jump + trailer


class ConditionalJumpTests(unittest.TestCase):
    def test_exact_pair(self):
        result = AUDIT.extract_command_pair(make_packed())
        self.assertEqual(result["command_pair_bytes"], 17)
        self.assertEqual(result["jump_target"], "0x201000")
        self.assertEqual(result["command_pair_hex"],
                         (command(0xc3, b"\x00") + command(0xda, (0x201000).to_bytes(4, "little"))).hex())

    def test_crc_corruption_rejected(self):
        data = bytearray(make_packed())
        data[-3] ^= 0x40
        with self.assertRaises(ValueError):
            AUDIT.extract_command_pair(bytes(data))

    def test_absent_reset_rejected(self):
        with self.assertRaises(ValueError):
            AUDIT.extract_command_pair(make_packed(reset=b""))

    def test_absent_jump_rejected(self):
        with self.assertRaises(ValueError):
            AUDIT.extract_command_pair(make_packed(jump=b""))

    def test_wrong_jump_target_rejected(self):
        with self.assertRaises(ValueError):
            AUDIT.extract_command_pair(make_packed(target=0x200000))

    def test_big_endian_target_rejected(self):
        with self.assertRaises(ValueError):
            AUDIT.extract_command_pair(make_packed(jump=command(0xda, (0x201000).to_bytes(4, "big"))))

    def test_gap_rejected(self):
        with self.assertRaises(ValueError):
            AUDIT.extract_command_pair(make_packed(gap=b"\x00"))

    def test_duplicate_reset_rejected(self):
        with self.assertRaises(ValueError):
            AUDIT.extract_command_pair(make_packed(reset=command(0xc3, b"\x00") * 2))

    def test_duplicate_jump_rejected(self):
        j = command(0xda, AUDIT.TARGET.to_bytes(4, "little"))
        with self.assertRaises(ValueError):
            AUDIT.extract_command_pair(make_packed(jump=j * 2))

    def test_reset_payload_rejected(self):
        with self.assertRaises(ValueError):
            AUDIT.extract_command_pair(make_packed(reset=command(0xc3, b"\x01")))

    def test_unexpected_trailer_rejected(self):
        with self.assertRaises(ValueError):
            AUDIT.extract_command_pair(make_packed(trailer=b"\x01\x00"))

    def test_not_synthesizing_hardware_state(self):
        result = AUDIT.extract_command_pair(make_packed())
        self.assertEqual(result["acceptance_by_cc_cfg_ctrl"], "UNPROVEN")
        self.assertEqual(result["configuration_engine_spi_handoff"], "UNPROVEN")

    def test_stage0_not_established(self):
        self.assertEqual(AUDIT.first_stage_policy(False, True, True),
                         "BLOCKED_NO_PROTECTED_DFU_STAGE0")

    def test_unprotected_stage0_blocked(self):
        self.assertEqual(AUDIT.first_stage_policy(False, True, True,
                          first_stage_dfu_installed=True),
                         "BLOCKED_NO_PROTECTED_DFU_STAGE0")

    def test_btn2_overrides_valid_secondary(self):
        self.assertEqual(AUDIT.first_stage_policy(True, True, True,
                          first_stage_dfu_installed=True, first_stage_protected=True,
                          allow_experimental_handoff=True), "STAY_DFU_BTN2")

    def test_bad_header_stays_dfu(self):
        self.assertEqual(AUDIT.first_stage_policy(False, False, True,
                          first_stage_dfu_installed=True, first_stage_protected=True,
                          allow_experimental_handoff=True), "STAY_DFU_INVALID_APP")

    def test_bad_payload_stays_dfu(self):
        self.assertEqual(AUDIT.first_stage_policy(False, True, False,
                          first_stage_dfu_installed=True, first_stage_protected=True,
                          allow_experimental_handoff=True), "STAY_DFU_INVALID_APP")

    def test_no_authorization_stays_dfu(self):
        self.assertEqual(AUDIT.first_stage_policy(False, True, True,
                          first_stage_dfu_installed=True, first_stage_protected=True),
                         "STAY_DFU_HANDOFF_NOT_AUTHORIZED")

    def test_valid_app_still_does_not_claim_success(self):
        self.assertEqual(AUDIT.first_stage_policy(False, True, True,
                          first_stage_dfu_installed=True, first_stage_protected=True,
                          allow_experimental_handoff=True),
                         "CANDIDATE_JUMP_ONLY_NOT_HARDWARE_PROVEN")

    def test_recovery_model(self):
        result = AUDIT.replay_recovery_model()
        self.assertEqual(result["power_cycle_btn2_after_failed_candidate"], "STAY_DFU_BTN2")
        self.assertEqual(result["current_factory_configuration"],
                         "BLOCKED_NO_PROTECTED_DFU_STAGE0")

    def test_wrong_vendor_hash_rejected(self):
        captured = []
        def run(args, **kwargs):
            captured.append(Path(args[-1]))
            Path(args[-1]).write_bytes(make_packed())
            return types.SimpleNamespace(returncode=0, stderr="")
        with self.assertRaises(ValueError):
            AUDIT.run_packer_native(Path("dummy.txt"), runner=run)
        self.assertEqual(len(captured), 1)
        self.assertFalse(captured[0].exists())

    def test_packer_failure_rejected(self):
        def run(args, **kwargs):
            return types.SimpleNamespace(returncode=1, stderr="deliberate")
        with self.assertRaises(RuntimeError):
            AUDIT.run_packer_native(Path("dummy.txt"), runner=run)

    def test_valid_simulated_packer_outputs_no_file(self):
        padded = b"\x00" * (3045 - 19) + make_packed()[30:]
        self.assertEqual(len(padded), 3045)
        captured = []
        def run(args, **kwargs):
            self.assertEqual(args[1:3], ["--bootaddr", str(AUDIT.TARGET)])
            captured.append(Path(args[-1]))
            Path(args[-1]).write_bytes(padded)
            return types.SimpleNamespace(returncode=0, stderr="")
        with patch.object(AUDIT, "NATIVE_PACK_SHA", AUDIT.digest(padded)):
            result = AUDIT.run_packer_native(Path("dummy.txt"), runner=run)
        self.assertEqual(result["jump_target"], "0x201000")
        self.assertFalse(captured[0].exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
