#!/usr/bin/env python3
"""Offline FLM1 host parser/protocol test. No USB device required."""
import importlib.util
import struct
from pathlib import Path

path = Path(__file__).with_name("diagnose-ulx5m-serv-dfu-stage.py")
spec = importlib.util.spec_from_file_location("dfu_stage_diag", path)
diag = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diag)


class FakeFlash:
    def __init__(self, jedec=b"\x1f\x42\x16"):
        self.jedec = jedec
        self.calls = []

    def ctrl_transfer(self, bm, req, value, index, length, timeout):
        self.calls.append((bm, req, value, index, length))
        assert (bm, value, index) == (0xc0, 0, 0)
        if req == 0x51:
            assert length == 3
            return self.jedec
        if req == diag.FLASH_LAYOUT_REQ:
            assert length == 32
            return b"FLM1" + struct.pack("<7I", 0x400000, 4096, 256,
                                           0, 0x400000, 0, 3)
        raise AssertionError("Unexpected or mutating USB request")


payload = b"FLM1" + struct.pack("<7I", 0x400000, 4096, 256,
                                0, 0x400000, 0, 3)
assert diag.parse_flash_layout(payload) == (0x400000, 4096, 256, 0,
                                             0x400000, 0, 3)
for invalid in (payload[:-1], b"BAD1" + payload[4:],
                payload[:-4] + struct.pack("<I", 0),
                payload[:24] + struct.pack("<I", 1) + payload[28:]):
    try:
        diag.parse_flash_layout(invalid)
    except ValueError:
        pass
    else:
        raise AssertionError("Invalid layout report accepted")

dev = FakeFlash()
diag.inspect_flash_layout(dev, 1000)
assert [call[0:2] for call in dev.calls] == [(0xc0, 0x51), (0xc0, 0x58)]
try:
    diag.inspect_flash_layout(FakeFlash(jedec=b"\x00\x00\x00"), 1000)
except RuntimeError:
    pass
else:
    raise AssertionError("Unexpected flash JEDEC ID accepted")
print("[PASS] FLM1 host parser, read-only requests, JEDEC mismatch refusal")
