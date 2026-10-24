#!/usr/bin/env python3
"""Host-only regressions for the ULX5M GateMate SPI multiboot audit."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

MODULE = Path(__file__).with_name("audit-ulx5m-spi-multiboot-commands.py")
SPEC = importlib.util.spec_from_file_location("ulx5m_multiboot_audit", MODULE)
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


def command(opcode, data):
    header = bytes((opcode, len(data)))
    base = header + AUDIT.crc16_x25(header).to_bytes(2, "little") + data
    return base + AUDIT.crc16_x25(base).to_bytes(2, "little")


class Tests(unittest.TestCase):
    def test_crc_standard(self):
        self.assertEqual(AUDIT.crc16_x25(b"123456789"), 0x906e)

    def test_jump_decode_little_endian(self):
        obj = AUDIT.parse_command(command(0xda, (0x200000).to_bytes(4, "little")), 0)
        self.assertEqual(obj["target_le"], "0x00200000")

    def test_jump_decode_big_endian(self):
        obj = AUDIT.parse_command(command(0xda, (0x200000).to_bytes(4, "big")), 0)
        self.assertEqual(obj["target_be"], "0x00200000")

    def test_crc_corruption_rejected(self):
        blob = bytearray(command(0xda, (0x200000).to_bytes(4, "little")))
        blob[-1] ^= 0x20
        self.assertIsNone(AUDIT.parse_command(bytes(blob), 0))

    def test_other_address_does_not_match(self):
        blob = command(0xda, (0x100000).to_bytes(4, "little"))
        self.assertNotEqual(AUDIT.parse_command(blob, 0)["target_le"], "0x00200000")

    def test_diff(self):
        self.assertEqual(AUDIT.find_diff(b"abxyz", b"ab123xyz")["size_delta"], 3)
        self.assertIsNone(AUDIT.find_diff(b"x", b"x")["first_diff"])

    def test_variants_scanned_in_temporary_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            reference = command(0xdb, bytes((0x13, 0x1f)))
            source = Path(directory) / "unused.txt"
            source.write_text("unused", encoding="ascii")
            visited = []
            def fake_runner(args, **kwargs):
                output = Path(args[-1])
                visited.append(output)
                body = reference
                if "--bootaddr" in args:
                    body = command(0xda, (0x200000).to_bytes(4, "little")) + body
                if "--background" in args:
                    body = command(0xc3, b"") + body
                output.write_bytes(body)
                return subprocess.CompletedProcess(args, 0, "", "")
            report = AUDIT.audit(source, reference, runner=fake_runner)
            self.assertEqual(set(report), {item[0] for item in AUDIT.VARIANTS})
            self.assertEqual(len(visited), 4)
            self.assertTrue(report["bootaddr"]["has_verified_jump_to_secondary"])
            self.assertTrue(report["bootaddr_background"]["has_verified_jump_to_secondary"])
            self.assertTrue(all(not p.exists() for p in visited))

    def test_background_may_suppress_jump_in_combined_variant(self):
        with tempfile.TemporaryDirectory() as directory:
            reference = command(0xdb, bytes((0x13, 0x1f)))
            source = Path(directory) / "unused.txt"
            source.write_text("unused", encoding="ascii")
            paths = []
            def fake_runner(args, **kwargs):
                output = Path(args[-1])
                paths.append(output)
                body = reference
                if "--bootaddr" in args and "--background" not in args:
                    body = command(0xda, (0x200000).to_bytes(4, "little")) + body
                if "--background" in args:
                    body = command(0xc3, b"") + body
                output.write_bytes(body)
                return subprocess.CompletedProcess(args, 0, "", "")
            report = AUDIT.audit(source, reference, runner=fake_runner)
            self.assertTrue(report["bootaddr"]["has_verified_jump_to_secondary"])
            self.assertFalse(report["bootaddr_background"]["has_verified_jump_to_secondary"])
            self.assertEqual(report["bootaddr_background"]["first_32_hex"],
                             (command(0xc3, b"") + reference)[:32].hex())
            self.assertTrue(report["bootaddr_background"]["first_difference_windows"]["candidate_hex"])
            self.assertTrue(all(not p.exists() for p in paths))

    def test_raw_da_is_not_a_verified_jump(self):
        reference = b"plain" + bytes((0xda,)) + b"bytes"
        self.assertEqual(AUDIT.jump_opcode_windows(reference)[0]["offset"], "0x5")
        self.assertEqual(AUDIT.find_commands(reference), [])

    def test_diff_windows_bounded_and_equal(self):
        self.assertEqual(AUDIT.difference_windows(b"same", b"same"),
                         {"reference_hex": "", "candidate_hex": ""})
        windows = AUDIT.difference_windows(b"helloWORLD", b"helloTESTWORLD")
        self.assertEqual(windows["candidate_hex"], b"helloTESTWORLD".hex())
        self.assertEqual(windows["reference_hex"], b"helloWORLD".hex())

    def test_missing_jump_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            reference = command(0xdb, bytes((0x13, 0x1f)))
            def fake_runner(args, **kwargs):
                Path(args[-1]).write_bytes(reference)
                return subprocess.CompletedProcess(args, 0, "", "")
            with self.assertRaisesRegex(ValueError, "lacks a CRC-valid jump"):
                AUDIT.audit(Path(directory) / "dummy", reference, runner=fake_runner)

    def test_modified_default_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            def fake_runner(args, **kwargs):
                Path(args[-1]).write_bytes(b"unexpected")
                return subprocess.CompletedProcess(args, 0, "", "")
            with self.assertRaisesRegex(ValueError, "did not reproduce"):
                AUDIT.audit(Path(directory) / "dummy", b"reference", runner=fake_runner)

    def test_failed_packer_rejected(self):
        def fake_runner(args, **kwargs):
            return subprocess.CompletedProcess(args, 1, "", "unsupported flag")
        with self.assertRaisesRegex(RuntimeError, "unsupported flag"):
            AUDIT.audit("dummy", b"known", runner=fake_runner)

    def test_missing_inputs_rejected(self):
        with self.assertRaises(FileNotFoundError):
            AUDIT.verify_inputs("/impossible/missing.bit", "/impossible/missing.txt")


if __name__ == "__main__":
    unittest.main(verbosity=2)
