#!/usr/bin/env python3
"""Host-only end-to-end checks for ULX5M normal-image integration."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("qualify-ulx5m-normal-image-integration.py")
SPEC = importlib.util.spec_from_file_location("qualify_u5im", SCRIPT)
Q = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(Q)
ROOT = Path(__file__).resolve().parents[1]
GOLDEN = bytes.fromhex("d901ed96") + bytes(range(256)) * 10


class IntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.factory = b"\xff" * Q.FLASH_BYTES

    def test_u5im_binary_header_interoperability(self):
        blob = Q.u5im_bytes(GOLDEN)
        self.assertEqual(blob[:4], b"U5IM")
        self.assertEqual(blob[Q.PAYLOAD_OFFSET:], GOLDEN)
        self.assertEqual(len(blob), Q.PAYLOAD_OFFSET + len(GOLDEN))

    def test_empty_bad_signature_and_oversize_rejected(self):
        for bit in (b"", b"bad" * 100, b"\xd9\x01\xed\x96"):
            with self.assertRaises(ValueError):
                Q.u5im_bytes(bit)
        with self.assertRaises(ValueError):
            Q.u5im_bytes(GOLDEN + b"Z" * Q.MAX_IMAGE_BYTES)

    def test_factory_digest_gate(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "factory.bin"
            p.write_bytes(self.factory)
            self.assertEqual(Q.require_factory(p, Q.digest(self.factory)), self.factory)
            with self.assertRaises(ValueError):
                Q.require_factory(p)
            p.write_bytes(b"short")
            with self.assertRaises(ValueError):
                Q.require_factory(p, Q.digest(b"short"))

    def test_overwrite_prevention_by_existing_data(self):
        damaged = bytearray(self.factory)
        damaged[Q.CANDIDATE_ADDR + 0x200] = 0
        with self.assertRaisesRegex(ValueError, "existing flash data"):
            Q.stage_in_memory(damaged, GOLDEN)

    def test_candidate_exceeds_upper_half(self):
        big = b"\xd9\x01\xed\x96" + b"Q" * (Q.MAX_IMAGE_BYTES - 4)
        staged, blob, end = Q.stage_in_memory(self.factory, big)
        self.assertEqual(end, Q.FLASH_BYTES)
        self.assertEqual(staged[-1], ord("Q"))
        self.assertEqual(len(blob), 0x200000)
        with self.assertRaises(ValueError):
            Q.stage_in_memory(self.factory, big + b"X")

    def test_full_compiler_and_firmware_parser_positive_negative(self):
        with tempfile.TemporaryDirectory() as td:
            result = Q.integrate(ROOT, self.factory, GOLDEN, Path(td))
        self.assertTrue(result["c_parser_valid"])
        self.assertTrue(result["c_parser_payload_corruption_rejected"])
        self.assertTrue(result["c_parser_header_corruption_rejected"])
        self.assertEqual(result["configuration_stream_address"], "0x200100")
        self.assertFalse(result["flash_write_authorized"])
        self.assertFalse(result["app_boot_authorized"])
        self.assertFalse(result["persistent_recovery_proven"])

    def test_mismatched_factory_reference_fails(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "factory.bin"
            b = bytearray(self.factory)
            b[0] = 0
            p.write_bytes(b)
            with self.assertRaises(ValueError):
                Q.require_factory(p)


if __name__ == "__main__":
    unittest.main(verbosity=2)
