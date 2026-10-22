# ULX5M-GS SERV Bitstreams

This directory contains selected, hardware-tested FPGA bitstreams for the ULX5M-GS SERV-based USB bootloader development project.

These files are retained as reproducible diagnostic baselines. Experimental builds and routine synthesis outputs should not be committed.

## Historical USB Diagnostic Reference Bitstream

**File:** `ulx5m-gs-serv-v16g2f-seed5.bit`

| Property | Value |
|---|---|
| Target board | ULX5M-GS |
| FPGA architecture | Cologne Chip GateMate |
| Processor | SERV bit-serial RISC-V |
| Build revision | v16g2f |
| Place-and-route seed | 5 |
| USB target clock | 48 MHz |
| Post-route maximum frequency | 49.46 MHz |
| Timing result | PASS |
| Programming interface | Tigard JTAG |
| JTAG frequency | 1 MHz |
| Programming mode | FPGA SRAM (volatile) |
| Build date | October 2026 |
| Git commit | TODO: Record exact source commit |
| OSS CAD Suite version | TODO: Record exact version |
| SHA-256 | TODO: Record checksum |

### Purpose

This bitstream provides a SERV-based USB diagnostic implementation for ULX5M-GS hardware bring-up.

It is intended for investigating USB enumeration, endpoint 0 (EP0) control transfers, transaction acknowledgments, and potential hardware or signal-integrity differences between USB connections.

**This is not yet a complete USB firmware-update bootloader.**

### Verified Behavior

- FPGA configuration through Tigard JTAG succeeds.
- The design passes the 48 MHz timing requirement.
- USB enumeration and control transfers operate successfully through the tested right-side USB connection.
- The right-side USB configuration completed 2,304 of 2,304 descriptor requests in the reported test.
- The left-side USB configuration exhibits repeatable communication failures.
- Reversing the USB cable did not resolve the left-side failure.

These results apply to the tested hardware, USB connections, host environment, and bitstream revision. They do not establish USB compatibility across all hardware or host configurations.

### Current Capabilities

The design includes:

- SERV processor and firmware execution.
- USB device enumeration and standard control request handling.
- USB EP0 diagnostic instrumentation.
- USB transaction counters and diagnostic state reporting.
- Read-only SPI flash diagnostic support.

The following bootloader capabilities are not yet implemented or validated:

- USB firmware image upload.
- SPI flash erase and programming.
- Complete USB DFU protocol.
- Firmware image authentication or integrity validation for booting.
- Automatic boot or configuration handoff to a stored application image.
- Recovery from interrupted firmware updates.

Do not use this bitstream as a production firmware-update or recovery solution.

## Current Hardware-Tested One-Sector DFU Flash Experiment (October 22, 2026)

**File:** `top_ulx5m_gs_flash_read-serv-dfu-hw-test.bit`

This is a separately built, experimental SERV firmware image. It is NOT the
older v16g2f diagnostic reference and is NOT a production bootloader.

| Property | Value |
|---|---|
| Board and FPGA | ULX5M-GS, Cologne Chip GateMate GM1Ax |
| Build target | `dfu-hw-test-serv` |
| Routing seed used | 260 |
| Target clock | 48 MHz |
| Reported Fmax | 51.15 MHz (PASS) |
| Programming | Tigard JTAG, FPGA SRAM (`-m`), volatile only |
| Physical test address | `0x200000..0x200FFF` (one 4 KiB sector) |
| Confirmed transfer lengths | 64, 512 and 4096 bytes |
| Independent verification | JTAG data comparison followed by complete 4 MiB restore |
| Factory image | Restored byte-for-byte, verified against both original backups |
| SHA-256 of bitstream | TODO: run `sha256sum` on the copied `.bit` |
| Source revision and toolchain | TODO: record Git commit and OSS CAD Suite version |

Copy the tested output into the reference directory from the repository root
in WSL (the source file must already exist and have passed FPGA timing):

```bash
cp ./bootloader-serv/build-ulx5m-gs/top_ulx5m_gs_flash_read-serv-dfu-hw-test.bit \
   ./bootloader-serv/bitstreams/top_ulx5m_gs_flash_read-serv-dfu-hw-test.bit
sha256sum ./bootloader-serv/bitstreams/top_ulx5m_gs_flash_read-serv-dfu-hw-test.bit
```

Use the Windows openFPGALoader executable from WSL for FPGA SRAM loading:

```bash
./bin/openFPGALoader.exe -c tigard --freq 1000k -m \
  ./bootloader-serv/bitstreams/top_ulx5m_gs_flash_read-serv-dfu-hw-test.bit
```

Keep Tigard powered. After SRAM loading do not power-cycle the FPGA before
running the USB diagnostic; SRAM configuration is volatile. On this board,
USB enumeration after programming has sometimes required another successful
SRAM load. Successful `openFPGALoader` completion alone does not prove USB
enumeration. Always run the read-only native-Windows diagnostic first:

```powershell
py -3 .\bootloader-serv\tests\diagnose-ulx5m-serv-dfu-hw-test.py
```

Native USB access is **not** available in the WSL environment. Run USB host
tests using native Windows Python and `bin/libusb-1.0.dll`. The experimental
USB write operation requires a separate explicit authorization and must never
be invoked during ordinary enumeration testing.

Hardware verification completed in this project: 64 bytes (one partial page),
512 bytes (two pages), and 4096 bytes (one complete sector) each passed the
USB programming CRC check, independent JTAG verification, candidate-sector
restoration and full 4 MiB comparison to the factory backup. The 4 KiB test
used 64 USB blocks, 16 SPI pages and one sector erase. The flash is back to
its factory contents (SHA-256
`74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d`).

The experimental image supports **no persistent boot selection**. Do not
write this `.bit` to factory flash or confuse copying it into `bitstreams/`
with installing a bootloader. For test and recovery commands see
`bootloader-serv/README_ULX5M_DFU_HW_ONE_SECTOR.md`.

## Programming

Development is performed under Windows with WSL.

FPGA builds and simulations run in WSL. Physical JTAG programming uses the Windows `openFPGALoader.exe` executable with Tigard.

### Power Sequence

The following sequence has produced repeatable successful JTAG programming:

1. Connect and power the Tigard.
2. Power the ULX5M.
3. Program the FPGA using `openFPGALoader.exe`.

The observed USB/JTAG initialization behavior can be sensitive to power sequencing. If FTDI or JTAG device discovery fails, verify that both devices are powered and recognized before retrying.

### Load into FPGA SRAM

From the repository root in WSL:

```bash
./bin/openFPGALoader.exe \
  -c tigard \
  --freq 1000k -m \
  bootloader-serv/bitstreams/ulx5m-gs-serv-v16g2f-seed5.bit
```

Verify the cable selection and command options against the installed version of `openFPGALoader`.

This command is intended to configure FPGA SRAM, not write persistent SPI flash.

**Do not add a flash-writing option when testing this diagnostic image.**

## USB Diagnostics

Run USB diagnostics using native Windows PowerShell and Python rather than attempting native USB device access from WSL.

Example from the repository root:

```powershell
py .\bootloader-serv\tests\compare-ulx5m-serv-usb-link.py `
  --tag "v16g2f-seed5-right" `
  --rounds 256 `
  --delay-ms 100 `
  --output ".\bootloader-serv\build-ulx5m-gs\v16g2f-right"
```

Repeat with the alternate USB connection, changing the tag and output path.

When investigating physical USB connectivity, record:

- Connection or port under test.
- Cable orientation.
- Whether any adapter, hub, or carrier board is present.
- USB host and operating system.
- Bitstream revision and routing seed.
- Successful and failed transfer counts.
- USB error and timeout statistics.
- Whether the device remains enumerated after the test.

## Known Issues

### Right-versus-left USB behavior

As of October 20, 2026:

- The tested right-side USB connection operates successfully.
- The tested left-side USB connection fails repeatedly.
- Reversing the cable does not eliminate the failure.
- The root cause remains undetermined.

Possible areas requiring investigation include USB signal routing, electrical connectivity, USB PHY timing, host behavior, and connector-specific hardware differences.

Do not assume that the failure is caused by FPGA firmware or by the USB cable until supported by testing.

### USB Timing

The reference design achieves 49.46 MHz against a 48 MHz target.

This is a relatively small timing margin. HDL changes, synthesis options, placement, routing, or debug instrumentation may affect timing closure.

The reported frequency is an FPGA static-timing result, not a measurement of USB protocol reliability.

## Rebuilding

Use the matching source revision, firmware, FPGA toolchain, build options, and routing seed to reproduce this bitstream.

Record the following for each retained reference build:

```text
Source commit:
Submodule commits:
OSS CAD Suite version:
Yosys version:
nextpnr-himbaechel version:
GateMate packer version:
Build target:
Clock constraints:
Routing seed:
Achieved Fmax:
Bitstream SHA-256:
Hardware test result:
```

The same routing seed does not guarantee an identical bitstream when the source, dependencies, or tool versions differ.

## Artifact Policy

Keep only selected diagnostic baselines and validated releases in version control.

- Retain bitstreams that reproduce significant hardware behavior.
- Store temporary experiments and unsuccessful routing attempts outside the tracked reference directory.
- Publish validated release bitstreams using GitHub Releases when practical.
- Record SHA-256 checksums for distributed binaries.
- Never replace a reference bitstream without updating its metadata and test results.

Binary bitstreams are generated artifacts and cannot be meaningfully reviewed as source diffs.

## Status

**Retained diagnostic and experimental SRAM images - not production bootloaders.**

The historical v16g2f right-versus-left USB difference remains unresolved. The newer one-sector DFU experiment has separately verified physical USB flash write and JTAG recovery, but still needs consistent enumeration and a validated persistent boot design.

The next work is safe multi-sector DFU programming and recovery, reliable SRAM-load USB enumeration, and GateMate boot-image validation. The separate 8 KiB multi-sector experiment is documented in `bootloader-serv/README_ULX5M_DFU_HW_TWO_SECTORS.md`; it is not yet hardware-tested.