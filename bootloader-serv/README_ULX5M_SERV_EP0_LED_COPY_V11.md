# ULX5M-GS SERV LED and USB data-copy test (v11)

Scope: `bootloader-serv/` only. The PicoRV32 fallback under `bootloader/`
remains unchanged. This test image performs no flash erase or program operations.

## Observations

- The original SERV firmware passed 640/640 GET_STATUS requests, but
  GET_DESCRIPTOR sometimes returned a libusb pipe error.
- Two interleaved GET_DESCRIPTOR tests (128 rounds of 18, 8, 16 bytes each)
  produced one failure each at lengths 8, 16, and two at 18. The results do
  not establish that 18-byte requests uniquely fail.
- A prior ULX5M-GS V005 JEDEC RTL test documented active-high LEDs and
  swaps of physical D4/D5 and D6/D7. The previous SERV status module
  used active-low outputs without these swaps. It predicted the observed
  D0-D2 OFF, D3-D5 ON, D6 blinking, D7 OFF pattern even after firmware boot.

## Changes

1. `rtl/soc_ulx5m_misc.v`: use the proven V005 physical active-high
   LED mapping. Expected after firmware initialization: physical D0-D2 ON,
   D3-D5 OFF, D6 ON (PLL locked), D7 blinking (heartbeat).
2. `fw/usb.c`: copy complete 32-bit words when the source is aligned,
   handle unaligned sources byte-by-byte, and zero-pad a final partial word
   without reading past the requested source length. The old code read 20
   bytes for an 18-byte descriptor.
3. `tests/test-ulx5m-serv-usb-copy.py`: host GCC + AddressSanitizer
   regression, covering source alignments 0..3 and sizes 0..65 bytes.
4. `tests/stress-ulx5m-serv-ep0.py`: repeatable read-only Windows PyUSB
   test using the repository's native `bin/libusb-1.0.dll`.

The partial-word overread is a concrete correctness defect. It is not yet
proven to explain the intermittent USB pipe errors, and the LED change is
unrelated to USB. The v10 unconditional EP0 polling diagnostic remains
present; it did not independently fix the hardware failures.

## Validate and build

From WSL:

```bash
cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
python3 tests/test-ulx5m-serv-usb-copy.py
make -f Makefile.ulx5m-gs check-serv
make -f Makefile.ulx5m-gs test-flash-serv-firmware
make -f Makefile.ulx5m-gs flash-read-serv
```

The LED RTL change and firmware data-copy change both affect the synthesized
image. **Do not** reuse the previous seed-1 route/bitstream. Inspect the new
`build-ulx5m-gs/flash-read-serv-pnr.log` for at least 48 MHz post-route. If
it fails, rerun the SERV seed sweep on the newly synthesized JSON and pack a
passing route. Do not JTAG-load a timing-failing route as a reliability test.

From the repository root, use only the Windows executable, with JTAG volatile
SRAM programming, after confirming the new route passes:

```bash
./bin/openFPGALoader.exe -c tigard --freq 100k -m \
  bootloader-serv/build-ulx5m-gs/top_ulx5m_gs_flash_read-serv.bit
```

**Never add `-f`**: that would request persistent flash programming.

In native Windows PowerShell:

```powershell
cd C:\workspace\Hazard3-Doom
py .\bootloader-serv\tests\stress-ulx5m-serv-ep0.py --runs 5 --rounds 128 --delay-ms 100
```

This runs interleaved 18-, 8-, and 16-byte GET_DESCRIPTOR requests. Report
counts by length and any errors. If failures remain, prioritize EP0 IN
buffer-descriptor ownership, SETUP re-arm timing, and the status stage before
changing the QSPI peripheral or introducing flash writes.
