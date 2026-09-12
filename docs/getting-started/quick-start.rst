Quick Start
===========

Target
------

The primary documented target is the **ULX3S 85F** running Hazard3 at 50 MHz
with HDMI output. ULX4M-LD 85F is also hardware-qualified with Hazard3/AHB at
40 MHz and a 60 MHz LiteDRAM DDR3 user clock. The compact ULX3S 12F and
ULX4M-LS profiles are documented where their clock, video, or memory layout
differs.

System Requirements
-------------------

Minimum development system:

* RAM: 8 GiB configured (VM guests may report slightly less usable memory)
* CPUs: 2
* Disk: 40 GiB filesystem capacity
* Swap: 4 GiB recommended

Recommended for source builds:

* RAM: 12-16 GiB
* CPUs: 4
* Disk: 60 GiB or more
* Swap: 4-8 GiB

Building Yosys and nextpnr from source can use substantial memory, especially
with parallel builds. Systems below the minimum RAM requirement may terminate
build processes due to memory pressure.

The ``check-system-requirements.sh`` script reports the detected resources:

.. code-block:: bash

   ./scripts/check-system-requirements.sh


Install Software Requirements
-----------------------------

On a fresh system, everything can be installed with a single script. The script is also useful for updating:

.. code-block:: bash

   mkdir -p workspace
   cd workspace

   wget -L \
       https://raw.githubusercontent.com/ulx3s/Hazard3-Doom/main/scripts/full-install.sh \
       -O ./full-install.sh

   chmod +x ./full-install.sh

   ./full-install.sh

.. admonition:: Yosys and nextpnr versions

   The scripts install specific versions of Yosys and nextpnr that are known to pass timing with the default seeds.
   Existing installed versions are quietly overwritten. If you have a different version of yosys or nextpnr installed,
   you may need to adjust the build scripts to match your installed versions. See the :doc:`/user-guide/build` for details.
   and the `build-ecp5-bitstream-common.sh <https://github.com/ulx3s/Hazard3-Doom/blob/main/scripts/build-ecp5-bitstream-common.sh>`_
   script.

1. Clone the repository
-----------------------

If using the ``./full-install.sh`` (above), this step was completed automatically.

Use a recursive clone so the Hazard3 and DoomGeneric submodules are present:

.. code-block:: bash

   git clone --recursive https://github.com/ulx3s/Hazard3-Doom.git
   cd Hazard3-Doom
   git submodule sync --recursive
   git submodule update --init --recursive

For an existing checkout:

.. code-block:: bash

   ./scripts/setup-submodules.sh

2. Build the complete ULX3S target
----------------------------------

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh

Important outputs include:

.. code-block:: text

   build/fpga_ulx3s.bit
   build/ulx3s/monitor/hazard3-boot-monitor.elf
   build/ulx3s/doom-image/hazard3-doom.h3d
   build/ulx3s/hazard3-boot-monitor.hex

3. Program the FPGA for a test run
----------------------------------

From commandline:

.. code-block:: text

   ./bin/fujprog-v48-win64.exe ./build/fpga_ulx3s.bit

From the web application:

For ULX3S, the Hazard3-Doom web application can load ``fpga_ulx3s.bit``
directly into FPGA SRAM through the board's ``US1`` FT231X JTAG interface.
Expand **FPGA web flasher**, select the ``.bit`` file, connect the ULX3S USB
device, probe JTAG, and choose **Program FPGA SRAM**.

On Windows, this WebUSB path requires the ULX3S FT231X interface to use the
WinUSB driver. See :doc:`../user-guide/web-flasher` for the complete setup,
driver, target-verification, and troubleshooting procedure.

A volatile FPGA load does **not** survive removal of power. Other ULX3S
programming tools can still be used when preferred. For a permanent standalone
installation, see :doc:`programming` and :doc:`../user-guide/sd-card`.

Optional: load the current monitor ELF through OpenOCD
------------------------------------------------------

A software-only monitor update can be loaded without rerouting or reprogramming
the FPGA. This path uses the Hazard3 debug module and requires three cooperating
processes: OpenOCD, the local web server, and the browser.

First disconnect the browser **FPGA web flasher** from ``US1`` so OpenOCD can
own the FT231X JTAG interface. In one terminal, from the repository root, start
OpenOCD:

.. code-block:: bash

   ./scripts/start-openocd.sh

A healthy ULX3S 85F session includes lines similar to:

.. code-block:: text

   JTAG tap: lfe5u85.hazard3 tap/device found: 0x41113043
   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

Leave OpenOCD running. In a second terminal start the project web server:

.. code-block:: bash

   python3 web/web-server.py

Open ``http://127.0.0.1:8000/`` in Chrome or Edge. Do **not** open
``web/index.html`` with a ``file://`` URL; the static page cannot call the local
firmware-loader API. Expand **Console firmware uploader**, select
``build/ulx3s/monitor/hazard3-boot-monitor.elf``, and load it. GDB connects to
the already-running OpenOCD server, verifies the ELF sections, resumes Hazard3,
and disconnects.

The external J1 USB-UART adapter is a separate path from the ``US1`` JTAG
interface, so Web Serial may remain connected while OpenOCD is running. See
:doc:`../user-guide/web-tool` and :doc:`../user-guide/jtag-debugging` for the
full workflow and troubleshooting details.

4. Load Doom over UART
----------------------

The browser device tool can perform both Doom transfers without leaving the web
console. Expand **Serial connection**, connect the board UART, and confirm the
resident monitor ``>`` prompt is active. Then expand **Device uploading**:

#. Open **Doom H3D uploader**, select
   ``build/ulx3s/doom-image/hazard3-doom.h3d``, and choose **Upload H3D**.
#. Open **Doom IWAD uploader**, select a legally obtained ``.wad`` file, choose
   the memory profile matching the resident monitor, and choose **Upload IWAD**.
#. Select **Launch with ``j`` after upload** on the IWAD uploader if Doom should
   start immediately after the monitor accepts the IWAD.

For the complete browser workflow and memory-profile table, see
:doc:`../user-guide/web-tool`.

The command-line uploaders remain available when preferred. Close any terminal
or browser connection that owns the UART port first, then run:

.. code-block:: powershell

   py .\doom\upload-doom-image.py `
       .\build\doom-image\hazard3-doom.h3d `
       --port COM7

   py .\doom\upload-wad.py `
       C:\path\to\DOOM.WAD `
       --port COM7 `
       --launch

The UART port name is only an example; use the port assigned to your board.

5. Verify startup
-----------------

A healthy UART launch includes markers similar to:

.. code-block:: text

   H3L READY
   H3L DATA
   H3L OK
   H3W READY
   H3W DATA
   H3W OK
   Doom SDRAM image startup
   monitor ABI: PASS
   Doom interactive HDMI loop: READY

ULX4M-LD fast path
------------------

For ULX4M-LD, use a timing-qualified 40 MHz Hazard3 / 60 MHz LiteDRAM
bitstream, program it through DFU, then explicitly leave DFU:

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

   ./bin/dfu-util.exe -a 0 -e

Use Tigard Interface 0 with the FTDI VCP driver for the 115200 UART and
Interface 1 with libusbK for OpenOCD JTAG. Once the monitor is running, check
``s`` for ``external_memory_ready=YES`` and run ``q``. The current qualified
route also passes ``k``, ``d``, and ``x``.

For a software-only monitor update matching the 40 MHz FPGA:

.. code-block:: bash

   HAZARD3_BUILD_DIR="$PWD/build/ulx4m-ld-40mhz/monitor" \
   HAZARD3_MEMORY_PROFILE=64m \
   HAZARD3_SYS_CLK_HZ=40000000 \
       ./scripts/build.sh

Then start the ULX4M Tigard OpenOCD configuration and load the ELF with
``scripts/load-firmware.sh``. See :doc:`../user-guide/jtag-debugging` for the
complete driver, wiring, IDCODE, and DTM troubleshooting details.

Next steps
----------

* Use :doc:`../user-guide/monitor` to inspect and control the resident monitor.
* Use :doc:`../user-guide/sd-card` to boot without a PC.
* Use :doc:`../user-guide/jtag-debugging` for source-level debugging.
* Use :doc:`../user-guide/sao` for SAO/I2C support.
* Use :doc:`../user-guide/i2cdriver` for the HDMI I2C scanner/analyzer interface.

Implementation references
-------------------------
* `openFPGALoader <https://trabucayre.github.io/openFPGALoader/guide/install.html>`_
