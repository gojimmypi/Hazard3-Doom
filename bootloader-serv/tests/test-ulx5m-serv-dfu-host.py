#!/usr/bin/env python3
"""Offline selftest for the native Windows RAM-only DFU multiblock host tool."""
import importlib.util
import struct
import zlib
from pathlib import Path

MODULE_PATH = Path(__file__).with_name('diagnose-ulx5m-serv-dfu-stage.py')
spec = importlib.util.spec_from_file_location('ulx5m_dfu_host', MODULE_PATH)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class FakeStage:
    def __init__(self, corrupt_at=0, fail_getstatus_at=0):
        self.corrupt_at = corrupt_at
        self.fail_getstatus_at = fail_getstatus_at
        self.calls = []
        self.reset()

    def reset(self):
        self.data = bytearray()
        self.next_block = 0
        self.state = mod.DFU_IDLE
        self.status = 0

    def ctrl_transfer(self, bm, req, wvalue, windex, data, timeout):
        self.calls.append((bm, req, wvalue, windex, data))
        assert timeout > 0 and windex == 0
        if (bm, req) == (0xc0, mod.STG_INFO_REQ):
            assert wvalue == 0 and data == mod.STG_INFO_LEN
            crc = zlib.crc32(self.data) & 0xffffffff
            if self.corrupt_at and self.next_block == self.corrupt_at:
                crc ^= 1
            return b'STG1' + struct.pack('<IIHBB',
                                          len(self.data), crc, self.next_block,
                                          self.state, self.status)
        if (bm, req) == (0x21, mod.DFU_DNLOAD):
            assert self.state in (mod.DFU_IDLE, mod.DFU_DNLOAD_IDLE)
            assert wvalue == self.next_block
            assert 1 <= len(data) <= mod.TRANSFER_SIZE
            assert len(self.data) + len(data) <= mod.STAGE_CAPACITY
            self.data.extend(data)
            self.next_block += 1
            self.state = mod.DFU_DNLOAD_SYNC
            return len(data)
        if (bm, req) == (0xa1, mod.DFU_GETSTATUS):
            assert wvalue == 0 and data == 6
            if self.fail_getstatus_at == self.next_block:
                self.state = mod.DFU_ERROR
                self.status = 3
            elif self.state == mod.DFU_DNLOAD_SYNC:
                self.state = mod.DFU_DNLOAD_IDLE
            return bytes((self.status, 0, 0, 0, self.state, 0))
        if (bm, req) == (0x21, mod.DFU_ABORT):
            assert not data and wvalue == 0
            assert self.state in (mod.DFU_IDLE, mod.DFU_DNLOAD_SYNC,
                                  mod.DFU_DNLOAD_IDLE)
            self.reset()
            return 0
        if (bm, req) == (0x21, mod.DFU_CLRSTATUS):
            assert self.state == mod.DFU_ERROR
            assert not data and wvalue == 0
            self.reset()
            return 0
        raise AssertionError('Unexpected USB request: {} {}'.format(bm, req))


def check_success(count):
    dev = FakeStage()
    mod.exercise_blocks(dev, 1000, count, sleep=lambda unused: None)
    assert (len(dev.data), dev.next_block, dev.state) == (0, 0, mod.DFU_IDLE)
    out = [call for call in dev.calls if call[:2] == (0x21, mod.DFU_DNLOAD)]
    nblocks = (count + mod.TRANSFER_SIZE - 1) // mod.TRANSFER_SIZE
    assert len(out) == nblocks
    assert [request[2] for request in out] == list(range(nblocks))
    assert sum(len(request[4]) for request in out) == count
    assert all(len(request[4]) > 0 for request in out)
    assert len([call for call in dev.calls if call[:2] ==
                (0xa1, mod.DFU_GETSTATUS)]) == nblocks
    assert len([call for call in dev.calls if call[:2] ==
                (0x21, mod.DFU_ABORT)]) == 1
    assert not any(call[:2] == (0x21, mod.DFU_CLRSTATUS) for call in dev.calls)


def check_failure(case, **kwargs):
    dev = FakeStage(**kwargs)
    try:
        mod.exercise_blocks(dev, 1000, 192, sleep=lambda unused: None)
    except RuntimeError:
        pass
    else:
        raise AssertionError('Expected error not raised: ' + case)
    assert dev.state == mod.DFU_IDLE and not dev.data and dev.next_block == 0
    recovery = mod.DFU_CLRSTATUS if 'status' in case else mod.DFU_ABORT
    assert any(call[:2] == (0x21, recovery) for call in dev.calls)


def main():
    for count in (1, 9, 63, 64, 65, 192, 4095, 4096):
        check_success(count)
    for invalid in (0, 4097):
        try:
            mod.exercise_blocks(FakeStage(), 1000, invalid)
        except ValueError:
            pass
        else:
            raise AssertionError('Invalid byte count accepted')
    check_failure('crc', corrupt_at=2)
    check_failure('status', fail_getstatus_at=2)
    print('[PASS] DFU multiblock host test: 1..4096 bytes, CRC, state, ABORT/CLRSTATUS')


if __name__ == '__main__':
    main()
