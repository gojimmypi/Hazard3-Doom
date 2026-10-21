# ULX5M-GS DFU bootloader port (stage 2)

Status: RAM-only LED/PLL bring-up target prepared; not built with GateMate
CAD tools here and not tested on hardware. USB PHY RTL prepared but not yet
integrated into a runnable DFU bitstream. No flash programming permitted.

## Inputs

- User-provided ULX4M DFU bootloader in `bootloader/` and helper scripts.
- User-provided ULX5M-GS `fpga_ulx5m_gs.ccf`, `.sdc`, `ULX5M_GS.mk`.
- ULX5M-GS v005 schematic repository:
  https://github.com/intergalaktik/ulx5m-gs/tree/main/hardware
- GateMate primitive library UG1001, sections 2.4, 2.9, 7.3:
  https://www.colognechip.com/docs/ug1001-gatemate1-primitives-library-latest.pdf

## Stage 2 changes

- `rtl/sysmgr_gatemate.v`: GateMate 25->48 MHz `CC_PLL` and reset release.
  The 25 MHz pin is IO_SB_A8. The PLL uses the global clock buffer.
  `PERF_MD` is intentionally not forced to `SPEED`: PCB core voltage
  defaults to 0.9 V and the selected P&R mode must match the rail.
- `cores/usb/rtl/usb_phy.v`: new `TARGET="GATEMATE"` branch, using
  registered bidirectional `CC_IOBUF` and input `CC_IDDR` for full-speed
  USB receive sampling. Original ICE40/ECP5 branches remain present.
  GateMate timing/electrical behavior is not yet hardware validated.
- `rtl/top-ulx5m-gs-bringup.v`: minimal PLL lock, heartbeat, BTN1 LED test.
- `data/top-ulx5m-gs-bringup.ccf/.sdc`: only validated clock/BTN1/LED pins.
- `Makefile.ulx5m-gs`: isolated GateMate build with no flash/DFU actions.
- `tests/check-ulx5m-gs-port.py`: static checks for constraints and safety.

## Build instructions (WSL, OSS CAD Suite in PATH)

    cd bootloader
    python3 tests/check-ulx5m-gs-port.py
    make -f Makefile.ulx5m-gs bringup

Expected output:

    bootloader/build-ulx5m-gs/top_ulx5m_gs_bringup.bit

Build uses `synth_gatemate`, `nextpnr-himbaechel`, and `gmpack`.
The bitstream is for **volatile FPGA/JTAG loading only**. There is no
`flash` or `dfu` target; both explicitly fail. Do not use `-f` when
programming with `openFPGALoader` until configuration flash is verified.

When loaded, D7 blinks at about 1.43 Hz, D6 indicates PLL lock (on if
locked), D0 follows BTN1 (on while pressed). LEDs are active low.

## Remaining DFU port blockers

1. USB D+/D- FPGA pin locations and USB pullup/attach control must be
   extracted and reviewed from the V005 KiCad schematic and PCB. The
   supplied LiteX/Hazard3 platform files do not contain these pins.
2. Check whether USB lines include external level translation appropriate
   for 1.8 V GPIO banks, and whether the D+ attach pullup is controllable.
3. Build a ULX5M-specific DFU SoC top (PicoRV32, Wishbone, USB, QSPI)
   and replace ECP5-specific button and LED peripherals.
4. Disable or replace the original firmware's PSRAM startup accesses,
   ECP5 flash-sector write protection, and ECP5 `reboot_now()` behavior.
   It currently hard-codes 16 MiB flash and 0x200000 user bitstream start.
5. Verify actual configuration SPI flash part, capacity, clock and
   erase geometry, and the GateMate configuration image layout. The
   Stage 1 QSPI pad PHY is not a confirmed working flash interface.
6. Embed firmware into inferred GateMate BRAM during synthesis, not with
   post-route `ecpbram` substitution.
7. Validate signal timing and host enumeration with RAM-only JTAG load
   BEFORE exposing any USB DFU flash write command or programming flash.

## Validation performed here

- Stage 2 static source/constraint/safety test passed.
- Makefile build command dry-run checked.
- **Not run**: Yosys, nextpnr, gmpack, Verilog simulation, hardware load.
  None of the relevant CAD executables are available in this environment.
- No ULX5M USB D+/D- assignments have been guessed.

## Stage 3: V005 KiCad PCB verification and USB pad monitor

Source: user-provided `hardware.zip` containing KiCad v005 PCB and schematics.
The original hardware source is NOT included in this changes-only ZIP.

The PCB shows GateMate U4 `USB25_P` on IO_EA_A0 and IO_EA_A1,
`USB25_N` on IO_EA_B0 and IO_EA_B1, `USB_PULL_P` on IO_EA_A2,
`USB_PULL_N` on IO_EA_B2. EA I/O bank supply is +3V3, unlike the
SB bank's 1.8 V rail. The D+/D- signals pass through fitted R142/R141
(0 ohm) and R45/R44 (27 ohm) to USB-C J5. They also connect to the
CM module HSIO USB_P/N pins, so use the ULX5M standalone for testing.

Fixed 3.3V D+ pullup R58 (1 kohm) is marked `exclude_from_bom dnp`.
The discrete attach circuit consists of USB_PULL_P/N, D5-D8 (1N914),
and resistors R46-R48/R55. This circuit is NOT enabled in the monitor.
It will need an explicit, verified GateMate output-stage implementation
before running any real USB device/DFU image.

The board uses Y1 `ASE2-25.000MHZ-L-C-T` at the FPGA clock input.
This confirms 25 MHz for the official V005 schematic/PCB. The
firmware's 48 MHz USB clock still depends on successful PLL routing.

Added `usb-monitor` target with top `top_ulx5m_gs_usb_monitor`:

    cd bootloader
    python3 tests/check-ulx5m-gs-usb.py
    # If the official v005 PCB file is available locally:
    python3 tests/check-ulx5m-gs-usb.py --pcb ../hardware/ulx5m-gs.kicad_pcb
    make -f Makefile.ulx5m-gs usb-monitor

Expected bitstream:

    build-ulx5m-gs/top_ulx5m_gs_usb_monitor.bit

This is strictly an RX-only pad test. It never enables TX, the USB
pullup, flash or reconfiguration. LED D0 reads the filtered D+ state;
D1 reads D-; D2 shows D+/D- transitions; D3 responds to BTN1;
D6 shows PLL lock; D7 blinks. Since no pullup is asserted, USB
enumeration is NOT expected. The spare USB pads A0/B0 are unused.

Stage 3 verification: source/CCF/PCB static tests and Makefile dry run.
GateMate Yosys/nextpnr/gmpack are not available in this execution
container. No synthesis, bitstream or hardware programming was run.

Remaining: verify USB monitor synthesis and voltage settings on
GateMate, validate the attach diode circuit, then implement the
PicoRV32/GateMate full DFU top with flash writes disabled and firmware
adapted for the board. Do not program configuration flash yet.

## Stage 4: consolidated build-dependency repair

Stage 3 was incremental. It lacked `rtl/sysmgr_gatemate.v`, introduced
by Stage 2, so running `make -f Makefile.ulx5m-gs usb-monitor` on Stage 3
alone failed before starting synthesis. The Stage 4 archive consolidates
all the files from Stages 1-3 into a single additive overlay.

The USB monitor static test now rejects missing local source or bring-up
constraint files referenced by the Makefile. It does not require the
Intergalaktik clone and does not change the USB PHY or hardware behavior.

Apply from the Hazard3-Doom repository root, preserving paths:

    unzip -o ulx5m-bootloader-port-consolidated-20261016-v4.zip
    cd bootloader
    python3 tests/check-ulx5m-gs-port.py
    python3 tests/check-ulx5m-gs-usb.py
    make -f Makefile.ulx5m-gs usb-monitor

The package was checked by the two static tests and Makefile dry runs.
Synthesis, place-and-route, hardware load and DFU enumeration remain
unverified; these designs do not implement a flash-capable bootloader.
