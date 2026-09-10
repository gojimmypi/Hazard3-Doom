Prerequisites
=============

Host environment
----------------

The project is designed to build reproducibly from a Bash environment. On Windows, WSL is the recommended command-line build environment; PowerShell remains convenient for the UART uploader scripts.

Machine requirements check
--------------------------

After cloning the repository, run the non-destructive machine checker before the
first build:

.. code-block:: bash

   ./scripts/requirements-check.sh

The checker does not install packages or change configuration. Missing required
items produce a failing exit status, while optional development, simulation,
debug, and documentation tools are reported separately. It also verifies that a
detected RISC-V compiler accepts the Hazard3 RV32 ISA/ABI options.

Required tools
--------------

At minimum, install:

* Git with recursive submodule support.
* Python 3.
* ``pyserial`` for UART uploads.
* A RISC-V bare-metal GCC/GDB toolchain.
* Yosys, nextpnr-ecp5, Project Trellis/ecppack, and the normal ULX3S FPGA tooling for bitstream builds.
* OpenOCD when using JTAG debugging.
* shellcheck for validating shell scripts.

The monitor build currently defaults to this RISC-V toolchain prefix:

.. code-block:: text

   /opt/riscv/bin/riscv32-unknown-elf-

The machine checker also recognizes common alternatives such as
``riscv-none-elf-`` and xPack installations. Override the build prefix when
your compiler is installed elsewhere. For example:

.. code-block:: bash

   TOOLCHAIN_PREFIX=riscv-none-elf- ./scripts/build.sh

Python uploader dependency
--------------------------

.. code-block:: bash

   python3 -m pip install pyserial

IWAD
----

The repository does not distribute a commercial Doom IWAD. Keep a legally obtained ``DOOM.WAD`` outside Git or in the ignored ``wads/`` directory.

.. warning::

   Do not commit or redistribute a commercial Doom IWAD as part of the project repository or documentation build.


Related links
-------------

* `RISC-V GCC XPACK <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_
* `yosys <https://github.com/YosysHQ/yosys>`_
* `nextpnr-ecp5 <https://github.com/YosysHQ/nextpnr>`_
