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
     - 1 GiB MT41K512M16HA-125 DDR3L; ``ahb_litedram`` + generated LiteDRAM/``ECP5DDRPHY``
     - 40 MHz CPU/AHB default; 75 MHz LiteDRAM user port
     - LiteDRAM target; timing waiver required
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
builds. Exact source revisions, netlist hashes, CAD-tool versions, and sweep
parameters should be taken from the corresponding build/sweep artifact; these
values are not portable timing guarantees:

.. list-table::
   :header-rows: 1
   :widths: 24 12 40 24

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
     - 232
     - ``clk_sys`` 38.69 MHz; LiteDRAM 62.52 MHz
     - FAIL at 40 MHz / 75.01 MHz

The ULX4M-LD build therefore uses ``ALLOW_TIMING_FAILURE=1`` when a development
bitstream is required. The waiver changes timing failures into reported
warnings; it does not claim timing closure. Rerun routed timing after material
RTL, netlist, seed, or toolchain changes. The ULX3S 85F result is specific to
the timing model selected by the current project flow and should not be compared
directly with runs that select a different ECP5 timing model. See
:doc:`timing-sweeps` for sweep provenance and comparison rules.

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
