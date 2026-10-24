#!/usr/bin/env python3
"""Host-only regressions for GateMate hardware handoff evidence audit."""

import hashlib
import contextlib
import io
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SRC = Path(__file__).with_name("audit-ulx5m-cfg-hardware-evidence.py")
SPEC = importlib.util.spec_from_file_location("ulx5m_cfg_evidence_v31", SRC)
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


def command(status):
    header = bytes.fromhex("db0c")
    payload = bytes((status, 0x1f)) + bytes.fromhex("00200000000000000000")
    cmd = header + MOD.crc16_x25(header).to_bytes(2, "little") + payload
    return cmd + MOD.crc16_x25(cmd).to_bytes(2, "little")


def fixture():
    prefix = bytes([0x21]) * MOD.STATUS_COMMAND_OFFSET
    default = prefix + command(0x13) + MOD.EPILOGUE
    reconfig = prefix + command(0x1b) + MOD.EPILOGUE
    source = bytes([0x72]) * 30700 + command(0x1b) + MOD.EPILOGUE
    rtl = "CC_CFG_CTRL cfg_i (.RECFG(1'b1)); assign led_n = state == FINISHED;"
    return default, reconfig, source, rtl


class EvidenceAuditTests(unittest.TestCase):
    def setUp(self):
        self.default, self.reconfig, self.source, self.rtl = fixture()
        self.hashes = (patch.object(MOD, "APP_SHA", hashlib.sha256(self.default).hexdigest()),
                       patch.object(MOD, "RECONFIG_SHA", hashlib.sha256(self.reconfig).hexdigest()),
                       patch.object(MOD, "SOURCE_SHA", hashlib.sha256(self.source).hexdigest()))
        for patcher in self.hashes:
            patcher.start()
            self.addCleanup(patcher.stop)

    def check(self, a=None, b=None, c=None, rtl=None):
        return MOD.audit_images(a if a is not None else self.default,
                                b if b is not None else self.reconfig,
                                c if c is not None else self.source,
                                rtl if rtl is not None else self.rtl)

    def test_success(self):
        info = self.check()
        self.assertEqual(info["source_probe"]["status"], "0x1b")
        self.assertEqual(info["app_reconfig"]["changed_range"], [3003, 3017])
        self.assertIn("not observable", info["source_probe"]["configuration_accepted"])

    def test_crc_reference(self):
        self.assertEqual(MOD.crc16_x25(b"123456789"), 0x906e)
        self.assertEqual(command(0x13).hex(),
                         "db0cb87e131f002000000000000000006ca1")

    def test_bad_application_sha(self):
        corrupt = bytearray(self.default)
        corrupt[20] ^= 1
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            self.check(a=bytes(corrupt))

    def test_unexpected_byte_outside_status(self):
        corrupt = bytearray(self.reconfig)
        corrupt[100] ^= 1
        with patch.object(MOD, "RECONFIG_SHA", hashlib.sha256(corrupt).hexdigest()):
            with self.assertRaisesRegex(ValueError, "unexpected changes"):
                self.check(b=bytes(corrupt))

    def test_bad_status_crc(self):
        corrupt = bytearray(self.reconfig)
        corrupt[3015] ^= 1
        with patch.object(MOD, "RECONFIG_SHA", hashlib.sha256(corrupt).hexdigest()):
            with self.assertRaisesRegex(ValueError, "CRC mismatch"):
                self.check(b=bytes(corrupt))

    def test_source_wrong_status(self):
        corrupt = self.source[:-27] + command(0x13) + self.source[-9:]
        with patch.object(MOD, "SOURCE_SHA", hashlib.sha256(corrupt).hexdigest()):
            with self.assertRaisesRegex(ValueError, "source does not have"):
                self.check(c=corrupt)

    def test_missing_primitive_or_reconfig(self):
        with self.assertRaisesRegex(ValueError, "RECFG=1"):
            self.check(rtl="CC_CFG_CTRL cfg_i (.RECFG(1'b0)); state == FINISHED")

    def test_missing_finished_output(self):
        with self.assertRaisesRegex(ValueError, "FINISHED"):
            self.check(rtl="CC_CFG_CTRL cfg_i (.RECFG(1'b1));")

    def test_truncated_command(self):
        with self.assertRaisesRegex(ValueError, "truncated"):
            MOD.status_command(b"\xdb\x0c", 0)

    def test_create_only_output_and_no_hardware_operation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, payload in (("default.bit", self.default),
                                  ("reconfig.bit", self.reconfig),
                                  ("source.bit", self.source)):
                (root / name).write_bytes(payload)
            (root / "probe.v").write_text(self.rtl, encoding="utf-8")
            argv = ["--default-bit", str(root / "default.bit"),
                    "--reconfig-bit", str(root / "reconfig.bit"),
                    "--source-bit", str(root / "source.bit"),
                    "--source-rtl", str(root / "probe.v"),
                    "--json-out", str(root / "evidence.json")]
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(MOD.main(argv), 0)
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(MOD.main(argv), 1)
            self.assertEqual(len(self.default), (root / "default.bit").stat().st_size)


if __name__ == "__main__":
    unittest.main(verbosity=2)
