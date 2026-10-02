Prerequisites
=============

Host environment
----------------

The documented and tested build-from-source environment is Ubuntu Linux,
either natively or through **WSL with Ubuntu** on Windows. The repository build
and development scripts use Bash. On Windows, WSL is required for the source
build and the repository's ``.sh`` scripts; do not run those build scripts from
PowerShell or ``cmd.exe``.

macOS and other Linux distributions can use the same project when the required
FPGA and RISC-V tools are installed and available on ``PATH``, but package-manager
commands and some host setup steps may need to be adapted for that platform.
The convenience ``full-install.sh`` script is specifically for Ubuntu/WSL.

Native Windows is still appropriate where the documentation explicitly calls
for the browser Device Tool, USB driver management, a COM-port UART uploader,
or a bundled Windows ``.exe``. Unless a command block is explicitly labeled
PowerShell or ``cmd.exe``, Windows users should run it in WSL/Bash.

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
* A RISC-V bare-metal GCC/GDB toolchain available on ``PATH``.
* Yosys, nextpnr-ecp5, Project Trellis/ecppack, and the normal ULX3S FPGA tooling for bitstream builds.
* OpenOCD when using JTAG debugging.

Optional development tools include ``shellcheck`` for repository shell-script
validation. ShellCheck is not required for normal builds.

FPGA toolchain
--------------

The recommended FPGA toolchain is the prebuilt `OSS CAD Suite
<https://github.com/YosysHQ/oss-cad-suite-build>`_. It provides Yosys,
nextpnr, Project Trellis/ecppack, and related tools for Linux, macOS, and
Windows. On Ubuntu/WSL, ``full-install.sh`` installs and activates the project's
expected OSS CAD Suite automatically. You may instead install an OSS CAD Suite
release yourself and activate its environment so its tools are available on
``PATH``.

For advanced development or reproducibility work, the installation scripts also
provide source-build options that build selected FPGA tools from specific
upstream GitHub commits. Building the FPGA tools from source is not required for
the normal installation path.

On Windows, the OSS CAD Suite project recommends WSL with its Linux-x64 package
for the best experience; this also matches the Bash/WSL environment used by
Hazard3-Doom.

RISC-V GCC toolchain
--------------------

The build uses a compatible RISC-V bare-metal GCC toolchain found on ``PATH``.
The normal discovery accepts ``riscv-none-elf-*``, ``riscv32-unknown-elf-*``,
and ``riscv64-unknown-elf-*`` tool names. xPack RISC-V GCC installations work
when their ``bin`` directory is on ``PATH``.

On Ubuntu/WSL, one distribution-provided option is:

.. code-block:: bash

   sudo apt-get update
   sudo apt-get install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

On macOS or another Linux distribution, install an equivalent bare-metal RISC-V
GCC package for that platform or use xPack. Package names vary, so a search for
``RISC-V bare-metal GCC install <distribution name or macOS>`` is often the
simplest way to find current platform-specific instructions. After installation,
confirm that the compiler is available on ``PATH``.

Use ``TOOLCHAIN_PREFIX`` when you need to select a specific installation. For
example:

.. code-block:: bash

   TOOLCHAIN_PREFIX=riscv-none-elf- ./scripts/build.sh

The historical ``/opt/riscv/bin/riscv32-unknown-elf-`` prefix remains
supported for compatibility, but installing the toolchain under ``/opt`` is
not required.

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

* `OSS CAD Suite <https://github.com/YosysHQ/oss-cad-suite-build>`_
* `RISC-V GCC xPack <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_
* `Ubuntu RISC-V GCC package <https://packages.ubuntu.com/search?keywords=gcc-riscv64-unknown-elf>`_
* `Yosys <https://github.com/YosysHQ/yosys>`_
* `nextpnr <https://github.com/YosysHQ/nextpnr>`_
