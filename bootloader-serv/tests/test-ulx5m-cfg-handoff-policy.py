#!/usr/bin/env python3
"""Prove that CFG primitive presence alone never authorizes a live handoff."""

import re
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
FW = ROOT / 'fw'


class ConfigHandoffPolicy(unittest.TestCase):
    def test_compile_gate(self):
        for cfg, approval, expected in (
            (False, None, 0),
            (True, None, 0),
            (False, 1, 0),
            (True, 0, 0),
            (True, 1, 1),
        ):
            with self.subTest(cfg=cfg, approval=approval):
                args = ['gcc', '-E', '-P', '-DBOARD_ULX5M_GS=1',
                        '-DULX5M_SERV_TEST=1',
                        '-DULX5M_NORMAL_BOOT_EXPERIMENT=1',
                        '-DULX5M_DFU_STREAM_ONLY=1',
                        '-I', str(FW)]
                if cfg:
                    args.append('-DULX5M_ENABLE_CFG_STREAM=1')
                if approval is not None:
                    args.append(f'-DULX5M_CFG_HANDOFF_AUTHORIZED={approval}')
                args.append(str(FW / 'fw_ulx5m_flash_read.c'))
                out = subprocess.run(args, check=True, capture_output=True,
                                     text=True).stdout
                values = re.findall(r'const int authorize\s*=\s*([01])\s*;', out)
                self.assertEqual(values, [str(expected)])

    def test_offline_target_cannot_activate_handoff(self):
        makefile = (ROOT / 'Makefile.ulx5m-gs').read_text(encoding='ascii')
        fw_makefile = (FW / 'Makefile.ulx5m-flash-read').read_text(encoding='ascii')
        self.assertIn('-DULX5M_ENABLE_CFG_STREAM', makefile)
        self.assertIn('CFG_STREAM_ENABLE=1', makefile)
        self.assertNotIn('ULX5M_CFG_HANDOFF_AUTHORIZED', makefile)
        self.assertNotIn('ULX5M_CFG_HANDOFF_AUTHORIZED', fw_makefile)
        self.assertIn('normal-boot-cfg-offline', makefile)


if __name__ == '__main__':
    unittest.main(verbosity=2)
