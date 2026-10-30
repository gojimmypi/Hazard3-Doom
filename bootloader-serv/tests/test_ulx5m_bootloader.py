#!/usr/bin/env python3
"""Pure-Python offline integrity and fail-closed qualification tests."""
from pathlib import Path
import json
import unittest
from unittest import mock
import tempfile
import ulx5m_flash_install as installer

from ulx5m_bootloader import (
    BOOTSTRAP, BOOTSTRAP_SHA, BOOTADDR, PINMAP,
    check_clock_topology, check_timing, derive_image, fingerprint,
    rom_text, sha, validate_manifest,
)
from cfgcmd_codec import packet, CMD_CHG_STATUS, CMD_CFGRST, CMD_JUMP

ROOT = Path(__file__).resolve().parents[1]


def sample_netlist():
    return {'modules': {'top_ulx5m_gs_bootloader': {'cells': {
        'clocks.clk_buf_i': {'type': 'CC_IBUF',
                             'connections': {'I': [1], 'Y': [2]}},
        'clocks.cfg_clock_i': {'type': 'CC_BUFG',
                               'connections': {'I': [2], 'O': [3]}},
        'clocks.pll_i': {'type': 'CC_PLL',
                         'connections': {'CLK_REF': [2], 'CLK0': [4]}},
        'clocks.bufg_i': {'type': 'CC_BUFG',
                          'connections': {'I': [4], 'O': [5]}},
        'cfg25_i.cfg_i': {'type': 'CC_CFG_CTRL',
                          'connections': {'CLK': [3]}}
    }}}}


def sample_log(fail=False):
    text = "Info: constraining clock net 'clk25' to 25.00 MHz\n"
    for name, actual, requested in [('clk_cfg25', 36.4, 25), ('clk48', 50.5, 48)]:
        text += ("Max frequency for clock '%s': %.2f MHz (%s at %.2f MHz)\n" %
                 (name, actual, 'FAIL' if fail and requested == 48 else 'PASS', requested))
    for signal, pad in PINMAP.items():
        text += "Constraining '%s' to pad '%s'\n" % (signal, pad)
    return text


class BootloaderOffline(unittest.TestCase):
    def test_canonical_names_and_no_flash_invocations(self):
        mk = (ROOT / 'Makefile.ulx5m-gs').read_text(encoding='ascii')
        top = (ROOT / 'rtl/top_ulx5m_gs_bootloader.v').read_text(encoding='ascii')
        self.assertIn('bootaddr 2101248', mk)
        self.assertIn('PACK-ONLY.bit', mk)
        self.assertIn('RUN := $(OUT)/bootloader', mk)
        self.assertNotIn('openFPGALoader', mk)
        self.assertNotIn('dfu-util', mk)
        self.assertNotIn('ULX5M_V79', top)
        self.assertNotIn('`ifdef', top)
        self.assertIn('module top_ulx5m_gs_bootloader (', top)
        self.assertIn('build-ulx5m-gs/bootloader/ulx5m_bootloader.hex', top)
        self.assertIn('.clk25(clk_cfg25)', top)
        self.assertIn('CC_BUFG cfg_clock_i',
                      (ROOT / 'rtl/sysmgr_gatemate.v').read_text(encoding='ascii'))
        self.assertIn('build-ulx5m-gs/bootloader/cmd.hex',
                      (ROOT / 'rtl/ulx5m_cfg_autoboot_25.v').read_text(encoding='ascii'))
        self.assertNotIn('normal-boot-dfu-hw-native', mk)
        self.assertEqual(len(list(ROOT.glob('Makefile.ulx5m*'))), 1)

    def test_firmware_and_sweep_build_reproducibility(self):
        mk = (ROOT / 'Makefile.ulx5m-gs').read_text(encoding='ascii')
        fw = (ROOT / 'fw/Makefile.ulx5m-gs').read_text(encoding='ascii')
        self.assertIn('$(FW): $(wildcard fw/*.c)', mk)
        self.assertIn('fw/Makefile.ulx5m-gs force-generated | $(RUN)', mk)
        self.assertIn('$(MAKE) -B -C fw', mk)
        self.assertIn('$(MC): cores/usb/utils/microcode.py force-generated', mk)
        self.assertIn('EXPECTED_RISCV_GCC_VERSION ?= 12.2.0', mk)
        self.assertIn('EXPECTED_GCC_VERSION ?= 12.2.0', fw)
        self.assertIn("'$(CC)' -dumpfullversion", fw)
        self.assertIn('sha256sum $(CMD) $(JSON)', mk)
        self.assertIn('sha256sum $(FW) $(MC) $(CCF) $(SDC)', mk)

    def test_bootstrap_rom_seed(self):
        self.assertEqual(len(BOOTSTRAP), 27)
        self.assertEqual(sha(BOOTSTRAP), BOOTSTRAP_SHA)
        self.assertEqual(len(rom_text(BOOTSTRAP).splitlines()), 27)

    def test_packed_command_codec(self):
        status = bytearray(12)
        status[0] = status[2] = 8
        packed = (packet(CMD_CHG_STATUS, bytes(status)) +
                  packet(CMD_CFGRST, b'\x00') +
                  packet(CMD_JUMP, BOOTADDR.to_bytes(4, 'little')))
        frame = derive_image(packed)
        self.assertEqual(len(frame), 27)
        self.assertEqual(frame[:2], bytes([CMD_CHG_STATUS, 12]))
        self.assertEqual(frame[-9:], bytes(4) + bytes([0x33]) + bytes(4))
        with self.assertRaises(ValueError):
            derive_image(packed[:-1])

    def test_global_clock_topology(self):
        good = sample_netlist()
        self.assertTrue(check_clock_topology(good))
        raw = json.loads(json.dumps(good))
        raw['modules']['top_ulx5m_gs_bootloader']['cells']['cfg25_i.cfg_i']['connections']['CLK'] = [1]
        with self.assertRaisesRegex(ValueError, 'not supplied by CC_BUFG'):
            check_clock_topology(raw)
        wrong_pll = json.loads(json.dumps(good))
        wrong_pll['modules']['top_ulx5m_gs_bootloader']['cells']['clocks.pll_i']['connections']['CLK_REF'] = [9]
        with self.assertRaisesRegex(ValueError, 'share one input buffer'):
            check_clock_topology(wrong_pll)

    def test_timing_and_flash_pin_guards(self):
        self.assertEqual(len(check_timing(sample_log())), 2)
        with self.assertRaisesRegex(ValueError, 'timing failed'):
            check_timing(sample_log(fail=True))
        with self.assertRaisesRegex(ValueError, 'flash pad'):
            check_timing(sample_log().replace('IO_WA_B7', 'IO_WA_B9'))
        with self.assertRaisesRegex(ValueError, '25 MHz'):
            check_timing(sample_log().replace('at 25.00 MHz)', 'at 24.00 MHz)'))

    def test_manifest_rejects_modified_source(self):
        names = ['Makefile.ulx5m-gs', 'rtl/sysmgr_gatemate.v']
        manifest = fingerprint(names)
        validate_manifest(manifest, names)
        with self.assertRaises(ValueError):
            validate_manifest(manifest, names[:-1])
        with self.assertRaises(ValueError):
            validate_manifest(manifest.replace('a', 'b', 1), names)

    def test_usb_status_read_and_startup_witness(self):
        usb = (ROOT / 'cores/usb/rtl/usb.v').read_text(encoding='ascii')
        startup = (ROOT / 'fw/start.S').read_text(encoding='ascii')
        self.assertIn('.s_read_0(eps_bus_read)', usb)
        self.assertNotIn('.s_read_0(eps_bus_ready)', usb)
        self.assertIn("cr_pu_ena  <= 1'b0;", usb)
        self.assertEqual(startup.count('#ifndef ULX5M_SERV_TEST'), 3)
        self.assertIn('// Light 1 LED', startup)
        self.assertIn('// Light 2 LED', startup)
        self.assertIn('// Light 3 LED', startup)

    def test_guarded_installer_primary_partition_and_authorization(self):
        source = bytes([0x33]) * installer.FLASH_SIZE
        target = b'candidate-image'
        expected = installer.expected_flash(source, target.ljust(10000, b'\0'))
        self.assertEqual(len(expected), installer.FLASH_SIZE)
        self.assertEqual(expected[installer.PRIMARY_SIZE:], source[installer.PRIMARY_SIZE:])
        self.assertEqual(expected[installer.PRIMARY_SIZE - 1], 0xff)
        with self.assertRaisesRegex(ValueError, 'secondary'):
            installer.expected_flash(bytes([0xff]) * installer.FLASH_SIZE,
                                     target.ljust(10000, b'\0'))
        with mock.patch.object(installer, 'install') as write:
            self.assertEqual(installer.main(['install', '--confirm', 'INVALID']), 1)
            write.assert_not_called()
        with mock.patch.object(installer, 'restore') as write:
            self.assertEqual(installer.main(['restore', '--session', '/tmp/untrusted',
                                             '--confirm', 'INVALID']), 1)
            write.assert_not_called()

    def test_guarded_installer_preflight_and_stale_stamp(self):
        with tempfile.TemporaryDirectory() as td:
            bit = Path(td) / 'primary.bit'
            stamp = Path(td) / 'build.ok'
            bit.write_bytes(b'Q' * 10000)
            stamp.write_text(json.dumps({'seed': 876, 'sha256': sha(bit.read_bytes())}),
                             encoding='ascii')
            with mock.patch.object(installer, 'BIT', bit), \
                 mock.patch.object(installer, 'STAMP', stamp), \
                 mock.patch.object(installer.subprocess, 'run') as run:
                image, seed = installer.candidate()
                self.assertEqual((image, seed), (bit.read_bytes(), 876))
                self.assertIn('SEED=876', run.call_args.args[0])
                bit.write_bytes(b'Z' * 10000)
                with self.assertRaisesRegex(ValueError, 'does not match'):
                    installer.candidate()
                self.assertEqual(run.call_count, 1)

    def test_guarded_installer_rollback_after_primary_mismatch(self):
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            original = b'R' * installer.FLASH_SIZE
            image = b'N' * 10000
            flash = bytearray(original)
            with mock.patch.object(installer, 'BUILD', base), \
                 mock.patch.object(installer, 'candidate', return_value=(image, 123)), \
                 mock.patch.object(installer, 'detect'), \
                 mock.patch.object(installer, 'dump') as dump, \
                 mock.patch.object(installer, 'program') as program:
                def do_dump(path):
                    data = bytes(flash)
                    path.write_bytes(data)
                    return data
                def do_program(path):
                    payload = path.read_bytes()
                    flash[:installer.PRIMARY_SIZE] = payload
                    if path.name == 'primary-new.bin':
                        flash[200] ^= 1
                dump.side_effect = do_dump
                program.side_effect = do_program
                with self.assertRaisesRegex(ValueError, 'original flash was restored'):
                    installer.install()
                self.assertEqual(bytes(flash), original)
                self.assertEqual(program.call_count, 2)
                sessions = list(base.glob('flash-install-*'))
                self.assertEqual(len(sessions), 1)
                meta = json.loads((sessions[0] / 'manifest.json').read_text())
                self.assertEqual(meta['state'], 'ROLLED_BACK_FULL_CHIP_VERIFIED')

    def test_guarded_installer_verified_write_and_protected_region_stop(self):
        for damage_protected in (False, True):
            with self.subTest(damage_protected=damage_protected):
                with tempfile.TemporaryDirectory() as td:
                    base = Path(td)
                    original = b'R' * installer.FLASH_SIZE
                    image = b'N' * 10000
                    flash = bytearray(original)
                    with mock.patch.object(installer, 'BUILD', base), \
                         mock.patch.object(installer, 'candidate', return_value=(image, 123)), \
                         mock.patch.object(installer, 'detect'), \
                         mock.patch.object(installer, 'dump') as dump, \
                         mock.patch.object(installer, 'program') as program:
                        def do_dump(path):
                            data = bytes(flash)
                            path.write_bytes(data)
                            return data
                        def do_program(path):
                            flash[:installer.PRIMARY_SIZE] = path.read_bytes()
                            if damage_protected:
                                flash[installer.PRIMARY_SIZE + 1] ^= 1
                        dump.side_effect = do_dump
                        program.side_effect = do_program
                        if damage_protected:
                            with self.assertRaisesRegex(RuntimeError, 'Protected region differs'):
                                installer.install()
                        else:
                            installer.install()
                        self.assertEqual(program.call_count, 1)
                        session = next(base.glob('flash-install-*'))
                        meta = json.loads((session / 'manifest.json').read_text())
                        self.assertEqual(meta['state'],
                                         'RECOVERY_REQUIRED_PROTECTED_REGION_CHANGED'
                                         if damage_protected else 'INSTALLED_FULL_CHIP_VERIFIED')
                        self.assertEqual(flash[:len(image)], image)
                        self.assertEqual(flash[installer.PRIMARY_SIZE - 1], 0xff)
                        self.assertEqual((session / 'flash-before-a.bin').read_bytes(), original)
                        self.assertEqual((session / 'flash-before-b.bin').read_bytes(), original)

    def test_firmware_does_not_compete_for_configuration_flash(self):
        firmware = (ROOT / 'fw/ulx5m_bootloader.c').read_text(encoding='ascii')
        self.assertIn('Autonomous 25 MHz CC_CFG_CTRL owns', firmware)
        self.assertIn('MISC_LEDS = 1u;', firmware)
        self.assertNotIn('ulx5m_spi_active_boot_run', firmware)
        self.assertNotIn('ulx5m_normal_boot_run', firmware)
        self.assertNotIn('CFG_REBOOT_EXEC', firmware)



class FullImageHostOffline(unittest.TestCase):
    @staticmethod
    def valid_secondary():
        from cfgcmd_codec import CMD_CHG_STATUS
        import ulx5m_dfu_update as updater
        prefix = bytes.fromhex('d901ed96104dd6')
        image = prefix + bytes(256 - len(prefix) - 18) + packet(CMD_CHG_STATUS, bytes(12))
        updater.check_image(image)
        return image

    def test_secondary_preflight_and_primary_rejection(self):
        import ulx5m_dfu_update as updater
        image = self.valid_secondary()
        self.assertEqual(updater.check_image(image), updater.zlib.crc32(image))
        with self.assertRaisesRegex(ValueError, 'synchronization'):
            updater.check_image(b'X' + image[1:])
        with self.assertRaisesRegex(ValueError, '256'):
            updater.check_image(image[:255])
        with self.assertRaisesRegex(ValueError, 'secondary'):
            updater.check_image(image[:-18] + bytes(8) +
                                packet(CMD_JUMP, updater.START.to_bytes(4, 'little')))
        with self.assertRaisesRegex(ValueError, 'Truncated'):
            updater.check_image(image + b'\x01')
        with tempfile.TemporaryDirectory() as td:
            file = Path(td) / 'secondary.bit'
            file.write_bytes(image)
            self.assertEqual(updater.main(['--image', str(file)]), 0)
            self.assertEqual(updater.main(['--image', str(file), '--execute']), 1)

    def test_read_only_probe_and_mismatch(self):
        import struct
        import ulx5m_dfu_update as updater
        image = self.valid_secondary()

        class ReadOnlyDevice:
            def __init__(self, profile=b'FWTN', corrupt=False):
                self.profile = profile
                self.corrupt = corrupt
                self.requests = []

            def ctrl_transfer(self, direction, command, value, index, data, timeout=0):
                # Any OUT request (including ARM/FINISH) fails the test.
                self.requests.append((direction, command))
                if direction != 0xc0:
                    raise AssertionError('probe attempted an OUT request')
                if command == 0x5d:
                    return self.profile + struct.pack('<5I', 0, 0, 0, 0, 0)
                if command == 0x5a:
                    return b'A251\x1f\x42\x16\x00'
                if command == 0x5b:
                    offset = ((index << 16) | value) - updater.START
                    result = bytearray(image[offset:offset + data])
                    if self.corrupt and offset == 0:
                        result[0] ^= 1
                    return result
                raise AssertionError('unexpected probe request')

        for profile in (b'FWTN', b'FWTF'):
            device = ReadOnlyDevice(profile)
            self.assertEqual(updater.probe(device, image),
                             updater.hashlib.sha256(image).hexdigest())
            self.assertTrue(all(direction == 0xc0 for direction, _ in device.requests))
        with self.assertRaisesRegex(ValueError, 'unexpected DFU writer profile'):
            updater.probe(ReadOnlyDevice(b'FWT1'), image)
        with self.assertRaisesRegex(ValueError, 'readback mismatch'):
            updater.probe(ReadOnlyDevice(corrupt=True), image)

    def test_vendor_transport_and_independent_readback(self):
        import struct
        import ulx5m_dfu_update as updater
        image = self.valid_secondary()

        class MockDevice:
            def __init__(self):
                self.phase = 0
                self.received = bytearray()
                self.expected_crc = 0
                self.image_length = 0
                self.corrupted = False

            def ctrl_transfer(self, direction, command, value, index, data, timeout=0):
                if (direction, command) == (0xc0, 0x5d):
                    return b'FWTF' + struct.pack('<5I', self.phase,
                                                  self.image_length, self.expected_crc,
                                                  len(self.received), 0)
                if (direction, command) == (0xc0, 0x5a):
                    return b'A251\x1f\x42\x16\x00'
                if (direction, command) == (0x40, 0x5c):
                    assert (value, index) == (1, 0x2000)
                    assert bytes(data[:4]) == b'U5WF'
                    self.image_length, self.expected_crc, token = struct.unpack('<3I', data[4:])
                    assert token == updater.TOKEN
                    self.phase = 1
                    return len(data)
                if (direction, command) == (0x21, 1):
                    assert self.phase == 1 and value == len(self.received) // 64
                    self.received.extend(data)
                    return len(data)
                if (direction, command) == (0xa1, 3):
                    return bytes((0, 0, 0, 0, 5, 0))
                if (direction, command) == (0x40, 0x5e):
                    assert (value, index) == (0x5afe, 0x2026)
                    assert len(self.received) == self.image_length
                    assert updater.zlib.crc32(self.received) == self.expected_crc
                    self.phase = 2
                    return 0
                if (direction, command) == (0xc0, 0x5b):
                    assert self.phase == 2
                    offset = ((index << 16) | value) - updater.START
                    result = bytearray(self.received[offset:offset + data])
                    if self.corrupted and offset == 0:
                        result[0] ^= 1
                    return result
                raise AssertionError('unexpected request %s' % ((direction, command),))

        self.assertEqual(updater.update(MockDevice(), image),
                         updater.hashlib.sha256(image).hexdigest())
        bad = MockDevice()
        bad.corrupted = True
        with self.assertRaisesRegex(ValueError, 'readback mismatch'):
            updater.update(bad, image)


if __name__ == '__main__':
    unittest.main(verbosity=2)
