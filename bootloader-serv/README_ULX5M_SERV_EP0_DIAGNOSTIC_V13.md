# ULX5M-GS SERV EP0 diagnostic, v13

Scope: `bootloader-serv/` only. This patch applies on top of the v11
USB-copy fix. The v12 LED/CCF cleanup may already be applied; it is
independent. It does not change the USB RTL, SPI/QSPI controller, DFU
write behavior, or PicoRV32 fallback in `bootloader/`.

## What changed

- `fw/usb_ctrl_ep0.c`: SERV-only counters for SETUP, completed IN data,
  completed OUT status, SETUP/IN/OUT errors, deliberate STALL, unexpected
  buffer completions and SETUP arriving while EP0 is busy. A new SETUP
  captures the previous EP0 state and IN/OUT buffer descriptor words
  **before** the normal handler clears them.
- `fw/usb_ep0_diag.h`: fixed request/response interface.
- `fw/fw_ulx5m_flash_read.c`: implements a strictly read-only vendor IN
  request `bmRequestType=0xC0`, `bRequest=0x53`, `wValue=0`, `wIndex=0`,
  `wLength=60`. The response is a single short 60-byte packet, not 64 bytes.
  No new requests write to SPI flash or modify device configuration.
- `tests/diagnose-ulx5m-serv-ep0.py`: native Windows PyUSB stress harness.
  It stops on the first descriptor failure and immediately asks for
  diagnostics, retrying the diagnostic request if needed.
- `tests/test-ulx5m-serv-ep0-diag.py`: host-only EP0 state/counter test using
  fake memory-mapped USB registers; does not require a USB device.

No diagnostic logic is enabled without `ULX5M_SERV_TEST=1`.

## Build and simulate (WSL)

From `/mnt/c/workspace/Hazard3-Doom/bootloader-serv`:

```bash
python3 tests/test-ulx5m-serv-ep0-diag.py
python3 tests/test-ulx5m-serv-usb-copy.py
make -f Makefile.ulx5m-gs check-serv
make -f Makefile.ulx5m-gs test-flash-serv-firmware
make -f Makefile.ulx5m-gs flash-read-serv
```

Note: the default route frequently FAILS 48 MHz. If it fails, run:

```bash
./scripts/sweep-ulx5m-serv.sh 1 16
```

Use the best **passing v13** seed, not the v11 seed-4 `.txt` file.
Verify the sweep input hashes and pack that seed's output:

```bash
sha256sum -c build-ulx5m-gs/serv-seed-sweep-<RUN>/inputs.sha256
gmpack build-ulx5m-gs/serv-seed-sweep-<RUN>/seed-<N>.txt \
  build-ulx5m-gs/top_ulx5m_gs_flash_read-serv-v13.bit
```

Run from WSL at repository root; this invokes the **Windows executable**:

```bash
./bin/openFPGALoader.exe -c tigard --freq 100k -m \
  bootloader-serv/build-ulx5m-gs/top_ulx5m_gs_flash_read-serv-v13.bit
```

Use `-m` for volatile FPGA SRAM only; **never `-f`** for these tests.

## Hardware diagnostics (native Windows PowerShell)

WSL has no native access to the ULX5M USB device in this setup. Leave
WinUSB installed. With v13 loaded via Tigard, run on **Windows**:

```powershell
cd C:\workspace\Hazard3-Doom
py .\bootloader-serv\tests\diagnose-ulx5m-serv-ep0.py --stats-only
py .\bootloader-serv\tests\diagnose-ulx5m-serv-ep0.py --rounds 256 --delay-ms 100
```

The script loads `bin\libusb-1.0.dll`, locates `1D50:614B`, reads an
initial diagnostic snapshot, and sends GET_DESCRIPTOR lengths 18/8/16.
On the *first* error it immediately requests the snapshot; later successful
requests could overwrite the previous state. Save **all** printed output.

The host error `[Errno 32] Pipe error` is not by itself proof that an
endpoint STALL was transmitted. The counters and BD words can help
identify whether firmware detected an error or was still waiting for
completion. If diagnostic retrieval also fails, report that as-is.

### 60-byte little-endian response layout

| Word | Meaning |
|------|---------|
| 0 | `0x31445045` = `EPD1` |
| 1 | byte 0: version (1), byte 1: previous EP0 state, byte 2: previous `bRequest`, byte 3: bus reset count (modulo 256) |
| 2 | SETUP descriptors processed (including diagnostic requests) |
| 3 | IN data/status descriptors acknowledged DONE_OK |
| 4 | OUT status descriptors acknowledged DONE_OK |
| 5 | SETUP DONE_ERR seen |
| 6 | IN DONE_ERR first observed (not counted repeatedly while latched) |
| 7 | OUT DONE_ERR seen |
| 8 | Deliberate STALL replies |
| 9 | SETUP observed while EP0 was neither IDLE nor STALL |
| 10 | Unexpected IN DONE_OK |
| 11 | Unexpected OUT DONE_OK |
| 12 | OUT status stage with unexpected length |
| 13 | Raw IN buffer descriptor word before the diagnostic SETUP |
| 14 | Raw OUT buffer descriptor word before the diagnostic SETUP |

Previous EP0 state: `0=IDLE`, `1=DATA_IN`, `2=DATA_OUT`,
`3=STATUS_DONE_OUT`, `4=STATUS_DONE_IN`, `5=STALL`.
The snapshot observes the state just **before processing the diagnostic
request**, and the counters naturally include that request. If a diagnostic
retry is needed, the pre-SETUP snapshot is no longer guaranteed to be from
the original failed descriptor request.

This is instrumentation, **not an EP0 fix**. It does not alter buffer
rearming, toggle handling or retry behavior. Keep the working v11 bitstream
as a rollback until v13 is validated.
