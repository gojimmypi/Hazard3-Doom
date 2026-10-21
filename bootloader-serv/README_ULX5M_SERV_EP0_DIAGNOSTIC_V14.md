# ULX5M-GS SERV EP0 short diagnostic v14

This diagnostic responds to intermittent WinUSB control-transfer failures.
It does not claim to correct USB protocol handling.

## Changes

- Keep legacy vendor IN request `0x53` (60-byte EPD1).
- Add vendor IN request `0x54` (EPS1, 16-byte page, `wIndex=0`,
  `wValue` selects page 0..4, `wLength=16`). Only valid in the SERV
  diagnostic firmware configuration (`ULX5M_SERV_TEST`).
- Save the EP0 state and IN/OUT BD values immediately before the first
  diagnostic SETUP following a non-diagnostic request. Retries and other
  diagnostic page requests do not overwrite that state. A subsequent
  non-diagnostic request allows a fresh snapshot.
- Retain all v13 counters. Counter pages are live, so values can change
  between separate requests; page 0 is the latched pre-diagnostic state.

Page 0: EPS1 magic; version/state/previous request/reset count; IN BD; OUT BD.
Page 1: EPS1; setup_ok; in_ok; status_out_ok.
Page 2: EPS1; setup_err; in_err; out_err.
Page 3: EPS1; stalls; setup_busy; unexpected_in.
Page 4: EPS1; unexpected_out; bad_status_len; reserved.

This is a read-only USB interface. No flash erase/program or DFU download
functionality has been added. `bootloader/` is untouched.

## Build and test on WSL

Extract this ZIP at the Hazard3-Doom repository root, preserving paths.
It assumes v13 and the v13a host-only test fix were already applied.

```
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
python3 tests/test-ulx5m-serv-ep0-diag.py
python3 tests/test-ulx5m-serv-usb-copy.py
make -f Makefile.ulx5m-gs check-serv
make -f Makefile.ulx5m-gs test-flash-serv-firmware
make -f Makefile.ulx5m-gs flash-read-serv
```

If the default nextpnr route fails timing, run `./scripts/sweep-ulx5m-serv.sh 1 16`
and use a passing route with matching JSON/CCF/SDC input checksums.
Do not reuse a v13 implementation for v14; firmware changed.

Once you have a routed v14 bitstream, call the Windows executable from WSL:

```
cd /mnt/c/workspace/Hazard3-Doom
./bin/openFPGALoader.exe -c tigard --freq 100k -m \
  bootloader-serv/build-ulx5m-gs/top_ulx5m_gs_flash_read-serv-v14.bit
```

The `-m` option programs volatile SRAM, not SPI flash. Native Linux USB
access is not available in this WSL setup.

## USB diagnosis on native Windows PowerShell

```
cd C:\workspace\Hazard3-Doom
py .\bootloader-serv\tests\diagnose-ulx5m-serv-ep0.py --stats-only
py .\bootloader-serv\tests\diagnose-ulx5m-serv-ep0.py --rounds 256 --delay-ms 100
```

The script uses the repository's `bin/libusb-1.0.dll` and existing WinUSB
binding. It does not program hardware or depend on WSL USB forwarding.

## Interpretation

- `before_request=0x06` following a failed GET_DESCRIPTOR is evidence that
  the saved BD state belongs to the failed descriptor request. A different
  request code needs investigation before making conclusions.
- `RDY_DATA` on IN and OUT means firmware had armed both data and status
  buffers, but it does not prove a packet was transmitted or acknowledged.
- `stalls` includes deliberate rejections of unsupported USB requests.
  A WinUSB pipe error alone does not prove that the FPGA issued STALL.
- The short diagnostic itself can still fail. If no EPS1 response arrives,
  the counters are not available; do not interpret missing counters as zero.
