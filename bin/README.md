# Hazard3-Doom bin

This directory contains precompiled Windows binaries, FPGA images, package inventory and checksum metadata, and supporting utilities for loading and debugging Hazard3-Doom.

The files are intended to support the Windows quick-start workflow without requiring WSL. Not every file is needed for every operation.

The monitor ELF is intentionally not duplicated in `bin/`. Load the board-specific monitor produced by the matching complete build under `build/<board>/monitor/`. This keeps the monitor clock, memory map, linker placement, and loader protocol aligned with the FPGA image.

## Directory contents

| File or directory | Purpose |
|---|---|
| `gdb/` | Bundled RISC-V GDB executable and its runtime files. GDB connects to OpenOCD and loads a board-specific monitor ELF from the corresponding `build/<board>/monitor/` directory. |
| `riscv-gcc/` | Optional local xPack RISC-V GCC toolchain installed by `scripts/setup-xpack-riscv-gcc.cmd`. This directory is ignored by Git and is not redistributed as part of Hazard3-Doom. |
| `dfu-prefix.exe` | DFU image utility for adding, checking, or removing a device-specific prefix from a DFU file. Distributed with dfu-util. |
| `dfu-suffix.exe` | DFU image utility for adding, checking, or removing the standard USB DFU suffix from a DFU file. Distributed with dfu-util. |
| `dfu-util-static.exe` | Statically linked Windows build of `dfu-util`. It provides the same USB Device Firmware Upgrade command-line functions with fewer external runtime dependencies. |
| `dfu-util.exe` | USB Device Firmware Upgrade command-line utility for downloading firmware to, and where supported uploading firmware from, devices that implement USB DFU. Source: https://dfu-util.sourceforge.net |
| `fpga_ulx3s_85f_hdmi_doom.bit` | Prebuilt ULX3S-85F FPGA bitstream containing the Hazard3 SoC and HDMI Doom hardware design. Load this file with `fujprog-v48-win64.exe` or `openFPGALoader.exe`. |
| `fpga_ulx3s_12f_hdmi_doom.bit` | Prebuilt ULX3S-12F FPGA bitstream containing the Hazard3 SoC and HDMI Doom hardware design. Load this file with `fujprog-v48-win64.exe` or `openFPGALoader.exe`. |
| `fpga_ulx4m_ld_hdmi_doom.bit` | Prebuilt ULX4M-LD FPGA bitstream for ULX4M-LD hardware. |
| `fpga_ulx5m_gs_bringup.bit` | ULX5M-GS V005 GateMate SRAM-only hardware test for JTAG configuration, PLL lock, and LED heartbeat. No CPU, USB DFU, or flash programming. |
| `fpga_ulx5m_gs_flash_data.bit` | ULX5M flash read verification, recovery procedure, and validated 4 MiB backups |
| `fpga_ulx5m_gs_flash_jedec.bit` | ULX5M-GS V005 SRAM-only, 25 MHz read-only SPI JEDEC-ID diagnostic. Displays the three flash ID bytes on D0-D7; no USB, DFU, flash erase, or programming. |
| `fpga_ulx5m_gs_usb_probe.bit` | ULX5M-GS V005 SRAM-only PicoRV32 USB enumeration probe. Uses development VID:PID `1d50:614b`; USB DFU downloads/uploads and flash access are disabled. Not a persistent bootloader or Doom image. |
| `fujprog-v48-win64.exe` | Windows FPGA programming utility commonly used with ULX3S boards. Source: https://github.com/kost/fujprog |
| `hazard3-doom-ulx3s-12F.h3img` | Prebuilt Hazard3-Doom application image in the project-specific H3IMG format for ULX3S-12F. |
| `hazard3-doom-ulx4m-ld.h3img` | Prebuilt Hazard3-Doom application image in the project-specific H3IMG format for ULX4M-LD-85F. |
| `hazard3-doom-ulx3s-85F.h3img` | Prebuilt Hazard3-Doom application image in the project-specific H3IMG format for ULX3S-85F. |
| `INVENTORY.md` | Human-readable package inventory describing the files included in this `bin` directory. |
| `INVENTORY.sha256` | SHA-256 checksum manifest used to verify the integrity of packaged files. |
| `INVENTORY.tsv` | Tab-separated package inventory intended for scripts, tooling, and other machine-readable processing. |
| `libftdi1.dll` | Runtime library used by tools that communicate with FTDI USB devices. Keep it beside the executable that requires it. |
| `libusb-1.0.dll` | Runtime library used for USB communication. Keep it beside the executable that requires it. |
| `openFPGALoader` | Linux x86-64 ELF executable, modified v1.2.0-ulx5m-rxfix.1; dynamically linked. Source: [fork commit c1c588e](https://github.com/gojimmypi/openFPGALoader/commit/c1c588ee29b8a03dceacf395f4dd361f0216e586). Linux build and dependencies checked under WSL; native Linux hardware operation not yet tested. |
| `openFPGALoader.exe` | Windows executable, modified v1.2.0-ulx5m-rxfix.1. Source: [fork commit c1c588e](https://github.com/gojimmypi/openFPGALoader/commit/c1c588ee29b8a03dceacf395f4dd361f0216e586). GateMate/Tigard JTAG-SPI flash read verified; modified flash writes not qualified. |
| `openFPGALoader-v1.1.1.exe` | v1.1.1 compiled from [tag/v1.1.1](https://github.com/trabucayre/openFPGALoader/releases/tag/v1.1.1)  Source: https://github.com/trabucayre/openFPGALoader |
| `openFPGALoader-v1.2.0.exe` | v1.2.0 compiled from [tag/v1.2.0](https://github.com/trabucayre/openFPGALoader/releases/tag/v1.2.0)  Source: https://github.com/trabucayre/openFPGALoader |
| `openocd.exe` | OpenOCD JTAG debug server. It provides the connection between the FPGA JTAG interface and RISC-V GDB. |
| `putty.exe` | Windows serial-terminal utility for viewing the Hazard3 console and interacting with the running firmware. |
| `README.md` | This file. |
| `usbview` | USB device viewer utility. See https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/usbview |
| `zadig-2.5.exe` | USB driver installation utility. It can install a libusb-compatible Windows driver when required by an FPGA programming or JTAG tool. Changing a device driver can affect other software that uses the same device. |

## Typical roles

- FPGA configuration: use the prebuilt `.bit` file appropriate for the target board.
- USB DFU operations and DFU image preparation: `dfu-util.exe`, `dfu-util-static.exe`, `dfu-prefix.exe`, and `dfu-suffix.exe`.
- Firmware loading and debugging: `openocd.exe`, `gdb/`, and the board-specific monitor ELF produced under `build/<board>/monitor/`.
- Firmware inspection: inspect the board-specific monitor `.elf` and `.map` files in the corresponding build directory.
- Doom application image: use the board-specific `.h3img` file.
- Serial console: `putty.exe`.
- Package inventory and integrity verification: `INVENTORY.md`, `INVENTORY.tsv`, and `INVENTORY.sha256`.
- USB driver setup, only when needed: `zadig-2.5.exe`.

## Examples

Program ULX3S FPGA bitstream from Windows, from repo root:

```DOS
.\bin\fujprog-v48-win64.exe .\bin\fpga_ulx3s_85f_hdmi_doom.bit
```

The Windows executable can also be called from a WSL Bash prompt:

```bash
./bin/fujprog-v48-win64.exe ./bin/fpga_ulx3s_85f_hdmi_doom.bit
```

Program the ULX5M-GS V005 diagnostics into volatile FPGA SRAM using Tigard JTAG (Windows, from repo root):

```DOS
.\bin\openFPGALoader.exe -c tigard --freq 100k -m .\bin\fpga_ulx5m_gs_bringup.bit
.\bin\openFPGALoader.exe -c tigard --freq 100k -m .\bin\fpga_ulx5m_gs_usb_probe.bit
.\bin\openFPGALoader.exe -c tigard --freq 100k -m .\bin\fpga_ulx5m_gs_flash_jedec.bit
```

Use the Tigard JTAG 1.8 V setting with the ULX5M powered externally. If JTAG programming completes but the design does not start, power off both devices; power on Tigard first, then ULX5M, and retry. These `.bit` files configure volatile SRAM only; power cycling removes them. The USB probe reports `ULX5M-GS FPGA (DFU Probe)` via its USB product string; Windows may still show the cached driver description `ULX4M-LS FPGA (DFU)` for the shared development VID:PID. It does not accept DFU transfers or program configuration flash.

The JEDEC diagnostic was verified on ULX5M-GS V005 hardware: the LED readout is `1F 42 16`, identifying the fitted AT25QL321 (32 Mbit / 4 MiB). D0-D7 initially display `0x1f`; BTN1 cycles through `0x42`, `0x16`, then `0x1f`; holding BTN2 displays byte indexes `0x81`, `0x82`, or `0x84`. The downloaded bitstream has SHA-256 `27fe241b5bbe0879e59168297d3d97a6e1850355f8dd1cf116c737181c928556`. Its SPI command is read-only (`0x9f`); it does not implement flash-content reads or DFU.

Windows users can start OpenOCD using the VisualGDB script:

```DOS
.\VisualGDB\start-openocd.cmd
```

With OpenOCD already running, load the monitor from the matching complete board build. For example, ULX3S 85F:

```DOS
.\bin\gdb\riscv-none-elf-gdb.exe -batch -x .\scripts\gdb\load-ulx3s-85f-monitor.gdb
```

The corresponding helpers are:

```text
scripts/gdb/load-ulx3s-85f-monitor.gdb
scripts/gdb/load-ulx3s-12f-monitor.gdb
scripts/gdb/load-ulx4m-ld-85f-monitor.gdb
```

## Runtime notes

- Keep `libftdi1.dll` and `libusb-1.0.dll` in this directory unless a tool-specific subdirectory already contains the required copy.
- The Linux `openFPGALoader` binary requires compatible shared libraries, including libusb-1.0, libftdi1, libudev, zlib, and the C++ runtime. This WSL build was checked with `ldd` and `-V`; USB hardware access in WSL was not tested. Use the Windows `.exe` from WSL for the established Tigard workflow.
- `dfu-util-static.exe` is provided as an alternative to `dfu-util.exe` when a self-contained build is preferable.
- Do not install or replace a USB driver with Zadig unless the current driver is incompatible with the selected programming or debugging tool.
- Close other FPGA programming, serial-terminal, or JTAG applications before starting OpenOCD if they might already have the target USB interface open.
- Monitor `.elf` and `.map` files are build outputs and should come from the board-specific build directory rather than `bin/`.

## Third-party software

The utilities in this directory remain subject to their respective upstream licenses. Consult each upstream project for source code, license terms, and updated releases.

See [LICENSES](../LICENSES)
