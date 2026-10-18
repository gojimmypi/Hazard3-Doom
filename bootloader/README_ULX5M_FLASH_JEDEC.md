# ULX5M-GS V005: 25 MHz read-only flash JEDEC diagnostic

This diagnostic tests the configuration-flash electrical interface independently
of PicoRV32 and USB timing closure. It is SRAM-loaded through JTAG and performs
exactly one standard single-bit SPI Read JEDEC ID command (`0x9f`), clocking
24 response bits. It does not send erase, write-enable, or program commands.

## Build

From `bootloader/`:

```bash
python3 tests/check-ulx5m-gs-flash-jedec.py
make -f Makefile.ulx5m-gs test-flash-jedec
make -f Makefile.ulx5m-gs flash-jedec
```

Inspect the **final post-route** Fmax in
`build-ulx5m-gs/flash-jedec-pnr.log`. It must pass 25 MHz. The bitstream is
`build-ulx5m-gs/top_ulx5m_gs_flash_jedec.bit`.

## JTAG test

Use the previously validated ULX5M/Tigard cold-start sequence: power off both;
power the ULX5M by USB; power Tigard by USB; program via 1.8 V JTAG. Do not
hold buttons during power-up. From the repository root:

```bash
./bin/openFPGALoader.exe -c tigard --freq 100k \
    ./bootloader/build-ulx5m-gs/top_ulx5m_gs_flash_jedec.bit
```

- The FPGA waits about 2.6 ms before issuing the SPI command at 6.25 MHz.
- All eight user LEDs show the first JEDEC byte (manufacturer) as binary,
  D0 = bit 0, D7 = bit 7.
- Press and release BTN1 once to display the second byte (device type).
  Press again for the third byte (capacity). Press again for the first byte.
- Hold BTN2 to show which byte is selected: `0x81`, `0x82`, or `0x84`.
  Release BTN2 to restore the data byte.
- During startup, LEDs display `0x55` (waiting) or `0xaa` (reading).
  Once complete, the display holds its value; there is no heartbeat.

The RTL compensates for the observed D4/D5 and D6/D7 permutations in the V005
LED wiring. If all data bytes are `0xff`, `0x00`, or inconsistent, do not infer
a flash part ID; investigate pin ownership and SPI timing first. Record all
three bytes before considering the flash identified.

## Hardware validation (2026-10-18)

ULX5M-GS V005, Tigard at 1.8 V, JTAG SRAM configuration:

- Static pin and read-only guards: PASS.
- Icarus simulation: PASS (32 SPI clocks, 3 JEDEC bytes, byte selection).
- GateMate final post-route Fmax: 84.21 MHz (PASS at 25.00 MHz).
- Manufacturer (startup): D0-D4 on = `0x1f`.
- BTN1 once: D1 and D6 on = `0x42`.
- BTN1 twice: D1, D2, and D4 on = `0x16`.
- Hold BTN2 on third byte: D2 and D7 on = `0x84` (byte index).

The ID `1f 42 16` matches the populated AT25QL321-MBUE-T (32 Mbit / 4 MiB).
This verifies the post-configuration SPI pins and read-ID command, not SPI
flash-content reads, USB DFU, or nonvolatile boot.

The tested `.bit` is also distributed as `bin/fpga_ulx5m_gs_flash_jedec.bit`:

```text
SHA256: 27fe241b5bbe0879e59168297d3d97a6e1850355f8dd1cf116c737181c928556
```

This test uses 1.8 V `IO_WA_*` pins for flash IO0-IO3, CS and SCK after JTAG
configuration. Verify operation on the actual board. Neither this diagnostic
nor the existing `flash-read-probe` can write configuration flash.

The integrated 48 MHz PicoRV32/USB flash-read probe remains a separate target.
Its current timing failure is in PicoRV32 next-PC logic, not the BRAM pipeline.
