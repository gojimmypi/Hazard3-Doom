#!/usr/bin/env python3
"""Host-only tests for ULX5M-GS factory configuration observations."""

import importlib.util
import io
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "factory_config", HERE / "inspect-ulx5m-serv-factory-config.py")
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class FactoryConfigurationTests(unittest.TestCase):
    def test_observed_prefix_not_interpreted_as_flash_layout(self):
        image = (config.GATEMATE_SYNC + b"\x00" * 12 + b"test" +
                 b"\xff" * (config.FLASH_BYTES - 20))
        result = config.inspect(image)
        self.assertEqual(result["sync_signature_offsets"], [0])
        self.assertEqual(result["last_non_ff_offset"], 19)
        self.assertEqual(result["first_all_ff_sector_start"], 4096)
        self.assertFalse(result["write_authorized"])
        self.assertFalse(result["candidate_bitstream_end_verified"])
        self.assertFalse(result["secondary_configuration_absence_verified"])

    def test_secondary_header_is_reported_but_not_interpreted(self):
        image = bytearray(b"\xff" * config.FLASH_BYTES)
        image[:16] = config.GATEMATE_SYNC + b"\x00" * 12
        image[0x22000:0x22004] = config.GATEMATE_SYNC
        self.assertEqual(config.inspect(bytes(image))["sync_signature_offsets"],
                         [0, 0x22000])

    def test_reference_is_informational(self):
        image = config.GATEMATE_SYNC + b"\x00" * 12 + b"\x01" + (
            b"\xff" * (config.FLASH_BYTES - 17))
        reference = image[:16] + b"\x02" + b"\x00" * 10
        result = config.inspect(image, reference)
        self.assertEqual(result["reference"]["identical_prefix_bytes"], 16)
        self.assertTrue(result["reference"]["same_16_byte_preamble"])
        self.assertFalse(result["write_authorized"])

    def test_non_gatemate_and_truncated_rejected(self):
        with self.assertRaises(ValueError):
            config.inspect(b"\xff" * config.FLASH_BYTES)
        with self.assertRaises(ValueError):
            config.inspect(config.GATEMATE_SYNC)

    def test_real_backup_must_pass_existing_verification(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "flash-pass1.bin").write_bytes(b"\x00" * 10)
            with self.assertRaises((ValueError, OSError, KeyError)):
                config.load_verified_backup(path)

    def test_no_file_written_unless_requested(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            out = path / "result.json"
            # Fail before opening any output if backup is absent.
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(config.main(["--input", str(path),
                                              "--json-out", str(out)]), 1)
            self.assertFalse(out.exists())

    def test_pattern_is_not_an_eof_validator(self):
        image = (config.GATEMATE_SYNC + b"\x00" * 12 +
                 config.OBSERVED_TRAILER + b"PAYLOAD" +
                 b"\xff" * (config.FLASH_BYTES - 28))
        result = config.inspect(image)
        self.assertEqual(result["observed_trailer_offsets"], [16])
        self.assertEqual(result["last_non_ff_offset"], 27)
        self.assertFalse(result["candidate_bitstream_end_verified"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
