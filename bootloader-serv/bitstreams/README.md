# ULX5M-GS SERV Bitstreams

This directory contains selected, hardware-tested FPGA bitstreams for the ULX5M-GS SERV-based USB bootloader development project.

These files are retained as reproducible diagnostic baselines. Experimental builds and routine synthesis outputs should not be committed.

## Current Reference Bitstream

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
  --freq 1000000 \
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

**Development diagnostic image — not a production bootloader.**

The immediate development priority is to determine why USB operates through the right-side connection but fails through the left-side connection.

After USB communication is sufficiently reliable, development can proceed toward firmware upload, verified SPI flash programming, image validation, and recovery functionality.