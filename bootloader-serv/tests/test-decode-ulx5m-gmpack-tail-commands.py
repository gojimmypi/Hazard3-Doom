#!/usr/bin/env python3
"""Offline regression tests for frozen GateMate command-trailer decoder."""

import importlib.util
from pathlib import Path
import unittest

SRC = Path(__file__).with_name("decode-ulx5m-gmpack-tail-commands.py")
SPEC = importlib.util.spec_from_file_location("gatemate_tail_decoder", SRC)
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


def command(opcode, payload):
    header = bytes((opcode, len(payload)))
    hdr_crc = MOD.crc16_x25(header).to_bytes(2, "little")
    start = header + hdr_crc + payload
    return start + MOD.crc16_x25(start).to_bytes(2, "little")


def build_fixture():
    # Synthetic prefix, real observed suffix and command framing.
    pre = b"\x00" * MOD.STATUS_OFFSET
    payload_suffix = bytes.fromhex("0821c300000000000000")
    trailer = MOD.STATUS_EPILOGUE
    golden = pre + command(0xDB, bytes.fromhex("13 1f") + payload_suffix) + trailer
    reconfig = pre + command(0xDB, bytes.fromhex("1b 1f") + payload_suffix) + trailer
    reset_jump = (command(0xC3, b"\x00") +
                  command(0xDA, bytes.fromhex("00002000")) + b"\x00\x00")
    boot = pre + command(0xDB, bytes.fromhex("17 10") + payload_suffix) + trailer + reset_jump
    both = pre + command(0xDB, bytes.fromhex("1f 10") + payload_suffix) + trailer + reset_jump
    return golden, reconfig, boot, both


class TailCommandTests(unittest.TestCase):
    def setUp(self):
        self.golden, self.reconfig, self.boot, self.combined = build_fixture()

    def test_reference_sizes(self):
        self.assertEqual(len(self.golden), 414867)
        self.assertEqual(len(self.boot), 414886)

    def test_x25_reference_vector(self):
        self.assertEqual(MOD.crc16_x25(b"123456789"), 0x906E)

    def test_observed_status_header_crc(self):
        self.assertEqual(command(0xDB, bytes.fromhex("13 1f") + MOD.STATUS_PAYLOAD_TAIL),
                         bytes.fromhex("db 0c b8 7e 13 1f 08 21 c3 00 00 00 00 00 00 00 7b a1"))

    def test_observed_reconfig_crc(self):
        self.assertTrue(command(0xDB, bytes.fromhex("1b 1f") + MOD.STATUS_PAYLOAD_TAIL).endswith(
            bytes.fromhex("97 ab")))

    def test_observed_bootaddr_crc(self):
        self.assertTrue(command(0xDB, bytes.fromhex("17 10") + MOD.STATUS_PAYLOAD_TAIL).endswith(
            bytes.fromhex("41 b8")))

    def test_observed_combined_crc(self):
        self.assertTrue(command(0xDB, bytes.fromhex("1f 10") + MOD.STATUS_PAYLOAD_TAIL).endswith(
            bytes.fromhex("ad b2")))

    def test_observed_appended_bytes(self):
        self.assertEqual(self.boot[-19:], bytes.fromhex(
            "c3 01 0c fe 00 cc c6 da 04 28 eb 00 00 20 00 bc d4 00 00"))

    def test_default_decoded(self):
        entry = MOD.decode_one(self.golden, "default", self.golden)
        self.assertEqual(entry["status_byte"], "0x13")
        self.assertEqual([c["name"] for c in entry["commands"]], ["CMD_CHG_STATUS"])

    def test_reconfig_decoded(self):
        entry = MOD.decode_one(self.reconfig, "reconfig", self.golden)
        self.assertEqual(entry["status_byte"], "0x1b")
        self.assertEqual(len(entry["commands"]), 1)
        self.assertTrue(entry["status_reconfig_mask_observed"])

    def test_bootaddr_decoded(self):
        entry = MOD.decode_one(self.boot, "bootaddr_probe", self.golden)
        self.assertEqual([c["name"] for c in entry["commands"]],
                         ["CMD_CHG_STATUS", "CMD_CFGRST", "CMD_JUMP"])
        self.assertEqual(entry["commands"][2]["address_observed"], "0x00200000")
        self.assertFalse(entry["commands"][2]["address_authorized"])

    def test_combined_decoded(self):
        entry = MOD.decode_one(self.combined, "reconfig_bootaddr_probe", self.golden)
        self.assertEqual(entry["status_byte"], "0x1f")
        self.assertEqual(len(entry["commands"]), 3)

    def reject_modified(self, original, name, offset, value):
        changed = bytearray(original)
        changed[offset] ^= value
        with self.assertRaises(ValueError):
            MOD.decode_one(bytes(changed), name, self.golden)

    def test_header_crc_rejected(self):
        self.reject_modified(self.golden, "default", MOD.STATUS_OFFSET + 2, 0x01)

    def test_payload_crc_rejected(self):
        self.reject_modified(self.reconfig, "reconfig", MOD.STATUS_OFFSET + 16, 0x01)

    def test_illegal_status_rejected_even_with_valid_crc(self):
        changed = (self.golden[:MOD.STATUS_OFFSET] +
                   command(0xDB, bytes.fromhex("03 1f") + MOD.STATUS_PAYLOAD_TAIL) +
                   MOD.STATUS_EPILOGUE)
        with self.assertRaises(ValueError):
            MOD.decode_one(changed, "default", self.golden)

    def test_unexpected_header_opcode_rejected(self):
        changed = (self.golden[:MOD.STATUS_OFFSET] +
                   command(0xDA, bytes.fromhex("13 1f") + MOD.STATUS_PAYLOAD_TAIL) +
                   MOD.STATUS_EPILOGUE)
        with self.assertRaises(ValueError):
            MOD.decode_one(changed, "default", self.golden)

    def test_bad_trailing_nops_rejected(self):
        self.reject_modified(self.golden, "default", len(self.golden) - 1, 0x01)

    def test_different_placed_route_body_rejected(self):
        self.reject_modified(self.boot, "bootaddr_probe", 123, 0x01)

    def test_reset_command_corrupted_rejected(self):
        self.reject_modified(self.boot, "bootaddr_probe", MOD.GOLDEN_SIZE + 2, 0x01)

    def test_jump_address_crc_corrupted_rejected(self):
        self.reject_modified(self.boot, "bootaddr_probe", MOD.GOLDEN_SIZE + 11, 0x01)

    def test_other_jump_address_rejected_even_with_valid_crc(self):
        changed = (self.boot[:MOD.GOLDEN_SIZE + 7] +
                   command(0xDA, bytes.fromhex("00001000")) + b"\x00\x00")
        with self.assertRaises(ValueError):
            MOD.decode_one(changed, "bootaddr_probe", self.golden)

    def test_extra_suffix_rejected(self):
        with self.assertRaises(ValueError):
            MOD.decode_one(self.combined + b"\x00", "reconfig_bootaddr_probe", self.golden)

    def test_unknown_name_rejected(self):
        with self.assertRaises(ValueError):
            MOD.decode_one(self.golden, "unknown", self.golden)

    def test_reconstructed_real_variants_match_measured_sha256(self):
        # Optional fixture: the unchanged hardware-validated image, when present.
        golden_path = (Path(__file__).resolve().parents[1] / "build-ulx5m-gs" /
                       "top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2.bit")
        if not golden_path.is_file():
            self.skipTest("frozen seed-147 .bit is not installed")
        golden = golden_path.read_bytes()
        self.assertEqual(MOD.decode_one(golden, "default", golden)["status_byte"], "0x13")
        prefix = golden[:MOD.STATUS_OFFSET]
        suffix = MOD.STATUS_EPILOGUE
        append = (command(0xC3, b"\x00") +
                  command(0xDA, bytes.fromhex("00002000")) + b"\x00\x00")
        images = {"default": golden,
                  "reconfig": prefix + command(0xDB, bytes.fromhex("1b1f") +
                                                 MOD.STATUS_PAYLOAD_TAIL) + suffix,
                  "bootaddr_probe": prefix + command(0xDB, bytes.fromhex("1710") +
                                                       MOD.STATUS_PAYLOAD_TAIL) + suffix + append,
                  "reconfig_bootaddr_probe": prefix + command(0xDB, bytes.fromhex("1f10") +
                                                                MOD.STATUS_PAYLOAD_TAIL) + suffix + append}
        self.assertEqual(len(MOD.analyze_images(images)["variants"]), 4)

    def test_frozen_hashes_gate_full_report(self):
        with self.assertRaisesRegex(ValueError, "frozen variant size/hash mismatch"):
            MOD.analyze_images({"default": self.golden, "reconfig": self.reconfig,
                                "bootaddr_probe": self.boot,
                                "reconfig_bootaddr_probe": self.combined})


if __name__ == "__main__":
    unittest.main(verbosity=2)
