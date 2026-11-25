#!/usr/bin/env python3
"""Guided ULX5M-GS FWTF acceptance test. Run on Linux or WSL from bootloader-serv.

The default is offline only. Full mode requires operator observations and a
separate typed confirmation before *one* secondary flash write. Primary flash
installation is a distinct, explicitly requested and confirmed operation.
The runner does not initiate a separate rollback. The separately authorized
guarded primary installer can automatically roll back a failed primary write.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build-ulx5m-gs'
PRIMARY = BUILD / 'bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit'
SECONDARY = BUILD / 'native-secondary/top_ulx5m_gs_secondary-SOURCE-CANDIDATE.bit'
UPDATER = ROOT / 'tests/ulx5m_dfu_update.py'
INSTALLER = ROOT / 'tests/ulx5m_flash_install.py'
PROGRAMMER = (ROOT / '../bin/openFPGALoader.exe').resolve()
SEED = 160
PRIMARY_SHA = 'c73b8d6fe1ac1150ad3e3bba72c6d64664ee495185fade339f188f628dcfe167'
SECONDARY_SHA = '25334f8fb384c413ee192d1ceab8b4940604eb53972217fbb232baba33e507f5'
PROGRAMMER_SHA = '9be9dcdb6e00e6d473f1031a459658561c95630584b1a5739aa2b8788237adea'
SECONDARY_TOKEN = 'REPLACE-SECONDARY-0x201000'
PRIMARY_TOKEN = 'I_AUTHORIZE_ULX5M_PRIMARY_512K_WITH_VERIFIED_ROLLBACK'


class StopTest(Exception):
    """Operator stop, missing prerequisite, or failed acceptance check."""


def host_platform():
    if sys.platform != 'linux':
        raise StopTest('run this test on native Linux or WSL2 (Windows via WSL)')
    release = Path('/proc/sys/kernel/osrelease')
    if release.is_file() and 'microsoft' in release.read_text(encoding='ascii').lower():
        return 'wsl'
    return 'linux'


class Acceptance:
    def __init__(self, args):
        self.args = args
        self.report = None
        self.outdir = None
        self.passed = []
        self.flash_reference = None
        self.platform = host_platform()
        self.programmer = (PROGRAMMER if self.platform == 'wsl' else
                           Path(shutil.which('openFPGALoader') or 'openFPGALoader'))

    def say(self, message):
        print(message, flush=True)
        if self.report is not None:
            self.report.write(message + '\n')
            self.report.flush()

    def fail(self, reason):
        raise StopTest(reason)

    def run(self, cmd, description, *, match=None):
        self.say('\n[RUN] ' + description)
        printable = [str(x) for x in cmd]
        self.say('[CMD] ' + (shlex.join(printable) if self.platform == 'linux'
                            else subprocess.list2cmdline(printable)))
        try:
            process = subprocess.Popen([str(x) for x in cmd], cwd=ROOT,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, errors='replace', bufsize=1)
            lines = []
            assert process.stdout is not None
            for line in process.stdout:
                self.say(line.rstrip('\r\n'))
                if match is not None:
                    lines.append(line)
            rc = process.wait()
        except OSError as exc:
            raise StopTest('%s: %s' % (description, exc)) from exc
        if rc:
            raise StopTest('%s failed (exit %d)' % (description, rc))
        combined = ''.join(lines)
        if match and match not in combined:
            raise StopTest('%s did not report expected result: %s' % (description, match))
        self.passed.append(description)

    def pause(self, message):
        self.say('\n[HARDWARE PAUSE] ' + message)
        try:
            answer = input('Type PASS only after completing/checking this step; '
                           'type anything else to stop: ').strip()
        except (EOFError, KeyboardInterrupt) as exc:
            raise StopTest('operator stopped at hardware pause') from exc
        if answer != 'PASS':
            raise StopTest('operator did not confirm hardware check')
        self.say('[OPERATOR] PASS: ' + message)

    def authorize(self, operation, token):
        self.say('\n[WRITE AUTHORIZATION] ' + operation)
        self.say('This will erase/program FPGA SPI flash. Do not disconnect power.')
        try:
            answer = input('Enter exactly %s to authorize, or Enter to cancel: ' % token)
        except (EOFError, KeyboardInterrupt) as exc:
            raise StopTest('operator cancelled write authorization') from exc
        if answer != token:
            raise StopTest('write was NOT authorized; no write command issued')
        self.say('[AUTHORIZED] ' + operation)

    @staticmethod
    def sha(path):
        value = hashlib.sha256()
        with path.open('rb') as source:
            for block in iter(lambda: source.read(1024 * 1024), b''):
                value.update(block)
        return value.hexdigest()

    def require_reference(self, path, expected, label):
        if not path.is_file():
            self.fail('%s missing: %s' % (label, path))
        found = self.sha(path)
        self.say('[HASH] %s: %s (%d bytes)' % (label, found, path.stat().st_size))
        if found != expected:
            self.fail('%s differs from the hardware-tested reference; '
                      'do not flash an unqualified build' % label)
        self.passed.append(label + ' reference SHA-256')

    def prerequisites(self):
        if not (ROOT / 'Makefile.ulx5m-gs').is_file():
            self.fail('run from a clone containing bootloader-serv/Makefile.ulx5m-gs')
        mk = (ROOT / 'Makefile.ulx5m-gs').read_text(encoding='utf-8')
        qualifier = (ROOT / 'tests/ulx5m_flash_install.py').read_text(encoding='utf-8')
        if 'DFU_FULL_IMAGE' not in mk or 'FW_PROFILE' not in mk or "stamp.get('profile')" not in qualifier:
            self.fail('fresh clone lacks the FWTF profile-guard changes; '
                      'obtain the reviewed bootloader revision before testing')
        required = ['git', 'make', 'gcc', 'iverilog', 'vvp', 'yosys',
                    'nextpnr-himbaechel', 'gmpack']
        if self.platform == 'wsl' and self.args.mode == 'full':
            required.extend(['wslpath', 'powershell.exe'])
        missing = [name for name in required if shutil.which(name) is None]
        if missing:
            self.fail('missing required command(s): ' + ', '.join(missing))
        self.say('[HOST] ' + ('Windows/WSL2' if self.platform == 'wsl' else 'native Linux'))
        if self.platform == 'linux' and self.args.mode == 'full':
            self.run([sys.executable, '-c', 'import usb.core; import usb.backend.libusb1; '
                      'assert usb.backend.libusb1.get_backend() is not None; '
                      'print("[PASS] PyUSB and libusb-1.0 available")'],
                     'native Linux USB dependencies', match='[PASS] PyUSB and libusb-1.0 available')
        self.run(['git', 'rev-parse', 'HEAD'], 'record source Git commit')
        self.run(['make', '-f', 'Makefile.ulx5m-gs', 'show-settings',
                  'SEED=160', 'DFU_FULL_IMAGE=1'], 'record build settings', match='FWTF')

    def offline(self):
        self.prerequisites()
        mk = ['make', '-f', 'Makefile.ulx5m-gs']
        self.run([*mk, 'test'], 'host, RTL, and Python regression tests', match='OK')
        self.run([*mk, 'build', 'SEED=160', 'DFU_FULL_IMAGE=1'],
                 'locally build full-image FWTF primary', match='Image-derived ROM matches packed primary')
        self.run([*mk, 'qualify', 'SEED=160', 'DFU_FULL_IMAGE=1'],
                 'qualify FWTF timing, ROM, pinout, and manifest', match='[PASS] FWTF primary:')
        self.run([*mk, 'native-secondary-build', 'SEED=160'],
                 'locally build and qualify native LED secondary', match='[PASS] native LED secondary')
        self.require_reference(PRIMARY, PRIMARY_SHA, 'FWTF primary')
        self.require_reference(SECONDARY, SECONDARY_SHA, 'native LED secondary')
        self.run(['python3', str(INSTALLER), 'preflight'],
                 'read-only primary-installation preflight', match='[SAFETY] No hardware was accessed')
        self.run(['python3', str(UPDATER), '--image', str(SECONDARY)],
                 'offline secondary DFU preflight', match='[SAFE] preflight only')

    @staticmethod
    def psquote(value):
        return "'" + str(value).replace("'", "''") + "'"

    def to_windows(self, path):
        try:
            return subprocess.check_output(['wslpath', '-w', str(path.resolve())],
                                           text=True).strip()
        except (OSError, subprocess.CalledProcessError) as exc:
            raise StopTest('failed to translate WSL path: %s' % path) from exc

    def usb_update(self, action, profile='FWTF'):
        arguments = ['--image', str(SECONDARY)]
        if action == 'probe':
            arguments.append('--probe')
        else:
            arguments.extend(['--execute', '--expected-sha256', SECONDARY_SHA,
                              '--confirm', SECONDARY_TOKEN])
        description = ('USB ' + ('read-only verification' if action == 'probe' else
                                'full-image program/readback') + ' (' + self.platform + ')')
        expected = ('Device profile %s; AT25QL321 identified' % profile if action == 'probe'
                    else '[PASS] full-image firmware and independent host flash readback SHA256 ' + SECONDARY_SHA)
        if self.platform == 'linux':
            self.run([sys.executable, str(UPDATER), *arguments], description, match=expected)
        else:
            script = self.to_windows(UPDATER)
            image = self.to_windows(SECONDARY)
            bin_dir = self.to_windows(PROGRAMMER.parent)
            parameters = '--probe' if action == 'probe' else (
                '--execute --expected-sha256 %s --confirm %s' % (SECONDARY_SHA, SECONDARY_TOKEN))
            command = ("$env:PATH=" + self.psquote(bin_dir + ';') + "+$env:PATH; " +
                       "& py -3 " + self.psquote(script) + ' --image ' +
                       self.psquote(image) + ' ' + parameters + '; exit $LASTEXITCODE')
            self.run(['powershell.exe', '-NoProfile', '-Command', command], description, match=expected)

    def usb_enumerated(self):
        if self.platform == 'linux':
            code = ('import usb.core; '
                    'd = usb.core.find(idVendor=0x1d50, idProduct=0x614b); '
                    'assert d is not None, "ULX5M VID/PID missing"; '
                    'print("[PASS] ULX5M USB VID/PID enumerated")')
            self.run([sys.executable, '-c', code], 'Linux USB enumeration 1D50:614B',
                     match='[PASS] ULX5M USB VID/PID enumerated')
        else:
            cmd = ("$d = @(Get-PnpDevice -PresentOnly | Where-Object "
                   "{ $_.InstanceId -match 'VID_1D50&PID_614B' }); "
                   "if ($d.Count -eq 0) { Write-Output '[FAIL] ULX5M VID/PID missing'; exit 1 }; "
                   "$d | Format-Table Status,FriendlyName,InstanceId; "
                   "if (@($d | Where-Object { $_.Status -eq 'OK' }).Count -eq 0) {exit 1}; "
                   "Write-Output '[PASS] ULX5M USB VID/PID enumerated'; exit 0")
            self.run(['powershell.exe', '-NoProfile', '-Command', cmd],
                     'Windows enumeration 1D50:614B', match='[PASS] ULX5M USB VID/PID enumerated')

    def require_programmer(self):
        if self.platform == 'wsl':
            self.require_reference(PROGRAMMER, PROGRAMMER_SHA, 'unmodified openFPGALoader v1.2.0')
        else:
            if not self.programmer.is_file():
                self.fail('native Linux openFPGALoader not found; install v1.2.0 and add it to PATH')
            self.run([str(self.programmer), '--version'], 'native Linux JTAG programmer version',
                     match='openFPGALoader v1.2.0')

    def dfu_boot(self, label):
        self.pause(label + ': unplug the ONE ULX5M USB power/data cable. With POWER OFF, '
                   'set both SW1 sections OFF/OFF. Hold BTN2 BEFORE reconnecting USB; '
                   'keep BTN2 held until D5 is on and startup stabilizes; then release. '
                   'Confirm D4 ON, D3 OFF, D5/D6 ON, D7 blinking, no walking LEDs. '
                   'The same USB cable provides power and USB data.')
        self.usb_enumerated()
        self.usb_update('probe')

    def normal_boot(self, label):
        self.pause(label + ': unplug the ONE USB power/data cable; with POWER OFF, '
                   'set SW1 OFF/OFF and release BTN2; reconnect USB. '
                   'Confirm secondary walking/blinking LEDs (allow several seconds). '
                   'USB DFU enumeration is NOT expected during normal secondary boot.')

    def primary_install(self):
        self.require_programmer()
        self.pause('Initial FWTN preflight: SW1 OFF/OFF, power disconnected, hold BTN2 '
                   'before connecting the USB cable, then release after D5 is on; '
                   'confirm DFU LEDs without walking LEDs')
        self.usb_enumerated()
        # FWTN read-only verification: expect the known LED secondary in flash.
        self.usb_update('probe', profile='FWTN')
        self.pause('JTAG setup: unplug USB power; turn off Tigard; with POWER OFF set '
                   'both SW1 sections ON/ON; attach Tigard; power the ULX5M first, '
                   'THEN power Tigard. Confirm all connections before proceeding. '
                   'All LEDs off in blank JTAG mode is not itself a fault')
        self.run([str(self.programmer), '-c', 'tigard', '--freq', '1000k', '--detect'],
                 'detect GateMate over Tigard', match='idcode 0x20000001')
        self.authorize('replace primary 0x000000..0x07ffff with verified FWTF; '
                       'create two 4 MiB backups and verify full chip', PRIMARY_TOKEN)
        self.run(['python3', str(INSTALLER), 'install', '--confirm', PRIMARY_TOKEN],
                 'guarded primary installation and full-chip preservation check',
                 match='[PASS] Full 4 MiB readback matches expected; non-primary bytes unchanged')
        # Protect the latest guarded install session outside the Git checkout.
        sessions = sorted(BUILD.glob('flash-install-*/manifest.json'),
                          key=lambda item: item.stat().st_mtime, reverse=True)
        if not sessions:
            self.fail('successful install did not leave a recovery manifest')
        session = sessions[0].parent
        record = json.loads((session / 'manifest.json').read_text(encoding='ascii'))
        if record.get('state') != 'INSTALLED_FULL_CHIP_VERIFIED':
            self.fail('recovery manifest is not in the verified installed state')
        recovery = Path.home() / 'ulx5m-primary-recovery' / session.name
        if recovery.exists():
            self.fail('recovery destination already exists; no files overwritten: ' + str(recovery))
        recovery.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(session, recovery)
        self.say('[RECOVERY] Separate verified installation backup: ' + str(recovery))


    def audit_flash(self, label, baseline):
        self.require_programmer()
        self.pause(label + ': disconnect USB POWER and turn off Tigard. With POWER OFF '
                   'set both SW1 sections ON/ON; attach Tigard; power ULX5M FIRST, '
                   'then Tigard. Confirm connections. This is a READ-ONLY JTAG dump.')
        filename = 'flash-before-update' if baseline else 'flash-after-update'
        first = self.outdir / (filename + '-a.bin')
        # Reuse the guarded canonical JTAG reader and JEDEC verification. No
        # new flash protocol or write path is added by this acceptance runner.
        pycode = ('import sys; from pathlib import Path; '
                  'sys.path.insert(0, "tests"); '
                  'import ulx5m_flash_install as guarded; '
                  'guarded.detect(); guarded.dump(Path(sys.argv[1]))')
        self.run(['python3', '-c', pycode, str(first)], label + ' JTAG flash dump')
        if first.stat().st_size != 0x400000:
            self.fail('read-only flash audit did not produce exactly 4 MiB')
        flash_sha = self.sha(first)
        self.say('[AUDIT] %s: %s' % (filename, flash_sha))
        if baseline:
            # Read twice: intermittent JTAG RX shifts make single snapshots unsafe.
            second = self.outdir / (filename + '-b.bin')
            self.run(['python3', '-c', pycode, str(second)], 'independent second flash baseline')
            if second.read_bytes() != first.read_bytes():
                self.fail('two JTAG baselines differ; possible one-bit shift; no write')
            data = first.read_bytes()
            image = SECONDARY.read_bytes()
            if data[:4] != bytes.fromhex('d901ed96') or data[0x201000:0x201000 + len(image)] != image:
                self.fail('JTAG baseline invalid or does not contain reference secondary')
            self.flash_reference = first
            self.say('[PASS] two exact JTAG baselines; installed secondary matches reference')
        else:
            if self.flash_reference is None or first.read_bytes() != self.flash_reference.read_bytes():
                self.fail('4 MiB flash changed during identical-image DFU rewrite; '
                          'STOP, preserve dumps and do not write again')
            self.say('[PASS] byte-for-byte identical 4 MiB flash after USB rewrite; '
                     'primary and all other flash contents preserved')
            self.passed.append('independent full-chip before/after preservation audit')

    def full(self):
        if self.args.install_primary:
            self.primary_install()
        # Verify DFU BEFORE any secondary erase/program operation.
        self.dfu_boot('Initial persistent FWTF DFU recovery')
        for cycle in range(1, self.args.cycles + 1):
            self.normal_boot('Normal cold boot %d/%d' % (cycle, self.args.cycles))
            self.dfu_boot('BTN2 recovery %d/%d' % (cycle, self.args.cycles))
        if self.args.audit_flash:
            self.audit_flash('Before-update full-chip audit', baseline=True)
            self.dfu_boot('Return to DFU after baseline JTAG read')
        self.authorize('ONE USB DFU erase/program cycle of the known 7,096-byte '
                       'secondary at 0x201000 (NOT the primary)', SECONDARY_TOKEN)
        try:
            self.usb_update('write')
        except StopTest:
            self.say('[RECOVERY] An interrupted or failed update may leave the secondary invalid. '
                     'KEEP or RE-ENTER BTN2 DFU; do NOT attempt normal boot until recovered.')
            raise
        self.normal_boot('Post-update normal cold boot')
        self.dfu_boot('Post-update persistent FWTF recovery and flash readback')
        if self.args.audit_flash:
            self.audit_flash('After-update full-chip audit', baseline=False)
            self.dfu_boot('Restore final SPI-active FWTF DFU state after JTAG audit')
        else:
            self.say('[LIMIT] Independent JTAG whole-chip post-DFU audit was skipped.')
        self.say('[LIMIT] No deliberate power-loss injection; in-place updates are non-atomic.')

    def plan(self):
        print('ULX5M-GS guided acceptance: host=%s, mode=%s, cold-boot cycles=%d' %
              (self.platform, self.args.mode, self.args.cycles))
        steps = [
            'Detect native Linux or WSL; check toolchain and source profile guard.',
            'Run offline tests, FWTF seed-160 build/qualification, native build.',
            'Verify candidate SHA-256 against known hardware-tested images.',
        ]
        if self.args.mode == 'full':
            if self.args.install_primary:
                steps.append('Read-only FWTN probe, JTAG setup, explicit primary-install consent; '
                             'guarded 4 MiB backup/verification.')
            steps.append('USB enumeration, FWTF read-only probe, normal cold-boot cycles.')
            if self.args.audit_flash:
                steps.append('Take two read-only JTAG 4 MiB flash snapshots before rewrite.')
            steps.extend([
                'Explicit separate consent for ONE USB secondary rewrite.',
                'Reboot secondary, recover via BTN2, and read-only verify again.',
            ])
            if self.args.audit_flash:
                steps.append('JTAG dump again and require exact 4 MiB preservation.')
        for number, message in enumerate(steps, 1):
            print(' %2d. %s' % (number, message))
        print('No hardware operation in --plan. Offline mode never accesses hardware.')

    def main(self):
        if self.args.plan:
            self.plan()
            return 0
        BUILD.mkdir(exist_ok=True)
        name = 'acceptance-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        self.outdir = BUILD / name
        self.outdir.mkdir(exist_ok=False)
        with (self.outdir / 'report.txt').open('w', encoding='utf-8', newline='\n') as report:
            self.report = report
            self.say('ULX5M-GS acceptance start; UTC ' + datetime.now(timezone.utc).isoformat())
            self.say('host=%s mode=%s seed=%d cycles=%d' %
                     (self.platform, self.args.mode, SEED, self.args.cycles))
            self.say('[LOG] ' + str(self.outdir / 'report.txt'))
            try:
                self.offline()
                if self.args.mode == 'full':
                    self.full()
                self.say('\n[PASS] ' + ('OFFLINE qualification complete' if self.args.mode == 'offline'
                                         else 'CORE FWTF BOOTLOADER ACCEPTANCE COMPLETE'))
                self.say('[RESULT] %d automated checks passed; operator hardware '
                         'checks were recorded separately' % len(self.passed))
                return 0
            except (StopTest, KeyboardInterrupt, OSError) as exc:
                self.say('\n[FAIL/STOP] ' + str(exc))
                self.say('[RESULT] Incomplete acceptance. Do NOT infer bootloader failure '
                         'from a missing prerequisite or an operator stop.')
                self.say('[SAFETY] Retain logs, builds, and recovery backups; no automatic retries.')
                return 1
            finally:
                self.say('[LOG] ' + str(self.outdir / 'report.txt'))
                self.report = None


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('offline', 'full'), default='offline',
                        help='offline is default; full includes manual physical tests and a confirmed USB rewrite')
    parser.add_argument('--install-primary', action='store_true',
                        help='with full mode, separately confirm guarded JTAG primary installation; '
                             'requires working FWTN and the known secondary already present')
    parser.add_argument('--cycles', type=int, default=3, help='normal+DFU cold-boot repetitions (1..20; default 3)')
    parser.add_argument('--audit-flash', action='store_true',
                        help='with full mode, optional independent JTAG 4 MiB before/after '
                             'audit of identical-image USB rewrite; requires Tigard')
    parser.add_argument('--plan', action='store_true', help='print plan only, no build or hardware access')
    args = parser.parse_args(argv)
    if args.install_primary and args.mode != 'full':
        parser.error('--install-primary requires --mode full')
    if args.audit_flash and args.mode != 'full':
        parser.error('--audit-flash requires --mode full')
    if not 1 <= args.cycles <= 20:
        parser.error('--cycles must be 1..20')
    return args


if __name__ == '__main__':
    sys.exit(Acceptance(parse_args()).main())
