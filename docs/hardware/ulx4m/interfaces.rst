External Interfaces and Expansion
=================================

The CM4-compatible connector pair is what turns ULX4M from a small FPGA board
into a module. It carries power and many peripheral signals between the module
and a carrier board. "CM4 compatible" should be read as a connector/form-factor
and signal-mapping design goal, not as a promise that arbitrary Raspberry Pi
software or every CM4 carrier function will automatically work with an FPGA.

Ethernet
--------

Published ULX4M variants include Ethernet hardware, but the exact PHY differs
between public sources and revisions. Crowd Supply lists ``KSZ9031RNXCA`` for
both promoted LS and LD configurations, while older LS documentation lists
``LAN8720A``.

Hazard3-Doom does not currently depend on Ethernet for its normal Doom, monitor,
programming, or debug path. The hardware guide records the interface because it
is part of the board and a natural future FPGA exercise, not because the current
SoC contains a production Ethernet stack.

CSI/DSI-style connectors
------------------------

Upstream material describes two-lane camera/display connector groups. Some are
implemented with ordinary FPGA I/O as "fake differential" pairs, while other
high-speed routes depend on SerDes-capable ECP5 variants and the exact PCB
revision.

These connectors are an excellent reminder that connector shape does not define
an electrical protocol. A MIPI-style connector can carry signals routed for
experimentation without the FPGA automatically implementing a MIPI D-PHY or
camera/display protocol.

SerDes and PCIe routes
----------------------

ULX4M was designed in part to make ECP5 high-speed SerDes resources easier to
experiment with. Published material describes SerDes routes to PCIe x1 and
other connectors/header locations.

Two checks are mandatory before using those routes:

#. Confirm the fitted ECP5 device actually includes the SerDes resources.
#. Confirm the PCB revision routes the desired channel to the connector you
   intend to use.

The current Hazard3-Doom ULX4M-LD device string ``LFE5UM-85F-8BG381C`` is from
the SerDes-capable ECP5 class, but the Doom SoC does not currently require PCIe
or another SerDes peripheral.

GPIO, buttons, switches, and LEDs
---------------------------------

Public ULX4M descriptions list GPIO, three buttons, two DIP switches, and eight
LEDs on representative configurations. The number actually used by a particular
Hazard3-Doom top level can be smaller.

For example, the current LD wrapper exposes eight LED outputs and uses them as
both bring-up diagnostics and general SoC GPIO after DDR initialization. Before
DDR calibration completes the LEDs expose a compact status view including the
board heartbeat, video/DDR lock state, initialization state, user-clock state,
and adapter activity. That makes the physical LEDs part of the memory bring-up
instrumentation rather than decoration.

The current LS wrapper exposes four LED outputs in its project top level,
matching the LPF used for that build.

UART
----

UART remains the simplest software-facing debug path. The project uses it for
resident-monitor interaction, diagnostics, image transfer, and Web Serial. The
ULX4M LPFs map the selected UART pins to the module/carrier FTDI path used by the
supported setup. See :doc:`pinout-and-revisions` for the ULX4M-LD carrier pinout
and board-revision notes.

JTAG is complementary rather than a replacement: UART is excellent for logs and
monitor commands; JTAG/OpenOCD/GDB is appropriate for halt/step/register/memory
and source-level debug.

Power and carrier-board assumptions
-----------------------------------

Upstream ULX4M documentation states that the module requires at least 500 mA
and discusses different carrier-board power arrangements. Carrier boards can
route USB and 5 V differently, so power-up instructions must name the carrier
rather than assuming every CM4-compatible base behaves the same way.

For hardware work, verify:

* the intended input supply and carrier-board power path;
* that all required FPGA/memory rails are present;
* I/O bank voltages before attaching external hardware; and
* whether a connector pin is an input, output, shared signal, or power rail.

Never infer voltage compatibility from connector shape alone.
