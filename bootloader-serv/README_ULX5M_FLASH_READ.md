# ULX5M-GS V005 configuration flash: read-only bring-up

Status: source-level diagnostic, NOT hardware validated. No flash writes.

The V005 schematic identifies U9 as AT25QL321-MBUE-T (32 Mbit, 4 MiB),
supplied from +1V8_FLASH. This replaces the unverified 16 MiB assumption
in the ULX4M firmware; do not reuse its flash layout or protection offsets.

The GateMate configuration SPI pads have GPIO alternate functions:

| Flash signal | GateMate GPIO | Ball |
|---|---|---|
| CS_N | IO_WA_A8 | N3 |
| SCK | IO_WA_B8 | N4 |
| IO0 / MOSI | IO_WA_B7 | P2 |
| IO1 / MISO | IO_WA_A7 | P1 |
| IO2 / WP_N | IO_WA_B6 | R2 |
| IO3 / HOLD_N | IO_WA_A6 | R1 |

The new target uses 1.8 V tri-state IO pads, leaves IO2/IO3 undriven,
and sends only command 0x9F (JEDEC ID) and command 0x03 (slow read).
No erase, program, status-write, write-enable, or power-down opcodes
are issued by its firmware. DFU upload and download remain rejected.

## Build

From `bootloader/` with OSS CAD Suite and the RISC-V compiler available:

```sh
python3 tests/check-ulx5m-gs-flash-read.py
make -f Makefile.ulx5m-gs test-flash-bram-pipe
make -f Makefile.ulx5m-gs flash-read-probe
```

Build output (volatile JTAG image only):

```
build-ulx5m-gs/top_ulx5m_gs_flash_read.bit
```

This target is independent of the verified `usb-probe` bitstream. The
flash-read top enables `soc_bridge.BRAM_REG=1` to register BRAM addresses,
write data, and write enables and delay BRAM acknowledgment until synchronous
read data is valid. Other board builds and the USB enumeration probe use the
unchanged default (`BRAM_REG=0`). The simulation target exercises RV32I word,
byte and halfword stores, loads, and one-shot acknowledgments.

Check post-route timing and any configuration-I/O warnings before programming.
**Do not program the bitstream unless the final routed result passes 48 MHz.**
The use of configuration SPI pads in user mode has NOT yet been verified
on ULX5M-GS; stop if any pad is rejected or cannot be released as GPIO.

## Hardware trial

Keep SW1 in JTAG mode. The working cold-start procedure is: remove USB
power from both ULX5M and Tigard; power the ULX5M first, then Tigard;
program through Tigard. BTN2 is not required.

From the repository root, SRAM load only (no `-f`):

```sh
./bin/openFPGALoader.exe -c tigard --freq 100k \
  ./bootloader/build-ulx5m-gs/top_ulx5m_gs_flash_read.bit
```

The FPGA loses this image when USB power is removed. Do not change the
SW1 configuration mode or write the configuration flash during this test.

## Read JEDEC ID and existing flash bytes

Run in native Windows Python (assuming the USB device already has a
libusb-compatible driver), from the repository root:

```powershell
py -m pip install pyusb
py .\bootloader\tests\read-ulx5m-flash.py --offset 0 --length 32
```

The script uses only USB vendor-control IN requests:

| bmRequestType | bRequest | Action | Response |
|---|---|---|---|
| 0xC0 | 0x51 | JEDEC RDID (0x9F) | 3 bytes |
| 0xC0 | 0x52 | SPI READ (0x03) | 1-32 bytes |

For request 0x52, `wValue` contains the low 16 address bits, and
`wIndex` the high 16 bits. Valid range: 0 through 0x3FFFFF.
Use `--output file.bin` to save a read-only sample.

Results are unverified until the host returns a plausible JEDEC ID and
repeatable flash data. Repeated 00/FF ID, USB stall, lost enumeration, or
failed timing means stop; do not enable flash writes.

Note: the USB VID:PID is still the development-only 1D50:614B. Do not
ship this device identity as an ULX5M product or alter Windows drivers
solely for this diagnostic.
