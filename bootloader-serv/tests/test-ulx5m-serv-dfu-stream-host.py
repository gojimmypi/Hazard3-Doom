#!/usr/bin/env python3
"""Offline host protocol tests for discard-only STR1 DFU streaming."""
import importlib.util
import pathlib
import unittest
import zlib

MODULE = pathlib.Path(__file__).with_name("diagnose-ulx5m-serv-dfu-stream.py")
spec = importlib.util.spec_from_file_location("ulx5m_dfu_stream_host", MODULE)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Device:
    def __init__(self, *, bad_crc=False, fail_at=None):
        self.buf = b""
        self.block = 0
        self.state = m.DFU_IDLE
        self.bad_crc = bad_crc
        self.fail_at = fail_at
        self.out_count = 0
        self.requests = []

    def ctrl_transfer(self, typ, cmd, value, index, payload, timeout=None):
        self.requests.append((typ, cmd, value, index))
        if (typ, cmd) == (0xc0, m.INFO_REQ):
            crc = zlib.crc32(self.buf) & 0xffffffff
            if self.bad_crc and self.block:
                crc ^= 1
            return (b"STR1" + len(self.buf).to_bytes(4, "little") +
                    crc.to_bytes(4, "little") +
                    self.block.to_bytes(2, "little") +
                    bytes((self.state, 0)) + m.MAX_BYTES.to_bytes(4, "little"))
        if (typ, cmd) == (0x21, 1):
            if self.fail_at == self.out_count:
                raise IOError("simulated transport loss")
            data = bytes(payload)
            assert value == self.block and len(data) <= 64
            self.buf += data
            self.block += 1
            self.out_count += 1
            self.state = m.DFU_SYNC
            return len(data)
        if (typ, cmd) == (0xa1, 3):
            assert self.state == m.DFU_SYNC
            self.state = m.DFU_DOWNLOAD_IDLE
            return bytes((0, 0, 0, 0, m.DFU_DOWNLOAD_IDLE, 0))
        if (typ, cmd) in ((0x21, 6), (0x21, 4)):
            self.buf = b""
            self.block = 0
            self.state = m.DFU_IDLE
            return 0
        raise AssertionError("Unexpected USB operation: {} {}".format(typ, cmd))


class StreamTests(unittest.TestCase):
    def test_info_validation(self):
        d = Device()
        self.assertEqual(m.read_info(d, 1000), (0, 0, 0, 2, 0, m.MAX_BYTES))
        with self.assertRaises(ValueError):
            m.parse_info(b"STG1" + b"\0" * 16)
        with self.assertRaises(ValueError):
            m.parse_info(b"STR1" + b"\0" * 16)

    def test_small_full_partial(self):
        for size in (1, 9, 64, 65, 4096, 16384, 65537):
            d = Device()
            payload = bytes(m.payload_byte(i) for i in range(size))
            crc = m.exercise(d, payload, sleep=lambda _: None,
                             progress=lambda _: None)
            self.assertEqual(crc, zlib.crc32(payload) & 0xffffffff)
            self.assertEqual(m.read_info(d, 1000), (0, 0, 0, 2, 0, m.MAX_BYTES))
            self.assertEqual(sum(t[:2] == (0x21, 1) for t in d.requests),
                             (size + 63) // 64)
            self.assertNotIn((0x21, 1, (size + 63)//64, 0), d.requests)

    def test_disallow_oversized(self):
        d = Device()
        for n in (0, m.MAX_BYTES + 1):
            with self.assertRaises(ValueError):
                m.exercise(d, b"x" * n, progress=lambda _: None)
        self.assertEqual(d.requests, [])

    def test_bad_crc_rejected_and_abort(self):
        d = Device(bad_crc=True)
        with self.assertRaises(RuntimeError):
            m.exercise(d, b"abc", sleep=lambda _: None, progress=lambda _: None)
        self.assertEqual(m.read_info(d, 1000)[0], 0)

    def test_transport_loss_no_dnload_retry(self):
        d = Device(fail_at=1)
        with self.assertRaises(IOError):
            m.exercise(d, b"z" * 192, progress=lambda _: None)
        self.assertEqual(sum(t[:2] == (0x21, 1) and t[2] == 1
                             for t in d.requests), 1)
        self.assertEqual(m.read_info(d, 1000)[0], 0)

    def test_read_only_default_and_no_flash_request(self):
        d = Device()
        self.assertEqual(m.read_info(d, 1000)[0], 0)
        self.assertTrue(all(cmd != 0x52 for _, cmd, _, _ in d.requests))


if __name__ == "__main__":
    unittest.main(verbosity=2)
