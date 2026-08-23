Web Serial Console and HDMI Screen Snip
=======================================

Hazard3-Doom includes a dependency-free browser console in the ``web/``
directory. It uses the browser Web Serial API to talk directly to the board's
UART and can also request a screen snip from supported HDMI applications.

The same web application also contains a separate WebUSB FPGA programmer for
the ULX3S ``US1`` FT231X JTAG interface. Web Serial and WebUSB are independent
transports: the UART console remains on its serial adapter while the FPGA
programmer talks to JTAG. See :doc:`web-flasher`.

The screen-snip path does not capture TMDS, read pixels back from the physical
HDMI connector, or require a server. The active firmware application sends the
indexed source frame and palette over UART. JavaScript reconstructs the full
HDMI active raster locally and downloads it as a PNG.

Web application files
---------------------

The browser application is implemented by:

.. code-block:: text

   web/index.html
   web/app.js
   web/styles.css

``index.html`` contains the controls, ``app.js`` owns Web Serial transport and
the screen-snip protocol, and ``styles.css`` provides the UI styling.

The page is static. There is no JavaScript package manager, framework, backend,
or cloud service in the screen-snip path.

Browser and serving requirements
--------------------------------

Web Serial requires a browser that exposes ``navigator.serial`` and a secure
context. ``localhost`` is accepted for local development, and HTTPS is suitable
for hosted use such as GitHub Pages.

A simple local server can be started from the ``web/`` directory with:

.. code-block:: bash

   python3 -m http.server 8000

Then open ``http://localhost:8000/`` in a Web Serial capable browser.

The normal Hazard3-Doom UART settings are:

.. code-block:: text

   115200 baud
   8 data bits
   no parity
   1 stop bit
   no flow control

The web console exposes these serial settings in the UI and persists its user
settings in browser ``localStorage``.

Screen-snip overview
--------------------

The **Screen snip** control downloads the current supported HDMI application as
a full ``1024x600`` PNG. The implementation is split between three layers:

#. The browser probes the active UART consumer to determine whether it supports
   screen snip.
#. The resident monitor (when its cached test frame is valid), Doom, or the
   I2CDriver HDMI GUI serializes its indexed source image and RGB332 palette
   over UART.
#. The browser removes the binary transfer from the terminal stream, expands the
   indexed source to the advertised display size, encodes a PNG with the Canvas
   API, and starts a local download.

The current resident monitor can also be a screen-snip provider. After a
successful monitor test-pattern presentation it stores a validated cached copy
of that RGB332 frame in reserved SDRAM and can serialize that cache on request.
Doom and the I2CDriver HDMI GUI provide their own active-screen implementations.
A loaded-but-not-running ``.h3d`` image does not provide capability merely by
being present in SDRAM.

Capability detection
--------------------

A connected serial port is not sufficient to enable screen snip. The browser
uses a small capability handshake so the button reflects the firmware mode that
is currently consuming UART input.

Reserved bytes are:

.. list-table::
   :header-rows: 1
   :widths: 18 24 58

   * - Byte
     - Name
     - Meaning
   * - ``0x1c``
     - Capability query
     - Sent by the browser to ask whether the active firmware screen supports the screen-snip protocol.
   * - ``0x06``
     - Capability ACK
     - Returned by the current monitor when its cached frame is valid, or by a supported Doom/I2CDriver HDMI implementation. The browser consumes this byte and does not display it in the terminal.
   * - ``0x1d``
     - Capture request
     - Sent only after capability has been confirmed. The active screen provider responds with an ``H3SNIP1`` frame.

An individual capability probe waits up to 750 ms for an ACK. Around runtime
transitions such as a Doom launch, the web application keeps a longer
reacquisition window and retries while the new UART consumer initializes. This
prevents an early probe during Doom startup from permanently leaving the button
disabled. A capture request is sent only after capability has been confirmed.

The screen-snip state is reflected in both button enablement and hover text:

.. list-table::
   :header-rows: 1
   :widths: 25 25 50

   * - State
     - Button
     - Hover/status meaning
   * - No serial connection
     - Disabled
     - Connect to the board first.
   * - Checking
     - Disabled
     - A capability query is in progress.
   * - Unsupported / no valid capture
     - Disabled
     - The current UART consumer did not report a valid capture source.
   * - Supported monitor/Doom/I2C screen
     - Enabled
     - The reported HDMI source can be downloaded as a ``1024x600`` PNG.
   * - Capture in progress
     - Disabled, labelled ``Capturing...``
     - A binary screen transfer is currently being received.

The HTML wraps the disabled button in a separate hoverable element. Disabled
HTML buttons do not reliably receive pointer events, so the wrapper owns the
``title`` text and remains hoverable even when the button cannot be clicked.

When capability is rechecked
----------------------------

The browser probes when a serial connection opens. It also schedules another
probe after commands that can change which firmware screen owns the UART:

.. code-block:: text

   i2c gui
   sao gui
   j
   b

The single-character launch commands use a longer delay than the GUI commands
so the new application has time to take control before the probe arrives.

If capture is currently unavailable, moving the pointer over the Screen snip
control initiates another probe. This lets the UI recover automatically if the
firmware mode changed by some path the browser did not observe.

The **Stop Doom** ``Ctrl-X`` control and the I2C GUI ``Q`` control trigger
capability reacquisition because those operations return UART ownership to the
resident monitor. The monitor may ACK if its cached frame remains valid. A
click on **Screen snip** also performs a final capability preflight before
sending ``0x1d``. That protects against stale UI state if the active firmware
changed since the last successful probe.


UART command routing and the ``H`` key
--------------------------------------

The resident monitor handles the reserved ``0x1c`` capability query and ``0x1d``
capture request before ordinary console command parsing. Normal printable keys
remain unchanged; in particular, the monitor keeps ``H`` as a Help key::

   case 'h':
   case 'H':
   case '?':
       console_print_help();
       break;

When ``i2c gui`` is active, ``hazard3_sao_console_feed(received)`` receives the
UART byte before the resident-monitor switch and consumes GUI keys such as
``H``. The I2C GUI's private ``toggle_resolution()`` helper is ``static`` in
``src/i2cdriver_hdmi.c`` and must not be called from ``src/main.c``. Doing so
would create an undefined linker reference; returning a value from
``console_poll()``, which returns ``void``, is also invalid.

Doom and the I2C GUI also intercept ``0x1c`` and ``0x1d`` inside their active
input paths, so capability follows whichever runtime currently owns UART input.
The I2C GUI must ACK ``0x1c`` as well as implement ``0x1d``; otherwise the
browser correctly leaves **Screen snip** disabled even though a capture handler
exists.

Wire protocol
-------------

After receiving ``0x1d``, the firmware writes an ASCII header terminated by
``CR LF`` and then immediately writes a binary payload.

The header grammar is:

.. code-block:: text

   H3SNIP1 <source_width> <source_height> <display_width> <display_height> IDX8 <palette_bytes> <pixel_bytes>\r\n

Current firmware emits a leading ``CR LF`` before ``H3SNIP1`` so ordinary UART
text is separated visually from the protocol header. The browser accepts and
forwards preceding ordinary text lines until it sees a valid ``H3SNIP1`` line.

For current Hazard3-Doom targets, ``display_width`` and ``display_height`` are
``1024`` and ``600``. ``palette_bytes`` must be exactly ``256`` and
``pixel_bytes`` must equal ``source_width * source_height``.

The browser rejects invalid headers, source images larger than 1,000,000 pixels,
and display images larger than 4,000,000 pixels. The header itself is also
bounded to 1024 bytes while capture is waiting for a valid response line.

Binary payload
--------------

The binary payload immediately following the header is:

#. 256 bytes of RGB332 palette data.
#. ``source_width * source_height`` bytes of indexed pixels in row-major order.

There is no binary trailer or terminator. The sizes in the validated header tell
the browser exactly how many bytes to consume. Any later UART bytes are returned
to normal terminal processing.

The current protocol identifier ``IDX8`` describes the wire representation, not
necessarily the provider's in-memory framebuffer packing. Every transmitted
pixel consumes one byte and is a palette index from 0 through 255.

Current source modes
--------------------

.. list-table::
   :header-rows: 1
   :widths: 22 18 18 18 24

   * - Provider/mode
     - Source geometry
     - Pixel bytes
     - Binary bytes including palette
     - Notes
   * - Doom standard
     - ``320x200``
     - ``64000``
     - ``64256``
     - Native Doom indexed source.
   * - Doom high-resolution presentation
     - ``400x240``
     - ``96000``
     - ``96256``
     - Doom still renders ``320x200``; firmware applies the same expansion used by the HDMI presentation path before serializing the snip.
   * - I2CDriver compatibility
     - ``320x200``
     - ``64000``
     - ``64256``
     - 8-bit indexed EBR-compatible source.
   * - I2CDriver 400 test mode
     - ``400x240``
     - ``96000``
     - ``96256``
     - Optional high-resolution comparison mode.

Representative headers are:

.. code-block:: text

   H3SNIP1 320 200 1024 600 IDX8 256 64000
   H3SNIP1 400 240 1024 600 IDX8 256 96000

RGB332 palette format
---------------------

Each palette byte is ``RRRGGGBB``:

.. code-block:: text

   bits 7..5   red,   3 bits
   bits 4..2   green, 3 bits
   bits 1..0   blue,  2 bits

The browser expands the components to 8-bit RGB with the same bit-replication
semantics used by the video path:

.. code-block:: text

   R8 = (R3 << 5) | (R3 << 2) | (R3 >> 1)
   G8 = (G3 << 5) | (G3 << 2) | (G3 >> 1)
   B8 = B2 * 0x55

Doom sends all 256 current palette entries after converting them to RGB332.
The I2CDriver UI currently uses 16 logical colors; entries 0 through 15 contain
the UI palette and entries 16 through 255 are sent as zero, matching its video
palette behavior.

Doom capture timing
-------------------

Doom does not immediately serialize the framebuffer from its UART input handler.
Receiving ``0x1d`` sets a pending flag. The request is fulfilled after the next
completed ``DG_DrawFrame()`` presentation path, so the screen snip is based on a
completed frame rather than a working buffer that Doom may still be modifying.

In the ``400x240`` Doom build, Doom itself remains a ``320x200`` renderer. The
capture code applies the same source expansion used by direct HDMI presentation:
16 horizontal source pixels become 20 output source pixels, and each group of
five source rows becomes six rows. The resulting protocol source is exactly
``400x240``.

I2CDriver capture timing and packing
------------------------------------

The I2CDriver HDMI GUI services ``0x1d`` directly from its UART event loop. It
serializes the GUI framebuffer representing the currently active source mode.
The control byte is intercepted before normal interactive key handling, so the
request is not interpreted as an I2C GUI command or prompt character.


Browser receive path
--------------------

Normal UART bytes are decoded by a persistent ``TextDecoder`` and appended to
the terminal. Screen-snip reception temporarily changes only the interpretation
of incoming bytes:

#. While waiting for the header, complete text lines are collected.
#. Lines that are not an ``H3SNIP1`` header are returned to the terminal.
#. After a valid header, the browser allocates exactly
   ``palette_bytes + pixel_bytes`` bytes.
#. Those bytes are copied verbatim and are never passed through the text decoder.
#. Once the exact payload length is received, any remaining bytes in the same
   serial chunk return to normal terminal processing.

This separation is required because arbitrary framebuffer and palette bytes are
not UTF-8 text and may contain control characters, NUL bytes, or byte sequences
that would corrupt terminal output if decoded.

Reconstructing the HDMI raster
------------------------------

The browser creates an in-memory Canvas whose dimensions are the display size
advertised by the header. Current firmware advertises ``1024x600``.

For every display pixel ``(x, y)``, JavaScript selects the corresponding source
pixel using integer nearest-neighbor mapping:

.. code-block:: text

   source_x = floor(x * source_width / display_width)
   source_y = floor(y * source_height / display_height)

The source byte is used as an index into the received RGB332 palette. The
expanded RGB value and an alpha value of 255 are written to ``ImageData``. The
browser then calls ``canvas.toBlob(..., "image/png")`` and downloads the result.

This means the screenshot represents the active display raster reconstructed
from the same indexed source image, rather than a capture of electrical HDMI
symbols. It also means the browser does not need to understand whether the
firmware source came from EBR, SDRAM, or a Doom expansion buffer.

Download naming and locality
----------------------------

The generated filename includes the reconstructed display geometry and an ISO
UTC timestamp, for example:

.. code-block:: text

   hazard3-doom-hdmi-1024x600-2026-08-19T18-00-00Z.png

The palette, indexed frame, RGB expansion, Canvas image, and PNG are processed
locally in the browser. The web application does not upload the screenshot to a
server.

UART transfer cost
------------------

The current transport is intentionally uncompressed. At 115200 baud with 8-N-1
framing, at most 11,520 UART data bytes are transmitted per second before
software overhead. Approximate minimum binary-payload times are therefore:

.. list-table::
   :header-rows: 1
   :widths: 25 25 25 25

   * - Source
     - Binary bytes
     - Approximate minimum time
     - Practical effect
   * - ``320x200``
     - ``64256``
     - 5.6 s
     - Noticeable pause while firmware writes UART data.
   * - ``400x240``
     - ``96256``
     - 8.4 s
     - Longer pause.

The ASCII header adds only a small amount to these values. Firmware is doing a
blocking UART stream during the payload, so Doom or the I2C GUI can appear
paused until the transfer finishes. The PNG size does not affect UART time
because PNG compression occurs only after the indexed payload reaches the
browser.

Timeouts and error handling
---------------------------

The browser uses two independent timeouts:

* Capability probe: 750 ms.
* Active screen capture: 30 seconds.

The capture parser reports an error if the header is malformed, the declared
sizes are inconsistent, the header becomes too long, the serial connection is
lost, the request cannot be written, the payload does not complete before the
capture timeout, or the browser cannot encode the Canvas as PNG.

Disconnecting cancels an active capture and resets capability to unavailable.

Compatibility and versioning
----------------------------

Older Doom or I2CDriver firmware does not understand the reserved capability
query and therefore sends no ``0x06`` ACK. The browser treats that as
unsupported and leaves Screen snip disabled. This prevents sending a binary
capture request to firmware that may interpret the byte differently.

A mixed revision can also contain the ``0x1d`` capture implementation without
the newer ``0x1c``/``0x06`` capability handshake. The browser intentionally
treats that combination as unavailable. The I2CDriver UART loop must implement
both capability ACK and capture request handling before the button can enable.

``H3SNIP1`` is the protocol version marker. Changes that would make existing
parsers interpret the payload incorrectly should use a new version marker
rather than silently changing the meaning of ``H3SNIP1`` fields.

The resident monitor should not acknowledge ``0x1c`` unless it actually gains a
compatible screen-snip provider. Capability must describe the active UART
consumer, not merely the fact that the bitstream has HDMI hardware.

Implementation locations
------------------------

The principal implementation points are:

.. code-block:: text

   web/app.js
       capability state machine
       raw UART request/ACK handling
       H3SNIP1 parser
       binary payload isolation
       RGB332 expansion
       1024x600 reconstruction
       PNG download

   web/index.html
       Screen snip button and hoverable disabled-state wrapper

   web/styles.css
       disabled-button wrapper pointer behavior

   doom/doomgeneric_hazard3.c
       Doom capability ACK
       deferred capture request
       Doom palette serialization
       320x200 and 400x240 source serialization

   src/i2cdriver_hdmi.c
       I2C GUI capability ACK
       active GUI framebuffer serialization
       GUI palette serialization
       320x200 and 400x240 source handling

No FPGA HDL change is required solely for the Web Serial protocol. The
screenshot transport is implemented in firmware and the browser.

Security and privacy
--------------------

The browser asks the user to select and authorize a serial port. UART traffic is
between the selected serial device and browser JavaScript. The screen-snip path
creates a local Blob URL only long enough to initiate the PNG download, then
revokes that URL.

Usage
-----

#. Serve the updated ``web/`` directory from a secure context or localhost.
#. Connect the browser to the Hazard3-Doom serial port at 115200 8-N-1.
#. Launch Doom or ``i2c gui``/``sao gui`` using firmware that implements
   ``H3SNIP1`` and the capability ACK.
#. Wait for **Screen snip** to become enabled. Hover the control to see the
   current availability state.
#. Press **Screen snip**.
#. Keep the serial port connected until the binary transfer completes and the
   PNG download starts.

See :doc:`doom` for Doom-specific behavior, :doc:`i2cdriver` for the HDMI I2C
GUI, :doc:`../architecture/video` for the display path, and
:doc:`../troubleshooting` for common screen-snip failures.
