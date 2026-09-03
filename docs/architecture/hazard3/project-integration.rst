Upstream Hazard3 vs Project Customization
=========================================

The most important maintenance rule for Hazard3-Doom is to keep the upstream
processor boundary visible. A large amount of hardware has been added to make
Doom practical on ULX3S/ULX4M, but those additions should not be mistaken for
changes to the RISC-V ISA or the fundamental Hazard3 pipeline.

Comparison basis
----------------

This page was reviewed on **2026-08-19** against:

* project snapshot: `ulx3s/Hazard3 at 736a74459b3f740c47803f20a62d820fcacbe5c3 <https://github.com/ulx3s/Hazard3/tree/736a74459b3f740c47803f20a62d820fcacbe5c3>`_;
* current upstream maintained branch: `Wren6991/Hazard3 stable <https://github.com/Wren6991/Hazard3/tree/stable>`_.

Current upstream can change after that date. The pinned SHA remains the source
of truth for the build documented here.

Upstream-standard processor material
------------------------------------

The following are Hazard3 architecture or reusable upstream infrastructure,
not Doom-specific modifications:

.. list-table::
   :header-rows: 1
   :widths: 34 66

   * - Area
     - Upstream-standard role
   * - ``hdl/hazard3_core.v``
     - Three-stage in-order CPU pipeline and architectural execution control.
   * - Front end / decoder / decompressor
     - RISC-V fetch, decode, compressed instruction handling, and extension gating.
   * - ALU / multiply-divide blocks
     - Integer execution and configurable M/bit-manipulation datapaths.
   * - CSR, PMP, power, IRQ, trigger modules
     - Configurable architectural/control features supplied by Hazard3.
   * - ``hazard3_cpu_1port.v`` and ``hazard3_cpu_2port.v``
     - Reusable wrappers translating core transactions to AHB5 system buses.
   * - Hazard3 Debug Module and DTM
     - Standard external RISC-V debug support.
   * - ECP5 JTAGG DTM adapter
     - Upstream Hazard3 support for using ECP5's chip TAP with OpenOCD.
   * - Minimal example SoC concept
     - CPU + debug + RAM + UART + timer reference integration.

At the current upstream ``stable`` tree, ``example_soc/soc`` remains compact
around the basic example-SoC files and peripheral directory. By contrast, the
pinned ULX3S fork's ``example_soc/soc`` contains additional SDRAM, SAO, SD, and
boot-image modules. That directory-level difference is a strong indicator of
where this project's hardware customization is concentrated.

Project-specific or fork-specific integration
---------------------------------------------

The pinned ULX3S fork adds system features required by the Doom platform:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Project area
     - Purpose
   * - ``ahb_sdram.v`` / ``ulx3s_sdram_controller.v``
     - Attach the ULX3S and ULX4M-LS external SDR SDRAM to the processor/system memory fabric.
   * - ``ahb_litedram.v`` / generated LiteDRAM
     - Attach ULX4M-LD DDR3 through the 40 MHz Hazard3/AHB domain to the qualified 60 MHz LiteDRAM/Wishbone clock-domain adapter; generated profiles select the DDR device and LiteDRAM initialization CPU without changing the AHB bridge interface.
   * - Video/native SDRAM access
     - Allow the display pipeline to consume framebuffer data without pretending video is a CPU feature.
   * - ``apb_sao_bridge.v``
     - Memory-mapped SAO control for project firmware.
   * - ``sao_i2c_engine.v`` / shared-controller logic
     - Implement project I2C/SAO functions and explicit ownership/arbitration.
   * - ``sao_esp32_uart_bridge.v`` / ``sao_uart_phy.v``
     - Sideband communication and resource sharing with the ESP32 companion.
   * - ``apb_sd_spi.v``
     - APB-controlled SD-card SPI engine for standalone loading.
   * - ``hazard3_boot.hex`` preload
     - Place the resident monitor into internal EBR at FPGA configuration time.
   * - ULX3S board wrapper/constraints
     - Connect SDRAM, HDMI/video, SD, SAO/ESP32, clocks, and board pins to the expanded SoC.

What commit ``736a744`` specifically added
------------------------------------------

The pinned commit is titled ``Add SD apb, improve SAO, introduce
hazard3_boot.hex``. Its changes are concentrated in the example-SoC and ULX3S
board integration. In particular it adds the SD APB block, enables SD SPI in
the ULX3S wrapper, adds resident-monitor SRAM preload support, updates SAO
integration, and updates the synthesis/constraint inputs needed for those
features.

That is exactly the pattern we want to preserve: board/application features
are implemented around the processor instead of embedding project behavior in
the generic core.

Selected CPU parameters are integration, not a CPU fork
-------------------------------------------------------

Choosing Hazard3 parameters is also part of the project integration, but it is
not the same thing as modifying the processor implementation. For example:

.. code-block:: text

   EXTENSION_A       = 0
   EXTENSION_C       = 1
   EXTENSION_M       = 1
   EXTENSION_ZBA     = 1
   EXTENSION_ZBB     = 1
   EXTENSION_ZBS     = 1
   BRANCH_PREDICTOR  = 1

These values tell standard parameterized Hazard3 RTL what hardware to
synthesize. The project owns the choice; upstream owns the generic mechanisms.

The same applies to ``RESET_VECTOR=0x40`` and ``DEBUG_SUPPORT=1`` in the
example-SoC CPU instance. They are configuration decisions for this system.

Why this boundary matters
-------------------------

For education
   Students can study a real RISC-V core without first disentangling Doom
   graphics or SD-card logic from the CPU pipeline.

For upstreaming
   Reusable processor fixes belong in upstream Hazard3; board/application
   features should remain in the fork or be generalized before proposing them
   upstream.

For debugging
   An illegal instruction points first toward ISA configuration/compile flags;
   an SDRAM/video/SD failure points first toward the SoC integration. Keeping
   those domains separate reduces the search space.

For upgrades
   A future Hazard3 submodule update can be reviewed as two questions: "what
   changed in upstream processor/debug behavior?" and "does our surrounding
   integration still satisfy the same interfaces?"

Repository ownership in Hazard3-Doom
------------------------------------

The superproject should therefore be read as three layers:

.. code-block:: text

   Hazard3-Doom application/monitor/scripts
                 |
                 v
   pinned ulx3s/Hazard3 integration fork
       |                    |
       |                    +-- project SoC/board additions
       v
   upstream Hazard3 CPU/debug architecture

See :doc:`../repositories` for the corresponding repository/submodule layout.
