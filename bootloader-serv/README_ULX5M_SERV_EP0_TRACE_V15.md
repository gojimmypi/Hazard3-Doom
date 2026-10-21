# ULX5M-GS SERV EP0 hardware trace (v15 proposed)

This is a diagnostic change under `bootloader-serv/` only. It is not a USB protocol fix.
No SPI flash write/erase operations or DFU DNLOAD support are added.

## Motivation

With v14 seed 4 (51.37 MHz), the Windows host completed 66 GET_DESCRIPTOR
transfers before `Pipe error`. The post-failure 16-byte EP0 snapshot retained:

- Prior request `0x06`, state `STATUS_DONE_OUT`.
- IN BD `0x4012` (18-byte RDY_DATA), OUT BD `0x4040` (64-byte RDY_DATA).
- `setup_busy` incremented; no firmware-observed IN/OUT/SETUP descriptor errors.
- Bus reset count did not increase.

The firmware handed the IN buffer to the USB controller. v14 could not establish
whether the controller saw an IN token, transmitted data, or received a host ACK.

## Design

With `ULX5M_USE_SERV`, the top module enables `.EP0_TRACE(1)` in `usb.v`.
The FPGA samples existing USB packet/transaction signals using independent
counters. The counters do not feed the USB transaction engine. The USB core
exposes them as read-only 16-bit CSR words in the existing Wishbone address
window. Firmware captures them when the first diagnostic SETUP (vendor IN `0x54`)
arrives, at the same point where v14 captures the pre-SETUP EP0 descriptors.
Further diagnostic pages/retries do not overwrite that capture.

The `0x54` response is still exactly 16 bytes. Existing pages 0..4 are
unchanged. New pages 5..8 contain the trace values (3 values per page).

| USB CSR word address | CPU byte offset | Counter / value |
|---|---|---|
| 0x20 | 0x80 | signature 0xE015 |
| 0x21 | 0x84 | EP0 IN tokens received (valid, matching address) |
| 0x22 | 0x88 | EP0 DATA0/DATA1 TX starts |
| 0x23 | 0x8C | EP0 DATA0/DATA1 TX done |
| 0x24 | 0x90 | EP0 ACK handshakes received |
| 0x25 | 0x94 | EP0 NAK TX starts |
| 0x26 | 0x98 | EP0 STALL TX starts |
| 0x27 | 0x9C | RX packet errors while EP0 was selected |
| 0x28 | 0xA0 | Last EP0 DATA TX length |
| 0x29 | 0xA4 | Last EP0 TX PID (low nibble) |

Each counter wraps modulo 65536. Counters are cumulative until FPGA reset.
The RX error counter is qualified by the last selected transaction endpoint,
not by a decoded address/endp on the corrupted packet; it is only a clue.
Likewise, these counters report internal USB engine events, not electrical
signals observed on the USB cable.

## Apply and build (WSL, offline: USB device unavailable to WSL)

Extract the ZIP at the Hazard3-Doom repository root. Do not overwrite the
separately maintained `bootloader/` PicoRV32 code.

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
python3 tests/test-ulx5m-serv-ep0-diag.py
python3 tests/test-ulx5m-serv-ep0-trace-decoder.py
python3 tests/test-ulx5m-serv-usb-copy.py
make -f Makefile.ulx5m-gs check-serv
make -f Makefile.ulx5m-gs test-flash-serv-firmware
make -f Makefile.ulx5m-gs flash-read-serv
```

`flash-read-serv` builds firmware, synthesizes and routes GateMate, and
packages a bitstream. **It does not access USB, JTAG, or SPI flash.**

The new trace logic changes the synthesized hardware netlist. Do not reuse
any v14 `.txt` or `.bit` file. If the default route fails 48 MHz timing:

```bash
./scripts/sweep-ulx5m-serv.sh 1 16
```

Select the best passing seed, verify the sweep's `inputs.sha256`, and package
its `.txt` with `gmpack` using the exact directory and seed reported. The
previous seed 4 is not guaranteed to pass timing with v15 RTL.

## Load only SRAM (Windows executable invoked from WSL)

After making `top_ulx5m_gs_flash_read-serv-v15.bit` from a passing route:

```bash
cd /mnt/c/workspace/Hazard3-Doom
./bin/openFPGALoader.exe -c tigard --freq 100k -m \
  bootloader-serv/build-ulx5m-gs/top_ulx5m_gs_flash_read-serv-v15.bit
```

**Never use `-f`** in this experiment: that writes persistent configuration.

## Diagnose USB (native Windows PowerShell, not WSL)

```powershell
cd C:\workspace\Hazard3-Doom
py .\bootloader-serv\tests\diagnose-ulx5m-serv-ep0.py --stats-only
py .\bootloader-serv\tests\diagnose-ulx5m-serv-ep0.py --rounds 256 --delay-ms 100
```

Requires the existing Windows WinUSB driver, PyUSB and
`C:\workspace\Hazard3-Doom\bin\libusb-1.0.dll`.
The host tool fails clearly if the v15 hardware signature is missing.

### How to interpret the counters

Compare the `AFTER FAILURE` minus `BASELINE` deltas, but allow for the
known successful descriptor requests between them. The hardware snapshot
is frozen at the *first diagnostic SETUP after the failure*, before the
new diagnostic response. The snapshot includes the diagnostic SETUP itself
but not its IN packet. An incomplete transfer may be retried by the host.

- More EP0 IN tokens but no corresponding DATA starts: engine did not launch
  the expected data packet (or replied NAK/STALL).
- DATA starts but missing DATA done: focus on `usb_tx_pkt.v` / TX low level.
- DATA done but fewer ACKs: host may reject/not acknowledge data, or ACK may
  be lost/not decoded. Inspect CRC, PHY and cable; not proof of cable fault.
- ACK count advances yet IN BD remains RDY_DATA: focus on transaction
  microcode ACK / BD writeback state.
- An EP0 STALL TX increment is stronger evidence of a device-sent STALL than
  a Windows libusb `Pipe error` by itself.

Counters include normal traffic and possibly retransmissions. Never expect
an exact 1:1 ratio with the number of successful host requests.

## Current validation

Performed without FPGA tools in the assistant environment:

- EP0 host harness (including retried/latching diagnostic pages): PASS.
- v15 Windows snapshot decoder self-test: PASS.
- C syntax, SERV and non-SERV configurations: PASS (host GCC with `-fno-builtin`).
- Python source bytecode compile: PASS.

**Not yet performed:** Icarus/Verilator simulation of the new trace RTL,
GateMate Yosys synthesis, nextpnr timing, JTAG programming and v15 hardware USB
measurements. This is a proposed diagnostic patch, not a proven FPGA build.

## Files modified in this patch

- `cores/usb/rtl/usb_trans.v`
- `cores/usb/rtl/usb.v`
- `rtl/top-ulx5m-gs-flash-read.v`
- `fw/usb_ep0_diag.h`
- `fw/usb_ctrl_ep0.c`
- `tests/diagnose-ulx5m-serv-ep0.py`
- `tests/test-ulx5m-serv-ep0-diag.py`
- `tests/test-ulx5m-serv-ep0-trace-decoder.py` (new)
- This README and `HANDOFF_ULX5M_SERV_EP0_V15.md` (new)

## v15a timing retiming (proposed, not yet routed)

The v15 seed sweep on 2026-10-19 failed all 16 seeds at a 48 MHz
constraint; the best was seed 5 at 36.76 MHz. The routed critical path
repeatedly passes through `usb_i.csr_bus_dout` to a memory-response register.
Do not use any of the failed v15 implementations on hardware.

The v15a candidate keeps the same EP0 counters, CSR addresses, diagnostic
pages and firmware. Only the trace CSR bus readback is split into clocked
address capture, counter mux/data capture, and acknowledgement stages.
Normal USB CSRs and endpoint buffer accesses retain their original timings.
The trace CSR access adds one clock cycle to its acknowledgement compared
with v15. These registers are read-only; no USB transaction state is changed.

From WSL, run `make -f Makefile.ulx5m-gs test-flash-serv-ep0-trace`
first, followed by the v15 checks and the `flash-read-serv` make target.
A new synthesis and route are mandatory. If the default
route fails, run a small new seed sweep using the NEW JSON. Do not reuse
any old `.txt` or `.bit` files. The retiming is a timing hypothesis until
both simulation and GateMate routing pass.
