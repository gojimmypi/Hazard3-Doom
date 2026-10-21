ULX5M-GS V005 Hardware Notes
============================

These notes describe the Intergalaktik ULX5M-GS V005 with the Cologne Chip
GateMate CCGM1A1. They record the electrical constraints and hardware
observations relevant to the in-development Hazard3-Doom port. They are not a
substitute for the board schematic or the FPGA datasheet. Check the populated
board revision before applying them to another unit.

.. warning:: East-bank voltage exceeds the GateMate rating

   The ULX5M-GS board manufacturer verbally confirmed that the USB-powered
   V005 board under investigation uses **3.3 V on GateMate bank EA**. This is
   a reported board configuration, not an independently measured VDD_EA
   reading or an endorsement by the FPGA manufacturer.

   Cologne Chip DS1001 (September 2026), Table 4.5, specifies **2.7 V**
   maximum operating VDDIO for single-ended GPIO. Table 4.1 specifies
   **2.75 V** absolute maximum VDDIO. Thus a 3.3 V VDD_EA supply exceeds both limits.
   Successful GPIO or USB operation does not establish that this supply is
   within specification, nor does a board-maker expectation that it will work
   override the FPGA ratings. Reliability and lifetime at 3.3 V are not
   qualified here.

   Do not connect additional 3.3 V drivers on the assumption that the FPGA is
   3.3 V tolerant. Do not change the board's rail straps or regulator settings
   without reviewing the V005 schematic and every peripheral attached to EA.
   A signal-level shifter alone cannot fix an out-of-range **VDD_EA supply**.

GPIO voltage domains and evidence
---------------------------------

Do not assume that every ULX5M GPIO bank has the same supply. The board
repository's README says its default GPIO voltage is 1.8 V, but that general
statement does not establish the voltage of each bank on the specific V005
board being tested.

.. list-table:: ULX5M-GS V005 voltage observations (October 2026)
   :header-rows: 1
   :widths: 16 16 38 30

   * - Rail or interface
     - Reported level
     - Evidence
     - Qualification
   * - ``VDD_EA`` (east bank EA)
     - 3.3 V
     - Verbal confirmation from board manufacturer for the USB-powered board
     - Not yet independently measured at a VDD_EA supply point; exceeds DS1001
   * - ``VDD_EB`` (east bank EB)
     - About 1.8 V
     - Bench multimeter reading reported for the tested board
     - A separate rail from EA; do not extrapolate to every unit
   * - ``VDD_WA`` (configuration/JTAG bank)
     - 1.8 V in V005 schematic
     - V005 JTAG schematic shows ``VDD_WA`` on ``+1V8``; JTAG mode pins were
       also observed near 1.8 V
     - Tigard JTAG used 1.8 V logic; not a direct measurement of the supply ball
   * - Remaining GPIO banks
     - Not established here
     - Check board-revision schematics and populated regulators
     - Do not infer 1.8 V or 3.3 V from connector labels

The DS1001 single-ended input specification is ``-0.4 V`` to
``VDDIO + 0.4 V`` (Table 4.5). On a 1.8 V bank, direct 3.3 V inputs are outside
that range. Check the actual supply and use an appropriate interface before
connecting external logic. For 3.3 V peripherals, consult Cologne Chip's
UG1003 level-shifting guide; its examples assume the GateMate supply itself
is within its specified range.

USB-C connection
----------------

The experimental USB device implementation uses these EA pins:

.. list-table:: USB pins used by the ULX5M-GS port
   :header-rows: 1
   :widths: 24 26 50

   * - Function
     - GateMate signal
     - Note
   * - USB D+
     - ``IO_EA_A1``
     - EA supply reported as 3.3 V; do not infer the exact D+ line voltage
   * - USB D-
     - ``IO_EA_B1``
     - Shares bank EA and its VDDIO
   * - USB attach control
     - ``IO_EA_A2``
     - Controls the attach pull-up in the current USB probe

The board's 25 MHz oscillator is the reference for the experimental USB PLL.
One earlier probe produced approximately 47.9167 MHz for a nominal 48 MHz USB
clock. The PLL configuration, routed Fmax, USB clock accuracy, and signal
integrity are separate issues: a timing PASS does not prove USB signaling
compliance or reliable enumeration.

In October 2026, a JTAG/SRAM-loaded USB probe enumerated on Windows. Later
SERV-based endpoint-zero work also enumerated, but repeated USB descriptor
requests could intermittently fail after prior successful requests. The cause
has not been isolated to the SERV core, USB RTL, timing, or hardware voltages.
Do not present intermittent USB transactions as evidence that 3.3 V VDD_EA is
safe or that it caused the failures. See :doc:`../../user-guide/bootloader`
for the earlier hardware-tested probe and its limitations.

JTAG and configuration
----------------------

The V005 schematic routes the GateMate JTAG signals through the Raspberry Pi
40-pin header (GPIO12/16/20/21; header pins 32/36/38/40), with 200-ohm series
resistors. The configuration/JTAG bank is ``WA``, shown with a 1.8 V supply in
the schematic. The separately powered Tigard is configured for 1.8 V I/O;
leave Tigard ``VTGT`` disconnected and share GND with the board.

.. figure:: ../../images/ulx5m-gs-jtag.png
   :alt: ULX5M-GS V005 configuration and JTAG schematic showing 1.8 V supply

   V005 configuration/JTAG schematic excerpt. The ``VDD_WA`` rail is shown
   at ``+1V8``; ``JTAG_TCK``, ``JTAG_TMS``, ``JTAG_TDI``, and ``JTAG_TDO``
   are separate from the EA USB pins.

The board also has six front-side JTAG pads. Their mating connector has not
been positively identified; do not assume a standard 0.1-inch or SOP/SC70
footprint from photos alone. Verify the exact pad dimensions, pin order,
mechanical retention, and GND before soldering an adapter. See
:doc:`../../user-guide/bootloader` for the tested Tigard sequence and
:doc:`../../troubleshooting` for the required cold-start recovery procedure.

Configuration flash and development status
------------------------------------------

The tested board's SPI flash returned JEDEC ID ``1f 42 16`` (AT25QL321,
4 MiB). The existing project diagnostic can read flash without writing it;
the original image was backed up in 64 KiB chunks. The ULX5M port is still
experimental: programming FPGA SRAM through JTAG does not create a persistent
DFU bootloader and power loss removes the running image. Do not apply ULX4M
flash layouts or recovery commands to ULX5M.

Sources and revision checks
---------------------------

* `Intergalaktik ULX5M-GS hardware repository
  <https://github.com/intergalaktik/ulx5m-gs>`_ - V005 source, schematic and
  default-voltage statement.
* `Cologne Chip DS1001, GateMate FPGA datasheet
  <https://colognechip.com/docs/ds1001-gatemate1-datasheet-latest.pdf>`_ -
  September 2026; Tables 4.1 and 4.5 (supply and GPIO limits).
* `Cologne Chip UG1003, 3.3 V peripheral interface guide
  <https://www.colognechip.com/docs/ug1003-gatemate1-level-shifting-latest.pdf>`_
  - August 2025; Section 1 and the interfacing examples.

The file ``docs/ds1001-gatemate1-datasheet-latest.pdf`` in this repository
is a **January 2023** copy despite its filename. The limits quoted here were
rechecked against the manufacturer's **September 2026** DS1001. For current
ratings, follow the manufacturer's linked datasheet rather than relying on
that bundled copy being the latest revision.
