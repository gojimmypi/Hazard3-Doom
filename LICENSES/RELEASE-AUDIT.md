# Hazard3-Doom release licensing audit

This file is a packaging aid, not legal advice and not a substitute for the
license notices in the source tree.

Before publishing a Hazard3-Doom release:

- Record the exact Hazard3 and DoomGeneric gitlink commits from the parent
  repository and preserve their license files and copyright headers.
- Record recursive Hazard3 submodule commits used to produce distributed
  hardware/firmware outputs.
- Include the applicable GPL text and satisfy corresponding-source obligations
  for distributed DoomGeneric/DOOM-derived binaries and other GPL components.
- Preserve Apache-2.0 notices and any required NOTICE material for
  Apache-licensed source actually redistributed.
- Preserve CERN-OHL-W-2.0 SPDX identifiers and notices for covered
  Hazard3-Doom hardware-design source, and ensure distributed Products or
  generated hardware outputs satisfy the applicable Complete Source/Source
  Location requirements.
- Preserve the James Bowman BSD 3-Clause notice if I2CDriver-derived code is
  redistributed; do not imply endorsement.
- For HAD2019/ULX3S/ULX4M bootloader-derived material, preserve the exact
  upstream per-file licenses and copyright headers. Do not treat the bootloader
  as blanket dual-licensed LGPL/BSD material. Include
  `HAD2019-Bootloader-NOTICE.md` and the applicable LGPL-3.0-or-later,
  BSD-3-Clause, ISC/PicoRV32, and mini-printf notices for redistributed content.
- Review `benchmarks/coremark` against EEMBC's current CoreMark source license,
  acceptable-use, result-reporting, and trademark rules before publication.
- Do not package commercial DOOM IWAD/game-data files without an independent
  right to redistribute them.
- Treat `BUNDLED-BINARIES-MANIFEST.md` as a release gate. Pin exact versions,
  SHA-256 values, matching licenses, component notices, and source availability
  for every third-party executable/DLL/toolchain directory actually shipped.
- In particular, do not assume one GPL file covers the bundled RISC-V GNU
  toolchain; it contains multiple components, license families, and runtime
  exceptions.
- For an xPack OpenOCD binary, preserve the exact archive's
  `distro-info/licenses` content instead of reconstructing it from memory.
- For bundled dfu-util executables, pin the exact release/source revision and
  preserve the matching GPL materials and corresponding source. Audit the
  dynamically linked and static Windows builds separately; do not assume the
  dependency/source obligations for `dfu-util.exe` and `dfu-util-static.exe`
  are identical.
- Review the WebUSB flasher provenance described in
  `Web-Flasher-Provenance-NOTICE.md`; preserve exact upstream notices for any
  copied or closely translated implementation material.
- Inventory JavaScript/CSS/font/media dependencies under `web/` and docs. If
  third-party assets are copied into the repository or release, preserve their
  license and attribution files.
- If scripts render but do not redistribute system fonts (for example DejaVu),
  record that tool/font provenance in attribution; if font files themselves
  are copied, include their exact font license.
- Distinguish tools merely used during development from tools redistributed in
  the release. A build dependency does not automatically become part of the
  distributed work, but bundled copies do require their own license review.
- Preserve Git history where practical. Do not replace specific copyright or
  SPDX headers with a generic project-level statement.
- Verify that generated bitstreams and firmware images can be traced to the
  exact source/submodule commits and build configuration used for the release.
- Re-run this audit whenever a new board, benchmark, imported example, web
  library, firmware blob, binary utility, font/artwork asset, or third-party
  source file is added.
