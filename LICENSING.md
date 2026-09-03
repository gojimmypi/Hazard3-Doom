# Licensing

Hazard3-Doom is a multi-license open-source and open-hardware project.

The project is intended primarily for education, research, development,
experimentation, and learning. This statement describes the purpose of the
project and does not restrict the rights granted by the applicable licenses.

## Original Hazard3-Doom open hardware and gateware

Original FPGA hardware designs, gateware, RTL, and related hardware-design
source created specifically for Hazard3-Doom are licensed under the CERN Open
Hardware Licence Version 2 - Weakly Reciprocal (CERN-OHL-W-2.0), where
explicitly identified as such.

The complete, unmodified license text is:

    LICENSES/CERN-OHL-W-2.0.txt

Files containing:

    SPDX-License-Identifier: CERN-OHL-W-2.0

are explicitly licensed under those terms.

## Original Hazard3-Doom software

Original Hazard3-Doom software, firmware, scripts, utilities, web application
code, and documentation are governed by the license identified by their SPDX
identifier or accompanying license notice.

Where a file is identified as Apache-2.0, the applicable license text is:

    LICENSES/Apache-2.0.txt

## Third-party material

Third-party material remains subject to its respective upstream license.

In particular:

- Hazard3 upstream material remains subject to its applicable Apache-2.0 terms.
- Doom and DoomGeneric source and derivative material remain subject to their
  applicable GPL terms.
- dfu-util convenience binaries in `bin/` remain subject to the applicable
  GNU GPL terms identified by the exact upstream release; see
  `LICENSES/dfu-util-NOTICE.md` and `LICENSES/dfu-util-COPYING.txt`.
- HAD2019/ULX3S/ULX4M DFU bootloader-derived material retains its upstream
  per-file licenses and copyrights. Upstream bootloader firmware files marked
  `LGPL v3+` are LGPL-3.0-or-later; much of the bootloader RTL is
  BSD-3-Clause; the included PicoRV32 core carries ISC terms; and
  `mini-printf.c` carries its own BSD-style 3-clause notice. See
  `LICENSES/HAD2019-Bootloader-NOTICE.md`. Original source-file headers and the
  exact upstream revision remain authoritative.
- Other third-party source, binaries, libraries, benchmarks, tools, and assets
  remain subject to their respective upstream licenses.

No Hazard3-Doom license declaration should be interpreted as relicensing
third-party material.

See LICENSES/, ATTRIBUTION.md, source-file headers, submodule license files,
binary-package notices, and Git history for additional information.

## Warranty and liability

The project is provided without warranty under the terms of its applicable
licenses.

For material licensed under CERN-OHL-W-2.0, the warranty disclaimer and
limitation of liability in section 6 of that license apply. Users are
responsible for evaluating the suitability and safety of the project for
their intended application.

## No endorsement

Use of CERN-OHL-W-2.0 does not imply that CERN participated in, approved,
certified, or endorses Hazard3-Doom.

Attribution of third-party projects, organizations, products, or individuals
does not imply endorsement or affiliation.