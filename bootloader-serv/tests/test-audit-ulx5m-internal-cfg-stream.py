#!/usr/bin/env python3
"""Host-only regression suite. This invokes NO gmpack or hardware commands."""
import importlib.util
import pathlib
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

P = pathlib.Path(__file__).with_name('audit-ulx5m-internal-cfg-stream.py')
spec = importlib.util.spec_from_file_location('audit', P)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def command(opcode, payload):
    prefix = bytes([opcode, len(payload)])
    return (prefix + audit.crc16_x25(prefix).to_bytes(2, 'little') + payload +
            audit.crc16_x25(prefix + audit.crc16_x25(prefix).to_bytes(2, 'little') + payload).to_bytes(2, 'little'))


def stream(status):
    body = b'\xd9\x01\xed\x96' + b'X' * 100
    tail = command(0xdb, bytes([status, 0x1f]) + b'\x00\x20' + b'\x00' * 8)
    return body + tail + b'\x00\x00\x00\x00\x33\x00\x00\x00\x00'


class AuditTests(unittest.TestCase):
    def test_crc_verified_status(self):
        data = stream(0x13)
        found = audit.scan_tail(data)
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0]['name'], 'CMD_CHG_STATUS')
        self.assertEqual(found[0]['status_byte'], '0x13')
        self.assertFalse(found[0]['reconfig_status_bit'])
        changed = bytearray(data)
        changed[found[0]['offset'] + 4] ^= 0x08
        self.assertEqual(audit.scan_tail(changed), [])

    def test_reconfig_flag(self):
        cmd = audit.scan_tail(stream(0x1b))[0]
        self.assertTrue(cmd['reconfig_status_bit'])

    def test_diff(self):
        same = audit.difference(b'abc', b'abc')
        self.assertIsNone(same['first_difference'])
        change = audit.difference(b'abcdef', b'abcXYZdef')
        self.assertEqual(change['common_prefix'], 3)
        self.assertEqual(change['common_suffix'], 3)
        self.assertEqual(change['size_delta'], 3)

    def test_wrong_fixture_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            a = pathlib.Path(tmp) / 'x.bit'
            b = pathlib.Path(tmp) / 'x.txt'
            a.write_bytes(b'not the image')
            b.write_bytes(b'not the implementation')
            with self.assertRaisesRegex(ValueError, 'does not match'):
                audit.load_reference(a, b)
            with self.assertRaisesRegex(ValueError, 'v26 probe'):
                audit.check_source_probe(a)

    def test_matrix_flags_and_cleanup(self):
        reference = stream(0x13)
        recorded = []
        def mock_run(cmd, **kwargs):
            self.assertEqual(cmd[0], 'gmpack')
            recorded.append(cmd[1:-2])
            output = pathlib.Path(cmd[-1])
            if '--reconfig' in cmd:
                data = stream(0x1b)
            else:
                data = reference
            if '--reset' in cmd:
                data += command(0xc3, b'\x00')
            output.write_bytes(data)
            return types.SimpleNamespace(returncode=0, stderr='', stdout='')
        with patch.object(audit.subprocess, 'run', side_effect=mock_run):
            outputs = audit.pack_variants('synthetic.txt', reference)
        self.assertEqual(recorded, [[], ['--reconfig'], ['--reset'],
                                    ['--reset', '--reconfig']])
        self.assertEqual(outputs['default']['length'], len(reference))
        self.assertEqual(outputs['reconfig']['tail_commands'][0]['status_byte'], '0x1b')
        self.assertIn('CMD_CFGRST', [c['name'] for c in outputs['reset']['tail_commands']])

    def test_wrong_default_rejected(self):
        with patch.object(audit.subprocess, 'run') as mocked:
            def mock_run(cmd, **kwargs):
                pathlib.Path(cmd[-1]).write_bytes(b'changed')
                return types.SimpleNamespace(returncode=0, stderr='', stdout='')
            mocked.side_effect = mock_run
            with self.assertRaisesRegex(ValueError, 'default gmpack output differs'):
                audit.pack_variants('synthetic.txt', stream(0x13))

    def test_failed_gmpack_rejected(self):
        with patch.object(audit.subprocess, 'run',
                          return_value=types.SimpleNamespace(returncode=1,
                                                             stderr='deliberate failure', stdout='')):
            with self.assertRaisesRegex(RuntimeError, 'deliberate failure'):
                audit.pack_variants('synthetic.txt', stream(0x13))


if __name__ == '__main__':
    unittest.main(verbosity=2)
