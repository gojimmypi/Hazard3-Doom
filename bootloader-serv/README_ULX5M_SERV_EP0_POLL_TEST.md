# ULX5M SERV EP0 polling diagnostic (v10)

Scope: `bootloader-serv/` only. This is a diagnostic experiment, not a
production fix. The PicoRV32 fallback in `bootloader/` is unchanged.

## Why

Hardware descriptor requests sporadically fail with a libusb pipe error,
even with 100 ms pacing and a 51.66 MHz timing route. A subsequent
request succeeds after waiting one second. The existing firmware calls
`usb_ep0_poll()` only when the USB CSR reports an event pending. The
USB RTL stores a 4-bit event count when EVT_DEPTH=0, which can wrap.
That is a hypothesis, not proof of the observed failures.

For builds compiled with `ULX5M_SERV_TEST`, `fw/usb.c` now processes
EP0 buffer descriptors every pass through `usb_poll()`, including
passes where the event count is zero. Event-register reads still drain
notifications when present. Non-SERV firmware behavior is unchanged.

## Test procedure

From `bootloader-serv/` in WSL:

```bash
make -f Makefile.ulx5m-gs check-serv
make -f Makefile.ulx5m-gs test-flash-serv-firmware
make -f Makefile.ulx5m-gs flash-read-serv
```

Do not reuse the old seed-1 routed implementation for this changed
firmware: it contains the previous BRAM contents. Because the new
firmware changes the synthesized design, recheck route timing against
48 MHz. If the default route fails, run the existing SERV timing sweep
on the newly generated JSON, choose a passing route, and pack *that*
route with `gmpack`. Do not assume seed 1 passes after changing firmware.

From the repository root, use the Windows programmer for volatile RAM
only (no `-f`):

```bash
./bin/openFPGALoader.exe -c tigard --freq 100k -m \
  bootloader-serv/build-ulx5m-gs/top_ulx5m_gs_flash_read-serv.bit
```

Then rerun the same 128-GET_DESCRIPTOR PowerShell test (100 ms gaps)
several times. Compare number of successes and recovery behavior against
the original SERV seed-1 bitstream, saved as:

`build-ulx5m-gs/top_ulx5m_gs_flash_read-serv-seed1.bit`

If failures continue, the missed-event hypothesis is insufficient;
inspect EP0 SETUP re-arm, data/status stage transitions, and USB RTL.

## Safety

No QSPI flash-write or erase operation is introduced. The test changes
firmware polling only. The Windows USB driver and the PicoRV32 fallback
are unchanged.
