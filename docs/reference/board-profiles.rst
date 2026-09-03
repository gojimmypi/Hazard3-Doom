Board Profiles
==============

.. list-table::
   :header-rows: 1
   :widths: 18 16 28 14 24

   * - Board
     - Memory profile
     - External memory/controller
     - System clock
     - Video/build note
   * - ULX3S 85F
     - ``64m``
     - 16-bit SDR SDRAM; native ``ahb_sdram`` controller path
     - 50 MHz
     - 320x200 default; extended modes available
   * - ULX3S 12F
     - ``32m`` default; ``64m`` optional
     - 16-bit SDR SDRAM; native ``ahb_sdram`` controller path
     - 40 MHz
     - Compact 320x200 SDRAM scanout
   * - ULX4M-LD 85F
     - ``64m``
     - x16 DDR3/DDR3L; Micron ``MT41K512M16HA`` or Alliance ``AS4C256M16D3`` profile; ``ahb_litedram`` + generated LiteDRAM/``ECP5DDRPHY``
     - 40 MHz CPU/AHB; 60 MHz qualified LiteDRAM user port; 25 MHz reference/init
     - Micron hardware-qualified; device-specific generated profiles
   * - ULX4M-LS 85F
     - ``32m``
     - 32 MiB, 16-bit SDR SDRAM; native ``ahb_sdram`` controller path
     - 50 MHz
     - Native SDR memory path

The monitor, linked Doom image, and SDRAM memory map must agree on the memory
profile. Complete board build wrappers set their target-specific profile and
clock automatically.

Current FPGA validation
-----------------------

The routed values below are regression checkpoints collected from project
builds. Exact source revisions, netlist hashes, CAD-tool versions, memory-device
profile, and nextpnr settings are part of the result; seed numbers are not
portable timing guarantees.

.. list-table::
   :header-rows: 1
   :widths: 22 12 38 28

   * - Board
     - Seed
     - Routed result
     - Status
   * - ULX3S 85F
     - 55
     - ``clk_sys`` 51.77 MHz
     - PASS at 50 MHz
   * - ULX3S 12F
     - 65
     - ``clk_sys`` 42.11 MHz
     - PASS at 40 MHz
   * - ULX4M-LD 85F
     - 2
     - ``clk_sys`` 43.94 MHz; LiteDRAM user 67.81 MHz
     - PASS at 40 MHz / 60 MHz and hardware-qualified DDR

The current ULX4M-LD checkpoint is substantially stronger than the older
``ALLOW_TIMING_FAILURE`` development state. The exact frozen netlist was:

.. code-block:: text

   160c536b12e46667990c887571da6f443ccc6c5a2ba644033db43fc783ea9453

The timing-passing hardware-qualified route used nextpnr seed 2 with HeAP
``timingweight=30``, ``critexp=3``, and timing-driven rip-up enabled. The exact
locally tested bitstream had SHA256:

.. code-block:: text

   294602982dfc4a9906961f2e8b6f43de925d8c11a7e5e6bb0f5e392965a868de

The same frozen netlist failed with the earlier default HeAP
``timingweight=10``, ``critexp=2`` and no timing-driven rip-up, showing why the
place-and-route settings are part of the qualification record rather than an
incidental detail.

Hardware validation on the Micron board then passed the complete ``q`` SDRAM
qualification suite, 40 MiB heap stress, Doom platform smoke test, and copied
RV32 execution from DDR. A timing PASS alone is not sufficient to claim DDR
qualification.

A new resident-monitor preload or any other synthesis-visible change creates a
new netlist. Preserve the qualified seed-2 artifact as a reference, then rerun
routing and hardware qualification for the new netlist. See :doc:`timing-sweeps`
for sweep provenance and comparison rules.

Primary ULX3S peripheral bases
------------------------------

.. list-table::
   :header-rows: 1

   * - Peripheral
     - Base
   * - SAO bridge
     - ``0x40009000``
   * - SD SPI
     - ``0x4000A000``
   * - HDMI/video
     - ``0x4000C000``
