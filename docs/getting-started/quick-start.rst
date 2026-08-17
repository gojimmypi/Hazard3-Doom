Quick Start
===========

Target
------

The primary documented target is the **ULX3S 85F** running Hazard3 at 50 MHz with HDMI output. ULX4M-LD and ULX4M-LS profiles are also documented where their memory layout differs.

1. Clone the repository
-----------------------

Use a recursive clone so the Hazard3 and DoomGeneric submodules are present:

.. code-block:: bash

   git clone --recursive https://github.com/gojimmypi/Hazard3-Doom.git
   cd Hazard3-Doom
   git switch develop
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

   build/ulx3s/fpga_ulx3s.bit
   build/hazard3-boot-monitor.elf
   build/doom-image/hazard3-doom.h3d

3. Program the FPGA for a test run
----------------------------------

Use the project's normal ULX3S programming flow to load ``fpga_ulx3s.bit`` temporarily while validating a build. A volatile FPGA load does **not** survive removal of power.

For a permanent standalone installation, see :doc:`programming` and :doc:`../user-guide/sd-card`.

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

Next steps
----------

* Use :doc:`../user-guide/monitor` to inspect and control the resident monitor.
* Use :doc:`../user-guide/sd-card` to boot without a PC.
* Use :doc:`../user-guide/jtag-debugging` for source-level debugging.
* Use :doc:`../user-guide/sao` for SAO/I2C support.
