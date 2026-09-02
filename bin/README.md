# Hazard3-Doom bin

This directory contains precompiled Windows binaries, FPGA images, firmware files, package inventory and checksum metadata, and supporting utilities for loading and debugging Hazard3-Doom.

The files are intended to support the Windows quick-start workflow without requiring WSL. Not every file is needed for every operation.

## Directory contents

| File or directory | Purpose |
|---|---|
| `gdb/` | Bundled RISC-V GDB executable and its runtime files. GDB connects to OpenOCD, loads `hazard3-test.elf`, and provides source-level or command-line debugging. |
| `riscv-gcc/` | Bundled RISC-V GCC toolchain support files used by the precompiled Hazard3 firmware and debugging workflow. Installed by `setup-xpack-riscv-gcc.cmd` in the /scripts/ directory. |
| `dfu-prefix.exe` | DFU image utility for adding, checking, or removing a device-specific prefix from a DFU file. Distributed with dfu-util. |
| `dfu-suffix.exe` | DFU image utility for adding, checking, or removing the standard USB DFU suffix from a DFU file. Distributed with dfu-util. |
| `dfu-util-static.exe` | Statically linked Windows build of `dfu-util`. It provides the same USB Device Firmware Upgrade command-line functions with fewer external runtime dependencies. |
| `dfu-util.exe` | USB Device Firmware Upgrade command-line utility for downloading firmware to, and where supported uploading firmware from, devices that implement USB DFU. Source: https://dfu-util.sourceforge.net |
| `fpga_ulx3s_hdmi_doom.bit` | Prebuilt ULX3S FPGA bitstream containing the Hazard3 SoC and HDMI Doom hardware design. Load this file with `fujprog-v48-win64.exe` or `openFPGALoader.exe`. |
| `fpga_ulx4m_ld_hdmi_doom.bit` | Prebuilt ULX4M-LD FPGA bitstream from the seed-2 routing build. This image is for ULX4M-LD hardware. |
| `fujprog-v48-win64.exe` | Windows FPGA programming utility commonly used with ULX3S boards. Source: https://github.com/kost/fujprog |
| `hazard3-doom.h3d` | Prebuilt Hazard3-Doom application image in the project-specific H3D format. |
| `hazard3-test.elf` | Hazard3 monitor and firmware ELF image. GDB uses this file for symbols, loading, and debugging. |
| `hazard3-test.map` | Linker map generated with `hazard3-test.elf`. It lists linked sections, symbols, and addresses and is useful when diagnosing memory-layout or size problems. |
| `INVENTORY.md` | Human-readable package inventory describing the files included in this `bin` directory. |
| `INVENTORY.sha256` | SHA-256 checksum manifest used to verify the integrity of packaged files. |
| `INVENTORY.tsv` | Tab-separated package inventory intended for scripts, tooling, and other machine-readable processing. |
| `libftdi1.dll` | Runtime library used by tools that communicate with FTDI USB devices. Keep it beside the executable that requires it. |
| `libusb-1.0.dll` | Runtime library used for USB communication. Keep it beside the executable that requires it. |
| `openFPGALoader.exe` | Cross-platform FPGA programming utility, provided here as a Windows executable. Source: https://github.com/trabucayre/openFPGALoader |
| `openocd.exe` | OpenOCD JTAG debug server. It provides the connection between the ULX3S JTAG interface and RISC-V GDB. |
| `putty.exe` | Windows serial-terminal utility for viewing the Hazard3 console and interacting with the running firmware. |
| `README.md` | This file. |
| `zadig-2.5.exe` | USB driver installation utility. It can install a libusb-compatible Windows driver when required by an FPGA programming or JTAG tool. Changing a device driver can affect other software that uses the same device. |

## Typical roles

- FPGA configuration: `fpga_ulx3s_hdmi_doom.bit` for ULX3S, or `fpga_ulx4m_ld_hdmi_doom.bit` for ULX4M-LD. Use the programmer appropriate for the target board.
- USB DFU operations and DFU image preparation: `dfu-util.exe`, `dfu-util-static.exe`, `dfu-prefix.exe`, and `dfu-suffix.exe`.
- Firmware loading and debugging: `openocd.exe`, `gdb/`, and `hazard3-test.elf`.
- Firmware inspection: `hazard3-test.map`.
- Doom application image: `hazard3-doom.h3d`.
- Serial console: `putty.exe`.
- Package inventory and integrity verification: `INVENTORY.md`, `INVENTORY.tsv`, and `INVENTORY.sha256`.
- USB driver setup, only when needed: `zadig-2.5.exe`.

## Examples

Program ULX3S FPGA bitstream from Windows, from repo root:

```DOS
.\bin\fujprog-v48-win64.exe .\bin\fpga_ulx3s_hdmi_doom.bit
```

The Windows executable can also be called from WSL bash prompt:

```bash
./bin/fujprog-v48-win64.exe ./bin/fpga_ulx3s_hdmi_doom.bit
```

Windows users can start OpenOCD using the VisualGDB script:

```DOS
.\VisualGDB\start-openocd.cmd
```

Load the Hazard3 firmware and start a GDB debugging session (required OpenOCD to be already running):

```DOS
./bin/load_firmware.bat
```

## Runtime notes

- Keep `libftdi1.dll` and `libusb-1.0.dll` in this directory unless a tool-specific subdirectory already contains the required copy.
- `dfu-util-static.exe` is provided as an alternative to `dfu-util.exe` when a self-contained build is preferable.
- Do not install or replace a USB driver with Zadig unless the current driver is incompatible with the selected programming or debugging tool.
- Close other FPGA programming, serial-terminal, or JTAG applications before starting OpenOCD if they might already have the ULX3S USB interface open.
- The `.bit`, `.h3d`, `.elf`, and `.map` files are project outputs, not Windows applications.

## Third-party software

The utilities in this directory remain subject to their respective upstream licenses. Consult each upstream project for source code, license terms, and updated releases.

See [LICENSES](../LICENSES)
