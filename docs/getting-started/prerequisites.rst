Prerequisites
=============

Host environment
----------------

The project is designed to build reproducibly from a Bash environment. On Windows, WSL is the recommended command-line build environment; PowerShell remains convenient for the UART uploader scripts.

Required tools
--------------

At minimum, install:

* Git with recursive submodule support.
* Python 3.
* ``pyserial`` for UART uploads.
* A RISC-V bare-metal GCC/GDB toolchain.
* Yosys, nextpnr-ecp5, Project Trellis/ecppack, and the normal ULX3S FPGA tooling for bitstream builds.
* OpenOCD when using JTAG debugging.

The known working RISC-V prefix used by the project is:

.. code-block:: text

   /opt/riscv/bin/riscv32-unknown-elf-

Override it when necessary:

.. code-block:: bash

   TOOLCHAIN_PREFIX=/path/to/riscv32-unknown-elf- ./scripts/build.sh

Python uploader dependency
--------------------------

.. code-block:: bash

   python3 -m pip install pyserial

IWAD
----

The repository does not distribute a commercial Doom IWAD. Keep a legally obtained ``DOOM.WAD`` outside Git or in the ignored ``wads/`` directory.

.. warning::

   Do not commit or redistribute a commercial Doom IWAD as part of the project repository or documentation build.
