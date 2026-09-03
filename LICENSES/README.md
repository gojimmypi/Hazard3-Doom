# Hazard3-Doom licensing references

This directory collects license texts and component-specific notices relevant
to Hazard3-Doom.

IMPORTANT: The presence of a license text here does not apply that license to
the Hazard3-Doom repository as a whole. Each source file, submodule,
third-party component, generated artifact, and bundled binary remains governed
by its own copyright notices, SPDX identifiers, upstream license, and Git
history.

Hazard3-Doom is a multi-license project. The root `LICENSE` provides a concise
licensing overview, while `../LICENSING.md` defines the applicable project
licensing policy and scope.

The presence of a license text in this directory does not apply that license
to unrelated project or third-party material.

See `../ATTRIBUTION.md` for broad acknowledgements.

## Core source/component notices

| File | Component/use |
|---|---|
| `Apache-2.0.txt` | Hazard3 and files/components explicitly licensed Apache-2.0 |
| `CERN-OHL-W-2.0.txt` | Original Hazard3-Doom FPGA/gateware source explicitly licensed CERN-OHL-W-2.0 |
| `GPL-2.0.txt` | DOOM/DoomGeneric and other exact GPL-2 components as applicable |
| `BSD-3-Clause-i2cdriver.txt` | James Bowman's I2CDriver |
| `CoreMark-NOTICE.md` | EEMBC CoreMark attribution/trademark caution |
| `Hazard3-NOTICE.md` | Hazard3 provenance and submodule boundary |
| `DOOM-DoomGeneric-NOTICE.md` | DOOM/DoomGeneric lineage and WAD separation |
| `I2CDriver-NOTICE.md` | I2CDriver inspiration and non-endorsement |
| `Nested-Upstream-NOTICE.md` | Recursive Hazard3/test/support projects |

### HAD2019 / ULX3S / ULX4M DFU bootloader

The bootloader is mixed-license, with licensing determined by the applicable
upstream file/header rather than a blanket project-wide choice.

| File | Component/use |
|---|---|
| `HAD2019-Bootloader-NOTICE.md` | Bootloader lineage, contributors, provenance, and per-file licensing summary |
| `LGPL-3.0.txt` | GNU LGPL v3 text for upstream bootloader firmware files marked LGPL v3-or-later |
| `BSD-3-Clause-HAD2019-Bootloader.txt` | Sylvain Munaut BSD 3-Clause text used by upstream bootloader RTL |
| `ISC-PicoRV32.txt` | Clifford Wolf PicoRV32 license notice used by the upstream bootloader |
| `BSD-3-Clause-mini-printf.txt` | Michal Ludvig `mini-printf.c` BSD-style 3-clause notice |

## Bundled Windows utility/library notices

The repository material reviewed for this bundle shows that `bin/` redistributes
third-party executables, DLLs, and GNU toolchain directories. These are not mere
build dependencies, so they receive explicit release notices.

| File | Component/use |
|---|---|
| `BSD-2-Clause-fujprog-reference.txt` | fujprog BSD-2 reference; exact revision LICENSE still required |
| `dfu-util-COPYING.txt` | Upstream GNU GPL version 2 text distributed with dfu-util |
| `dfu-util-NOTICE.md` | dfu-util Windows utilities, attribution, GPL source obligations, and version-pinning requirement |
| `fujprog-NOTICE.md` | fujprog/ujprog credits and version-pinning requirement |
| `openFPGALoader-NOTICE.md` | openFPGALoader Apache-2.0 binary notice |
| `OpenOCD-xPack-NOTICE.md` | OpenOCD GPL and xPack distribution notice |
| `MIT-PuTTY-reference.txt` | PuTTY MIT reference; exact version LICENCE still required |
| `PuTTY-NOTICE.md` | PuTTY attribution/version-pinning requirement |
| `GPL-3.0.txt` | GPL version 3 reference, relevant to Zadig and GNU components |
| `LGPL-3.0.txt` | LGPL version 3 reference, relevant to libwdi |
| `Zadig-libwdi-NOTICE.md` | Zadig 2.5/libwdi and additional upstream credits |
| `LGPL-2.1.txt` | LGPL version 2.1 reference, relevant to libusb/libftdi1 |
| `libusb-NOTICE.md` | libusb DLL attribution and exact-version requirement |
| `libftdi1-NOTICE.md` | libftdi1 DLL attribution and exact-version requirement |
| `RISC-V-GNU-Toolchain-NOTICE.md` | bundled GDB/GCC toolchain multi-license warning |
| `BUNDLED-BINARIES-MANIFEST.md` | known `bin/` inventory and release gate |

## FPGA/WebUSB provenance and data licenses

| File | Component/use |
|---|---|
| `CC0-1.0.txt` | Reference for Project Trellis database licensing where applicable |
| `Web-Flasher-Provenance-NOTICE.md` | Project Trellis/fujprog/FTDI/libftdi technical lineage |

## Release guidance

`RELEASE-AUDIT.md` is the top-level release checklist. It deliberately marks
unknown exact binary versions as work to complete rather than inventing
version-specific notices.

When the exact contents of a release archive are known, prefer copying the
original license/NOTICE files from each exact upstream source/binary package in
addition to these project-level summaries. Upstream originals are authoritative.
