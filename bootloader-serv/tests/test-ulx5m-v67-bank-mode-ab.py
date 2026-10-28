#!/usr/bin/env python3
"""v67 experimental bank-mode status/CRC toggle, offline and mocked JTAG only."""
import importlib.util
import hashlib
import json
from pathlib import Path
from unittest import TestCase, main, mock
import tempfile

HERE = Path(__file__).resolve().parent

def load(file, name):
    s = importlib.util.spec_from_file_location(name, HERE/file)
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m

v67 = load('prepare-ulx5m-v67-bank-mode-ab.py', 'v67_make')
v67b = load('qualify-ulx5m-v67b-bank-mode-ab.py', 'v67_install')
v65t = load('test-ulx5m-v65-multiboot-probe.py', 'v67_v65test')

class MockHw:
    def __init__(self, flash):
        self.flash = bytearray(flash); self.writes = []; self.inject_error = False
    def check_loader(self, *_): pass
    def detect(self, *_): pass
    def windows_file_argument(self, *_): return 'C:\\mock'
    def jtag_cmd(self, _loader, freq):
        assert freq == 100
        return ['MOCK']
    def call(self, cmd, timeout=0):
        assert cmd[:5] == ['MOCK','-f','--verify','--offset','0'], cmd
        payload = Path(cmd[-1]).read_bytes()
        assert len(payload) == 65536
        self.flash[:65536] = payload
        self.writes.append(payload)
    def read_region(self, _loader, freq, offset, length):
        assert freq == 100
        if self.inject_error and len(self.writes) == 1:
            self.inject_error = False
            raise ValueError('injected post-write readback failure')
        return bytes(self.flash[offset:offset+length])

class V67(TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = v65t.sample(v67.OLD_STATUS)
        cls.new, cls.meta = v67.derive(cls.old, strict=False)
        v64, region, expected_region, oldblock, newblock = v67b.pinned_v63c_state()
        cls.v64 = v64
        cls.pinned = (v64,region,expected_region,oldblock,newblock)
        app = (v67b.BUILD / 'fwtn-jtag-201000-tailfix-4096.bin').read_bytes()
        before = bytearray(b'\xff'*v67b.FLASH_BYTES)
        before[:len(region)] = region
        before[v67b.APP_OFFSET:v67b.APP_OFFSET+len(app)] = app
        cls.v60 = bytes(before)
        cls.v63c = cls.v60[:v64.BLOCK_BASE] + newblock + cls.v60[v64.BLOCK_BASE+v64.BLOCK_SIZE:]
        cls.firstblock = cls.new + b'\xff'*(65536-len(cls.new))
        cls.after = v67b.proposed_image(cls.v63c,cls.firstblock)

    def test_exact_three_changes_crc_and_jump(self):
        self.assertEqual(self.meta['changed_offsets'], [106,116,117])
        self.assertEqual(self.new[106],0)
        self.assertEqual(self.new[:106],self.old[:106])
        self.assertEqual(self.new[118:],self.old[118:])
        self.assertEqual(v67.v65().inspect(self.new)['jump_address'],0x201000)

    def test_reject_wrong_source_and_crc(self):
        with self.assertRaisesRegex(ValueError,'v66 primary bytes'):
            v67.derive(self.old)
        broken=bytearray(self.old);broken[-10]^=1
        with self.assertRaises(ValueError):v67.derive(bytes(broken),False)
        broken=bytearray(self.old);broken[106]=0
        with self.assertRaises(ValueError):v67.derive(bytes(broken),False)
        broken=bytearray(self.old);broken[116]^=1
        with self.assertRaises(ValueError):v67.derive(bytes(broken),False)

    def test_real_gmpack_frame_recrc(self):
        # Exercise the exact v43 locally built gmpack record structure, not
        # only the small synthetic test frame. This is never a flash image.
        ref = v67b.BUILD / 'cfg-probe/top_ulx5m_gs_cfg_probe-bootaddr-201000-v43.bit'
        if not ref.is_file():
            self.skipTest('v43 reference unavailable')
        raw = ref.read_bytes()
        self.assertEqual(v67.sha(raw),
            '2195166eb2035d9fb0ca22d99b37fd4ea8ba49488e808cf864eee0df127dddc0')
        m = v67.v65()
        pos = m.inspect(raw)['status_offset']
        temp = bytearray(raw)
        temp[pos+4:pos+16] = v67.OLD_STATUS
        end = pos+16
        temp[end:end+2] = m.crc16_x25(temp[pos:end]).to_bytes(2,'little')
        changed, meta = v67.derive(bytes(temp), strict=False)
        self.assertEqual(meta['status_offset'],pos)
        self.assertEqual(meta['changed_offsets'],[pos+6,pos+16,pos+17])
        self.assertEqual(m.inspect(changed)['status'],v67.NEW_STATUS.hex())

    def test_mutant_is_not_programmed_by_builder(self):
        source=(HERE/'prepare-ulx5m-v67-bank-mode-ab.py').read_text()
        self.assertNotIn('openFPGALoader',source)
        self.assertNotIn('subprocess',source)
        self.assertNotIn('write_block(',source)
        self.assertEqual(v67.main(['--install']),2)

    def test_source_hash_pinning(self):
        v67b.check_source()
        with mock.patch.dict(v67b.SOURCE_SHA, {'tests/prepare-ulx5m-v67-bank-mode-ab.py':'0'*64}):
            with self.assertRaisesRegex(ValueError,'Changed v66 source'):
                v67b.check_source()

    def test_only_first_sector_block_and_app_preserved(self):
        self.assertEqual(self.after[65536:],self.v63c[65536:])
        self.assertEqual(self.after[v67b.APP_OFFSET:v67b.APP_OFFSET+4096],
                         self.v63c[v67b.APP_OFFSET:v67b.APP_OFFSET+4096])

    def test_candidate_guard_accepts_only_exact_derived_bytes(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'candidate.bit'; p.write_bytes(self.new)
            log=Path(d)/'route.log'; log.write_text('fake')
            original_load=v67b.load_py
            class Generated:
                @staticmethod
                def verify_generated(): return self.new,self.meta
            def patched_load(name, path):
                if name=='v67_packer': return Generated()
                return original_load(name,path)
            with mock.patch.object(v67b,'V67_BIT',p), mock.patch.object(v67b,'V66_PNR_LOG',log),mock.patch.object(v67b,'load_py',side_effect=patched_load):
                block,dig=v67b.check_candidate(p,log,v67b.sha(self.new))
                self.assertEqual(block,self.firstblock)
                self.assertEqual(dig,v67b.sha(self.new))
                with self.assertRaisesRegex(ValueError,'acknowledgement'):
                    v67b.check_candidate(p,log,'0'*64)
                p.write_bytes(self.old)
                with self.assertRaises(ValueError):
                    v67b.check_candidate(p,log)

    def test_mock_install_restore_and_checksum_guard(self):
        with tempfile.TemporaryDirectory() as d:
            build=Path(d); fake=MockHw(self.v63c)
            with mock.patch.object(self.v64,'BEFORE_FLASH_SHA',v67b.sha(self.v60)), \
                mock.patch.object(v67b,'BUILD',build), \
                mock.patch.object(v67b,'pinned_v63c_state',return_value=self.pinned), \
                mock.patch.object(v67b,'check_candidate',return_value=(self.firstblock,v67b.sha(self.new))), \
                mock.patch.object(v67b,'hw_adapter',return_value=fake):
                self.assertEqual(v67b.main(['--read-only']),0)
                self.assertEqual(len(fake.writes),0)
                self.assertEqual(v67b.main(['--install','--candidate-sha256',v67b.sha(self.new),
                    '--confirm',v67b.INSTALL_ACK]),0)
                self.assertEqual(bytes(fake.flash),self.after)
                sessions=list(build.glob('v67b-bank-mode-ab-*'))
                self.assertEqual(len(sessions),1)
                self.assertEqual(v67b.main(['--restore-session',str(sessions[0]),'--confirm',v67b.RESTORE_ACK]),0)
                self.assertEqual(bytes(fake.flash),self.v63c)

    def test_mock_auto_restore_after_readback_error(self):
        with tempfile.TemporaryDirectory() as d:
            build=Path(d); fake=MockHw(self.v63c);fake.inject_error=True
            with mock.patch.object(self.v64,'BEFORE_FLASH_SHA',v67b.sha(self.v60)), \
                mock.patch.object(v67b,'BUILD',build), \
                mock.patch.object(v67b,'pinned_v63c_state',return_value=self.pinned), \
                mock.patch.object(v67b,'check_candidate',return_value=(self.firstblock,v67b.sha(self.new))), \
                mock.patch.object(v67b,'hw_adapter',return_value=fake):
                self.assertEqual(v67b.main(['--install','--candidate-sha256',v67b.sha(self.new),
                    '--confirm',v67b.INSTALL_ACK]),1)
                self.assertEqual(bytes(fake.flash),self.v63c)
                sessions=list(build.glob('v67b-bank-mode-ab-*'))
                self.assertEqual(len(sessions),1)
                state=json.loads((sessions[0]/'state.json').read_text())
                self.assertEqual(state['phase'],'EXACT_V63C_FULL_FLASH_RESTORED')

    def test_install_restore_ack_precedes_hardware(self):
        with mock.patch.object(v67b,'hw_adapter',side_effect=AssertionError('Must never use hardware')):
            self.assertEqual(v67b.main(['--install']),1)
            self.assertEqual(v67b.main(['--restore-session','/tmp/nonexistent']),1)

if __name__=='__main__':
    main(verbosity=2)
