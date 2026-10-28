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

* Use the startup order that yields reliable Tigard detection on the
  actual bench. On October 28, powering the ULX5M before Tigard resolved
  one initial JEDEC-detection failure; earlier experiments sometimes
  favored the opposite order. Do not treat either order as guaranteed.
  Load SRAM from WSL by invoking the Windows executable, for example:

  .. code-block:: bash

     ./bin/openFPGALoader.exe -c tigard --freq 1000k -m path/to/image.bit

  The ``-m`` RAM configuration is volatile and does not write configuration
  flash. A cold restart can be necessary after unsuccessful transfers.
  Require a valid JTAG IDCODE and flash JEDEC before trusting any readback.
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

October 26, 2026: persistent primary installation
-------------------------------------------------

* The physical V005 SW1 mapping was already measured on October 17: ON/ON
  raised ``CFG_MD2`` and ``CFG_MD3`` to approximately 1.8 V (JTAG ``0xC``).
  The V005 schematic shows OFF/OFF pulls both LOW (SPI-active ``0x0``).
  See :doc:`index` for the full switch table. No RTL register sets this
  power-on configuration mode.
* The SERV v50 seed-7 image was locally routed at 48.57 MHz. With SW1 ON/ON,
  JTAG SRAM configuration supported BTN2 DFU, USB enumeration ``1D50:614B``,
  and read-only verification of the secondary sector. The normal-mode firmware
  reported ``RECFG`` requested; this did **not** establish secondary takeover.
* The guarded v55 install reported all seven 64 KiB primary blocks at
  ``0x000000..0x06FFFF`` verified, followed by an exact full 4 MiB flash hash
  ``bf0db6395ac728aa51c424052087e627b51163941530b5419e2f5c41e490fc28``.
  Factory recovery data was preserved. SPI-active cold boot (SW1 OFF/OFF) and
  BTN2-held **persistent** DFU boot have **not yet been physically tested**.

October 28, 2026: v72 runtime secondary takeover on silicon
-----------------------------------------------------------

* The isolated v72b RTL simulation and seven regression checks passed in WSL.
  The 25 MHz seed-302 v72 primary routed at 79.26 MHz. The 27-byte command
  was checked against its exact final packed image, not just a hand-coded
  constant. Bitstream size was 14,987 bytes; SHA-256 was
  ``839696d7c8a4ecdf63dff904c01ce85aea280bd885eda4309c7e5d25800e3aa0``.
* The v72c guarded install verified JTAG IDCODE ``0x20000001``, flash JEDEC
  ``1f 42 16`` and the original v63c full 4 MiB flash twice before writing.
  The pre-install full-flash SHA-256 was
  ``644c7c1b26e4cc2ba419a59a53ca8ffbbc02e808920d68336e84ac886d81cb02``.
  Only the first 64 KiB was replaced. The protected remainder and secondary
  application were verified; an exact v63c backup was saved.
* With SW1 OFF/OFF (SPI-active), BTN2 released and a new power-on, the user
  observed the v72 primary LED witness (D6 on, D7 blinking), followed by
  D0 blinking and the D1-D7 walking-LED pattern of the secondary v41 app
  at ``0x201000``. **Physical secondary takeover PASSED.** JTAG was not used
  to configure the FPGA during the observed SPI-active boot.
* The successful v72 primary deliberately has **no USB DFU**. The v63c
  recovery session is
  ``bootloader-serv/build-ulx5m-gs/v72c-registered-ab-20261028T193955726442Z-508``.
  Preserve that directory and the v72 bitstream. v72 is an experiment, not
  a replacement for the real SERV/BTN2 bootloader.

Configuration handoff and remaining work
----------------------------------------

The v65/v67 results demonstrated that the packed configuration-bank ownership
bit matters. The v70 command bytes matched TinyDFU's algorithm but v70
failed physically. v72 succeeded using registered EN/VALID/DATA, a minimum
three-clock EN lead, interbyte idle clocks, at least eight EN-high clocks
following the last byte, a 16-count EN-low wait, and RECFG. This proves
that the **complete v72 sequence** works on this board; it does not prove
which individual timing difference made v70 fail.

Integrate this engine into ``bootloader-serv/rtl/ulx5m_spi_active_reboot_wb.v``
while retaining existing SPI-idle/flash-pin release, ARM/BOOT Wishbone gating,
BTN2 selection, and native v41-sector validation. Generate the command from
the final full SERV packed primary (not v72's minimal ``cmd.hex``), route the
combined design locally at 48 MHz, and independently qualify both power-on
paths before considering production readiness. Full details, hashes and
recovery constraints are recorded in :doc:`multiboot-v72`.

For GateMate bitstream and reconfiguration options see the `Cologne Chip
GateMate toolchain quickstart
<https://colognechip.com/programmable-logic/gatemate/gatemate-toolchain-quickstart/>`_.
For GPIO overstress research and its limitations see `gm_gpio_ringosc
<https://github.com/pu-cc/gm_gpio_ringosc>`_.
