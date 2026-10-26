#!/usr/bin/env python3
"""Offline create-only sector-image preparation tests. No hardware modules."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("ulx5m_prep", HERE / "prepare-ulx5m-v52-spi-primary.py")
prep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prep)


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.primary = prep.MAGIC + b"\x91" * (prep.PRIMARY_BYTES - 4)
        self.factory = bytearray(prep.MAGIC + b"\xff" * (prep.FLASH_BYTES - 4))
        # Factory data in the partial final 64 KiB block MUST be preserved.
        self.factory[0x64000:0x70000] = b"\x53" * (0x70000 - 0x64000)
        self.factory = bytes(self.factory)
        self.sector = prep.MAGIC + b"\x39" * (prep.ERASE_BYTES - 4)
        self.hash_patches = [
            patch.object(prep, "PRIMARY_SHA", prep.digest(self.primary)),
            patch.object(prep, "FACTORY_SHA", prep.digest(self.factory)),
            patch.object(prep, "SECTOR_SHA", prep.digest(self.sector)),
        ]
        for p in self.hash_patches:
            p.start(); self.addCleanup(p.stop)

    def test_exact_region_and_protected_bytes(self):
        proposed, restore, evidence = prep.build(self.primary, self.factory, self.factory, self.sector)
        self.assertEqual(len(proposed), 7 * 65536)
        self.assertEqual(proposed[:len(self.primary)], self.primary)
        self.assertEqual(proposed[len(self.primary):0x64000], b"\xff" * (0x64000 - len(self.primary)))
        self.assertEqual(proposed[0x64000:], self.factory[0x64000:0x70000])
        self.assertEqual(restore, self.factory[:len(restore)])
        self.assertEqual(evidence["programming_authorized"], False)
        full = bytearray(self.factory)
        full[:len(proposed)] = proposed
        full[prep.SECONDARY:prep.SECONDARY + 4096] = self.sector
        self.assertEqual(evidence["expected_full_flash_sha256_after_controlled_install"], prep.digest(full))
        self.assertEqual(full[len(proposed):prep.SECONDARY], self.factory[len(proposed):prep.SECONDARY])

    def test_corrupt_primary_or_secondary_rejected(self):
        with self.assertRaises(ValueError):
            prep.build(self.primary[:-1] + b"X", self.factory, self.factory, self.sector)
        with self.assertRaises(ValueError):
            prep.build(self.primary, self.factory, self.factory, self.sector[:-1] + b"X")

    def test_factory_disagreement_rejected(self):
        with self.assertRaises(ValueError):
            prep.build(self.primary, self.factory, self.factory[:-1] + b"X", self.sector)

    def test_input_magic_required(self):
        with patch.object(prep, "PRIMARY_SHA", prep.digest(b"\x00" * len(self.primary))):
            with self.assertRaisesRegex(ValueError, "magic"):
                prep.build(b"\x00" * len(self.primary), self.factory, self.factory, self.sector)

    def test_new_files_only(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name, data in (("primary", self.primary), ("factory1", self.factory),
                               ("factory2", self.factory), ("sector", self.sector)):
                (root / name).write_bytes(data)
            class Args:
                primary = str(root / "primary")
                factory_pass1 = str(root / "factory1")
                factory_pass2 = str(root / "factory2")
                sector_dump = str(root / "sector")
                output_dir = str(root / "outputs")
            manifest = prep.prepare(Args)
            self.assertFalse(manifest["programming_authorized"])
            self.assertEqual(len(list((root / "outputs").iterdir())), 3)
            with self.assertRaisesRegex(ValueError, "exists"):
                prep.prepare(Args)


if __name__ == "__main__":
    unittest.main(verbosity=2)
