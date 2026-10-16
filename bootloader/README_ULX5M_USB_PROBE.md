# ULX5M-GS V005 USB enumeration probe

This is a first PicoRV32/USB SoC integration test for GateMate A1. It is
not a functional flash bootloader. It is intended for volatile FPGA
configuration through JTAG, followed by Windows USB enumeration testing.

## Build

From `bootloader/`, with OSS CAD Suite and a RISC-V bare-metal GCC on PATH:

    python3 tests/check-ulx5m-gs-port.py
    python3 tests/check-ulx5m-gs-usb.py
    python3 tests/check-ulx5m-gs-probe.py
    make -f Makefile.ulx5m-gs usb-probe

The firmware Makefile searches PATH for common RISC-V GCC prefixes, then
checks standard local xPack installations under `~/.local/xPacks` and
`bin/riscv-gcc` at the repository root. If none is found, it reports a
missing compiler before attempting the build. To select another installation,
set `CROSS` on the outer make command line, including the full path prefix:

    make -f Makefile.ulx5m-gs usb-probe CROSS=/path/to/bin/riscv-none-elf-

To find an existing local compiler from WSL:

    find "$HOME/.local/xPacks" ../bin/riscv-gcc -type f -name 'riscv*-gcc' 2>/dev/null

The build compiles `fw/fw_ulx5m_probe.c`, creates a 32-bit little-endian
BRAM hex file, and then synthesizes the Verilog.

Expected outputs:

    build-ulx5m-gs/fw_ulx5m_probe.elf
    build-ulx5m-gs/fw_ulx5m_probe.hex
    build-ulx5m-gs/top_ulx5m_gs_usb_probe.bit

## Hardware behavior

- 25 MHz external clock, GateMate PLL nominal 48 MHz (previous routing
  reported 47.9167 MHz).
- USB D+ / D- on `IO_EA_A1` / `IO_EA_B1` (EA bank at 3.3 V).
- `USB_PULL_P` on `IO_EA_A2`: drives high only when USB connects; otherwise
  high impedance. `USB_PULL_N` remains unused/high impedance.
- Duplicate USB pads `IO_EA_A0` / `IO_EA_B0` remain unused.
- D7 is a clock heartbeat; D6 indicates PLL lock; lower LEDs may be
  changed by firmware. The default startup code writes to the LED register.
- V005 USB attach circuit: steering diodes D5-D8 and 1 kOhm / 12.1 kOhm
  resistors R46/R47/R48/R55. Fixed R58 pullup is DNP.

The FPGA has no SPI flash connections in this build. The memory-mapped SPI
slot returns zero and acknowledges accesses; it is not a flash controller.
The firmware does not link `spi.c`, `usb_dfu.c`, or the original DFU main.
DFU GETSTATE and GETSTATUS return idle; DFU UPLOAD, DNLOAD, and DETACH
are rejected. The USB descriptors advertise a single diagnostic DFU
alternate setting with neither upload nor download capability.

This probe inherits USB VID:PID `1d50:614b` from the ULX3S bootloader
only for local development. Do not ship this identity as an ULX5M product.

## What to verify on hardware

1. Program the bitstream into FPGA volatile configuration with a verified
   GateMate-compatible JTAG setup and the correct Tigard voltage reference.
2. Connect the ULX5M USB-C directly to Windows. Check Device Manager and
   `Get-PnpDevice` for a new USB device. No other carrier is needed.
3. Use native Windows `dfu-util -l` if the device enumerates. It should
   show only a non-programmable diagnostic alternate setting.
4. Do not use any DFU upload/download commands with this target. Its
   purpose is enumeration and class-request handling only.

The built bitstream is *not yet verified* on physical hardware. Additional
GateMate synthesis/route issues may arise in the complete SoC even though
the earlier RX-only monitor built. The external flash geometry, GateMate
boot/multiboot method, DFU write regions, and bootloader recovery procedure
must all be validated before building or installing real flash firmware.

## Source changes

- New `rtl/top-ulx5m-gs-usb-probe.v` and `rtl/soc_ulx5m_misc.v` provide
  the PicoRV32, BRAM, USB, UART and no-flash bus integration.
- New `fw/Makefile.ulx5m-gs`, `fw/fw_ulx5m_probe.c`, and
  `fw/usb_desc_ulx5m_probe.c` provide an enumeration-only firmware image.
- `fw/usb_ctrl_std.c` fixes GET_STATUS_INTERFACE/GET_INTERFACE selection
  only when `BOARD_ULX5M_GS` is defined. Older board builds retain their
  previous behavior.
- `Makefile.ulx5m-gs` adds the `usb-probe` target without changing
  `usb-monitor`, `bringup`, `flash` or `dfu` semantics.

## Stage 5: CPU timing experiment (RV32I)

The Stage 4 complete SoC routed but failed the 48 MHz clock requirement:
post-route Fmax was 24.44 MHz. The reported critical path starts at
firmware BRAM and ends at the PicoRV32 register-file read address. It
passes through the compressed-instruction decoder.

The ULX5M USB enumeration probe now uses the uncompressed RV32I ISA
(`COMPRESSED_ISA=0` and `-march=rv32i`), removing that decoder from the
critical path. The firmware Makefile itself is now an ELF prerequisite
so ISA changes cause a firmware rebuild. The original ECP5 bootloader
firmware and PicoRV32 settings are unchanged.

This is a timing experiment, not a proven timing fix. USB and CPU remain
on the same nominal 48 MHz clock; no clock-domain crossing was added.
Check the post-route Fmax and timing report after rebuilding. Do not
load the resulting bitstream into hardware unless timing passes.
