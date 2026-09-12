Web Device Tool
===============

Hazard3-Doom includes a browser-based device tool in the repository ``web/``
directory. It combines the most common board bring-up and interactive tasks in
one page instead of requiring a separate terminal and several command-line
upload tools.

The current page provides four main areas:

* **Device uploading** - FPGA SRAM programming, console firmware loading, Doom
  H3D upload, and Doom IWAD upload.
* **Serial connection** - Web Serial port selection and UART settings.
* **UART terminal** - live monitor/Doom output, command entry, logging, and HDMI
  screen snip.
* **Hazard3-Doom controls** - one-click monitor, SAO, and I2CDriver commands.

The **Device uploading** and **Serial connection** panels are collapsible. The
individual uploaders inside **Device uploading** are collapsible as well, so the
terminal can retain most of the browser window during normal use.

Transport overview
------------------

The web tool uses three independent device paths:

.. code-block:: text

   Browser
     |
     +-- Web Serial --> USB-UART --> resident monitor / Doom
     |                  |             |
     |                  |             +-- H3L .h3d upload
     |                  |             +-- H3W .wad upload
     |                  |             +-- terminal / commands / screen snip
     |
     +-- WebUSB ------> ULX3S US1 FT231X --> ECP5 JTAG --> FPGA SRAM
     |
     +-- localhost ---> web-server.py --> GDB --> OpenOCD --> Hazard3 debug
                         console firmware ELF only

Web Serial and WebUSB communicate directly from the browser to devices selected
in the browser permission dialogs. The console firmware uploader is different:
it requires the project's local ``web-server.py`` helper because a static web
page cannot invoke the user's local GDB/OpenOCD tools.

Browser requirements
--------------------

Use a current Chromium-based browser such as Chrome or Edge. Web Serial and
WebUSB require a secure context. ``localhost`` is accepted for local use, and
HTTPS is suitable for a hosted copy such as GitHub Pages.

For the complete tool, including the console firmware uploader, start the
project server from the repository root:

.. code-block:: bash

   python3 web/web-server.py

Then open:

.. code-block:: text

   http://127.0.0.1:8000/

``http://localhost:8000/`` is equivalent when the local server uses its default
loopback binding.

.. warning::

   Do not double-click ``web/index.html`` or open it with a ``file://`` URL when
   the console firmware uploader is needed. The page can render as a local file,
   but there is no HTTP API behind it, so the local GDB/OpenOCD loader will be
   reported as unavailable. The browser address bar should show
   ``http://127.0.0.1:8000/`` (or ``localhost:8000``).

A generic static server is sufficient when the console firmware uploader is not
needed:

.. code-block:: bash

   cd web
   python3 -m http.server 8000

With a generic static server or GitHub Pages, the UART terminal, H3D uploader,
IWAD uploader, screen snip, and FPGA WebUSB flasher remain available. The
**Console firmware uploader** reports that its local loader is unavailable.

Serial connection
-----------------

Expand **Serial connection** and choose the UART device. The normal
Hazard3-Doom settings are:

.. code-block:: text

   115200 baud
   8 data bits
   no parity
   1 stop bit
   no flow control

The page also exposes the command line ending separately. ``CR + LF`` is the
normal interactive setting.

**Connect** opens the browser serial-device chooser. **Reconnect** opens the
selected port from the ports that the site has already been authorized to use.
Only one application can own a serial port at a time, so close PuTTY, another
browser tab, or a command-line uploader before connecting.

Device uploading
----------------

Expand **Device uploading** to access the four upload/programming workflows.
They are intentionally separate because they use different transports and have
different persistence rules.

FPGA web flasher
~~~~~~~~~~~~~~~~

The **FPGA web flasher** accepts an ULX3S ECP5 ``.bit`` or compatible ``.svf``
file and programs FPGA **SRAM** through the board's ``US1`` FT231X JTAG
interface using WebUSB.

The browser probes the physical ECP5 JTAG ID and, for a ``.bit`` file, verifies
that the bitstream target matches the FPGA before programming. The programmed
image starts immediately but is lost when power is removed. Persistent SPI
flash is intentionally not written by this control.

On Windows, the ULX3S FT231X used by WebUSB must be bound to WinUSB. This driver
choice is separate from the external USB-UART adapter used by Web Serial.

See :doc:`web-flasher` for target IDs, Windows driver compatibility, the JTAG
sequence, and troubleshooting.

Console firmware uploader
~~~~~~~~~~~~~~~~~~~~~~~~~

The **Console firmware uploader** loads ``hazard3-boot-monitor.elf`` through the
Hazard3 debug module. It does not ask the running monitor to replace itself.
Instead:

#. the browser validates the selected 32-bit little-endian RISC-V ELF;
#. ``web-server.py`` passes it to the project's local firmware loader;
#. GDB connects to OpenOCD, halts Hazard3, writes and verifies the ELF sections,
   sets the program counter, resumes the processor, and disconnects.

Start the matching OpenOCD configuration first and leave its GDB server
listening on port ``3333``. Do not leave the browser FPGA flasher connected to
``US1`` while OpenOCD needs the same FT231X JTAG interface.

The **Local loader Ready** state confirms that the browser can reach
``web-server.py``; it does not replace or start OpenOCD. OpenOCD is a separate
long-running process and must already have examined the Hazard3 core. Verify it
with output similar to:

.. code-block:: text

   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

The external J1 USB-UART adapter used by Web Serial is independent of the
``US1`` FT231X JTAG interface, so the UART console can remain connected while
OpenOCD is running.

This uploader is available only through ``web/web-server.py`` on the local
machine. It is disabled when the page is hosted as static content.

Doom H3D uploader
~~~~~~~~~~~~~~~~~

The **Doom H3D uploader** sends a packaged ``.h3d`` image over the same Web
Serial connection as the terminal. The resident monitor must be at its ``>``
prompt.

Before transmission, the browser validates the H3D header, package length, and
payload CRC32. It then follows the monitor H3L loader handshake:

.. code-block:: text

   browser -> l
   monitor -> H3L READY
   browser -> 64-byte H3D header
   monitor -> H3L DATA
   browser -> H3D payload
   monitor -> H3L OK

The upload changes SDRAM only; it does not modify the SD card. **Launch with
``j`` after upload** can be selected when the uploaded image should start as
soon as the monitor accepts it.

If Doom is already running, use **Stop Doom** first and wait for the monitor
``>`` prompt before starting an H3D transfer.

Doom IWAD uploader
~~~~~~~~~~~~~~~~~~

The **Doom IWAD uploader** sends a legally obtained Doom IWAD over Web Serial.
Commercial IWAD content is not distributed by Hazard3-Doom.

The browser validates the ``IWAD`` identification, directory and lump bounds,
Doom-visible filename, available reserved SDRAM space, and CRC32 before sending
the file. The monitor transfer uses the H3W handshake:

.. code-block:: text

   browser -> w
   monitor -> H3W READY
   browser -> 64-byte H3W header
   monitor -> H3W DATA
   browser -> IWAD bytes
   monitor -> H3W OK

Select the memory profile that matches the resident monitor build:

.. list-table::
   :header-rows: 1
   :widths: 20 30 50

   * - Profile
     - IWAD load address
     - Current use
   * - ``64m``
     - ``0x22c00000``
     - ULX3S and ULX4M-LD
   * - ``32m``
     - ``0x21000000``
     - ULX4M-LS

The profile matters because the H3W header contains the SDRAM destination
address. Selecting the wrong profile is therefore not just a UI preference.

As with H3D, **Launch with ``j`` after upload** is optional and is sent only
after the monitor reports ``H3W OK``.

Binary-transfer ownership
-------------------------

H3D and IWAD payloads are binary UART transfers. During either upload the web
application temporarily suspends ordinary command controls and screen-snip
capability probes so unrelated bytes cannot be inserted into the payload.
Normal terminal operation resumes when the transfer finishes or fails.

UART terminal and controls
--------------------------

The UART terminal provides live output, command history, RX/TX counters, a
session timer, local echo, auto-scroll, log copy/save controls, and the normal
resident-monitor command entry box.

The **Hazard3-Doom controls** panel provides convenience buttons for common
monitor and SAO/I2C operations. Raw one-byte controls do not append the selected
line ending.

The **Screen snip** control can capture supported HDMI application state over
UART and reconstruct the current ``1024x600`` display as a PNG in the browser.
See :doc:`web-serial` for the complete capability negotiation, wire protocol,
frame reconstruction, and firmware implementation details.

Suggested browser bring-up flow
-------------------------------

For a normal ULX3S development session, a convenient order is:

#. Start ``python3 web/web-server.py`` and open
   ``http://127.0.0.1:8000/`` if console firmware loading may be needed.
#. If necessary, expand **Device uploading -> FPGA web flasher** and program the
   matching ``.bit`` image into FPGA SRAM.
#. **Disconnect the FPGA web flasher from US1** after programming. OpenOCD and
   browser WebUSB cannot own the FT231X JTAG interface at the same time.
#. In a separate terminal, run ``./scripts/start-openocd.sh`` and wait for both
   ``Examined RISC-V core`` and ``Listening on port 3333``.
#. Expand **Serial connection**, select the external board UART, and connect at
   ``115200 8N1``. The UART can remain connected while OpenOCD is running.
#. If necessary, use **Console firmware uploader** to load the matching
   ``hazard3-boot-monitor.elf`` through the already-running OpenOCD server.
#. Confirm that the new monitor banner is readable and the ``>`` prompt responds
   to ``h`` or ``?``.
#. Upload the packaged Doom ``.h3d`` image.
#. Upload a legally obtained IWAD using the memory profile matching the monitor.
#. Launch with ``j`` from the uploader option or the terminal.

On a board with no micro-SD card installed, the monitor may first report an SD
initialization failure such as ``CMD0 failed r1=0x000000FF`` before presenting
the ``>`` prompt. That is expected when no card is present; it is not a UART,
SDRAM, or OpenOCD failure.

The command-line upload scripts remain useful for automation and debugging; the
web uploaders implement the same monitor H3L/H3W protocols rather than a
separate firmware path.

Data and persistence boundaries
-------------------------------

The browser tool deliberately keeps the persistence boundaries visible:

.. list-table::
   :header-rows: 1
   :widths: 30 35 35

   * - Operation
     - Transport
     - Persistent after power-off?
   * - FPGA web flasher
     - WebUSB / JTAG
     - No; FPGA SRAM only
   * - Console firmware uploader
     - localhost + GDB/OpenOCD
     - No; loaded into the running FPGA system
   * - H3D uploader
     - Web Serial / H3L
     - No; SDRAM only
   * - IWAD uploader
     - Web Serial / H3W
     - No; SDRAM only

For standalone boot and persistent FPGA configuration, see
:doc:`../getting-started/programming` and :doc:`sd-card`.

Related documentation
---------------------

* :doc:`web-serial` - detailed Web Serial console and HDMI screen-snip protocol.
* :doc:`web-flasher` - detailed ULX3S WebUSB/JTAG FPGA programming guide.
* :doc:`monitor` - resident monitor commands and loader behavior.
* :doc:`doom` - Doom image and runtime operation.
* :doc:`sd-card` - standalone H3D/IWAD loading from micro-SD.
* :doc:`jtag-debugging` - OpenOCD/GDB debug setup.
