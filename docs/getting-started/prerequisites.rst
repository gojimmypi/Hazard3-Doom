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

Linux serial-port access
------------------------

On native Linux, including an Ubuntu VM, USB-UART adapters commonly appear as
``/dev/ttyUSB0``, ``/dev/ttyUSB1``, and so on. The device node is normally owned
by ``root:dialout`` with mode ``0660``. Check the active device and your current
login groups before using Web Serial or the Python uploaders:

.. code-block:: bash

   ls -l /dev/ttyUSB*
   groups

If the UART device belongs to ``dialout`` but your user does not, add the user to
the group:

.. code-block:: bash

   sudo usermod -aG dialout "$USER"

The new supplementary group applies to a **new login session**. Log out of the
Ubuntu desktop and log back in before starting the browser. Running ``groups``
in an already-open terminal immediately after ``usermod`` will still show the
old session groups.

For a temporary test that does not require a reboot, logout, or USB reconnect,
grant the current user access to the existing device node with an ACL:

.. code-block:: bash

   sudo setfacl -m u:"$USER":rw /dev/ttyUSB1

Replace ``ttyUSB1`` with the actual device. ``setfacl`` is provided by the
Ubuntu ``acl`` package. This ACL is diagnostic/session-local state on that device
node and may disappear when the USB device is re-enumerated; ``dialout``
membership is the normal persistent setup.

See :doc:`../troubleshooting` for port-ownership, ModemManager, Web Serial, and
one-way UART diagnostics.

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
