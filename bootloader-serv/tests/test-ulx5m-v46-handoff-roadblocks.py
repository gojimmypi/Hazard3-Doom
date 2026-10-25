#!/usr/bin/env python3
"""Offline regression: diagnose three distinct v43/DFU handoff mechanisms.

Reports observed artifacts and source contract, NOT silicon success.
No FPGA tools or hardware interfaces are used.
"""
import hashlib
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build-ulx5m-gs"
SOURCE_SHA = "c298999e6a19604018f0b8be8ceadb3572b95b00d90475c1017fd3a037e9ff84"
CANDIDATE_SHA = "2195166eb2035d9fb0ca22d99b37fd4ea8ba49488e808cf864eee0df127dddc0"
APP_SHA = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
COMMAND_PAIR = bytes.fromhex("c3010cfe00ccc6da0428eb001020002951")
SOURCE = BUILD / "cfg-probe/top_ulx5m_gs_cfg_probe.bit"
CANDIDATE = BUILD / "cfg-probe/top_ulx5m_gs_cfg_probe-bootaddr-201000-v43.bit"
ROM = BUILD / "cfg-probe/walking-led.hex"
APP = BUILD / "top_ulx5m_gs_normal_led.bit"


def pinned(path, size, digest):
    data = path.read_bytes()
    if len(data) != size or hashlib.sha256(data).hexdigest() != digest:
        raise ValueError("Non-pinned input: %s" % path)
    return data


class HandoffRoadblocks(unittest.TestCase):
    def test_v43_exact_artifacts_and_diff(self):
        source = pinned(SOURCE, 31411, SOURCE_SHA)
        candidate = pinned(CANDIDATE, 31430, CANDIDATE_SHA)
        differences = [i for i in range(len(source)) if source[i] != candidate[i]]
        self.assertEqual(differences, [31388, 31389, 31392, 31393, 31400, 31401])
        self.assertEqual(candidate[len(source):], COMMAND_PAIR + b"\x00\x00")
        self.assertNotEqual(source[-19:], COMMAND_PAIR + b"\x00\x00")
        print("[OBSERVED] Six status/CRC byte changes plus appended 17-byte command pair")

    def test_command_target_is_native_slot_not_source_rom(self):
        pinned(CANDIDATE, 31430, CANDIDATE_SHA)
        jump = COMMAND_PAIR[7:]
        self.assertEqual(jump[:1], b"\xda")
        self.assertEqual(jump[4:8], b"\x00\x10\x20\x00")
        self.assertEqual(int.from_bytes(jump[4:8], "little"), 0x201000)
        print("[OBSERVED] JTAG candidate CMD_JUMP targets 0x201000; execution NOT proven")

    def test_btn3_rom_is_not_jtag_candidate(self):
        app = pinned(APP, 3026, APP_SHA)
        words = ROM.read_text(encoding="ascii").split()
        self.assertEqual(len(words), 3026)
        self.assertTrue(all(re.fullmatch(r"[0-9a-fA-F]{2}", word) for word in words))
        self.assertEqual(bytes(int(word, 16) for word in words), app)
        self.assertNotIn(COMMAND_PAIR, app)
        print("[ROADBLOCK] BTN3 ROM is the plain application; no bootaddr command pair")

    def test_btn3_rtl_has_no_flash_reader(self):
        rtl = (ROOT / "rtl/top-ulx5m-gs-cfg-probe.v").read_text(encoding="utf8")
        self.assertIn("CC_CFG_CTRL", rtl)
        self.assertIn("image_rom[byte_index]", rtl)
        self.assertIn("state == FINISHED", rtl)
        self.assertNotIn("SPI_CS_N", rtl)
        print("[ROADBLOCK] Source FINISHED LED is byte-stream completion only")

    def test_old_normal_boot_contract_misses_raw_native_slot(self):
        header = (ROOT / "fw/ulx5m_normal_boot.h").read_text(encoding="utf8")
        code = (ROOT / "fw/ulx5m_normal_boot.c").read_text(encoding="utf8")
        self.assertIn("#define ULX5M_NORMAL_BOOT_SLOT 0x00200000u", header)
        self.assertIn("ULX5M_NORMAL_BOOT_SLOT + 256u", code)
        self.assertIn("ulx5m_normal_image_probe", code)
        self.assertEqual(0x200000 + 256, 0x200100)
        self.assertNotEqual(0x200100, 0x201000)
        print("[ROADBLOCK] Legacy C expects U5IM @ 0x200000, payload @ 0x200100")
        print("[FIX PREPARED] New native v41 reader verifies raw payload @ 0x201000")


if __name__ == "__main__":
    unittest.main(verbosity=2)
