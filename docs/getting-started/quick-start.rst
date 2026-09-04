Quick Start
===========

Target
------

The primary documented target is the **ULX3S 85F** running Hazard3 at 50 MHz
with HDMI output. ULX4M-LD 85F is also hardware-qualified with Hazard3/AHB at
40 MHz and a 60 MHz LiteDRAM DDR3 user clock. The compact ULX3S 12F and
ULX4M-LS profiles are documented where their clock, video, or memory layout
differs.

1. Clone the repository
-----------------------

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
   build/hazard3-boot-monitor.elf
   build/doom-image/hazard3-doom.h3d

3. Program the FPGA for a test run
----------------------------------

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

4. Load Doom over UART
----------------------

Close any terminal program that already owns the UART port, then upload the Doom image:

.. code-block:: powershell

   py .\doom\upload-doom-image.py `
       .\build\doom-image\hazard3-doom.h3d `
       --port COM7

Then upload a legally obtained IWAD:

.. code-block:: powershell

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
