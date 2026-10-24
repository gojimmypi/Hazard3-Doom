#!/usr/bin/env python3
"""Offline mock-parser checks for GateMate configuration inspection."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "inspect-ulx5m-serv-gmunpack.py"
spec = importlib.util.spec_from_file_location("ulx5m_gmunpack_inspect", SOURCE)
inspector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inspector)


class UnpackTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.image = (inspector.GATEMATE_SYNC + b"X" * 91 + b"\x33" +
                      b"\x00" * 4 + b"\xff" * (inspector.FLASH_BYTES - 100))
        self.reference = self.root / "reference.bit"
        self.reference.write_bytes(inspector.GATEMATE_SYNC + b"REFERENCE-12345678")
        self.parser = self.root / "mock_gmunpack"
        self.parser.write_text(
            "#!/usr/bin/env python3\n"
            "import pathlib, sys\n"
            "src = pathlib.Path(sys.argv[1]).read_bytes()\n"
            "dst = pathlib.Path(sys.argv[2])\n"
            "if not src.startswith(bytes.fromhex('d901ed96')):\n"
            "    sys.exit(2)\n"
            "if len(src) > 100 and b'REFERENCE' not in src:\n"
            "    sys.exit(3)\n"
            "dst.write_text('mock parsed configuration\\n', encoding='ascii')\n",
            encoding="ascii", newline="\n")
        self.parser.chmod(0o755)
        self.patch_image = patch.object(inspector, "load_verified_flash", return_value=self.image)
        self.patch_image.start()
        self.addCleanup(self.patch_image.stop)

    def call_inspect(self, **kwargs):
        return inspector.inspect(self.root / "unused.zip", self.reference,
                                 str(self.parser), **kwargs)

    def test_factory_candidates_are_not_assumed_valid_boundaries(self):
        variants = inspector.input_variants(self.image)
        self.assertEqual(len(variants["observed_prefix"]), 100)
        self.assertEqual(len(variants["sector_aligned_prefix"]), 4096)
        self.assertEqual(len(variants["complete_flash"]), inspector.FLASH_BYTES)

    def test_bad_image_refused(self):
        with self.assertRaises(ValueError):
            inspector.input_variants(b"\xff" * inspector.FLASH_BYTES)
        with self.assertRaises(ValueError):
            inspector.input_variants(b"short")

    def test_successful_reference_and_prefix_not_write_authorized(self):
        result = self.call_inspect()
        self.assertTrue(result["reference"]["parser_succeeded"])
        self.assertTrue(result["factory_attempts"]["observed_prefix"]["parser_succeeded"])
        self.assertFalse(result["factory_attempts"]["sector_aligned_prefix"]["parser_succeeded"])
        self.assertFalse(result["factory_attempts"]["complete_flash"]["parser_succeeded"])
        self.assertFalse(result["factory_stream_end_verified"])
        self.assertFalse(result["write_authorized"])
        self.assertFalse(result["secondary_boot_layout_verified"])

    def test_no_outputs_created_without_explicit_paths(self):
        self.call_inspect()
        self.assertEqual(sorted(p.name for p in self.root.iterdir()),
                         ["mock_gmunpack", "reference.bit"])

    def test_optional_configs_and_json_create_only(self):
        folder = self.root / "configs"
        report = self.root / "report.json"
        result = self.call_inspect(output_dir=folder, json_out=report)
        self.assertEqual(len(list(folder.glob("*.config"))), 1)
        self.assertTrue(report.is_file())
        self.assertIn('"write_authorized": false', report.read_text())
        self.assertFalse(result["write_authorized"])
        with self.assertRaisesRegex(ValueError, "existing output directory"):
            self.call_inspect(output_dir=folder)
        with self.assertRaisesRegex(ValueError, "overwrite report"):
            self.call_inspect(json_out=report)

    def test_reference_must_parse_before_factory(self):
        self.parser.write_text("#!/usr/bin/env python3\nimport sys\nsys.exit(4)\n",
                               encoding="ascii")
        self.parser.chmod(0o755)
        with self.assertRaisesRegex(ValueError, "known SERV reference"):
            self.call_inspect()

    def test_short_reference_refused(self):
        self.reference.write_bytes(b"NOT GATEMATE")
        with self.assertRaisesRegex(ValueError, "lacks the GateMate signature"):
            self.call_inspect()

    def test_missing_parser_refused(self):
        with self.assertRaisesRegex(ValueError, "does not exist"):
            inspector.locate_gmunpack(str(self.root / "absent"))

    def test_empty_parser_output_not_reported_as_success(self):
        self.parser.write_text("#!/usr/bin/env python3\nimport sys\nsys.exit(0)\n",
                               encoding="ascii")
        self.parser.chmod(0o755)
        with self.assertRaisesRegex(ValueError, "known SERV reference"):
            self.call_inspect()

    def test_timeout_never_authorizes_write(self):
        self.parser.write_text("#!/usr/bin/env python3\nimport time\ntime.sleep(5)\n",
                               encoding="ascii")
        self.parser.chmod(0o755)
        with tempfile.TemporaryDirectory() as workspace:
            outcome = inspector.unpack_one(str(self.parser), "timeout",
                                           b"binary", Path(workspace), timeout=0.05)
        self.assertFalse(outcome["parser_succeeded"])
        self.assertIn("timed out", outcome["diagnostic"])

    @staticmethod
    def crc_frame(command, payload):
        header = bytes((command, len(payload)))
        header_crc = inspector.crc16_x25(header).to_bytes(2, "little")
        prefix = header + header_crc + payload
        return prefix + inspector.crc16_x25(prefix).to_bytes(2, "little")

    def padded_pll_stream(self):
        return (self.crc_frame(0xd9, b"\x10") + bytes.fromhex("000000003300000000") +
                self.crc_frame(0xc1, bytes(range(24))) + bytes(12) +
                self.crc_frame(0xce, b"\x00\x01") + b"\x33")

    def test_pll_padding_crc_checked(self):
        original = self.padded_pll_stream()
        normal, offsets = inspector.trim_pll_padding_for_parser(original)
        self.assertEqual(offsets, [16])
        self.assertEqual(len(normal), len(original) - 4)
        self.assertEqual(normal[:16], original[:16])
        self.assertEqual(normal[-9:], original[-9:])
        self.assertEqual(original, self.padded_pll_stream())

    def test_pll_padding_probe_lengths(self):
        original = self.padded_pll_stream()
        start = original.find(bytes.fromhex("ce02"))
        self.assertGreater(start, 0)
        for keep in (8, 6, 4, 0):
            adjusted, offsets = inspector.trim_pll_padding_for_parser(
                original, keep_pad_bytes=keep)
            self.assertEqual(offsets, [16])
            self.assertEqual(len(adjusted), len(original) - (12 - keep))
            self.assertEqual(adjusted.find(bytes.fromhex("ce02")),
                             start - (12 - keep))
        self.assertEqual(original, self.padded_pll_stream())
        with self.assertRaises(ValueError):
            inspector.trim_pll_padding_for_parser(original, keep_pad_bytes=3)

    def test_probe_recovers_only_after_12_to_4_adjustment(self):
        stream = self.padded_pll_stream()
        self.reference.write_bytes(stream)
        original_flash = stream + b"\xff" * (inspector.FLASH_BYTES - len(stream))
        expected_offset = stream.find(bytes.fromhex("ce02")) - 8
        self.parser.write_text(
            "#!/usr/bin/env python3\n"
            "import pathlib, sys\n"
            "src = pathlib.Path(sys.argv[1]).read_bytes()\n"
            "offset = src.find(bytes.fromhex('ce02'))\n"
            "if offset != %d:\n" % expected_offset +
            "    print('Bitstream Parse Error: Unhandled command 0x00 [at 0x0000003d]')\n"
            "    sys.exit(7)\n"
            "pathlib.Path(sys.argv[2]).write_text('config\\n')\n",
            encoding="ascii", newline="\n")
        self.parser.chmod(0o755)
        before = self.reference.read_bytes()
        with patch.object(inspector, "load_verified_flash", return_value=original_flash):
            with self.assertRaisesRegex(ValueError, "known SERV reference"):
                self.call_inspect(pll_padding_compat=True)
            result = self.call_inspect(pll_padding_probe=True)
        self.assertTrue(result["reference"]["parser_succeeded"])
        self.assertEqual([p["kept_padding_bytes"] for p in result["reference_probes"]],
                         [8, 6, 4])
        self.assertFalse(result["reference_probes"][0]["result"]["parser_succeeded"])
        self.assertFalse(result["reference_probes"][1]["result"]["parser_succeeded"])
        self.assertTrue(result["reference_probes"][2]["result"]["parser_succeeded"])
        self.assertEqual(result["pll_padding_kept_bytes"], 4)
        self.assertTrue(result["factory_attempts"]["observed_prefix"]["parser_succeeded"])
        self.assertFalse(result["write_authorized"])
        self.assertEqual(self.reference.read_bytes(), before)

    def test_probe_recovers_with_six_padding_bytes(self):
        stream = self.padded_pll_stream()
        self.reference.write_bytes(stream)
        original_flash = stream + b"\xff" * (inspector.FLASH_BYTES - len(stream))
        expected_offset = stream.find(bytes.fromhex("ce02")) - 6
        self.parser.write_text(
            "#!/usr/bin/env python3\n"
            "import pathlib, sys\n"
            "src = pathlib.Path(sys.argv[1]).read_bytes()\n"
            "if src[%d:%d] != bytes.fromhex('ce02'):\n" % (
                expected_offset, expected_offset + 2) +
            "    print('Bitstream Parse Error: Unhandled command 0x00')\n"
            "    sys.exit(7)\n"
            "pathlib.Path(sys.argv[2]).write_text('config\\n')\n",
            encoding="ascii", newline="\n")
        self.parser.chmod(0o755)
        before = self.reference.read_bytes()
        with patch.object(inspector, "load_verified_flash", return_value=original_flash):
            result = self.call_inspect(pll_padding_probe=True)
        self.assertEqual([p["kept_padding_bytes"] for p in result["reference_probes"]],
                         [8, 6])
        self.assertFalse(result["reference_probes"][0]["result"]["parser_succeeded"])
        self.assertTrue(result["reference_probes"][1]["result"]["parser_succeeded"])
        self.assertEqual(result["pll_padding_kept_bytes"], 6)
        self.assertTrue(result["factory_attempts"]["observed_prefix"]["parser_succeeded"])
        self.assertFalse(result["write_authorized"])
        self.assertEqual(self.reference.read_bytes(), before)

    def test_probe_all_fails_and_does_not_test_factory(self):
        stream = self.padded_pll_stream()
        self.reference.write_bytes(stream)
        self.parser.write_text(
            "#!/usr/bin/env python3\n"
            "import sys\n"
            "print('Bitstream Parse Error: Unhandled command 0x00 [at 0x0000003d]')\n"
            "sys.exit(7)\n", encoding="ascii", newline="\n")
        self.parser.chmod(0o755)
        with self.assertRaisesRegex(ValueError, "keep8:.*keep6:.*keep4:.*keep0:"):
            self.call_inspect(pll_padding_probe=True)
        self.assertEqual(sorted(x.name for x in self.root.iterdir()),
                         ["mock_gmunpack", "reference.bit"])
        with self.assertRaisesRegex(ValueError, "only one PLL"):
            self.call_inspect(pll_padding_compat=True, pll_padding_probe=True)

    def test_bad_crc_or_padding_never_changed(self):
        original = bytearray(self.padded_pll_stream())
        original[18] ^= 1  # C1 command header CRC byte
        fixed, offsets = inspector.trim_pll_padding_for_parser(bytes(original))
        self.assertEqual(fixed, original)
        self.assertEqual(offsets, [])
        original = bytearray(self.padded_pll_stream())
        original[16 + 4 + 24 + 2 + 11] = 0x77  # Nonzero padding byte
        fixed, offsets = inspector.trim_pll_padding_for_parser(bytes(original))
        self.assertEqual(fixed, original)
        self.assertEqual(offsets, [])
        original = bytearray(self.padded_pll_stream())
        original[-7] ^= 1  # Following CE command header CRC
        fixed, offsets = inspector.trim_pll_padding_for_parser(bytes(original))
        self.assertEqual(fixed, original)
        self.assertEqual(offsets, [])

    def test_compat_fallback_requires_opt_in_and_keeps_original(self):
        stream = self.padded_pll_stream()
        original_flash = (stream + b"\xff" * (inspector.FLASH_BYTES - len(stream)))
        self.reference.write_bytes(stream)
        self.parser.write_text(
            "#!/usr/bin/env python3\n"
            "import pathlib, sys\n"
            "src = pathlib.Path(sys.argv[1]).read_bytes()\n"
            "if bytes(12) + bytes.fromhex('ce02') in src:\n"
            "    print('Bitstream Parse Error: Unhandled command 0x00 [at 0x0000003d]')\n"
            "    sys.exit(7)\n"
            "pathlib.Path(sys.argv[2]).write_text('config\\n')\n",
            encoding="ascii", newline="\n")
        self.parser.chmod(0o755)
        before = self.reference.read_bytes()
        with patch.object(inspector, "load_verified_flash", return_value=original_flash):
            with self.assertRaisesRegex(ValueError, "known SERV reference"):
                self.call_inspect()
            result = self.call_inspect(pll_padding_compat=True)
        self.assertTrue(result["reference"]["parser_succeeded"])
        self.assertEqual(result["reference_original"]["returncode"], 7)
        self.assertTrue(result["pll_padding_compat_used"])
        self.assertEqual(result["reference_pll_offsets"], [16])
        self.assertEqual(result["factory_attempts"]["observed_prefix"]["pll_padding_offsets"],
                         [16])
        self.assertFalse(result["write_authorized"])
        self.assertFalse(result["factory_stream_end_verified"])
        self.assertEqual(self.reference.read_bytes(), before)

    def test_compat_never_rescues_non_padding_parse_failure(self):
        self.parser.write_text("#!/usr/bin/env python3\nimport sys\nsys.exit(4)\n",
                               encoding="ascii", newline="\n")
        self.parser.chmod(0o755)
        with self.assertRaisesRegex(ValueError, "No CRC-verified"):
            self.call_inspect(pll_padding_compat=True)



if __name__ == "__main__":
    unittest.main(verbosity=2)
