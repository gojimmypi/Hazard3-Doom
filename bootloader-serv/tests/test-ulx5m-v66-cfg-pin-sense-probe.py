#!/usr/bin/env python3
"""v66 offline tests: six input-only flash GPIOs vs v65 no-flash-pad primary."""
import importlib.util
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOP = ROOT / 'rtl/top-ulx5m-gs-v66-cfg-pin-sense-probe.v'
CCF = ROOT / 'data/top-ulx5m-gs-v66-cfg-pin-sense-probe.ccf'
SDC = ROOT / 'data/top-ulx5m-gs-v66-cfg-pin-sense-probe.sdc'
MAKE = ROOT / 'Makefile.ulx5m-v66-cfg-pin-sense-probe'
QUAL = ROOT / 'tests/qualify-ulx5m-v66-cfg-pin-sense-probe.py'
spec = importlib.util.spec_from_file_location('v66_check', QUAL)
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)

class V66(unittest.TestCase):
    def test_six_inputs_exactly_pinned_and_never_driven(self):
        ccf = CCF.read_text(encoding='ascii')
        assignments = re.findall(r'^Pin_(in|out|inout)\s+"([^"]+)"\s+Loc\s*=\s*"([^"]+)"', ccf, re.M)
        pins = {port: (direction,pad) for direction,port,pad in assignments}
        self.assertEqual(len(pins), 15)
        self.assertEqual(len(assignments), len(pins))
        for port, pad in q.PINMAP.items():
            self.assertEqual(pins[port], ('in',pad))
        self.assertEqual(pins['clk25'], ('in','IO_SB_A8'))
        for i in range(8):
            self.assertEqual(pins['led_n[%d]' % i][0], 'out')

    def test_source_input_only_recfg_and_comparator(self):
        rtl = TOP.read_text(encoding='ascii')
        for tag in ('input wire [3:0] flash_io', 'input wire flash_cs_n',
                    'input wire flash_sck', 'sensor_parity <= ^{flash_io, flash_cs_n, flash_sck};',
                    'wire recfg = &start_count;',".CLK(1'b0), .EN(1'b0), .DATA(8'b0)",
                    ".VALID(1'b0), .RECFG(recfg)"):
            self.assertIn(tag,rtl)
        self.assertNotIn('inout wire',rtl)
        self.assertNotIn('output wire flash_',rtl)
        self.assertNotIn('qspi_',rtl)
        self.assertNotIn('USB',rtl.split('module')[1])
        self.assertEqual(rtl.count('CC_CFG_CTRL cfg_i'),1)

    def test_makefile_packonly_timing_and_no_programmer(self):
        s = MAKE.read_text(encoding='ascii')
        self.assertIn('V66_BOOTADDR := 2101248',s)
        self.assertIn('$(GMPACK) --bootaddr $(V66_BOOTADDR)',s)
        self.assertIn('python3 tests/qualify-ulx5m-v66-cfg-pin-sense-probe.py',s)
        self.assertNotIn('--reconfig',s)
        self.assertNotIn('openFPGALoader',s)
        self.assertNotIn('include ',s)
        self.assertIn('create_clock -name clk25 -period 40.000', SDC.read_text())

    def test_placement_evidence_required(self):
        # Prefer the historical real v43 locally built bitstream when present.
        p = ROOT / 'build-ulx5m-gs/cfg-probe/top_ulx5m_gs_cfg_probe-bootaddr-201000-v43.bit'
        if p.is_file():
            bit = p.read_bytes()
            self.assertEqual(__import__('hashlib').sha256(bit).hexdigest(),
                             '2195166eb2035d9fb0ca22d99b37fd4ea8ba49488e808cf864eee0df127dddc0')
        else:
            m=q.v65_parser()
            hdr=b'\xdb\x0c'
            data=bytes.fromhex('171000200401000000000000')
            headcrc=m.crc16_x25(hdr).to_bytes(2,'little')
            full=hdr+headcrc+data
            bodycrc=m.crc16_x25(full).to_bytes(2,'little')
            bit=bytes.fromhex('d901ed96')+bytes(range(96))+full+bodycrc+m.EXEC+m.TRAILER
        lines = ["Info:     Constraining '$iopadmap$top_ulx5m_gs_v66_cfg_pin_sense_probe.%s' to pad '%s'." % (port.replace('[','_').replace(']',''),pad)
                 for port,pad in q.PINMAP.items()]
        log = '\n'.join(lines) + "\nInfo: Max frequency for clock '$iopadmap$clk25': 110.00 MHz (PASS at 25.00 MHz)\n"
        info, fmax=q.inspect(bit,log)
        self.assertEqual(info['jump_address'],0x201000)
        self.assertEqual(fmax,'110.00')
        for line in lines:
            with self.assertRaises(ValueError):
                q.inspect(bit,log.replace(line,''))
        with self.assertRaises(ValueError):
            q.inspect(bit,log.replace('PASS at 25.00', 'FAIL at 25.00'))
        bad=bytearray(bit)
        bad[-30] ^= 1
        with self.assertRaises(ValueError):
            q.inspect(bytes(bad),log)

    def test_real_nextpnr_vector_zero_naming(self):
        """Regression for routed 2026-10-27 v66 log (unsuffixed bit zero)."""
        parser = q.v65_parser()
        hdr = b'\xdb\x0c'
        payload = bytes.fromhex('171000200401000000000000')
        command = (hdr + parser.crc16_x25(hdr).to_bytes(2, 'little')
                   + payload)
        command += parser.crc16_x25(command).to_bytes(2, 'little')
        bit = (bytes.fromhex('d901ed96') + bytes(range(96))
               + command + parser.EXEC + parser.TRAILER)
        # Actual names and pads observed in the user's nextpnr output.
        routed = {
            'flash_cs_n': 'IO_WA_A8', 'flash_sck': 'IO_WA_B8',
            'flash_io': 'IO_WA_B7', 'flash_io_1': 'IO_WA_A7',
            'flash_io_2': 'IO_WA_B6', 'flash_io_3': 'IO_WA_A6',
        }
        lines = [
            "Info:     Constraining '$iopadmap$top_ulx5m_gs_v66_cfg_pin_sense_probe.%s' to pad '%s'." % (port, pad)
            for port, pad in routed.items()
        ]
        log = '\n'.join(lines) + "\nInfo: Max frequency for clock '$iopadmap$clk25': 117.91 MHz (PASS at 25.00 MHz)\n"
        info, fmax = q.inspect(bit, log)
        self.assertEqual(fmax, '117.91')
        self.assertEqual(info['jump_address'], 0x201000)
        # Must not confuse bit zero with bit one, nor accept a wrong pad.
        for line in lines:
            with self.subTest(missing=line):
                with self.assertRaisesRegex(ValueError, 'missing routed input-only flash pad'):
                    q.inspect(bit, log.replace(line, ''))
        with self.assertRaisesRegex(ValueError, r'missing routed input-only flash pad flash_io\[0\]'):
            q.inspect(bit, log.replace('IO_WA_B7', 'IO_WA_B6'))

    def test_icarus_simulation(self):
        if not shutil.which('iverilog') or not shutil.which('vvp'):
            self.skipTest('Icarus not installed here; run in WSL')
        with tempfile.TemporaryDirectory() as tmp:
            out=str(Path(tmp)/'v66.vvp')
            subprocess.run(['iverilog','-g2012','-s','tb_ulx5m_v66_cfg_pin_sense_probe',
                            '-o',out,str(TOP),str(ROOT/'tests/tb_ulx5m_v66_cfg_pin_sense_probe.v')],
                           check=True,timeout=25)
            subprocess.run(['vvp',out],check=True,timeout=25)

if __name__ == '__main__':
    unittest.main(verbosity=2)
