# RISC-V GNU toolchain notice

Hazard3-Doom documentation identifies bundled `bin/gdb/` and `bin/riscv-gcc/`
directories for Windows quick-start/debug workflows.

The RISC-V GNU toolchain is a collection/aggregator, not one uniformly licensed
program. Relevant upstream projects include GCC, GNU Binutils, GDB, Newlib,
RISC-V toolchain integration, and their runtime libraries:
https://github.com/riscv-collab/riscv-gnu-toolchain

Hazard3-Doom documentation has also referenced Sysprogs distributions for the
Windows RISC-V toolchain. Sysprogs and the exact package/version used should be
recorded as distribution provenance when those files are copied into `bin/`.

Do not represent `GPL-3.0.txt` or any single license as covering the whole
`riscv-gcc/` directory. GCC, GDB, Binutils, Newlib, target runtime libraries,
and bundled DLLs/data files can have distinct licenses, exceptions, and notice
requirements. GCC runtime libraries can involve the GCC Runtime Library
Exception; Newlib contains multiple permissive copyright notices.

Before release:

- record the exact package name/version/source URL and SHA-256;
- preserve the complete license/notice tree shipped with that package;
- provide source or source offers/links as required for copyleft components;
- preserve runtime-library exceptions and Newlib notices;
- inventory every DLL/executable under `gdb/` and `riscv-gcc/` rather than
  treating each directory as one binary.
