# ULX5M-GS V005: 25 MHz SPI flash content reader

This is the second read-only configuration-flash diagnostic. It uses the
hardware-verified JEDEC reader's clock and pin assignments, without a CPU,
PLL, or USB controller. It is loaded into FPGA SRAM through JTAG. No flash
program, erase, or write-enable commands exist in this design.

The new design sends `03 00 00 00` (single-bit SPI READ, address 0x000000)
and captures exactly 32 bytes (`0x000000` through `0x00001f`) at 6.25 MHz SCK.
The SPI transaction runs once after startup. It does not change flash contents.

## Build and test

From `bootloader/`:

```bash
make -f Makefile.ulx5m-gs test-flash-jedec
make -f Makefile.ulx5m-gs test-flash-data
make -f Makefile.ulx5m-gs flash-data
```

Check the **last** Fmax report in `build-ulx5m-gs/flash-data-pnr.log` for a
post-route PASS at 25 MHz. The output is
`build-ulx5m-gs/top_ulx5m_gs_flash_data.bit`.

## JTAG test

Power off the ULX5M and Tigard. Power Tigard by USB first, then power the
ULX5M by USB-C. Keep the JTAG interface at 1.8 V; leave buttons released.
If JTAG detection fails after an SRAM load, power-cycle both in this order.
From the repository root:

```bash
./bin/openFPGALoader.exe -c tigard --freq 100k \
    ./bootloader/build-ulx5m-gs/top_ulx5m_gs_flash_data.bit
```

The design reads 32 bytes after a roughly 2.6 ms startup wait. LEDs D0-D7
show the selected byte as binary (D0 = bit 0). The default offset is zero.

- Press and release BTN1: advance one byte (offset 0 through 31, wrapping).
- Hold BTN2: show `0x80 | offset` instead of flash data. Values range from
  `0x80` (offset 0) to `0x9f` (offset 31). Release to show the data again.
- Before completion, LED displays `0x55` (startup) or `0xaa` (reading).
  There is no heartbeat after completion.

The LED mapping includes the same D4/D5 and D6/D7 permutations already
validated by the JEDEC diagnostic. All displayed bytes, including `0x00` and
`0xff`, are data values; an erased flash region can legitimately read `0xff`.
If bytes appear invalid, re-run the verified `flash-jedec` diagnostic to
confirm the SPI electrical connection before changing any flash contents.

## Validation status

The 25 MHz JEDEC-ID image was verified on hardware on 2026-10-18:
ID `1f 42 16` (AT25QL321, 4 MiB), post-route Fmax 84.21 MHz.

The SPI `0x03` diagnostic passed its simulation and 25 MHz timing target
(post-route Fmax 61.36 MHz) and was verified on ULX5M-GS V005 hardware on
2026-10-18. The first eight bytes were observed twice through physical LEDs
and independently verified through Tigard JTAG flash dumping:

```text
Address: 00 01 02 03 04 05 06 07
Data:    D9 01 ED 96 10 4D D6 00
```

At offset 2, BTN2 displayed `0x82` (D1/D7), confirming the selected byte;
releasing BTN2 displayed `0xed`. A previous `0xeb` report was a mistaken LED
observation, not a confirmed SPI read error.

This establishes basic flash-content read access. It does not validate USB
DFU, flash writing, multiboot, or persistent bootloader operation.
