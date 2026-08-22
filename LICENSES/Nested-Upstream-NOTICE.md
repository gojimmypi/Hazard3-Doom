# Nested upstream projects notice

Hazard3 itself contains recursive development, verification, benchmarking, and
FPGA-support submodules. Historical/current Hazard3 trees used by this project
have included projects such as:

- Wren6991/libfpga;
- Wren6991/fpgascripts;
- riscv-formal;
- Embench / embench-iot;
- RISC-V Architectural Tests / riscv-arch-test;
- riscv-tests;
- other exact recursive submodules recorded by the pinned Hazard3 commit.

Do not duplicate guessed license texts for all of these at the Hazard3-Doom
root. Preserve each recursively checked-out project's own license and notices,
and inventory only the nested content actually redistributed in a release.
The exact recursive submodule revisions are part of reproducible provenance.
