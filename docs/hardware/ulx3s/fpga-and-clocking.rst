FPGA, Clocking, and I/O Domains
===============================

ECP5 device family
------------------

ULX3S uses Lattice ECP5 devices in the 381-ball package. Upstream board material
supports 12F, 25F, 45F, and 85F density populations. Hazard3-Doom currently
provides complete build wrappers for the 85F and 12F targets.

The density changes available LUTs, EBR, and routing resources; it does not by
itself identify the PCB revision. This distinction is especially important when
reading an FTDI description string or an old build log: a product string may be
stale while the ECP5 JTAG ID still reports the actual FPGA device.

25 MHz board oscillator
-----------------------

The upstream ULX3S design provides a 25 MHz onboard oscillator. Hazard3-Doom
uses that reference to generate the clocks required by the processor, SDRAM,
and video logic.

The current board-profile baselines are:

.. list-table::
   :header-rows: 1
   :widths: 24 20 56

   * - Target
     - Hazard3 clock
     - Purpose
   * - ULX3S 85F
     - 50 MHz
     - CPU, AHB/SoC logic, SDRAM controller side, monitor, and platform logic.
   * - ULX3S 12F
     - 40 MHz
     - Reduced-resource CPU/SoC and SDRAM target.

Video uses its own derived clocks, so timing work must consider more than the
CPU clock alone. The exact routed clock values are build results, not permanent
board specifications.

SDRAM clocking
--------------

The external memory is synchronous SDR SDRAM. The board wrapper and native
controller keep the SDRAM command/data timing related to the Hazard3 system
clock and provide the physical SDRAM clock with the phase relationship required
by the design.

Changing ``HAZARD3_SYS_CLK_HZ`` is therefore not just a CPU-speed change. SDRAM
timing, video timing, UART divisors, and nextpnr closure must remain valid for
the selected configuration.

Timing closure is target-specific
---------------------------------

Hazard3-Doom centralizes the default nextpnr routing settings in
``scripts/build-ecp5-bitstream-common.sh``. Current release baselines are also
summarized in :doc:`../../reference/board-profiles`.

A seed that passes for ULX3S 85F is not evidence that it will pass on 12F, and a
previously good seed should not be assumed valid after a synthesis-visible RTL,
monitor-preload, toolchain, or constraint change. See
:doc:`../../reference/timing-sweeps` for the project sweep workflow.

I/O standards and differential-looking signals
-----------------------------------------------

The LPF is electrical documentation as well as a pin map. Ordinary ULX3S GPIO,
SDRAM, and many peripheral signals use 3.3 V LVCMOS I/O. GPDI/TMDS-style video
uses paired FPGA outputs and board routing that must match the selected video
implementation and constraint file.

Do not infer an electrical standard from a connector name. A signal can be
routed as a pair without being a native ECP5 high-speed SerDes channel, and a
correct package ball with the wrong I/O configuration can still be an invalid
hardware design.
