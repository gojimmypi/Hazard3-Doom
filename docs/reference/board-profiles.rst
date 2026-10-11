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

Default nextpnr routing settings
--------------------------------

Builds and seed sweeps use the board-specific defaults in
``scripts/ecp5-board-defaults.sh``. The assignments below are included directly
from that file:

.. literalinclude:: ../../scripts/ecp5-board-defaults.sh
   :language: bash
   :start-at: ULX3S_12F_DEFAULT_NEXTPNR_SEED=
   :end-at: ULX4M_LD_85F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT=

``NEXTPNR_SEED`` and ``NEXTPNR_HEAP_TIMINGWEIGHT`` override build defaults.
``SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT`` overrides the sweep timing weight.
Record explicit overrides with the routed results. These defaults are
configuration baselines, not timing guarantees.

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
     - 11
     - ``clk_sys`` 52.24 MHz
     - PASS at 50 MHz
   * - ULX3S 12F
     - 82
     - ``clk_sys`` 42.70 MHz
     - PASS at 40 MHz
   * - ULX4M-LD 85F
     - 8
     - ``clk_sys`` 40.47 MHz; LiteDRAM clocks 65.71 / 66.05 MHz; HeAP weight 30
     - PASS at 40 MHz; routed sweep, hardware qualification pending

These rows record specific routes. The ULX4M-LD seed-8 result used frozen
netlist SHA256 ``9403efe0ff3fb55866be8afbfed0261a5769dd98e4c150fa81aa3520f5ea3173``.
The older seed-83 route passed a previous netlist but failed at 38.06 MHz on
the current netlist with HeAP weight 30. Seed 8 has not yet been confirmed by
a normal production rebuild or hardware test.

The hardware-qualified ULX4M-LD checkpoint is substantially stronger than the
older ``ALLOW_TIMING_FAILURE`` development state. The exact frozen netlist was:

.. code-block:: text

   160c536b12e46667990c887571da6f443ccc6c5a2ba644033db43fc783ea9453

The timing-passing hardware-qualified route used nextpnr seed 2 with HeAP
``timingweight=30``. The exact locally tested bitstream had SHA256:

.. code-block:: text

   294602982dfc4a9906961f2e8b6f43de925d8c11a7e5e6bb0f5e392965a868de

The same frozen netlist failed with the earlier HeAP ``timingweight=10``
setting, showing why the place-and-route settings are part of the qualification
record rather than an incidental detail.

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
