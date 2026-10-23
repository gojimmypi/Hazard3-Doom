.. NOTE: English fallback - Croatian translation pending.

ULX5M-GS GateMate Bring-up Record (October 2026)
================================================

This page records observed results on the ULX5M-GS V005 development board.
It supplements :doc:`index` and :doc:`../../user-guide/bootloader`; it
does not replace the current source, test logs, or board schematics. Dates
and design revisions matter: a passing result from one bitstream does not
qualify another bitstream.

Toolchain, synthesis and timing
-------------------------------

* Development builds and simulations run in WSL. Native USB device access is
  not available in this WSL setup. Windows tools handle FPGA programming and
  Windows/PyUSB tests handle USB enumeration and transactions.
* The reproducibility baseline used OSS CAD Suite ``2026-07-20``, Yosys
  ``0.67+47`` and ``nextpnr-himbaechel 0.10-95-gddc6c8c8``. Compare both
  versions, synthesis settings, input netlist hash, seed and constraints
  before comparing route frequency between local and CI runs.
* GateMate synthesis used ``synth_gatemate -top top_ulx5m_gs_flash_read
  -luttree -nomx8`` for the tested flash-read/SERV path. P&R seed strongly
  affects timing; a passing seed is not a substitute for design margin.
* Tested SERV USB diagnostics reached a 48 MHz timing constraint with
  specific seeds. The v16g2f baseline passed with seed 5 (49.46 MHz),
  while many other seeds failed. The later BTN2-gated build passed at
  49.94 MHz with seed 147. Keep the precise RTL, JSON hash and tool versions
  together when retaining a known-good bitstream.
* Synthesis transforms RTL to a netlist; nextpnr places cells and routes
  interconnect while checking the architecture's constraints. Post-route
  timing PASS does not establish USB electrical or protocol reliability.

JTAG, USB and repeatability
---------------------------

* Power Tigard first, then the ULX5M. Load SRAM only from WSL by invoking
  the Windows executable, for example:

  .. code-block:: bash

     ./bin/openFPGALoader.exe -c tigard --freq 1000k -m path/to/image.bit

  The ``-m`` RAM configuration is volatile and does not write configuration
  flash. On the tested setup, powering Tigard first resolved initial FTDI
  failures; a cold restart can be necessary after unsuccessful transfers.
* The USB test identity is ``1D50:614B``; a cached Windows friendly name
  can still say ULX4M. Check the device-reported description and USB
  descriptors rather than relying on the friendly name.
* The same USB diagnostic bitstream passed 768/768 descriptor transfers
  on the Dell Precision 5570 right USB-C port. Left USB-C direct failed
  intermittently, but the left port through an Anker USB hub passed.
  Cable reversal did not resolve direct-left failures. The precise physical
  or host-controller cause remains undetermined; do not attribute it to
  SERV instruction throughput or a specific USB RTL block without capture.
* USB-C VBUS attach power is a **separate issue** from USB descriptor traffic.
  See :doc:`index` for missing CC pull-down resistors on the carrier path.

SERV DFU and flash safety
-------------------------

* The active GateMate SERV development path is under ``bootloader-serv/``.
  The ``bootloader/`` PicoRV32 version remains a separate fallback.
* Physical tests of the FWT3 DFU stage transferred 16,384 bytes to four
  flash sectors at ``0x200000`` through ``0x203FFF`` (256 DFU blocks and
  64 SPI pages); independent JTAG readback verified the pattern. The
  sectors were subsequently restored and the 4 MiB factory flash compared
  byte-for-byte with its backups. This is evidence for the tested staging
  and flash-write path, not proof of safe arbitrary image replacement.
* Factory flash geometry observed: JEDEC ``1f 42 16``, 4 MiB, 4096-byte
  sectors, 256-byte pages. Back up and verify before any write. Protect
  the original configuration and never reuse another board's flash layout
  without verifying device and partition boundaries.
* BTN2 (active-low ``btn_n[1]``) was physically verified as a latched
  startup mode selector: hold it during configuration for DFU and release
  after startup. Without BTN2 the tested gated build entered a
  **normal-mode placeholder**, not a user application; SERV/USB/SPI stayed
  in reset and USB ``1D50:614B`` was absent. Do not describe that build
  as a completed persistent dual-mode bootloader.
* The isolated configuration handoff timing model passed Icarus simulations
  covering EN lead, interbyte spacing, an eight-cycle tail and rejection
  of invalid or BTN2-DFU candidates. A passing simulation-only model is
  **not** hardware proof of GateMate reconfiguration or application boot.

Configuration handoff and next steps
------------------------------------

The target design keeps a recoverable DFU entry path and starts a verified
normal image only after validating selection and safety policy. GateMate
configuration/reconfiguration is a distinct mechanism from firmware jumping
to a new instruction address. Before treating it as finished, validate the
actual configuration interface, flash image boundaries, persistent startup,
and power-cycle recovery on hardware. Prefer JTAG SRAM tests until those
checks are complete.

For GateMate bitstream and reconfiguration options see the `Cologne Chip
GateMate toolchain quickstart
<https://colognechip.com/programmable-logic/gatemate/gatemate-toolchain-quickstart/>`_.
For GPIO overstress research and its limitations see `gm_gpio_ringosc
<https://github.com/pu-cc/gm_gpio_ringosc>`_.
