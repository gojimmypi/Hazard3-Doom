#!/usr/bin/env python3
"""Offline-only mutation/unit tests for v63c frozen gmpack --reconfig A/B."""
import importlib.util
from pathlib import Path
from unittest import TestCase, main, mock
import hashlib
import json
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
spec = importlib.util.spec_from_file_location('v63c', HERE / 'qualify-ulx5m-v63c-reconfig-primary.py')
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


class V63cOffline(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inst = a.IMPLEMENTATION.read_bytes()
        cls.baseline = a.BASELINE.read_bytes()
        cls.mk = a.MAKE.read_text(encoding='ascii')

    def test_frozen_source_guard(self):
        a.assert_frozen(self.baseline, self.inst, self.mk)
        self.assertEqual(hashlib.sha256(self.baseline).hexdigest(), a.BASELINE_SHA)

    def test_predicted_variant_is_isolated(self):
        candidate = a.predict_variant(self.baseline)
        info = a.validate_variant(self.baseline, candidate)
        self.assertEqual(info['sha256'], '689f17a6b2e5ba1669e8f7652da4163b2d824ec91878b767e202ca1b33b9d4a2')
        self.assertEqual(info['changed_offsets'], ['0x06d0df', '0x06d0eb', '0x06d0ec'])

    def test_primary_fabric_mutation_rejected(self):
        bad = bytearray(self.baseline)
        bad[0x340] ^= 1
        with self.assertRaises(ValueError):
            a.assert_frozen(bytes(bad), self.inst, self.mk)

    def test_implementation_mutation_rejected(self):
        bad = bytearray(self.inst)
        bad[100] ^= 1
        with self.assertRaises(ValueError):
            a.assert_frozen(self.baseline, bytes(bad), self.mk)

    def test_makefile_changed_rejected(self):
        for changed in (self.mk.replace('2101248', '2097152'),
                        self.mk + '\n# --reconfig\n',
                        self.mk.replace('--bootaddr', '--reconfig --bootaddr')):
            with self.subTest(change=changed[-30:]):
                with self.assertRaises(ValueError):
                    a.assert_frozen(self.baseline, self.inst, changed)

    def test_jump_mutation_rejected(self):
        bad = bytearray(a.predict_variant(self.baseline))
        bad[-7] ^= 1
        with self.assertRaises(ValueError):
            a.validate_variant(self.baseline, bytes(bad))

    def test_status_mutation_rejected(self):
        bad = bytearray(a.predict_variant(self.baseline))
        bad[a.STATUS_OFFSET + 4] = 0x17
        with self.assertRaises(ValueError):
            a.validate_variant(self.baseline, bytes(bad))

    def test_body_crc_mutation_rejected(self):
        bad = bytearray(a.predict_variant(self.baseline))
        bad[a.STATUS_OFFSET + 16] ^= 1
        with self.assertRaises(ValueError):
            a.validate_variant(self.baseline, bytes(bad))

    def test_simulated_packer_accept_and_fail_closed(self):
        """Mock subprocess only; never interpret mock pass as real gmpack."""
        with tempfile.TemporaryDirectory(prefix='v63c-test-') as td:
            scratch = Path(td)
            for name, content in (('primary.bit', self.baseline), ('design.txt', self.inst)):
                (scratch / name).write_bytes(content)
            (scratch / 'Makefile').write_text(self.mk, encoding='ascii')
            base_args = dict(baseline_path=scratch / 'primary.bit',
                             implementation_path=scratch / 'design.txt',
                             makefile_path=scratch / 'Makefile',
                             output_root=scratch, packer='/usr/bin/fake-gmpack', save=True)

            def correct_fake(argv, **kw):
                self.assertEqual(argv[1:4], ['--reconfig', '--bootaddr', str(a.BOOTADDR)])
                Path(argv[-1]).write_bytes(a.predict_variant(self.baseline))

            with mock.patch.object(a.subprocess, 'run', side_effect=correct_fake):
                info = a.qualify(**base_args)
            self.assertEqual(info['candidate_status'], '0x1f')
            generated = list(scratch.glob('v63c-reconfig-PACK-ONLY-*/manifest.json'))
            self.assertEqual(len(generated), 1)
            data = json.loads(generated[0].read_text())
            self.assertFalse(data['secondary_takeover_verified_on_hardware'])
            self.assertEqual(data['reconfiguration_command_for_bank_restore'], 'UNKNOWN')

            def wrong_fake(argv, **kw):
                changed = bytearray(a.predict_variant(self.baseline))
                changed[0x400] ^= 1
                Path(argv[-1]).write_bytes(changed)

            with mock.patch.object(a.subprocess, 'run', side_effect=wrong_fake):
                with self.assertRaises(ValueError):
                    a.qualify(**{**base_args, 'save': False})
            self.assertEqual(len(list(scratch.glob('v63c-reconfig-PACK-ONLY-*'))), 1)


if __name__ == '__main__':
    main(verbosity=2)
