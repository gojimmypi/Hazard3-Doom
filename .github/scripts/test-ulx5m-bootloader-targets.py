#!/usr/bin/env python3
"""Offline regression for ULX5M normal-boot sweep target selection."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/ulx5m-bootloader-seed-sweep.yml"
DISPATCHER = ROOT / "scripts/sweep-ulx5m-bootloader.sh"
CHECKER = ROOT / "scripts/check-ulx5m-oss-cad-suite.sh"
MAKEFILE = ROOT / "bootloader-serv/Makefile.ulx5m-gs"


class SweepTargetTests(unittest.TestCase):
    def test_workflow_menu_and_validation(self):
        source = WORKFLOW.read_text(encoding="ascii")
        self.assertIn("default: normal-boot", source)
        # Keep the workflow dispatch menu and shell allowlist synchronized.
        # Checking one literal case arm broke when v73-integrated was added.
        target_block = re.search(
            r"(?ms)^      target:\n(.*?)(?=^      seed_first:)", source
        )
        self.assertIsNotNone(target_block)
        menu = set(re.findall(r"(?m)^\s+- ([a-z0-9-]+)$", target_block.group(1)))
        allowlist = re.search(
            r'(?m)^\s+(normal-boot(?:\|[a-z0-9-]+)+)\) ;;$', source
        )
        self.assertIsNotNone(allowlist)
        allowed = set(allowlist.group(1).split("|"))
        required = {
            "normal-boot", "v73-integrated", "spi-secondary",
            "flash-read-serv", "usb-probe", "flash-read-probe",
        }
        self.assertTrue(required.issubset(menu))
        self.assertEqual(menu, allowed)
        self.assertIn("test-ulx5m-bootloader-targets.py", source)
        self.assertIn("design=top_ulx5m_gs_flash_read-normal-boot", source)
        self.assertIn("source_dir=bootloader-serv", source)
        self.assertIn("constraint=top-ulx5m-gs-flash-read", source)
        self.assertIn('"build-ulx5m-gs/${design}.json"', source)
        self.assertIn('printf \'netlist_sha256=%s\\n\'', source)
        self.assertIn('grep -Fx "target=${SWEEP_TARGET}" frozen/metadata.txt', source)
        self.assertIn('(cd frozen && sha256sum --check SHA256SUMS)', source)
        self.assertIn('SWEEP_SKIP_SYNTH=1', source)

    def test_dispatcher_matches_normal_boot_make_target(self):
        source = DISPATCHER.read_text(encoding="ascii")
        match = re.search(r"(?m)^    normal-boot\)\n(.*?)^        ;;", source, re.S | re.M)
        self.assertIsNotNone(match)
        self.assertIn("source_subdir=bootloader-serv", match.group(1))
        self.assertIn("design=top_ulx5m_gs_flash_read-normal-boot", match.group(1))
        self.assertIn("constraint_stem=top-ulx5m-gs-flash-read", match.group(1))
        self.assertIn("synth_log=normal-boot-serv-synth.log", match.group(1))
        for other in ("usb-probe", "flash-read-probe", "flash-read-serv"):
            self.assertIn(f"    {other})", source)
        self.assertIn('"build-ulx5m-gs/$design.json"', source)
        self.assertIn('"$result_dir/inputs.sha256"', source)

    def test_makefile_builds_combined_serv_design(self):
        source = MAKEFILE.read_text(encoding="ascii")
        self.assertIn("NORMAL_BOOT_JSON := $(BUILD_DIR)/$(FLASH_TOP)-normal-boot.json", source)
        self.assertIn("$(NORMAL_BOOT_JSON): $(NORMAL_BOOT_FW)", source)
        self.assertIn("-DULX5M_USE_SERV", source)
        self.assertIn("-DULX5M_SERV_DFU_STREAM", source)
        self.assertIn("-DULX5M_SERV_BTN2_DFU_GATE", source)
        self.assertIn("-DULX5M_SERV_NORMAL_BOOT_EXPERIMENT", source)

    def test_real_dispatcher_offline_with_fake_packer_and_router(self):
        with tempfile.TemporaryDirectory(prefix="ulx5m-target-test-") as tmp:
            root = Path(tmp)
            scripts = root / "scripts"
            scripts.mkdir()
            shutil.copy2(DISPATCHER, scripts / DISPATCHER.name)
            shutil.copy2(CHECKER, scripts / CHECKER.name)
            tools = root / "tools"
            tools.mkdir()
            binaries = {
                "yosys": """#!/bin/sh
printf 'Yosys 0.67+47 (git sha1 5f29546d8-dirty, Release, Clang 18.1.8)\\n'
""",
                "nextpnr-himbaechel": """#!/usr/bin/env python3
import sys
from pathlib import Path
if '--version' in sys.argv:
    print('nextpnr-0.10-95-gddc6c8c8', file=sys.stderr)
    sys.exit(0)
args = sys.argv
out = next(x.split('=', 1)[1] for x in args if x.startswith('out='))
log = args[args.index('-l') + 1]
Path(out).write_text('fake route\\n', encoding='ascii')
Path(log).write_text("Routing complete.\\nMax frequency for clock 'bram_i.clk': 49.50 MHz (PASS at 48.00 MHz)\\n", encoding='ascii')
""",
                "gmpack": """#!/usr/bin/env python3
import shutil
import sys
if '--version' in sys.argv:
    print('mock gmpack')
else:
    shutil.copyfile(sys.argv[1], sys.argv[2])
""",
            }
            for name, content in binaries.items():
                path = tools / name
                path.write_text(content, encoding="ascii")
                path.chmod(0o755)
            for name in ("design.json", "constraints.ccf", "constraints.sdc"):
                (root / name).write_text("test input\n", encoding="ascii")
            dest = root / "results"
            env = os.environ.copy()
            env.update({
                "PATH": f"{tools}:{os.environ['PATH']}",
                "SWEEP_SKIP_SYNTH": "1",
                "SWEEP_JSON": str(root / "design.json"),
                "SWEEP_CCF": str(root / "constraints.ccf"),
                "SWEEP_SDC": str(root / "constraints.sdc"),
                "SWEEP_OUTPUT_DIR": str(dest),
            })
            result = subprocess.run(
                ["bash", str(scripts / DISPATCHER.name), "normal-boot", "147", "1", "30"],
                env=env, capture_output=True, text=True, timeout=15, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Target: normal-boot", result.stdout)
            self.assertIn("49.50 MHz", result.stdout)
            self.assertIn("1 PASS", (dest / "summary.md").read_text(encoding="ascii"))
            self.assertIn("target=normal-boot", (dest / "build-info.txt").read_text(encoding="ascii"))
            self.assertTrue((dest / "best-seed-147.bit").is_file())
            no = subprocess.run(
                ["bash", str(scripts / DISPATCHER.name), "bogus"],
                env=env, capture_output=True, text=True, timeout=5, check=False,
            )
            self.assertNotEqual(no.returncode, 0)
            self.assertIn("unsupported target", no.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
