DFU Bootloader Operation and Recovery
=====================================

.. important::

   Replacing the board DFU bootloader is **highly unusual** and is **not** part
   of normal Hazard3-Doom installation, FPGA development, firmware loading, or
   Doom updates.

   In normal use, keep the existing bootloader and replace only the **user
   bitstream** in its normal DFU user-image area. Do not expose or write the
   bootloader flash area unless you are intentionally developing the bootloader
   itself or recovering a board whose persistent bootloader is missing,
   corrupted, or known to be incompatible with the board.

This page describes the working ULX3S and ULX4M-LD USB DFU bootloaders and
the in-development ULX5M-GS port. Ordinary DFU operation is separate from
bootloader replacement and recovery.

Do not confuse these three components
--------------------------------------

Hazard3-Doom uses several pieces of software and FPGA configuration that can all
participate in startup, but they are not interchangeable:

``DFU bootloader``
   A persistent FPGA configuration and small firmware environment stored at the
   beginning of SPI flash. It provides USB DFU access and then transfers control
   to the user FPGA image. This is the component discussed on this page.

``FPGA user bitstream``
   The normal Hazard3-Doom FPGA image. Updating this image is routine and does
   **not** require replacing the DFU bootloader.

``Hazard3 boot monitor``
   The RISC-V monitor/firmware built by Hazard3-Doom, for example
   ``hazard3-boot-monitor.elf``. Loading or rebuilding the Hazard3 monitor does
   **not** mean that the board DFU bootloader must be replaced.

If the goal is to test or install a new Hazard3-Doom FPGA image, use the normal
programming procedures in :doc:`../getting-started/programming`. If the goal is
source-level firmware debugging, use :doc:`jtag-debugging`.

When bootloader replacement is actually appropriate
----------------------------------------------------

Replacing the bootloader should be treated as an advanced maintenance or
recovery operation. Typical reasons are limited to:

* the persistent DFU bootloader no longer enumerates and has been diagnosed as
  missing or corrupted;
* a board revision requires a deliberate bootloader pin-mapping or hardware
  compatibility change; or
* you are actively developing and validating the bootloader itself.

The following are **not** reasons to replace the bootloader:

* installing or updating Hazard3-Doom;
* loading a newly built FPGA bitstream;
* changing Hazard3 or LiteDRAM RTL;
* updating ``hazard3-boot-monitor.elf``;
* loading Doom or an IWAD; or
* testing a new FPGA route in SRAM or in the normal user-bitstream flash area.

Normal bootloader operation
---------------------------

On ULX3S and ULX4M-LD, the bootloader normally transfers control to the user
FPGA image. Holding the board-specific DFU-entry control instead keeps the
bootloader active so a host can program the user image through USB.

These bootloaders enumerate as VID:PID ``1d50:614b``. The normal user
bitstream is DFU alternate setting 0.

A normal user-image update therefore targets **alt 0**, not the bootloader
region.

ULX3S normal DFU operation
~~~~~~~~~~~~~~~~~~~~~~~~~~

The ULX3S bootloader provides USB DFU on connector ``US2``. It also provides the
ULX3S-specific ``US1`` passthrough behavior used for ESP32 programming. That
ESP32 passthrough behavior is specific to ULX3S and should not be assumed for
ULX4M-LD.

For the ULX3S bootloader described by ``bootloader/README.md``:

#. Remove or cycle board power as appropriate.
#. Hold ``BTN1`` or set DIP ``SW1`` ON.
#. Connect ``US2`` and wait for USB DFU enumeration.
#. Release the button after DFU is active if desired.

In bootloader mode, ULX3S LEDs 0 through 2 are expected to be on while LEDs 3
through 7 are off.

If the board does not power from ``US2`` because of its USB/RTC power state,
the upstream bootloader README documents two recovery options: also connect
``US1``, or hold ``BTN1`` and briefly press ``BTN0`` to power the board.

Confirm USB enumeration with:

.. code-block:: bash

   dfu-util -l

A normal user-bitstream transfer can use:

.. code-block:: bash

   dfu-util -a 0 -D blink.bit

or:

.. code-block:: bash

   openFPGALoader --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       blink.bit

To leave DFU and start the stored user bitstream:

.. code-block:: bash

   dfu-util -a 0 -e

ULX4M-LD normal DFU operation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The validated ULX4M-LD v0.0.3 bootloader uses a different physical button
mapping from ULX3S. PCB labels are one-based while the Verilog button vector is
zero-based, so use the PCB labels in the table below when operating the board.

.. list-table:: ULX4M-LD startup behavior
   :header-rows: 1
   :widths: 35 65

   * - Startup condition
     - Result
   * - No buttons
     - Boot the user bitstream beginning at flash address ``0x200000``.
   * - PCB ``BTN3``
     - Stay in ordinary DFU. Alt 0 through alt 4 are visible; alt 5 is hidden.
   * - PCB ``BTN2`` + ``BTN3``
     - Stay in bootloader-upgrade DFU. Alt 0 through alt 5 are visible.

.. warning::

   ``BTN2`` + ``BTN3`` is **not** the normal programming mode. It exposes alt 5,
   which contains the bootloader itself. For routine Hazard3-Doom FPGA updates,
   use PCB ``BTN3`` alone and program alt 0.

The validated ULX4M-LD DFU layout is:

.. list-table:: ULX4M-LD DFU alternate settings
   :header-rows: 1
   :widths: 10 35 55

   * - Alt
     - Flash range
     - Purpose
   * - 5
     - ``0x000000-0x1FFFFF``
     - Bootloader bitstream. Hidden during ordinary DFU operation.
   * - 4
     - ``0x800000-0xFFFFFF``
     - User data.
   * - 3
     - ``0x400000-0xFFFFFF``
     - User data.
   * - 2
     - ``0x360000-0x3FFFFF``
     - SaxonSoc U-Boot area.
   * - 1
     - ``0x340000-0x35FFFF``
     - SaxonSoc ``fw_jump`` area.
   * - 0
     - ``0x200000-0xFFFFFF``
     - Normal user bitstream area.

For a routine Hazard3-Doom user-bitstream update:

#. Remove power.
#. Hold PCB ``BTN3``.
#. Connect the ULX4M Micro-B USB cable/apply power.
#. Wait for ``1d50:614b`` to enumerate, then release ``BTN3``.
#. Program alt 0.

``BTN3`` selects DFU only during startup; do not keep it held for the transfer.
When using the bundled Windows tools directly from WSL, run the following first
if Bash reports ``Permission denied``:

.. code-block:: bash

   chmod +x ./bin/openFPGALoader.exe ./bin/dfu-util.exe

A validated command is:

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

To tell the bootloader to leave DFU and start the already stored user image:

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

The ``-e`` operation does not replace the bootloader and does not download a
new FPGA image. It requests the transition from the currently running DFU
bootloader to the user image already stored in flash.

ULX5M-GS V005 bootloader port (in development)
----------------------------------------------

.. note::

   The probe description below records the earlier PicoRV32 JTAG/SRAM
   stage. The separate active ``bootloader-serv/`` implementation later
   demonstrated native USB DFU flash writes and BTN2 startup selection.
   On October 26, 2026 a guarded installer wrote the SERV SPI-primary image
   at flash offset ``0x000000`` and verified the complete 4 MiB flash.
   On October 28, an independent v72 diagnostic primary physically
   demonstrated **SPI-active secondary takeover** into the v41 walking-LED
   image at ``0x201000``. That primary has no DFU support; full SERV/BTN2
   integration is still pending. See :doc:`../hardware/ulx5m/multiboot-v72`
   for the dated hardware evidence and recovery status.

.. warning::

   The ULX5M-GS **combined persistent DFU/normal bootloader is not yet
   qualified**. The isolated v72 primary did cold-boot from SPI and run the
   secondary application, but it has no DFU. The SERV BTN2/DFU branch and
   registered normal-boot handoff have not yet been proven together in one
   persistent 48 MHz image. Do not apply ULX4M flash layouts or DFU recovery
   commands to ULX5M.

ULX5M-GS V005 SW1 and BTN2 startup selection
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The physical SW1 DIP switches choose the GateMate hardware configuration
source at reset. On this V005 board, **ON/ON** ties ``CFG_MD2`` and
``CFG_MD3`` HIGH (JTAG, ``0xC``), while **OFF/OFF** lets both pins be pulled
LOW (SPI-active boot, ``0x0``). ``CFG_MD1`` and ``CFG_MD0`` stay LOW. Mixed
switch positions are not valid for the intended primary flash boot.

SW1 must be changed with the FPGA **powered off**, followed by a cold
power-on. GateMate samples ``CFG_MD`` at reset; the SERV RTL does not select
this hardware boot source. Once the primary configuration is loaded, BTN2
selects its firmware behavior: hold BTN2 during startup for USB DFU and
release after enumeration, or leave BTN2 released for the normal secondary
boot path. BTN2 cannot rescue an invalid primary image at flash zero.

See :doc:`../hardware/ulx5m/index` for the V005 pin-level mapping, full SW1
table, and recovery distinction. The October 26 v55 result is historical. On October 28, the isolated v72
primary passed SPI-active cold boot and secondary takeover with BTN2 released.
Persistent BTN2-selected DFU **in that same bootable primary** is not yet
verified; v72 itself deliberately has no DFU.

The port targets the Intergalaktik ULX5M-GS V005 with a Cologne Chip GateMate
CCGM1A1. It retains the ULX4M bootloader's PicoRV32/USB architecture but uses
GateMate-specific PLL, I/O, and build primitives. The probe runs RV32I firmware
from FPGA BRAM and uses a registered PicoRV32 memory-response stage. USB and
PicoRV32 share the nominal 48 MHz clock; no clock-domain crossing is needed.

The board's 25 MHz oscillator drives the GateMate PLL, which currently produces
approximately 47.9167 MHz. The 48 MHz timing constraint passed in local WSL
(48.16 MHz post-route Fmax) and in GitHub Actions (48.50 MHz post-route Fmax),
measured in October 2026. The margin is small. The PLL still reports ``CI``
and ``CP`` parameter-range warnings. Hardware operation is confirmed, but
the output clock frequency and jitter have not been measured independently.

The USB interface uses these GateMate pins:

.. list-table:: ULX5M-GS V005 USB probe signals
   :header-rows: 1
   :widths: 35 25 40

   * - Signal
     - FPGA pin
     - Status
   * - USB D+
     - ``IO_EA_A1``
     - 3.3 V EA bank
   * - USB D-
     - ``IO_EA_B1``
     - 3.3 V EA bank
   * - USB D+ attach control
     - ``IO_EA_A2``
     - Drives the pull-up on attach; otherwise high impedance

The unused ``USB_PULL_N`` connection and duplicate USB pads are not driven.
The diagnostic firmware advertises one DFU alternate setting with no upload or
download capability. Requests to download, upload, or detach are rejected.
The development USB VID:PID is ``1d50:614b``, inherited from the ULX3S/ULX4M
bootloader. This is a bench-test identity, not an assigned ULX5M product ID.
The probe reports ``ULX5M-GS FPGA (DFU Probe)`` as its USB product string.
Windows enumeration on physical ULX5M-GS V005 hardware passed in October 2026.

Build and verification
~~~~~~~~~~~~~~~~~~~~~~

From ``bootloader/``, with OSS CAD Suite, RISC-V bare-metal GCC, and Icarus
Verilog installed, run:

.. code-block:: bash

   python3 tests/check-ulx5m-gs-port.py
   python3 tests/check-ulx5m-gs-usb.py
   python3 tests/check-ulx5m-gs-probe.py
   make -f Makefile.ulx5m-gs test-usb-probe-bus
   make -f Makefile.ulx5m-gs bringup
   make -f Makefile.ulx5m-gs usb-probe

To exercise the registered response stage separately:

.. code-block:: bash

   iverilog -g2012 -s tb_soc_mem_response_reg \
       -o build-ulx5m-gs/response-test.vvp \
       rtl/soc_mem_response_reg.v tests/tb_soc_mem_response_reg.v
   vvp build-ulx5m-gs/response-test.vvp

The response-stage and integrated PicoRV32/BRAM/Wishbone simulations passed.
The build creates ``build-ulx5m-gs/top_ulx5m_gs_bringup.bit`` and
``build-ulx5m-gs/top_ulx5m_gs_usb_probe.bit``. GitHub Actions workflow
``.github/workflows/bootloader-ulx5m-gs.yml`` passed synthesis, routing,
timing, simulations, and bitstream packaging. Both images have also been run
on ULX5M-GS V005 hardware. Persistent flash boot is not implemented.

JTAG through the Raspberry Pi carrier
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The V005 ``config.kicad_sch`` and ``cm4-gpio.kicad_sch`` route GateMate JTAG
through the same Raspberry Pi 40-pin header positions used by ULX4M-LD:

.. list-table:: ULX5M-GS V005 JTAG routing
   :header-rows: 1
   :widths: 25 25 20 30

   * - JTAG signal
     - Raspberry Pi GPIO
     - Header pin
     - Series resistor
   * - TDI
     - GPIO12
     - 32
     - R147, 200 ohm
   * - TDO
     - GPIO16
     - 36
     - R148, 200 ohm
   * - TCK
     - GPIO20
     - 38
     - R149, 200 ohm
   * - TMS
     - GPIO21
     - 40
     - R150, 200 ohm

Use a common ground (header pin 34 or 39). The four resistors are marked as
populated in the V005 schematic. Verify continuity and the actual board's
JTAG I/O voltage before attaching the programmer. The GateMate JTAG bank is
expected to use 1.8 V signaling; some CM5 carriers default their GPIO voltage
reference to 3.3 V. Set the carrier and Tigard to compatible signaling levels.
Do not drive the JTAG inputs at 3.3 V without verifying the board voltage.

Hardware-verified JTAG and USB test
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The following sequence was verified on ULX5M-GS V005 with Tigard, Windows,
and ``openFPGALoader.exe``. The board is powered only by its USB-C connection;
Tigard is powered separately through its own USB connection. The JTAG adapter
does not supply target power.

* Set both SW1 DIP switches ON for JTAG configuration mode (``0xC``). The
  tested ``CFG_MD2`` and ``CFG_MD3`` pins measured approximately 1.8 V each.
* Set Tigard to JTAG mode and 1.8 V I/O. Leave Tigard ``VTGT`` disconnected.
  On Windows, Tigard FT2232H Interface 1 uses ``libusbK`` for JTAG; Interface 0
  remains on the FTDI UART driver.
* Connect TCK, TMS, TDI, TDO, and common GND using the V005 board mapping
  above or the six front-side JTAG pads. No reset wire is required for the
  verified test sequence.

Cold-start sequence (no buttons are pressed):

#. Remove USB power from both the ULX5M and Tigard. Leave JTAG signal wires
   connected.
#. Connect Tigard USB power first (1.8 V JTAG, ``VTGT`` disconnected).
#. Connect the ULX5M USB-C cable to the Windows host second. The user LEDs
   remain dark before FPGA programming.
#. Run the JTAG detection or programming command. After an SRAM load, if a
   subsequent JTAG command reports ``Error: no device found``, fully remove
   power from both devices and repeat this sequence before retrying.

From the Hazard3-Doom repository root in WSL, use the native Windows
``openFPGALoader.exe`` (verified with ``--freq 100k``):

.. code-block:: bash

   ./bin/openFPGALoader.exe -c tigard --freq 100k --detect

The expected JTAG IDCODE is ``0x20000001`` (Cologne Chip GateMate GM1Ax,
IR length 6). Program the LED/PLL bring-up image:

.. code-block:: bash

   ./bin/openFPGALoader.exe -c tigard --freq 100k \
       ./bootloader/build-ulx5m-gs/top_ulx5m_gs_bringup.bit

On the tested board, physical LEDs D0-D5 turn on, D6 blinks, and D7 remains
off. This confirms that the loaded configuration is executing, not merely
that the JTAG transfer reached 100 percent.

To test the PicoRV32 USB enumeration probe, program its image. A fresh
cold-start may be required if the preceding SRAM load makes JTAG detection
fail:

.. code-block:: bash

   ./bin/openFPGALoader.exe -c tigard --freq 100k \
       ./bootloader/build-ulx5m-gs/top_ulx5m_gs_usb_probe.bit

The observed USB-probe LED pattern is D0-D2 off, D3-D5 on, D6 blinking faster
than in the bring-up image, and D7 off. The D0-D2 startup pattern indicates
that the firmware reached its third startup checkpoint; USB enumeration
confirms that the processor has progressed into USB control handling.

Windows USB verification
~~~~~~~~~~~~~~~~~~~~~~~~

With the ULX5M USB-C data cable still connected, run in Windows PowerShell:

.. code-block:: powershell

   $dev = Get-PnpDevice -PresentOnly |
       Where-Object { $_.InstanceId -match 'VID_1D50&PID_614B' }
   $dev | Format-List Status, Class, FriendlyName, InstanceId
   $dev | ForEach-Object {
       Get-PnpDeviceProperty -InstanceId $_.InstanceId |
           Where-Object {
               $_.KeyName -match 'BusReportedDeviceDesc|DeviceDesc'
           } |
           Format-Table KeyName, Data -AutoSize
   }

Expected: ``Status: OK``, ``Class: USBDevice``, VID:PID ``1d50:614b``, and
``DEVPKEY_Device_BusReportedDeviceDesc`` equal to
``ULX5M-GS FPGA (DFU Probe)``. Windows may separately show
``DEVPKEY_Device_DeviceDesc`` as ``ULX4M-LS FPGA (DFU)`` because the shared
VID:PID retains an existing Windows driver description. Use the bus-reported
name to check the ULX5M product string. If another board with the same VID:PID
is connected, distinguish the physical device before interpreting the result.

During initial testing, one character in the bus-reported product string was
corrupted although the C descriptor and compiled RISC-V firmware contained the
correct UTF-16LE bytes. A complete power-off of **both** Tigard and the ULX5M,
followed by the startup sequence above and reprogramming the unchanged image,
restored the correct name. The cause was not determined. No descriptor-staging
workaround or USB data-path change was required.

.. important::

   USB-C provides the board's only power in this setup. Unplugging it erases
   the SRAM-loaded configuration. Do not disconnect USB-C merely to refresh
   enumeration; if power is removed, repeat the JTAG programming sequence.
   ``Done`` from openFPGALoader alone is not proof of a running FPGA image.

Read-only configuration-flash JEDEC diagnostic
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The standalone ``flash-jedec`` target runs from the ULX5M-GS V005 25 MHz
oscillator. It has no PicoRV32, PLL, or USB controller. It sends only SPI
``0x9f`` (Read JEDEC ID) at 6.25 MHz, then displays the three response bytes
on the board's eight user LEDs. It does not read flash contents or enable
flash writes.

From ``bootloader/``, build and validate:

.. code-block:: bash

   python3 tests/check-ulx5m-gs-flash-jedec.py
   make -f Makefile.ulx5m-gs test-flash-jedec
   make -f Makefile.ulx5m-gs flash-jedec
   grep 'Max frequency for clock' build-ulx5m-gs/flash-jedec-pnr.log | tail -1

The October 2026 ULX5M-GS V005 test passed the Icarus simulation and routed
at ``84.21 MHz`` Fmax against the ``25.00 MHz`` target. The output is
``bootloader/build-ulx5m-gs/top_ulx5m_gs_flash_jedec.bit``. A copy of the
hardware-tested bitstream is distributed as
``bin/fpga_ulx5m_gs_flash_jedec.bit``.

With the board in JTAG configuration mode, follow the Tigard-first, ULX5M-second
cold-start sequence above. From the repository root, load the distributed
image into volatile FPGA SRAM:

.. code-block:: bash

   ./bin/openFPGALoader.exe -c tigard --freq 100k \
       ./bin/fpga_ulx5m_gs_flash_jedec.bit

Read the *physical* D0-D7 LEDs, with D0 as bit 0. The diagnostic compensates
for the observed V005 D4/D5 and D6/D7 permutations:

.. list-table:: Hardware-verified flash ID, ULX5M-GS V005
   :header-rows: 1
   :widths: 32 32 36

   * - Action
     - LEDs on
     - Displayed byte
   * - After programming
     - D0, D1, D2, D3, D4
     - ``0x1f`` (manufacturer)
   * - Press BTN1 once
     - D1, D6
     - ``0x42`` (memory type)
   * - Press BTN1 again
     - D1, D2, D4
     - ``0x16`` (capacity)
   * - Hold BTN2 after two BTN1 presses
     - D2, D7
     - ``0x84`` (third-byte index)

The resulting JEDEC ID is ``1f 42 16``, consistent with the fitted
AT25QL321-MBUE-T, a 32 Mbit (4 MiB) SPI NOR flash. BTN1 cycles back to
the manufacturer byte on the third press; holding BTN2 indicates the
selected byte using ``0x81``, ``0x82``, or ``0x84``. Release BTN2 to
restore the ID display. The LEDs do not blink after the read completes.

The successful test confirms that GateMate user logic can access the board's
configuration-flash SPI pins after a JTAG SRAM load. This test alone does not
validate flash-content reads, erase/program operations, persistent boot, or
USB DFU. See ``bootloader/README_ULX5M_FLASH_JEDEC.md`` for signal details.

Read-only SPI flash-content diagnostic
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The standalone ``flash-data`` target uses the board's 25 MHz oscillator, no
CPU, PLL, or USB, and a 6.25 MHz SPI clock. It issues ``0x03`` with a 24-bit
address of zero and captures 32 bytes from the configuration flash in one
read-only transaction. BTN1 advances the displayed byte offset (0 through 31,
wrapping); holding BTN2 displays ``0x80 | offset`` on D0-D7 instead of data.
The diagnostic sends no write-enable, erase, or program command.

From ``bootloader/``:

.. code-block:: bash

   make -f Makefile.ulx5m-gs test-flash-data
   make -f Makefile.ulx5m-gs flash-data

The Icarus simulation passed, and the routed diagnostic achieved ``61.36 MHz``
Fmax against a ``25.00 MHz`` constraint (October 18, 2026). The output is
``build-ulx5m-gs/top_ulx5m_gs_flash_data.bit``; the hardware-tested copy is
``bin/fpga_ulx5m_gs_flash_data.bit``. From the repository root:

.. code-block:: bash

   ./bin/openFPGALoader.exe -c tigard --freq 100k \
       ./bin/fpga_ulx5m_gs_flash_data.bit

The first eight bytes were read twice using the physical LEDs and then
confirmed by a separate JTAG-to-flash dump:

.. code-block:: text

   Address  00 01 02 03 04 05 06 07
   Data     D9 01 ED 96 10 4D D6 00

At offset 2, holding BTN2 displayed ``0x82`` (D1 and D7 on); releasing it
displayed ``0xed`` (D0, D2, D3, D5, D6, D7 on). The earlier ``0xeb`` report
was corrected by this repeat test. The 32-byte independent JTAG dump began:

.. code-block:: text

   d9 01 ed 96 10 4d d6 00 00 00 00 33 00 00 00 00
   c3 01 0c fe 00 cc c6 dd 01 8d f1 01 45 d7 c1 18

See ``bootloader/README_ULX5M_FLASH_DATA.md`` for implementation and LED
operation. This validates basic FPGA-driven flash-content reads, but not
USB-to-flash transfers or persistent DFU.

Original 4 MiB configuration-flash backup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The fitted AT25QL321 (JEDEC ``1f 42 16``) contains 4,194,304 bytes. A direct
4 MiB ``openFPGALoader.exe --dump-flash`` attempt ended with an empty output;
the cause is not proven. Separate 32-byte and 64 KiB reads succeeded. To avoid
that failure mode, ``bootloader/scripts/dump-ulx5m-flash.sh`` reads 64 chunks
of 65,536 bytes through Tigard JTAG, checks each chunk's size, and assembles
the full image. It uses read-only operations and retains chunks for resuming.

From the repository root, after a Tigard-first, ULX5M-second cold start:

.. code-block:: bash

   ./bootloader/scripts/dump-ulx5m-flash.sh

Two independently captured complete images matched byte-for-byte using
``cmp`` on October 18, 2026. Both measured 4,194,304 bytes and produced the
following SHA-256:

.. code-block:: text

   74b3accfa91b04efee753a72b6b9787eb20bfb217266198fefb349ca1cb9509d

This checksum identifies the **original tested board image**, not a required
hash for future flash updates. Store both verified backups outside the
repository and do not commit the flash images or temporary chunk files to
Git. See ``bootloader/README_ULX5M_FLASH_BACKUP.md`` for resume, verification,
and SRAM-loading utility instructions.

Remaining work
~~~~~~~~~~~~~~

The USB probe enumerates, and separate 25 MHz GateMate diagnostics identify
and read the configuration flash. The integrated 48 MHz PicoRV32/USB flash-read
target has **not** met timing; USB flash-content reads are not yet available.
Before enabling flash writes, integrate and verify USB read requests against
the preserved backup, determine the flash layout and bootloader protection,
and validate user-image handoff and recovery. Persistent boot and DFU-entry
buttons remain unvalidated. See ``bootloader/README_ULX5M_USB_PROBE.md`` for
USB-probe limitations.

Rare bootloader replacement and recovery
----------------------------------------

The procedures below apply to the validated ULX4M-LD bootloader, not to
the unfinished ULX5M-GS port.

.. danger::

   Do not replace a working bootloader merely because a new Hazard3-Doom build
   is available. A bootloader update writes the first 2 MiB of flash, including
   the component that normally provides the easiest recovery path.

   A failed or mismatched bootloader write can leave JTAG recovery as the only
   practical way to regain DFU access.

The ULX4M-LD recovery procedure documented in
``bootloader/README_ULX4M_BOOTLOADER.md`` was validated on ULX4M-LD v0.0.3 with
an LFE5UM-85F FPGA and JTAG IDCODE ``0x01113043``. Do not use an image built for
a different FPGA density or an unverified board mapping.

0.2.0 CI toolchain pin
~~~~~~~~~~~~~~~~~~~~~~

The 0.2.0 ``ULX4M Bootloader`` GitHub Actions workflow intentionally pins OSS
CAD Suite to ``2026-09-14``. This preserves the known-good synthesis and
place-and-route environment used to validate the release instead of silently
following newer nightly tool builds.

A later OSS CAD Suite nightly exposed a multiple-driver issue in the existing
input-only ECP5 ``TRELLIS_IO`` usage. That RTL cleanup, testing with a newer
suite, and any deliberate update of the pinned CAD version are 0.3.0 work.
Until then, the 0.2.0 pin is part of the reproducible bootloader build
environment and should not be advanced casually.

Safe replacement sequence
~~~~~~~~~~~~~~~~~~~~~~~~~

The important rule is: **validate the replacement bootloader in FPGA SRAM
before writing the persistent bootloader flash region**.

A conservative replacement sequence is:

#. Build the intended bootloader for the exact board and FPGA.
#. Repack an SRAM-only test image without the persistent ``--bootaddr`` setting.
#. Load that image through JTAG and verify ordinary DFU operation.
#. Verify bootloader-upgrade mode separately.
#. Back up the existing alt-5 bootloader region before overwriting it.
#. Prepare an image that is exactly 2 MiB for alt 5.
#. Run a known-good bootloader from FPGA SRAM in upgrade mode.
#. Write the replacement to alt 5 while that SRAM copy is running.
#. Read alt 5 back before power-cycling.
#. Verify the readback byte-for-byte or by matching SHA256 hashes.
#. Only after successful readback, remove power and perform cold-boot tests.

This procedure deliberately avoids executing the flash-resident bootloader while
that same flash region is being replaced.

Back up ULX4M-LD alt 5
~~~~~~~~~~~~~~~~~~~~~~

When alt 5 has intentionally been exposed by the bootloader-upgrade mode, back
up the existing first 2 MiB before writing anything:

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -U bootloader-alt5-before-update.bin

Verify the backup size and record a hash:

.. code-block:: bash

   stat -c '%n: %s bytes' bootloader-alt5-before-update.bin
   sha256sum bootloader-alt5-before-update.bin

The expected size is exactly ``2097152`` bytes.

Write and verify a replacement
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

With a known-good SRAM bootloader still running in the intentional
bootloader-upgrade mode, write an exact 2 MiB image to alt 5:

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -D bootloader-alt5-2m.img

Do **not** power-cycle immediately. Read the region back first:

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -U bootloader-alt5-after-update.bin

Then verify both files are exactly 2 MiB and have identical hashes:

.. code-block:: bash

   stat -c '%n: %s bytes' \
       bootloader-alt5-2m.img \
       bootloader-alt5-after-update.bin

   sha256sum \
       bootloader-alt5-2m.img \
       bootloader-alt5-after-update.bin

Do not cold-boot the replacement if the sizes or hashes differ.

ULX4M-LD cold-boot verification
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After a verified alt-5 readback, remove all power so the SRAM-loaded test image
is lost. Then verify all three persistent startup paths:

#. No buttons: the normal user bitstream starts.
#. PCB ``BTN3``: ordinary DFU starts and alt 5 remains hidden.
#. PCB ``BTN2`` + ``BTN3``: upgrade DFU starts and alt 5 is visible.

Only after all three tests pass should the bootloader replacement be considered
complete.

JTAG recovery when persistent DFU is unavailable
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If the persistent bootloader does not enumerate as ``1d50:614b``, the validated
ULX4M-LD recovery path uses Tigard/JTAG to load an emergency bootloader into
FPGA SRAM. The bootloader source provides ``EMERGENCY_RESTORE2`` to force both
"stay in DFU" and bootloader write-enable behavior so alt 5 can be restored.

The recovery chain is:

.. code-block:: text

   Tigard JTAG
       -> emergency bootloader in FPGA SRAM
       -> USB DFU 1d50:614b
       -> alt 5 access
       -> restore exactly first 2 MiB
       -> read back exactly first 2 MiB
       -> SHA256 match
       -> cold boot from SPI flash

For the exact ULX4M-LD build commands, SRAM repacking procedure, button remapper,
pin mapping, and emergency build details, use the repository source document
``bootloader/README_ULX4M_BOOTLOADER.md``. Those steps are intentionally kept
out of the normal Hazard3-Doom programming path because they are board recovery
and bootloader-development procedures, not routine application programming.

ULX3S bootloader write protection note
--------------------------------------

The upstream ULX3S bootloader can write-protect the first 2 MiB on supported
16 MiB ISSI IS25LP128 and Winbond W25Q128 flash devices. Protection behavior is
flash-vendor-specific. The upstream README also warns that some
``openFPGALoader`` versions can remove non-OTP write protection while writing
flash.

Treat any ULX3S bootloader-region update as a separate maintenance operation.
Do not use persistent-flash commands that overwrite the first 2 MiB merely to
install a new Hazard3-Doom user image.

Source documentation
--------------------

The implementation and recovery details summarized here come from the bootloader
source documentation included with the Hazard3-Doom tree:

* ``bootloader/README.md`` - ULX3S DFU bootloader operation and flash-protection
  notes.
* ``bootloader/README_ULX4M_BOOTLOADER.md`` - validated ULX4M-LD build, SRAM
  test, backup, recovery, installation, readback, and cold-boot procedure.
* ``bootloader/README_ULX5M_USB_PROBE.md`` - ULX5M-GS V005 enumeration
  probe build, pin mapping, and limitations (no persistent DFU yet).


Implementation references
-------------------------
* `openFPGALoader <https://trabucayre.github.io/openFPGALoader/guide/install.html>`_
