#!/usr/bin/env python3
"""Offline source guards for the experimental ULX5M-GS SERV target."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
read = lambda p: (root / p).read_text(encoding="ascii")
make = read("Makefile.ulx5m-gs")
top = read("rtl/top-ulx5m-gs-flash-read.v")
adapter = read("rtl/soc_serv_cpu.v")
start = read("fw/start.S")
fw_make = read("fw/Makefile.ulx5m-flash-read")
test = read("tests/tb_ulx5m_serv_flash_bram_pipe.v")

assert 'SERV_TAG := 1.4.0' in make
assert 'SERV_COMMIT := 7d9cde4' in make
assert 'flash-read-serv: $(SERV_BIT)' in make
assert 'rtl/soc_serv_cpu.v' in make
assert '$(filter-out rtl/picorv32.v,$(FLASH_SRC))' in make
assert '$(FLASH_CCF)' in make and '$(FLASH_SDC)' in make
assert 'test-flash-serv-bus:' in make
assert 'test-flash-serv-bus: $(SERV_STAMP)' in make
assert 'flash-read-probe: $(FLASH_BIT)' in make
assert 'flash dfu:' in make
assert '`ifdef ULX5M_USE_SERV' in top
assert '`else\n    picorv32 #(' in top
assert 'soc_serv_cpu serv_i' in top
assert 'build-ulx5m-gs/serv/fw_ulx5m_flash_read.hex' in top
assert 'build-ulx5m-gs/fw_ulx5m_flash_read.hex' in top
assert 'qspi_master_wb #(.N_CS(1))' in top
assert 'usb #(.TARGET("GATEMATE")' in top
assert 'serv_rf_top #(' in adapter
for param in ('.WITH_CSR(0)', '.W(1)', '.MDU(1\'b0)',
              '.COMPRESSED(1\'b0)', '.PRE_REGISTER(0)'):
    assert param in adapter, param
assert 'assign mem_wstrb = (dbus_cyc && dbus_we && !ibus_cyc)' in adapter
assert 'mem_ready && ibus_cyc' in adapter
assert 'mem_ready && dbus_cyc && !ibus_cyc' in adapter
assert 'li sp, 0x8000' in start
assert '#ifdef ULX5M_SERV_TEST' in start
assert '-DULX5M_SERV_TEST=1' in fw_make
assert 'for (i = 0; i < 30000;' in test
print('[PASS] SERV isolated build, bus ACK gating, RV32I and firmware stack guards')
print('[PASS] Original PicoRV32 target and read-only peripherals retained')
