Board Pinouts and Wiring
=========================

This page collects the pinout diagrams and the project-tested connections most
useful when attaching UART adapters, SAOs, debug hardware, or other external
devices. It is a practical wiring reference; the hardware guide remains the
authoritative project reference for PCB revisions, schematics, LPF constraints,
and FPGA package-ball assignments.

ULX3S
-----

.. _fig-ulx3s-pinout:

.. figure:: ../images/ulx3s-pinout.png
   :alt: ULX3S pinout

   **ULX3S Pinout** - FPGA GPIO and connector pin assignments.

The project-tested Hazard3-Doom monitor UART uses these J1 connections:

.. code-block:: text

   adapter TX  -> J1 pin 8 / GP1 -> Hazard3 RxD
   adapter RX  <- J1 pin 6 / GP0 <- Hazard3 TxD
   adapter GND -> adjacent J1 GND

TX and RX are named from the perspective of each device, so they must be
crossed as shown. For schematic, LPF, header-orientation, and board-revision
details, see :doc:`../hardware/ulx3s/pinout-and-revisions`.

Tigard JTAG to Hazard3 on ULX3S
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The ULX3S J4 header is the direct external JTAG connection to the ECP5. Hazard3
uses the ECP5 hard JTAG TAP plus the ``JTAGG`` primitive to expose its RISC-V
Debug Transport Module, so the Tigard connects to J4 rather than to J1/J2.

The ULX3S manual gives the J4 signal layout as::

   3V3  GND
   TCK  TDI
   TDO  TMS

With Tigard in ``SPI/JTAG`` mode, use these connections. This follows the
published Tigard and ULX3S JTAG pinouts; it should be treated as a wiring
reference until the external-Tigard path is qualified in Hazard3-Doom.

.. list-table:: Tigard to ULX3S J4 for Hazard3 debugging
   :header-rows: 1
   :widths: 20 20 20 40

   * - Tigard pin
     - Tigard signal
     - Wire color
     - ULX3S J4
   * - 2
     - GND
     - Black
     - GND
   * - 3
     - TCK
     - White
     - TCK
   * - 4
     - TDI
     - Grey
     - TDI
   * - 5
     - TDO
     - Purple
     - TDO
   * - 6
     - TMS
     - Blue
     - TMS

Power the ULX3S normally from US1. Set Tigard for 3.3 V logic, but leave its
``VTGT`` wire disconnected so Tigard does not power the board. ``TRST`` and
``SRST`` are not required for the Hazard3 connection. Keeping US1 connected
also keeps the onboard FT231X powered; the ULX3S documentation notes that an
unpowered FT231X can load the shared JTAG signals on some board revisions.

See :doc:`jtag-debugging` for OpenOCD and GDB single-step examples.

Tigard JTAG to the onboard ESP32
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is a separate debug target. The classic ESP32 on ULX3S is an Xtensa
processor; it does not use the Hazard3/ECP5 JTAG path. Its native JTAG pins are
GPIO12 through GPIO15, and ULX3S shares those four signals with the microSD
socket. The mapping below is derived from the ULX3S schematic/LPF and the
Espressif ESP32 JTAG pinout; it has not yet been project-qualified on ULX3S:

.. list-table:: Tigard to ULX3S onboard ESP32
   :header-rows: 1
   :widths: 18 18 18 20 26

   * - Tigard
     - JTAG signal
     - ESP32 pin
     - ULX3S SD signal
     - microSD contact
   * - Pin 4 / grey
     - TDI
     - GPIO12 / MTDI
     - DAT2
     - Pin 1
   * - Pin 3 / white
     - TCK
     - GPIO13 / MTCK
     - DAT3
     - Pin 2
   * - Pin 6 / blue
     - TMS
     - GPIO14 / MTMS
     - CLK
     - Pin 5
   * - Pin 5 / purple
     - TDO
     - GPIO15 / MTDO
     - CMD
     - Pin 3
   * - Pin 2 / black
     - GND
     - GND
     - VSS
     - Pin 6, or another board GND

A microSD breakout or extension is preferable to probing the card socket
contacts directly. Remove the SD card before using these signals for ESP32
JTAG.

.. warning::

   The same SD signals are also connected to the ECP5. Do not attach or drive
   the Tigard JTAG signals while an FPGA image may be actively driving the SD
   bus. Before attempting ESP32 JTAG debugging, use or verify an FPGA image
   that leaves ``SD_D2``, ``SD_D3``, ``SD_CLK``, and ``SD_CMD`` high impedance.
   The normal Hazard3-Doom image uses the SD interface, so do not assume this
   condition is satisfied.

ESP32 ``EN`` is the active-low reset input. ULX3S exposes it through the J3
``WIFI_OFF`` jumper, so Tigard ``SRST`` can optionally be wired to the
``WIFI_OFF``/EN side of J3 for hardware reset. Basic JTAG attachment does not
require this connection. Identify the EN side of J3 before wiring it; do not
connect ``SRST`` to the J3 ground side.

GPIO12 is also an ESP32 boot-strapping pin related to SPI-flash voltage. When
using OpenOCD, keep the ESP32 flash-voltage setting at 3.3 V and avoid allowing
an external adapter to force an incorrect TDI level during reset.

ULX4M-LD on the Waveshare CM4 carrier
--------------------------------------

.. _fig-ulx4m-ld-pinout:

.. figure:: ../images/ulx4m_ld-pinout.png
   :alt: ULX4M-LD pinout

   **ULX4M-LD Pinout** - FPGA pin assignments on the
   `Waveshare CM4 Carrier <https://www.waveshare.com/wiki/CM4-IO-BASE-A#Dimension>`_.

For the project-tested Tigard UART connection on the Waveshare Raspberry
Pi-style 40-pin header:

.. code-block:: text

   Tigard UART TX  -> physical pin 16 -> GPIO23 -> FPGA N4 -> uart_rx
   Tigard UART RX  <- physical pin 18 -> GPIO24 <- FPGA N3 <- uart_tx
   Tigard GND      -> physical pin 20
   Tigard VCC      -> not connected

Do not power the ULX4M from Tigard. For module revisions, schematics, LPF
constraints, and carrier assumptions, see
:doc:`../hardware/ulx4m/pinout-and-revisions`. For the complete OpenOCD/Tigard
setup, see :doc:`jtag-debugging`.

Generate Custom Pinouts
-----------------------

The pinout diagrams can be regenerated or adapted with the standalone
`ULX Pinout Generator <https://github.com/ulx3s/ulx3s-pinout>`_. It builds
annotated diagrams from board-specific constraint files, connector maps, and
board images instead of hard-coding a single pin mapping. This is useful when
working with another board revision or LPF, checking how a design uses shared
FPGA pins, or producing a diagram in a different output format.

The generator currently supports ULX3S and ULX4M-LD. Mapping-data generation
and diagram rendering are separate steps: first select or generate the board
mapping from the appropriate LPF, then render the resulting pinout.

For Ubuntu or WSL, a basic setup is:

.. code-block:: bash

   git clone https://github.com/ulx3s/ulx3s-pinout.git
   cd ulx3s-pinout
   python3 -m pip install --user --upgrade pinout cairosvg pillow

For example, regenerate the default ULX3S mapping and PNG image with:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       --include aliases \
       --markdown output/ulx3s/PIN-MAPPING.md
   ./generate-pinout.py ulx3s --format png

To generate the ULX3S mapping from a different checked-in LPF, specify the LPF
explicitly before rendering the image. For example:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v20.lpf \
       --include aliases \
       --markdown output/ulx3s/PIN-MAPPING-v20.md
   ./generate-pinout.py ulx3s --format png

ULX4M-LD uses the same workflow with the ``ulx4m-ld`` board name:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx4m-ld \
       --markdown output/ulx4m-ld/PIN-MAPPING.md
   ./generate-pinout.py ulx4m-ld --format png

The renderer supports SVG, PNG, PDF, and PS output. See the generator repository
for board-specific options, layout details, and additional examples. Generated
diagrams are documentation aids; always verify connector power, FPGA sites,
board revision, shared resources, and connector orientation against the actual
schematic and selected constraint file before connecting hardware.

Before connecting external hardware
-----------------------------------

* Confirm the exact board and PCB revision.
* Confirm the active FPGA bitstream and LPF constraints.
* Check I/O voltage and signal direction before making a connection.
* Connect grounds before relying on UART or other single-ended signals.
* Do not assume a connector position has the same function across board or
  carrier revisions.

The diagrams are convenient visual references, but the active constraints and
the schematic for the hardware in front of you determine the actual electrical
connection.


External References
-------------------

* `ULX3S hardware manual <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_
* `ULX3S hardware sources <https://github.com/emard/ulx3s>`_
* `ULX Pinout Generator <https://github.com/ulx3s/ulx3s-pinout>`_
* `Tigard hardware/debug adapter <https://github.com/tigard-tools/tigard>`_
* `ESP32 JTAG pin mapping <https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/jtag-debugging/configure-other-jtag.html>`_
* `ULX4M hardware sources <https://github.com/intergalaktik/ulx4m>`_
* `Waveshare CM4-IO-BASE-A Schematic <https://files.waveshare.com/upload/a/aa/CM4-IO-BASE-A_V4_SchDoc.pdf>`_
* `Waveshare CM4-IO-BASE-A carrier <https://www.waveshare.com/wiki/CM4-IO-BASE-A>`_
